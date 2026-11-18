#requires -Version 5.1
<#
.SYNOPSIS
  Launch a game copy with a portable window/fullscreen configuration.

.DESCRIPTION
  No registry changes and no hardcoded install path. The game directory is a parameter.
  "borderless" expects a GenTool d3d8.cfg with window=3 and passes -win; "windowed" expects
  window=2 and passes -win; "exclusive" omits -win.

.PARAMETER GameDir
  Game copy to launch (default: <repo>\game\work).

.PARAMETER Mode
  borderless (default), windowed, or exclusive.

.PARAMETER Width / Height
  Forced resolution passed as -xres / -yres.

.PARAMETER QuickStart
  Add -quickstart (skip intro/shellmap).

.PARAMETER ExtraArgs
  Additional arguments, passed through unchanged.

.PARAMETER DrawDistance
  Opt-in render distance cull for the benchmark-harness engine (world units, 0 = off).

.PARAMETER ShadowDistance
  Opt-in shadow-volume distance cull (world units, 0 = off). Units stay visible.

.PARAMETER ShadowSize
  Opt-in screen-size shadow cull: minimum projected radius in pixels (0 = off). Large/near
  shadows stay; tiny/far ones are skipped.

.PARAMETER NoFPSLimit
  Start uncapped for this launch. Live FPS controls remain available.

.PARAMETER WithFpsLimit
  Restore the engine's 30 FPS render cap for this launch.

.PARAMETER ExperimentalSingleplayer
  Permit experimental simulation settings in solo/skirmish only. Engine blocks them in network games/replays.

.PARAMETER PathfindingQueue
  Auto (default) leaves queue selection to the engine or explicit TestEnv.ZH_PF_HEAP.
  List/Heap override it. Network/replay always use List in the engine.

.PARAMETER DryRun
  Print the command without launching.

.PARAMETER Wait
  Wait for the process and return its exit code.

.PARAMETER TestEnv
  Test-only `ZH_*` environment variables for this launch (hashtable). The launcher clears every
  inherited ZH_ variable first and restores the caller's environment afterwards, so a benchmark
  or demo cannot leak `ZH_STRESS`, nuke, cull or logging settings into a later normal launch.
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [ValidateSet('borderless', 'windowed', 'exclusive')]
    [string]$Mode = 'borderless',
    [int]$Width = 1920,
    [int]$Height = 1080,
    [switch]$QuickStart,
    [switch]$DryRun,
    [switch]$Wait,
    [int]$DrawDistance = 0,
    [int]$ShadowDistance = 0,
    [int]$ShadowSize = 0,
    [switch]$NoFPSLimit,
    [switch]$WithFpsLimit,
    [switch]$ExperimentalSingleplayer,
    [ValidateSet('Auto','List','Heap')][string]$PathfindingQueue = 'Auto',
    [string[]]$ExtraArgs = @(),
    [switch]$NoFocus,
    [hashtable]$TestEnv = @{}
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\work' }

if ($PathfindingQueue -ne 'Auto' -and $TestEnv.ContainsKey('ZH_PF_HEAP')) { throw 'Choose PathfindingQueue or TestEnv.ZH_PF_HEAP, not both.' }
if ($NoFPSLimit -and $WithFpsLimit) { throw 'Choose NoFPSLimit or WithFpsLimit, not both.' }
foreach ($key in $TestEnv.Keys) {
    if ($key -notmatch '^ZH_[A-Z0-9_]+$') { throw "Invalid TestEnv key: $key" }
}
# Simulation-changing test switches require an explicit launch mode, even if Options.ini or
# a previous shell has enabled them. The engine also disables them for network games/replays.
$simulationKeys = @('ZH_DEBRIS_BROADPHASE', 'ZH_DEBRIS_PAIR_FILTER', 'ZH_DEBRIS_PER_FRAME', 'ZH_HULK_PER_FRAME')
if (-not $ExperimentalSingleplayer) {
    foreach ($key in $simulationKeys) {
        if ($TestEnv.ContainsKey($key) -and [int]$TestEnv[$key] -ne 0) {
            throw "$key requires -ExperimentalSingleplayer (not certified for multiplayer/replays)."
        }
    }
}
if (-not (Test-Path -LiteralPath $GameDir)) { throw "Game directory not found: $GameDir" }
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir

$exe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $exe)) { $exe = Join-Path $GameDir 'generals.exe' }
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe not found in $GameDir" }

$cfg = Join-Path $GameDir 'd3d8.cfg'
$windowPreset = $null
if (Test-Path -LiteralPath $cfg) {
    $m = Select-String -LiteralPath $cfg -Pattern '^\s*window\s*=\s*(\d+)' -ErrorAction SilentlyContinue
    if ($m) { $windowPreset = [int]$m.Matches[0].Groups[1].Value }
}
$expected = @{ borderless = 3; windowed = 2 }
if ($expected.ContainsKey($Mode) -and $windowPreset -ne $expected[$Mode]) {
    Write-Warning ("Mode '{0}' expects window={1} in d3d8.cfg, found {2}. The game may not use the intended mode." -f $Mode, $expected[$Mode], $(if ($null -eq $windowPreset) { '<missing>' } else { $windowPreset }))
}

