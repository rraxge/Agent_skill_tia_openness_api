---
name: "tia-openness-api"
description: "TIA Portal Openness API automation skill. Invoke when user asks to automate TIA Portal operations: create/open projects, import/export PLC blocks, manage tag tables, write LAD/SCL XML, or debug Openness API errors."
---

# TIA Portal Openness API Automation

西门子 TIA Portal Openness API 的 PowerShell 自动化。支持 **V19 / V20 / V21** —— SDK 自动发现本机安装的版本，无需改代码。

## 版本适配（先看这个）

| 项 | V19 及以前 | V21 起 |
|---|---|---|
| 安装位置 | `C:\Program Files\Siemens\Automation\Portal V19\` | 可装在任意盘（例：`D:\Siemens\Portal V21\`）；**别硬编码，从注册表发现** |
| Openness 程序集 | 单个 `Siemens.Engineering.dll` | 拆成多个：`Base` / `Step7` / `WinCC` / `WinCCUnified` / `Safety` / `Startdrive` / `TeamcenterGateway` |
| 主程序集 | `...\PublicAPI\V19\Siemens.Engineering.dll` | `...\PublicAPI\V21\net48\Siemens.Engineering.Base.dll`（**多一层 TFM 目录**） |
| 程序集签名 | `PublicKeyToken=d29ec89bac048f84` | `PublicKeyToken=29bfe5fdf4ba5d3b` |
| 工程 / 归档扩展名 | `.ap19` / `.zap19` | `.ap21` / `.zap21` |
| 导入 XML | `<Engineering version="V19" />` | `<Engineering version="V21" />` |
| Add-In | V20 及更早写的 | **在 V21 中不可用**，必须改成新的 `AddIn.*` 机制 |

**V21 类型分散的后果**：`Siemens.Engineering.Base.dll` 装的是 `TiaPortal` / `Project` / `HW.Device` / `Online.OnlineProvider` / `Download.DownloadProvider` / `ICompilable`；`Siemens.Engineering.Step7.dll` 装的是 `SW.PlcSoftware` / `SW.Blocks.*` / `SW.Tags.*`。**对单一程序集调 `GetType()` 会返回 `$null`** —— 本 SDK 用 `Get-TiaType` 跨程序集解析。

切换版本：`Connect-TiaPortal -TiaVersion 21`（缺省取本机最高版本）。

## SDK Module

Core module: `<技能目录>\TiaPortalSDK.ps1`（与 SKILL.md 同目录，整个技能包可克隆到任意位置）

Load with dot-source: `. "<技能目录>\TiaPortalSDK.ps1"`

### Available Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `Connect-TiaPortal` | Connect to TIA Portal (attach or start new) | `-StartIfNotFound -WithUI -TiaVersion 21` |
| `Get-TiaInstallations` | 列出本机已装的 Openness 版本 | `Version/Dir/Primary/Assemblies` |
| `Get-TiaType` | 跨程序集按全名解析类型 | `-TypeName 'Siemens.Engineering.SW.PlcSoftware'` |
| `Disconnect-TiaPortal` | Dispose TIA Portal connection | (none) |
| `Get-TiaProject` | Get or open a project | `-ProjectPath "D:\path\project.ap19" -Upgrade` |
| `Save-TiaProject` | Save current project | (none) |
| `New-TiaProject` | Create new project | `-Directory "D:\path" -Name "ProjectName"` |
| `Get-TiaPlcSoftware` | Find PLC software in device | `-DeviceIndex 0` |
| `Get-TiaDevice` | Get device by index | `-DeviceIndex 0` |
| `Get-TiaDeviceItems` | Get device item details | `-DeviceIndex 0` |
| `Get-TiaBlocks` | List all blocks | `-IncludeDetails` |
| `Get-TiaBlock` | Find a specific block | `-Name "Main"` |
| `Export-TiaBlock` | Export block to XML | `-Name "Main" -OutputDir "export" -WithDefaults` |
| `Import-TiaBlock` | Import block from XML | `-XmlPath "block.xml" -Override` |
| `New-TiaFB` | Create FB block（V21 已改为「生成 XML → 导入」） | `-Name "MyFB" -ProgrammingLanguage "LAD"` |
| `New-TiaFbXml` | 生成可导入的 FB XML（V21 的 CreateFB 只支持 ProDiag，FB 必须走 XML） | `-Name -ProgrammingLanguage -StaticMembers` |
| `Set-TiaOnlineTargetInterface` | 把在线目标网卡切到指定 PC 接口（如 PLCSIM 虚拟网卡） | `-PcInterfacePattern 'PLCSIM'` |
| `Connect-TiaToPlcsim` | 仿真联机：切网卡 → GoOnline → 在线则下载 | `-DeviceIndex 0` |
| `New-TiaInstanceDB` | Create instance DB | `-Name "MyDB" -InstanceOfName "MyFB"` |
| `Remove-TiaBlock` | Delete blocks by name | `-Names @("Block1","Block2")` |
| `Remove-TiaBlocksByPattern` | Delete blocks by pattern | `-Pattern "Temp_*"` |
| `Get-TiaTagTables` | List all tag tables | (none) |
| `Get-TiaTagTable` | Find a specific tag table | `-Name "Variables"` |
| `Export-TiaTagTable` | Export tag table to XML | `-Name "Variables" -WithDefaults` |
| `Import-TiaTagTable` | Import tag table from XML | `-XmlPath "tags.xml" -Override` |
| `Remove-TiaTagTable` | Delete tag tables by name | `-Names @("Table1")` |
| `Remove-TiaTagTablesByPattern` | Delete tag tables by pattern | `-Pattern "Temp_*"` |
| `Invoke-TiaCompile` | Compile PLC software or single block | `-BlockName "Main"` |
| `Get-TiaOnlineProvider` | Get online provider for device | `-DeviceIndex 0` |
| `Get-TiaDownloadProvider` | Get download provider for device | `-DeviceIndex 0` |
| `Invoke-TiaGoOnline` | Go online to PLC | `-DeviceIndex 0` |
| `Invoke-TiaGoOffline` | Go offline from PLC | `-DeviceIndex 0` |
| `Invoke-TiaDownload` | Download to PLC | `-DeviceIndex 0 -Options "Software"` |
| `Set-TiaIpAddress` | Configure PROFINET IP | `-IpAddress "192.168.0.1" -SubnetMask "255.255.255.0"` |
| `New-TiaDevice` | Create a new device | `-OrderNumber "6ES7 214-1AG40-0XB0/V4.5" -DeviceName "PLC"` |
| `New-TiaTagXml` | Generate tag table XML | `-TableName "Vars" -Tags @(...)` |
| `New-TiaGlobalDbXml` | Generate GlobalDB XML | `-Name "data" -Members @(...)` |
| `New-TiaFcXml` | Generate FC XML | `-Name "MyFC" -ProgrammingLanguage "SCL"` |
| `Write-TiaXmlWithBom` | Write XML file with UTF-8 BOM | `-Xml $xml -Path "file.xml"` |
| `Add-Utf8Bom` | Add BOM to existing file | `-Path "file.xml"` |
| `Get-TiaBlockInterface` | Read block interface members | `-Name "data"` |
| `Get-TiaBlockReferences` | Get block cross-references | `-Name "Main"` |
| `New-TiaWatchTable` | Create watch table | `-Name "Watch1"` |
| `New-TiaForceTable` | Create force table | `-Name "Force1"` |
| `Get-TiaProjectStatus` | Get connection/project status | (none) |
| `Invoke-TiaArchive` | Archive project to .zap19 | `-TargetDirectory "D:\arch" -ArchiveName "proj"` |
| `Restore-TiaProject` | Restore project from archive | `-ArchivePath "D:\arch\proj.zap19" -TargetDirectory "D:\restore"` |

### Quick Usage Patterns

```powershell
. "<技能目录>\TiaPortalSDK.ps1"

Connect-TiaPortal
Get-TiaProject
Get-TiaPlcSoftware

$blocks = Get-TiaBlocks -IncludeDetails
$blocks | Format-Table -AutoSize

Invoke-TiaCompile

Save-TiaProject
Disconnect-TiaPortal
```

## Environment & Connection

- DLL: **不写死**。用 `Get-TiaInstallations` 从注册表发现（V21 例：`D:\Siemens\Portal V21\PublicAPI\V21\net48\Siemens.Engineering.Base.dll`，盘符按实际安装位置）
- 注册表根：`HKLM\SOFTWARE\Siemens\Automation\Openness\<ver>\PublicAPI\`
  - V21 形状：`\<apiVer>\net48\` → `Siemens.Engineering.Base = <dll 路径>`
  - V19 形状：`\<apiVer>\` 直接挂 DLL 值，**没有 **`net48`** 层**；且同一次安装会登记 `16.0.0.0`…`19.0.0.0` 多个 apiVer
- Load: `[System.Reflection.Assembly]::LoadFrom($dllPath)`（V21 要先加载 `Base`，再 `Step7`）
- Enum type: `TiaPortalMode` (NOT `TiaPortalStartMode`!)
- Prefer Attach to existing process; start new only if no process found
- PSObject wrapping: always unwrap with `.BaseObject`

```powershell
# 版本自适应入口：发现 → 选定 → 加载全部程序集
Get-TiaInstallations | Format-Table Version, Dir, Primary -AutoSize

Connect-TiaPortal -TiaVersion 21      # 或 -TiaVersion 19；缺省 = 本机最高版本
Get-TiaType 'Siemens.Engineering.SW.PlcSoftware'   # => Siemens.Engineering.Step7
```

```powershell
$dllPath = 'D:\Siemens\Portal V21\PublicAPI\V21\net48\Siemens.Engineering.Base.dll'   # 盘符按实际安装位置改
$asm = [System.Reflection.Assembly]::LoadFrom($dllPath)

