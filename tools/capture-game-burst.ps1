#requires -Version 5.1
<#
.SYNOPSIS
  High-rate in-process capture of the game window (for short destruction bursts).

.DESCRIPTION
  capture-game-window.ps1 is fine for stills but spawns a new PowerShell per frame (~0.9 s),
  which is slower than the mod's ~2 s debris lifetime. This script binds the window once and
  loops CopyFromScreen + downscale + PNG save in a single process, reaching ~10 fps at 960 px
  wide.

.PARAMETER Path
  Output directory for frame0000.png ...

.PARAMETER DurationSeconds
  Capture duration (default 20).

.PARAMETER Fps
  Target frames per second (default 10).

.PARAMETER Width
  Output width; height follows the window aspect (default 960).

.EXAMPLE
  .\tools\capture-game-burst.ps1 -Path artifacts\burst -DurationSeconds 20
#>
[CmdletBinding()]
param(
    [string]$ProcessName = 'Generals',
    [Parameter(Mandatory = $true)][string]$Path,
    [double]$DurationSeconds = 20,
    [int]$Fps = 10,
    [int]$Width = 960
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class BurstCapture {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
}
"@
[BurstCapture]::SetProcessDPIAware() | Out-Null

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { throw "No '$ProcessName' window" }
$h = $proc.MainWindowHandle

$fg = [BurstCapture]::GetForegroundWindow()
$fgPid = 0; $tmp = 0
$fgThread = if ($fg -ne [IntPtr]::Zero) { [BurstCapture]::GetWindowThreadProcessId($fg, [ref]$fgPid) } else { 0 }
$gameThread = [BurstCapture]::GetWindowThreadProcessId($h, [ref]$tmp)
$attached = $false
if ($fgThread -ne 0 -and $fgThread -ne $gameThread) { $attached = [BurstCapture]::AttachThreadInput($fgThread, $gameThread, $true) }
[BurstCapture]::ShowWindow($h, 9) | Out-Null
[BurstCapture]::SetForegroundWindow($h) | Out-Null
if ($attached) { [BurstCapture]::AttachThreadInput($fgThread, $gameThread, $false) | Out-Null }
Start-Sleep -Milliseconds 300

$rect = New-Object BurstCapture+RECT
[BurstCapture]::GetClientRect($h, [ref]$rect) | Out-Null
$origin = New-Object BurstCapture+POINT
[BurstCapture]::ClientToScreen($h, [ref]$origin) | Out-Null
$w = $rect.R - $rect.L
$ht = $rect.B - $rect.T
if ($w -le 0 -or $ht -le 0) { throw "invalid client size ${w}x${ht}" }

New-Item -ItemType Directory -Force -Path $Path | Out-Null
Get-ChildItem -LiteralPath $Path -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$outW = $Width
$outH = [int]([math]::Round($ht * $outW / $w))
$small = New-Object System.Drawing.Bitmap $outW, $outH
$sg = [System.Drawing.Graphics]::FromImage($small)
$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear

$total = [int]($DurationSeconds * $Fps)
$frameTime = 1000.0 / $Fps
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt $total; $i++) {
    $target = $i * $frameTime
    $wait = $target - $sw.Elapsed.TotalMilliseconds
    if ($wait -gt 1) { Start-Sleep -Milliseconds ([int]$wait) }
    $g.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bmp.Size)
    $sg.DrawImage($bmp, 0, 0, $outW, $outH)
    $small.Save((Join-Path $Path ('frame{0:D4}.png' -f $i)), [System.Drawing.Imaging.ImageFormat]::Png)
}
$sw.Stop()
$g.Dispose(); $sg.Dispose(); $bmp.Dispose(); $small.Dispose()
Write-Host ("captured {0} frames at ~{1:N1} fps -> {2}" -f $total, ($total / $sw.Elapsed.TotalSeconds), $Path)
