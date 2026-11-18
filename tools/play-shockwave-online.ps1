#requires -Version 5.1
<#
.SYNOPSIS
  Launch the stock ShockWave game online-style: GenTool + d3d8to9 + borderless.

.DESCRIPTION
  This is the online/retail profile chosen after the CRC and GenTool-validator review:

    Generals.exe   stock retail 1.04 (no limiter, no binary modification)
    d3d8.dll       GenTool 8.9 (the usual proxy, keeps SWR.net/anti-cheat)
    d3d8x.dll      d3d8to9 1.16.0 (GenTool chainloads it -> D3D9 -> discrete GPU)
    d3d8.cfg       window=3 (borderless; avoids the exclusive-fullscreen Alt+Tab crash)

  It never touches the real installation; it works on a copy under game/. The T-041
  debris/hulk limiter is deliberately NOT part of this profile: it changes object counts,
  which are included in the multiplayer CRC and in GenTool's game-file validation
  (docs/experiments/EXP-008-shockwave-nuke-performance.md §9).

  SWR.net acceptance of the chainloaded d3d8to9 is NOT verified (no account/opponent);
  delete d3d8x.dll to return to plain GenTool if a lobby rejects it.

.PARAMETER GameDir
  Copy to launch (default: game\shockwave-online).

.PARAMETER Width / Height
  Borderless client size (default 1920x1080).

.PARAMETER NoGPUPreference
  Do not set the per-app high-performance preference.

.PARAMETER DryRun
  Print the plan without copying or launching.

.EXAMPLE
  .\tools\play-shockwave-online.ps1
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [int]$Width = 1920,
    [int]$Height = 1080,
    [switch]$NoGPUPreference,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-online' }

$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
$retailHash = 'F37A4929F8D697104E99C2BCF46F8D833122C943AFCD87FD077DF641D344495B'
$wrapperCache = Join-Path $repo 'artifacts\d3d8to9\d3d8-1.16.0.dll'

if (-not (Test-Path -LiteralPath $GameDir)) {
    Write-Host "Creating $GameDir from the mod install ..."
    if (-not $DryRun) {
        & (Join-Path $PSScriptRoot 'prepare-shockwave-copy.ps1') -GameDir $GameDir
    }
}

$exe = Join-Path $GameDir 'Generals.exe'
$retailBackup = Join-Path $GameDir 'Generals.retail.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe missing in $GameDir" }
$exeHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
if ($exeHash -ne $retailHash) {
    if (-not (Test-Path -LiteralPath $retailBackup)) {
        throw "Generals.exe in $GameDir is not stock 1.04 and no Generals.retail.exe backup exists."
    }
    Write-Host "Restoring stock retail executable ..."
    if (-not $DryRun) { Copy-Item -LiteralPath $retailBackup -Destination $exe -Force }
}

$gentool = Join-Path $GameDir 'd3d8.dll'
$gentoolSource = @('d3d8.dll.gentool', 'd3d8.dll.gentool-disabled') |
    ForEach-Object { Join-Path $GameDir $_ } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$gentoolLooksRight = (Test-Path -LiteralPath $gentool) -and ((Get-Item -LiteralPath $gentool).Length -eq 3843584)
if (-not $gentoolLooksRight) {
    if (-not $gentoolSource) { throw "GenTool d3d8.dll not found in $GameDir (need d3d8.dll or d3d8.dll.gentool)." }
    Write-Host "Installing GenTool proxy ..."
    if (-not $DryRun) { Copy-Item -LiteralPath $gentoolSource -Destination $gentool -Force }
}

if (-not (Test-Path -LiteralPath $wrapperCache)) {
    throw "d3d8to9 cache missing: $wrapperCache"
}
Write-Host "Installing d3d8to9 as d3d8x.dll ..."
if (-not $DryRun) { Copy-Item -LiteralPath $wrapperCache -Destination (Join-Path $GameDir 'd3d8x.dll') -Force }

$profileCfg = Join-Path $repo 'game\profiles\fullscreen\d3d8.cfg'
if (Test-Path -LiteralPath $profileCfg) {
    if (-not $DryRun) { Copy-Item -LiteralPath $profileCfg -Destination (Join-Path $GameDir 'd3d8.cfg') -Force }
}

if (-not $NoGPUPreference) {
    if (-not $DryRun) {
        & (Join-Path $PSScriptRoot 'set-gpu-preference.ps1') -ExePath $exe -Action Enable | Out-Null
    }
    Write-Host "GPU preference: high performance (GenTool -> d3d8x -> D3D9 -> NVIDIA)"
}
Write-Host "Profile: STOCK online (no T-041 limiter). SWR.net acceptance of d3d8x is unverified."

if ($DryRun) { exit 0 }
& (Join-Path $PSScriptRoot 'launch-game.ps1') -GameDir $GameDir -Mode borderless -Width $Width -Height $Height -QuickStart
