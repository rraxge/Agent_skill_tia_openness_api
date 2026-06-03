$script:DllPath = 'C:\Program Files\Siemens\Automation\Portal V19\PublicAPI\V19\Siemens.Engineering.dll'
$script:Asm = $null
$script:TiaPortal = $null
$script:Project = $null
$script:Software = $null

function Unwrap-PSObject {
    param($obj)
    if ($obj -is [System.Management.Automation.PSObject]) { return $obj.BaseObject }
    return $obj
}

function Connect-TiaPortal {
    param(
        [switch]$StartIfNotFound,
        [switch]$WithUI
    )
    if (-not (Test-Path $script:DllPath)) {
        throw "Siemens.Engineering.dll not found at $($script:DllPath)"
    }
    $script:Asm = [System.Reflection.Assembly]::LoadFrom($script:DllPath)
    $modeType = $script:Asm.GetType('Siemens.Engineering.TiaPortalMode')
    $getProcessesMethod = $script:Asm.GetType('Siemens.Engineering.TiaPortal').GetMethod('GetProcesses', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
    $processes = $getProcessesMethod.Invoke($null, $null)
    $script:TiaPortal = $null
    if ($processes.Count -gt 0) {
        $process = Unwrap-PSObject $processes[0]
        $attachMethod = $process.GetType().GetMethod('Attach')
        $script:TiaPortal = Unwrap-PSObject ($attachMethod.Invoke($process, $null))
        Write-Host "Attached to existing TIA Portal process" -ForegroundColor Green
    } elseif ($StartIfNotFound) {
        $modeValue = if ($WithUI) { 'WithUserInterface' } else { 'WithoutUserInterface' }
        $mode = [System.Enum]::Parse($modeType, $modeValue)
        $ctor = $script:Asm.GetType('Siemens.Engineering.TiaPortal').GetConstructor(@($modeType))
        $script:TiaPortal = Unwrap-PSObject ($ctor.Invoke(@($mode)))
        Start-Sleep -Seconds 15
        Write-Host "Started new TIA Portal ($modeValue)" -ForegroundColor Green
    } else {
        throw "No TIA Portal process found. Use -StartIfNotFound to start a new instance."
    }
    $script:Project = $null
    $script:Software = $null
    return $script:TiaPortal
}

function Disconnect-TiaPortal {
    if ($script:TiaPortal) {
        $script:TiaPortal.Dispose()
        $script:TiaPortal = $null
        $script:Project = $null
        $script:Software = $null
        Write-Host "TIA Portal disposed" -ForegroundColor Green
    }
}

function Get-TiaProject {
    param(
        [string]$ProjectPath
    )
    if (-not $script:TiaPortal) { throw "Not connected. Call Connect-TiaPortal first." }
    
    # Check if there's already an open project
    if ($script:TiaPortal.Projects.Count -gt 0) {
        $existing = $script:TiaPortal.Projects[0]
        if ($existing -is [System.Management.Automation.PSObject]) { $existing = $existing.BaseObject }
        if (-not $ProjectPath -or $existing.Path -eq (Resolve-Path $ProjectPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path)) {
            $script:Project = $existing
            Write-Host "Using already open project: $($script:Project.Path)" -ForegroundColor Cyan
            return $script:Project
        }
        # Close the existing project first
        Write-Host "Closing current project: $($existing.Name)..." -ForegroundColor Yellow
        $existing.Close()
        Start-Sleep -Seconds 3
    }
    
    if ($ProjectPath) {
        $fi = New-Object System.IO.FileInfo((Resolve-Path $ProjectPath).Path)
        Write-Host "Opening project: $ProjectPath ..." -ForegroundColor Yellow
        $script:Project = $script:TiaPortal.Projects.Open($fi)
        if ($script:Project -is [System.Management.Automation.PSObject]) { $script:Project = $script:Project.BaseObject }
        Start-Sleep -Seconds 10
        Write-Host "Opened project: $($script:Project.Path)" -ForegroundColor Green
    } else {
        $script:Project = $null
        if ($script:TiaPortal.Projects.Count -gt 0) {
            $p = $script:TiaPortal.Projects[0]
            if ($p -is [System.Management.Automation.PSObject]) { $p = $p.BaseObject }
            $script:Project = $p
            Write-Host "Current project: $($script:Project.Path)" -ForegroundColor Cyan
        } else {
            Write-Host "No project open" -ForegroundColor Yellow
        }
    }
    return $script:Project
}

function Save-TiaProject {
    if (-not $script:Project) { throw "No project open." }
    $script:Project.Save()
    Write-Host "Project saved" -ForegroundColor Green
}

function Find-TiaPlcSoftware {
    param($item)
    $softwareContainerType = $script:Asm.GetType('Siemens.Engineering.HW.Features.SoftwareContainer')
    $gsm = $item.GetType().GetMethod('GetService')
    if ($gsm -and $gsm.IsGenericMethod) {
        $gm = $gsm.MakeGenericMethod($softwareContainerType)
        $c = $gm.Invoke($item, $null)
        if ($c) {
            if ($c -is [System.Management.Automation.PSObject]) { $c = $c.BaseObject }
            $softwareEnum = $c.Software
            if ($softwareEnum) {
                foreach ($s in $softwareEnum) {
                    if ($s -is [System.Management.Automation.PSObject]) { $s = $s.BaseObject }
                    if ($s.GetType().Name -eq 'PlcSoftware') { return $s }
                }
            }
        }
    }
    foreach ($sub in $item.DeviceItems) {
        $subItem = $sub
        if ($subItem -is [System.Management.Automation.PSObject]) { $subItem = $subItem.BaseObject }
        $r = Find-TiaPlcSoftware -item $subItem
        if ($r) { return $r }
    }
    return $null
}

function Get-TiaPlcSoftware {
    param(
        [int]$DeviceIndex = 0
    )
    if (-not $script:Project) { throw "No project open." }
    $device = Unwrap-PSObject $script:Project.Devices[$DeviceIndex]
    if (-not $device) {
        Write-Host "No device at index $DeviceIndex" -ForegroundColor Red
        return $null
    }
    Write-Host "Device: $($device.Name)" -ForegroundColor DarkGray
    if (-not $device.DeviceItems -or $device.DeviceItems.Count -eq 0) {
        Write-Host "Device has no items" -ForegroundColor Yellow
        return $null
    }
    $deviceItem = $device.DeviceItems[0]
    if ($deviceItem -is [System.Management.Automation.PSObject]) { $deviceItem = $deviceItem.BaseObject }
    $sw = Find-TiaPlcSoftware -item $deviceItem
    if (-not $sw) {
        Write-Host "Could not find PLC software via DeviceItems[0], trying all device items..." -ForegroundColor Yellow
        foreach ($item in $device.DeviceItems) {
            $i = $item
            if ($i -is [System.Management.Automation.PSObject]) { $i = $i.BaseObject }
            $sw = Find-TiaPlcSoftware -item $i
            if ($sw) { break }
        }
    }
    if ($sw -is [System.Management.Automation.PSObject]) { $sw = $sw.BaseObject }
    $script:Software = $sw
    if ($sw) {
        Write-Host "PLC Software: $($sw.Name)" -ForegroundColor Cyan
    } else {
        Write-Host "No PLC Software found" -ForegroundColor Red
    }
    return $sw
}

function Get-TiaDevice {
    param(
        [int]$DeviceIndex = 0
    )
    if (-not $script:Project) { throw "No project open." }
    return Unwrap-PSObject $script:Project.Devices[$DeviceIndex]
}

function Get-TiaDeviceItems {
    param(
        [int]$DeviceIndex = 0
    )
    $device = Get-TiaDevice -DeviceIndex $DeviceIndex
    $items = @()
    foreach ($item in $device.DeviceItems) {
        $realItem = Unwrap-PSObject $item
        $itemInfo = [PSCustomObject]@{
            Name            = $realItem.Name
            TypeIdentifier  = $realItem.TypeIdentifier
            SubItems        = @()
        }
        foreach ($sub in $realItem.DeviceItems) {
            $realSub = Unwrap-PSObject $sub
            $subInfo = [PSCustomObject]@{
                Name           = $realSub.Name
                TypeIdentifier = $realSub.TypeIdentifier
                Attributes     = @{}
            }
            try {
                foreach ($attrName in @('Classification','IPAddress','SubnetMask','FirmwareVersion')) {
                    $val = $realSub.GetAttribute($attrName)
                    if ($val) { $subInfo.Attributes[$attrName] = $val }
                }
            } catch {}
            $itemInfo.SubItems += $subInfo
        }
        $items += $itemInfo
    }
    return $items
}

function Get-TiaBlocks {
    param(
        [switch]$IncludeDetails
    )
    if (-not $script:Software) { throw "No PLC software. Call Get-TiaPlcSoftware first." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    $blocks = $blockGroup.Blocks
    $result = @()
    foreach ($b in $blocks) {
        $bObj = Unwrap-PSObject $b
        if ($IncludeDetails) {
            $result += [PSCustomObject]@{
                Name     = $bObj.Name
                Number   = $bObj.Number
                Language = $bObj.ProgrammingLanguage
                Type     = $bObj.GetType().Name
            }
        } else {
            $result += $bObj.Name
        }
    }
    return $result
}

function Get-TiaBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    if (-not $script:Software) { throw "No PLC software." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    $block = $blockGroup.Blocks.Find($Name)
    if (-not $block) { throw "Block '$Name' not found." }
    return Unwrap-PSObject $block
}

function Export-TiaBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$OutputDir = (Join-Path $PSScriptRoot 'export'),
        [switch]$WithDefaults
    )
    $block = Get-TiaBlock -Name $Name
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
    $exportPath = Join-Path $OutputDir "$Name.xml"
    $fi = New-Object System.IO.FileInfo($exportPath)
    $exportOptionsType = $script:Asm.GetType('Siemens.Engineering.ExportOptions')
    $option = if ($WithDefaults) { [System.Enum]::Parse($exportOptionsType, 'WithDefaults') } else { [System.Enum]::Parse($exportOptionsType, 'AsInterface') }
    $block.Export($fi, $option)
    Write-Host "Exported block '$Name' to $exportPath" -ForegroundColor Green
    return $exportPath
}

