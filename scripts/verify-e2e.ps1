<#
  端到端验证: 把旧版本 TIA 工程自动升级到当前版本, 并枚举设备/块/标签表 + 编译。

  用法:
    powershell -NoProfile -ExecutionPolicy Bypass -File verify-e2e.ps1 `
        -ProjectPath "D:\proj\项目1\项目1.ap19"

  注意:
    * 会先保存并关闭 TIA 里已打开的工程(同时只能开一个工程)
    * 升级不改原工程, 会在同级目录生成 <原名>_V21\ 与 <原名>_V21.backup\
    * 建议先复制一份工程再跑, 别直接拿工作目录里的原件试
#>
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$PortalVersion = '21',
    [string]$LogPath
)

$ErrorActionPreference = 'Continue'
if (-not $LogPath) { $LogPath = Join-Path (Split-Path $ProjectPath -Parent) 'e2e.log' }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Start-Transcript -Path $LogPath -Force | Out-Null

function Step($m) { Write-Host ''; Write-Host ("===== $m =====") -ForegroundColor Cyan }
function TryStep($m, $sb) {
    Step $m
    try { & $sb } catch {
        Write-Host ("  !! FAILED: " + $_.Exception.Message) -ForegroundColor Red
        if ($_.Exception.InnerException) { Write-Host ("     inner: " + $_.Exception.InnerException.Message) -ForegroundColor Red }
    }
}

# 点源必须在顶层 —— 放进 & {} 子作用域会导致函数定义被销毁
$sdk = Join-Path (Split-Path $PSScriptRoot -Parent) 'TiaPortalSDK.ps1'
. $sdk
Write-Host ("SDK: $sdk")
Write-Host ("开始: " + (Get-Date -Format 'HH:mm:ss'))

# 注意: 不要把自己的变量叫 TiaVersion —— SDK 的 $script:TiaVersion 会把它覆盖掉
TryStep "连接 TIA Portal V$PortalVersion" {
    [void](Connect-TiaPortal -TiaVersion $PortalVersion)
    Write-Host ("  Openness V" + $script:TiaVersion + " 已连接")
}

TryStep "打开并升级工程 (OpenWithUpgrade)" {
    [void](Get-TiaProject -ProjectPath $ProjectPath -Upgrade)
    Write-Host ("  工程名     = " + $script:Project.Name)
    Write-Host ("  升级后路径 = " + $script:Project.Path)
}

TryStep '枚举设备' {
    $devs = @()
    foreach ($d in $script:Project.Devices) { $o = $d; if ($o -is [System.Management.Automation.PSObject]) { $o = $o.BaseObject }; $devs += $o }
    Write-Host ("  设备数 = " + $devs.Count)
    foreach ($o in $devs) { Write-Host ("    - " + $o.Name + '  |  ' + $o.TypeIdentifier) }
    if ($devs.Count -eq 0) { Write-Host '  (空工程, 后面 PLC 相关步骤会失败, 属正常)' -ForegroundColor Yellow }
}

TryStep '获取 PLC 软件' {
    [void](Get-TiaPlcSoftware -DeviceIndex 0)
    Write-Host ("  PLC 软件 = " + $script:Software.Name)
}

TryStep '枚举程序块' {
    $blocks = @(Get-TiaBlocks -IncludeDetails)
    Write-Host ("  块数 = " + $blocks.Count)
    $blocks | Select-Object Name, Number, Language | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

TryStep '枚举标签表' {
    $tabs = @(Get-TiaTagTables)
    Write-Host ("  标签表数 = " + $tabs.Count)
    $tabs | Select-Object Name | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

TryStep '编译 PLC 软件' { Invoke-TiaCompile }
TryStep '保存工程' { Save-TiaProject }
TryStep '关闭工程' { if ($script:Project) { $script:Project.Close(); Write-Host '  已关闭' } }
TryStep '断开连接' { Disconnect-TiaPortal }

Write-Host ''
Write-Host ("结束: " + (Get-Date -Format 'HH:mm:ss'))
Write-Host ("日志: $LogPath")
Stop-Transcript | Out-Null
