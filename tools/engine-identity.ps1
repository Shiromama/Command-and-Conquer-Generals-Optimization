#requires -Version 5.1
<#
.SYNOPSIS
  Report a PE image's full hash, per-section hashes and a link-independent identity.

.DESCRIPTION
  MSVC builds of identical source are not byte-identical: the linker writes a PE
  TimeDateStamp, a CodeView (RSDS) GUID/age, and some translation units embed
  __DATE__/__TIME__. A single SHA-256 therefore cannot identify an engine build;
  it identifies one link.

  This tool prints:
    - full SHA-256 (what engine.json/history recorded),
    - per-section SHA-256, so a code change is distinguishable from metadata,
    - .text-only SHA-256, the practical "same code" check,
    - a stable hash: the whole file with the PE TimeDateStamp and every CodeView
      RSDS GUID/age zeroed. The __DATE__/__TIME__ stamp is reported separately
      (offset + value) because its address depends on the build.

.PARAMETER Path
  PE file to inspect.

.PARAMETER Reference
  Optional second PE file. Prints per-section equality and lists differing byte
  ranges grouped by section, so a reviewer can see that only metadata moved.

.EXAMPLE
  .\tools\engine-identity.ps1 -Path build\engine-vs-community\GeneralsMD\Release\generalszh.exe `
      -Reference game\shockwave-engine\Generals.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Reference
)

$ErrorActionPreference = 'Stop'

function Get-PeInfo {
    param([byte[]]$Bytes)
    $e_lfanew = [BitConverter]::ToInt32($Bytes, 0x3C)
    if ([BitConverter]::ToUInt32($Bytes, $e_lfanew) -ne 0x00004550) { throw 'Not a PE image.' }
    $sectionCount = [BitConverter]::ToUInt16($Bytes, $e_lfanew + 6)
    $optSize = [BitConverter]::ToUInt16($Bytes, $e_lfanew + 20)
    $sectionTable = $e_lfanew + 24 + $optSize
    $sections = @()
    for ($i = 0; $i -lt $sectionCount; $i++) {
        $o = $sectionTable + ($i * 40)
        $name = ([Text.Encoding]::ASCII.GetString($Bytes, $o, 8)).TrimEnd([char]0)
        $rawSize = [BitConverter]::ToUInt32($Bytes, $o + 16)
        $rawPtr = [BitConverter]::ToUInt32($Bytes, $o + 20)
        $virtAddr = [BitConverter]::ToUInt32($Bytes, $o + 12)
        $sections += [pscustomobject]@{ Name = $name; VirtualAddress = [int64]$virtAddr; RawPointer = [int64]$rawPtr; RawSize = [int64]$rawSize }
    }
    # Data directories start after the optional header's fixed part (96 bytes for PE32,
    # 112 for PE32+; PE32 has BaseOfData, PE32+ has extra 8-byte alignment).
    $magic = [BitConverter]::ToUInt16($Bytes, $e_lfanew + 24)
    $dataDir = $e_lfanew + 24 + $(if ($magic -eq 0x20B) { 112 } else { 96 })
    $debugRva = [BitConverter]::ToUInt32($Bytes, $dataDir + (6 * 8))
    $debugSize = [BitConverter]::ToUInt32($Bytes, $dataDir + (6 * 8) + 4)
    [pscustomobject]@{
        TimeDateStampOffset = $e_lfanew + 8
        TimeDateStamp       = [BitConverter]::ToUInt32($Bytes, $e_lfanew + 8)
        Sections            = $sections
        DebugRva            = $debugRva
        DebugSize           = $debugSize
    }
}

function Get-Sha256 {
    param([byte[]]$Bytes, [int64]$Offset = 0, [int64]$Length = -1)
    if ($Length -lt 0) { $Length = $Bytes.Length - $Offset }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes, [int]$Offset, [int]$Length))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Get-RvaToOffset {
    param($Pe, [uint32]$Rva)
    foreach ($s in $Pe.Sections) {
        if ($Rva -ge $s.VirtualAddress -and $Rva -lt ($s.VirtualAddress + $s.RawSize)) {
            return [int64]($Rva - $s.VirtualAddress + $s.RawPointer)
        }
    }
    throw ('RVA 0x{0:X} is not inside any section raw range.' -f $Rva)
}

function Get-Identity {
    param([string]$File)
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $File).Path)
    $pe = Get-PeInfo $bytes
    $stable = [byte[]]$bytes.Clone()
    # Zero the link timestamp.
    for ($i = 0; $i -lt 4; $i++) { $stable[$pe.TimeDateStampOffset + $i] = 0 }
    # Zero every CodeView RSDS GUID+age (16 bytes) recorded in the debug directory.
    if ($pe.DebugRva -ne 0 -and $pe.DebugSize -ge 28) {
        $off = Get-RvaToOffset $pe $pe.DebugRva
        $count = [int]($pe.DebugSize / 28)
        for ($i = 0; $i -lt $count; $i++) {
            $entry = $off + ($i * 28)
            $type = [BitConverter]::ToUInt32($bytes, $entry + 12)
            $size = [BitConverter]::ToUInt32($bytes, $entry + 16)
            # +20 is AddressOfRawData (RVA); +24 is PointerToRawData (file offset).
            $data = [BitConverter]::ToUInt32($bytes, $entry + 24)
            # Each debug directory entry carries its own link timestamp.
            for ($k = 0; $k -lt 4; $k++) { $stable[$entry + 4 + $k] = 0 }
            if ($type -eq 2 -and $size -ge 24) {
                $sigOff = [int64]$data
                if (([Text.Encoding]::ASCII.GetString($bytes, $sigOff, 4)) -eq 'RSDS') {
                    # GUID (16) + Age (4) are per-link.
                    for ($k = 0; $k -lt 20; $k++) { $stable[$sigOff + 4 + $k] = 0 }
                }
            }
        }
    }
    # MSVC embeds __DATE__/__TIME__ in .rdata ("Nov 15 2026\016:39:16"). Zero the pair so
    # two links of the same source compare equal.
    $rdata = $pe.Sections | Where-Object Name -eq '.rdata' | Select-Object -First 1
    $stamps = @()
    if ($rdata) {
        $text = [Text.Encoding]::GetEncoding(28591).GetString($stable, [int]$rdata.RawPointer, [int]$rdata.RawSize)
        $pattern = '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ 0-9][0-9] [0-9]{4}\x00[0-9]{2}:[0-9]{2}:[0-9]{2}'
        foreach ($m in [regex]::Matches($text, $pattern)) {
            $start = [int]$rdata.RawPointer + $m.Index
            for ($k = 0; $k -lt $m.Length; $k++) { $stable[$start + $k] = 0 }
            $stamps += ('0x{0:X} {1}' -f $start, $m.Value.Replace([char]0, ' '))
        }
    }
    $ranges = $pe.Sections | ForEach-Object {
        [pscustomobject]@{ name = $_.Name; bytes = $_.RawSize; sha256 = (Get-Sha256 $bytes $_.RawPointer $_.RawSize) }
    }
    $text = $ranges | Where-Object name -eq '.text' | Select-Object -First 1
    [pscustomobject]@{
        file                 = (Resolve-Path -LiteralPath $File).Path
        size                 = $bytes.Length
        full_sha256          = (Get-Sha256 $bytes)
        stable_sha256        = (Get-Sha256 $stable)
        text_sha256          = if ($text) { $text.sha256 } else { $null }
        time_date_stamp      = ('0x{0:X8}' -f $pe.TimeDateStamp)
        build_stamps         = $stamps
        sections             = $ranges
        bytes                = $bytes
    }
}

$info = Get-Identity $Path
Write-Host "File:            $($info.file)"
Write-Host "Size:            $($info.size)"
Write-Host "Full SHA-256:    $($info.full_sha256)   (one link)"
Write-Host "Stable SHA-256:  $($info.stable_sha256) (timestamp + PDB GUID/age zeroed)"
Write-Host "Text SHA-256:    $($info.text_sha256)   (code only)"
Write-Host "TimeDateStamp:   $($info.time_date_stamp)"
if ($info.build_stamps.Count) { Write-Host "Build stamp(s):  $($info.build_stamps -join '; ')" }
Write-Host ''
$info.sections | Format-Table -AutoSize name, bytes, sha256

if ($Reference) {
    $ref = Get-Identity $Reference
    Write-Host ''
    Write-Host "Reference:       $($ref.file)"
    Write-Host "Full SHA-256:    $($ref.full_sha256)"
    Write-Host "Stable SHA-256:  $($ref.stable_sha256)"
    Write-Host "Text SHA-256:    $($ref.text_sha256)"
    Write-Host ''
    $comparison = foreach ($s in $info.sections) {
        $r = $ref.sections | Where-Object name -eq $s.name | Select-Object -First 1
        [pscustomobject]@{
            section = $s.name
            equal   = ($r -and $r.sha256 -eq $s.sha256)
            built   = $s.sha256.Substring(0, 12)
            reference = if ($r) { $r.sha256.Substring(0, 12) } else { '(absent)' }
        }
    }
    $comparison | Format-Table -AutoSize
    if ($info.stable_sha256 -eq $ref.stable_sha256) {
        Write-Host 'STABLE IDENTITY MATCH: same code and data apart from link metadata.' -ForegroundColor Green
    } else {
        Write-Host 'STABLE IDENTITY DIFFERS: source or build settings changed.' -ForegroundColor Yellow
        $a = $info.bytes; $b = $ref.bytes
        $n = [Math]::Min($a.Length, $b.Length)
        $first = -1; $count = 0
        for ($i = 0; $i -lt $n; $i++) { if ($a[$i] -ne $b[$i]) { $count++; if ($first -lt 0) { $first = $i } } }
        Write-Host ("differing bytes: {0}, first at 0x{1:X}" -f $count, $first)
    }
}
