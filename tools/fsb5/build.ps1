# Build the host-side FSB5 tool.
# Compiles tools/fsb5/fsb5.cpp to tools/out/fsb5.exe (gitignored).
# Requires: VS Build Tools (Windows SDK + MSVC headers) and LLVM/clang on PATH.

param(
    [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'out')
)

$ErrorActionPreference = 'Stop'

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars)) { throw "vcvars64.bat not found: $vcvars" }
if (-not (Get-Command clang++ -ErrorAction SilentlyContinue)) { throw "clang++ not on PATH" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$src = Join-Path $PSScriptRoot 'fsb5.cpp'
$exe = Join-Path $OutDir 'fsb5.exe'

$cmd = "call `"$vcvars`" && clang++ -std=c++17 -O2 -Wall -Wextra -o `"$exe`" `"$src`""
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }

Write-Output "built $exe"
