#requires -Version 5.1
<#
.SYNOPSIS
  Run a ShockWave army/nuke scenario with frame-attribution logging and stop the game afterwards.

.DESCRIPTION
  The ShockWave auto-start path crashes before the mod's player templates resolve (EXP-008 §6),
  so the match is started with the same scripted UI clicks the demo uses. This script differs
  from demo-shockwave-army-nuke.ps1 in three ways:

    - it always writes ZH_ATTR_LOG (T-051 frame attribution) alongside ZH_PERF_LOG;
    - it stops the game when the measured window ends, so runs can be repeated unattended;
    - it accepts arbitrary extra harness variables through -ExtraEnv.

  The attribution row is written from the engine's own loop, so the numbers are directly
  comparable across runs of the same binary. Do not change resolution or the options profile
  between A/B runs.

.PARAMETER Units
  Tanks spawned per cycle (default 1000).

.PARAMETER Cycles
  Spawn -> nuke cycles (default 1).

.PARAMETER CycleInterval
  Logic frames between spawns (default 240).

.PARAMETER Warheads
  Real NeutronMissile warheads per cycle (default 1).

.PARAMETER DebrisPerFrame
  ZH_DEBRIS_PER_FRAME. -1 leaves the engine default (unlimited).

.PARAMETER ExtraEnv
  Additional harness variables, e.g. @{ ZH_ATTR_SAMPLE = '1' }.

.EXAMPLE
  .\tools\benchmark-shockwave-attrib.ps1 -Warheads 1 -ExtraEnv @{ ZH_ATTR_SAMPLE='1' }
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [int]$Units = 1000,
    [switch]$ExperimentalSingleplayer,
    [double]$Spacing = 30,
    [int]$Cycles = 1,
    [int]$CycleInterval = 240,
    [int]$Warheads = 1,
    [double]$WarheadSpread = 400,
    [string]$UnitTemplate = 'ChinaTankBattleMaster',
    [int]$WarmupSeconds = 25,
    [int]$RunSeconds = 45,
    [int]$DebrisPerFrame = -1,
    [hashtable]$ExtraEnv = @{},
    [string]$Label = 'attr',
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-engine' }

