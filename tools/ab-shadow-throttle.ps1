$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# Stage the T-066 build so the tested binary really contains the throttle.
.\tools\stage-engine.ps1 -BuiltExe build\engine-vs-community\GeneralsMD\Release\generalszh.exe -GameDir game\engine-test |
    Select-String 'sha256' | ForEach-Object { $_.Line }

.\tools\apply-options-profile.ps1 -Profile custom -AntiAliasing 0 -StaticLOD High | Out-Null
Write-Host "profile: AA 0 + High (shadows on)"

$root = 'artifacts\2026-11-16-t066-shadow-throttle'
New-Item -ItemType Directory -Force -Path $root | Out-Null

for ($i = 1; $i -le 2; $i++) {
    foreach ($v in @(@{ t = 'A'; thr = '0' }, @{ t = 'B'; thr = '33' })) {
        $dir = Join-Path $root ("{0}-{1}" -f $v.t, $i)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
        if ($v.thr -eq '0') { $env:ZH_SHADOW_THROTTLE = '0' } else { Remove-Item Env:\ZH_SHADOW_THROTTLE -ErrorAction SilentlyContinue }
        Write-Host ("=== {0}-{1} throttle={2} ===" -f $v.t, $i, $v.thr)
        .\tools\benchmark-entity-heavy.ps1 -GameDir game\engine-test -Runs 1 -StressUnits 1000 `
            -DurationSeconds 40 -ArtifactDir $dir | Out-Null
    }
}
Remove-Item Env:\ZH_SHADOW_THROTTLE -ErrorAction SilentlyContinue

# --- screenshots: prove the throttled build still draws shadows ---
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Fg {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
function Save-Shot([string]$path, [IntPtr]$hwnd) {
    if ($hwnd -ne [IntPtr]::Zero) {
        [void][Win32Fg]::ShowWindow($hwnd, 9)   # SW_RESTORE
        [void][Win32Fg]::SetForegroundWindow($hwnd)
        Start-Sleep -Milliseconds 900
    }
    $bmp = New-Object System.Drawing.Bitmap 1920, 1080
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "screenshot: $path (hwnd=$hwnd)"
}

foreach ($v in @(@{ t = 'A'; thr = '0' }, @{ t = 'B'; thr = '33' })) {
    Get-Process generals -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
    if ($v.thr -eq '0') { $env:ZH_SHADOW_THROTTLE = '0' } else { Remove-Item Env:\ZH_SHADOW_THROTTLE -ErrorAction SilentlyContinue }
    $env:ZH_MAP = 'maps\northamerica\northamerica.map'
    $env:ZH_STRESS = '1000'
    $env:ZH_NOFPSLIMIT = '1'
    $exe = (Resolve-Path (Join-Path $repo 'game\engine-test\Generals.exe')).Path
    $proc = Start-Process -FilePath $exe -ArgumentList '-win', '-quickstart', '-xres', '1920', '-yres', '1080', '-noFPSLimit' `
        -WorkingDirectory (Join-Path $repo 'game\engine-test') -PassThru
    Start-Sleep -Seconds 24
    $proc.Refresh()
    Save-Shot (Join-Path (Resolve-Path $root).Path ("shot-{0}.png" -f $v.t)) $proc.MainWindowHandle
    Start-Sleep -Seconds 1
    Stop-Process -Id $proc.Id -Force
    Start-Sleep -Seconds 3
    Write-Host ("screenshot arm {0} done (throttle={1})" -f $v.t, $v.thr)
}
Remove-Item Env:\ZH_SHADOW_THROTTLE, Env:\ZH_MAP, Env:\ZH_STRESS -ErrorAction SilentlyContinue
Write-Host 'T066 AB DONE'