$modeType = Get-TiaType 'Siemens.Engineering.TiaPortalMode'
$tpType = Get-TiaType 'Siemens.Engineering.TiaPortal'
$getProcessesMethod = $tpType.GetMethod('GetProcesses', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
$processes = $getProcessesMethod.Invoke($null, $null)
```

⚠️ **PowerShell 参数模式坑**：语句以函数调用开头时进入参数模式，不能直接`.Method()`链式调用，整串会被当成字符串参数，报 `[System.String] 不包含名为 GetMethod 的方法`。必须先赋值给变量（本 SDK 已按此写法）。

⚠️ **`$script:` 变量名冲突**：SDK 用 `$script:` 保存状态（`TiaVersion` / `Asm` / `DllPaths` / `DllPath` / `Project` / `Software` / `TiaPortal` / `XmlVersion` / `ProjectExt` / `ArchiveExt`）。**点源会把调用脚本里同名的脚本作用域变量整个覆盖** —— 例如自己写 `param([string]$TiaVersion)` 再 `. $sdk`，该参数会被置成 `$null`（实测：标签打成了 `V `）。自己的变量换名字，如 `-PortalVersion`。

if ($processes.Count -gt 0) {
    $process = $processes[0]
    if ($process -is [System.Management.Automation.PSObject]) { $process = $process.BaseObject }
    $attachMethod = $process.GetType().GetMethod('Attach')
    $tiaPortal = $attachMethod.Invoke($process, $null)
    if ($tiaPortal -is [System.Management.Automation.PSObject]) { $tiaPortal = $tiaPortal.BaseObject }
} else {
    $withUI = [System.Enum]::Parse($modeType, 'WithUserInterface')
    $ctor = $asm.GetType('Siemens.Engineering.TiaPortal').GetConstructor(@($modeType))
    $tiaPortal = $ctor.Invoke(@($withUI))
    if ($tiaPortal -is [System.Management.Automation.PSObject]) { $tiaPortal = $tiaPortal.BaseObject }
    Start-Sleep -Seconds 15
}
```

## Find PLC Software (Recursive)

```powershell
$softwareContainerType = $asm.GetType('Siemens.Engineering.HW.Features.SoftwareContainer')

function FindSw {
    param($item)
    $gsm = $item.GetType().GetMethod('GetService')
    if ($gsm -and $gsm.IsGenericMethod) {
        $gm = $gsm.MakeGenericMethod($softwareContainerType)
        $c = $gm.Invoke($item, $null)
        if ($c) {
            foreach ($s in $c.Software) {
                if ($s.GetType().Name -eq 'PlcSoftware') { return $s }
            }
        }
    }
    foreach ($sub in $item.DeviceItems) {
        $r = FindSw -item $sub
        if ($r) { return $r }
    }
    return $null
}

$project = $tiaPortal.Projects[0]
if ($project -is [System.Management.Automation.PSObject]) { $project = $project.BaseObject }
$device = $project.Devices[0]
if ($device -is [System.Management.Automation.PSObject]) { $device = $device.BaseObject }
$software = FindSw -item $device.DeviceItems[0]
```

## Device Creation

- Must use `CreateWithItem` method (not `Create`) for devices with CPU
- OrderNumber format MUST include spaces: `"OrderNumber:6ES7 214-1AG40-0XB0/V4.5"`

## Block Import Order (Critical!)

1. UDT — first, other blocks depend on these types
2. GlobalDB — FC/FB may reference variables
3. FC — no instance DB needed
4. FB — must be imported before InstanceDB
5. InstanceDB — must be after corresponding FB
6. OB — last, may call all other blocks

```powershell
$importOptionsType = $asm.GetType('Siemens.Engineering.ImportOptions')
$importOverride = [System.Enum]::Parse($importOptionsType, 'Override')
$blockGroup.Blocks.Import($fileInfo, $importOverride)
```

## Tag Table Operations

- Tag table group: `$software.TagTableGroup` (NOT `TagGroup`)
- Tag table collection: `$tagTableGroup.TagTables` (NOT `Tags`)
- Use XML import for tags with absolute addresses
- LogicalAddress format: `%M0.0` (Bool), `%MW2` (Int), `%MD10` (DInt/Real)

### Tag XML Import Format (V19)

Tag XML must use `SW.Tags.PlcTag` (NOT `SW.Tags.Tag`!) and `DataTypeName`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V19" />
  <SW.Tags.PlcTagTable ID="0">
    <AttributeList>
      <Name>TableName</Name>
    </AttributeList>
    <ObjectList>
      <SW.Tags.PlcTag ID="1" CompositionName="Tags">
        <AttributeList>
          <DataTypeName>Int</DataTypeName>
          <ExternalAccessible>true</ExternalAccessible>
          <ExternalVisible>true</ExternalVisible>
          <ExternalWritable>true</ExternalWritable>
          <LogicalAddress>%MW2</LogicalAddress>
          <Name>SV1</Name>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="2" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="3" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text>Comment text</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Tags.PlcTag>
    </ObjectList>
  </SW.Tags.PlcTagTable>
</Document>
```

### Address Rules for Data Types

- **Bool**: `%M0.0`, `%M0.1`, etc. (bit address)
- **Byte**: `%MB1`, `%MB2`, etc.
- **Int/Word**: `%MW0`, `%MW2`, `%MW4` — MUST start at even byte boundary!
- **DInt/DWord/Real**: `%MD0`, `%MD4`, `%MD8` — MUST start at byte divisible by 4!

⚠️ INT at `%MW1` or `%MW3` is INVALID — S7 PLCs require word alignment!

### Adding Tags to Existing Table

Export existing tag table first to get correct XML format, then either:
- Import a new `SW.Tags.PlcTagTable` with different Name (creates new table)
- Or add tags to existing table by importing tag XML into `$tagTable.Tags` collection

## DB Block Member Modification

To add/modify members in an existing DB (e.g., adding a new pump struct):

1. **Export** the DB to XML: `$dbBlock.Export($fileInfo, $exportWithDefaults)`
2. **Parse and modify** the XML in PowerShell:
   ```powershell
   [xml]$xml = Get-Content $exportPath
   $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
   $ns.AddNamespace('s', 'http://www.siemens.com/automation/Openness/SW/Interface/v5')
   $staticSection = $xml.SelectSingleNode('//s:Section[@Name="Static"]', $ns)
   # Find existing member to clone
   $existingMember = $null
   foreach ($m in $staticSection.SelectNodes('s:Member', $ns)) {
       if ($m.GetAttribute('Name') -eq 'ExistingName') { $existingMember = $m; break }
   }
   # Clone and modify
   $newMember = $existingMember.CloneNode($true)
   $newMember.SetAttribute('Name', 'NewName')
   # Update comment
   $commentNode = $newMember.SelectSingleNode('s:Comment/s:MultiLanguageText', $ns)
   if ($commentNode) { $commentNode.InnerText = 'New comment' }
   # Insert after existing member
   $staticSection.InsertAfter($newMember, $existingMember)
   $xml.Save($modifiedPath)
   ```
3. **Re-import** the modified DB: `$blockGroup.Blocks.Import($fileInfo, $importOverride)`
4. Address offsets are automatically calculated by TIA Portal — no need to specify manually

## GlobalDB Block XML Format (V19)

### AttributeList Required Fields

```xml
<SW.Blocks.GlobalDB ID="0">
  <AttributeList>
    <AutoNumber>true</AutoNumber>
    <DBAccessibleFromOPCUA>true</DBAccessibleFromOPCUA>
    <HeaderAuthor />
    <HeaderFamily />
    <HeaderName />
    <HeaderVersion>0.1</HeaderVersion>
    <Interface><Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
  <Section Name="Static">
    <Member Name="Var1" Datatype="Real" Remanence="NonRetain" Accessibility="Public">
      <AttributeList>
        <BooleanAttribute Name="ExternalAccessible" SystemDefined="true">true</BooleanAttribute>
        <BooleanAttribute Name="ExternalVisible" SystemDefined="true">true</BooleanAttribute>
        <BooleanAttribute Name="ExternalWritable" SystemDefined="true">true</BooleanAttribute>
        <BooleanAttribute Name="SetPoint" SystemDefined="true">false</BooleanAttribute>
      </AttributeList>
      <Comment>
        <MultiLanguageText Lang="zh-CN">Comment</MultiLanguageText>
      </Comment>
    </Member>
  </Section>
</Sections></Interface>
    <IsOnlyStoredInLoadMemory>false</IsOnlyStoredInLoadMemory>
    <IsWriteProtectedInAS>false</IsWriteProtectedInAS>
    <MemoryLayout>Standard</MemoryLayout>
    <Name>DB_Name</Name>
    <Namespace />
    <Number>0</Number>
    <ProgrammingLanguage>DB</ProgrammingLanguage>
  </AttributeList>
  <ObjectList>
    <MultilingualText ID="1" CompositionName="Comment">
      <ObjectList>
        <MultilingualTextItem ID="2" CompositionName="Items">
          <AttributeList>
            <Culture>zh-CN</Culture>
            <Text />
          </AttributeList>
        </MultilingualTextItem>
      </ObjectList>
    </MultilingualText>
    <MultilingualText ID="3" CompositionName="Title">
      <ObjectList>
        <MultilingualTextItem ID="4" CompositionName="Items">
          <AttributeList>
            <Culture>zh-CN</Culture>
            <Text />
          </AttributeList>
        </MultilingualTextItem>
      </ObjectList>
    </MultilingualText>
  </ObjectList>
</SW.Blocks.GlobalDB>
```

### Critical Rules for GlobalDB

1. GlobalDB only has `<Section Name="Static">` — NO Input/Output/InOut sections
2. Do NOT use `<IsIECCheckEnabled>` — GlobalDB does not support this attribute
3. Must include `<IsOnlyStoredInLoadMemory>` and `<IsWriteProtectedInAS>` attributes
4. `<ProgrammingLanguage>` must be `DB`
5. Must include both `Comment` and `Title` MultilingualText in ObjectList
6. Member `Remanence` attribute is valid in GlobalDB Static section
7. Use `<AutoNumber>true</AutoNumber>` with `<Number>0</Number>` to auto-assign block number

## FC/FB Block XML Format (V19)

### AttributeList Required Fields

```xml
<SW.Blocks.FC ID="0">
  <AttributeList>
    <AutoNumber>true</AutoNumber>
    <HeaderAuthor />
    <HeaderFamily />
    <HeaderName />
    <HeaderVersion>0.1</HeaderVersion>
    <Interface>...</Interface>
    <IsIECCheckEnabled>false</IsIECCheckEnabled>
    <MemoryLayout>Optimized</MemoryLayout>
    <Name>BlockName</Name>
    <Namespace />
    <Number>1</Number>
    <ProgrammingLanguage>LAD</ProgrammingLanguage>
    <SetENOAutomatically>false</SetENOAutomatically>
    <UDABlockProperties />
    <UDAEnableTagReadback>false</UDAEnableTagReadback>
  </AttributeList>
```

### Critical Rules

1. `<Interface>` MUST be inside `<AttributeList>`, NOT after `</AttributeList>`
2. `<Interface>` MUST NOT have `ID` attribute — it is an inline property
3. `<Namespace />` MUST exist even if empty
4. Do NOT use `<IsKnowHowProtected>` — V19 does not need it
5. Do NOT use `<InterfaceList>` — use `<Interface><Sections>` format instead

### Interface Format

```xml
<Interface><Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
  <Section Name="Input" />
  <Section Name="Output" />
  <Section Name="InOut" />
  <Section Name="Temp" />
  <Section Name="Constant" />
  <Section Name="Return">
    <Member Name="Ret_Val" Datatype="Void" Accessibility="Public" />
  </Section>
</Sections></Interface>
```

## LAD Network XML Rules

### FlgNet Namespace

```xml
<FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5">
```

### Normally Closed Contact

Use `<Negated>` child element, NOT `TemplateValue`:

```xml
<Part Name="Contact" UId="26">
  <Negated Name="operand" />
</Part>
```

WRONG: `<TemplateValue Name="Negate" Type="Bool">true</TemplateValue>`

### Powerrail Rule

- Only ONE Powerrail entry per LAD network
- All parallel branch contacts `in` must connect Powerrail in the SAME Wire element:

```xml
<Wire UId="30">
  <Powerrail />
  <NameCon UId="25" Name="in" />
  <NameCon UId="27" Name="in" />
</Wire>
```

WRONG: Using two separate Wire elements each with Powerrail

### OR Parallel Branch

```xml
<Part Name="O" UId="28">
  <TemplateValue Name="Card" Type="Cardinality">2</TemplateValue>
</Part>
```

- Card value = number of parallel branches
- in1 = main path output, in2 = first branch output, etc.

### Variable References

- Global: `<Access Scope="GlobalVariable"><Symbol><Component Name="VarName" /></Symbol></Access>`
- Local: `<Access Scope="LocalVariable"><Symbol><Component Name="VarName" /></Symbol></Access>`
- M-area absolute address variables must be defined in tag table first, then referenced by symbol name

## Project Operations

- Only one project can be open at a time
- Close current project before creating new one
- Always call `$project.Save()` after operations
- Delete blocks/tag tables by collecting into array first, then iterating (cannot delete during enumeration)
- Open project via `$tiaPortal.Projects.Open(fileInfo)`, NOT `$tiaPortal.Open()`
- If project is locked by another instance, wait up to 60s or close that instance first

## Chinese Encoding

- Scripts with Chinese **must** use UTF-8 BOM encoding. PS 5.1 读无 BOM 文件按 GBK 解码 → 中文乱码，甚至报「字符串缺少终止符」这类莫名其妙语法错误。
- ⚠️ 用 `write_file` / `skill_manage write_file` 生成的 .ps1 **不带 BOM**，含中文时会直接语法错。写完必须补 BOM：

```powershell
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($true)))
```

- `Out-File -Encoding utf8` outputs with BOM automatically
- Files written by Write tool may lack BOM, convert with:

```powershell
[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | Out-File -FilePath $bomPath -Encoding UTF8
```

## Sleep/Wait Constraint

- All `Start-Sleep` or wait times in scripts MUST NOT exceed 60 seconds
- For TIA Portal startup, use 15 seconds (sufficient in most cases)
- For project lock release, use 60 seconds maximum; if still locked, report error to user

## Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| TypeInitializationException | TIA Portal not running or DLL version mismatch | Confirm TIA Portal running, check DLL version |
| "No hardware object found with TypeIdentifier" | OrderNumber format wrong | Must include spaces: `6ES7 214-1AG40-0XB0` |
| "Block does not exist" | InstanceDB imported before FB | Reorder: FB before InstanceDB |
| "在 LAD 中只能包含一个电源线" | Parallel branches use multiple Powerrail Wires | Merge into single Wire element |
| "Type 特性无效 - TemplateType_TE" | Negate uses wrong Type | Use `<Negated Name="operand" />` |
| "操作数未定义" | Variable not in tag table | Create tag table and variables first |
| "Missing 'ReadOnly' XML attribute for IsKnowHowProtected" | Used `<IsKnowHowProtected>` | Remove it, V19 does not need it |
| "Missing 'ID' attribute for Interface" | `<Interface>` after `</AttributeList>` | Move `<Interface>` inside `<AttributeList>` |
| "Class of 'Interface' type not supported" | `<Interface>` has `ID` attribute | Remove ID, Interface is inline property |
| "Missing 'Namespace' identifier attribute" | `<Namespace />` missing | Add `<Namespace />` to AttributeList |
| "Class of 'Siemens.Engineering.SW.Tags.Tag' type not supported" | Used `SW.Tags.Tag` in tag XML | Use `SW.Tags.PlcTag` with `DataTypeName` instead |
| "IsIECCheckEnabled attribute not supported" | Used `<IsIECCheckEnabled>` in GlobalDB | GlobalDB does not have this attribute; use `<IsOnlyStoredInLoadMemory>` and `<IsWriteProtectedInAS>` instead |
| "无法设置属性 Remanence" | Used Remanence on Input/Output/InOut members | Remanence is only valid for Static section members |
| "项目已被打开，无法访问" | Project locked by another instance | Close existing instance or wait up to 60s |
| TiaPortalStartMode not found | Wrong enum name in V19 | Use `TiaPortalMode` instead |
| PSObject cannot convert to FileInfo | PowerShell wraps .NET objects | Unwrap with `.BaseObject` |
| INT variable at odd byte address (e.g., %MW1) | S7 PLCs require word alignment | Use even byte addresses: %MW0, %MW2, %MW4... |
| `[System.String] 不包含名为 GetMethod 的方法` | 语句以函数调用开头（参数模式）后又 `.Method()` 链式调用 | 先赋值再调：`$x = Get-TiaType '...'` 然后 `$x.GetMethod(...)` |
| V21 下 `$asm.GetType('Siemens.Engineering.SW.PlcSoftware')` 返回 `$null` | V21 类型分散在 Base / Step7 多个程序集，单一程序集查不到 | 用 `Get-TiaType`（跨程序集解析） |
| 找不到 V21 的 DLL | 硬编码了 `C:\Program Files\...\Portal V21`，但实际装在 D 盘 | 用 `Get-TiaInstallations` 从注册表取路径 |
| `Get-TiaInstallations` 只返回 V21、漏掉 V19 | V19 注册表没有 `net48` 这一层，DLL 值直接挂在 apiVer 下 | SDK 已兼容两种形状；自行遍历时两级都要试 |
| `不能对 Null 值表达式调用方法`（调 `Projects.OpenWithUpgrade` / `Retrieve` 时） | 对**集合**用了 `Unwrap-PSObject` —— PowerShell 函数 `return` 会展开集合：空集合→`$null`，非空→拆成里面的元素 | 集合不要 Unwrap；函数内输出用 `Write-Output $x -NoEnumerate`（SDK 已修） |
| `无法将 Connect-TiaPortal 项识别为 cmdlet/函数`（明明点源过 SDK） | 把 `. $sdk` 写进了 `& { }` / 函数包装的子作用域，函数定义随子作用域被销毁 | 点源必须在脚本**顶层**执行 |
| `No device at index 0` / `No PLC software` | 工程里没有设备（空工程） | 先查 `$script:Project.Devices.Count`；空工程也能升级成功，但没东西可编译 |
| `The action "Create block" only supports the programming language 'ProDiag'` | V21 的 `CreateFB` 被限制 | 改用 `New-TiaFbXml` + `Import-TiaBlock`（SDK 的 `New-TiaFB` 已自动这样） |
| `FC 上不包含名为 GetReferences 的方法` | V21 移除了 `GetReferences` | 用 `Siemens.Engineering.CrossReference` 命名空间 |
| `Language of 'SCL' have to have at least one compile unit` | 生成的 SCL 块没有 CompileUnit | 语言选 SCL/ST 时补一个 CompileUnit（SDK 已自动） |
| `Attribute 'NetworkSource' does not support xml attribute 'xmlns'` | CompileUnit 的 xmlns 挂错层了 | xmlns 必须挂在 `<StructuredText>` 元素上 |
| `Operation is not possible while project has unsaved changes` | V21 归档前有未保存改动 | 先 `Save()`（`Invoke-TiaArchive` 已自动做） |
| `Archive Operation is not possible as the target file/folder ... already exist` | 归档名和工程目录同名且在同一个父目录 | 归档到独立子目录（SDK 已提前拦下并给出清晰提示） |
| `找不到 Download 的重载，参数计数为 4` / `preDownloadConfigurationDelegate may not be null` | V21 的 Download 两个重载都要求非空 delegate | PowerShell 侧造不出该 delegate；下载留在 TIA 界面做 |
| `The connection partner is not responding`（GoOnline） | 在线目标网卡没配，或 PLCSIM 里没有活动虚拟 PLC 实例 | 先 `Set-TiaOnlineTargetInterface -PcInterfacePattern 'PLCSIM'`；实例需在 PLCSIM 界面先建 |

## Block Compilation

Compile blocks or entire PLC software to check for errors:

```powershell
$compilableType = $asm.GetType('Siemens.Engineering.Compiler.ICompilable')
$getServiceMethod = $software.GetType().GetMethod('GetService')
$compilableGeneric = $getServiceMethod.MakeGenericMethod($compilableType)
$compilable = $compilableGeneric.Invoke($software, $null)
if ($compilable -is [System.Management.Automation.PSObject]) { $compilable = $compilable.BaseObject }

$result = $compilable.Compile()
Write-Host ('State: ' + $result.State)
Write-Host ('Errors: ' + $result.ErrorCount + ', Warnings: ' + $result.WarningCount)

foreach ($msg in $result.Messages) {
    Write-Host ('[' + $msg.Severity + '] ' + $msg.Description + ' Path: ' + $msg.Path)
}
```

### Compile Single Block

```powershell
$block = $blockGroup.Blocks.Find('Main')
$compilableBlock = $block.GetService($compilableType)
$result = $compilableBlock.Compile()
```

### CompilerResult States

- `Success` — no errors
- `Warning` — compiled with warnings
- `Error` — compilation failed

## Block Deletion

Cannot delete blocks during enumeration — collect names first, then delete:

```powershell
$blocksToDelete = @()
foreach ($b in $blockGroup.Blocks) {
    $bObj = $b
    if ($bObj -is [System.Management.Automation.PSObject]) { $bObj = $bObj.BaseObject }
    if ($bObj.Name -like 'Temp_*') { $blocksToDelete += $bObj.Name }
}
foreach ($name in $blocksToDelete) {
    $block = $blockGroup.Blocks.Find($name)
    if ($block) { $block.Delete() }
}
```

### Delete Tag Tables

Same pattern — collect first, delete after:

```powershell
$tablesToDelete = @()
foreach ($t in $software.TagTableGroup.TagTables) {
    $tObj = $t
    if ($tObj -is [System.Management.Automation.PSObject]) { $tObj = $tObj.BaseObject }
    if ($tObj.Name -like 'Temp_*') { $tablesToDelete += $tObj.Name }
}
foreach ($name in $tablesToDelete) {
    $table = $software.TagTableGroup.TagTables.Find($name)
    if ($table) { $table.Delete() }
}
```

## Block Direct Creation (Empty Blocks)

V19 API only provides `CreateFB` and `CreateInstanceDB` methods directly. Other block types (FC, OB, GlobalDB) must be created via XML import.

### Correct Enum Types (V19)

- `Siemens.Engineering.SW.Blocks.ProgrammingLanguage` (NOT `PlcProgrammingLanguage`!)
- `Siemens.Engineering.SW.Blocks.BlockType` (NOT `PlcBlockType`!)
- `BlockType` values: Undef, FB, SFB, UDT, FBT, SDT (NOT OrganizationBlock/Function/etc.)
- `ProgrammingLanguage` values: STL, LAD, FBD, SCL, DB, GRAPH, CPU_DB, CFC, SFC, etc.

### Create FB Block

```powershell
$progLangType = $asm.GetType('Siemens.Engineering.SW.Blocks.ProgrammingLanguage')
$ladLang = [System.Enum]::Parse($progLangType, 'LAD')
$sclLang = [System.Enum]::Parse($progLangType, 'SCL')

$fb = $blockGroup.Blocks.CreateFB('MyFB', $true, 0, $ladLang)
```

### Create Instance DB for FB

```powershell
$instanceDB = $blockGroup.Blocks.CreateInstanceDB('MyDB', $true, 0, 'MyFB')
```

### Create FC/OB/GlobalDB via XML Import

For FC, OB, and GlobalDB blocks, use XML import (see FC/FB Block XML Format and GlobalDB sections above):

```powershell
$importOptionsType = $asm.GetType('Siemens.Engineering.ImportOptions')
$importOverride = [System.Enum]::Parse($importOptionsType, 'Override')
$blockGroup.Blocks.Import($fileInfo, $importOverride)
```

### Create Block from Library MasterCopy

```powershell
$blockGroup.Blocks.CreateFrom($masterCopy)
```

## SCL Code Block Creation

Create an SCL block with code by importing XML that includes `<CompileUnit>` sections:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V19" />
  <SW.Blocks.FC ID="0">
    <AttributeList>
      <AutoNumber>true</AutoNumber>
      <HeaderAuthor />
      <HeaderFamily />
      <HeaderName />
      <HeaderVersion>0.1</HeaderVersion>
      <Interface><Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
  <Section Name="Input">
    <Member Name="In1" Datatype="Bool" Accessibility="Public" />
  </Section>
  <Section Name="Output">
    <Member Name="Out1" Datatype="Bool" Accessibility="Public" />
  </Section>
  <Section Name="InOut" />
  <Section Name="Temp" />
  <Section Name="Constant" />
  <Section Name="Return">
    <Member Name="Ret_Val" Datatype="Void" Accessibility="Public" />
  </Section>
</Sections></Interface>
      <IsIECCheckEnabled>false</IsIECCheckEnabled>
      <MemoryLayout>Optimized</MemoryLayout>
      <Name>MySCL_FC</Name>
      <Namespace />
      <Number>0</Number>
      <ProgrammingLanguage>SCL</ProgrammingLanguage>
      <SetENOAutomatically>false</SetENOAutomatically>
      <UDABlockProperties />
      <UDAEnableTagReadback>false</UDAEnableTagReadback>
    </AttributeList>
    <ObjectList>
      <MultilingualText ID="1" CompositionName="Comment">
        <ObjectList>
          <MultilingualTextItem ID="2" CompositionName="Items">
            <AttributeList>
              <Culture>zh-CN</Culture>
              <Text />
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
      <SW.Blocks.CompileUnit ID="3" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5"><FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5"><Parts><Part Name="Assignment" UId="2"><TemplateValue Name="src" Type="Bool">In1</TemplateValue><TemplateValue Name="dst" Type="Bool">Out1</TemplateValue></Part></Parts><Wires><Wire UId="3"><NameCon UId="2" Name="dst" /><NameCon UId="4" Name="in" /></Wire></Wires></FlgNet></NetworkSource>
          <ProgrammingLanguage>SCL</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="4" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="5" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text>Out1 := In1;</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
    </ObjectList>
  </SW.Blocks.FC>
</Document>
```

### Simpler SCL Approach: Export → Edit → Re-import

For SCL blocks, it's often easier to:
1. Create empty FC/FB with SCL language
2. Export the block to XML
3. Modify the XML to add SCL code in the CompileUnit section
4. Re-import with Override

## Hardware Configuration

### Adding Expansion Modules

```powershell
$device = $project.Devices[0]
if ($device -is [System.Management.Automation.PSObject]) { $device = $device.BaseObject }

$hwConfigType = $asm.GetType('Siemens.Engineering.HW.HardwareConfiguration')

function FindCpuItem {
    param($deviceItem)
    $classification = $null
    try {
        $classification = $deviceItem.GetAttribute('Classification')
    } catch {}
    if ($classification -and $classification.ToString().Contains('CPU')) { return $deviceItem }
    foreach ($sub in $deviceItem.DeviceItems) {
        $r = FindCpuItem -deviceItem $sub
        if ($r) { return $r }
    }
    return $null
}

$cpuItem = FindCpuItem -deviceItem ($device.DeviceItems[0])

$diModule = $cpuItem.DeviceItems.CreateWithItem(
    'OrderNumber:6ES7 221-1BH32-0XB0/V2.0',
    'DI_Module',
    'DI_Module'
)
```

> ⚠️ **上面这段是错的，已在 V21/V19 实测推翻**：`DeviceItemComposition` 两个版本都**没有** `CreateWithItem`。
> 会报 `DeviceItemImpl 不包含名为 CreateWithItem 的方法`。
> `CreateWithItem` **只在 `DeviceComposition` 上**（`$project.Devices.CreateWithItem(...)`，用于新建带 CPU 的站点）。
> 给已有站点加扩展模块只有两条路：`DeviceItemComposition.CreateFrom(MasterCopy)`（需库主副本），或在 TIA 界面里加。
```

### Configuring PROFINET IP Address

```powershell
function SetPlcIpAddress {
    param($device, [string]$ipAddress, [string]$subnetMask = '255.255.255.0')

    foreach ($item in $device.DeviceItems) {
        foreach ($subItem in $item.DeviceItems) {
            try {
                $classification = $subItem.GetAttribute('Classification')
                if ($classification -and $classification.ToString().Contains('PN')) {
                    $subItem.SetAttribute('IPAddress', $ipAddress)
                    $subItem.SetAttribute('SubnetMask', $subnetMask)
                    $subItem.SetAttribute('UseIPProtocol', $true)
                    Write-Host "IP configured: $ipAddress"
                    return
                }
            } catch {}
        }
    }
}

SetPlcIpAddress -device $device -ipAddress '192.168.0.1'
```

### Reading Device Item Attributes

```powershell
foreach ($item in $device.DeviceItems) {
    Write-Host ('Item: ' + $item.Name + ' Type: ' + $item.TypeIdentifier)
    foreach ($sub in $item.DeviceItems) {
        Write-Host ('  Sub: ' + $sub.Name + ' Type: ' + $sub.TypeIdentifier)
        try {
            $attrs = @('Classification', 'IPAddress', 'SubnetMask', 'FirmwareVersion')
            foreach ($a in $attrs) {
                $val = $sub.GetAttribute($a)
                if ($val) { Write-Host ('    ' + $a + ': ' + $val) }
            }
        } catch {}
    }
}
```

## Online Operations & Simulation

### Key Discovery: Online/Download Types DO Exist in V19!

⚠️ **CORRECTION**: Previous versions of this skill incorrectly stated that online/download operations are NOT available. They ARE available, but under different namespace paths than older documentation suggests.

| Correct Type Name (V19) | Wrong Name (DO NOT USE) | Purpose |
|---|---|---|
| `Siemens.Engineering.Online.OnlineProvider` | ~~PlcOnlineProvider~~ / ~~SW.Online.PlcOnlineProvider~~ | Go online/offline |
| `Siemens.Engineering.Online.OnlineState` | — | Offline, Online, Connecting, etc. |
| `Siemens.Engineering.Download.DownloadProvider` | ~~SW.Online.DownloadConfiguration~~ | Download to PLC |
| `Siemens.Engineering.Download.DownloadOptions` | ~~SW.Online.DownloadOptions~~ | None, Hardware, Software, SoftwareOnlyChanges |
| `Siemens.Engineering.Download.DownloadResult` | — | Download result with State/ErrorCount |
| `Siemens.Engineering.Download.DownloadResultState` | — | Success, Information, Warning, Error |
| `Siemens.Engineering.Upload.StationUploadProvider` | — | Station upload from PLC |
| `Siemens.Engineering.Online.RHOnlineProvider` | — | Redundant HMI online |
| `Siemens.Engineering.Download.RHDownloadProvider` | — | Redundant HMI download |
| `Siemens.Engineering.Connection.ConnectionConfiguration` | — | Connection settings |
| `Siemens.Engineering.Online.Configurations.OnlineCredentials` | — | Online authentication |

### Simulation Limitation

V19's public API does NOT have a dedicated PLCSIM/simulation type. There is no:
- `SimulationFeature` or `PlcSimulation` type
- API to start/stop PLCSIM programmatically
- API to configure virtual commissioning

**Workaround**: Start PLCSIM Advanced manually (or via command line), then connect to it using OnlineProvider just like a real PLC.

> **V21 不同**：已有 `SW.PlcSimulationSettingsProvider` / `VirtualPlcSettingsProvider`（管工程侧仿真设置）；但启动/停止 PLCSIM 进程仍需手工或用命令行。

### Getting OnlineProvider and DownloadProvider

Both can be obtained via `GetService<T>()` on either `PlcSoftware` or `DeviceItem` (CPU):

```powershell
$onlineProviderType = $asm.GetType('Siemens.Engineering.Online.OnlineProvider')
$downloadProviderType = $asm.GetType('Siemens.Engineering.Download.DownloadProvider')

# Method 1: From CPU DeviceItem (RECOMMENDED)
$softwareContainerType = $asm.GetType('Siemens.Engineering.HW.Features.SoftwareContainer')
foreach ($item in $device.DeviceItems) {
    $realItem = if ($item -is [System.Management.Automation.PSObject]) { $item.BaseObject } else { $item }
    $gsm = $realItem.GetType().GetMethod('GetService')
    $gm = $gsm.MakeGenericMethod($softwareContainerType)
    $sc = $gm.Invoke($realItem, $null)
    if ($null -ne $sc) {
        $cpuItem = $realItem
        break
    }
}

# Get OnlineProvider from CPU DeviceItem
$gsm = $cpuItem.GetType().GetMethod('GetService')
$gm = $gsm.MakeGenericMethod($onlineProviderType)
$onlineProvider = $gm.Invoke($cpuItem, $null)

# Get DownloadProvider from CPU DeviceItem
$gsm = $cpuItem.GetType().GetMethod('GetService')
$gm = $gsm.MakeGenericMethod($downloadProviderType)
$downloadProvider = $gm.Invoke($cpuItem, $null)

# Method 2: From PlcSoftware (may return null if not configured)
$gsm = $software.GetType().GetMethod('GetService')
$gm = $gsm.MakeGenericMethod($onlineProviderType)
$swOnlineProvider = $gm.Invoke($software, $null)
```

### OnlineProvider Methods & Properties

```powershell
# Go online (connect to PLC/simulator)
$state = $onlineProvider.GoOnline()  # Returns OnlineState

# Check current state
$state = $onlineProvider.State  # OnlineState enum

# Go offline
$onlineProvider.GoOffline()

# Connection configuration
$config = $onlineProvider.Configuration  # ConnectionConfiguration
$isConfigured = $config.IsConfigured     # Boolean
$config.ApplyConfiguration($targetInterface)  # Apply config
```

### OnlineState Enum Values

| Value | Meaning |
|---|---|
| `Offline` | Not connected |
| `Connecting` | Connection in progress |
| `Online` | Connected to PLC |
| `Incompatible` | PLC firmware incompatible |
| `NotReachable` | PLC not reachable on network |
| `Protected` | PLC is password-protected |
| `Disconnecting` | Disconnection in progress |

### Download to PLC

```powershell
$downloadOptionsType = $asm.GetType('Siemens.Engineering.Download.DownloadOptions')
$downloadConfigDelegateType = $asm.GetType('Siemens.Engineering.Download.DownloadConfigurationDelegate')

# Download with options
$softwareOption = [System.Enum]::Parse($downloadOptionsType, 'Software')

# Create download configuration delegate (can be null for default)
$preDownloadDelegate = $null
$postDownloadDelegate = $null

# Method 1: Simple download with DirectoryInfo
$tempDir = New-Object System.IO.DirectoryInfo([System.IO.Path]::GetTempPath())
$result = $downloadProvider.Download($tempDir, $preDownloadDelegate)

# Method 2: Download with full configuration
$config = $downloadProvider.Configuration
$result = $downloadProvider.Download($config, $preDownloadDelegate, $postDownloadDelegate, $softwareOption)

# Check result
Write-Host ('Download State: ' + $result.State)        # DownloadResultState
Write-Host ('Errors: ' + $result.ErrorCount)
Write-Host ('Warnings: ' + $result.WarningCount)
```

### DownloadOptions Enum Values

| Value | Meaning |
|---|---|
| `None` | No specific option |
| `Hardware` | Download hardware configuration |
| `Software` | Download software (blocks) |
| `SoftwareOnlyChanges` | Download only changed blocks |

### DownloadResult Properties

| Property | Type | Purpose |
|---|---|---|
| `State` | DownloadResultState | Success, Information, Warning, Error |
| `ErrorCount` | Int32 | Number of errors |
| `WarningCount` | Int32 | Number of warnings |
| `Messages` | Composition | Detailed messages |

### DownloadResultState Enum Values

| Value | Meaning |
|---|---|
| `Success` | Download completed successfully |
| `Information` | Completed with info messages |
| `Warning` | Completed with warnings |
| `Error` | Download failed |

### RHOnlineProvider (Redundant HMI)

```powershell
$rhOnlineProvider = $cpuItem.GetService([Siemens.Engineering.Online.RHOnlineProvider])
$primaryState = $rhOnlineProvider.GoOnlineToPrimary()
$backupState = $rhOnlineProvider.GoOnlineToBackup()
$rhOnlineProvider.GoOffline()
```

### RHDownloadProvider (Redundant HMI)

```powershell
$rhDownloadProvider = $cpuItem.GetService([Siemens.Engineering.Download.RHDownloadProvider])
$result = $rhDownloadProvider.DownloadToPrimary($config, $preDelegate, $postDelegate, $options)
$result = $rhDownloadProvider.DownloadToBackup($config, $preDelegate, $postDelegate, $options)
```

### Station Upload (Read from PLC)

```powershell
$stationUploadType = $asm.GetType('Siemens.Engineering.Upload.StationUploadProvider')
$gsm = $cpuItem.GetType().GetMethod('GetService')
$gm = $gsm.MakeGenericMethod($stationUploadType)
$stationUploadProvider = $gm.Invoke($cpuItem, $null)

$uploadConfigDelegateType = $asm.GetType('Siemens.Engineering.Upload.UploadConfigurationDelegate')
$uploadResult = $stationUploadProvider.StationUpload($configAddress, $null)
Write-Host ('Upload State: ' + $uploadResult.State)  # UploadResultState
Write-Host ('Uploaded Station: ' + $uploadResult.UploadedStation.Name)
```

### CompareToOnline (Offline vs Online Comparison)

```powershell
$realSw = if ($software -is [System.Management.Automation.PSObject]) { $software.BaseObject } else { $software }
$compareResult = $realSw.CompareToOnline()
# Requires PLC to be online - throws exception if offline
# Returns CompareResult with RootElement property
```

### UpdateProgram

```powershell
$realSw = if ($software -is [System.Management.Automation.PSObject]) { $software.BaseObject } else { $software }
$realSw.UpdateProgram()  # Updates program from offline to online
```

### Online Credentials & Authentication

```powershell
$onlineCredType = $asm.GetType('Siemens.Engineering.Online.Configurations.OnlineCredentials')
$userTypeType = $asm.GetType('Siemens.Engineering.Online.Configurations.UserType')

# UserType enum values: None, AnonymousUser, GlobalUser, ProjectUser, SingleSignOnUser, PasswordOnly
```

### Download Configuration Sub-Types

| Type | Purpose |
|---|---|
| `DownloadConfiguration` | Base download config |
| `DownloadCheckConfiguration` | Pre-download checks |
| `DownloadSelectionConfiguration` | Selective download options |
| `ConsistentBlocksDownload` | Consistent block download (enum: ConsistentDownload) |
| `ExpandDownload` | Expand download (enum: NoAction, Download) |
| `DownloadCertificate` | Certificate download |
| `SelectiveDeleteDownload` | Selective delete before download |
| `UserManagementDownload` | User management data download |

### Simulation Workflow (S7-PLCSIM V19)

Since V19 has no dedicated simulation API, follow this workflow. 本机**未安装 PLCSIM Advanced**（原 `Siemens.Simulation.Exe` 路径不存在）；已安装 **S7-PLCSIM V19** 和 **S7-PLCSIM V21**（分别在 `C:\Program Files\Siemens\Automation\PLCSIM_V19\` 与 `...\PLCSIM_V21\`，用与 TIA 同版本的那个）。

1. **Start PLCSIM** manually or via command line（V21 用 `S7PLCSIMV21.exe`）:
   ```powershell
   Start-Process 'C:\Program Files\Siemens\Automation\PLCSIM_V21\S7PLCSIMV21.exe'
   Start-Sleep -Seconds 30  # Wait for PLCSIM to initialize
   ```

2. **Configure PLC connection** in TIA Portal project:
   - Set PROFINET IP address for the virtual PLC
   - Ensure subnet is configured

3. **Go Online** using OnlineProvider:
   ```powershell
   $onlineProvider = GetOnlineProvider -cpuItem $cpuItem
   $state = $onlineProvider.GoOnline()
   if ($state.ToString() -eq 'Online') {
       Write-Host 'Connected to PLCSIM!'
   }
   ```

4. **Download** program to virtual PLC:
   ```powershell
   $downloadProvider = GetDownloadProvider -cpuItem $cpuItem
   $result = $downloadProvider.Download($config, $null, $null, $softwareOption)
   ```

5. **Monitor variables** using Watch Tables (see Watch Table section)

### Alternative: Compile and Verify Offline

When no PLC/PLCSIM is available:

```powershell
$compilableType = $asm.GetType('Siemens.Engineering.Compiler.ICompilable')
$getServiceMethod = $software.GetType().GetMethod('GetService')
$compilableGeneric = $getServiceMethod.MakeGenericMethod($compilableType)
$compilable = $compilableGeneric.Invoke($software, $null)
if ($compilable -is [System.Management.Automation.PSObject]) { $compilable = $compilable.BaseObject }

$result = $compilable.Compile()
if ($result.State -eq 'Error') {
    Write-Host 'Compilation failed - cannot download'
} else {
    Write-Host 'Compilation successful - download manually via TIA Portal GUI'
}
```

## Watch Table / Force Table Operations

Watch and Force tables are accessed through a COMBINED group `$software.WatchAndForceTableGroup` (NOT separate `WatchTableGroup` and `ForceTableGroup`!).

### Access Watch/Force Table Group

```powershell
$wfGroup = $software.WatchAndForceTableGroup
if ($wfGroup -is [System.Management.Automation.PSObject]) { $wfGroup = $wfGroup.BaseObject }
```

### Create Watch Table

```powershell
$watchTable = $wfGroup.WatchTables.Create('MyWatchTable')
```

### Create Force Table

```powershell
$forceTable = $wfGroup.ForceTables.Create('MyForceTable')
```

## Global Library Operations

### Open Global Library and Copy Block to Project

```powershell
$globalLibraries = $tiaPortal.GlobalLibraries
if ($globalLibraries -is [System.Management.Automation.PSObject]) { $globalLibraries = $globalLibraries.BaseObject }

$libPath = 'C:\Program Files\Siemens\Automation\Portal V19\Lib\StandardStep7LibProject\StandardStep7LibProject.al19'  # 本机真实全局库；无 StdBlocks.al19
$fi = New-Object System.IO.FileInfo($libPath)
$openModeType = $asm.GetType('Siemens.Engineering.OpenMode')
$readOnly = [System.Enum]::Parse($openModeType, 'ReadOnly')

$library = $globalLibraries.Open($fi, $readOnly)
if ($library -is [System.Management.Automation.PSObject]) { $library = $library.BaseObject }
```

## Project Archive & Restore

### Archive Project (.zap19)

> V21 用 `.zap21`。`Invoke-TiaArchive` / `Restore-TiaProject` 已按当前连接版本自动选扩展名（`$script:ArchiveExt`），不用手改。

V19 uses `Project.Archive(DirectoryInfo, String, ProjectArchivationMode)` — NOT `ProjectArchiveConfiguration`!

```powershell
$archivationModeType = $asm.GetType('Siemens.Engineering.ProjectArchivationMode')
$compressed = [System.Enum]::Parse($archivationModeType, 'Compressed')

$targetDir = New-Object System.IO.DirectoryInfo('D:\Archive')
$project.Archive($targetDir, 'MyProject', $compressed)   # 产物: D:\Archive\MyProject.zap19
Write-Host 'Project archived successfully'
```

### ProjectArchivationMode Values

- `None` — no compression
- `Compressed` — compressed archive
- `DiscardRestorableData` — discard restorable data
- `DiscardRestorableDataAndCompressed` — discard restorable data and compress

### Restore (Retrieve) Project from Archive

V19 uses `ProjectComposition.Retrieve()` — NOT `Restore()`!

```powershell
$archivePath = 'D:\Archive\MyProject.zap19'
$archiveFi = New-Object System.IO.FileInfo($archivePath)
$restoreDir = New-Object System.IO.DirectoryInfo('D:\Archive')

$project = $tiaPortal.Projects.Retrieve($archiveFi, $restoreDir)
if ($project -is [System.Management.Automation.PSObject]) { $project = $project.BaseObject }
Write-Host ('Project retrieved: ' + $project.Name)
```

### Other ProjectComposition Methods

- `Open(FileInfo path)` — open existing project
- `Open(FileInfo path, UmacDelegate umacDelegate)` — open with authentication
- `OpenWithUpgrade(FileInfo path)` — open and upgrade project version
- `Retrieve(FileInfo sourcePath, DirectoryInfo targetDirectory)` — restore from archive
- `RetrieveWithUpgrade(FileInfo sourcePath, DirectoryInfo targetDirectory)` — restore and upgrade
- `Create(DirectoryInfo targetDirectory, String name)` — create new project

## Block Attribute Reading

### Read Block Properties

```powershell
foreach ($b in $blockGroup.Blocks) {
    $bObj = $b
    if ($bObj -is [System.Management.Automation.PSObject]) { $bObj = $bObj.BaseObject }
    Write-Host ('Name: ' + $bObj.Name + ' Number: ' + $bObj.Number + ' Language: ' + $bObj.ProgrammingLanguage)
}
```

### Read Block Interface Members

```powershell
$block = $blockGroup.Blocks.Find('data')
$interface = $block.Interface
if ($interface -is [System.Management.Automation.PSObject]) { $interface = $interface.BaseObject }

$ns = 'http://www.siemens.com/automation/Openness/SW/Interface/v5'
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($interface.Text))
while ($xmlReader.Read()) {
    if ($xmlReader.NodeType -eq [System.Xml.XmlNodeType]::Element -and $xmlReader.Name -eq 'Member') {
        $name = $xmlReader.GetAttribute('Name')
        $datatype = $xmlReader.GetAttribute('Datatype')
        if ($name) { Write-Host ('  ' + $name + ' : ' + $datatype) }
    }
}
$xmlReader.Close()
```

## Cross-Reference & Dependency Analysis

### Find Block Dependencies

```powershell
$block = $blockGroup.Blocks.Find('Main')
$compilableType = $asm.GetType('Siemens.Engineering.Compiler.ICompilable')
$compilableBlock = $block.GetService($compilableType)