function Import-TiaBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XmlPath,
        [switch]$Override
    )
    if (-not $script:Software) { throw "No PLC software." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    $importOptionsType = $script:Asm.GetType('Siemens.Engineering.ImportOptions')
    $option = if ($Override) { [System.Enum]::Parse($importOptionsType, 'Override') } else { [System.Enum]::Parse($importOptionsType, 'Keep') }
    $fi = New-Object System.IO.FileInfo($XmlPath)
    $blockGroup.Blocks.Import($fi, $option)
    Write-Host "Imported block from $XmlPath" -ForegroundColor Green
}

function New-TiaFB {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$ProgrammingLanguage = 'LAD',
        [bool]$AutoNumber = $true,
        [int]$Number = 0
    )
    if (-not $script:Software) { throw "No PLC software." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    $progLangType = $script:Asm.GetType('Siemens.Engineering.SW.Blocks.ProgrammingLanguage')
    $lang = [System.Enum]::Parse($progLangType, $ProgrammingLanguage)
    $fb = $blockGroup.Blocks.CreateFB($Name, $AutoNumber, $Number, $lang)
    Write-Host "Created FB '$Name'" -ForegroundColor Green
    return Unwrap-PSObject $fb
}

function New-TiaInstanceDB {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$InstanceOfName,
        [bool]$AutoNumber = $true,
        [int]$Number = 0
    )
    if (-not $script:Software) { throw "No PLC software." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    $idb = $blockGroup.Blocks.CreateInstanceDB($Name, $AutoNumber, $Number, $InstanceOfName)
    Write-Host "Created InstanceDB '$Name' for FB '$InstanceOfName'" -ForegroundColor Green
    return Unwrap-PSObject $idb
}

