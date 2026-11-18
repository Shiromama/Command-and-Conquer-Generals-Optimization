#requires -Version 5.1
<#
.SYNOPSIS
  Run the entity-heavy Zero Hour benchmark with the test-only harness and summarize frame times.

.DESCRIPTION
  Requires an engine built with engine/patches/T-015-benchmark-harness.patch. The harness reads:
    ZH_MAP       map to load without the shell
    ZH_STRESS    number of AmericaTankCrusader units to spawn
    ZH_PERF_LOG  frame-time CSV (frame,frame_ms)
    ZH_PERF_SPLIT phase CSV (client/draw/logic)
    ZH_DRAWDIST  optional distance cull (patched engine only)

  This script does not modify game files. Pass -ApplyProfile to change the user's Options.ini
  through tools/apply-options-profile.ps1 (which backs it up first).

.PARAMETER Runs
  Number of measured runs. Default 3.

.PARAMETER StressUnits
  Units to spawn. Default 1000 (the harness caps at 1000).

.PARAMETER Map
  Map passed to ZH_MAP. Default maps\northamerica\northamerica.map.

.PARAMETER DurationSeconds
  Seconds per run, including map load. Default 40.

.PARAMETER WarmupFrames
  Frames excluded from the steady-state statistics. Default 300.

.PARAMETER DrawDistance
  Optional ZH_DRAWDIST value in world units (0 = off).

.PARAMETER ArtifactDir
  Output directory. Default artifacts\<date>-entity-benchmark-<time>.

.PARAMETER ApplyProfile
  Apply an options profile before running: performance, balanced, default, or custom.

.PARAMETER KeepRunning
  Do not stop the game after the last run (for manual inspection).

.EXAMPLE
  .\tools\benchmark-entity-heavy.ps1 -Runs 3 -ApplyProfile performance

.EXAMPLE
  .\tools\benchmark-entity-heavy.ps1 -Runs 1 -DrawDistance 400 -ArtifactDir artifacts\cull-test
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [ValidateRange(1, 20)]
    [int]$Runs = 3,
    [ValidateRange(1, 1000)]
    [int]$StressUnits = 1000,
    [string]$Map = 'maps\northamerica\northamerica.map',
    [ValidateRange(1, 1920)]
    [int]$Width = 1920,
    [ValidateRange(1, 1080)]
    [int]$Height = 1080,
    [ValidateRange(10, 600)]
    [int]$DurationSeconds = 40,
    [ValidateRange(0, 100000)]
    [int]$WarmupFrames = 300,
    [ValidateRange(0, 1000)]
    [int]$MaxFps = 0,
    [switch]$WithFpsLimit,
    [ValidateRange(0, 100000)]
    [int]$DrawDistance = 0,
    [string]$ArtifactDir,
    [ValidateSet('performance', 'balanced', 'default')]
    [string]$ApplyProfile,
    [switch]$KeepRunning
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\engine-test' }

$repo = Split-Path -Parent $PSScriptRoot
if (-not $ArtifactDir) {
    $ArtifactDir = Join-Path $repo ("artifacts\{0}-entity-benchmark-{1}" -f (Get-Date -Format 'yyyy-MM-dd'), (Get-Date -Format 'HHmmss'))
}
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
$ArtifactDir = (Resolve-Path -LiteralPath $ArtifactDir).Path

$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
$exe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe not found in $GameDir" }

if ($ApplyProfile) {
    & (Join-Path $PSScriptRoot 'apply-options-profile.ps1') -Profile $ApplyProfile
}

# Save and clear every harness variable so this run cannot inherit a previous demo/benchmark
# (and cannot leak its own settings into a later normal launch).
$old = @{}
foreach ($item in Get-ChildItem Env:) {
    if ($item.Name -like 'ZH_*') { $old[$item.Name] = $item.Value }
}
try {
foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
    Remove-Item -LiteralPath ("Env:" + $item.Name)
}
$env:ZH_EXPERIMENTAL_SINGLEPLAYER = '0'
$env:ZH_DEBRIS_BROADPHASE = '0'
$env:ZH_DEBRIS_PAIR_FILTER = '0'
$env:ZH_MAP = $Map
$env:ZH_STRESS = [string]$StressUnits
if ($MaxFps -gt 0) { $env:ZH_FPS = [string]$MaxFps } else { Remove-Item Env:\ZH_FPS -ErrorAction SilentlyContinue }
if ($DrawDistance -gt 0) { $env:ZH_DRAWDIST = [string]$DrawDistance } else { Remove-Item Env:\ZH_DRAWDIST -ErrorAction SilentlyContinue }

