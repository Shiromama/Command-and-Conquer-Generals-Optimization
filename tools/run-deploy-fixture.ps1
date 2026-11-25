#requires -Version 5.1
<#
.SYNOPSIS
  Run one T-120 unattended engine fixture case in a verified mutable game copy.

.DESCRIPTION
  Stages the supplied development engine as Generals.exe, starts a scripted skirmish, polls a
  heartbeat and a final JSON result, and enforces separate startup, progress and total deadlines.
  The original executable and Skirmish.ini are restored in a finally block. Only the child PID is
  stopped; no unrelated game process is touched.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Label,
    [ValidateSet('deploy_guard', 'path_bench', 'formation_start', 'vision_probe', 'avoid_probe')][string]$Case = 'deploy_guard',
    [ValidateSet('0', '1')][string]$Hold = '0',
    [ValidateSet('0', '1')][string]$GroupStartRelax = '0',
    [ValidateSet('0', '1')][string]$LongRangeVision = '0',
    [ValidateSet('0', '1')][string]$DeployedAvoid = '0',
    [string]$Template = '',
    [string]$BlockerBuilding = '',
    [ValidateSet('leader', 'mid', 'goal')][string]$BlockerAt = 'leader',
    [int]$BlockerCount = 1,
    [string]$Map = 'maps\barrenbadlands\barrenbadlands.map',
    [string]$GameDir = '',
    [string]$ArtifactDir = '',
    [ValidateSet('0', '1')][string]$Cache = '1',
    [ValidateSet('0', '1')][string]$Oracle = '0',
    [ValidateSet('0', '1')][string]$Selftest = '0',
    [int]$Groups = 8,
    [int]$GroupSize = 25,
    [int]$Waves = 4,
    [int]$Seed = 1,
    [int]$ReadyFrame = 180,
    [int]$StartupSeconds = 150,
    [int]$StallSeconds = 60,
    [int]$TimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $GameDir) { $GameDir = Join-Path $repo 'game\last-stand-replay' }
