#requires -Version 5.1
<#
.SYNOPSIS
  Watchable dense-army nuke cycles: spawn N tanks, nuke them, repeat (T-048).

.DESCRIPTION
  Starts the optimized ShockWave engine, spawns a dense square grid of tanks and then runs
  spawn -> real-nuke salvo cycles. The game is left running so you can watch it; close the
  game when you are done. Frame times and combat logs are written to the output folder.

  A single NeutronMissile warhead only kills within ~210 units, so a 1,000-tank formation
  (about 930 x 930 at 30-unit spacing) needs a salvo to be wiped. Nine warheads is the
  default; lower -Warheads for a lighter, more "single nuke" feel.

.PARAMETER Units
  Tanks per cycle (default 1000).

.PARAMETER Spacing
  Distance between tank centres in world units (default 30; a BattleMaster is 26 long).
  Do not rely on auto-spacing: ChinaTankBattleMaster has no Geometry block in the mod INI.

.PARAMETER Cycles
  Spawn -> nuke cycles (default 5).

.PARAMETER CycleInterval
  Logic frames between spawns (default 240 = 8 s at 30 FPS). The nuke fires half-way.

.PARAMETER Warheads
  Real NeutronMissile warheads per cycle (default 9).

.PARAMETER WarheadSpread
  Warheads land randomly within +/- this distance of the camera (default 400).

.EXAMPLE
  .\tools\demo-shockwave-army-nuke.ps1

.EXAMPLE
  .\tools\demo-shockwave-army-nuke.ps1 -Units 1000 -Warheads 1
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [int]$Units = 1000,
    [switch]$ExperimentalSingleplayer,
    [double]$Spacing = 30,
    [int]$Cycles = 5,
    [int]$CycleInterval = 240,
    [int]$Warheads = 9,
    [double]$WarheadSpread = 400,
    [string]$UnitTemplate = 'ChinaTankBattleMaster',
    [switch]$Loop,
    [string]$OutputDir = ''
)

if ($Loop) { $Cycles = 1000 }

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-engine' }
if (-not $OutputDir) { $OutputDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\shockwave-watch' }

$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
if (-not (Test-Path -LiteralPath $GameDir)) { throw "Game copy not found: $GameDir. Run tools\prepare-shockwave-copy.ps1 first." }
$exe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe missing in $GameDir" }
if ($Spacing -lt 8) { throw "Spacing $Spacing is too small; tanks will stack and drop to ~1 FPS." }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$res = (Resolve-Path -LiteralPath $OutputDir).Path

Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
& (Join-Path $PSScriptRoot 'set-gpu-preference.ps1') -ExePath $exe -Action Enable | Out-Null

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
    ZH_DEBRIS_PER_FRAME = '0'
    ZH_HULK_PER_FRAME = '0'
    ZH_DEBRIS_BROADPHASE = [string][int][bool]$ExperimentalSingleplayer
    ZH_DEBRIS_PAIR_FILTER = '0'
    ZH_PERF_LOG = (Join-Path $res 'perf.csv')
    ZH_PERF_LOGIC = (Join-Path $res 'logic.csv')
    ZH_OBJLOG = (Join-Path $res 'objects.log')
}
Remove-Item (Join-Path $GameDir 'stress.log') -ErrorAction SilentlyContinue

Write-Host ("Army: {0} x {1}, spacing {2}, cycles {3}, {4} warheads per cycle" -f $Units, $UnitTemplate, $Spacing, $Cycles, $Warheads)
& (Join-Path $PSScriptRoot 'launch-game.ps1') -GameDir $GameDir -Mode borderless -QuickStart -NoFPSLimit -TestEnv $testEnv -ExperimentalSingleplayer:$ExperimentalSingleplayer

# Map 1920x1080 shell coordinates onto the game's actual client area (DPI/window size can vary).
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ArmyClick {
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
    if (-not $proc) { throw "No Generals window" }
    $h = $proc.MainWindowHandle
    # Restore/focus BEFORE measuring: ui-click also restores, which can resize a 1536x816
    # DPI-virtualized window to 1920x1080 and invalidate precomputed coordinates.
    [ArmyClick]::ShowWindow($h, 9) | Out-Null
    [ArmyClick]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 2500
    $r = New-Object ArmyClick+RECT
    [ArmyClick]::GetClientRect($h, [ref]$r) | Out-Null
    $prev = "{0}x{1}" -f $r.R, $r.B
    # The window can resize once more after regaining focus; wait until the size is stable.
    for ($i = 0; $i -lt 4; $i++) {
        Start-Sleep -Milliseconds 700
        [ArmyClick]::GetClientRect($h, [ref]$r) | Out-Null
        $now = "{0}x{1}" -f $r.R, $r.B
        if ($now -eq $prev) { break }
        $prev = $now
    }
    $p = New-Object ArmyClick+POINT
    [ArmyClick]::ClientToScreen($h, [ref]$p) | Out-Null
    $x = [int]($p.X + $logicalX * $r.R / 1920.0)
    $y = [int]($p.Y + $logicalY * $r.B / 1080.0)
    Write-Host ("client {0}x{1} -> logical ({2},{3}) at ({4},{5})" -f $r.R, $r.B, $logicalX, $logicalY, $x, $y)
    & (Join-Path $PSScriptRoot 'ui-click.ps1') -X $x -Y $y -DelayMs 2500
}

Start-Sleep -Seconds 18
# The first focus restore resizes the DPI-virtualized window to 1920x1080, so focus once on a
# neutral corner before measuring the menu coordinates.
& (Join-Path $PSScriptRoot 'ui-click.ps1') -X 5 -Y 5 -DelayMs 800
Start-Sleep -Milliseconds 1200
Click-Shell 1450 212   # Solo Play
Click-Shell 1450 507   # Skirmish
Click-Shell 437 940    # Play

$deadline = (Get-Date).AddSeconds(45)
$log = Join-Path $GameDir 'stress.log'
while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $log)) { Start-Sleep -Seconds 2 }
if (Test-Path -LiteralPath $log) {
    Start-Sleep -Seconds 2
    Get-Content -LiteralPath $log
} else {
    Write-Host "Match did not start from the scripted clicks." -ForegroundColor Yellow
    Write-Host "Click SOLO PLAY -> SKIRMISH -> PLAY yourself; the scenario is armed and will start on the first game frame." -ForegroundColor Yellow
}
Write-Host "Game is running - watch the cycles. Close the game when done." -ForegroundColor Green
Write-Host "Logs: $res"
