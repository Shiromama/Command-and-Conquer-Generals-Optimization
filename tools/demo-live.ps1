$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# Live demo for the user to watch: 1,000 tanks, then 1,000 units x nuke cycles.
$root = 'artifacts\2026-11-17-live'
New-Item -ItemType Directory -Force -Path $root | Out-Null

Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

.\tools\apply-options-profile.ps1 -Profile performance | Out-Null
Write-Host 'config: AA 0 + Low, shipping defaults (DrawDistance off, partition skip on)'

Write-Host '=== scene 1: 1,000 tanks (45 s) ==='
.\tools\benchmark-entity-heavy.ps1 -GameDir game\engine-test -Runs 1 -StressUnits 1000 `
    -DurationSeconds 45 -ArtifactDir (Join-Path $root 'tanks') | Out-Null

Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

Write-Host '=== scene 2: 1,000 units x 5 nuke cycles (90 s) ==='
.\tools\benchmark-shockwave-attrib.ps1 -GameDir game\shockwave-engine -Units 1000 -Cycles 5 `
    -Warheads 1 -WarmupSeconds 10 -RunSeconds 90 -Label live `
    -OutputDir (Join-Path $root 'nuke') | Out-Null

Write-Host 'LIVE DONE'
