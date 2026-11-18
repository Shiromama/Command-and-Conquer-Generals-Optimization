#requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference='Stop'

function Test-Package([string]$Directory) {
    foreach ($file in @('zh-patcher.exe','manifest.json','engine.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Directory $file) -PathType Leaf)) { return $false }
    }
    return $true
}

$packageDir=$PSScriptRoot
if (-not (Test-Package $packageDir) -and (Split-Path -Leaf $PSScriptRoot) -eq 'patcher') {
    $repo=Split-Path -Parent $PSScriptRoot
    $stateFile=Join-Path $repo 'docs/state.json'
    if ((Test-Path -LiteralPath (Join-Path $repo 'AGENTS.md') -PathType Leaf) -and
        (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
        try {
            $state=Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            $artifactRoot=Join-Path $repo 'artifacts'
            $recorded=[IO.Path]::GetFullPath((Join-Path $repo $state.alpha_release.package_dir))
            if ($recorded.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
                $packageDir=$recorded
            }
        } catch {
            Write-Host 'Could not read the local package location from docs/state.json.'
        }
    }
}

if (-not (Test-Package $packageDir)) {
    Write-Host 'Patcher package missing or incomplete. Extract the entire patcher ZIP, then open Patcher.cmd from the extracted folder.'
    exit 1
}
$exe=Join-Path $packageDir 'zh-patcher.exe'

Write-Host 'Zero Hour Patcher 0.1.0-alpha.1'
$dialog=New-Object Windows.Forms.FolderBrowserDialog
$dialog.Description='Choose a writable Zero Hour copy containing Generals.exe.'
$dialog.ShowNewFolderButton=$false
try {
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit }
    $gameDir=$dialog.SelectedPath
} finally {
    $dialog.Dispose()
}

Write-Host "Game: $gameDir"
Write-Host '1  Install'
Write-Host '2  Uninstall'
$actions=@{'1'='install';'2'='uninstall'}
do {
    $choice=(Read-Host 'Choose 1 or 2 (Enter to close)').Trim()
    if (-not $choice) { exit }
    $action=$actions[$choice]
} until ($action)

& $exe $action --game-dir $gameDir --recover-interrupted --progress
exit $LASTEXITCODE
