#requires -Version 5.1
<#
.SYNOPSIS
  Create or verify a pristine baseline copy and a mutable work copy of the game.

.DESCRIPTION
  Never modifies the source installation. The baseline is hashed and marked read-only.
  All fixes are applied to the work copy only. Paths and labels are parameters so the
  workflow is reproducible on another PC.

.PARAMETER SourceGameDir
  Existing game installation to copy. It is only read.

.PARAMETER Root
  Destination root (default: <repo>\game).

.PARAMETER Label
  Stable label for this baseline (default: yyyy-MM-dd). Used in the manifest name.

.PARAMETER Profile
  Config overlay copied into the work copy: fullscreen, windowed, or none.

.PARAMETER VerifyOnly
  Do not copy. Verify the baseline against its manifest.

.PARAMETER Force
  Deprecated. Existing baseline/work pairs are never deleted; use verification or a new workspace.

.EXAMPLE
  .\tools\prepare-game-copies.ps1 -SourceGameDir 'D:\Games\GeneralsZH' -Label v104-gentool76

.EXAMPLE
  .\tools\prepare-game-copies.ps1 -Label v104-gentool76 -VerifyOnly
#>
[CmdletBinding()]
param(
    [string]$SourceGameDir,
    [string]$Root = '',
    [string]$Label = '',
    [ValidateSet('fullscreen', 'windowed', 'none')]
    [string]$Profile = 'fullscreen',
    [switch]$VerifyOnly,
    [switch]$ApplyProfileOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Root) { $Root = Join-Path $repoRoot 'game' }
$baseline = Join-Path $Root 'baseline-pristine'
$work = Join-Path $Root 'work'
$manifestDir = Join-Path $repoRoot 'docs\manifests'
if (-not $Label) {
    if ($VerifyOnly) {
        # Verification should not depend on today's date: use the newest baseline manifest.
        $latestManifest = Get-ChildItem -LiteralPath $manifestDir -Filter 'game-baseline-*.sha256' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latestManifest) { throw "No baseline manifest found in $manifestDir" }
        $manifest = $latestManifest.FullName
        Write-Host "Using manifest: $($latestManifest.Name)"
    } else {
        $Label = Get-Date -Format 'yyyy-MM-dd'
        $manifest = Join-Path $manifestDir "game-baseline-$Label.sha256"
    }
} else {
    $manifest = Join-Path $manifestDir "game-baseline-$Label.sha256"
}
$profiles = Join-Path $Root 'profiles'
$copiesJson = Join-Path $Root 'copies.json'

function Invoke-Robocopy {
    param([string]$From, [string]$To, [switch]$ClearReadOnly)
    if (-not (Test-Path -LiteralPath $From)) { throw "Source not found: $From" }
    New-Item -ItemType Directory -Force -Path $To | Out-Null
    $rcArgs = @($From, $To, '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:8',
              '/NFL', '/NDL', '/NP', '/NJH', '/NJS')
    & robocopy.exe @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE ($From -> $To)" }
    if ($ClearReadOnly) {
        & attrib.exe -R "$To\*" /S /D | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "attrib -R failed with exit code $LASTEXITCODE" }
    }
}

function Get-ManifestRows {
    param([string]$BaseDir)
    $rows = New-Object System.Collections.Generic.List[string]
    $files = Get-ChildItem -LiteralPath $BaseDir -Recurse -File -Force | Sort-Object FullName
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($BaseDir.Length).TrimStart('\')
        $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        $rows.Add(("{0}`t{1}`t{2}" -f $hash, $f.Length, $rel))
    }
    return $rows
}

function Write-Manifest {
    param([string]$BaseDir, [string]$Path)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $rows = Get-ManifestRows -BaseDir $BaseDir
    $header = @(
        "# Pristine game baseline manifest",
        "# label: $Label",
        "# created: $(Get-Date -Format o)",
        "# source: $SourceGameDir",
        "# format: sha256<TAB>bytes<TAB>relative-path",
        ""
    )
    $text = ($header -join "`r`n") + ($rows -join "`r`n") + "`r`n"
    [IO.File]::WriteAllText($Path, $text, (New-Object Text.UTF8Encoding($false)))
    return $rows.Count
}

