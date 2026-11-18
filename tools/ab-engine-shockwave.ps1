#requires -Version 5.1
<#
.SYNOPSIS
  Alternating A/B of two engine builds on the ShockWave 1,000-unit five-cycle scene.

.DESCRIPTION
  Stages each build into the game copy, runs the scenario, and collects perf/logic CSVs.
  Intended for a before/after pair where only one engine change differs.

.PARAMETER ExeA
  Baseline engine exe.

.PARAMETER ExeB
  Variant engine exe.

.PARAMETER Pairs
  Number of A/B pairs (default 3).

.PARAMETER RunSeconds
  Measured window per run (default 45).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ExeA,
    [Parameter(Mandatory = $true)][string]$ExeB,
    [int]$Pairs = 3,
    [int]$WarmupSeconds = 12,
    [int]$RunSeconds = 45,
    [string]$Label = 'ab',
    [string]$GameDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-engine'),
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) {
    $OutputDir = Join-Path $repo ("artifacts\{0}-{1}" -f (Get-Date -Format 'yyyy-MM-dd'), $Label)
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

for ($i = 1; $i -le $Pairs; $i++) {
    foreach ($v in @(@{ tag = 'A'; exe = $ExeA }, @{ tag = 'B'; exe = $ExeB })) {
        $dir = Join-Path $OutputDir ("{0}-{1}" -f $v.tag, $i)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $resolved = (Resolve-Path $dir).Path
        Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
        Write-Host ("=== {0}-{1} ===" -f $v.tag, $i)
        & (Join-Path $PSScriptRoot 'stage-engine.ps1') -BuiltExe $v.exe -GameDir $GameDir | Out-Null
        & (Join-Path $PSScriptRoot 'benchmark-shockwave-attrib.ps1') -Units 1000 -Cycles 5 -Warheads 9 `
            -CycleInterval 240 -WarmupSeconds $WarmupSeconds -RunSeconds $RunSeconds `
            -Label ("{0}-{1}" -f $v.tag, $i) -OutputDir $resolved -ExtraEnv @{ ZH_ATTR_LOG = '' } | Out-Null
        $p = Join-Path $resolved 'perf.csv'
        if (Test-Path $p) { Write-Host ("   frames: " + ((Get-Content $p).Count - 1)) } else { Write-Host '   NO PERF' }
    }
}
Write-Host 'AB DONE'
