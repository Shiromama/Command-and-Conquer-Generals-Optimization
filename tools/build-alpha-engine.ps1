#requires -Version 5.1
[CmdletBinding()]
param([string]$SourceDir='', [string]$BuildDir='', [string]$DependencyBuild='', [switch]$ConfigureOnly)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
if (-not $SourceDir) { $SourceDir=Join-Path $repo 'build/alpha-engine-source' }
if (-not $BuildDir) { $BuildDir=Join-Path $repo 'build/alpha-engine-release' }
if (-not $DependencyBuild) { $DependencyBuild=Join-Path $repo 'build/engine-vs-community' }
if (-not (Test-Path -LiteralPath (Join-Path $SourceDir 'alpha-source.json'))) { throw 'Prepare alpha source first with tools/prepare-alpha-engine.py.' }
$null=New-Item -ItemType Directory -Force -Path $BuildDir
foreach ($mapping in @(@('_deps/lzhl-src','_deps/lzhl-src'),@('Core/Libraries/Source/Compression/_deps/zlib-1.1.4-src','Core/Libraries/Source/Compression/_deps/zlib-1.1.4-src'))) {
    $from=Join-Path $DependencyBuild $mapping[0];$to=Join-Path $BuildDir $mapping[1]
    if (-not (Test-Path -LiteralPath $from)) { throw "Missing cached dependency: $from" }
    $null=New-Item -ItemType Directory -Force -Path $to
    & robocopy.exe $from $to /E /XD .git /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw 'Dependency copy failed' }
}
$configure=@('-S',$SourceDir,'-B',$BuildDir,'-G','Visual Studio 17 2022','-A','Win32','-T','v143','-DCMAKE_GENERATOR_INSTANCE=C:/Program Files/Microsoft Visual Studio/2022/Community','-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON','-DRTS_BUILD_OPTION_PROFILE=OFF','-DRTS_BUILD_OPTION_PROFILE_TRACY=OFF','-DFETCHCONTENT_FULLY_DISCONNECTED=ON')
$sourcePrefix=[IO.Path]::GetFullPath($SourceDir).TrimEnd('\','/')
$trimFlag='/d1trimfile:"' + $sourcePrefix + '"'
$configure+=@("-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /W3 /GR /EHsc $trimFlag",'-DCMAKE_EXE_LINKER_FLAGS=/machine:X86 /PDBALTPATH:generalszh.pdb','-DCMAKE_SUPPRESS_REGENERATION=ON')
foreach ($name in @('DX8','GAMEMATH','GAMESPY','STB')) {
    $dep=Join-Path $DependencyBuild ('_deps/'+$name.ToLower()+'-src')
    if (-not (Test-Path -LiteralPath $dep)) { throw "Missing cached dependency: $dep" }
    $configure+=('-DFETCHCONTENT_SOURCE_DIR_'+$name+'='+$dep)
}
function Invoke-AlphaCmake([string[]]$Arguments,[string]$Name) {
    # Escape quotes and the backslashes immediately preceding a quote for CreateProcess.
    $commandLine=($Arguments | ForEach-Object { '"' + (($_ -replace '(\\*)"', '$1$1\"') -replace '(\\+)$','$1$1') + '"' }) -join ' '
    $process=Start-Process -FilePath 'cmake.exe' -ArgumentList $commandLine -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $BuildDir "$Name.log") -RedirectStandardError (Join-Path $BuildDir "$Name.err.log")
    if ($process.ExitCode -ne 0) { throw "Alpha $Name failed; see $BuildDir/$Name.log and $Name.err.log" }
}
Invoke-AlphaCmake -Arguments $configure -Name 'configure'
if ($ConfigureOnly) { return }
Invoke-AlphaCmake -Arguments @('--build',$BuildDir,'--config','Release','--target','z_generals','--','/m:1','/nodeReuse:false') -Name 'build'
Get-FileHash -LiteralPath (Join-Path $BuildDir 'GeneralsMD/Release/generalszh.exe') -Algorithm SHA256