function Test-Manifest {
    param([string]$BaseDir, [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Manifest not found: $Path" }
    if (-not (Test-Path -LiteralPath $BaseDir)) { throw "Baseline not found: $BaseDir" }
    $expected = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $parts = $line -split "`t", 3
        if ($parts.Count -ne 3) { throw "Malformed manifest line: $line" }
        $expected[$parts[2]] = @{ Hash = $parts[0]; Size = [int64]$parts[1] }
    }
    $problems = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($f in Get-ChildItem -LiteralPath $BaseDir -Recurse -File -Force) {
        $rel = $f.FullName.Substring($BaseDir.Length).TrimStart('\')
        $seen[$rel] = $true
        if (-not $expected.ContainsKey($rel)) { $problems.Add("unexpected file: $rel"); continue }
        if ($f.Length -ne $expected[$rel].Size) { $problems.Add("size mismatch: $rel"); continue }
        $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        if ($hash -ne $expected[$rel].Hash) { $problems.Add("hash mismatch: $rel") }
    }
    foreach ($rel in $expected.Keys) {
        if (-not $seen.ContainsKey($rel)) { $problems.Add("missing file: $rel") }
    }
    if ($problems.Count -gt 0) {
        $problems | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        throw "Baseline verification FAILED: $($problems.Count) problem(s)."
    }
    Write-Host ("OK: baseline matches manifest ({0} files)." -f $expected.Count) -ForegroundColor Green
}

New-Item -ItemType Directory -Force -Path $Root | Out-Null

function Apply-Profile {
    param([string]$WorkDir, [string]$Name)
    if ($Name -eq 'none') { return $null }
    $profileDir = Join-Path $profiles $Name
    if (-not (Test-Path -LiteralPath $profileDir)) { throw "Profile not found: $profileDir" }
    $profileCfg = Join-Path $profileDir 'd3d8.cfg'
    if (-not (Test-Path -LiteralPath $profileCfg)) { throw "Profile has no d3d8.cfg: $profileDir" }
    Copy-Item -LiteralPath $profileCfg -Destination (Join-Path $WorkDir 'd3d8.cfg') -Force
    return (Get-FileHash -LiteralPath (Join-Path $WorkDir 'd3d8.cfg') -Algorithm SHA256).Hash
}

if ($ApplyProfileOnly) {
    . (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
    $work = Assert-MutableGameCopyPath -Path $work
    if (-not (Test-Path -LiteralPath $work)) { throw "Work copy not found: $work" }
    $hash = Apply-Profile -WorkDir $work -Name $Profile
    if (Test-Path -LiteralPath $copiesJson) {
        $rec = Get-Content -LiteralPath $copiesJson -Raw | ConvertFrom-Json
        $rec.profile = $Profile
        $rec.profile_d3d8_sha256 = $hash
        $rec | Add-Member -NotePropertyName profile_applied -NotePropertyValue (Get-Date -Format o) -Force
        $rec | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $copiesJson -Encoding UTF8
    }
    Write-Host ("Applied profile '{0}' to work copy (d3d8.cfg sha256 {1})." -f $Profile, $hash) -ForegroundColor Green
    exit 0
}

if ($VerifyOnly) {
    Test-Manifest -BaseDir $baseline -Path $manifest
    exit 0
}

if (-not $SourceGameDir) { throw "-SourceGameDir is required unless -VerifyOnly is used." }
$SourceGameDir = (Resolve-Path -LiteralPath $SourceGameDir).Path

. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$work = Assert-MutableGameCopyPath -Path $work -SourcePaths @($SourceGameDir)
if ((Test-Path -LiteralPath $baseline) -or (Test-Path -LiteralPath $work)) {
    throw 'Existing baseline/work pair is immutable to recreation, including -Force. Use -VerifyOnly or a new workspace.'
}

Write-Host "Source : $SourceGameDir"
Write-Host "Baseline: $baseline"
Write-Host "Work    : $work"
Write-Host "Label   : $Label"

Invoke-Robocopy -From $SourceGameDir -To $baseline
& attrib.exe +R "$baseline\*" /S /D | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Failed to mark baseline read-only (attrib exit $LASTEXITCODE)." }

$fileCount = Write-Manifest -BaseDir $baseline -Path $manifest
$baselineBytes = (Get-ChildItem -LiteralPath $baseline -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ("Baseline: {0} files, {1:N2} GB, manifest {2}" -f $fileCount, ($baselineBytes / 1GB), $manifest) -ForegroundColor Green

Write-Host "Verifying baseline against manifest..."
Test-Manifest -BaseDir $baseline -Path $manifest

Invoke-Robocopy -From $baseline -To $work -ClearReadOnly
Write-Host "Verifying work copy against manifest (before profile)..."
Test-Manifest -BaseDir $work -Path $manifest

$profileHash = $null
if ($Profile -ne 'none') {
    $profileHash = Apply-Profile -WorkDir $work -Name $Profile
}

$record = [ordered]@{
    label = $Label
    created = (Get-Date -Format o)
    source = $SourceGameDir
    baseline = $baseline
    work = $work
    manifest = $manifest
    profile = $Profile
    profile_d3d8_sha256 = $profileHash
    files = $fileCount
    bytes = $baselineBytes
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $copiesJson -Encoding UTF8
Write-Host "Recorded: $copiesJson" -ForegroundColor Green
Write-Host "DONE. Source installation was not modified." -ForegroundColor Green
