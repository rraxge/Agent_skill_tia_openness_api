# -*- coding: utf-8 -*-
"""
lad_gen.py —— 生成西门子 TIA Portal LAD（梯形图）网络的 SimaticML（FlgNet v5）

为什么需要它：Openness 没有“画梯形图”的 API，建 LAD 块只能生成 SimaticML XML 再 Import。
本模块把“画网络”抽象成几个调用，自动处理 UId 分配与连线。

结构依据（权威，别猜）：`<TIA安装目录>\PublicAPI\<版本>\Schemas\`
  - SW.PlcBlocks.LADFBD_v5.xsd   FlgNet / Part / Wire / Call
  - SW.PlcBlocks.Access_v5.xsd   Access / Instance / Constant / CallInfo / Parameter
  - SW.PlcBlocks.SCL_v4.xsd      StructuredText（SCL 是 v4）

关键规则（均为实测踩坑所得，详见 SKILL.md）：
  1. 一条网络只能有一根电源轨连线：一根 <Wire> 带 <Powerrail/> + 多个落点 = 并联支路。
     拆成多根轨线会报“输出口只能接一个电源轨”。
  2. 空闲引脚必须配 <OpenCon/>：<Wire><NameCon UId="t" Name="ET"/><OpenCon UId="x"/></Wire>。
     不写报“connection ET is not connected”；只写 NameCon 报“A rung must have at least two connections”。
  3. CompileUnit 的 ID 不能与块内 MultilingualText 的 ID 撞（报 Duplicate Simatic ML ID）。
  4. 每个 CompileUnit 内部 UId 必须唯一（跨网络可重复，本模块用不重叠区间更省心）。
  5. 调用 FB 用 <Call><CallInfo Name= BlockType="FB">，每个参数都要 <Parameter> 声明且必须连上
     （不用就 OpenCon）；连线引用的是 Call 的 UId，不是 Parameter 的 UId。

用法：
    from lad_gen import Net

    # 串联起保停：[Start][/Stop] -> ( )Run
    n = Net(1000)
    a, b, r = n.local('Start'), n.local('Stop'), n.local('Run')
    n.coil('Coil', r, n.series([(a, False), (b, True)]))
    print(n.xml(101, title='起保停', comment='说明'))

    # 并联：[A] 或 [B] -> 置位 S
    n2 = Net(2000)
    s = n2.local('RunLatch')
    n2.coil('SCoil', s, n2.or_block([n2.contact(n2.local('A')), n2.contact(n2.local('B'))]))

    # 定时器（实例需在 FB 的 Static 段声明为 TON_TIME，见 SKILL.md）
    t = n2.part('TON', tv=[('time_type', 'Type', 'Time')], inst='IEC_Timer_0_Instance', ver='1.0')
    n2.wire(src, ('pin', t, 'IN'))
    n2.wire(('id', n2.local('PT_Time')), ('pin', t, 'PT'))
    n2.wire(('pin', t, 'ET'), ('open',))          # 空闲引脚
    n2.coil('SCoil', s, ('pin', t, 'Q'))
"""


def esc(s):
    """XML 文本转义（中文注释也要过）"""
    return (str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            .replace('"', '&quot;'))


