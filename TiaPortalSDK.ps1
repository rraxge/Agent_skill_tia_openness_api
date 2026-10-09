# ============================================================
#  TIA Portal Openness SDK - 版本自适应 (V19 / V20 / V21 ...)
# ------------------------------------------------------------
#  安装位置从注册表自动发现:
#     HKLM\SOFTWARE\Siemens\Automation\Openness\<ver>\PublicAPI\<ver>\<tfm>\
#  V19 及以前: 单个 Siemens.Engineering.dll
#  V21 起    : 拆成 Siemens.Engineering.Base.dll / .Step7.dll / .WinCC*.dll / ...
#              Base 必须先加载, 其余程序集才解析得到依赖。
#  用 Connect-TiaPortal -TiaVersion 21 指定版本; 缺省取本机最高版本。
# ============================================================

$script:TiaVersion = $null      # '19' / '21'
$script:DllPath    = $null      # 主程序集 (类型解析兜底)
$script:DllPaths   = @()        # 本次需要加载的全部 Openness 程序集
$script:Asm        = $null      # == 主程序集
$script:XmlVersion = 'V21'      # 写入导入 XML 的 <Engineering version="...">
$script:ProjectExt = 'ap21'
$script:ArchiveExt = 'zap21'
$script:TiaPortal  = $null
$script:Project    = $null
$script:Software   = $null

function Unwrap-PSObject {
    <#  解包 PowerShell 的 PSObject 包装。
        必须用 -NoEnumerate 输出: 如果传进来的是集合
        (如 TiaPortal.Projects 这类 ProjectComposition),
        return 会把集合展开成多个元素 —— 空集合直接变成 $null,
        非空集合变成里面的元素, 调用方拿到的东西完全不对。  #>
    param($obj)
    $t = $obj
    if ($t -is [System.Management.Automation.PSObject]) { $t = $t.BaseObject }
    Write-Output $t -NoEnumerate
}

function Get-TiaInstallations {
    <#  列出本机所有已安装的 TIA Portal Openness 版本。
        注册表有两种形状, 都要兼容:
          V21 起: Openness\<ver>\PublicAPI\<apiVer>\net48\Siemens.Engineering.Base = <dll 路径>
          V19 及以前: Openness\<ver>\PublicAPI\<apiVer>\Siemens.Engineering = <dll 路径>
        V19 会为同一次安装登记多个 apiVer(16.0.0.0 ... 19.0.0.0),
        同一 Version 只保留 apiVer 最高的那个。
        返回对象含 Version / Dir / Primary / Assemblies  #>
    $best = @{}
    $root = 'HKLM:\SOFTWARE\Siemens\Automation\Openness'
    if (-not (Test-Path $root)) { return @() }
    foreach ($vKey in (Get-ChildItem $root -ErrorAction SilentlyContinue)) {
        $apiRoot = Join-Path $vKey.PSPath 'PublicAPI'
        if (-not (Test-Path $apiRoot)) { continue }
        $cands = @()
        foreach ($apiKey in (Get-ChildItem $apiRoot -ErrorAction SilentlyContinue)) {
            $cands += [PSCustomObject]@{ Key = $apiKey.PSPath; ApiVer = $apiKey.PSChildName }
            foreach ($sfxKey in (Get-ChildItem $apiKey.PSPath -ErrorAction SilentlyContinue)) {
                $cands += [PSCustomObject]@{ Key = $sfxKey.PSPath; ApiVer = $apiKey.PSChildName }
            }
        }
        foreach ($c in $cands) {
            $props = Get-ItemProperty $c.Key -ErrorAction SilentlyContinue
            $dll = $null
            foreach ($pr in $props.PSObject.Properties) {
                if ($pr.Name -like 'Siemens.Engineering*' -and "$($pr.Value)" -like '*.dll') { $dll = $pr.Value; break }
            }
            if (-not $dll) { continue }
            $dir = Split-Path $dll -Parent
            $files = @(Get-ChildItem -Path $dir -Filter 'Siemens.Engineering*.dll' -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -notlike '*AddIn*' } | ForEach-Object { $_.FullName })
            $primary = $files | Where-Object { $_ -like '*Siemens.Engineering.Base.dll' } | Select-Object -First 1
            if (-not $primary) { $primary = $files | Where-Object { $_ -like '*\Siemens.Engineering.dll' } | Select-Object -First 1 }
            if (-not $primary) { $primary = $files | Select-Object -First 1 }
            $ver = $vKey.PSChildName.Split('.')[0]
            $apiNum = 0.0
            try { $apiNum = [double]($c.ApiVer -replace '^(\d+\.\d+).*$', '$1') } catch { }
            if (-not $best.ContainsKey($ver) -or $apiNum -gt $best[$ver].ApiNum) {
                $best[$ver] = [PSCustomObject]@{
                    Version    = $ver
                    Dir        = $dir
                    Primary    = $primary
                    Assemblies = $files
                    ApiNum     = $apiNum
                }
            }
        }
    }
    return @($best.Values | Sort-Object { [int]$_.Version } | ForEach-Object { $_ })
}

