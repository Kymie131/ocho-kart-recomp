# Build the UE3 LZX helper used by ue3_catalog.py.
# Compiles tools/catalog/ue3lzx.c + libmspack's lzxd.c (from the vendored
# rexglue-sdk submodule) into tools/out/ue3lzx.dll (gitignored).
# Requires: VS Build Tools (Windows SDK + MSVC headers) and LLVM/clang on PATH,
# and `git submodule update --init --recursive` so libmspack is present.

param(
    [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'out')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mspack = Join-Path $repoRoot 'external\rexglue-sdk\thirdparty\libmspack\libmspack\mspack'
if (-not (Test-Path -LiteralPath (Join-Path $mspack 'lzxd.c'))) {
    throw "libmspack not found at $mspack (run: git submodule update --init --recursive)"
}

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'common.ps1')
$vcvars = Find-VcVars
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) { throw "clang not on PATH" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$src = Join-Path $PSScriptRoot 'ue3lzx.c'
$dll = Join-Path $OutDir 'ue3lzx.dll'

$cmd = "call `"$vcvars`" && clang -O2 -shared -D_CRT_SECURE_NO_WARNINGS -I`"$mspack`" -o `"$dll`" `"$src`" `"$mspack\lzxd.c`""
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }

Write-Output "built $dll"