function Remove-TiaBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Names
    )
    if (-not $script:Software) { throw "No PLC software." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    foreach ($name in $Names) {
        $block = $blockGroup.Blocks.Find($name)
        if ($block) {
            $block.Delete()
            Write-Host "Deleted block '$name'" -ForegroundColor Yellow
        } else {
            Write-Host "Block '$name' not found" -ForegroundColor DarkGray
        }
    }
}

function Remove-TiaBlocksByPattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    if (-not $script:Software) { throw "No PLC software." }
    $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
    $toDelete = @()
    foreach ($b in $blockGroup.Blocks) {
        $bObj = Unwrap-PSObject $b
        if ($bObj.Name -like $Pattern) { $toDelete += $bObj.Name }
    }
    foreach ($name in $toDelete) {
        $block = $blockGroup.Blocks.Find($name)
        if ($block) { $block.Delete() }
    }
    Write-Host "Deleted $($toDelete.Count) blocks matching '$Pattern'" -ForegroundColor Yellow
}

function Get-TiaTagTables {
    if (-not $script:Software) { throw "No PLC software." }
    $tagTableGroup = Unwrap-PSObject $script:Software.TagTableGroup
    $tables = @()
    foreach ($t in $tagTableGroup.TagTables) {
        $tObj = Unwrap-PSObject $t
        $tables += [PSCustomObject]@{
            Name = $tObj.Name
            Tags = $tObj.Tags.Count
        }
    }
    return $tables
}