$references = $block.GetReferences()
foreach ($ref in $references) {
    Write-Host ('Reference: ' + $ref)
}
```

### Enumerate All Blocks with Type Info

```powershell
$blocks = @()
foreach ($b in $blockGroup.Blocks) {
    $bObj = $b
    if ($bObj -is [System.Management.Automation.PSObject]) { $bObj = $bObj.BaseObject }
    $blocks += [PSCustomObject]@{
        Name     = $bObj.Name
        Number   = $bObj.Number
        Type     = $bObj.GetType().Name
        Language = $bObj.ProgrammingLanguage
    }
}
$blocks | Format-Table -AutoSize
```

## V21 实测要点（对真实程序集反射枚举验证）

以下是实测环境下（V21 的 Openness 目录，例：`D:\Siemens\Portal V21\PublicAPI\V21\net48\`）每个程序集逐个 `LoadFrom` + `GetExportedTypes()` 枚举得出的结果，不是文档推测。

### 旧工程升级到 V21（自动化，本机实测通过）

`Projects.Open($fi)` 打开旧版本工程会失败，必须用 `Projects.OpenWithUpgrade($fi)` —— SDK 里就是 `Get-TiaProject -ProjectPath <旧工程> -Upgrade`。

实测（V19 工程 → V21，全程自动化，约 31 秒）：

| 步骤 | 实测结果 |
|---|---|
| `Get-TiaProject -ProjectPath 'D:\...\项目1\项目1.ap19' -Upgrade` | 生成 `D:\...\项目1_V21\项目1_V21.ap21`（工程自动改名为 `<原名>_V21`） |
| 设备枚举 | 1 个：`S7-1200 station_1` / `System:Device.S71200`（与手动升级结果一致） |
| `Get-TiaPlcSoftware -DeviceIndex 0` | `PLC_1`（自动回退到全部 DeviceItems 扫描） |
| `Get-TiaBlocks -IncludeDetails` | 13 个块（Main LAD、FC_IO_Map SCL、Alarm SCL、数据块 DB、实例 DB…） |
| `Get-TiaTagTables` | 2 个（默认变量表、IO映射表） |
| `Invoke-TiaCompile` | **State: Success, Errors: 0, Warnings: 0** |
| `Save-TiaProject` → `Close` | 正常 |

**升级的副作用（提前知道，别意外）**：

1. 升级**不改原工程**，而是在**同级目录**新建 `<原名>_V21\` 文件夹，并额外留一份 `<原名>_V21.backup\`。
2. 升级后工程名变成 `<原名>_V21`。
3. TIA Portal 同时只能开一个工程：`Get-TiaProject` 遇到已打开的工程会**先保存再关闭**（SDK 已改成 save-then-close，不会丢未保存的改动）。
4. 附加到运行中的 TIA（`Attach`）后调 `Dispose()` **不会关掉 TIA 进程**，只断开连接 —— 已实测。
5. 旧工程里若**没有任何设备**（空工程），升级会成功但 `设备数 = 0`，`Get-TiaPlcSoftware -DeviceIndex 0` 报 `No device at index 0`。先看 `$script:Project.Devices.Count`，别当成升级失败。

一键复跑：`scripts\verify-e2e.ps1 -ProjectPath <旧工程.ap19>`（日志写到工程同级 `e2e2.log`）

### 程序集分工

| 程序集 | 导出类型数 | 关键类型 |
|---|---|---|
| `Siemens.Engineering.Base.dll` | 1382 | `TiaPortal`、`TiaPortalMode`、`Project`、`ProjectArchivationMode`、`ImportOptions`、`ExportOptions`、`OpenMode`、`Compiler.ICompilable`、`Online.OnlineProvider`、`Download.DownloadProvider`、`HW.Device`、`HW.Features.SoftwareContainer`、`VersionControl.*`、`Umac.*`、`Multiuser.*`、`Security.*` |
| `Siemens.Engineering.Step7.dll` | 228 | `SW.PlcSoftware`、`SW.Blocks.*`（`PlcBlockComposition` / `PlcBlockSystemGroup` / `ProgrammingLanguage`）、`SW.Tags.*`、`SW.Types.*`、`SW.WatchAndForceTables.*`、`SW.TechnologicalObjects.Motion.*` |
| `Siemens.Engineering.WinCCUnified.dll` | 536 | WinCC Unified |
| `Siemens.Engineering.WinCC.dll` | 65 | WinCC Comfort / Advanced |
| `Siemens.Engineering.Safety.dll` / `.SafetyValidation.dll` | 18 / 19 | F-CPU 安全程序 |
| `Siemens.Engineering.Startdrive.dll` | 64 | G120 / S120 驱动 |
| `Siemens.Engineering.TeamcenterGateway.dll` | 20 | Teamcenter |
| `Siemens.Engineering.AddIn.*.dll` + `AddIn.Publisher.exe` | — | V21 新的 Add-In 基类与发布器；**V20 及更早的 Add-In 在 V21 不可用** |

⚠️ **加载顺序**：必须先 `Base`，再 `Step7` / `WinCC`，否则依赖解析失败。

### XML 模式版本（`PublicAPI\V21\Schemas\`）

V19 用的 `v5` / `v1` 命名空间在 V21 **继续有效**，XML 只需把 `<Engineering version>` 改成 `V21`：

| 文件 | 结论 |
|---|---|
| `SW.InterfaceSections_v5.xsd` | Interface `v5`（同 V19） |
| `SW.PlcBlocks.LADFBD_v5.xsd` | FlgNet LAD/FBD `v5`（同 V19） |
| `SW.PlcBlocks.Access_v5.xsd` / `CompileUnitCommon_v5.xsd` | Access / 编译单元公共 |
| `SW.PlcBlocks.SCL_v4.xsd` | SCL 结构文本 |
| `SW.PlcBlocks.STL_v5.xsd` / `Graph_v6.xsd` | STL / GRAPH |
| `SW.TechnologicalObjects_*_v1/v2.xsd` | 工艺对象 |

### 枚举值（与 V19 一致）

`TiaPortalMode`、`ImportOptions`、`ExportOptions`、`ProjectArchivationMode`、`OpenMode`、`MemoryLayout`、`BlockType` 与 V19 **完全相同**。
`ProgrammingLanguage` 新增：`FBD_IEC`、`LAD_IEC`、`SDB`、`S7_PDIAG`、`ProDiag`、`ProDiag_OB`、`RSE`、`F_STL`、`F_LAD`、`F_FBD`、`F_DB`、`F_CALL`、`Motion_DB`、`CEM`、`ST`。

### V21 新增 API（V19 没有）

| 类型 / 成员 | 用途 |
|---|---|
| `Siemens.Engineering.SW.PlcSimulationSettingsProvider` | 仿真设置（V19 完全没有仿真 API） |
| `Siemens.Engineering.SW.VirtualPlcSettingsProvider` | 虚拟 PLC 设置 |
| `PlcBlockComposition.ImportFromDocuments(DirectoryInfo, String, ImportDocumentOptions)` | 从外部文档批量导入 |
| `SWImportOptions` | 导入时覆盖 / 跳过非活动语言（`Import` 新重载） |
| `SW.PlcChecksumProvider` / `ProcessImageProvider` / `FingerprintProvider` | 校验和 / 过程映像 / 指纹 |
| `Siemens.Engineering.HistoryEntry` | 工程变更记录（V21 变更追踪） |
| `SW.Alarm` / `SW.Alarm.TextLists` / `SW.OpcUa` / `SW.Units` / `SW.Supervision` 命名空间 | 报警文本、OPC UA、工艺单元、监视 |
| `PlcSoftware.PlcAlarmTextlistGroup` / `.TechnologicalObjectGroup`、`PlcBlockSystemGroup.SystemBlockGroups` | 新增属性 |

### 文档提到、但本机 V21 未见的改动

Siemens 的 Openness V21 迁移文档称 `SW.TechnologicalObjects.Motion.AxisEncoderHardwareConnectionInterface` 改名为 `...SDRInterface`、`TorqueHardwareConnectionInterface` 改名为 `TorqueHardwareConnectionSDRInterface`。
对本机 `Siemens.Engineering.Step7.dll` 反射枚举 **找不到任何 `*SDR*` 类型，旧名仍在**。该改名可能由后续 Update 引入 —— 改这类代码前先用 `Get-TiaType` 试一下，别照文档直接改。

## V21 逐项实测报告（建工程 / 设备 / 程序 / 仿真）

对 V21 做的全流程自动化实测，28 项里 22 项通过。下面按「能用的 / V21 已破坏的 / 无法自动化的」三档列清楚。

### 实测可用的完整链路

新建工程 → 建 CPU → 标签表 → FC(LAD/SCL) → FB(LAD/SCL) → InstanceDB → GlobalDB → 编译 → 导出 → 删块 → 监视表 → 归档 → 恢复，全部成功：

```
New-TiaProject   -> D:\...\OpennessFull3\OpennessFull3.ap21
New-TiaDevice    -> 6ES7 215-1AG40-0XB0/V4.6 (CPU 1215C)
标签/FC/FB/DB    -> 7 个块 (Main LAD, FC_Lad LAD, FC_Scl SCL, FB_Motor LAD, FB_Scl SCL, FB_Motor_DB, Data_Block)
Invoke-TiaCompile            -> Success, Errors=0
Invoke-TiaCompile -BlockName -> Success（单块）
Get-TiaBlockInterface        -> In1:Bool / Out1:Bool / Ret_Val:Void
Invoke-TiaArchive            -> D:\...\arch\Full3
Restore-TiaProject           -> 恢复后 7 个块都在
```

### V21 的破坏性变更（改代码时必看）

| 变更 | 现象 | 替代做法 |
|---|---|---|
| `PlcBlockComposition.CreateFB` 只支持 ProDiag | `The action "Create block" only supports the programming language 'ProDiag'.` | 走 XML 导入 —— SDK 已加 `New-TiaFbXml`，`New-TiaFB` 也改成生成 XML 再导入 |
| FC/FB/OB 都没有 `GetReferences` | `FC 上不包含名为 GetReferences 的方法` | V21 用 `Siemens.Engineering.CrossReference` 命名空间；SDK 的 `Get-TiaBlockReferences` 会明确报错 |
| `PlcBlock.Interface` 属性消失 | `$block.Interface` 为 `$null` | 导出 XML 再解析 Member（SDK 的 `Get-TiaBlockInterface` 已改成这条路） |
| `PlcForceTableComposition` 没有 `Create` | `找不到 Create 的重载，参数计数为 1` | 只能 `Import(FileInfo, ImportOptions)` 或界面手工建（监视表 `Create(String)` 仍在） |
| 单块编译不能用位置参数反射调 `GetService` | `找不到 GetService 的重载，参数计数为 1` | 必须 `MakeGenericMethod`（SDK 已修） |
| `Project.Archive` 要求先保存 | `Operation is not possible while project has unsaved changes` | 归档前先 `Save()`（SDK 已自动做） |
| `Archive` 产物**不带扩展名** | 产出的是 `...\arch\Full3`（内容其实是 zip），V19 是 `.zap19` | `Invoke-TiaArchive` 返回真实路径；`Restore-TiaProject` 两种都兼容 |
| `Download` 两个重载都要求非空 delegate | `找不到 Download 的重载，参数计数为 4` / `preDownloadConfigurationDelegate may not be null` | PowerShell 造不出 `DownloadConfigurationDelegate`；下载这步建议留在 TIA 界面做 |
| SCL 必须带 CompileUnit | `Language of 'SCL' have to have at least one compile unit.` | 语言是 SCL/ST 时自动补一个 CompileUnit（SDK 已做） |
| CompileUnit 的 xmlns 位置 | 挂 `NetworkSource` 上会被拒：`Attribute 'NetworkSource' does not support xml attribute 'xmlns'` | 必须挂在 `<StructuredText>` 上（SDK 已按此生成） |

### 仿真：实测能到哪一步

`Siemens.Engineering.Connection` 这套对象在 V21 是开放的，**能把在线目标网卡切到 PLCSIM**，实测成功：

```powershell
Set-TiaOnlineTargetInterface -PcInterfacePattern 'PLCSIM'
#   -> 命中 'Siemens PLCSIM Virtual Ethernet Adapter'，ApplyConfiguration=True，IsConfigured=True
```

- 本机可用 PC 接口（实测 5 个）：`Realtek PCIe GbE`、**`Siemens PLCSIM Virtual Ethernet Adapter`**、`TAP-Windows Adapter V9`、`Wintun Userspace Tunnel`、`Intel(R) Wi-Fi 6E AX211`。
- ⚠️ `ConfigurationTargetInterface` 对象本身只叫 `1 X1`，**不能按它的名字匹配**，要按 `ConfigurationMode.PcInterfaces` 里的网卡名匹配。（另：筛选属性时按**属性类型** `*Composition` 过滤，不是按属性名。）
- ⚠️ **Openness 没有「启动仿真」接口**。V21 的 `PlcSimulationSettingsProvider` / `VirtualPlcSettingsProvider` 只暴露 `IsSimulationDuringBlockCompilationEnabled` 这类编译期开关，不是启动仿真。
- 因此 `GoOnline` 的实测结果是：切到 PLCSIM 网卡后仍报
  `Connection could not be established. The connection partner is not responding.`
  —— 因为 PLCSIM 里还没有**活动的虚拟 PLC 实例**。实例要先在 PLCSIM 界面里建（或先在 TIA 界面点一次「启动仿真」）。
- 结论：**Openness 能配好通路，但启不了仿真**。纯脚本要跑通仿真，得先在外部把 PLCSIM 实例拉起来。

### 顺带修正：扩展模块的写法（原文档是错的）

原 SKILL 里这段从未真正验证过 —— `DeviceItemComposition` **在 V19 和 V21 都没有 `CreateWithItem`**：

```powershell
# ✗ 错误 —— 会报 "DeviceItemImpl 不包含名为 CreateWithItem 的方法"
# $diModule = $cpuItem.DeviceItems.CreateWithItem('OrderNumber:6ES7 221-1BH32-0XB0/V2.0', 'DI_1', 'DI_1')
```

实测结论：`CreateWithItem` **只存在于 `DeviceComposition` 上**（即 `$project.Devices.CreateWithItem(...)`，用来新建带 CPU 的站点）。
给已有站点加扩展模块，Openness 侧只有 `DeviceItemComposition.CreateFrom(MasterCopy)` 一条路（需要库主副本），否则就在 TIA 界面里加。

**另注**：`Get-TiaBlock -Name xxx` 在块不存在时是**抛异常**而不是返回 `$null`，写脚本时要用 try/catch。

## V19 API Type Quick Reference

These are the CORRECT type names verified against the actual V19 DLL. Do NOT use incorrect names from older documentation!

| Correct Type Name | Wrong Name (DO NOT USE) | Purpose |
|---|---|---|
| `Siemens.Engineering.TiaPortalMode` | ~~TiaPortalStartMode~~ | Start mode enum |
| `Siemens.Engineering.SW.Blocks.ProgrammingLanguage` | ~~PlcProgrammingLanguage~~ | LAD, SCL, FBD, DB, etc. |
| `Siemens.Engineering.SW.Blocks.BlockType` | ~~PlcBlockType~~ | FB, UDT, etc. (NOT used for Create) |
| `Siemens.Engineering.SW.Blocks.MemoryLayout` | — | Standard, Optimized |
| `Siemens.Engineering.ImportOptions` | — | Override, etc. |
| `Siemens.Engineering.ExportOptions` | — | WithDefaults, etc. |
| `Siemens.Engineering.OpenMode` | ~~Library.OpenMode~~ | ReadOnly, ReadWrite |
| `Siemens.Engineering.ProjectArchivationMode` | ~~ProjectArchiveConfiguration~~ | None, Compressed, etc. |
| `Siemens.Engineering.Compiler.ICompilable` | — | Compilation service |
| `Siemens.Engineering.HW.Features.SoftwareContainer` | — | Find PlcSoftware |
| `Siemens.Engineering.Online.OnlineProvider` | ~~PlcOnlineProvider~~ | Go online/offline |
| `Siemens.Engineering.Online.OnlineState` | — | Online state enum |
| `Siemens.Engineering.Download.DownloadProvider` | ~~SW.Online.DownloadConfiguration~~ | Download to PLC |
| `Siemens.Engineering.Download.DownloadOptions` | ~~SW.Online.DownloadOptions~~ | Download options enum |
| `Siemens.Engineering.Download.DownloadResult` | — | Download result |
| `Siemens.Engineering.Download.DownloadResultState` | — | Download result state enum |
| `Siemens.Engineering.Upload.StationUploadProvider` | — | Station upload from PLC |
| `Siemens.Engineering.Upload.UploadResult` | — | Upload result |
| `Siemens.Engineering.Upload.UploadResultState` | — | Upload result state enum |
| `Siemens.Engineering.Connection.ConnectionConfiguration` | — | Connection settings |

### Types That Do NOT Exist in V19 Public API

- ~~`PlcOnlineProvider`~~ — Use `Siemens.Engineering.Online.OnlineProvider` instead
- ~~`SW.Online.PlcOnlineProvider`~~ — Use `Siemens.Engineering.Online.OnlineProvider` instead
- ~~`SW.Online.DownloadConfiguration`~~ — Use `Siemens.Engineering.Download.DownloadProvider` instead
- ~~`SW.Online.DownloadOptions`~~ — Use `Siemens.Engineering.Download.DownloadOptions` instead
- ~~`SimulationFeature`~~ / ~~`PlcSimulation`~~ — No simulation API in V19
- ~~`PlcSimOnlineProvider`~~ — Does not exist
- ~~`ProjectArchiveConfiguration`~~ — Use `ProjectArchivationMode` instead
- ~~`EngineeringInvalidOperationException`~~ — Does not exist
- ~~`Library.OpenMode`~~ — Use `Siemens.Engineering.OpenMode`

### PlcSoftware Property Names

| Property | Type | Purpose |
|---|---|---|
| `BlockGroup` | PlcBlockSystemGroup | Contains `Blocks` and `Groups` |
| `TagTableGroup` | PlcTagTableSystemGroup | Contains `TagTables` |
| `WatchAndForceTableGroup` | PlcWatchAndForceTableSystemGroup | Contains `WatchTables` and `ForceTables` |
| `TypeGroup` | PlcTypeSystemGroup | UDT/plc types |
| `ExternalSourceGroup` | PlcExternalSourceSystemGroup | External sources |

### PlcBlockComposition Methods

| Method | Signature | Purpose |
|---|---|---|
| `CreateFB` | `(String name, Boolean isAutoNumbered, Int32 number, ProgrammingLanguage lang)` | Create FB block |
| `CreateInstanceDB` | `(String name, Boolean isAutoNumbered, Int32 number, String instanceOfName)` | Create instance DB |
| `CreateFrom` | `(MasterCopy source)` | Create from library master copy |
| `Import` | `(FileInfo, ImportOptions)` | Import block from XML |
| `Find` | `(String name)` | Find block by name |


## SCL StructuredText XML Format (V19)

For TIA Portal V19, SCL code uses `StructuredText` (NOT `STSource`) with namespace `http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v1`.

### Basic Structure

```xml
<StructuredText xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v1" UId="10">
  <Text UId="100">#Deviation := #Setpoint - #ProcessValue;</Text>
  <Text UId="101">#PropTerm := #Gain * #Deviation;</Text>