if (-not $ArtifactDir) { $ArtifactDir = Join-Path $repo "artifacts\2026-11-22-t120-deploy-fixture\$Label" }
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
$exe = (Resolve-Path -LiteralPath $Exe).Path
$exeHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
$gameExe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $gameExe)) { throw "Generals.exe not found in $GameDir" }
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
$ArtifactDir = (Resolve-Path -LiteralPath $ArtifactDir).Path
if (Test-Path -LiteralPath (Join-Path $ArtifactDir 'result.json')) {
    throw "Refusing to overwrite evidence: $ArtifactDir\result.json"
}
$resultPath = Join-Path $ArtifactDir 'result.json'
$heartbeatPath = "$resultPath.heartbeat"
$skirmish = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Command and Conquer Generals Zero Hour Data\Skirmish.ini'
$skirmishBackup = Join-Path $ArtifactDir 'Skirmish.ini.original'
$hadSkirmish = Test-Path -LiteralPath $skirmish
if ($hadSkirmish) { Copy-Item -LiteralPath $skirmish -Destination $skirmishBackup -Force }
$gameExeBackup = Join-Path $ArtifactDir 'Generals.exe.original'
Copy-Item -LiteralPath $gameExe -Destination $gameExeBackup -Force
$gameExeHash = (Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash
$savedEnv = @{}
foreach ($item in Get-ChildItem Env:) { if ($item.Name -like 'ZH_*') { $savedEnv[$item.Name] = $item.Value } }
$proc = $null
$status = 'infrastructure_error'
$detail = ''
$started = Get-Date
try {
    if (Get-Process -Name 'Generals', 'generalszh' -ErrorAction SilentlyContinue) {
        throw 'Another Generals process is running; refusing to launch.'
    }
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ('Env:' + $item.Name)
    }
    Copy-Item -LiteralPath $exe -Destination $gameExe -Force
    if ((Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash -ne $exeHash) {
        throw 'Staged executable hash mismatch.'
    }

    $env:ZH_FIXTURE_RESULT = $resultPath
    $env:ZH_FIXTURE_MAP = $Map
    $env:ZH_FIXTURE_CASE = $Case
    $env:ZH_FIXTURE_SEED = [string]$Seed
    if ($Case -eq 'formation_start') { $env:ZH_FIXTURE_READY_FRAME = [string]$ReadyFrame }
    if ($Template) { $env:ZH_FIXTURE_TEMPLATE = $Template }
    if ($BlockerBuilding) { $env:ZH_FIXTURE_BLOCKER_BUILDING = $BlockerBuilding; $env:ZH_FIXTURE_BLOCKER_AT = $BlockerAt; $env:ZH_FIXTURE_BLOCKER_COUNT = [string]$BlockerCount }
    $env:ZH_DEPLOY_GUARD_HOLD = $Hold
    $env:ZH_DEPLOYED_AVOID = $DeployedAvoid
    $env:ZH_LONG_RANGE_VISION = $LongRangeVision
    $env:ZH_GROUP_START_RELAX = $GroupStartRelax
    $env:ZH_GROUP_ENDPOINT_RELAX = '0'
    $env:ZH_FORMATION_COMMANDS = Join-Path $ArtifactDir 'formation-commands.csv'
    $env:ZH_FORMATION_COMMANDS_ALL = '1'
    $env:ZH_PF_OCCUPANT_CACHE = $Cache
    $env:ZH_PF_CACHE_ORACLE = $Oracle
    $env:ZH_PF_CACHE_SELFTEST = $Selftest
    $env:ZH_PF_CACHE_LOG = Join-Path $ArtifactDir 'cache-oracle.csv'
    $env:ZH_PF_CACHE_LIFECYCLE = Join-Path $ArtifactDir 'cache-lifecycle.csv'
    $env:ZH_PF_FRAME = Join-Path $ArtifactDir 'pf-frame.csv'
    $env:ZH_PF_LOG = Join-Path $ArtifactDir 'requests.csv'
    $env:ZH_ATTR_LOG = Join-Path $ArtifactDir 'attr.csv'
    $env:ZH_PERF_LOG = Join-Path $ArtifactDir 'frames.csv'
    $env:ZH_DEPLOY_DEBUG_LOG = Join-Path $ArtifactDir 'deploy.csv'
    $env:ZH_NOFPSLIMIT = '1'
    if ($Case -eq 'path_bench') {
        $env:ZH_FIXTURE_GROUPS = [string]$Groups
        $env:ZH_FIXTURE_GROUP_SIZE = [string]$GroupSize
        $env:ZH_FIXTURE_WAVES = [string]$Waves
        $env:ZH_FIXTURE_INTERVAL = '90'
    }

    [ordered]@{
        label = $Label
        case = $Case
        map = $Map
        hold = [int]$Hold
        group_start_relax = [int]$GroupStartRelax
        long_range_vision = [int]$LongRangeVision
        deployed_avoid = [int]$DeployedAvoid
        template = $Template
        blocker_building = $BlockerBuilding
    blocker_at = $BlockerAt
    blocker_count = $BlockerCount
        cache = [int]$Cache
        oracle = [int]$Oracle
        selftest = [int]$Selftest
        groups = $Groups
        group_size = $GroupSize
        waves = $Waves
        seed = $Seed
        ready_frame = $ReadyFrame
        game_dir = $GameDir
        exe = $exe
        exe_sha256 = $exeHash
        replaced_exe_sha256 = $gameExeHash
        startup_seconds = $StartupSeconds
        stall_seconds = $StallSeconds
        timeout_seconds = $TimeoutSeconds
        started = $started.ToString('o')
    } | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $ArtifactDir 'parameters.json')

    $argList = @('-win', '-quickstart', '-xres', '1920', '-yres', '1080', '-noFPSLimit')
    $proc = Start-Process -FilePath $gameExe -WorkingDirectory $GameDir -ArgumentList $argList `
        -PassThru -RedirectStandardOutput (Join-Path $ArtifactDir 'stdout.log') `
        -RedirectStandardError (Join-Path $ArtifactDir 'stderr.log')
    Write-Output "Started $Label PID $($proc.Id), engine $exeHash"

    $lastFrame = -1
    $lastProgress = Get-Date
    $sawReadiness = $false
    while ($true) {
        Start-Sleep -Seconds 1
        $proc.Refresh()
        $now = Get-Date
        if (Test-Path -LiteralPath $resultPath) {
            try {
                $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
                if ($result.status) {
                    $status = [string]$result.status
                    $detail = "case=$($result.case) frame=$($result.frame)"
                    break
                }
            } catch {
                # The final write is one handle; a partial read is retried on the next poll.
            }
        }
        if (Test-Path -LiteralPath $heartbeatPath) {
            $heartbeat = Get-Content -LiteralPath $heartbeatPath -Raw -ErrorAction SilentlyContinue
            if ($heartbeat -match 'frame=(\d+)') {
                $sawReadiness = $true
                $frame = [int]$Matches[1]
                if ($frame -ne $lastFrame) {
                    $lastFrame = $frame
                    $lastProgress = $now
                }
            }
        }
        $elapsed = ($now - $started).TotalSeconds
        if (-not $sawReadiness -and $elapsed -gt $StartupSeconds) {
            $status = 'timeout'; $detail = 'no heartbeat within the startup deadline'
            break
        }
        if ($sawReadiness -and ($now - $lastProgress).TotalSeconds -gt $StallSeconds) {
            $status = 'timeout'; $detail = "no logic progress for $StallSeconds s (last frame $lastFrame)"
            break
        }
        if ($elapsed -gt $TimeoutSeconds) {
            $status = 'timeout'; $detail = "total deadline $TimeoutSeconds s exceeded"
            break
        }
        if ($proc.HasExited) {
            $status = 'crash'; $detail = "process exited early with code $($proc.ExitCode)"
            break
        }
    }
} catch {
    $status = 'infrastructure_error'
    $detail = $_.Exception.Message
} finally {
    if ($proc) {
        $proc.Refresh()
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            try { $proc.WaitForExit(10000) | Out-Null } catch { }
        }
    }
    $restoredHash = $null
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try {
            Copy-Item -LiteralPath $gameExeBackup -Destination $gameExe -Force
            $restoredHash = (Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash
            break
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $restoredHash) {
        $restoredHash = '<restore failed>'
        Write-Output "WARNING: could not restore $gameExe; backup at $gameExeBackup"
    }
    if ($hadSkirmish -and (Test-Path -LiteralPath $skirmishBackup)) {
        Copy-Item -LiteralPath $skirmishBackup -Destination $skirmish -Force
    }
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ('Env:' + $item.Name)
    }
    foreach ($key in $savedEnv.Keys) { Set-Item -LiteralPath ('Env:' + $key) -Value $savedEnv[$key] }

    $result = $null
    if (Test-Path -LiteralPath $resultPath) {
        try { $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json } catch { }
    }
    $run = [ordered]@{
        label = $Label
        case = $Case
        status = $status
        detail = $detail
        engine_sha256 = $exeHash
        restored_exe_sha256 = $restoredHash
        restored_exe_matches = ($restoredHash -eq $gameExeHash)
        result_path = $resultPath
        heartbeat_path = $heartbeatPath
        exit_code = if ($proc -and $proc.HasExited) { $proc.ExitCode } else { $null }
        started = $started.ToString('o')
        finished = (Get-Date).ToString('o')
        elapsed_seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
        result = $result
    }
    $run | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $ArtifactDir 'run.json')
    Write-Output "STATUS=$status $detail"
    Write-Output "RUN=$ArtifactDir\run.json"
    if (-not $run.restored_exe_matches) { Write-Output 'WARNING: restored executable hash mismatch' }
}

if ($status -eq 'pass') { exit 0 }
if ($status -in @('assertion_failed', 'invalid_fixture', 'diverged')) { exit 2 }
exit 3
