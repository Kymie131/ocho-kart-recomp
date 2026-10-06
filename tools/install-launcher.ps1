# Deploy the canonical launcher app into the analysis project.
# The project should not keep its UI in the repo, so the source of truth lives
# in src/launcher/ and gets copied into the project before a build. Codegen
# writes src/<name>_app.h only on first init (RegeneratePolicy::FirstInitOnly),
# so overwriting it here is intentional and safe between builds.
#
# Usage:
#   powershell -File tools/install-launcher.ps1
#   powershell -File tools/install-launcher.ps1 -ProjectDir "D:/some/project"

param(
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repoRoot 'src\launcher\ocho_kart_app.h'
$dst = Join-Path $ProjectDir 'src\ocho_kart_app.h'

if (-not (Test-Path -LiteralPath $src)) { throw "launcher source missing: $src" }
if (-not (Test-Path -LiteralPath $ProjectDir)) { throw "project not found: $ProjectDir" }

Copy-Item -LiteralPath $src -Destination $dst -Force
Write-Output "launcher deployed: $dst"

# Host-side music player, included by the launcher.
$hostSrc = Join-Path $repoRoot 'src\audio\host_music.h'
$hostDir = Join-Path $ProjectDir 'src\audio'
$hostDst = Join-Path $hostDir 'host_music.h'
if (Test-Path -LiteralPath $hostSrc) {
    New-Item -ItemType Directory -Force -Path $hostDir | Out-Null
    Copy-Item -LiteralPath $hostSrc -Destination $hostDst -Force
    Write-Output "host music deployed: $hostDst"
}
