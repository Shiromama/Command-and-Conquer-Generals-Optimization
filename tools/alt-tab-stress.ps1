#requires -Version 5.1
<#
.SYNOPSIS
  Repeated focus-loss/focus-gain stress test for a running game window.

.DESCRIPTION
  Reproduces what Alt+Tab does to the engine: the game loses foreground
  (WM_ACTIVATEAPP FALSE), then regains it (WM_ACTIVATEAPP TRUE).  Instead of
  relying on the real Alt+Tab chord (which only works when the sending process is
  itself in the foreground), this script owns a small helper window and moves
  foreground between the helper and the game with AttachThreadInput, which is the
  same OS mechanism Alt+Tab uses and is allowed from a background process.

  Each cycle records whether the game process is still alive and responding, and
  whether it actually owns the foreground.  On a crash it reports the exit code,
  the Windows Error Reporting event (faulting module + offset) and any new WER
  dump.

.PARAMETER Cycles
  Away-and-back cycles (default 20).

.PARAMETER DwellSeconds
  Seconds spent away and back per cycle (default 1.5).  Use 0 for a rapid spam test.

.PARAMETER ProcessName
  Game process name (default Generals).

.PARAMETER Path
  Optional screenshot captured after the final cycle.

.PARAMETER HoldSeconds
  Keep watching the process for this many seconds after the last cycle, so a
  delayed exit (or a crash after focus returns) is still recorded.

.EXAMPLE
  .\tools\alt-tab-stress.ps1 -Cycles 30 -DwellSeconds 1
  .\tools\alt-tab-stress.ps1 -Cycles 100 -DwellSeconds 0