$gameArgs = New-Object System.Collections.Generic.List[string]
if ($Mode -ne 'exclusive') { $gameArgs.Add('-win') }
$gameArgs.Add('-xres'); $gameArgs.Add([string]$Width)
$gameArgs.Add('-yres'); $gameArgs.Add([string]$Height)
if ($QuickStart) { $gameArgs.Add('-quickstart') }
# Ordinary launches honor saved preferences. Explicit switches only set startup state.
if ($NoFPSLimit) { $gameArgs.Add('-noFPSLimit') }
foreach ($a in $ExtraArgs) { $gameArgs.Add($a) }

$display = '"{0}" {1}' -f $exe, ($gameArgs -join ' ')
Write-Host "Game  : $GameDir"
Write-Host "Mode  : $Mode (GenTool window preset: $(if ($null -eq $windowPreset) { 'n/a' } else { $windowPreset }))"
Write-Host "Launch: $display"
Write-Host "Pathfinding queue: $PathfindingQueue (Auto uses engine default; network/replay always use List)"
if ($DryRun) { exit 0 }

# Snapshot every inherited ZH_ variable, not a list that becomes stale as diagnostics grow.
$savedHarnessEnv = @{}
foreach ($item in Get-ChildItem Env:) {
    if ($item.Name -like 'ZH_*') { $savedHarnessEnv[$item.Name] = $item.Value }
}
try {
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ("Env:" + $item.Name)
    }
    foreach ($key in $TestEnv.Keys) {
        Set-Item -LiteralPath ("Env:" + $key) -Value ([string]$TestEnv[$key])
    }
    if ($DrawDistance -gt 0) { $env:ZH_DRAWDIST = [string]$DrawDistance }
    if ($ShadowDistance -gt 0) { $env:ZH_SHADOWDIST = [string]$ShadowDistance }
    if ($ShadowSize -gt 0) { $env:ZH_SHADOWSIZE = [string]$ShadowSize }
    if ($NoFPSLimit) { $env:ZH_NOFPSLIMIT = '1' }
    elseif ($WithFpsLimit) { $env:ZH_NOFPSLIMIT = '0' }
    $env:ZH_EXPERIMENTAL_SINGLEPLAYER = if ($ExperimentalSingleplayer) { '1' } else { '0' }
    if ($PathfindingQueue -eq 'Heap') { $env:ZH_PF_HEAP = '1' }
    elseif ($PathfindingQueue -eq 'List') { $env:ZH_PF_HEAP = '0' }
    if (-not $ExperimentalSingleplayer) {
        foreach ($key in $simulationKeys) { Set-Item -LiteralPath ("Env:" + $key) -Value '0' }
    }
    $proc = Start-Process -FilePath $exe -ArgumentList $gameArgs.ToArray() -WorkingDirectory $GameDir -PassThru
} finally {
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) {
        Remove-Item -LiteralPath ("Env:" + $item.Name)
    }
    foreach ($key in $savedHarnessEnv.Keys) {
        Set-Item -LiteralPath ("Env:" + $key) -Value $savedHarnessEnv[$key]
    }
}
Write-Host "Started PID $($proc.Id)"

# Bring the game to the foreground once the window exists. Mouse wheel zoom and screen-edge
# scrolling only work while the game owns the foreground; a Start-Process launch otherwise
# leaves the terminal focused.
if (-not $NoFocus) {
    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $deadline) {
        $proc.Refresh()
        if ($proc.MainWindowHandle -ne 0) { break }
        Start-Sleep -Milliseconds 250
    }
    if ($proc.MainWindowHandle -ne 0) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LaunchFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
}
"@
        $fg = [LaunchFocus]::GetForegroundWindow()
        $fgPid = 0; $gamePid = 0
        $fgThread = if ($fg -ne [IntPtr]::Zero) { [LaunchFocus]::GetWindowThreadProcessId($fg, [ref]$fgPid) } else { 0 }
        $gameThread = [LaunchFocus]::GetWindowThreadProcessId($proc.MainWindowHandle, [ref]$gamePid)
        $attached = $false
        if ($fgThread -ne 0 -and $fgThread -ne $gameThread) {
            $attached = [LaunchFocus]::AttachThreadInput($fgThread, $gameThread, $true)
        }
        [LaunchFocus]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
        [LaunchFocus]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
        if ($attached) { [LaunchFocus]::AttachThreadInput($fgThread, $gameThread, $false) | Out-Null }
    }
}
if ($Wait) {
    $proc.WaitForExit()
    Write-Host "Exit code: $($proc.ExitCode)"
    exit $proc.ExitCode
}
