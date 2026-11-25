#requires -Version 5.1
<#
.SYNOPSIS
  Launch the T-120 playtest engine in the Last Stand test copy.

.DESCRIPTION
  Enables the validated T-117 deploy guard hold, the T-116 alternate-leader
  candidate, the T-122 width-6 cluster/portal corridor, the T-124 repeated
  formation-request cache and the T-127 width-6 group kernel commit for local
  singleplayer. These change routes (no exact replay parity) but cut the
  benchmark replay from 74.76 to 31.92 ms mean and the 16,978-17,402 window from
  142.84 to 43.98 ms. The T-118 occupant cache is left off because it was
  correct but not faster on the measured workload.

  Run with -Restore to put the retail executable back.
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [ValidateSet('borderless', 'windowed', 'exclusive')][string]$Mode = 'windowed',
    [ValidateSet('0', '1')][string]$DeployedAvoid = '1',
    [ValidateSet('0', '1')][string]$LongRangeVision = '1',
    [switch]$Restore,
    [switch]$DryRun,
    [switch]$NoFPSLimit,
    [switch]$FormationLog,
    [switch]$Performance,
    [ValidateSet('100', '66', '33', '0')][string]$AllyCost = '33',
    [string]$Record = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $GameDir) { $GameDir = Join-Path $repo 'game\last-stand-replay' }
if (-not (Test-Path -LiteralPath $GameDir)) { throw "Game directory not found: $GameDir" }
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
$exe = Join-Path $GameDir 'Generals.exe'
$backup = Join-Path $GameDir 'Generals.exe.original'
if ($Restore) {
    if (-not (Test-Path -LiteralPath $backup)) { throw "No executable backup: $backup" }
    Copy-Item -LiteralPath $backup -Destination $exe -Force
    Write-Host ("Restored {0} ({1})" -f $exe, (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash)
    exit 0
}
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe not found: $exe" }
$testEnv = @{
    ZH_DEPLOY_GUARD_HOLD  = '1'   # T-117: deployed guard units hold position
    ZH_GROUP_START_RELAX  = '1'   # T-116 candidate: alternate clear group leader
    ZH_PF_OCCUPANT_CACHE  = '0'   # T-118 cache was not faster; keep the control path
    ZH_DEPLOYED_AVOID     = $DeployedAvoid
    ZH_LONG_RANGE_VISION  = $LongRangeVision
    ZH_HPA_CORRIDOR       = '1'   # T-122: width-6 cluster/portal corridor (route-changing)
    ZH_GROUP_PATH_CACHE_TTL = '20' # T-124: reuse an exact repeated group request for 20 frames
    ZH_CLOSEST_MAX_EXPANSIONS = '4000' # T-127: bound closest-reachable outlier searches
    ZH_GROUP_KERNEL_REPLACE = '1' # T-127: validated width-6 kernel route, serial fallback
}
if ($Record) {
    # T-112: record a live skirmish so the 33% feel can be measured in a match that is
    # deliberately prolonged (the replay variant resolves early and never reaches the heavy window).
    New-Item -ItemType Directory -Force -Path $Record | Out-Null
    $Record = (Resolve-Path -LiteralPath $Record).Path
    $testEnv['ZH_ATTR_LOG'] = Join-Path $Record 'attr.csv'
    $testEnv['ZH_PF_FRAME'] = Join-Path $Record 'pf-frame.csv'
    $testEnv['ZH_PERF_LOG'] = Join-Path $Record 'frames.csv'
    $testEnv['ZH_CALIB_LOG'] = Join-Path $Record 'calib.csv'
    $testEnv['ZH_GROUP_KERNEL_SYNC'] = Join-Path $Record 'sync.csv'
    # Scene split also logs the per-frame visible-object count, which is the load proxy used to
    # define the "high unit count" window in a live match.
    $testEnv['ZH_SCENE_SPLIT'] = Join-Path $Record 'scene-split.csv'
    Write-Host ("Recording live metrics to {0}" -f $Record) -ForegroundColor Yellow
}
if ($AllyCost -ne '100') {
    # T-112: friendly-crowd congestion price (retail 100). Lower values make units take straighter
    # lines and bunch up more. 66 measured heavy 30.06 ms / 33.3 FPS vs 36.80 retail and is the
    # benchmark value; 33 is the user's chosen playtest feel (livelier, denser swarms) but resolves
    # the benchmark battle early, so it is judged by feel and live play, not the replay gate.
    $testEnv['ZH_ALLY_COST_PCT'] = $AllyCost
    Write-Host ("Ally congestion cost: {0}% of retail" -f $AllyCost) -ForegroundColor Yellow
}
if ($Performance) {
    # T-112 opt-in visual-trade profile. Measured on the GTX 1650 Ti through the d3d8to9 proxy:
    # heavy window 34.59 ms / 28.9 FPS vs 36.80 / 27.2 with full visuals, whole run 37.4 vs 34.7 FPS.
    # It suppresses behind-building/occluded rendering, volumetric shadows and particles, so it is
    # a visual trade and stays opt-in (ZIP: choose full visuals by omitting -Performance).
    $testEnv['ZH_SKIP_OCCLUDED']    = '1'
    $testEnv['ZH_SKIP_VOLUMETRIC']  = '1'
    $testEnv['ZH_SKIP_PARTICLES']   = '1'
    Write-Host 'Performance profile: occluded/behind-building rendering, volumetric shadows and particles are OFF (visual trade).' -ForegroundColor Yellow
}
if ($FormationLog) {
    # launch-game.ps1 clears inherited ZH_* variables, so the log path must be
    # passed through TestEnv. The playtest build logs frames 16,978-17,277 only.
    $logPath = Join-Path $repo 'artifacts\live-formation-commands.csv'
    $testEnv['ZH_FORMATION_COMMANDS'] = $logPath
    Write-Host ("Formation command log: {0}" -f $logPath)
}
Write-Host ("Playtest engine: {0}" -f (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash)
Write-Host ("Switches: " + (($testEnv.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' '))
& (Join-Path $PSScriptRoot 'launch-game.ps1') -GameDir $GameDir -Mode $Mode -Width 1920 -Height 1080 `
    -QuickStart -NoFPSLimit:$NoFPSLimit -TestEnv $testEnv -DryRun:$DryRun
