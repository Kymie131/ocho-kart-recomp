# Install the repo git hooks (blocks game assets from being committed).
# Usage: powershell -File scripts/install-hooks.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

git config core.hooksPath scripts/hooks
Write-Output "core.hooksPath -> scripts/hooks"

# Make the hook executable where the filesystem tracks it.
$hook = Join-Path $PSScriptRoot 'hooks\pre-commit'
if (Test-Path -LiteralPath $hook) {
    git update-index --chmod=+x -- scripts/hooks/pre-commit 2>$null
    Write-Output "pre-commit hook installed"
} else {
    throw "hooks/pre-commit not found"
}
