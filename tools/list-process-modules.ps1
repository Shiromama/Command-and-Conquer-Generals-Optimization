#requires -Version 5.1
<#
.SYNOPSIS
  List graphics-related modules loaded in a process, from a 32-bit host.

.DESCRIPTION
  A 64-bit PowerShell cannot enumerate the modules of a 32-bit (WOW64) game
  process. Running this script from
  %SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe lists the real
  modules, which is how the active Direct3D adapter (Intel iGPU vs NVIDIA) is
  identified: the vendor user-mode driver DLL (igdumdim32/nvumd...) appears in
  the list.

.PARAMETER Id
  Process id. Defaults to the first process named Generals.

.EXAMPLE
  & "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File tools\list-process-modules.ps1
#>
param(
    [int]$Id = 0,
    [string]$ProcessName = 'Generals',
    [string]$Filter = 'igd|nv|d3d8|d3d9|opengl|vulkan|GenTool|d3d8x'
)

$ErrorActionPreference = 'Stop'
if ($Id -eq 0) {
    $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p) { throw "No '$ProcessName' process" }
} else {
    $p = Get-Process -Id $Id
}

$mods = $p.Modules | Where-Object { $_.ModuleName -match $Filter }
if (-not $mods) {
    Write-Host "no matching modules; loaded modules: $((($p.Modules | Select-Object -ExpandProperty ModuleName) -join ', '))"
    exit 0
}
$mods | Select-Object ModuleName, FileName | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
