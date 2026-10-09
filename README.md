# tia-openness-api

Siemens TIA Portal 自动化技能（支持 **V19 / V20 / V21**）— 通过 Openness API 以 PowerShell 脚本实现对 TIA Portal 项目的全自动化操作。SDK 从注册表自动发现本机安装的版本，切换版本只需 `Connect-TiaPortal -TiaVersion 21`。

## 功能概览

| 类别 | 能力 |
|------|------|
| **连接管理** | 附加已有 TIA Portal 进程 / 启动新实例、断开连接 |
| **项目管理** | 打开、创建、保存、归档 (.zap19)、从归档恢复 |
| **设备** | 创建设备、设置 PROFINET IP、查看设备信息 |
| **PLC 程序块** | 列出/查找/导出/导入/创建/删除 FB、FC、OB、DB、UDT |
| **标签表** | 列出/查找/导出/导入/创建/删除标签表 |
| **XML 生成** | 生成 GlobalDB、FC、SCL 块 XML；生成标签表 XML |
| **编译** | 编译全部 PLC 软件或单个块 |
| **在线操作** | 上线/离线、下载到 PLC |
| **监视/强制** | 创建监视表、强制表 |
| **交叉引用** | 读取块接口、获取交叉引用 |

## 系统要求

- **Windows** 10 / Server 2016+
- **Siemens TIA Portal V19 / V20 / V21**（需已安装 Openness API 组件）
- **PowerShell 5.1+（64 位）**
- DLL 路径**不写死**，从 `HKLM\SOFTWARE\Siemens\Automation\Openness\<ver>\PublicAPI\` 自动发现
  - V19：`C:\Program Files\Siemens\Automation\Portal V19\PublicAPI\V19\Siemens.Engineering.dll`
  - V21：例 `D:\Siemens\Portal V21\PublicAPI\V21\net48\Siemens.Engineering.Base.dll`（盘符按实际安装位置） —— V21 拆成 `Base` / `Step7` / `WinCC` / ... 多个程序集，且多一层 `net48` 目录

## 快速开始

```powershell
# 1. 加载 SDK
. ".\TiaPortalSDK.ps1"

# 2. 连接 TIA Portal（附加或启动；多版本并存时用 -TiaVersion 指定）
Get-TiaInstallations | Format-Table Version, Dir -AutoSize
Connect-TiaPortal -StartIfNotFound -WithUI -TiaVersion 21

# 3. 打开项目
Get-TiaProject -ProjectPath "D:\Projects\MyProject.ap19"

# 4. 获取 PLC 软件
Get-TiaPlcSoftware -DeviceIndex 0

# 5. 查看所有块
Get-TiaBlocks -IncludeDetails | Format-Table -AutoSize

# 6. 编译
Invoke-TiaCompile

# 7. 保存并断开
Save-TiaProject
Disconnect-TiaPortal
```

## 文件结构

```
tia-openness-api/
├── SKILL.md           # 完整技能文档（~1700行），含 V21 实测章节
├── TiaPortalSDK.ps1   # PowerShell SDK 模块（~1060行，49函数，版本自适应 V19/V21）
├── package.json       # 包信息
├── _meta.json         # 元数据
└── README.md          # 本文件
```

## 典型工作流

### 批量导入程序块

```powershell
Connect-TiaPortal -StartIfNotFound -WithUI
Get-TiaProject -ProjectPath "D:\project.ap19"
Get-TiaPlcSoftware

# 导入顺序很关键：UDT → GlobalDB → FC → FB → InstanceDB → OB
Import-TiaBlock -XmlPath "blocks\udt\MotorType.xml" -Override
Import-TiaBlock -XmlPath "blocks\db\Config.xml" -Override
Import-TiaBlock -XmlPath "blocks\fc\Calculate.xml" -Override
Import-TiaBlock -XmlPath "blocks\fb\Motor.xml" -Override
Import-TiaBlock -XmlPath "blocks\idb\Motor_DB.xml" -Override
Import-TiaBlock -XmlPath "blocks\ob\Main.xml" -Override

