#requires -Version 5.1
<#
.SYNOPSIS
  Configure and build the GPLv3 Zero Hour source with MSVC 2022.

.DESCRIPTION
  Uses the Visual Studio Community instance that has ATL installed. Dependencies are fetched
  by CMake into the build directory (pinned revisions). No game files are modified.

.PARAMETER BuildDir
  CMake build directory (default: build\engine-vs-community).

.PARAMETER Profile
  Build with legacy profiling + Tracy (default) or a plain release build.

.PARAMETER Target
  CMake target (default: z_generals).

.PARAMETER VcInstance
  Visual Studio instance with ATL. Defaults to the Community install path.

.PARAMETER ConfigureOnly
  Configure without building.
#>
[CmdletBinding()]
param(
    [string]$BuildDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build\engine-vs-community'),
    [bool]$Profile = $true,
    [string]$Target = 'z_generals',
    [string]$VcInstance = 'C:\Program Files\Microsoft Visual Studio\2022\Community',
    [switch]$ConfigureOnly,
    [switch]$NoLtcg,
    [hashtable]$CmakeOptions = @{}
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'vendor\GeneralsGameCode'
if (-not (Test-Path -LiteralPath $source)) { throw "Source not found: $source" }
if (-not (Test-Path -LiteralPath $VcInstance)) { throw "Visual Studio instance not found: $VcInstance" }

$atl = Get-ChildItem (Join-Path $VcInstance 'VC\Tools\MSVC') -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'atlmfc\include\atlbase.h' } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $atl) { throw "ATL (atlbase.h) not found under $VcInstance. Install 'C++ ATL for latest v143 build tools'." }
Write-Host "ATL: $atl"

$profileArgs = @()
if ($Profile) {
    $profileArgs = @('-DRTS_BUILD_OPTION_PROFILE=ON', '-DRTS_BUILD_OPTION_PROFILE_TRACY=ON')
}
# T-064: link-time code generation is on by default (measured -3.6% median, EXP-010).
# Pass -NoLtcg for a faster build.
if (-not $NoLtcg) {
    $profileArgs += '-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON'
}

function Invoke-CMake {
    param([string]$Arguments, [string]$Name)
    $logDir = Join-Path $BuildDir 'project-logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $stdout = Join-Path $logDir "$Name.out.log"
    $stderr = Join-Path $logDir "$Name.err.log"
    # Start-Process joins an ArgumentList array with spaces without quoting; paths in this
    # repo contain '&' and spaces (and "Visual Studio 17 2022" contains spaces), so the
    # command line is composed explicitly with quotes.
    $proc = Start-Process -FilePath 'cmake.exe' -ArgumentList $Arguments -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (Test-Path -LiteralPath $stderr) {
        Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
    }
    if (Test-Path -LiteralPath $stdout) {
        Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
    }
    Write-Host ("cmake {0} exit={1} (logs: {2})" -f $Name, $proc.ExitCode, $logDir)
    return $proc.ExitCode
}

$configureArgs = "-S `"$source`" -B `"$BuildDir`" -G `"Visual Studio 17 2022`" -A Win32 -T v143 " +
    "-DCMAKE_GENERATOR_INSTANCE=`"$VcInstance`" " + ($profileArgs -join ' ')
foreach ($key in $CmakeOptions.Keys) {
    $configureArgs += " -D$key=`"$($CmakeOptions[$key])`""
}
$configureExit = Invoke-CMake -Arguments $configureArgs -Name 'configure'
if ($configureExit -ne 0) { throw "CMake configure failed: $configureExit" }

if (-not $ConfigureOnly) {
    $buildArgs = "--build `"$BuildDir`" --config Release --target $Target -- /m:8 /nodeReuse:false"
    $buildExit = Invoke-CMake -Arguments $buildArgs -Name 'build'
    if ($buildExit -ne 0) { throw "Build failed: $buildExit" }
    $exe = Join-Path $BuildDir "GeneralsMD\Release\generalszh.exe"
    if (Test-Path -LiteralPath $exe) {
        Write-Host ("Built: {0} ({1:N0} bytes, sha256 {2})" -f $exe, (Get-Item $exe).Length, (Get-FileHash $exe -Algorithm SHA256).Hash) -ForegroundColor Green
    }
}