$meta = [pscustomobject]@{
    started_at = (Get-Date).ToString('o')
    game_dir = $GameDir
    exe_sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    map = $Map
    stress_units = $StressUnits
    resolution = "${Width}x${Height}"
    runs = $Runs
    duration_seconds = $DurationSeconds
    warmup_frames = $WarmupFrames
    max_fps = $MaxFps
    draw_distance = $DrawDistance
    options_profile = $ApplyProfile
}
$meta | ConvertTo-Json | Set-Content (Join-Path $ArtifactDir 'benchmark-parameters.json')

$results = @()
    for ($i = 1; $i -le $Runs; $i++) {
        $framesCsv = Join-Path $ArtifactDir ("frames-run$i.csv")
        $splitCsv = Join-Path $ArtifactDir ("split-run$i.csv")
        Remove-Item $framesCsv, $splitCsv -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $GameDir 'stress.log') -Force -ErrorAction SilentlyContinue
        $env:ZH_PERF_LOG = $framesCsv
        $env:ZH_PERF_SPLIT = $splitCsv

        $gameArgs = @('-win', '-quickstart', '-xres', [string]$Width, '-yres', [string]$Height)
        # Uncapped by default; -WithFpsLimit or -MaxFps restores an explicit cap.
        if (-not $WithFpsLimit -and $MaxFps -le 0) {
            $gameArgs += '-noFPSLimit'
            $env:ZH_NOFPSLIMIT = '1'
        } else {
            $env:ZH_NOFPSLIMIT = '0'
        }
        $proc = Start-Process -FilePath $exe -ArgumentList $gameArgs -WorkingDirectory $GameDir -PassThru
        Start-Sleep -Seconds $DurationSeconds
        $proc.Refresh()
        $alive = -not $proc.HasExited
        if ($alive -and -not ($KeepRunning -and $i -eq $Runs)) {
            Stop-Process -Id $proc.Id -Force
            Start-Sleep -Seconds 3
        } elseif (-not $alive) {
            Write-Warning "Run $i exited early (exit code $($proc.ExitCode))."
        }
        if ($KeepRunning -and $i -eq $Runs -and $alive) { Write-Host "Game left running (PID $($proc.Id))." }

        $draw = $null; $logic = $null; $count = 0; $median = $null; $p95 = $null; $p99 = $null
        if (Test-Path -LiteralPath $framesCsv) {
            $ms = @(Get-Content -LiteralPath $framesCsv | Select-Object -Skip 1 | ForEach-Object { [double](($_ -split ',')[1]) })
            $count = $ms.Count
            if ($ms.Count -gt $WarmupFrames) {
                $steady = @($ms | Select-Object -Skip $WarmupFrames | Sort-Object)
                $median = [math]::Round($steady[[int][math]::Floor($steady.Count / 2)], 2)
                $p95 = [math]::Round($steady[[int][math]::Floor($steady.Count * 0.95)], 2)
                $p99 = [math]::Round($steady[[int][math]::Floor($steady.Count * 0.99)], 2)
            }
        }
        if (Test-Path -LiteralPath $splitCsv) {
            $rows = Get-Content -LiteralPath $splitCsv | Select-Object -Skip 1 | ForEach-Object {
                $parts = $_ -split ','
                [pscustomobject]@{ phase = $parts[0]; ms = [double]$parts[1] }
            }
            $vals = @($rows | Where-Object phase -eq 'draw' | ForEach-Object ms)
            if ($vals.Count) { $sorted = $vals | Sort-Object; $draw = [math]::Round($sorted[[int][math]::Floor($sorted.Count / 2)], 2) }
            $vals = @($rows | Where-Object phase -eq 'logic' | ForEach-Object ms)
            if ($vals.Count) { $sorted = $vals | Sort-Object; $logic = [math]::Round($sorted[[int][math]::Floor($sorted.Count / 2)], 2) }
        }

        $result = [pscustomobject]@{
            run = $i; frames = $count; steady_frames = [math]::Max(0, $count - $WarmupFrames)
            median_ms = $median; p95_ms = $p95; p99_ms = $p99
            draw_median_ms = $draw; logic_median_ms = $logic
        }
        $results += $result
        $result | Format-Table -AutoSize
    }
}
finally {
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ("Env:" + $item.Name)
    }
    foreach ($key in $old.Keys) {
        if ($null -eq $old[$key]) { Remove-Item "Env:$key" -ErrorAction SilentlyContinue }
        else { Set-Item "Env:$key" $old[$key] }
    }
}

$results | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $ArtifactDir 'benchmark-results.json')
$results | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $ArtifactDir 'benchmark-results.csv')

Write-Host "`n=== summary ===" -ForegroundColor Green
$results | Format-Table -AutoSize
if (-not (Test-Path (Join-Path $GameDir 'stress.log'))) {
    Write-Warning 'No stress.log was produced; the exe may not contain the T-015 benchmark harness.'
}
Write-Host "Artifacts: $ArtifactDir"
Write-Host "Options: $env:USERPROFILE\Documents\Command and Conquer Generals Zero Hour Data\options.ini"

