#requires -Version 5.1
<#
.SYNOPSIS
  Wait for a replay benchmark process and stop it when the measured window is over.
.DESCRIPTION
  The engine stop switch (ZH_GRAPHICAL_REPLAY_STOP) is the primary stop. This
  helper is the harness backstop: it kills the game when
    * stdout reports "Graphical replay checkpoint" but the process has not exited,
    * the attributed logic work (l_updates + l_ai) stays near zero for IdleSeconds
      (score screen / replay over), or
    * the overall timeout expires.
  It returns EXIT, CHECKPOINT, IDLE or TIMEOUT.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory)][string]$AttrPath,
    [string]$StdoutPath = '',
    [int]$TimeoutSeconds = 1500,
    [int]$IdleSeconds = 30,
    [int]$MinFrame = 500,
    [int]$PollSeconds = 2
)
$ErrorActionPreference = 'Stop'
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$idle = 0
$idlePolls = [Math]::Max(1, [int][Math]::Ceiling($IdleSeconds / $PollSeconds))
while (-not $Process.HasExited) {
    Start-Sleep -Seconds $PollSeconds
    if ($StdoutPath -and (Test-Path -LiteralPath $StdoutPath)) {
        $line = Get-Content -LiteralPath $StdoutPath -Tail 1 -ErrorAction SilentlyContinue
        if ($line -match 'Graphical replay checkpoint') {
            # The engine asked to quit; give it a moment, then force it.
            Start-Sleep -Seconds 5
            if (-not $Process.HasExited) { Stop-Process -Id $Process.Id -Force }
            return 'CHECKPOINT'
        }
    }
    if (Test-Path -LiteralPath $AttrPath) {
        $line = Get-Content -LiteralPath $AttrPath -Tail 1 -ErrorAction SilentlyContinue
        if ($line) {
            $parts = $line -split ','
            if ($parts.Count -gt 17) {
                $frame = 0
                $updates = 0.0
                $ai = 0.0
                if ([int]::TryParse($parts[1], [ref]$frame) -and
                    [double]::TryParse($parts[16], [ref]$updates) -and
                    [double]::TryParse($parts[17], [ref]$ai)) {
                    if ($frame -ge $MinFrame -and ($updates + $ai) -lt 0.2) {
                        $idle++
                    } else {
                        $idle = 0
                    }
                    if ($idle -ge $idlePolls) {
                        Stop-Process -Id $Process.Id -Force
                        return 'IDLE'
                    }
                }
            }
        }
    }
    if ((Get-Date) -gt $deadline) {
        Stop-Process -Id $Process.Id -Force
        return 'TIMEOUT'
    }
}
return 'EXIT'
