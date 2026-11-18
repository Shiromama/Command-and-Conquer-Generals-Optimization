#requires -Version 5.1
<#
.SYNOPSIS
  Stage a freshly built engine executable into an isolated, mutable game copy.

.DESCRIPTION
  Copies the verified baseline into a test directory (once), applies the fullscreen profile,
  backs up the retail executable, and installs the built executable as Generals.exe.
  The baseline and installed game are only read.

.PARAMETER BuiltExe
  Path to the built executable (e.g. build\engine-vs-community\GeneralsMD\generalszh.exe).

.PARAMETER GameDir
  Destination test copy (default: <repo>\game\engine-test).

.PARAMETER Profile
  Config profile to apply: fullscreen or windowed.

.PARAMETER Force
  Re-copy the test directory from the baseline and replace the backup.

.EXAMPLE
  .\tools\stage-engine.ps1 -BuiltExe build\engine-vs-community\GeneralsMD\generalszh.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BuiltExe,
    [string]$GameDir = '',
    [ValidateSet('fullscreen', 'windowed')]
    [string]$Profile = 'fullscreen',
    [switch]$WithGenTool,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\engine-test' }

$repo = Split-Path -Parent $PSScriptRoot
$baseline = Join-Path $repo 'game\baseline-pristine'
$profiles = Join-Path $repo 'game\profiles'
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir -SourcePaths @($baseline, $BuiltExe)


if (-not (Test-Path -LiteralPath $BuiltExe)) { throw "Built executable not found: $BuiltExe" }
if (-not (Test-Path -LiteralPath $baseline)) { throw "Baseline not found: $baseline. Run tools\prepare-game-copies.ps1 first." }
$BuiltExe = (Resolve-Path -LiteralPath $BuiltExe).Path

if ((Test-Path -LiteralPath $GameDir) -and $Force) {
    Remove-Item -LiteralPath $GameDir -Recurse -Force
}

if (-not (Test-Path -LiteralPath $GameDir)) {
    Write-Host "Copying baseline to $GameDir ..."
    New-Item -ItemType Directory -Force -Path $GameDir | Out-Null
    $rcArgs = @($baseline, $GameDir, '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:8',
                '/NFL', '/NDL', '/NP', '/NJH', '/NJS')
    & robocopy.exe @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    & attrib.exe -R "$GameDir\*" /S /D | Out-Null
}

$retail = Join-Path $GameDir 'Generals.exe'
$backup = Join-Path $GameDir 'Generals.retail.exe'
if (-not (Test-Path -LiteralPath $backup)) {
    if (-not (Test-Path -LiteralPath $retail)) { throw "Retail Generals.exe missing in $GameDir" }
    Copy-Item -LiteralPath $retail -Destination $backup -Force
}

$profileCfg = Join-Path $profiles "$Profile\d3d8.cfg"
if (Test-Path -LiteralPath $profileCfg) {
    Copy-Item -LiteralPath $profileCfg -Destination (Join-Path $GameDir 'd3d8.cfg') -Force
}

# The rebuilt exe is incompatible with GenTool's proxy (immediate 0xC0000005). The system
# d3d8.dll works; disable GenTool unless explicitly requested.
if (-not $WithGenTool) {
    $gentool = Join-Path $GameDir 'd3d8.dll'
    if (Test-Path -LiteralPath $gentool) {
        Move-Item -LiteralPath $gentool -Destination (Join-Path $GameDir 'd3d8.dll.gentool-disabled') -Force
    }
}

Copy-Item -LiteralPath $BuiltExe -Destination $retail -Force
$builtHash = (Get-FileHash -LiteralPath $retail -Algorithm SHA256).Hash
$retailHash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash
$cfgHash = $null
if (Test-Path -LiteralPath (Join-Path $GameDir 'd3d8.cfg')) {
    $cfgHash = (Get-FileHash -LiteralPath (Join-Path $GameDir 'd3d8.cfg') -Algorithm SHA256).Hash
}
$d3d8Dll = Join-Path $GameDir 'd3d8.dll'
$d3d8DllHash = if (Test-Path -LiteralPath $d3d8Dll) {
    (Get-FileHash -LiteralPath $d3d8Dll -Algorithm SHA256).Hash
} else {
    $null
}

$record = [ordered]@{
    created = (Get-Date -Format o)
    built_exe = $BuiltExe
    installed_exe = $retail
    installed_sha256 = $builtHash
    retail_backup = $backup
    retail_sha256 = $retailHash
    profile = $Profile
    # `d3d8_sha256` used to hold the cfg hash, which made the record ambiguous.
    d3d8_cfg_sha256 = $cfgHash
    d3d8_dll_sha256 = $d3d8DllHash
    gentool_disabled_file = (Test-Path -LiteralPath (Join-Path $GameDir 'd3d8.dll.gentool-disabled'))
    baseline = $baseline
}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $GameDir 'engine.json') -Encoding UTF8

Write-Host "Installed built engine:" -ForegroundColor Green
Write-Host "  exe    : $retail"
Write-Host "  sha256 : $builtHash"
Write-Host "  retail : $backup ($retailHash)"
Write-Host "  profile: $Profile ($cfgHash)"
Write-Host "Launch : tools\launch-game.ps1 -GameDir '$GameDir' -Mode borderless -QuickStart"
Write-Host "Restore: copy '$backup' over '$retail'"
