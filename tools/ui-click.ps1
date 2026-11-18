#requires -Version 5.1
<#
.SYNOPSIS
  Send a real mouse click at absolute screen coordinates (for game UI automation).

.DESCRIPTION
  Brings the target window to the foreground, moves the cursor with SetCursorPos and
  sends WM_LBUTTONDOWN/UP through SendInput (the same path as a physical mouse), then
  waits a moment for the UI to react. Coordinates are physical pixels: the script makes
  itself per-monitor DPI aware first so 1920x1080 game coordinates map 1:1.

.PARAMETER X / Y
  Absolute screen position in physical pixels.

.PARAMETER ProcessName
  Window owner (default Generals).

.PARAMETER DelayMs
  Settle time after the click (default 700).

.EXAMPLE
  .\tools\ui-click.ps1 -X 1450 -Y 215
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y,
    [string]$ProcessName = 'Generals',
    [int]$DelayMs = 700,
    [switch]$DoubleClick
)

$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class UiInput {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
}
"@
[UiInput]::SetProcessDPIAware() | Out-Null

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { throw "No '$ProcessName' window" }
$h = $proc.MainWindowHandle

$fg = [UiInput]::GetForegroundWindow()
$fgPid = 0; $tmp = 0
$fgThread = if ($fg -ne [IntPtr]::Zero) { [UiInput]::GetWindowThreadProcessId($fg, [ref]$fgPid) } else { 0 }
$gameThread = [UiInput]::GetWindowThreadProcessId($h, [ref]$tmp)
$attached = $false
if ($fgThread -ne 0 -and $fgThread -ne $gameThread) { $attached = [UiInput]::AttachThreadInput($fgThread, $gameThread, $true) }
[UiInput]::ShowWindow($h, 9) | Out-Null
[UiInput]::SetForegroundWindow($h) | Out-Null
if ($attached) { [UiInput]::AttachThreadInput($fgThread, $gameThread, $false) | Out-Null }
Start-Sleep -Milliseconds 250

[UiInput]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 80
$down = 0x0002; $up = 0x0004
[UiInput]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[UiInput]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
if ($DoubleClick) {
    Start-Sleep -Milliseconds 80
    [UiInput]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [UiInput]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
}
Start-Sleep -Milliseconds $DelayMs
Write-Host ("clicked ({0},{1}) in pid {2}" -f $X, $Y, $proc.Id)
