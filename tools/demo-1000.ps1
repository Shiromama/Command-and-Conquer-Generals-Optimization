$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# Fresh end-to-end demo: 1,000 tanks (stock copy) and 1,000 x5 nuke cycles (ShockWave copy),
# in the retail-equivalent configuration and in the shipping (optimised) configuration.
Remove-Item Env:\ZH_LOCK_LOG, Env:\ZH_ATTR_LOG, Env:\ZH_SHADOW_THROTTLE -ErrorAction SilentlyContinue

$root = 'artifacts\2026-11-17-demo-1000'
New-Item -ItemType Directory -Force -Path $root | Out-Null

foreach ($cfg in @(
        @{ name = 'retail'; profile = 'default' },      # AA 8 + High
        @{ name = 'ship';   profile = 'performance' }   # AA 0 + Low, defaults on
    )) {
    Write-Host ("=== configuration: {0} (profile {1}) ===" -f $cfg.name, $cfg.profile)
    .\tools\apply-options-profile.ps1 -Profile $cfg.profile | Out-Null

    for ($i = 1; $i -le 2; $i++) {
        $dir = Join-Path $root ("stock-{0}-{1}" -f $cfg.name, $i)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
        Write-Host ("  stock  {0}-{1}" -f $cfg.name, $i)
        .\tools\benchmark-entity-heavy.ps1 -GameDir game\engine-test -Runs 1 -StressUnits 1000 `
            -DurationSeconds 40 -ArtifactDir $dir | Out-Null
    }

    for ($i = 1; $i -le 2; $i++) {
        $dir = Join-Path $root ("nuke-{0}-{1}" -f $cfg.name, $i)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
        Write-Host ("  nuke   {0}-{1}" -f $cfg.name, $i)
        .\tools\benchmark-shockwave-attrib.ps1 -GameDir game\shockwave-engine -Units 1000 -Cycles 5 `
            -Warheads 1 -WarmupSeconds 12 -RunSeconds 45 -Label ("demo-{0}-{1}" -f $cfg.name, $i) `
            -OutputDir $dir | Out-Null
    }
}
Write-Host 'DEMO DONE'