</StructuredText>
```

- Each `<Text>` element = one line of SCL code
- Supports assignments, IF/THEN/END_IF, CASE/END_CASE
- Local variables use `#` prefix
- Global DBs use `"DBName".VariableName` syntax
- Function calls like `REAL_TO_UINT(expr)` are supported inline
- **Cannot** have multiple CompileUnits (SCL = single program section)

### Important Notes

- SCL requires at least one CompileUnit with code
- Output parameter warning: initialize `#OutputValue := 0.0;` at the top to avoid "cannot be initialized" warning
- Add `StartValue` elements for default values
- For REAL to UINT conversion, output type must be `UInt` not `Word`


## LAD FlgNet Instruction XML Format (V19)

LAD uses `FlgNet` with namespace `http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5`.
Each network = one `CompileUnit`. Multiple CompileUnits = multiple networks.

### Available FlgNet Instruction Parts

| Part Name | Purpose | Needs Card | Needs SrcType | Connections |
|-----------|---------|-----------|---------------|-------------|
| `Contact` | Normally open contact | No | No | in(power), operand(var), out(power) |
| `NContact` | Normally closed contact | No | No | in, operand, out |
| `Coil` | Normal coil | No | No | in, operand |
| `RCoil` | Reset coil | No | No | in, operand |
| `SCoil` | Set coil | No | No | in, operand |
| `PBox` | Positive edge | No | No | in(power), bit(signal), out(power) |
| `Move` | MOVE | **Yes** (Card=1) | No | en, in(data), out1(data) |
| `Sub` | Subtraction (A-B) | **No** | AutomaticTyped | en, in1, in2, out |
| `Add` | Addition (A+B) | **Yes** (Card=2) | AutomaticTyped | en, in1, in2, out |
| `Mul` | Multiplication (A*B) | **Yes** (Card=2) | AutomaticTyped | en, in1, in2, out |
| `Calc` | CALCULATE | **Yes** (Card=N) | **TemplateValue SrcType** | en, in1..inN, out, eno |
| `Eq` | Equals | No | TemplateValue SrcType | pre(power), in1, in2, out(power) |
| `Gt` | Greater than | No | TemplateValue SrcType | pre(power), in1, in2, out(power) |
| `Lt` | Less than | No | TemplateValue SrcType | pre(power), in1, in2, out(power) |
| `Ge` | Greater or equal | No | TemplateValue SrcType | pre(power), in1, in2, out(power) |
| `Ne` | Not equal | No | TemplateValue SrcType | pre(power), in1, in2, out(power) |
| `TON` | Timer on delay | — | — | IN, PT, Q, ET |