function Get-TiaTagTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    if (-not $script:Software) { throw "No PLC software." }
    $tagTableGroup = Unwrap-PSObject $script:Software.TagTableGroup
    $table = $tagTableGroup.TagTables.Find($Name)
    if (-not $table) { throw "Tag table '$Name' not found." }
    return Unwrap-PSObject $table
}

function Export-TiaTagTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$OutputDir = (Join-Path $PSScriptRoot 'export'),
        [switch]$WithDefaults
    )
    $table = Get-TiaTagTable -Name $Name
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
    $exportPath = Join-Path $OutputDir "${Name}_tagtable.xml"
    $fi = New-Object System.IO.FileInfo($exportPath)
    $exportOptionsType = $script:Asm.GetType('Siemens.Engineering.ExportOptions')
    $option = if ($WithDefaults) { [System.Enum]::Parse($exportOptionsType, 'WithDefaults') } else { [System.Enum]::Parse($exportOptionsType, 'AsInterface') }
    $table.Export($fi, $option)
    Write-Host "Exported tag table '$Name' to $exportPath" -ForegroundColor Green
    return $exportPath
}

function Import-TiaTagTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XmlPath,
        [switch]$Override
    )
    if (-not $script:Software) { throw "No PLC software." }
    $tagTableGroup = Unwrap-PSObject $script:Software.TagTableGroup
    $importOptionsType = $script:Asm.GetType('Siemens.Engineering.ImportOptions')
    $option = if ($Override) { [System.Enum]::Parse($importOptionsType, 'Override') } else { [System.Enum]::Parse($importOptionsType, 'Keep') }
    $fi = New-Object System.IO.FileInfo($XmlPath)
    $tagTableGroup.TagTables.Import($fi, $option)
    Write-Host "Imported tag table from $XmlPath" -ForegroundColor Green
}

function Remove-TiaTagTable {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Names
    )
    if (-not $script:Software) { throw "No PLC software." }
    $tagTableGroup = Unwrap-PSObject $script:Software.TagTableGroup
    foreach ($name in $Names) {
        $table = $tagTableGroup.TagTables.Find($name)
        if ($table) {
            $table.Delete()
            Write-Host "Deleted tag table '$name'" -ForegroundColor Yellow
        } else {
            Write-Host "Tag table '$name' not found" -ForegroundColor DarkGray
        }
    }
}

function Remove-TiaTagTablesByPattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    if (-not $script:Software) { throw "No PLC software." }
    $tagTableGroup = Unwrap-PSObject $script:Software.TagTableGroup
    $toDelete = @()
    foreach ($t in $tagTableGroup.TagTables) {
        $tObj = Unwrap-PSObject $t
        if ($tObj.Name -like $Pattern) { $toDelete += $tObj.Name }
    }
    foreach ($name in $toDelete) {
        $table = $tagTableGroup.TagTables.Find($name)
        if ($table) { $table.Delete() }
    }
    Write-Host "Deleted $($toDelete.Count) tag tables matching '$Pattern'" -ForegroundColor Yellow
}

function Invoke-TiaCompile {
    param(
        [string]$BlockName
    )
    if (-not $script:Software) { throw "No PLC software." }
    $compilableType = $script:Asm.GetType('Siemens.Engineering.Compiler.ICompilable')
    $getServiceMethod = $script:Software.GetType().GetMethod('GetService')
    if ($BlockName) {
        $block = Get-TiaBlock -Name $BlockName
        $compilableBlock = $block.GetService($compilableType)
        $result = $compilableBlock.Compile()
    } else {
        $compilableGeneric = $getServiceMethod.MakeGenericMethod($compilableType)
        $compilable = Unwrap-PSObject ($compilableGeneric.Invoke($script:Software, $null))
        $result = $compilable.Compile()
    }
    Write-Host "Compile State: $($result.State)" -ForegroundColor $(if ($result.State -eq 'Error') { 'Red' } else { 'Green' })
    Write-Host "Errors: $($result.ErrorCount), Warnings: $($result.WarningCount)"
    foreach ($msg in $result.Messages) {
        $color = switch ($msg.Severity) { 'Error' { 'Red' } 'Warning' { 'Yellow' } default { 'Gray' } }
        Write-Host "  [$($msg.Severity)] $($msg.Description) Path: $($msg.Path)" -ForegroundColor $color
    }
    return $result
}

