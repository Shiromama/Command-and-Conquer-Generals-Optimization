#requires -Version 5.1
<#
.SYNOPSIS
  Profile the staged engine's CPU/GPU resource use during a replay.

.DESCRIPTION
  Starts one owned game process, samples process/per-thread CPU, total and per-core CPU, GPU
  engine utilization, memory and GPU adapter data, then stops only that process. The game copy's
  Skirmish.ini is restored. The executable is not replaced.
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [Parameter(Mandatory)][string]$Label,
    [string]$Replay = '',
    [int]$StopFrame = 0,
    [int]$WarmupSeconds = 15,
    [int]$SampleSeconds = 30,
    [hashtable]$TestEnv = @{}
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $GameDir) { $GameDir = Join-Path $repo 'game\last-stand-replay' }
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
$out = Join-Path $repo "artifacts/2026-11-22-t120-deploy-fixture/$Label"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$out = (Resolve-Path -LiteralPath $out).Path
$exe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe not found: $exe" }
$exeHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
$skirmish = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Command and Conquer Generals Zero Hour Data\Skirmish.ini'
$skirmishBackup = Join-Path $out 'Skirmish.ini.original'
$hadSkirmish = Test-Path -LiteralPath $skirmish
if ($hadSkirmish) { Copy-Item -LiteralPath $skirmish -Destination $skirmishBackup -Force }
$savedEnv = @{}
foreach ($item in Get-ChildItem Env:) { if ($item.Name -like 'ZH_*') { $savedEnv[$item.Name] = $item.Value } }
$proc = $null
try {
    Get-Process -Name 'Generals', 'generalszh' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ('Env:' + $item.Name)
    }
    foreach ($key in $TestEnv.Keys) { Set-Item -LiteralPath ('Env:' + $key) -Value ([string]$TestEnv[$key]) }
    $args = @('-win', '-xres', '1920', '-yres', '1080', '-quickstart', '-noFPSLimit', '-useCwd')
    if ($Replay) {
        $replayName = Split-Path -Leaf $Replay
        Copy-Item -LiteralPath $Replay -Destination (Join-Path $GameDir $replayName) -Force
        $replayDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Command and Conquer Generals Zero Hour Data\Replays'
        New-Item -ItemType Directory -Force -Path $replayDir | Out-Null
        Copy-Item -LiteralPath $Replay -Destination (Join-Path $replayDir $replayName) -Force
        $args += @('-loadreplay', $replayName, '-ignoreReplaySyncErrors')
    }
    if ($StopFrame -gt 0) { $env:ZH_GRAPHICAL_REPLAY_STOP = [string]$StopFrame }
    [ordered]@{
        label = $Label
        exe = $exe
        exe_sha256 = $exeHash
        replay = $Replay
        replay_sha256 = if ($Replay) { (Get-FileHash -LiteralPath $Replay -Algorithm SHA256).Hash } else { '' }
        stop_frame = $StopFrame
        warmup_seconds = $WarmupSeconds
        sample_seconds = $SampleSeconds
        switches = $TestEnv
        started = (Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $out 'parameters.json')
    $proc = Start-Process -FilePath $exe -WorkingDirectory $GameDir -ArgumentList $args `
        -PassThru -RedirectStandardOutput (Join-Path $out 'stdout.log') `
        -RedirectStandardError (Join-Path $out 'stderr.log')
    Write-Output "Started PID $($proc.Id) engine $exeHash"
    Start-Sleep -Seconds $WarmupSeconds
    $proc.Refresh()
    if ($proc.HasExited) { throw "process exited during warmup: $($proc.ExitCode)" }
    $samples = New-Object System.Collections.Generic.List[object]
    $prev = Get-Date
    $prevCpu = $proc.TotalProcessorTime.TotalSeconds
    $prevThreads = @{}
    foreach ($t in $proc.Threads) { $prevThreads[[int]$t.Id] = $t.TotalProcessorTime.TotalSeconds }
    for ($i = 0; $i -lt $SampleSeconds; $i++) {
        Start-Sleep -Seconds 1
        $proc.Refresh()
        if ($proc.HasExited) { break }
        $now = Get-Date
        $elapsed = ($now - $prev).TotalSeconds
        $cpu = $proc.TotalProcessorTime.TotalSeconds
        $processPct = if ($elapsed -gt 0) { ($cpu - $prevCpu) / $elapsed * 100.0 } else { 0 }
        $threads = @{}
        foreach ($t in $proc.Threads) {
            $id = [int]$t.Id
            $seconds = $t.TotalProcessorTime.TotalSeconds
            $threads[$id] = if ($prevThreads.ContainsKey($id) -and $elapsed -gt 0) { ($seconds - $prevThreads[$id]) / $elapsed * 100.0 } else { 0 }
        }
        $prevThreads = @{}
        foreach ($t in $proc.Threads) { $prevThreads[[int]$t.Id] = $t.TotalProcessorTime.TotalSeconds }
        $prev = $now
        $prevCpu = $cpu
        $topThreads = $threads.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
        $totalCpu = $null
        $maxCore = $null
        try {
            $totalCpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time' -MaxSamples 1).CounterSamples[0].CookedValue, 1)
            $cores = (Get-Counter '\Processor(*)\% Processor Time' -MaxSamples 1).CounterSamples | Where-Object InstanceName -ne '_total'
            if ($cores) { $maxCore = [math]::Round(($cores | Measure-Object CookedValue -Maximum).Maximum, 1) }
        } catch { }
        $gpuPct = $null
        try {
            $gpu = (Get-Counter '\GPU Engine(*)\Utilization Percentage' -MaxSamples 1).CounterSamples |
                Where-Object { $_.InstanceName -like "pid_$($proc.Id)_*" }
            if ($gpu) { $gpuPct = [math]::Round(($gpu | Measure-Object CookedValue -Sum).Sum, 1) }
        } catch { }
        $smi = $null
        try { $smi = (& nvidia-smi --query-gpu=utilization.gpu,memory.used,clocks.sm --format=csv,noheader 2>$null) -join '; ' } catch { }
        $samples.Add([pscustomobject]@{
            second = $i + 1
            process_cpu_pct = [math]::Round($processPct, 1)
            total_cpu_pct = $totalCpu
            max_core_pct = $maxCore
            gpu_engine_pct = $gpuPct
            nvidia_smi = $smi
            working_set_mb = [math]::Round($proc.WorkingSet64 / 1MB, 1)
            private_mb = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1)
            threads = $proc.Threads.Count
            top_threads = (($topThreads | ForEach-Object { "$($_.Key):$([math]::Round($_.Value,1))" }) -join ' ')
        })
        Write-Output ("t={0}s process={1}% total={2}% maxcore={3}% gpu={4}% ws={5}MB threads={6}" -f ($i+1), $samples[-1].process_cpu_pct, $totalCpu, $maxCore, $gpuPct, $samples[-1].working_set_mb, $proc.Threads.Count)
    }
    $samples | Export-Csv -LiteralPath (Join-Path $out 'resource-samples.csv') -NoTypeInformation
    $modules = $proc.Modules | Where-Object { $_.ModuleName -match 'd3d8|d3d9|nvd3dum|igdumdim|nvapi|dxgi' } | Select-Object ModuleName, FileName
    $modules | Export-Csv -LiteralPath (Join-Path $out 'graphics-modules.csv') -NoTypeInformation
    $modules | Format-Table -AutoSize
} finally {
    if ($proc) {
        $proc.Refresh()
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            try { $proc.WaitForExit(10000) | Out-Null } catch { }
        }
    }
    Get-Process -Name 'Generals', 'generalszh' -ErrorAction SilentlyContinue | Stop-Process -Force
    if ($hadSkirmish -and (Test-Path -LiteralPath $skirmishBackup)) {
        Copy-Item -LiteralPath $skirmishBackup -Destination $skirmish -Force
    }
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ('Env:' + $item.Name)
    }
    foreach ($key in $savedEnv.Keys) { Set-Item -LiteralPath ('Env:' + $key) -Value $savedEnv[$key] }
    Write-Output "OUT=$out"
}