### Critical Wiring Rules

| Instruction | Power In | Data In | Data Out |
|-------------|----------|---------|----------|
| Contact | `in` | `operand` | power `out` |
| Coil | `in` | `operand` | — |
| Move | `en` | `in` | `out1` |
| Sub/Add/Mul | `en` | `in1`, `in2` | `out` |
| Calc | `en` | `in1`..`inN` | `out` |
| Eq/Gt/Lt/Ge/Ne | **`pre`** (not `in`!) | `in1`, `in2` | power `out` |
| PBox | `in` | `bit` | power `out` |

### Sub (NO Card needed)

```xml
<Part Name="Sub" UId="1104" DisabledENO="true">
  <AutomaticTyped Name="SrcType" />
</Part>
```

### Mul (Card=2 required)

```xml
<Part Name="Mul" UId="1204" DisabledENO="true">
  <TemplateValue Name="Card" Type="Cardinality">2</TemplateValue>
  <AutomaticTyped Name="SrcType" />
</Part>
```

### Add (Card=2)

```xml
<Part Name="Add" UId="39" DisabledENO="true">
  <TemplateValue Name="Card" Type="Cardinality">2</TemplateValue>
  <AutomaticTyped Name="SrcType" />
</Part>
```

### Calc (uses TemplateValue SrcType, NOT AutomaticTyped)

