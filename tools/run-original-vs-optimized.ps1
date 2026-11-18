$ErrorActionPreference = 'Continue'
$root = 'artifacts\2026-11-16-original-vs-optimized'
New-Item -ItemType Directory -Force -Path $root | Out-Null

function Run-SceneA([string]$profile, [string]$tag) {
    $dir = Join-Path $root $tag
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host ("=== A/{0} ({1}) ===" -f $tag, $profile)
    & (Join-Path $PSScriptRoot 'benchmark-entity-heavy.ps1') -GameDir 'game\engine-test' -Runs 1 `
        -StressUnits 1000 -DurationSeconds 40 -ApplyProfile $profile -ArtifactDir $dir |
        Select-String -Pattern 'median_ms|p95_ms|draw_median' | Out-Null
    if (Test-Path (Join-Path $dir 'frames-run1.csv')) {
        Write-Host ("   frames: " + ((Get-Content (Join-Path $dir 'frames-run1.csv')).Count - 1))
    } else { Write-Host '   NO FRAMES' }
}

function Run-SceneB([string]$profile, [string]$tag) {
    $dir = Join-Path $root $tag
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $resolved = (Resolve-Path $dir).Path
    Write-Host ("=== B/{0} ({1}) ===" -f $tag, $profile)
    & (Join-Path $PSScriptRoot 'apply-options-profile.ps1') -Profile $profile | Out-Null
    & (Join-Path $PSScriptRoot 'benchmark-shockwave-attrib.ps1') -Units 1000 -Cycles 5 -Warheads 9 `
        -CycleInterval 240 -WarmupSeconds 12 -RunSeconds 90 -Label $tag -OutputDir $resolved `
        -ExtraEnv @{ ZH_ATTR_LOG='' } | Out-Null
    if (Test-Path (Join-Path $resolved 'perf.csv')) {
        Write-Host ("   frames: " + ((Get-Content (Join-Path $resolved 'perf.csv')).Count - 1))
    } else { Write-Host '   NO PERF' }
}

for ($i = 1; $i -le 3; $i++) {
    Run-SceneA 'default'     ("A-default-{0}" -f $i)
    Run-SceneA 'performance' ("A-performance-{0}" -f $i)
}
for ($i = 1; $i -le 2; $i++) {
    Run-SceneB 'default'     ("B-default-{0}" -f $i)
    Run-SceneB 'performance' ("B-performance-{0}" -f $i)
}

& (Join-Path $PSScriptRoot 'apply-options-profile.ps1') -Profile 'performance' | Out-Null
Write-Host 'ORIGINAL-VS-OPTIMIZED DONE'
