#requires -Version 5.1
<#
.SYNOPSIS
  Apply a portable Zero Hour options profile and keep a backup.

.DESCRIPTION
  Only edits the user's Options.ini. The game installation and game copies are untouched.
  Profiles control anti-aliasing (the dominant render cost in the entity-heavy benchmark)
  and the game's built-in detail preset (shadows, lightmaps, particles, heat effects).

  The "performance" profile keeps every unit visible but uses the Low detail preset, which
  measured draw submission 27.3 -> 18.45 ms at 1,000 units. The "balanced" profile keeps
  medium detail; "default" restores retail-equivalent High detail with 8x MSAA.

.PARAMETER Profile
  performance (AA 0 + Low detail), balanced (AA 2 + Medium), default (AA 8 + High), or
  custom (use -AntiAliasing / -StaticLOD explicitly).

.PARAMETER AntiAliasing
  Explicit anti-aliasing override: 0, 2, 4, or 8.

.PARAMETER StaticLOD
  Explicit detail override: Low, Medium, or High. Sets StaticGameLOD and IdealStaticGameLOD.

.PARAMETER KeepStaticLOD
  Change anti-aliasing only and leave the current detail preset untouched.

.PARAMETER OptionsPath
  Explicit Options.ini. Defaults to Documents\Command and Conquer Generals Zero Hour Data\options.ini.

.PARAMETER Restore
  Restore from a backup created by this script instead of applying a profile.

.EXAMPLE
  .\tools\apply-options-profile.ps1 -Profile performance

.EXAMPLE
  .\tools\apply-options-profile.ps1 -AntiAliasing 4 -KeepStaticLOD

.EXAMPLE
  .\tools\apply-options-profile.ps1 -Restore artifacts\options-backups\options-2026-11-15-005413.ini
#>
[CmdletBinding()]
param(
    [ValidateSet('performance', 'balanced', 'default', 'custom')]
    [string]$Profile = 'performance',
    [ValidateSet(0, 2, 4, 8)]
    [int]$AntiAliasing = -1,
    [ValidateSet('Low', 'Medium', 'High')]
    [string]$StaticLOD,
    [switch]$KeepStaticLOD,
    [string]$OptionsPath,
    [string]$Restore,
    [string]$BackupDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\options-backups')
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OptionsPath) {
    $OptionsPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Command and Conquer Generals Zero Hour Data\options.ini'
}
if (-not (Test-Path -LiteralPath $OptionsPath)) { throw "Options.ini not found: $OptionsPath" }
$OptionsPath = (Resolve-Path -LiteralPath $OptionsPath).Path

if ($Restore) {
    if (-not (Test-Path -LiteralPath $Restore)) { throw "Backup not found: $Restore" }
    Copy-Item -LiteralPath $Restore -Destination $OptionsPath -Force
    Write-Host "Restored $OptionsPath from $Restore" -ForegroundColor Green
    exit 0
}

$profileAA = switch ($Profile) {
    'performance' { 0 }
    'balanced' { 2 }
    'default' { 8 }
    default { -1 }
}
$profileLOD = switch ($Profile) {
    'performance' { 'Low' }
    'balanced' { 'Medium' }
    'default' { 'High' }
    default { '' }
}
if ($AntiAliasing -ge 0) { $profileAA = $AntiAliasing }
if ($StaticLOD) { $profileLOD = $StaticLOD }
if ($KeepStaticLOD) { $profileLOD = '' }
if ($profileAA -lt 0) { throw "Profile 'custom' needs -AntiAliasing (0/2/4/8)." }

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$backup = Join-Path $BackupDir "options-$stamp.ini"
Copy-Item -LiteralPath $OptionsPath -Destination $backup -Force

function Set-IniValue {
    param([string]$Text, [string]$Key, [string]$Value)
    if ($Text -match "(?m)^$Key\s*=") {
        return $Text -replace "(?m)^$Key\s*=.*$", "$Key = $Value"
    }
    return $Text.TrimEnd() + "`r`n$Key = $Value`r`n"
}

$text = Get-Content -LiteralPath $OptionsPath -Raw
$text = Set-IniValue -Text $text -Key 'AntiAliasing' -Value ([string]$profileAA)
if ($profileLOD) {
    $text = Set-IniValue -Text $text -Key 'StaticGameLOD' -Value $profileLOD
    $text = Set-IniValue -Text $text -Key 'IdealStaticGameLOD' -Value $profileLOD
}
Set-Content -LiteralPath $OptionsPath -Value $text -Encoding ASCII

Write-Host ("Applied profile '{0}': AntiAliasing = {1}; StaticGameLOD = {2}" -f $Profile, $profileAA, $(if ($profileLOD) { $profileLOD } else { 'unchanged' })) -ForegroundColor Green
Write-Host "  options: $OptionsPath"
Write-Host "  backup : $backup"
Write-Host "  sha256 : $((Get-FileHash -LiteralPath $OptionsPath -Algorithm SHA256).Hash)"
Write-Host "Restore with: tools\apply-options-profile.ps1 -Restore '$backup'"