```xml
<Part Name="Calc" UId="1308" DisabledENO="true">
  <Equation>(IN1*IN2*IN3)/(IN4*IN6)+IN5</Equation>
  <TemplateValue Name="Card" Type="Cardinality">6</TemplateValue>
  <TemplateValue Name="SrcType" Type="Type">Real</TemplateValue>
</Part>
```

### Gt/Lt (use `pre` for power in, NOT `in`)

```xml
<Part Name="Gt" UId="1404">
  <TemplateValue Name="SrcType" Type="Type">Real</TemplateValue>
</Part>
```

### Move

```xml
<Part Name="Move" UId="1406" DisabledENO="true">
  <TemplateValue Name="Card" Type="Cardinality">1</TemplateValue>
</Part>
```

### Constants in Calc Equations

CRITICAL: Calc equations can only use `IN1`, `IN2`, etc. as operands.
Do NOT embed literal numbers in the equation text:

Wrong:
```xml
<Equation>(IN1*IN2*IN3)/(IN4*1000.0)+IN5</Equation>
```

Correct (1000.0 passed as IN6 input):
```xml
<Equation>(IN1*IN2*IN3)/(IN4*IN6)+IN5</Equation>
```

Define constants as Access elements and wire them as inputs:
```xml
<Access Scope="LiteralConstant" UId="1308">
  <Constant>
    <ConstantType>Real</ConstantType>
    <ConstantValue>1000.0</ConstantValue>
  </Constant>
</Access>
```

