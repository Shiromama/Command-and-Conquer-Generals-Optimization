#requires -Version 5.1
<#
.SYNOPSIS
  Scripted ShockWave nuke demo: 1,000-unit wipe with the T-043 partition fix.

.DESCRIPTION
  Launches the optimized engine copy, starts a China Nuke General skirmish through the UI,
  spawns a tank army and detonates nukes around the camera, then captures a frame series and
  a GIF plus frame-time/census summaries.

  Defaults reflect the performance profile: all debris kept (budgets 0), d3d8to9 +
  high-performance GPU preference.

.PARAMETER GameDir
  Engine copy (default: game\shockwave-engine).

.PARAMETER Units
  Tanks spawned (default 1000).

.PARAMETER CaptureSeconds
  Duration of the frame series after the match loads (default 14).

.PARAMETER CaptureIntervalMs
  Interval between captures (default 600).

.EXAMPLE
  .\tools\demo-shockwave-nukes.ps1
#>
[CmdletBinding()]
param(
    [string]$GameDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-engine'),
    [int]$Units = 400,
    [string]$UnitTemplate = 'ChinaTankBattleMaster',
    [string]$FxName = 'FX_Nuke',
    [switch]$MaxGameSpeed,
    [int]$NukeCount = 1,
    [int]$NukeInterval = 90,
    [int]$Damage = 2000,
    [int]$Radius = 300,
    [double]$CaptureSeconds = 10,
    [int]$CaptureIntervalMs = 400,
    [double]$StartDelaySeconds = 4,
    [string]$OutputDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\shockwave-demo')
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $GameDir)) { throw "Game copy not found: $GameDir. Run tools\prepare-shockwave-copy.ps1 first." }
$exe = Join-Path $GameDir 'Generals.exe'
$d3d8 = Join-Path $GameDir 'd3d8.dll'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe missing in $GameDir" }
if (-not (Test-Path -LiteralPath $d3d8)) { throw "d3d8.dll missing in $GameDir (expected d3d8to9)" }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$framesDir = Join-Path $OutputDir 'frames'
New-Item -ItemType Directory -Force -Path $framesDir | Out-Null
Get-ChildItem -LiteralPath $framesDir -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

$res = (Resolve-Path -LiteralPath $OutputDir).Path
$testEnv = @{
    ZH_STRESS = [string]$Units
    ZH_STRESS_RESPAWN = '0'
    ZH_NUKEFX = [string]$NukeCount
    ZH_NUKEFX_INTERVAL = [string]$NukeInterval
    ZH_NUKEFX_DAMAGE = [string]$Damage
    ZH_NUKEFX_RADIUS = [string]$Radius
    ZH_DEBRIS_PER_FRAME = '0'
    ZH_HULK_PER_FRAME = '0'
    ZH_PERF_LOG = (Join-Path $res 'perf.csv')
    ZH_OBJLOG = (Join-Path $res 'objects.log')
    ZH_PERF_LOGIC = (Join-Path $res 'logic-phases.csv')
}

Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
& (Join-Path $PSScriptRoot 'set-gpu-preference.ps1') -ExePath $exe -Action Enable | Out-Null

Write-Host "Launching demo: $Units units, $NukeCount nukes / $NukeInterval frames, radius $Radius"
& (Join-Path $PSScriptRoot 'launch-game.ps1') -GameDir $GameDir -Mode borderless -QuickStart -TestEnv $testEnv
Start-Sleep -Seconds 16
& (Join-Path $PSScriptRoot 'capture-game-window.ps1') -Path (Join-Path $OutputDir '00-menu.png')

# Menu coordinates at 1920x1080 (ShockWave 3-pane menu / skirmish screen).
& (Join-Path $PSScriptRoot 'ui-click.ps1') -X 1450 -Y 212 -DelayMs 2200
& (Join-Path $PSScriptRoot 'ui-click.ps1') -X 1450 -Y 507 -DelayMs 2500
& (Join-Path $PSScriptRoot 'ui-click.ps1') -X 437 -Y 940 -DelayMs 1500
Write-Host "Match starting; high-rate capture for $CaptureSeconds s ..."
Start-Sleep -Seconds $StartDelaySeconds
& (Join-Path $PSScriptRoot 'capture-game-burst.ps1') -Path $framesDir -DurationSeconds $CaptureSeconds -Fps 12 -Width 960

Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force

# --- summary -----------------------------------------------------------------
$perf = Join-Path $res 'perf.csv'
if (Test-Path -LiteralPath $perf) {
    python (Join-Path $PSScriptRoot 'analyze-perf-log.py') $perf --skip 900 --label 'demo frames' |
        Tee-Object -FilePath (Join-Path $res 'summary.txt')
}
$objects = Join-Path $res 'objects.log'
if (Test-Path -LiteralPath $objects) {
    $peak = Get-Content -LiteralPath $objects |
        ForEach-Object { if ($_ -match 'hulks=(\d+) debris=(\d+)') { [pscustomobject]@{ h = [int]$Matches[1]; d = [int]$Matches[2] } } } |
        Sort-Object { $_.h + $_.d } -Descending | Select-Object -First 1
    if ($peak) { "peak objects: hulks=$($peak.h) debris=$($peak.d)" | Tee-Object -FilePath (Join-Path $res 'summary.txt') -Append }
}
$phases = Join-Path $res 'logic-phases.csv'
if (Test-Path -LiteralPath $phases) {
    python (Join-Path $PSScriptRoot 'analyze-split-log.py') $phases --label 'logic phases (partition is column 4)' |
        Tee-Object -FilePath (Join-Path $res 'summary.txt') -Append
}

# --- GIF ---------------------------------------------------------------------
$gif = Join-Path $res 'shockwave-nukes.gif'
try {
    @'
import sys, glob
from pathlib import Path
from PIL import Image
frames_dir, out = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(str(Path(frames_dir) / 'frame*.png')))
if not files:
    print('no frames'); sys.exit(0)
imgs = []
for f in files:
    im = Image.open(f).convert('RGB').resize((960, 540), Image.LANCZOS)
    imgs.append(im)
# 4 fps, hold each frame ~250 ms
imgs[0].save(out, save_all=True, append_images=imgs[1:], duration=100, loop=0, optimize=True)
print(f'gif: {out} ({len(imgs)} frames)')
'@ | Set-Content -Encoding UTF8 (Join-Path $res '_gif.py')
    python (Join-Path $res '_gif.py') $framesDir $gif
} catch {
    Write-Warning "GIF assembly failed: $_"
}

Write-Host "Demo output: $res" -ForegroundColor Green