function Get-TiaOnlineProvider {
    param(
        [int]$DeviceIndex = 0
    )
    if (-not $script:Project) { throw "No project open." }
    $onlineProviderType = $script:Asm.GetType('Siemens.Engineering.Online.OnlineProvider')
    $device = Get-TiaDevice -DeviceIndex $DeviceIndex
    foreach ($item in $device.DeviceItems) {
        $realItem = Unwrap-PSObject $item
        $gsm = $realItem.GetType().GetMethod('GetService')
        $gm = $gsm.MakeGenericMethod($onlineProviderType)
        $provider = $gm.Invoke($realItem, $null)
        if ($provider) { return Unwrap-PSObject $provider }
    }
    throw "Could not get OnlineProvider from device"
}

function Get-TiaDownloadProvider {
    param(
        [int]$DeviceIndex = 0
    )
    if (-not $script:Project) { throw "No project open." }
    $downloadProviderType = $script:Asm.GetType('Siemens.Engineering.Download.DownloadProvider')
    $device = Get-TiaDevice -DeviceIndex $DeviceIndex
    foreach ($item in $device.DeviceItems) {
        $realItem = Unwrap-PSObject $item
        $gsm = $realItem.GetType().GetMethod('GetService')
        $gm = $gsm.MakeGenericMethod($downloadProviderType)
        $provider = $gm.Invoke($realItem, $null)
        if ($provider) { return Unwrap-PSObject $provider }
    }
    throw "Could not get DownloadProvider from device"
}

function Invoke-TiaGoOnline {
    param(
        [int]$DeviceIndex = 0
    )
    $provider = Get-TiaOnlineProvider -DeviceIndex $DeviceIndex
    $state = $provider.GoOnline()
    Write-Host "Online state: $state" -ForegroundColor Cyan
    return $state
}

function Invoke-TiaGoOffline {
    param(
        [int]$DeviceIndex = 0
    )
    $provider = Get-TiaOnlineProvider -DeviceIndex $DeviceIndex
    $provider.GoOffline()
    Write-Host "Gone offline" -ForegroundColor Cyan
}

function Invoke-TiaDownload {
    param(
        [int]$DeviceIndex = 0,
        [string]$Options = 'Software'
    )
    $downloadProvider = Get-TiaDownloadProvider -DeviceIndex $DeviceIndex
    $downloadOptionsType = $script:Asm.GetType('Siemens.Engineering.Download.DownloadOptions')
    $option = [System.Enum]::Parse($downloadOptionsType, $Options)
    $config = $downloadProvider.Configuration
    $result = $downloadProvider.Download($config, $null, $null, $option)
    Write-Host "Download State: $($result.State)" -ForegroundColor $(if ($result.State -eq 'Error') { 'Red' } else { 'Green' })
    Write-Host "Errors: $($result.ErrorCount), Warnings: $($result.WarningCount)"
    return $result
}

function Set-TiaIpAddress {
    param(
        [int]$DeviceIndex = 0,
        [Parameter(Mandatory=$true)]
        [string]$IpAddress,
        [string]$SubnetMask = '255.255.255.0'
    )
    $device = Get-TiaDevice -DeviceIndex $DeviceIndex
    foreach ($item in $device.DeviceItems) {
        foreach ($subItem in $item.DeviceItems) {
            try {
                $realSub = Unwrap-PSObject $subItem
                $classification = $realSub.GetAttribute('Classification')
                if ($classification -and $classification.ToString().Contains('PN')) {
                    $realSub.SetAttribute('IPAddress', $IpAddress)
                    $realSub.SetAttribute('SubnetMask', $SubnetMask)
                    $realSub.SetAttribute('UseIPProtocol', $true)
                    Write-Host "IP configured: $IpAddress" -ForegroundColor Green
                    return
                }
            } catch {}
        }
    }
    Write-Host "PROFINET interface not found on device" -ForegroundColor Red
}

function New-TiaProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Directory,
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    if (-not $script:TiaPortal) { throw "Not connected." }
    $projects = Unwrap-PSObject $script:TiaPortal.Projects
    $dirInfo = New-Object System.IO.DirectoryInfo($Directory)
    $script:Project = $projects.Create($dirInfo, $Name)
    Write-Host "Created project: $($script:Project.Name)" -ForegroundColor Green
    return $script:Project
}