Then wire:
```xml
<Wire UId="1310"><IdentCon UId="1308"/><NameCon UId="1309" Name="in6"/></Wire>
```

### Adding Comments & Titles to LAD Networks

Insert between `</AttributeList>` and `</SW.Blocks.CompileUnit>`:

```xml
<ObjectList>
  <MultilingualText ID="500A" CompositionName="Comment">
    <ObjectList>
      <MultilingualTextItem ID="500B" CompositionName="Items">
        <AttributeList>
          <Culture>zh-CN</Culture>
          <Text>Comment text</Text>
        </AttributeList>
      </MultilingualTextItem>
    </ObjectList>
  </MultilingualText>
  <MultilingualText ID="500C" CompositionName="Title">
    <ObjectList>
      <MultilingualTextItem ID="500D" CompositionName="Items">
        <AttributeList>
          <Culture>zh-CN</Culture>
          <Text>Network title</Text>
        </AttributeList>
      </MultilingualTextItem>
    </ObjectList>
  </MultilingualText>
</ObjectList>
```

### Wiring Pattern Reference

For each instruction, wire connections follow this pattern:
- Power rail to enable: `<Wire UId="W1"><Powerrail/><NameCon UId="PartId" Name="en"/></Wire>` (use `"pre"` for comparison instructions)
- Variable to input: `<Wire UId="W2"><IdentCon UId="AccessUid"/><NameCon UId="PartId" Name="in1"/></Wire>`
- Result to variable: `<Wire UId="W3"><NameCon UId="PartId" Name="out"/><IdentCon UId="ResultUid"/></Wire>`


