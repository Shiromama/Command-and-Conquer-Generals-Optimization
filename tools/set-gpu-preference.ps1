#requires -Version 5.1
<#
.SYNOPSIS
  Enable, disable, or query the Windows per-app "High performance" GPU preference.

.DESCRIPTION
  D3D8 exposes only the display adapter on hybrid laptops, so the engine cannot
  select the discrete GPU by itself (verified: adapter-probe reports one Intel
  adapter). Windows' per-application GPU preference is honored by D3D9/DXGI, so
  the pair "d3d8to9 wrapper + High performance preference" is what moves this
  game onto the NVIDIA GPU.

  The change is per-user (HKCU\Software\Microsoft\DirectX\UserGpuPreferences),
  reversible with -Action Disable, and needs no elevation. It is never applied
  silently: the caller must name the executable.

.PARAMETER ExePath
  Full path to the game executable to configure.

.PARAMETER Action
  Enable (GpuPreference=2), Disable (remove the value), or Query.

.EXAMPLE
  .\tools\set-gpu-preference.ps1 -ExePath game\shockwave-engine\Generals.exe -Action Enable
  .\tools\set-gpu-preference.ps1 -ExePath game\shockwave-engine\Generals.exe -Action Disable
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [ValidateSet('Enable', 'Disable', 'Query')][string]$Action = 'Query'
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $ExePath).Path
$key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'

switch ($Action) {
    'Enable' {
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        New-ItemProperty -Path $key -Name $resolved -Value 'GpuPreference=2;' -PropertyType String -Force | Out-Null
        Write-Host "Enabled high-performance GPU preference for: $resolved"
    }
    'Disable' {
        if ((Get-Item -Path $key -ErrorAction SilentlyContinue) -and
            (Get-ItemProperty -Path $key -Name $resolved -ErrorAction SilentlyContinue)) {
            Remove-ItemProperty -Path $key -Name $resolved
            Write-Host "Removed GPU preference for: $resolved"
        } else {
            Write-Host "No GPU preference present for: $resolved"
        }
    }
    'Query' {
        $value = $null
        if (Test-Path $key) {
            $value = (Get-ItemProperty -Path $key -Name $resolved -ErrorAction SilentlyContinue).$resolved
        }
        if ($null -eq $value) {
            Write-Host "GPU preference: <none> for $resolved"
        } else {
            Write-Host "GPU preference: $value for $resolved"
        }
    }
}
