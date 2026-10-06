# Run ReXGlue codegen on a local analysis project.
# Generated C++ stays outside this repo.
#
# Usage:
#   powershell -File tools/run-codegen.ps1 -DumpPath "C:/path/to/EL CHAVO KART"
#   powershell -File tools/run-codegen.ps1 -DumpPath "..." -Force
#
# -DumpPath is the folder that contains default.xex. It is substituted into the
# manifest that is copied to the analysis project (the repo manifest keeps a
# placeholder so no personal paths are committed).

param(
    [Parameter(Mandatory = $true)][string]$DumpPath,
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [string]$ReXGlue = "$env:ProgramData\rextools\rexglue.exe",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $repoRoot 'tools\config\ocho_kart_manifest.toml'

if (-not (Test-Path -LiteralPath $ReXGlue)) { throw "rexglue.exe not found: $ReXGlue" }
if (-not (Test-Path -LiteralPath $manifest)) { throw "manifest not found: $manifest" }
if (-not (Test-Path -LiteralPath (Join-Path $DumpPath 'default.xex'))) {
    throw "default.xex not found under: $DumpPath"
}
if (-not (Test-Path -LiteralPath $ProjectDir)) { throw "analysis project not found: $ProjectDir" }

$dump = ($DumpPath -replace '\\', '/').TrimEnd('/')
$projManifest = Join-Path $ProjectDir 'ocho_kart_manifest.toml'

# Output folder must match what the project's src/main.cpp includes:
# `rexglue init` from v0.10.0 writes "generated/default/<name>_init.h", older
# projects used "generated/<name>_init.h".
$outDir = 'generated'
$mainCpp = Join-Path $ProjectDir 'src\main.cpp'
if ((Test-Path -LiteralPath $mainCpp) -and ((Get-Content -LiteralPath $mainCpp -Raw) -match 'generated/default/')) {
    $outDir = 'generated/default'
}

(Get-Content -LiteralPath $manifest -Raw) `
    -replace 'REPLACE_WITH_YOUR_DUMP_ROOT', $dump `
    -replace 'out_directory_path = "generated"', "out_directory_path = `"$outDir`"" |
    Set-Content -LiteralPath $projManifest -Encoding UTF8

$argv = @('codegen', $projManifest)
if ($Force) { $argv = @('--force') + $argv }

Write-Output "dump    : $dump"
Write-Output "output  : $outDir"
Write-Output "manifest: $projManifest"
Write-Output "rexglue $($argv -join ' ')"
& $ReXGlue @argv
exit $LASTEXITCODE