## DB Block Number & Offset Fix

### S7-1200 Restrictions

- DB number **0 is invalid** for S7-1200 CPUs. Compile fails with:
  ```
  编号：块 data DB 的编号 0 无效。
  ```
- All DBs must have number >= 1
- Fix by setting AutoNumber=false, changing Number, then AutoNumber=true

### Fixing Offset Issues

```powershell
# Set AutoNumber = true (forces TIA to recalculate offsets from 0)
$db.AutoNumber = $true

# If number is 0, change it first
$db.AutoNumber = $false
$db.Number = 1006
$db.AutoNumber = $true

# Compile
$compType = $asm.GetType('Siemens.Engineering.Compiler.ICompilable')
$gsm2 = $db.GetType().GetMethod('GetService').MakeGenericMethod($compType)
$comp = $gsm2.Invoke($db, $null)
$result = $comp.Compile()
```

### Rebuilding Inconsistent DB (IsConsistent=False)

```powershell
# 1. Export a good version of the DB
# 2. Modify XML (change Name, AutoNumber=true, Number=0)
# 3. Delete old DB
$db.Delete()
# 4. Import fixed XML
$importOpts = [System.Enum]::Parse($asm.GetType('Siemens.Engineering.ImportOptions'), 'Override')
$bg.Blocks.Import($importFi, $importOpts)
# 5. Fix number if assigned 0
$newDb.AutoNumber = $false
$newDb.Number = <valid_number>
$newDb.AutoNumber = $true
# 6. Compile
```


## InstanceDB & FB Calling

### Creating Instance DB

```powershell
$idb = $bg.Blocks.CreateInstanceDB("MyInstance", $true, 0, "MyFB")
# Fix number if auto-assigned 0
$idb.AutoNumber = $false
$idb.Number = 61
$idb.AutoNumber = $true
```

### Calling FB from SCL via InstanceDB

Wrong (FB code won't execute):
```scl
"MyInstance".Setpoint := "TestData".SP;
"MyInstance".ProcessValue := "TestData".PV;
```

Correct (must explicitly call the FB):
```scl
"MyInstance".Setpoint := "TestData".SP;
"MyInstance".ProcessValue := "TestData".PV;
"MyInstance"();  // Executes FB code!
```

### FC vs FB for Test Logic

- **FC** (Function): No instance data, access DBs via `"DBName".Variable`
- **FB** (Function Block): Has instance data, supports multi-instance
- For test harnesses, FC is simpler


## Protection Password for Simulation

When simulating, TIA Portal may require:
- "密码不允许为空"
- "该 PLC 中未组态保护机密 PLC 组态数据的密码"

Fix: Set PLC password manually:
1. Right-click PLC_1 → Properties → Protection tab
2. Check "Protection of confidential PLC configuration data"
3. Enter a password (e.g. 1234)
4. Recompile

One-time setting for S7-1200 safety requirements.
## Performance Best Practices

| Scenario | Problem | Optimization |
|----------|---------|-------------|
| Batch tag creation | Each `Tags.Create()` triggers IPC | Use XML batch import (single IPC) |
| Frequent GetAttribute | Repeated IPC overhead | Cache results to local variables |
| Save timing | Save() after each change doubles IO | Call Save() once after all operations |
| UI mode overhead | WithUserInterface refreshes UI | Use WithoutUserInterface for batch tasks |
| Parallel processing | Single thread is slow for multi-project | Use multiple processes (NOT threads) per project |

## Exception Handling

```powershell
try {
    # Openness operations
} catch [Siemens.Engineering.EngineeringNotSupportedException] {
    Write-Host ('API not supported: ' + $_.Exception.Message)
} catch [Siemens.Engineering.EngineeringTargetInvocationException] {
    Write-Host ('TIA internal error: ' + $_.Exception.InnerException.Message)
} catch [Siemens.Engineering.EngineeringException] {
    Write-Host ('Openness error: ' + $_.Exception.Message)
}
```

### Key Exception Types

- `EngineeringNotSupportedException` — API not available in this TIA version
- `EngineeringTargetInvocationException` — TIA Portal internal error (check InnerException)
- `EngineeringSecurityException` — Permission denied (check user group membership)
- `EngineeringException` — Base exception type for all Openness errors

Note: `EngineeringInvalidOperationException` does NOT exist in V19's public API.


## LAD FlgNet XML Generation Patterns

### Proven Patterns (These Work)

#### 1. Simple Contact → Coil

```xml
<Parts>
  <Access Scope="LocalVariable" UId="1"><Symbol><Component Name="src"/></Symbol></Access>
  <Part Name="Contact" UId="2"/>
  <Part Name="Coil" UId="3"/>
  <Access Scope="LocalVariable" UId="4"><Symbol><Component Name="dst"/></Symbol></Access>
</Parts>
<Wires>
  <Wire UId="100"><Powerrail/><NameCon UId="2" Name="in"/></Wire>
  <Wire UId="101"><IdentCon UId="1"/><NameCon UId="2" Name="operand"/></Wire>
  <Wire UId="102"><NameCon UId="2" Name="out"/><NameCon UId="3" Name="in"/></Wire>
  <Wire UId="103"><IdentCon UId="4"/><NameCon UId="3" Name="operand"/></Wire>
</Wires>
```

#### 2. Series Contacts → Coil

Wire pattern: Powerrail→C1.in, C1.out→C2.in, C2.out→Coil.in. Each contact needs IdentCon for its Access.

#### 3. Self-Holding Latch (O-Block, Card=2)

```xml
<Parts>
  <!-- Top branch -->
  <Access UId="1"><Symbol><Component Name="trig1"/></Symbol></Access>
  <Part Name="Contact" UId="2"/>
  <!-- Bottom branch (self-hold) -->
  <Access UId="3"><Symbol><Component Name="selfHold"/></Symbol></Access>
  <Part Name="Contact" UId="4"/>
  <!-- O block -->
  <Part Name="O" UId="5"><TemplateValue Name="Card" Type="Cardinality">2</TemplateValue></Part>
  <Part Name="Coil" UId="6"/>
  <Access UId="7"><Symbol><Component Name="dst"/></Symbol></Access>
</Parts>
<Wires>
  <Wire UId="100"><Powerrail/><NameCon UId="2" Name="in"/><NameCon UId="4" Name="in"/></Wire>
  <Wire UId="101"><IdentCon UId="1"/><NameCon UId="2" Name="operand"/></Wire>
  <Wire UId="102"><IdentCon UId="3"/><NameCon UId="4" Name="operand"/></Wire>
  <Wire UId="103"><NameCon UId="2" Name="out"/><NameCon UId="5" Name="in1"/></Wire>
  <Wire UId="104"><NameCon UId="4" Name="out"/><NameCon UId="5" Name="in2"/></Wire>
  <Wire UId="105"><NameCon UId="5" Name="out"/><NameCon UId="6" Name="in"/></Wire>
  <Wire UId="106"><IdentCon UId="7"/><NameCon UId="6" Name="operand"/></Wire>
</Wires>
```

### Patterns That DON'T Work (Missing Undocumented TemplateValue)

- **EQ block**: Requires `<TemplateValue Name="SrcType" Type="type">` — format unknown
- **MOVE block**: Requires SrcType/DstType TemplateValue — format unknown
- **TON timer block**: Requires IN/PT/Q TemplateValue — format unknown
- **R_TRIG/F_TRIG**: Cannot be instantiated as FlgNet parts

**Workaround**: For state machines needing EQ/MOVE/timers, use SCL (it is standard TIA language, not a hack). LAD is recommended for simple contact/coil/O-block logic only.

### UId Rules

- UIds MUST be unique within a single CompileUnit (Parts + Wires combined)
- UIds CAN repeat across different CompileUnits
- Wire UIds should start from 100+ to avoid collision with Parts UIds (typically 1-20)
- Every Access element must have at least one IdentCon wire connecting it to a Contact/Coil operand
- Each CompileUnit needs exactly ONE `<Wires>` section

### FB Call in LAD (Proven Format)

```xml
<Parts>
  <Access Scope="GlobalVariable" UId="2"><Symbol><Component Name="InputTag"/></Symbol></Access>
  <!-- ... more input Access elements ... -->
  <Call UId="30">
    <CallInfo Name="FB_Name" BlockType="FB">
      <Instance Scope="GlobalVariable" UId="31"><Component Name="DB_Name"/></Instance>
      <Parameter Name="PinName" Section="Input" Type="Bool"/>
      <!-- Only declare the 10 Bool input params you wire; leave Real/Time/Enable params out -->
      <Parameter Name="OutPin" Section="Output" Type="Bool"/>
    </CallInfo>
  </Call>
  <Access Scope="GlobalVariable" UId="50"><Symbol><Component Name="OutputTag"/></Symbol></Access>
</Parts>
<Wires>
  <Wire UId="70"><Powerrail/><NameCon UId="30" Name="en"/></Wire>
  <!-- Input: IdentCon → Call -->
  <Wire UId="71"><IdentCon UId="2"/><NameCon UId="30" Name="PinName"/></Wire>
  <!-- Output: Call → IdentCon -->
  <Wire UId="90"><NameCon UId="30" Name="OutPin"/><IdentCon UId="50"/></Wire>
</Wires>
```

**Critical**: Only wire Bool Input params. Real/Time/Enable params must use the FB's default `<StartValue>` (defined in FB interface). If you include them in CallInfo without wiring, TIA throws "connection not connected" error.

### Empty LAD FB Creation

SDK's `CreateFB` only supports ProDiag, not LAD. To create a LAD FB:
1. Generate XML with full interface but NO CompileUnits (empty `<ObjectList>`)
2. Set `<ProgrammingLanguage>LAD</ProgrammingLanguage>`
3. Import via SDK
4. Add LAD networks via XML modify + re-import

### Tag Management

- **NEVER create duplicate tag tables** with same-address different-name tags
- Use existing tag names from the project (check with `Get-TiaTagTables` first)
- Tag names should be meaningful: `B1_LVL_H` not `I0_0`
- Input FB pins use existing DI tags; Output FB pins use existing DO tags
- Add new tags sparingly (only when no existing tag covers the address)
- Address-ambiguous warnings come from duplicate tags at same address
