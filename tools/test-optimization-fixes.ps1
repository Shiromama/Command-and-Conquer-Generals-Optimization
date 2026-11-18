# Focused regressions for T-079/T-022/T-035. All process launches are mocked.
param([string]$ArtifactDir = '')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'game-copy-safety.ps1')
$artifact=if ($ArtifactDir) { [IO.Path]::GetFullPath($ArtifactDir) } else { Join-Path $repo 'artifacts\2026-11-17-t079-remediation' }
New-Item -ItemType Directory -Force -Path $artifact | Out-Null
$fixture=Join-Path $repo ('game\t079-tests-' + [guid]::NewGuid().ToString('N'))
$fixture=Assert-MutableGameCopyPath $fixture
New-Item -ItemType Directory -Path $fixture | Out-Null
Set-Content -LiteralPath (Join-Path $fixture 'Generals.exe') -Value 'INERT TEST FIXTURE - NEVER EXECUTED'
$results=New-Object 'System.Collections.Generic.List[string]'
function Assert($ok,[string]$message) { if (-not $ok) { throw "ASSERT: $message" }; $results.Add($message) }
function MustReject([scriptblock]$action,[string]$message,[string]$pattern='') {
 $rejected=$false; try { & $action | Out-Null } catch {
  if ($pattern -and $_.Exception.Message -notmatch $pattern) { throw "Wrong rejection for ${message}: $($_.Exception.Message)" }
  $rejected=$true
 }
 Assert $rejected $message
}
$baseline=Join-Path $repo 'game\baseline-pristine'
$original=Join-Path $repo 'Command and Conquer Generals Zero Hour'
$protectedHashes=@{}
foreach ($path in @((Join-Path $baseline 'Generals.exe'),(Join-Path $original 'Generals.exe'))) {
 $protectedHashes[$path]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
# Exercise the real mutating entry point, which must reject before Force or copying.
foreach ($bad in @($repo,(Join-Path $repo 'game'),$baseline,($baseline + '.'),($baseline + ' '),(Join-Path $repo 'game\BASELI~1'),(Join-Path $baseline 'child'),(Join-Path $repo 'game\profiles'),$original,(Join-Path $repo 'artifacts\outside-game'),(Join-Path $repo 'game\work\nested'))) {
 MustReject { & (Join-Path $PSScriptRoot 'stage-engine.ps1') -BuiltExe (Join-Path $fixture 'Generals.exe') -GameDir $bad -Force } "staging rejects $bad" "Unsafe|Protected|Ambiguous"
}
MustReject { Assert-MutableGameCopyPath $fixture -SourcePaths @((Join-Path $fixture 'Generals.exe')) } 'rejects source inside deletion target'
MustReject { & (Join-Path $PSScriptRoot 'prepare-game-copies.ps1') -SourceGameDir $original -Force } 'existing pristine baseline cannot be recreated with Force' 'immutable'
MustReject { & (Join-Path $PSScriptRoot 'apply-d3d8to9.ps1') -GameDir $baseline -Action Install } 'wrapper installation rejects baseline before downloading' 'Protected'
MustReject { & (Join-Path $PSScriptRoot 'play-shockwave-online.ps1') -GameDir $baseline -DryRun } 'online staging rejects baseline' 'Protected'
MustReject { & (Join-Path $PSScriptRoot 'prepare-shockwave-copy.ps1') -SourceDir $original -GameDir $baseline -Force } 'mod copy preparation rejects baseline' 'Protected'

$normalized=Assert-MutableGameCopyPath (Join-Path $repo 'game\unused\..\safe-copy')
Assert ($normalized -eq (Join-Path $repo 'game\safe-copy')) 'normalizes relative traversal before allowlist'
$junction=Join-Path $fixture 'linked'
New-Item -ItemType Junction -Path $junction -Target $artifact | Out-Null
MustReject { Assert-MutableGameCopyPath $fixture } 'rejects descendant junction before recursive mutation'
[IO.Directory]::Delete($junction)
$hard=Join-Path $fixture 'hardlink'
New-Item -ItemType HardLink -Path $hard -Target (Join-Path $fixture 'Generals.exe') | Out-Null
MustReject { Assert-MutableGameCopyPath $fixture } 'rejects hard-linked files'
Remove-Item -LiteralPath $hard
# A hard link also marks its original inode; recreate only our inert fixture.
Remove-Item -LiteralPath (Join-Path $fixture 'Generals.exe')
Set-Content -LiteralPath (Join-Path $fixture 'Generals.exe') -Value 'INERT TEST FIXTURE'
$env:ZH_HEAL_PULSE='7';$env:ZH_NOFPSLIMIT='sentinel';$env:ZH_FUTURE_DIAGNOSTIC='inherited'
$before=@{};foreach ($e in Get-ChildItem Env:) { if ($e.Name -like 'ZH_*') { $before[$e.Name]=$e.Value } }
function Start-Process {
 param($FilePath,$ArgumentList,$WorkingDirectory,[switch]$PassThru)
 $global:t079Child=@{};foreach ($e in Get-ChildItem Env:) { if ($e.Name -like 'ZH_*') { $global:t079Child[$e.Name]=$e.Value } }
 if ($global:t079FailStart) { throw 'injected process-start failure' }
 [pscustomobject]@{Id=12345}
}
function AssertRestored([string]$tag) {
 $after=@{};foreach ($e in Get-ChildItem Env:) { if ($e.Name -like 'ZH_*') { $after[$e.Name]=$e.Value } }
 Assert ($after.Count -eq $before.Count) "${tag}: variable count restored"
 foreach ($k in $before.Keys) { Assert ($after[$k] -ceq $before[$k]) "${tag}: restored $k" }
}
$launch=Join-Path $PSScriptRoot 'launch-game.ps1'
& $launch -GameDir $fixture -Mode exclusive -NoFocus -TestEnv @{ZH_HEAL_PULSE='11';ZH_NEW_TEST='1'}
Assert ($global:t079Child.ZH_HEAL_PULSE -eq '11') 'explicit diagnostic reaches child'
Assert (-not $global:t079Child.ContainsKey('ZH_FUTURE_DIAGNOSTIC')) 'unknown inherited diagnostic excluded'
Assert (-not $global:t079Child.ContainsKey('ZH_NOFPSLIMIT')) 'ordinary launch honors saved FPS preference'
Assert ($global:t079Child.ZH_DEBRIS_BROADPHASE -eq '0') 'ordinary launch disables experimental broadphase'
AssertRestored 'success'
$global:t079FailStart=$true
MustReject { & $launch -GameDir $fixture -Mode exclusive -NoFocus -NoFPSLimit -TestEnv @{ZH_ATTR_SAMPLE='1'} } 'injected launch failure propagated'
AssertRestored 'failure'
$global:t079FailStart=$false
MustReject { & $launch -GameDir $fixture -Mode exclusive -NoFocus -TestEnv @{'PATH'='bad'} } 'invalid TestEnv rejected'
AssertRestored 'invalid-input'
MustReject { & $launch -GameDir $fixture -Mode exclusive -NoFocus -TestEnv @{ZH_DEBRIS_BROADPHASE='1'} } 'simulation switch requires explicit mode'
& $launch -GameDir $fixture -Mode exclusive -NoFocus -ExperimentalSingleplayer -NoFPSLimit -TestEnv @{ZH_DEBRIS_BROADPHASE='1'}
Assert ($global:t079Child.ZH_EXPERIMENTAL_SINGLEPLAYER -eq '1' -and $global:t079Child.ZH_DEBRIS_BROADPHASE -eq '1') 'experimental launch explicitly opts in'
Assert ($global:t079Child.ZH_NOFPSLIMIT -eq '1') 'explicit uncapped startup reaches child'
AssertRestored 'experimental'
& $launch -GameDir $fixture -Mode exclusive -NoFocus -WithFpsLimit
Assert ($global:t079Child.ZH_NOFPSLIMIT -eq '0') 'explicit capped startup reaches child'
AssertRestored 'capped'
& $launch -GameDir $fixture -Mode exclusive -NoFocus -PathfindingQueue Heap
Assert ($global:t079Child.ZH_PF_HEAP -eq '1') 'explicit heap reaches child without experimental mode'
AssertRestored 'heap'
& $launch -GameDir $fixture -Mode exclusive -NoFocus
Assert (-not $global:t079Child.ContainsKey('ZH_PF_HEAP')) 'normal launch preserves engine queue default'
AssertRestored 'auto'
& $launch -GameDir $fixture -Mode exclusive -NoFocus -PathfindingQueue List
Assert ($global:t079Child.ZH_PF_HEAP -eq '0') 'explicit list override reaches child'
AssertRestored 'list'
& $launch -GameDir $fixture -Mode exclusive -NoFocus -TestEnv @{ZH_PF_HEAP='0'}
Assert ($global:t079Child.ZH_PF_HEAP -eq '0') 'Auto honors diagnostic list override'
AssertRestored 'auto-override'
MustReject { & $launch -GameDir $fixture -Mode exclusive -NoFocus -PathfindingQueue Heap -TestEnv @{ZH_PF_HEAP='0'} } 'conflicting queue selectors rejected'
AssertRestored 'queue-conflict'
# A stale inherited opt-out must not defeat the default of a new normal launch.
$env:ZH_PF_HEAP='0'
& $launch -GameDir $fixture -Mode exclusive -NoFocus
Assert (-not $global:t079Child.ContainsKey('ZH_PF_HEAP')) 'inherited queue override excluded'
Assert ($env:ZH_PF_HEAP -eq '0') 'inherited queue override restored to caller'
Remove-Item Env:ZH_PF_HEAP
AssertRestored 'inherited-queue'
# Unsupported renderer modes must fail before creating artifacts or writing preferences.
$shadow=Join-Path $PSScriptRoot 'benchmark-shadow-map.ps1'
$badEvidence=Join-Path $artifact 'must-not-be-created'
foreach ($mode in @('ShadowMap','Calibration','Mask','Delta','DepthFormat')) {
 $benchmarkParams=@{ ArtifactDir=$badEvidence; GameDir=$fixture }
 if ($mode -eq 'ShadowMap') { $benchmarkParams.Backend='ShadowMap' }
 elseif ($mode -eq 'DepthFormat') { $benchmarkParams.DepthFormat='INTZ' }
 else { $benchmarkParams[$mode]=$true }
 MustReject { & $shadow @benchmarkParams } "removed renderer mode $mode rejected in preflight" 'rejected and removed'
 Assert (-not (Test-Path -LiteralPath $badEvidence)) 'preflight leaves no artifact directory'
}
$shadowAst=[Management.Automation.Language.Parser]::ParseFile($shadow,[ref]$null,[ref]$null)
$backend=$shadowAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Backend' }
Assert ($backend.DefaultValue.Value -eq 'Stencil') 'shadow benchmark defaults to supported stencil backend'
foreach ($path in $protectedHashes.Keys) { Assert ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $protectedHashes[$path]) "protected executable unchanged: $path" }
# Resolved absolute target checked again before cleanup; only this freshly-created fixture.
$cleanup=Assert-MutableGameCopyPath $fixture
if ($cleanup -ne $fixture -or (Split-Path -Leaf $cleanup) -notlike 't079-tests-*') { throw 'Unsafe test cleanup target' }
Remove-Item -LiteralPath $cleanup -Recurse -Force
$results | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $artifact 'powershell-tests.json')
Write-Output ("PASS: {0} staging/environment assertions" -f $results.Count)