class Net:
    """一个 LAD 网络（SW.Blocks.CompileUnit 里的 FlgNet）构造器"""

    def __init__(self, uid_start=100):
        self.parts = []
        self.wires = []
        self._u = uid_start
        self._rail = []          # 接电源轨的引脚；统一在 xml() 里合成“唯一一根轨线”

    def nid(self):
        """分配一个唯一 UId"""
        self._u += 1
        return self._u

    # ---------- 操作数 / 常量 ----------
    def local(self, name):
        """块内符号（FB 的 In/Out/Static/Temp 参数）"""
        u = self.nid()
        self.parts.append('<Access Scope="LocalVariable" UId="%d"><Symbol><Component Name="%s" /></Symbol></Access>' % (u, esc(name)))
        return u

    def glob(self, name):
        """全局符号（PLC 变量表里的名字，如 I_Start / Q_Motor / M_Ready）"""
        u = self.nid()
        self.parts.append('<Access Scope="GlobalVariable" UId="%d"><Symbol><Component Name="%s" /></Symbol></Access>' % (u, esc(name)))
        return u

    def const(self, val):
        """类型化常量，如 T#2S / 16#FF"""
        u = self.nid()
        self.parts.append('<Access Scope="TypedConstant" UId="%d"><Constant><ConstantValue>%s</ConstantValue></Constant></Access>' % (u, esc(val)))
        return u

    # ---------- 元件 ----------
    def part(self, name, negated=False, tv=None, inst=None, ver=None):
        """通用元件。
        name: Contact / Coil / SCoil / RCoil / O / TON / TOF / TP / PBox / NBox ...
        tv:   [(名, 类型, 值)]，如 [('Card','Cardinality',2)] 或 [('time_type','Type','Time')]
        inst: 实例名（TON/TOF/TP 必需，须在 FB 的 Static 段声明为 TON_TIME）
        """
        u = self.nid()
        inner = ''
        if inst is not None:
            iu = self.nid()
            inner += '<Instance Scope="LocalVariable" UId="%d"><Component Name="%s" /></Instance>' % (iu, esc(inst))
        if tv:
            for k, t, v in tv:
                inner += '<TemplateValue Name="%s" Type="%s">%s</TemplateValue>' % (k, t, v)
        if negated:
            inner += '<Negated Name="operand" />'
        verattr = (' Version="%s"' % ver) if ver else ''
        if inner:
            self.parts.append('<Part Name="%s"%s UId="%d">%s</Part>' % (name, verattr, u, inner))
        else:
            self.parts.append('<Part Name="%s"%s UId="%d" />' % (name, verattr, u))
        return u

    def rail_pin(self, uid, pin='in'):
        """把一个引脚挂到电源轨；xml() 会合成唯一一根轨线（含所有落点）"""
        self._rail.append((uid, pin))

    def contact(self, acc_uid, negated=False, src=None):
        """触点。src=None 表示直接接电源轨，否则接上游节点的 out。返回 ('pin', uid, 'out')"""
        c = self.part('Contact', negated=negated)
        if src is None:
            self.rail_pin(c)
        else:
            self.wire(src, ('pin', c, 'in'))
        self.wire(('id', acc_uid), ('pin', c, 'operand'))
        return ('pin', c, 'out')

    def coil(self, kind, acc_uid, src):
        """线圈。kind: 'Coil'（普通）/ 'SCoil'（置位）/ 'RCoil'（复位）"""
        c = self.part(kind)
        self.wire(src, ('pin', c, 'in'))
        self.wire(('id', acc_uid), ('pin', c, 'operand'))
        return ('pin', c, 'out')

    def series(self, items, src=None):
        """串联。items: [(acc_uid, negated), ...]；首件 src=None -> 接电源轨"""
        cur = src
        for uid, neg in items:
            cur = self.contact(uid, neg, cur)
        return cur

    def or_block(self, branches):
        """并联汇合：各支路的 out 进 O 块的 in1..inN（Card 自动算）"""
        o = self.part('O', tv=[('Card', 'Cardinality', len(branches))])
        for i, b in enumerate(branches):
            self.wire(b, ('pin', o, 'in%d' % (i + 1)))
        return ('pin', o, 'out')

    def wire(self, src, *dsts):
        """连一条线。元素写法：
        ('pr',)            电源轨
        ('id', uid)        操作数/常量引用
        ('pin', uid, 名)   元件引脚
        ('open',)          OpenCon（空闲引脚占位）
        """
        u = self.nid()

        def ref(x):
            if x[0] == 'pr':
                return '<Powerrail />'
            if x[0] == 'pin':
                return '<NameCon UId="%d" Name="%s" />' % (x[1], x[2])
            if x[0] == 'id':
                return '<IdentCon UId="%d" />' % x[1]
            if x[0] == 'open':
                return '<OpenCon UId="%d" />' % self.nid()
            raise ValueError(x)

        self.wires.append('<Wire UId="%d">%s%s</Wire>' % (u, ref(src), ''.join(ref(d) for d in dsts)))

    def xml(self, cu_id, title='', comment=''):
        """输出一个 SW.Blocks.CompileUnit。
        cu_id 必须与块内其它 ID（MultilingualText 等）不冲突；建议用 100 以上。
        """
        base = cu_id * 1000
        if self._rail:
            ru = self.nid()
            dsts = ''.join('<NameCon UId="%d" Name="%s" />' % (a, b) for a, b in self._rail)
            self.wires.insert(0, '<Wire UId="%d"><Powerrail />%s</Wire>' % (ru, dsts))
        return '''      <SW.Blocks.CompileUnit ID="{cid}" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource>
            <FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5">
              <Parts>
{parts}
              </Parts>
              <Wires>
{wires}
              </Wires>
            </FlgNet>
          </NetworkSource>
          <ProgrammingLanguage>LAD</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="{t1}" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="{t2}" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text>{c}</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="{t3}" CompositionName="Title">
            <ObjectList>
              <MultilingualTextItem ID="{t4}" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text>{ti}</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>'''.format(
            cid=cu_id, parts='\n'.join('                ' + p for p in self.parts),
            wires='\n'.join('                ' + w for w in self.wires),
            t1=base + 1, t2=base + 2, t3=base + 3, t4=base + 4,
            ti=esc(title), c=esc(comment))
