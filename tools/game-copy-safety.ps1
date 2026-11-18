# Shared preflight for scripts that mutate game copies. Never changes files.
function Assert-MutableGameCopyPath {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path, [string[]]$SourcePaths = @())

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $gameRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'game')).TrimEnd('\')
    $candidate = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $candidate = [IO.Path]::GetFullPath($candidate).TrimEnd('\')
    $leaf = Split-Path -Leaf $candidate
    # Reject Win32 trailing-dot/space aliases and DOS short names before the reserved-name test.
    if ($leaf -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $leaf.EndsWith('.')) {
        throw "Ambiguous game destination name: $candidate"
    }
    # Only direct children of this workspace's game directory are mutable copies.
    # This excludes original installations, the repository itself, ancestors and other drives.
    if (-not [string]::Equals((Split-Path -Parent $candidate), $gameRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe game destination: '$candidate'. Use a direct mutable child of '$gameRoot'."
    }
    if ((Split-Path -Leaf $candidate) -in @('baseline-pristine', 'profiles')) {
        throw "Protected game destination: $candidate"
    }
    foreach ($sourcePath in $SourcePaths) {
        if (-not $sourcePath) { continue }
        $source = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($sourcePath)).TrimEnd('\')
        if ([string]::Equals($candidate, $source, [StringComparison]::OrdinalIgnoreCase) -or
            $candidate.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $source.StartsWith($candidate + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Game destination overlaps a source: $candidate / $source"
        }
    }
    # Refuse aliases anywhere in the ancestry and any linked child before recursive deletion,
    # attrib, overwrite or backup. Traverse explicitly so links are never followed.
    $ancestor = $candidate
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point refused: $ancestor" }
            if (-not $item.PSIsContainer) { throw "Not a game directory: $ancestor" }
        }
        $ancestor = Split-Path -Parent $ancestor
    }
    if (Test-Path -LiteralPath $candidate) {
        $pending = New-Object 'System.Collections.Generic.Queue[string]'
        $pending.Enqueue($candidate)
        while ($pending.Count) {
            foreach ($item in Get-ChildItem -LiteralPath $pending.Dequeue() -Force -ErrorAction Stop) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked game content refused: $($item.FullName)" }
                if (-not $item.PSIsContainer -and $item.LinkType -eq 'HardLink') { throw "Hard-linked game content refused: $($item.FullName)" }
                if ($item.PSIsContainer) { $pending.Enqueue($item.FullName) }
            }
        }
    }
    return $candidate
}
