# Run ReXGlue codegen on the local analysis project.
# Generated C++ stays outside this repo (see .gitignore / STATE.md).
#
# Usage:
#   powershell -File tools/run-codegen.ps1
#   powershell -File tools/run-codegen.ps1 -Force

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $repoRoot 'tools\config\ocho_kart_manifest.toml'
$rexglue  = 'C:\ProgramData\rextools\rexglue.exe'
$projDir  = 'C:\ProgramData\rextools\proj-ocho-kart'

if (-not (Test-Path -LiteralPath $rexglue)) {
    throw "rexglue.exe not found at $rexglue (install ReXGlue v0.10.0 prebuilt)"
}
if (-not (Test-Path -LiteralPath $manifest)) {
    throw "manifest not found: $manifest"
}
if (-not (Test-Path -LiteralPath $projDir)) {
    throw "analysis project not found: $projDir (was created by rexglue init)"
}

# Keep the analysis project manifest in sync with the repo copy.
$projManifest = Join-Path $projDir 'ocho_kart_manifest.toml'
Copy-Item -LiteralPath $manifest -Destination $projManifest -Force

$args = @('codegen', $projManifest)
if ($Force) { $args = @('--force') + $args }

Write-Output "rexglue $($args -join ' ')"
& $rexglue @args
exit $LASTEXITCODE
