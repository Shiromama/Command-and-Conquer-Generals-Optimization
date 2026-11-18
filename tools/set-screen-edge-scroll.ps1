#requires -Version 5.1
<#
.SYNOPSIS
  Enable screen-edge scrolling in windowed/borderless mode (Zero Hour engine option).

.DESCRIPTION
  The SuperHackers engine (and our rebuild) gates edge scrolling behind
  `ScreenEdgeScrollEnabledInWindowedApp` / `...InFullscreenApp` in Options.ini. The default
  matches retail: fullscreen only. Our performance profile runs borderless (`-win`), so edge
  scrolling is off unless this key is set to yes.

  The real retail 1.04 client ignores unknown Options.ini keys, so this is safe for the shared
  user profile; a one-time backup is written next to Options.ini.

.PARAMETER OptionsPath
  Options.ini (default: the Zero Hour user data folder).

.PARAMETER Disable
  Set the windowed key back to "no".

.PARAMETER DryRun
  Show the changes without writing.

.EXAMPLE
  .\tools\set-screen-edge-scroll.ps1
#>
[CmdletBinding()]
param(
    [string]$OptionsPath = (Join-Path $env:USERPROFILE 'Documents\Command and Conquer Generals Zero Hour Data\Options.ini'),
    [switch]$Disable,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $OptionsPath)) { throw "Options.ini not found: $OptionsPath" }

$windowed = if ($Disable) { 'no' } else { 'yes' }
$fullscreen = 'yes'
$lines = Get-Content -LiteralPath $OptionsPath
$backup = "$OptionsPath.edge-scroll.bak"

$foundWindowed = $false
$foundFullscreen = $false
$out = foreach ($line in $lines) {
    if ($line -match '^\s*ScreenEdgeScrollEnabledInWindowedApp\s*=') {
        $foundWindowed = $true
        "ScreenEdgeScrollEnabledInWindowedApp = $windowed"
    } elseif ($line -match '^\s*ScreenEdgeScrollEnabledInFullscreenApp\s*=') {
        $foundFullscreen = $true
        "ScreenEdgeScrollEnabledInFullscreenApp = $fullscreen"
    } else {
        $line
    }
}
if (-not $foundWindowed) { $out += "ScreenEdgeScrollEnabledInWindowedApp = $windowed" }
if (-not $foundFullscreen) { $out += "ScreenEdgeScrollEnabledInFullscreenApp = $fullscreen" }

if ($DryRun) {
    Write-Host "Would set windowed edge scroll = $windowed in $OptionsPath"
    exit 0
}

if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $OptionsPath -Destination $backup
    Write-Host "Backup: $backup"
}
$out | Set-Content -LiteralPath $OptionsPath -Encoding ASCII
Write-Host "Screen-edge scrolling: windowed=$windowed fullscreen=$fullscreen"
