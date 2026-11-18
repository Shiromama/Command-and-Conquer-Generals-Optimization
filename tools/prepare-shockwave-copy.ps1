#requires -Version 5.1
<#
.SYNOPSIS
  Create an isolated, mutable ShockWave test copy from the read-only mod install.

.DESCRIPTION
  The ShockWave launcher does not patch the executable: it renames its `!*.gib`
  archives to `*.big` immediately before starting `generals.exe` (mapping in
  `Shockwave_Lnchr.dat`) and restores the names on exit.  BIGFileSystem only loads
  `*.big`, and because it appends archives in ascending filename order (first match
  wins), the `!`-prefixed mod archives override the retail archives.

  This script reproduces that materialisation in a copy, so a rebuilt engine or a
  profiling harness can load the mod data without running the launcher and without
  ever writing to the source installation.

.PARAMETER SourceDir
  Read-only ShockWave installation (default: repository sibling folder).

.PARAMETER GameDir
  Destination copy (default: <repo>\game\shockwave-work).

.PARAMETER Force
  Delete and recreate the copy.

.PARAMETER NoMaterialize
  Copy only; leave .gib names untouched (useful for inspecting the raw install).

.EXAMPLE
  .\tools\prepare-shockwave-copy.ps1
  .\tools\prepare-shockwave-copy.ps1 -GameDir game\shockwave-engine-test -Force
#>
[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$GameDir = '',
    [switch]$Force,
    [switch]$NoMaterialize
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $SourceDir) { $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Command and Conquer Generals Zero Hour - Shockwave' }
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\shockwave-work' }

$repo = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $SourceDir)) { throw "ShockWave source not found: $SourceDir" }
$SourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir -SourcePaths @($SourceDir)

$manifestPath = Join-Path $SourceDir 'Shockwave_Lnchr.dat'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Launcher file map missing: $manifestPath" }

if ((Test-Path -LiteralPath $GameDir) -and $Force) {
    Write-Host "Removing existing copy $GameDir ..."
    # The copied files may be read-only; clear before deletion.
    & attrib.exe -R "$GameDir\*" /S /D 2>$null | Out-Null
    Remove-Item -LiteralPath $GameDir -Recurse -Force
}

if (-not (Test-Path -LiteralPath $GameDir)) {
    Write-Host "Copying ShockWave install to $GameDir ..."
    New-Item -ItemType Directory -Force -Path $GameDir | Out-Null
    $rcArgs = @($SourceDir, $GameDir, '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:8',
                '/NFL', '/NDL', '/NP', '/NJH', '/NJS')
    & robocopy.exe @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    & attrib.exe -R "$GameDir\*" /S /D | Out-Null
}

$sourceExe = Join-Path $GameDir 'Generals.exe'
$sourceHash = if (Test-Path -LiteralPath $sourceExe) { (Get-FileHash -LiteralPath $sourceExe -Algorithm SHA256).Hash } else { $null }

# --- Materialise the launcher's file map -------------------------------------
# Lines look like `!Shw_ini.gib  > !Shw_ini.big` (rename) or `A.bmp < B.bmp` (swap).
# Only the rename form is needed to load the mod; the bitmap swaps are launcher UI.
$materialized = New-Object System.Collections.Generic.List[string]
if (-not $NoMaterialize) {
    $map = Get-Content -LiteralPath $manifestPath
    foreach ($line in $map) {
        if ($line -notmatch '^\s*(\S.*?)\s+>\s+(\S.*?)\s*$') { continue }
        $from = Join-Path $GameDir $Matches[1].Trim()
        $to = Join-Path $GameDir $Matches[2].Trim()
        if (-not (Test-Path -LiteralPath $from)) { Write-Warning "file map entry missing, skipped: $from"; continue }
        if ((Test-Path -LiteralPath $to) -and -not $Force) {
            Write-Verbose "already materialised: $to"
            continue
        }
        Copy-Item -LiteralPath $from -Destination $to -Force
        $hash = (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash
        $materialized.Add(("{0} -> {1}  {2}" -f (Split-Path $from -Leaf), (Split-Path $to -Leaf), $hash))
    }
}

$record = [ordered]@{
    created = (Get-Date -Format o)
    source = $SourceDir
    copy = (Resolve-Path -LiteralPath $GameDir).Path
    source_generals_sha256 = $sourceHash
    materialized = $materialized
    gentool_present = Test-Path -LiteralPath (Join-Path $GameDir 'd3d8.dll')
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $GameDir 'shockwave.json') -Encoding UTF8

Write-Host "ShockWave copy ready:" -ForegroundColor Green
Write-Host "  copy : $GameDir"
Write-Host "  exe  : $sourceHash (retail/launcher binary)"
Write-Host "  files: $($materialized.Count) materialised from .gib/.scb"
Write-Host "Next : tools\stage-engine.ps1 -GameDir '$GameDir' -BuiltExe <built exe>"