function Get-TiaType {
    <#  跨程序集按全名解析类型。
        V21 起类型分散在 Base / Step7 / WinCC 等多个程序集,
        只查单一程序集会漏掉 SW.* 等类型 (返回 $null)。
        同机装有多版本时, 优先返回本次 Connect 选定版本的程序集里的类型。  #>
    param([Parameter(Mandatory=$true)][string]$TypeName)
    if ($script:Asm) {
        $t = $script:Asm.GetType($TypeName)
        if ($t) { return $t }
    }
    $preferred = @($script:DllPaths | ForEach-Object { "$_".ToLower() })
    $fallback = $null
    foreach ($a in [AppDomain]::CurrentDomain.GetAssemblies()) {
        if ($a.GetName().Name -notlike 'Siemens.Engineering*') { continue }
        try { $t = $a.GetType($TypeName) } catch { $t = $null }
        if (-not $t) { continue }
        $loc = ''
        try { $loc = "$($a.Location)".ToLower() } catch { }
        if ($preferred -contains $loc) { return $t }
        if (-not $fallback) { $fallback = $t }
    }
    return $fallback
}

function Connect-TiaPortal {
    param(
        [switch]$StartIfNotFound,
        [switch]$WithUI,
        [string]$TiaVersion      # '19' / '21', 缺省取本机最高版本
    )
    # --- 发现并选定 Openness 版本 ---
    $installs = @(Get-TiaInstallations)
    if (-not $installs) {
        throw 'No TIA Portal Openness installed (HKLM\SOFTWARE\Siemens\Automation\Openness)'
    }
    $pick = if ($TiaVersion) { $installs | Where-Object { $_.Version -eq $TiaVersion } | Select-Object -First 1 }
            else             { $installs | Select-Object -Last 1 }
    if (-not $pick) {
        $have = ($installs | ForEach-Object { 'V' + $_.Version }) -join ', '
        throw "TIA Portal V$TiaVersion Openness not found. Installed: $have"
    }
    $script:TiaVersion = $pick.Version
    $script:XmlVersion = 'V' + $pick.Version
    $script:ProjectExt = 'ap' + $pick.Version
    $script:ArchiveExt = 'zap' + $pick.Version
    $script:DllPath    = $pick.Primary
    $script:DllPaths   = @($pick.Assemblies)

    # 逐个加载: V21 起 Base 必须先于 Step7 / WinCC 加载
    foreach ($dll in ($script:DllPaths | Sort-Object { if ($_ -like '*Siemens.Engineering.Base.dll') { 0 } else { 1 } })) {
        try { [void][System.Reflection.Assembly]::LoadFrom($dll) }
        catch { Write-Warning "Load failed: $dll -- $($_.Exception.Message)" }
    }
    $script:Asm = [System.Reflection.Assembly]::LoadFrom($script:DllPath)
    Write-Host "Openness V$($script:TiaVersion) loaded: $($pick.Dir)" -ForegroundColor DarkGray

    $modeType = Get-TiaType('Siemens.Engineering.TiaPortalMode')
    # 注意: 行首是函数调用时属于参数模式, 不能在后面直接 .Method() 链式调用,
    #       必须先赋值给变量(或整体加括号), 否则整串会被当成字符串参数。
    $tpType = Get-TiaType('Siemens.Engineering.TiaPortal')
    $getProcessesMethod = $tpType.GetMethod('GetProcesses', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
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
        $ctor = $tpType.GetConstructor(@($modeType))
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
        [string]$ProjectPath,
        [switch]$Upgrade        # 旧版本工程(.ap19 等)必须用 -Upgrade 走 OpenWithUpgrade
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
        # Close the existing project first (先保存, 避免丢掉用户未保存的改动)
        Write-Host "Closing current project: $($existing.Name) (saving first)..." -ForegroundColor Yellow
        try { $existing.Save() } catch { Write-Host ("  Save failed: " + $_.Exception.Message) -ForegroundColor Yellow }
        $existing.Close()
        Start-Sleep -Seconds 3
    }
    
    if ($ProjectPath) {
        $fi = New-Object System.IO.FileInfo((Resolve-Path $ProjectPath).Path)
        # 注意: 不要对 Projects 这种集合做 Unwrap —— PowerShell 函数返回会展开集合
        $projects = $script:TiaPortal.Projects
        if ($Upgrade) {
            Write-Host "Opening WITH UPGRADE: $ProjectPath ..." -ForegroundColor Yellow
            $script:Project = $projects.OpenWithUpgrade($fi)
        } else {
            Write-Host "Opening project: $ProjectPath ..." -ForegroundColor Yellow
            $script:Project = $script:TiaPortal.Projects.Open($fi)
        }
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
    if ($null -eq $item) { return $null }
    $softwareContainerType = Get-TiaType('Siemens.Engineering.HW.Features.SoftwareContainer')
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
    $exportOptionsType = Get-TiaType('Siemens.Engineering.ExportOptions')
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
    $importOptionsType = Get-TiaType('Siemens.Engineering.ImportOptions')
    $option = if ($Override) { [System.Enum]::Parse($importOptionsType, 'Override') } else { [System.Enum]::Parse($importOptionsType, 'Keep') }
    $fi = New-Object System.IO.FileInfo($XmlPath)
    $blockGroup.Blocks.Import($fi, $option)
    Write-Host "Imported block from $XmlPath" -ForegroundColor Green
}

function New-TiaFbXml {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [int]$Number = 0,
        [string]$ProgrammingLanguage = 'LAD',
        [string]$Culture = 'zh-CN',
        [array]$InputMembers,
        [array]$OutputMembers,
        [array]$InOutMembers,
        [array]$StaticMembers,
        [array]$TempMembers
    )
    <#  V21 起 PlcBlockComposition.CreateFB 只接受 ProDiag 语言:
          "The action \"Create block\" only supports the programming language 'ProDiag'."
        所以创建 FB 必须走 XML 导入, 本函数生成可导入的 FB XML。
        FB 的 Section 不含 Return(FB 用 Static 存状态)。  #>
    function __tiaBuildSec {
        param($sectionName, $members)
        if (-not $members -or $members.Count -eq 0) { return "<Section Name=`"$sectionName`" />" }
        $s = ''
        foreach ($m in $members) {
            $acc = if ($m.Accessibility) { " Accessibility=`"$($m.Accessibility)`"" } else { '' }
            $s += "<Member Name=`"$([System.Security.SecurityElement]::Escape($m.Name))`" Datatype=`"$($m.Datatype)`"$acc />"
        }
        return "<Section Name=`"$sectionName`">$s</Section>"
    }
    $secInput  = __tiaBuildSec 'Input'    $InputMembers
    $secOutput = __tiaBuildSec 'Output'   $OutputMembers
    $secInOut  = __tiaBuildSec 'InOut'    $InOutMembers
    $secStatic = __tiaBuildSec 'Static'   $StaticMembers
    $secTemp   = __tiaBuildSec 'Temp'     $TempMembers
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="$script:XmlVersion" />
  <SW.Blocks.FB ID="0">
    <AttributeList>
      <AutoNumber>true</AutoNumber>
      <HeaderAuthor />
      <HeaderFamily />
      <HeaderName />
      <HeaderVersion>0.1</HeaderVersion>
      <Interface><Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
  $secInput
  $secOutput
  $secInOut
  $secStatic
  $secTemp
  <Section Name="Constant" />
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
  </SW.Blocks.FB>
</Document>
"@
    if ($ProgrammingLanguage -match '^(SCL|ST)$') {
        $unit = @"
      <SW.Blocks.CompileUnit ID="101" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource><StructuredText xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v1" UId="110"><Text UId="1110">// generated by TiaPortalSDK</Text></StructuredText></NetworkSource>
          <ProgrammingLanguage>$ProgrammingLanguage</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="102" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="103" CompositionName="Items">
                <AttributeList>
                  <Culture>$Culture</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
"@
        $xml = $xml.Replace('  </SW.Blocks.FB>', $unit + '  </SW.Blocks.FB>')
    }
    return $xml
}

function New-TiaFB {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$ProgrammingLanguage = 'LAD',
        [int]$Number = 0
    )
    <#  V21 的 CreateFB 只支持 ProDiag, 这里统一改成"生成 XML -> 导入",
        V19 / V21 都能用。  #>
    $xml = New-TiaFbXml -Name $Name -Number $Number -ProgrammingLanguage $ProgrammingLanguage
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("fb_" + [System.Guid]::NewGuid().ToString('N') + ".xml")
    Write-TiaXmlWithBom -Xml $xml -Path $tmp
    try {
        Import-TiaBlock -XmlPath $tmp -Override
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
    return Get-TiaBlock -Name $Name
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
    $exportOptionsType = Get-TiaType('Siemens.Engineering.ExportOptions')
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
    $importOptionsType = Get-TiaType('Siemens.Engineering.ImportOptions')
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
    $compilableType = Get-TiaType('Siemens.Engineering.Compiler.ICompilable')
    $getServiceMethod = $script:Software.GetType().GetMethod('GetService')
    if ($BlockName) {
        $block = Get-TiaBlock -Name $BlockName
        # V21: 不能用 $block.GetService($type) 这种位置参数反射调用(报
        # "找不到 GetService 的重载，参数计数为 1"), 必须 MakeGenericMethod
        $gsmB = $block.GetType().GetMethod('GetService')
        $compilableBlock = Unwrap-PSObject ($gsmB.MakeGenericMethod($compilableType).Invoke($block, $null))
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
    $onlineProviderType = Get-TiaType('Siemens.Engineering.Online.OnlineProvider')
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
    $downloadProviderType = Get-TiaType('Siemens.Engineering.Download.DownloadProvider')
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

function Set-TiaOnlineTargetInterface {
    param(
        [int]$DeviceIndex = 0,
        [string]$PcInterfacePattern = 'PLCSIM'
    )
    <#  V21 实测可用: 把在线连接的目标网卡切到指定的 PC 接口,
        例如 'Siemens PLCSIM Virtual Ethernet Adapter' 或 'Realtek PCIe GbE'.
        注意: ConfigurationTargetInterface 对象本身只叫 "1 X1", 必须按
        ConfigurationMode.PcInterfaces 的名字去匹配。
        实测: ApplyConfiguration 返回 True, IsConfigured 变 True。  #>
    if (-not $script:Project) { throw 'No project open.' }
    $op = Get-TiaOnlineProvider -DeviceIndex $DeviceIndex
    $cfg = $op.Configuration
    $target = $null
    foreach ($m in $cfg.Modes) {
        foreach ($pc in $m.PcInterfaces) {
            if ($pc.Name -notmatch $PcInterfacePattern) { continue }
            Write-Host ("  命中 PC 接口: " + $pc.Name)
            foreach ($pr in $pc.GetType().GetProperties()) {
                if ($pr.PropertyType.Name -notmatch 'Composition') { continue }   # 按属性类型过滤, 不是属性名
                try { foreach ($c in $pr.GetValue($pc)) { $target = $c; break } } catch { }
                if ($target) { break }
            }
            if ($target) { break }
        }
        if ($target) { break }
    }
    if (-not $target) { throw ("没找到匹配 '" + $PcInterfacePattern + "' 的 PC 接口(检查网卡名)") }
    $ok = $cfg.ApplyConfiguration($target)
    Write-Host ("在线目标接口 -> '" + $pc.Name + "' / 目标 '" + $target.Name + "'  ApplyConfiguration=" + $ok + "  IsConfigured=" + $cfg.IsConfigured) -ForegroundColor Green
    return $ok
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

function Connect-TiaToPlcsim {
    param(
        [int]$DeviceIndex = 0,
        [string]$PcInterfacePattern = 'PLCSIM'
    )
    <#  仿真联机入口: 切换在线网卡到 PLCSIM 虚拟网卡 -> GoOnline ->
        在线则下载。前提: PLCSIM 已启动且里面已有活动的虚拟 PLC 实例
        (Openness 没有"启动仿真"接口, 实例要先在 PLCSIM 里建好)。  #>
    [void](Set-TiaOnlineTargetInterface -DeviceIndex $DeviceIndex -PcInterfacePattern $PcInterfacePattern)
    $op = Get-TiaOnlineProvider -DeviceIndex $DeviceIndex
    $st = $op.GoOnline()
    Write-Host ("GoOnline => " + $st) -ForegroundColor $(if ("$st" -eq 'Online') { 'Green' } else { 'Yellow' })
    if ("$st" -eq 'Online') {
        $r = Invoke-TiaDownload -DeviceIndex $DeviceIndex -Options 'Software'
        Write-Host ("下载 State=" + $r.State + "  Errors=" + $r.ErrorCount + "  Warnings=" + $r.WarningCount)
        return $r
    }
    return $null
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
    # V21 的 Download 只剩三个重载:
    #   Download(DirectoryInfo, delegate)
    #   Download(IConfiguration, pre, post, DownloadOptions)
    #   Download(IConfiguration, ConfigurationAddress, pre, post, DownloadOptions)
    # 注意第一参是 IConfiguration, 不是 $provider.Configuration(ConnectionConfiguration),
    # 直接传后者会报 "找不到 Download 的重载，参数计数为 4"。
    # 所以这里先试 4 参形式, 不行就回退到最稳的 Download(DirectoryInfo, delegate)。
    $result = $null
    try {
        $downloadOptionsType = Get-TiaType('Siemens.Engineering.Download.DownloadOptions')
        $option = [System.Enum]::Parse($downloadOptionsType, $Options)
        $config = $downloadProvider.Configuration
        $result = $downloadProvider.Download($config, $null, $null, $option)
    } catch {
        # V21 的 Download(DirectoryInfo, delegate) 也要求 delegate 非空:
        #   "The argument 'preDownloadConfigurationDelegate' may not be null."
        # 从 PowerShell 造 DownloadConfigurationDelegate 很麻烦, 先用 Try/Catch 兜住,
        # 给出可操作的提示而不是难懂的重载错误。
        Write-Host ("  下载失败(V21 的 Download 两个重载都要求非空 delegate): " + $_.Exception.Message) -ForegroundColor Red
        $tmpDir = New-Object System.IO.DirectoryInfo([System.IO.Path]::GetTempPath())
        try { $result = $downloadProvider.Download($tmpDir, $null) }
        catch {
            throw ("V21 下载需要非空的 DownloadConfigurationDelegate 参数, PowerShell 侧无法直接构造。" +
                   "可行做法: (a) 先 Set-TiaOnlineTargetInterface 并 GoOnline 成功后再下载; " +
                   "(b) 下载这一步改用 TIA 界面/或写 C# 宿主程序用 `new DownloadConfigurationDelegate(handler)`。原始错误: " + $_.Exception.Message)
        }
    }
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
  <Engineering version="$script:XmlVersion" />
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
  <Engineering version="$script:XmlVersion" />
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
  <Engineering version="$script:XmlVersion" />
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
    # SCL/ST 必须有至少一个 CompileUnit, 否则导入报
    # "Language of 'SCL' have to have at least one compile unit."
    # 注意: xmlns 必须挂在 StructuredText 上; 挂到 NetworkSource 上会被拒(实测 V21):
    #   "Attribute 'NetworkSource' does not support xml attribute 'xmlns'"
    if ($ProgrammingLanguage -match '^(SCL|ST)$') {
        $unit = @"
      <SW.Blocks.CompileUnit ID="101" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource><StructuredText xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v1" UId="110"><Text UId="1110">// generated by TiaPortalSDK</Text></StructuredText></NetworkSource>
          <ProgrammingLanguage>$ProgrammingLanguage</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="102" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="103" CompositionName="Items">
                <AttributeList>
                  <Culture>$Culture</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
"@
        $xml = $xml.Replace('  </SW.Blocks.FC>', $unit + '  </SW.Blocks.FC>')
    }
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
    <#  V21 起 FC/OB 不再暴露 .Interface 属性($block.Interface 为 $null),
        改为"导出 XML -> 解析 Member", V19/V21 通用。  #>
    $block = Get-TiaBlock -Name $Name
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("iface_" + [System.Guid]::NewGuid().ToString('N') + ".xml")
    $exportOptionsType = Get-TiaType('Siemens.Engineering.ExportOptions')
    $opt = [System.Enum]::Parse($exportOptionsType, 'WithDefaults')
    $block.Export((New-Object System.IO.FileInfo($tmp)), $opt)
    $members = @()
    try {
        [xml]$doc = [System.IO.File]::ReadAllText($tmp, [System.Text.Encoding]::UTF8)
        foreach ($n in $doc.SelectNodes('//*[local-name()="Member"]')) {
            $nm = $n.GetAttribute('Name')
            $dt = $n.GetAttribute('Datatype')
            if ($nm) { $members += [PSCustomObject]@{ Name = $nm; Datatype = $dt } }
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
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
    <#  V21: PlcForceTableComposition 只有 Import/Find, 没有 Create
        (监视表 PlcWatchTableComposition 仍有 Create)。  #>
    $wfGroup = Get-TiaWatchAndForceTableGroup
    $ftComp = $wfGroup.ForceTables
    $hasCreate = $false
    foreach ($m in $ftComp.GetType().GetMethods()) { if ($m.Name -eq 'Create') { $hasCreate = $true } }
    if (-not $hasCreate) {
        throw ("Openness V21 的 PlcForceTableComposition 没有 Create 方法(只有 Import/Find) —— " +
               "力表不能用 Create 新建, 请用 ForceTables.Import(FileInfo, ImportOptions) 从 XML 导入, " +
               "或在 TIA 界面手工创建。")
    }
    $ft = $ftComp.Create($Name)
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
    # V21 要求归档前没有未保存改动, 否则报:
    #   "Operation is not possible while project has unsaved changes"
    try { $script:Project.Save() } catch { }
    if (-not (Test-Path $TargetDirectory)) { New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null }
    # 目标已存在时 TIA 的报错很含糊, 这里提前拦下:
    #   "Archive Operation is not possible as the target file/folder ... is already exist"
    # 最常见的触发原因: 归档名和工程目录同名且在同一个父目录下。
    $collide = Join-Path $TargetDirectory $ArchiveName
    if (Test-Path $collide) {
        throw ("归档目标 '$collide' 已存在(常见于归档名与工程目录同名/同处)。换个目录或换个归档名。")
    }
    $archivationModeType = Get-TiaType('Siemens.Engineering.ProjectArchivationMode')
    $modeValue = [System.Enum]::Parse($archivationModeType, $Mode)
    $targetDir = New-Object System.IO.DirectoryInfo($TargetDirectory)
    $script:Project.Archive($targetDir, $ArchiveName, $modeValue)
    # 注意: V21 的归档产物就叫 <ArchiveName>, 不带扩展名(V19 是 .zap19)
    $made = Join-Path $TargetDirectory $ArchiveName
    if (-not (Test-Path $made)) {
        $alt = Join-Path $TargetDirectory ("$ArchiveName.$($script:ArchiveExt)")
        if (Test-Path $alt) { $made = $alt }
    }
    Write-Host "Project archived to $made" -ForegroundColor Green
    return $made
}

function Restore-TiaProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ArchivePath,
        [Parameter(Mandatory=$true)]
        [string]$TargetDirectory
    )
    if (-not $script:TiaPortal) { throw "Not connected." }
    # V21 归档不带扩展名, V19 是 .zap19 —— 两种都试
    $path = $ArchivePath
    if (-not (Test-Path $path)) {
        $alt1 = "$ArchivePath.$($script:ArchiveExt)"
        if (Test-Path $alt1) { $path = $alt1 }
    }
    if (-not (Test-Path $path)) { throw "归档文件不存在: $ArchivePath" }
    if (-not (Test-Path $TargetDirectory)) { New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null }
    $archiveFi = New-Object System.IO.FileInfo($path)
    $restoreDir = New-Object System.IO.DirectoryInfo($TargetDirectory)
    # 集合不要 Unwrap(PowerShell 函数返回会展开集合)
    $projects = $script:TiaPortal.Projects
    $script:Project = $projects.Retrieve($archiveFi, $restoreDir)
    Write-Host "Project retrieved: $($script:Project.Name)" -ForegroundColor Green
    return $script:Project
}

function Get-TiaBlockReferences {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    <#  V21: FC/FB/OB 全都没有 GetReferences 方法了(V19 有)。
        V21 请改用 Siemens.Engineering.CrossReference 命名空间。  #>
    $block = Get-TiaBlock -Name $Name
    if (-not $block.GetType().GetMethod('GetReferences')) {
        throw ("Openness V21 已移除 GetReferences (" + $block.GetType().Name + " 上没有此方法)。" +
               "V21 请用 Siemens.Engineering.CrossReference 命名空间(CrossReferenceProvider / CrossReferenceComposition)。")
    }
    $refs = $block.GetReferences()
    $result = @()
    foreach ($ref in $refs) { $result += $ref.ToString() }
    return $result
}

function Find-TiaProjects {
    param(
        [string[]]$SearchDirs = $null,
        [int]$MaxDepth = 5
    )
    if (-not $SearchDirs) {
        # 通用默认搜索目录。要个性化请设环境变量 TIA_PROJECT_SEARCH_DIRS(分号分隔), 例如:
        #   [Environment]::SetEnvironmentVariable('TIA_PROJECT_SEARCH_DIRS','D:\我的工程;E:\PLC','User')
        $SearchDirs = @(
            'D:\Projects',
            'D:\work',
            'D:\Siemens',
            (Join-Path $env:USERPROFILE 'Documents\Automation')
        )
        if ($env:TIA_PROJECT_SEARCH_DIRS) {
            $SearchDirs = @($env:TIA_PROJECT_SEARCH_DIRS.Split(';') | Where-Object { "$_".Trim() -ne '' })
        }
    }
    $results = @()
    # 按本机实际安装的版本决定扫描哪些工程扩展名 (ap19 / ap21 ...)
    $exts = @('.ap19', '.ap20', '.ap21')
    $detected = @(Get-TiaInstallations)
    if ($detected) { $exts = @($detected | ForEach-Object { '.ap' + $_.Version }) }
    foreach ($dir in $SearchDirs) {
        if (Test-Path $dir) {
            Write-Host "Scanning: $dir  ($($exts -join ', '))" -ForegroundColor DarkGray
            Get-ChildItem -Path $dir -Recurse -Depth $MaxDepth -File -ErrorAction SilentlyContinue |
                Where-Object { $exts -contains $_.Extension } | ForEach-Object {
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
