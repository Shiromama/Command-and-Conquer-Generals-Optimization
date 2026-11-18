#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [ValidateRange(640,7680)][int]$Width = 1920,
    [ValidateRange(480,4320)][int]$Height = 1080,
    [string]$ArtifactDir = '',
    [ValidateRange(1,600)][int]$DurationSeconds = 150,
    [ValidateRange(1,10)][int]$Runs = 3,
    [ValidateRange(0,32)][int]$Groups = 8,
    [ValidateRange(1,50)][int]$GroupSize = 25,
    [ValidateRange(1,3600)][int]$Interval = 90,
    [ValidateRange(0,2147483647)][int]$Seed = 1,
    [ValidateSet('List','Heap','Default')][string]$QueueMode = 'List',
    [switch]$CaptureOperations,
    [switch]$GateEachRun,
    [int[]]$BlockerCounts = @(0,5)
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $GameDir) { $GameDir = Join-Path $repo 'game\engine-test' }
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
if (-not $ArtifactDir) { $ArtifactDir = Join-Path $repo ('artifacts\{0}-pathfinding-{1}' -f (Get-Date -Format yyyy-MM-dd),(Get-Date -Format HHmmss)) }
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
$ArtifactDir = (Resolve-Path -LiteralPath $ArtifactDir).Path
$exe = Join-Path $GameDir 'Generals.exe'
$old = @{}
foreach ($item in Get-ChildItem Env:) { if ($item.Name -like 'ZH_*') { $old[$item.Name] = $item.Value } }
$proc = $null
try {
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) { Remove-Item -LiteralPath ('Env:' + $item.Name) }
    [pscustomobject]@{ exe_sha256=(Get-FileHash -LiteralPath $exe).Hash; game_dir=$GameDir; duration=$DurationSeconds; width=$Width; height=$Height; runs=$Runs; groups=$Groups; group_size=$GroupSize; interval=$Interval; seed=$Seed; queue_mode=$QueueMode; blockers=$BlockerCounts; started=(Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ArtifactDir 'parameters.json')
    foreach ($blockers in $BlockerCounts) {
        if ($blockers -lt 0 -or $blockers -gt 16) { throw 'Blocker count must be between 0 and 16.' }
        for ($run=1; $run -le $Runs; ++$run) {
            $name = "blockers-$blockers-run-$run"
            $dir = Join-Path $ArtifactDir $name
            if (Test-Path -LiteralPath $dir) { throw "Refusing to overwrite evidence: $dir" }
            New-Item -ItemType Directory -Path $dir | Out-Null
            $env:ZH_MAP = 'maps\northamerica\northamerica.map'
            $env:ZH_EXPERIMENTAL_SINGLEPLAYER = '1'
            if ($QueueMode -eq 'Default') { Remove-Item Env:\ZH_PF_HEAP -ErrorAction SilentlyContinue } else { $env:ZH_PF_HEAP = if ($QueueMode -eq 'Heap') { '1' } else { '0' } }
            $env:ZH_PF_GROUPS = [string]$Groups
            $env:ZH_PF_GROUP_SIZE = [string]$GroupSize
            $env:ZH_PF_BLOCKERS = [string]$blockers
            $env:ZH_PF_INTERVAL = [string]$Interval
            $env:ZH_PF_SEED = [string]$Seed
$env:ZH_PF_LOG = Join-Path $dir 'requests.csv'
            if ($CaptureOperations) { $env:ZH_PF_OPS = Join-Path $dir 'operations.csv' }
            $env:ZH_PF_FRAME = Join-Path $dir 'pathfinding-frames.csv'
            $env:ZH_PF_CRC_LOG = Join-Path $dir 'crc.csv'
            $env:ZH_PF_COMMAND_LOG = Join-Path $dir 'commands.csv'
            $env:ZH_PF_SPAWN_LOG = Join-Path $dir 'spawns.csv'
            $env:ZH_PF_FIXTURE_LOG = Join-Path $dir 'fixture.csv'
            $env:ZH_PERF_LOGIC = Join-Path $dir 'logic.csv'
            $env:ZH_PERF_LOG = Join-Path $dir 'frames.csv'
            $env:ZH_NOFPSLIMIT = '1'
            $env:ZH_DEBRIS_BROADPHASE = '0'
            $env:ZH_DEBRIS_PAIR_FILTER = '0'
            if ($GateEachRun) {
                $gate = Join-Path $ArtifactDir ("launch-$name.signal")
                Write-Output "Waiting for launch signal: $name"
                while (-not (Test-Path -LiteralPath $gate)) { Start-Sleep -Milliseconds 250 }
            }
            $proc = Start-Process -FilePath $exe -WorkingDirectory $GameDir -ArgumentList @('-win','-quickstart','-xres',[string]$Width,'-yres',[string]$Height,'-noFPSLimit') -WindowStyle Hidden -PassThru
            Write-Output "Started $name pid=$($proc.Id)"
            for ($elapsed=0; $elapsed -lt $DurationSeconds; ++$elapsed) {
                Start-Sleep -Seconds 1
                $proc.Refresh()
                if ($proc.HasExited) { throw "$name exited early: $($proc.ExitCode)" }
                if ($elapsed -eq 10 -and $Groups -gt 0) {
                    $spawnFile = Join-Path $dir 'spawns.csv'
                    if (-not (Test-Path -LiteralPath $spawnFile)) { throw "$name did not spawn" }
                    $spawns = @(Import-Csv -LiteralPath $spawnFile)
                    $units = @($spawns | Where-Object kind -EQ 'unit')
                    if ($units.Count -ne $Groups*$GroupSize) { throw "$name unit count mismatch" }
                    $fixture = @(Import-Csv -LiteralPath (Join-Path $dir 'fixture.csv'))[0]
                    if ($blockers -ge 2 -and ($fixture.chokePassable -ne '1' -or $fixture.buildingPassable -ne '0')) { throw "$name navigation fixture invalid: choke=$($fixture.chokePassable), building=$($fixture.buildingPassable)" }
                    foreach ($unit in $units) {
                        if ($unit.adjusted -ne '1' -or [double]$unit.x -lt [double]$unit.loX -or [double]$unit.x -gt [double]$unit.hiX -or [double]$unit.y -lt [double]$unit.loY -or [double]$unit.y -gt [double]$unit.hiY) { throw "$name has invalid spawn $($unit.object)" }
                    }
                }
                if (($elapsed+1)%30 -eq 0) { Write-Output "$name elapsed=$($elapsed+1)s" }
            }
            Stop-Process -Id $proc.Id -Force
            $proc.WaitForExit(); $proc = $null
            if ($CaptureOperations -and -not (Test-Path -LiteralPath (Join-Path $dir 'operations.csv'))) { throw 'Queue operation log missing.' }
            $required = @('requests.csv','pathfinding-frames.csv','logic.csv','frames.csv')
            if ($Groups -gt 0) { $required += @('commands.csv','spawns.csv') }
            foreach ($file in $required) {
                if (-not (Test-Path -LiteralPath (Join-Path $dir $file))) { throw "Missing evidence $name/$file" }
            }
            Write-Output "Completed $name"
        }
    }
}
finally {
    if ($proc) { $proc.Refresh(); if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force } }
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) { Remove-Item -LiteralPath ('Env:' + $item.Name) }
    foreach ($key in $old.Keys) { Set-Item -LiteralPath ('Env:' + $key) -Value $old[$key] }
}