$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
if (-not $OutputDir) {
    $OutputDir = Join-Path $repo ("artifacts\{0}-shockwave-{1}" -f (Get-Date -Format 'yyyy-MM-dd'), (Get-Date -Format 'HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$res = (Resolve-Path -LiteralPath $OutputDir).Path

$exe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe missing in $GameDir" }


$testEnv = @{
    ZH_STRESS = [string]$Units
    ZH_STRESS_MAX = [string]$Units
    ZH_STRESS_TEMPLATE = $UnitTemplate
    ZH_STRESS_DENSE = '1'
    ZH_STRESS_SPACING = [string]$Spacing
    ZH_STRESS_CYCLES = [string]$Cycles
    ZH_STRESS_CYCLE_INTERVAL = [string]$CycleInterval
    ZH_REALNUKE = 'NeutronMissileDUMMYObject'
    ZH_NUKEFX = [string]$Warheads
    ZH_NUKEFX_RADIUS = [string]$WarheadSpread
    ZH_NUKEFX_INTERVAL = [string]$CycleInterval
    ZH_NUKEFX_OFFSET = [string][int]($CycleInterval / 2)
    ZH_DEBRIS_BROADPHASE = [string][int][bool]$ExperimentalSingleplayer
    ZH_DEBRIS_PAIR_FILTER = '0'
    ZH_PERF_LOG = (Join-Path $res 'perf.csv')
    ZH_PERF_LOGIC = (Join-Path $res 'logic.csv')
    ZH_ATTR_LOG = (Join-Path $res 'attr.csv')
    ZH_OBJLOG = (Join-Path $res 'objects.log')
    ZH_OCL_LOG = (Join-Path $res 'ocl.log')
}
if ($DebrisPerFrame -ge 0) { $testEnv['ZH_DEBRIS_PER_FRAME'] = [string]$DebrisPerFrame }
foreach ($k in $ExtraEnv.Keys) { $testEnv[$k] = [string]$ExtraEnv[$k] }

# Reject experimental inputs before stopping a process or writing game state.
if (-not $ExperimentalSingleplayer) {
    foreach ($key in @('ZH_DEBRIS_BROADPHASE','ZH_DEBRIS_PAIR_FILTER','ZH_DEBRIS_PER_FRAME','ZH_HULK_PER_FRAME')) {
        if ($testEnv.ContainsKey($key) -and [int]$testEnv[$key] -gt 0) { throw "$key requires -ExperimentalSingleplayer" }
    }
}
Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$meta = [pscustomobject]@{
    label = $Label
    started_at = (Get-Date).ToString('o')
    game_dir = (Resolve-Path -LiteralPath $GameDir).Path
    exe_sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    units = $Units; spacing = $Spacing; cycles = $Cycles; cycle_interval = $CycleInterval
    warheads = $Warheads; debris_per_frame = $DebrisPerFrame
    warmup_seconds = $WarmupSeconds; run_seconds = $RunSeconds
    env = ($testEnv | ConvertTo-Json -Compress)
}
$meta | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $res 'run-parameters.json')

Remove-Item (Join-Path $GameDir 'stress.log') -ErrorAction SilentlyContinue
& (Join-Path $PSScriptRoot 'launch-game.ps1') -GameDir $GameDir -Mode borderless -QuickStart -NoFPSLimit -TestEnv $testEnv -ExperimentalSingleplayer:$ExperimentalSingleplayer

# --- scripted UI start (same fixed 1920x1080 layout as the demo) -------------------------------
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class AttribClick {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    public struct RECT { public int L, T, R, B; }
    public struct POINT { public int X, Y; }
}
"@
function Click-Shell([int]$logicalX, [int]$logicalY) {
    $proc = Get-Process -Name generals -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $proc) { throw 'No Generals window' }
    $h = $proc.MainWindowHandle
    [AttribClick]::ShowWindow($h, 9) | Out-Null
    [AttribClick]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 2500
    $r = New-Object AttribClick+RECT
    [AttribClick]::GetClientRect($h, [ref]$r) | Out-Null
    $prev = '{0}x{1}' -f $r.R, $r.B
    for ($i = 0; $i -lt 4; $i++) {
        Start-Sleep -Milliseconds 700
        [AttribClick]::GetClientRect($h, [ref]$r) | Out-Null
        $now = '{0}x{1}' -f $r.R, $r.B
        if ($now -eq $prev) { break }
        $prev = $now
    }
    $p = New-Object AttribClick+POINT
    [AttribClick]::ClientToScreen($h, [ref]$p) | Out-Null
    $x = [int]($p.X + $logicalX * $r.R / 1920.0)
    $y = [int]($p.Y + $logicalY * $r.B / 1080.0)
    & (Join-Path $PSScriptRoot 'ui-click.ps1') -X $x -Y $y -DelayMs 2500
}

Start-Sleep -Seconds 18
& (Join-Path $PSScriptRoot 'ui-click.ps1') -X 5 -Y 5 -DelayMs 800
Start-Sleep -Milliseconds 1200
Click-Shell 1450 212   # Solo Play
Click-Shell 1450 507   # Skirmish
Click-Shell 437 940    # Play

$deadline = (Get-Date).AddSeconds(45)
$log = Join-Path $GameDir 'stress.log'
while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $log)) { Start-Sleep -Seconds 2 }
$startedAtFrame = $null
if (Test-Path -LiteralPath $log) {
    $startedAtFrame = ((Get-Content -LiteralPath $log -TotalCount 1) -replace '.*frame=(\d+).*', '$1')
    Write-Host ("Match started (logic frame {0}). Warmup {1}s, measured {2}s." -f $startedAtFrame, $WarmupSeconds, $RunSeconds)
} else {
    Write-Warning 'Match did not start from the scripted clicks; logs will be incomplete.'
}

Start-Sleep -Seconds ($WarmupSeconds + $RunSeconds)
$proc = Get-Process -Name generals -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) { Stop-Process -Id $proc.Id -Force; Write-Host 'Game stopped.' }
Start-Sleep -Seconds 2

$result = [pscustomobject]@{
    label = $Label
    output_dir = $res
    perf_rows = if (Test-Path (Join-Path $res 'perf.csv')) { (Get-Content (Join-Path $res 'perf.csv')).Count - 1 } else { 0 }
    attr_rows = if (Test-Path (Join-Path $res 'attr.csv')) { (Get-Content (Join-Path $res 'attr.csv')).Count - 1 } else { 0 }
    logic_rows = if (Test-Path (Join-Path $res 'logic.csv')) { (Get-Content (Join-Path $res 'logic.csv')).Count - 1 } else { 0 }
}
$result | ConvertTo-Json | Set-Content (Join-Path $res 'run-result.json')
$result | Format-List
Write-Host "Artifacts: $res"