#>
[CmdletBinding()]
param(
    [string]$ProcessName = 'Generals',
    [int]$Cycles = 20,
    [double]$DwellSeconds = 1.5,
    [int]$HoldSeconds = 20,
    [switch]$UseChord,
    [switch]$GlobalChord,
    [string]$MetricsPath,
    [string]$DumpDir = (Join-Path $env:LOCALAPPDATA 'CrashDumps'),
    [string]$Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class FocusNative {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attach, uint attachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr hProcess, uint flags);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@

function Get-GameProcess {
    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Set-ForegroundWindow([IntPtr]$Window) {
    if ($Window -eq [IntPtr]::Zero) { return $false }
    $fg = [FocusNative]::GetForegroundWindow()
    $fgPid = 0
    $tmpPid = 0
    $fgThread = if ($fg -ne [IntPtr]::Zero) { [FocusNative]::GetWindowThreadProcessId($fg, [ref]$fgPid) } else { 0 }
    $targetThread = [FocusNative]::GetWindowThreadProcessId($Window, [ref]$tmpPid)
    $attached = $false
    if ($fgThread -ne 0 -and $fgThread -ne $targetThread) {
        $attached = [FocusNative]::AttachThreadInput($fgThread, $targetThread, $true)
    }
    if ([FocusNative]::IsIconic($Window)) { [FocusNative]::ShowWindow($Window, 9) | Out-Null }
    [FocusNative]::ShowWindow($Window, 5) | Out-Null   # SW_SHOW
    [FocusNative]::SetForegroundWindow($Window) | Out-Null
    if ($attached) { [FocusNative]::AttachThreadInput($fgThread, $targetThread, $false) | Out-Null }
    Start-Sleep -Milliseconds 120
    [System.Windows.Forms.Application]::DoEvents()
    return ([FocusNative]::GetForegroundWindow() -eq $Window)
}

$proc = Get-GameProcess
if (-not $proc) { throw "Game process '$ProcessName' is not running. Start it first." }
if ($proc.MainWindowHandle -eq 0) { throw "Game process has no main window yet." }
$gameWindow = $proc.MainWindowHandle

# A plain helper window gives us a legitimate foreground target while the game is away.
$helper = New-Object System.Windows.Forms.Form
$helper.Text = 'AltTabStressHelper'
$helper.Width = 420
$helper.Height = 220
$helper.StartPosition = 'CenterScreen'
$helper.TopMost = $false
$helper.Show()
[System.Windows.Forms.Application]::DoEvents()
$helperWindow = $helper.Handle

Write-Host ("Focus stress: pid={0} game={1} helper={2} cycles={3} dwell={4}s" -f $proc.Id, $gameWindow, $helperWindow, $Cycles, $DwellSeconds)

$startDumps = @()
if (Test-Path -LiteralPath $DumpDir) {
    $startDumps = Get-ChildItem -LiteralPath $DumpDir -Filter '*.dmp' -ErrorAction SilentlyContinue |
                  Select-Object -ExpandProperty FullName
}

# Baseline: make sure the game starts in the foreground.
$ok = Set-ForegroundWindow $gameWindow
Write-Host ("baseline game_foreground={0}" -f $ok)

$results = New-Object System.Collections.Generic.List[object]
$metrics = New-Object System.Collections.Generic.List[object]
for ($i = 1; $i -le $Cycles; $i++) {
    if ($proc.HasExited) { break }

    if ($GlobalChord) {
        # Real system Alt+Tab, injected with keybd_event: the shell's task switcher
        # processes it and may minimise the fullscreen window, which is the path a
        # player exercises and the one a plain SetForegroundWindow change misses.
        $null = Set-ForegroundWindow $gameWindow
        [FocusNative]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)          # Alt down
        Start-Sleep -Milliseconds 60
        [FocusNative]::keybd_event(0x09, 0, 0, [UIntPtr]::Zero)          # Tab down
        Start-Sleep -Milliseconds 60
        [FocusNative]::keybd_event(0x09, 0, 2, [UIntPtr]::Zero)          # Tab up
        [FocusNative]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)          # Alt up
        $away = $true
    } else {
        $away = Set-ForegroundWindow $helperWindow
    }
    $proc.Refresh()
    $aliveAway = -not $proc.HasExited
    if ($UseChord -and $aliveAway) {
        # From our helper (foreground) the real Alt+Tab chord is processed by the OS and
        # selects the next window - the same path a user takes.
        [System.Windows.Forms.SendKeys]::SendWait('%{TAB}')
    }
    if ($DwellSeconds -gt 0) { Start-Sleep -Seconds $DwellSeconds }

    if ($GlobalChord) {
        [FocusNative]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [FocusNative]::keybd_event(0x09, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [FocusNative]::keybd_event(0x09, 0, 2, [UIntPtr]::Zero)
        [FocusNative]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 120
        $back = $true
    } else {
        $back = Set-ForegroundWindow $gameWindow
    }
    $proc.Refresh()
    $alive = -not $proc.HasExited
    $responding = if ($alive) { $proc.Responding } else { $false }
    if ($DwellSeconds -gt 0) { Start-Sleep -Seconds $DwellSeconds }
    [System.Windows.Forms.Application]::DoEvents()

    $memMb = $null; $wsMb = $null; $handles = $null; $gdi = $null; $user = $null
    if ($alive) {
        $memMb = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1)
        $wsMb = [math]::Round($proc.WorkingSet64 / 1MB, 1)
        $handles = $proc.HandleCount
        try {
            $gdi = [FocusNative]::GetGuiResources($proc.Handle, 0)
            $user = [FocusNative]::GetGuiResources($proc.Handle, 1)
        } catch { }
        $metrics.Add([pscustomobject][ordered]@{
            cycle = $i; private_mb = $memMb; workingset_mb = $wsMb
            handles = $handles; gdi = $gdi; user = $user
        })
    }

    $results.Add([pscustomobject][ordered]@{
        cycle = $i
        away_focus = $away
        alive_after_away = $aliveAway
        alive = $alive
        responding = $responding
        game_foreground = $back
        private_mb = $memMb
        handles = $handles
    })
    Write-Host ("cycle {0,3}: away_focus={1} alive_away={2} alive={3} responding={4} game_fg={5} private={6}MB handles={7}" -f `
        $i, $away, $aliveAway, $alive, $responding, $back, $memMb, $handles)

    if (-not $alive) { break }
}

$proc.Refresh()
$exitCode = if ($proc.HasExited) { $proc.ExitCode } else { $null }

if (-not $proc.HasExited -and $HoldSeconds -gt 0) {
    if ($Path) {
        & (Join-Path $PSScriptRoot 'capture-game-window.ps1') -ProcessName $ProcessName -Path $Path
    }
    Write-Host ("Holding {0}s to catch a delayed exit ..." -f $HoldSeconds)
    $deadline = (Get-Date).AddSeconds($HoldSeconds)
    while ((Get-Date) -lt $deadline -and -not $proc.HasExited) {
        Start-Sleep -Milliseconds 500
        $proc.Refresh()
    }
    if ($proc.HasExited) { $exitCode = $proc.ExitCode }
}
Write-Host ""
Write-Host ("Result: cycles_completed={0} exited={1} exit_code={2}" -f $results.Count, $proc.HasExited, $exitCode)

if ($proc.HasExited) {
    $hex = if ($null -ne $exitCode) { '0x{0:X8}' -f ([uint32]$exitCode) } else { 'n/a' }
    Write-Host ("Exit code hex: {0}" -f $hex) -ForegroundColor Yellow

    try {
        $since = (Get-Date).AddMinutes(-10)
        Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $since; Id = 1000 } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match [regex]::Escape($ProcessName) } |
            Select-Object -First 3 |
            ForEach-Object { Write-Host "--- WER 1000 ---"; Write-Host $_.Message }
    } catch { Write-Warning "WER event query failed: $_" }

    if (Test-Path -LiteralPath $DumpDir) {
        Get-ChildItem -LiteralPath $DumpDir -Filter '*.dmp' -ErrorAction SilentlyContinue |
            Where-Object { $startDumps -notcontains $_.FullName } |
            ForEach-Object { Write-Host ("New dump: {0} ({1:N0} bytes)" -f $_.FullName, $_.Length) }
    }
}

if ($MetricsPath -and $metrics.Count -gt 0) {
    $dir = Split-Path -Parent $MetricsPath
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $metrics | Export-Csv -NoTypeInformation -LiteralPath $MetricsPath
    Write-Host ("metrics -> {0} ({1} rows)" -f $MetricsPath, $metrics.Count)
}

$helper.Close()
$helper.Dispose()

if ($Path -and -not $proc.HasExited) {
    & (Join-Path $PSScriptRoot 'capture-game-window.ps1') -ProcessName $ProcessName -Path $Path
}

$results | Format-Table -AutoSize
if ($proc.HasExited) { exit 1 } else { exit 0 }
