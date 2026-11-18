#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$GameDir = '',
    [ValidateRange(640,7680)][int]$Width = 1920,
    [ValidateRange(480,4320)][int]$Height = 1080,
    [Parameter(Mandatory=$true)][string]$ArtifactDir,
    [ValidateSet('Stencil','ShadowMap')][string]$Backend = 'Stencil',
    [ValidateRange(10,300)][int]$DurationSeconds = 20,
    [ValidateRange(1,1000)][int]$Units = 1000,
    [switch]$Wrapper,
    [switch]$Visible = $true,
    [switch]$Mask,
    [switch]$Delta,
    [switch]$Calibration,
    [ValidateSet(1,2,3,4)][int]$CalibrationLight = 1,
    [ValidateSet('Orthographic','Perspective','Angled')][string]$CalibrationCamera = 'Orthographic',
    [ValidateSet('Batched','Legacy')][string]$Submission = 'Batched',
    [ValidateSet('R32F','INTZ')][string]$DepthFormat = 'R32F',
    [ValidateRange(0.0,4.0)][double]$SlopeBias = 1.0,
    [ValidateSet(256,512,1024,2048,4096)][int]$ShadowMapSize = 1024,
    [ValidateRange(0,16)][int]$ReceiverBias = 1,
    [ValidateRange(0.0,0.02)][double]$Bias = 0.001,
    [switch]$Screenshot,
    [switch]$AtCamera,
    [switch]$Passable,
    [switch]$Diagnose,
    [switch]$SpawnAtCamera,
    [switch]$NoShroud,
    [int]$PinFrames = 240,
    [int]$SpawnDelayFrames = 0,
    [string]$Template = '',
    [string]$Map = 'maps\northamerica\northamerica.map',
    [string]$CenterWaypoint = 'Player_1_Start'
)
$ErrorActionPreference = 'Stop'
$rendererOptions = @('CalibrationLight','CalibrationCamera','Submission','DepthFormat','SlopeBias','ShadowMapSize','ReceiverBias','Bias')
$removedOption = @($rendererOptions | Where-Object { $PSBoundParameters.ContainsKey($_) }).Count -gt 0
if ($Backend -ne 'Stencil' -or $Calibration -or $Mask -or $Delta -or $removedOption) {
    throw 'The shadow-map renderer was rejected and removed. This tool supports Stencil measurement only; archived source is in engine/rejected/T-035.'
}
$repo = Split-Path -Parent $PSScriptRoot
if (-not $GameDir) { $GameDir = Join-Path $repo 'game\engine-test' }
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$GameDir = Assert-MutableGameCopyPath -Path $GameDir
if (Test-Path -LiteralPath $ArtifactDir) { throw "Refusing to overwrite evidence: $ArtifactDir" }
New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null
$ArtifactDir = (Resolve-Path -LiteralPath $ArtifactDir).Path
$options = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Command and Conquer Generals Zero Hour Data\options.ini'
$original = [IO.File]::ReadAllBytes($options)
$beforeHash = (Get-FileHash -LiteralPath $options).Hash
[IO.File]::WriteAllBytes((Join-Path $ArtifactDir 'options-before.ini'), $original)
$old = @{}
foreach ($item in Get-ChildItem Env:) { if ($item.Name -like 'ZH_*') { $old[$item.Name] = $item.Value } }
$proc = $null; $installed = $false
try {
    if ($Wrapper) {
        if (Test-Path -LiteralPath (Join-Path $GameDir 'd3d8.dll')) { throw 'Wrapper probe requires an empty local d3d8.dll slot.' }
        & (Join-Path $PSScriptRoot 'apply-d3d8to9.ps1') -GameDir $GameDir -Action Install
        $installed = $true
    }
    & (Join-Path $PSScriptRoot 'apply-options-profile.ps1') -Profile custom -AntiAliasing 0 -StaticLOD High -OptionsPath $options -BackupDir $ArtifactDir
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) { Remove-Item -LiteralPath ('Env:' + $item.Name) }
    $env:ZH_MAP = $Map
    $env:ZH_STRESS = [string]$Units
    $env:ZH_STRESS_CENTER_MAP = if ($AtCamera) { '0' } else { '1' }
    $env:ZH_STRESS_CENTER_WAYPOINT = $CenterWaypoint
    $env:ZH_STRESS_PASSABLE = if ($Passable) { '1' } else { '0' }
    $env:ZH_STRESS_DELAY = [string]$SpawnDelayFrames
    $env:ZH_STRESS_DIAG = if ($Diagnose) { '1' } else { '0' }
    $env:ZH_STRESS_AT_CAMERA = if ($SpawnAtCamera) { '1' } else { '0' }
    $env:ZH_STRESS_NOSHROUD = if ($NoShroud) { '1' } else { '0' }
    $env:ZH_STRESS_PIN_FRAMES = [string]$PinFrames
    $env:ZH_STRESS_TEMPLATE = $Template
    $env:ZH_SHADOWSIZE = '0'
    $env:ZH_SHADOWDIST = '0'
    $env:ZH_DRAWDIST = '0'
    $env:ZH_PERF_LOG = Join-Path $ArtifactDir 'frames.csv'
    $env:ZH_PERF_SPLIT = Join-Path $ArtifactDir 'split.csv'
    $env:ZH_NOFPSLIMIT = '1'
    $env:ZH_EXPERIMENTAL_SINGLEPLAYER = '0'
    $env:ZH_DEBRIS_BROADPHASE = '0'
    $env:ZH_DEBRIS_PAIR_FILTER = '0'
    $exe = Join-Path $GameDir 'Generals.exe'
    [pscustomobject]@{
        backend=$Backend; map=$Map; center_waypoint=$CenterWaypoint
        at_camera=[bool]$AtCamera; passable=[bool]$Passable; diagnose=[bool]$Diagnose
        spawn_at_camera=[bool]$SpawnAtCamera; no_shroud=[bool]$NoShroud
        pin_frames=$PinFrames; spawn_delay_frames=$SpawnDelayFrames; template=$Template
        visible=[bool]$Visible; wrapper=[bool]$Wrapper
        wrapper_sha256=$(if ($installed) { (Get-FileHash -LiteralPath (Join-Path $GameDir 'd3d8.dll')).Hash } else { $null })
        units=$Units; width=$Width; height=$Height; duration=$DurationSeconds
        anti_aliasing=0; static_lod='High'; uncapped=$true
        exe_sha256=(Get-FileHash -LiteralPath $exe).Hash
        options_before=$beforeHash; options_test=(Get-FileHash -LiteralPath $options).Hash
        started=(Get-Date).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ArtifactDir 'parameters.json')
    $windowStyle = if ($Visible) { 'Normal' } else { 'Hidden' }
    $proc = Start-Process -FilePath $exe -WorkingDirectory $GameDir -ArgumentList @('-win','-quickstart','-xres',[string]$Width,'-yres',[string]$Height,'-noFPSLimit') -WindowStyle $windowStyle -PassThru
    Write-Output "Started $Backend pid=$($proc.Id)"
    for ($i=0; $i -lt $DurationSeconds; ++$i) {
        Start-Sleep -Seconds 1
        $proc.Refresh()
        if ($proc.HasExited) { throw "Game exited early: $($proc.ExitCode)" }
        if ($Screenshot -and $i -eq ($DurationSeconds - 2)) {
            & (Join-Path $PSScriptRoot 'capture-game-window.ps1') -ProcessName $proc.ProcessName -Path (Join-Path $ArtifactDir 'scene.png')
        }
    }
    Stop-Process -Id $proc.Id -Force; $proc.WaitForExit(); $proc = $null
    if (-not (Test-Path -LiteralPath (Join-Path $ArtifactDir 'frames.csv'))) { throw 'Frame log missing.' }
}
finally {
    if ($proc) { $proc.Refresh(); if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; $proc.WaitForExit() } }
    if ((Get-FileHash -LiteralPath $options).Hash -ne $beforeHash) { [IO.File]::WriteAllBytes($options,$original) }
    $restored = (Get-FileHash -LiteralPath $options).Hash
    [pscustomobject]@{ before=$beforeHash; after=$restored; equal=($beforeHash -eq $restored) } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ArtifactDir 'options-restored.json')
    foreach ($item in @(Get-ChildItem Env: | Where-Object Name -Like 'ZH_*')) { Remove-Item -LiteralPath ('Env:' + $item.Name) }
    foreach ($key in $old.Keys) { Set-Item -LiteralPath ('Env:' + $key) -Value $old[$key] }
    if ($installed) { & (Join-Path $PSScriptRoot 'apply-d3d8to9.ps1') -GameDir $GameDir -Action Remove }
    if ($beforeHash -ne $restored) { throw 'Options restore hash mismatch.' }
}
