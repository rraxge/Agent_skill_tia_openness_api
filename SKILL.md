---
name: "tia-openness-api"
description: "TIA Portal Openness API automation skill. Invoke when user asks to automate TIA Portal operations: create/open projects, import/export PLC blocks, manage tag tables, write LAD/SCL XML, or debug Openness API errors."
---

# TIA Portal Openness API Automation

This skill provides comprehensive guidance for automating Siemens TIA Portal V19 operations via the Openness API in PowerShell.

## SDK Module

Core module: `.trae/skills/tia-openness-api/TiaPortalSDK.ps1`

Load with dot-source: `. "D:\新建文件夹\项目test\123\.trae\skills\tia-openness-api\TiaPortalSDK.ps1"`

### Available Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `Connect-TiaPortal` | Connect to TIA Portal (attach or start new) | `-StartIfNotFound -WithUI` |
| `Disconnect-TiaPortal` | Dispose TIA Portal connection | (none) |
| `Get-TiaProject` | Get or open a project | `-ProjectPath "D:\path\project.ap19"` |
| `Save-TiaProject` | Save current project | (none) |
| `New-TiaProject` | Create new project | `-Directory "D:\path" -Name "ProjectName"` |
| `Get-TiaPlcSoftware` | Find PLC software in device | `-DeviceIndex 0` |
| `Get-TiaDevice` | Get device by index | `-DeviceIndex 0` |
| `Get-TiaDeviceItems` | Get device item details | `-DeviceIndex 0` |
| `Get-TiaBlocks` | List all blocks | `-IncludeDetails` |
| `Get-TiaBlock` | Find a specific block | `-Name "Main"` |
| `Export-TiaBlock` | Export block to XML | `-Name "Main" -OutputDir "export" -WithDefaults` |
| `Import-TiaBlock` | Import block from XML | `-XmlPath "block.xml" -Override` |
| `New-TiaFB` | Create FB block | `-Name "MyFB" -ProgrammingLanguage "LAD"` |
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
. "D:\新建文件夹\项目test\123\.trae\skills\tia-openness-api\TiaPortalSDK.ps1"

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

- DLL: `C:\Program Files\Siemens\Automation\Portal V19\PublicAPI\V19\Siemens.Engineering.dll`
- Load: `[System.Reflection.Assembly]::LoadFrom($dllPath)`
- Enum type: `TiaPortalMode` (NOT `TiaPortalStartMode`!)
- Prefer Attach to existing process; start new only if no process found
- PSObject wrapping: always unwrap with `.BaseObject`

```powershell
$dllPath = 'C:\Program Files\Siemens\Automation\Portal V19\PublicAPI\V19\Siemens.Engineering.dll'
$asm = [System.Reflection.Assembly]::LoadFrom($dllPath)

$modeType = $asm.GetType('Siemens.Engineering.TiaPortalMode')
$getProcessesMethod = $asm.GetType('Siemens.Engineering.TiaPortal').GetMethod('GetProcesses', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
$processes = $getProcessesMethod.Invoke($null, $null)

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

- Scripts with Chinese must use UTF-8 BOM encoding
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
    'OrderNumber:6ES7 221-1BH32-0XB0/V6.0',
    'DI_Module',
    'DI_Module'
)
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

### Simulation Workflow (PLCSIM Advanced)

Since V19 has no dedicated simulation API, follow this workflow:

1. **Start PLCSIM Advanced** manually or via command line:
   ```powershell
   Start-Process 'C:\Program Files\Siemens\Automation\PLCSIM Advanced\bin\Siemens.Simulation.Exe'
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

$libPath = 'C:\Libraries\StdBlocks.al19'
$fi = New-Object System.IO.FileInfo($libPath)
$openModeType = $asm.GetType('Siemens.Engineering.OpenMode')
$readOnly = [System.Enum]::Parse($openModeType, 'ReadOnly')

$library = $globalLibraries.Open($fi, $readOnly)
if ($library -is [System.Management.Automation.PSObject]) { $library = $library.BaseObject }
```

## Project Archive & Restore

### Archive Project (.zap19)

V19 uses `Project.Archive(DirectoryInfo, String, ProjectArchivationMode)` — NOT `ProjectArchiveConfiguration`!

```powershell
$archivationModeType = $asm.GetType('Siemens.Engineering.ProjectArchivationMode')
$compressed = [System.Enum]::Parse($archivationModeType, 'Compressed')

$targetDir = New-Object System.IO.DirectoryInfo('D:\Archives')
$project.Archive($targetDir, 'SeedBox_Control', $compressed)
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
$archivePath = 'D:\Archives\SeedBox_Control.zap19'
$archiveFi = New-Object System.IO.FileInfo($archivePath)
$restoreDir = New-Object System.IO.DirectoryInfo('D:\RestoredProjects')

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
