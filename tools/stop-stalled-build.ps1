# Stops build/stage wrapper shells that are idle (finished their work but blocked on the output pipe).
# Safe by construction: it only targets powershell processes whose command line runs build-engine or
# stage-engine, that have no compiler children, and that have used under 5 seconds of CPU.
#
# -Watch keeps checking (default every 30 s) until -WatchMinutes elapses; it only ever kills idle
# wrappers, so a compile that is actually running is never touched.
param(
    [switch]$DryRun,
    [switch]$Watch,
    [int]$IntervalSeconds = 30,
    [int]$WatchMinutes = 30
)

$self = $PID

function Get-Wrappers {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" |
        Where-Object { $_.ProcessId -ne $self -and $_.CommandLine -match 'build-engine\.ps1|stage-engine\.ps1' }
}

function Invoke-Sweep {
    $candidates = Get-Wrappers
    if (-not $candidates) {
        Write-Host ('[{0}] no build/stage wrapper shells running' -f (Get-Date -Format 'HH:mm:ss'))
        return $false
    }

    $compiling = Get-Process cl, link, MSBuild -ErrorAction SilentlyContinue
    $killedAny = $false
    foreach ($p in $candidates) {
        $proc = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
        if (-not $proc) { continue }

        $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.ProcessId)" |
            Where-Object { $_.Name -match '^(cl|link|MSBuild|cmake)\.exe$' }

        $idle = ($proc.CPU -lt 5) -and (-not $children) -and (-not $compiling)
        $label = if ($idle) { 'IDLE  ' } else { 'ACTIVE' }
        Write-Host ('[{0}] {1} pid={2} cpu={3:N1}s' -f (Get-Date -Format 'HH:mm:ss'), $label, $p.ProcessId, $proc.CPU)

        if ($idle -and -not $DryRun) {
            Stop-Process -Id $p.ProcessId -Force
            Write-Host ('           killed pid {0}' -f $p.ProcessId)
            $killedAny = $true
        }
    }
    return $killedAny
}

if (-not $Watch) {
    Invoke-Sweep | Out-Null
    return
}

$deadline = (Get-Date).AddMinutes($WatchMinutes)
while ((Get-Date) -lt $deadline) {
    Invoke-Sweep | Out-Null
    if (-not (Get-Wrappers)) { break }
    Start-Sleep -Seconds $IntervalSeconds
}