function New-TiaDevice {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OrderNumber,
        [string]$DeviceName = 'PLC',
        [int]$DeviceIndex = 0
    )
    if (-not $script:Project) { throw "No project open." }
    $deviceTypeIdentifier = "OrderNumber:$OrderNumber"
    $device = $script:Project.Devices.CreateWithItem($deviceTypeIdentifier, $DeviceName, $DeviceName)
    Write-Host "Created device: $DeviceName ($OrderNumber)" -ForegroundColor Green
    return Unwrap-PSObject $device
}

function New-TiaTagXml {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName,
        [Parameter(Mandatory=$true)]
        [array]$Tags,
        [string]$Culture = 'zh-CN'
    )
    $id = 1
    $tagXml = ''
    foreach ($tag in $Tags) {
        $id++
        $tagId = $id
        $id++
        $commentId = $id
        $id++
        $itemId = $id
        $comment = if ($tag.Comment) { @"
        <ObjectList>
          <MultilingualText ID="$commentId" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="$itemId" CompositionName="Items">
                <AttributeList>
                  <Culture>$Culture</Culture>
                  <Text>$([System.Security.SecurityElement]::Escape($tag.Comment))</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
"@ } else { '' }
        $tagXml += @"
      <SW.Tags.PlcTag ID="$tagId" CompositionName="Tags">
        <AttributeList>
          <DataTypeName>$($tag.DataType)</DataTypeName>
          <ExternalAccessible>true</ExternalAccessible>
          <ExternalVisible>true</ExternalVisible>
          <ExternalWritable>true</ExternalWritable>
          <LogicalAddress>$($tag.Address)</LogicalAddress>
          <Name>$([System.Security.SecurityElement]::Escape($tag.Name))</Name>
        </AttributeList>$comment
      </SW.Tags.PlcTag>

"@
    }
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V19" />
  <SW.Tags.PlcTagTable ID="0">
    <AttributeList>
      <Name>$([System.Security.SecurityElement]::Escape($TableName))</Name>
    </AttributeList>
    <ObjectList>
$tagXml    </ObjectList>
  </SW.Tags.PlcTagTable>
</Document>
"@
    return $xml
}