Invoke-TiaCompile
Save-TiaProject
Disconnect-TiaPortal
```

### 导出所有块和标签表

```powershell
Connect-TiaPortal
Get-TiaProject -ProjectPath "D:\project.ap19"
Get-TiaPlcSoftware

Export-TiaBlock -Name "Main" -OutputDir "export\blocks" -WithDefaults
# ... 批量导出其他块

$tables = Get-TiaTagTables
foreach ($t in $tables) {
    Export-TiaTagTable -Name $t.Name -OutputDir "export\tags" -WithDefaults
}

Disconnect-TiaPortal
```

### 用代码生成 XML 并导入

```powershell
# 生成 GlobalDB XML
$members = @(
    @{ Name = "Speed"; DataType = "Real"; StartValue = "0.0"; Comment = "Motor speed" },
    @{ Name = "Status"; DataType = "Int"; StartValue = "0"; Comment = "Motor status" }
)
$xml = New-TiaGlobalDbXml -Name "MotorData" -Members $members
Write-TiaXmlWithBom -Xml $xml -Path "MotorData.db.xml"

# 导入
Connect-TiaPortal -StartIfNotFound
Get-TiaProject -ProjectPath "D:\project.ap19"
Get-TiaPlcSoftware
Import-TiaBlock -XmlPath "MotorData.db.xml" -Override
Save-TiaProject
Disconnect-TiaPortal
```

## 注意事项

1. **块导入顺序**：UDT → GlobalDB → FC → FB → InstanceDB → OB，否则会因依赖缺失而失败
2. **标签表 XML**：V19 必须使用 `SW.Tags.PlcTag`（非 `SW.Tags.Tag`），属性名为 `DataTypeName`
3. **地址对齐**：S7-1200/1500 要求 INT 从偶数字节开始 (`%MW0`、`%MW2`)，DINT/Real 从 4 的倍数开始 (`%MD0`、`%MD4`)
4. **PSObject 包装**：反射调用返回的对象常被 PowerShell 包装为 PSObject，需通过 `.BaseObject` 解包
5. **设备创建**：含 CPU 的设备必须使用 `CreateWithItem`，OrderNumber 必须包含空格（如 `"OrderNumber:6ES7 214-1AG40-0XB0/V4.5"`）
6. **V21 跨程序集**：`SW.*`（PlcSoftware / Blocks / Tags）在 `Siemens.Engineering.Step7.dll`，其余在 `Siemens.Engineering.Base.dll`。用 `Get-TiaType` 跨程序集解析，不要对单个程序集调 `GetType()`（V21 下会返回 `$null`）
7. **PowerShell 参数模式坑**：语句以函数调用开头时不能直接 `.Method()` 链式调用，整串会被当字符串参数；先赋值给变量再调
8. **XML 版本号**：V19 写 `V19`、V21 写 `V21`（SDK 按当前连接版本自动填 `$script:XmlVersion`）；归档扩展名同理 `.zap19` / `.zap21`
9. **V21 的 Add-In**：V20 及更早写的 Add-In 在 V21 不可用，需按新的 `Siemens.Engineering.AddIn.*` 机制改造

## 作为 Agent Skill 使用

本 Skill 是一个纯文本 + PowerShell 脚本的包，**不绑定任何特定的 Agent 框架**：
把 `SKILL.md` 作为上下文交给你的编码助手即可（也可以直接调用 `TiaPortalSDK.ps1`，
或用 `scripts/verify-e2e.ps1` 跑端到端验证）。SKILL.md 包含：

- 所有 SDK 函数的完整说明
- 底层反射 API 调用示例
- XML 生成模板（LAD、SCL、GlobalDB、标签表）
- 常见错误排查指南
- 地址对齐规则

## 许可证

MIT
