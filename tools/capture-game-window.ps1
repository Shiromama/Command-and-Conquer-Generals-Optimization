#requires -Version 5.1
<#
.SYNOPSIS
  Capture a screenshot of a running game window (foreground-safe).

.DESCRIPTION
  Finds the game process by executable name, brings its main window to the
  foreground, waits a moment, then captures the window client area with
  CopyFromScreen. Uses physical pixel coordinates by making the *capturing*
  PowerShell process per-monitor DPI aware first, so the image matches the
  real client area instead of a virtualised thumbnail.

.PARAMETER ProcessName
  Process name without .exe (default: Generals).

.PARAMETER Path
  Output PNG path.

.PARAMETER TimeoutSeconds
  How long to wait for a main window to appear.

.EXAMPLE
  .\tools\capture-game-window.ps1 -Path artifacts\shot.png
#>
[CmdletBinding()]
param(
    [string]$ProcessName = 'Generals',
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [int]$TimeoutSeconds = 30,
    [switch]$NoForeground
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class GameWindow {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attach, uint attachTo, bool fAttach);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
}
"@
[GameWindow]::SetProcessDPIAware() | Out-Null

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$proc = $null
do {
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($proc) { break }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)

if (-not $proc) { throw "No '$ProcessName' window appeared within $TimeoutSeconds s" }

if (-not $NoForeground) {
    # A background process may not call SetForegroundWindow successfully; attaching to the
    # current foreground thread's input queue lifts that restriction for the call.
    $fg = [GameWindow]::GetForegroundWindow()
    $fgPid = 0
    $gamePid = 0
    $fgThread = if ($fg -ne [IntPtr]::Zero) { [GameWindow]::GetWindowThreadProcessId($fg, [ref]$fgPid) } else { 0 }
    $gameThread = [GameWindow]::GetWindowThreadProcessId($proc.MainWindowHandle, [ref]$gamePid)
    $attached = $false
    if ($fgThread -ne 0 -and $fgThread -ne $gameThread) {
        $attached = [GameWindow]::AttachThreadInput($fgThread, $gameThread, $true)
    }
    [GameWindow]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null   # SW_RESTORE
    [GameWindow]::BringWindowToTop($proc.MainWindowHandle) | Out-Null
    [GameWindow]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    if ($attached) { [GameWindow]::AttachThreadInput($fgThread, $gameThread, $false) | Out-Null }
    Start-Sleep -Milliseconds 900
}

$rect = New-Object GameWindow+RECT
[GameWindow]::GetClientRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$origin = New-Object GameWindow+POINT
[GameWindow]::ClientToScreen($proc.MainWindowHandle, [ref]$origin) | Out-Null
$width = $rect.R - $rect.L
$height = $rect.B - $rect.T
if ($width -le 0 -or $height -le 0) { throw "Invalid client size ${width}x${height}" }

$dir = Split-Path -Parent $Path
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bmp.Size)
$bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

$foreground = [GameWindow]::GetForegroundWindow() -eq $proc.MainWindowHandle
Write-Host ("captured {0} ({1}x{2}) foreground={3} -> {4}" -f $proc.ProcessName, $width, $height, $foreground, $Path)