function New-TiaGlobalDbXml {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [array]$Members,
        [int]$Number = 0,
        [string]$Culture = 'zh-CN'
    )
    $memberXml = ''
    foreach ($m in $Members) {
        $comment = if ($m.Comment) { @"
      <Comment>
        <MultiLanguageText Lang="$Culture">$([System.Security.SecurityElement]::Escape($m.Comment))</MultiLanguageText>
      </Comment>
"@ } else { '' }
        $remanence = if ($m.Remanence) { " Remanence=`"$($m.Remanence)`"" } else { ' Remanence="NonRetain"' }
        $accessibility = if ($m.Accessibility) { " Accessibility=`"$($m.Accessibility)`"" } else { ' Accessibility="Public"' }
        $memberXml += @"
    <Member Name="$([System.Security.SecurityElement]::Escape($m.Name))" Datatype="$($m.Datatype)"$remanence$accessibility>
      <AttributeList>
        <BooleanAttribute Name="ExternalAccessible" SystemDefined="true">true</BooleanAttribute>
        <BooleanAttribute Name="ExternalVisible" SystemDefined="true">true</BooleanAttribute>
        <BooleanAttribute Name="ExternalWritable" SystemDefined="true">true</BooleanAttribute>
        <BooleanAttribute Name="SetPoint" SystemDefined="true">false</BooleanAttribute>
      </AttributeList>$comment
    </Member>

"@
    }
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V19" />
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
$memberXml  </Section>
</Sections></Interface>
      <IsOnlyStoredInLoadMemory>false</IsOnlyStoredInLoadMemory>
      <IsWriteProtectedInAS>false</IsWriteProtectedInAS>
      <MemoryLayout>Standard</MemoryLayout>
      <Name>$([System.Security.SecurityElement]::Escape($Name))</Name>
      <Namespace />
      <Number>$Number</Number>
      <ProgrammingLanguage>DB</ProgrammingLanguage>
    </AttributeList>
    <ObjectList>
      <MultilingualText ID="1" CompositionName="Comment">
        <ObjectList>
          <MultilingualTextItem ID="2" CompositionName="Items">
            <AttributeList>
              <Culture>$Culture</Culture>
              <Text />
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
      <MultilingualText ID="3" CompositionName="Title">
        <ObjectList>
          <MultilingualTextItem ID="4" CompositionName="Items">
            <AttributeList>
              <Culture>$Culture</Culture>
              <Text />
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
    </ObjectList>
  </SW.Blocks.GlobalDB>
</Document>
"@
    return $xml
}

function New-TiaFcXml {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [int]$Number = 0,
        [string]$ProgrammingLanguage = 'LAD',
        [string]$Culture = 'zh-CN',
        [array]$InputMembers,
        [array]$OutputMembers,
        [array]$InOutMembers,
        [array]$TempMembers,
        [string]$ReturnDatatype = 'Void'
    )
    function Build-Section {
        param($sectionName, $members)
        if (-not $members -or $members.Count -eq 0) {
            return "<Section Name=`"$sectionName`" />"
        }
        $memXml = ''
        foreach ($m in $members) {
            $accessibility = if ($m.Accessibility) { " Accessibility=`"$($m.Accessibility)`"" } else { '' }
            $memXml += "<Member Name=`"$([System.Security.SecurityElement]::Escape($m.Name))`" Datatype=`"$($m.Datatype)`"$accessibility />"
        }
        return "<Section Name=`"$sectionName`">$memXml</Section>"
    }
    $inputSection = Build-Section 'Input' $InputMembers
    $outputSection = Build-Section 'Output' $OutputMembers
    $inoutSection = Build-Section 'InOut' $InOutMembers
    $tempSection = Build-Section 'Temp' $TempMembers
    $xml = @"
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
  $inputSection
  $outputSection
  $inoutSection
  $tempSection
  <Section Name="Constant" />
  <Section Name="Return">
    <Member Name="Ret_Val" Datatype="$ReturnDatatype" Accessibility="Public" />
  </Section>
</Sections></Interface>
      <IsIECCheckEnabled>false</IsIECCheckEnabled>
      <MemoryLayout>Optimized</MemoryLayout>
      <Name>$([System.Security.SecurityElement]::Escape($Name))</Name>
      <Namespace />
      <Number>$Number</Number>
      <ProgrammingLanguage>$ProgrammingLanguage</ProgrammingLanguage>
      <SetENOAutomatically>false</SetENOAutomatically>
      <UDABlockProperties />
      <UDAEnableTagReadback>false</UDAEnableTagReadback>
    </AttributeList>
    <ObjectList>
      <MultilingualText ID="1" CompositionName="Comment">
        <ObjectList>
          <MultilingualTextItem ID="2" CompositionName="Items">
            <AttributeList>
              <Culture>$Culture</Culture>
              <Text />
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
      <MultilingualText ID="3" CompositionName="Title">
        <ObjectList>
          <MultilingualTextItem ID="4" CompositionName="Items">
            <AttributeList>
              <Culture>$Culture</Culture>
              <Text />
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
    </ObjectList>
  </SW.Blocks.FC>
</Document>
"@
    return $xml
}

function Add-Utf8Bom {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $content | Out-File -FilePath $Path -Encoding utf8
    Write-Host "Added UTF-8 BOM to $Path" -ForegroundColor Green
}

function Write-TiaXmlWithBom {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Xml,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Xml, [System.Text.Encoding]::UTF8)
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $content | Out-File -FilePath $Path -Encoding utf8
    Write-Host "Written XML with BOM to $Path" -ForegroundColor Green
}

function Get-TiaBlockInterface {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $block = Get-TiaBlock -Name $Name
    $interface = Unwrap-PSObject $block.Interface
    $ns = 'http://www.siemens.com/automation/Openness/SW/Interface/v5'
    $xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($interface.Text))
    $members = @()
    while ($xmlReader.Read()) {
        if ($xmlReader.NodeType -eq [System.Xml.XmlNodeType]::Element -and $xmlReader.Name -eq 'Member') {
            $name = $xmlReader.GetAttribute('Name')
            $datatype = $xmlReader.GetAttribute('Datatype')
            if ($name) { $members += [PSCustomObject]@{ Name = $name; Datatype = $datatype } }
        }
    }
    $xmlReader.Close()
    return $members
}

function Get-TiaWatchAndForceTableGroup {
    if (-not $script:Software) { throw "No PLC software." }
    return Unwrap-PSObject $script:Software.WatchAndForceTableGroup
}

function New-TiaWatchTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $wfGroup = Get-TiaWatchAndForceTableGroup
    $wt = $wfGroup.WatchTables.Create($Name)
    Write-Host "Created watch table '$Name'" -ForegroundColor Green
    return Unwrap-PSObject $wt
}

function New-TiaForceTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $wfGroup = Get-TiaWatchAndForceTableGroup
    $ft = $wfGroup.ForceTables.Create($Name)
    Write-Host "Created force table '$Name'" -ForegroundColor Green
    return Unwrap-PSObject $ft
}

function Get-TiaProjectStatus {
    if (-not $script:TiaPortal) { return [PSCustomObject]@{ Connected = $false } }
    $result = [PSCustomObject]@{
        Connected = $true
        HasProject = $false
        ProjectName = ''
        HasSoftware = $false
        SoftwareName = ''
        BlockCount = 0
        TagTableCount = 0
    }
    if ($script:Project) {
        $result.HasProject = $true
        $result.ProjectName = $script:Project.Name
    }
    if ($script:Software) {
        $result.HasSoftware = $true
        $result.SoftwareName = $script:Software.Name
        $blockGroup = Unwrap-PSObject $script:Software.BlockGroup
        $result.BlockCount = $blockGroup.Blocks.Count
        $tagTableGroup = Unwrap-PSObject $script:Software.TagTableGroup
        $result.TagTableCount = $tagTableGroup.TagTables.Count
    }
    return $result
}

function Invoke-TiaArchive {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetDirectory,
        [string]$ArchiveName,
        [string]$Mode = 'Compressed'
    )
    if (-not $script:Project) { throw "No project open." }
    $archivationModeType = $script:Asm.GetType('Siemens.Engineering.ProjectArchivationMode')
    $modeValue = [System.Enum]::Parse($archivationModeType, $Mode)
    $targetDir = New-Object System.IO.DirectoryInfo($TargetDirectory)
    $script:Project.Archive($targetDir, $ArchiveName, $modeValue)
    Write-Host "Project archived to $TargetDirectory\$ArchiveName.zap19" -ForegroundColor Green
}

function Restore-TiaProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ArchivePath,
        [Parameter(Mandatory=$true)]
        [string]$TargetDirectory
    )
    if (-not $script:TiaPortal) { throw "Not connected." }
    $archiveFi = New-Object System.IO.FileInfo($ArchivePath)
    $restoreDir = New-Object System.IO.DirectoryInfo($TargetDirectory)
    $projects = Unwrap-PSObject $script:TiaPortal.Projects
    $script:Project = $projects.Retrieve($archiveFi, $restoreDir)
    Write-Host "Project retrieved: $($script:Project.Name)" -ForegroundColor Green
    return $script:Project
}

function Get-TiaBlockReferences {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $block = Get-TiaBlock -Name $Name
    $refs = $block.GetReferences()
    $result = @()
    foreach ($ref in $refs) {
        $result += $ref.ToString()
    }
    return $result
}

function Find-TiaProjects {
    param(
        [string[]]$SearchDirs = $null,
        [int]$MaxDepth = 5
    )
    if (-not $SearchDirs) {
        $SearchDirs = @(
            'D:\work',
            'D:\new folder',
            'D:\Projects',
            [System.IO.Path]::Combine($env:USERPROFILE, 'Documents', 'Automation')
        )
    }
    $results = @()
    foreach ($dir in $SearchDirs) {
        if (Test-Path $dir) {
            Write-Host "Scanning: $dir" -ForegroundColor DarkGray
            Get-ChildItem -Path $dir -Filter '*.ap19' -Recurse -ErrorAction SilentlyContinue -Depth $MaxDepth | ForEach-Object {
                $results += [PSCustomObject]@{
                    FullName = $_.FullName
                    Directory = $_.Directory.Name
                    LastModified = $_.LastWriteTime
                    SizeKB = [math]::Round($_.Length / 1KB, 1)
                }
            }
        }
    }
    return $results | Sort-Object LastModified -Descending
}

function Get-TiaOpenProjects {
    if (-not $script:TiaPortal) { throw "Not connected. Call Connect-TiaPortal first." }
    $result = @()
    foreach ($p in $script:TiaPortal.Projects) {
        $proj = $p
        if ($proj -is [System.Management.Automation.PSObject]) { $proj = $proj.BaseObject }
        $result += [PSCustomObject]@{
            Name = $proj.Name
            Path = $proj.Path
        }
    }
    return $result
}
