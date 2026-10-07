# Apply this repo's ReXGlue SDK changes to the vendored submodule.
#
# patches/rexglue-sdk-local-all.patch is the single source of truth (every local
# change on top of upstream v0.10.0, commit c94f5eb). The focused patches in
# patches/ are subsets kept for upstream PRs; do not apply them on top of it.
#
# Idempotent: if the patch is already applied it does nothing; if the submodule
# has other, conflicting edits it stops and tells you.

param(
    [string]$Patch = 'rexglue-sdk-local-all.patch',
    # Stash whatever is in the submodule first (older hand-applied local edits).
    # Safe here: the consolidated patch already contains every local change.
    [switch]$StashLocalChanges
)

$ErrorActionPreference = 'Stop'

# git prints to stderr on a failed --check; under 'Stop' Windows PowerShell 5.1
# would make that a terminating error, so run git with 'Continue' and use the
# exit code.
function Invoke-Git {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git @args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $repoRoot 'external\rexglue-sdk'
$patchPath = Join-Path $repoRoot (Join-Path 'patches' $Patch)

if (-not (Test-Path -LiteralPath (Join-Path $sdk 'CMakeLists.txt'))) {
    throw "submodule missing: run 'git submodule update --init --recursive'"
}
if (-not (Test-Path -LiteralPath $patchPath)) { throw "patch not found: $patchPath" }

$head = ((Invoke-Git -C $sdk rev-parse HEAD) | Select-Object -Last 1).Trim()
if ($head -ne 'c94f5ebdcb3c9d1a460ca48e04f9758448f8d518') {
    Write-Warning "submodule HEAD is $head, the patches are made against v0.10.0 (c94f5eb)"
}

$null = Invoke-Git -C $sdk apply --reverse --check $patchPath
if ($LASTEXITCODE -eq 0) {
    Write-Output "already applied: $Patch"
    exit 0
}

# The consolidated patch holds every local change, so an older version of it
# (or hand edits it already contains) is replaced: stash the submodule edits as a
# backup and apply the current patch on a clean tree.
if (-not $StashLocalChanges) {
    $null = Invoke-Git -C $sdk apply --check $patchPath
    if ($LASTEXITCODE -ne 0 -and (Invoke-Git -C $sdk status --porcelain --untracked-files=no)) {
        Write-Output "submodule has an older set of local edits; replacing them with $Patch"
        $StashLocalChanges = $true
    }
}
if ($StashLocalChanges -and (Invoke-Git -C $sdk status --porcelain --untracked-files=no)) {
    Invoke-Git -C $sdk stash push -m "ocho-kart: before apply-sdk-patches $(Get-Date -Format s)"
    if ($LASTEXITCODE -ne 0) { throw "git stash failed in $sdk" }
    Write-Output "stashed previous submodule edits (git -C external/rexglue-sdk stash list)"
}

Invoke-Git -C $sdk apply --check $patchPath
if ($LASTEXITCODE -ne 0) {
    throw "patch does not apply cleanly. The submodule has other local edits; " +
          "stash or reset them (git -C external/rexglue-sdk stash) and run again."
}
Invoke-Git -C $sdk apply $patchPath
if ($LASTEXITCODE -ne 0) { throw "git apply failed ($LASTEXITCODE)" }
Write-Output "applied: $Patch"
