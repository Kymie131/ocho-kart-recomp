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

# The game needs the Xenos GPU plugin (rexgpu-xenos.dll) next to the exe;
# without it the runtime logs "GPU plugin 'xenos' not found" and exits. A
# project from `rexglue init` calls rexglue_setup_target(<name>) without
# plugins, so ask for it here (idempotent).
$cml = Join-Path $ProjectDir 'CMakeLists.txt'
if (Test-Path -LiteralPath $cml) {
    $text = Get-Content -LiteralPath $cml -Raw
    if ($text -notmatch 'GPU_PLUGINS') {
        $new = [regex]::Replace($text, 'rexglue_setup_target\(\s*([A-Za-z0-9_]+)\s*\)', 'rexglue_setup_target($1 GPU_PLUGINS xenos)')
        if ($new -ne $text) {
            Set-Content -LiteralPath $cml -Value $new -Encoding UTF8 -NoNewline
            Write-Output "CMakeLists.txt: rexglue_setup_target now stages the xenos GPU plugin"
            # POST_BUILD steps only run when the exe relinks; force that once.
            $exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
            if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
        } else {
            Write-Warning "CMakeLists.txt: could not find rexglue_setup_target(...) to add GPU_PLUGINS xenos"
        }
    }
}

# Diagnostic hooks (strong overrides of generated guest functions). Pass-through
# unless the game runs with --fmod_diag=true (run-game.ps1 -Trace does).
$diagFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src\diag') -Filter '*.cpp' -File -ErrorAction SilentlyContinue)
if ($diagFiles.Count) {
    $diagDir = Join-Path $ProjectDir 'src\diag'
    New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
    foreach ($f in $diagFiles) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $diagDir $f.Name) -Force
        Write-Output "diagnostics deployed: $diagDir\$($f.Name)"
    }
    if (Test-Path -LiteralPath $cml) {
        foreach ($f in $diagFiles) {
            $text = Get-Content -LiteralPath $cml -Raw
            $rel = "src/diag/$($f.Name)"
            if ($text -match [regex]::Escape($rel)) { continue }
            $new = ([regex]'(?m)^([ \t]*)src/main\.cpp[ \t]*(\r?)$').Replace($text, "`$1src/main.cpp`$2`n`$1$rel`$2", 1)
            if ($new -ne $text) {
                Set-Content -LiteralPath $cml -Value $new -Encoding UTF8 -NoNewline
                Write-Output "CMakeLists.txt: added $rel"
            } else {
                Write-Warning "CMakeLists.txt: could not find 'src/main.cpp' in the sources list; add $rel by hand"
            }
        }
    }
}
