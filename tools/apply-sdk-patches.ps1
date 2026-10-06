# Apply this repo's ReXGlue SDK changes to the vendored submodule.
#
# patches/rexglue-sdk-local-all.patch is the single source of truth (every local
# change on top of upstream v0.10.0, commit c94f5eb). The focused patches in
# patches/ are subsets kept for upstream PRs; do not apply them on top of it.
#
# Idempotent: if the patch is already applied it does nothing; if the submodule
# has other, conflicting edits it stops and tells you.

param(
    [string]$Patch = 'rexglue-sdk-local-all.patch'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $repoRoot 'external\rexglue-sdk'
$patchPath = Join-Path $repoRoot (Join-Path 'patches' $Patch)

if (-not (Test-Path -LiteralPath (Join-Path $sdk 'CMakeLists.txt'))) {
    throw "submodule missing: run 'git submodule update --init --recursive'"
}
if (-not (Test-Path -LiteralPath $patchPath)) { throw "patch not found: $patchPath" }

$head = (git -C $sdk rev-parse HEAD).Trim()
if ($head -ne 'c94f5ebdcb3c9d1a460ca48e04f9758448f8d518') {
    Write-Warning "submodule HEAD is $head, the patches are made against v0.10.0 (c94f5eb)"
}

git -C $sdk apply --reverse --check $patchPath 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Output "already applied: $Patch"
    exit 0
}

git -C $sdk apply --check $patchPath
if ($LASTEXITCODE -ne 0) {
    throw "patch does not apply cleanly. The submodule has other local edits; " +
          "stash or reset them (git -C external/rexglue-sdk stash) and run again."
}
git -C $sdk apply $patchPath
if ($LASTEXITCODE -ne 0) { throw "git apply failed ($LASTEXITCODE)" }
Write-Output "applied: $Patch"
