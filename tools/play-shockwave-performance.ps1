#requires -Version 5.1
<#
.SYNOPSIS
  Launch ShockWave on the optimized engine and the discrete GPU.

.DESCRIPTION
  One-command performance profile for singleplayer/skirmish:

    1. creates game\shockwave-engine from the read-only mod install if missing
       (materialises .gib -> .big; the install is never modified),
    2. installs the current built engine (GenTool disabled),
    3. installs d3d8to9 as d3d8.dll and enables the per-app High-performance
       GPU preference (required on hybrid laptops; D3D8 alone only sees the iGPU),
    4. launches borderless at the requested resolution.

  Use this profile for solo play. For SWR.net/C&C Online, keep the normal
  ShockWave launcher and run it with the Windowed option + GenTool window FULL
  (see docs/issues/ISSUE-0011-...): that avoids the exclusive-fullscreen
  Alt+Tab crash, at the cost of staying on the Intel GPU.

.PARAMETER GameDir
  Copy to use (default: game\shockwave-engine).

.PARAMETER BuiltExe
  Engine to install (default: build\engine-vs-community\GeneralsMD\Release\generalszh.exe).

.PARAMETER Width / Height
  Borderless client size (default 1920x1080).

.PARAMETER NoGPUPreference
  Do not touch HKCU (e.g. if the user manages GPU choice in the NVIDIA panel).

.PARAMETER DebrisPerFrame
  Optional cosmetic debris budget per logic frame (default 0 = keep every debris).

.PARAMETER HulkPerFrame
  Optional dead-vehicle hulk budget per logic frame (default 0 = keep every hulk).

.PARAMETER DebrisPairFilter
  1 keeps cell membership but drops debris-vs-debris and NO_COLLIDE collision pairs;
  0 (default) restores full pair generation.

.PARAMETER DebrisBroadphase
  1 (experimental singleplayer only) rejects collision pairs whose 3D bounding spheres do not overlap before
  hashing/allocation. Conservative: keeps every collision and therefore all physics.

.PARAMETER DryRun
  Print what would happen without copying, staging or launching.

.EXAMPLE
  .\tools\play-shockwave-performance.ps1
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [string]$BuiltExe = '',
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$DebrisPerFrame = 0,
    [int]$HulkPerFrame = 0,
    [int]$DebrisPairFilter = 0,
    [int]$DebrisBroadphase = 0,
    [switch]$NoGPUPreference,
    [switch]$WithFpsLimit,
    [switch]$ExperimentalSingleplayer,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-engine' }
if (-not $BuiltExe) { $BuiltExe = Join-Path (Split-Path -Parent $PSScriptRoot) 'build\engine-vs-community\GeneralsMD\Release\generalszh.exe' }

if (-not $ExperimentalSingleplayer -and ($DebrisBroadphase -ne 0 -or $DebrisPairFilter -ne 0 -or $DebrisPerFrame -ne 0 -or $HulkPerFrame -ne 0)) {
    throw 'Simulation-changing settings require -ExperimentalSingleplayer.'
}
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir -SourcePaths @($BuiltExe)

$wrapperCache = Join-Path $repo 'artifacts\d3d8to9\d3d8-1.16.0.dll'

if (-not (Test-Path -LiteralPath $GameDir)) {
    Write-Host "Creating $GameDir from the mod install ..."
    if (-not $DryRun) {
        & (Join-Path $PSScriptRoot 'prepare-shockwave-copy.ps1') -GameDir $GameDir
    }
}

if (-not (Test-Path -LiteralPath $BuiltExe)) {
    throw "Built engine not found: $BuiltExe. Build it with tools\build-engine.ps1 first."
}
$builtHash = (Get-FileHash -LiteralPath $BuiltExe -Algorithm SHA256).Hash

$installed = Join-Path $GameDir 'Generals.exe'
$installedHash = if (Test-Path -LiteralPath $installed) { (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash } else { $null }
if ($installedHash -ne $builtHash) {
    Write-Host "Installing engine $($builtHash.Substring(0,16)) ..."
    if (-not $DryRun) {
        # -WithGenTool only means "do not move an existing d3d8.dll": the wrapper below is
        # installed deliberately and GenTool itself is not present in this copy.
        & (Join-Path $PSScriptRoot 'stage-engine.ps1') -GameDir $GameDir -BuiltExe $BuiltExe -WithGenTool
    }
} else {
    Write-Host "Engine already current: $($builtHash.Substring(0,16))"
}

if (-not (Test-Path -LiteralPath $wrapperCache)) {
    throw "d3d8to9 cache missing: $wrapperCache. Run tools\apply-d3d8to9.ps1 once on a copy to populate it."
}
$wrapperHash = (Get-FileHash -LiteralPath $wrapperCache -Algorithm SHA256).Hash
$d3d8 = Join-Path $GameDir 'd3d8.dll'
$d3d8Hash = if (Test-Path -LiteralPath $d3d8) { (Get-FileHash -LiteralPath $d3d8 -Algorithm SHA256).Hash } else { $null }
if ($d3d8Hash -ne $wrapperHash) {
    Write-Host "Installing d3d8to9 wrapper ..."
    if (-not $DryRun) { Copy-Item -LiteralPath $wrapperCache -Destination $d3d8 -Force }
}

if (-not $NoGPUPreference) {
    if (-not $DryRun) {
        & (Join-Path $PSScriptRoot 'set-gpu-preference.ps1') -ExePath $installed -Action Enable | Out-Null
    }
    Write-Host "GPU preference: high performance (d3d8to9 -> D3D9 -> NVIDIA)"
}

Write-Host ("Partition: debris pair filter = {0}, broadphase = {1}" -f $DebrisPairFilter, $DebrisBroadphase)
Write-Host ("Budgets: debris {0}/frame, hulks {1}/frame (0 = off, keeps everything)" -f $DebrisPerFrame, $HulkPerFrame)
# Borderless mode disables edge scrolling unless this engine option is enabled.
if (-not $DryRun) {
    & (Join-Path $PSScriptRoot 'set-screen-edge-scroll.ps1') | Out-Null
} else {
    & (Join-Path $PSScriptRoot 'set-screen-edge-scroll.ps1') -DryRun | Out-Null
}
$testEnv = @{
    ZH_DEBRIS_PER_FRAME = [string]$DebrisPerFrame
    ZH_HULK_PER_FRAME = [string]$HulkPerFrame
    ZH_DEBRIS_PAIR_FILTER = [string]$DebrisPairFilter
    ZH_DEBRIS_BROADPHASE = [string]$DebrisBroadphase
}

Write-Host "Launching ShockWave (optimized profile) ..."
if ($DryRun) { exit 0 }
& (Join-Path $PSScriptRoot 'launch-game.ps1') -GameDir $GameDir -Mode borderless -Width $Width -Height $Height -QuickStart -TestEnv $testEnv -WithFpsLimit:$WithFpsLimit -ExperimentalSingleplayer:$ExperimentalSingleplayer
