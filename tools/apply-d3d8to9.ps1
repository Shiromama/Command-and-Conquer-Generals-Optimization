#requires -Version 5.1
<#
.SYNOPSIS
  Install, remove, or verify the optional d3d8to9 wrapper in a game copy.

.DESCRIPTION
  d3d8to9 translates Direct3D 8 calls to Direct3D 9. Our clean A/B measured a 5.7% Low-detail
  and 8.4% High+120 px gain, but it is a third-party DLL and can conflict with GenTool's
  d3d8.dll proxy. This tool is for copies only; it refuses the known real installation path.

.PARAMETER GameDir
  Game copy to modify. Defaults to game\engine-test.

.PARAMETER Action
  Install, Remove, or Verify. Default Verify.

.PARAMETER Version
  d3d8to9 release version. Default 1.16.0.

.EXAMPLE
  .\tools\apply-d3d8to9.ps1 -Action Install

.EXAMPLE
  .\tools\apply-d3d8to9.ps1 -Action Remove
#>
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [ValidateSet('Install', 'Remove', 'Verify')]
    [string]$Action = 'Verify',
    [string]$Version = '1.16.0'
)

$ErrorActionPreference = 'Stop'
# Resolve script-relative defaults after script scope is initialized (Windows PowerShell -File).
if (-not $GameDir) { $GameDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\engine-test' }

$repo = Split-Path -Parent $PSScriptRoot
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
if ($Action -ne 'Verify') { $GameDir = Assert-MutableGameCopyPath -Path $GameDir }
$exe = Join-Path $GameDir 'Generals.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Generals.exe not found in $GameDir" }
if ($GameDir -match 'R\.G\. Mechanics' -or $GameDir -match 'Program Files') {
    throw "Refusing to modify the real installation: $GameDir. Use a game copy."
}

$url = "https://github.com/crosire/d3d8to9/releases/download/v$Version/d3d8.dll"
$expected = '122928CFE225C25D30DECF7184A5D37E490CECF3B58256BA3206C7E1853F8AB8'
$cacheDir = Join-Path $repo 'artifacts\d3d8to9'
$cache = Join-Path $cacheDir "d3d8-$Version.dll"
$target = Join-Path $GameDir 'd3d8.dll'
$backup = Join-Path $GameDir 'd3d8.dll.pre-d3d8to9.bak'

function Get-Wrapper {
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    if (-not (Test-Path -LiteralPath $cache)) {
        Write-Host "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $cache -UseBasicParsing
    }
    $hash = (Get-FileHash -LiteralPath $cache -Algorithm SHA256).Hash
    if ($hash -ne $expected) { throw "d3d8to9 hash mismatch: $hash (expected $expected)" }
    return $cache
}

switch ($Action) {
    'Verify' {
        if (Test-Path -LiteralPath $target) {
            $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            Write-Host "d3d8.dll present: $hash"
            if ($hash -eq $expected) { Write-Host "This is d3d8to9 v$Version." -ForegroundColor Green }
            else { Write-Host "This is not the pinned d3d8to9 build." -ForegroundColor Yellow }
        } else {
            Write-Host "No local d3d8.dll; the system D3D8 DLL is used." -ForegroundColor Green
        }
        if (Test-Path -LiteralPath $backup) { Write-Host "Backup exists: $backup" }
    }
    'Install' {
        $src = Get-Wrapper
        if (Test-Path -LiteralPath $target) {
            $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            if ($hash -ne $expected) {
                if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
                Copy-Item -LiteralPath $target -Destination $backup -Force
                Write-Host "Backed up existing d3d8.dll to $backup"
            }
        }
        Copy-Item -LiteralPath $src -Destination $target -Force
        Write-Host "Installed d3d8to9 v$Version -> $target" -ForegroundColor Green
        Write-Host "  sha256: $((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash)"
        Write-Host "Remove with: tools\apply-d3d8to9.ps1 -Action Remove -GameDir '$GameDir'"
    }
    'Remove' {
        if (-not (Test-Path -LiteralPath $target)) {
            Write-Host "No local d3d8.dll to remove." -ForegroundColor Green
            exit 0
        }
        $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($hash -ne $expected) {
            throw "Refusing to remove a d3d8.dll that is not the pinned d3d8to9 build: $hash"
        }
        Remove-Item -LiteralPath $target -Force
        if (Test-Path -LiteralPath $backup) {
            Move-Item -LiteralPath $backup -Destination $target -Force
            Write-Host "Restored the previous d3d8.dll from $backup" -ForegroundColor Green
        } else {
            Write-Host "Removed d3d8to9; the system D3D8 DLL will be used." -ForegroundColor Green
        }
    }
}
