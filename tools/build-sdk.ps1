# Build and install the patched ReXGlue SDK (runtime + rexglue.exe) from the
# vendored submodule, so the game links against this repo's kernel fixes
# (DPC dispatch, cache: mount, input lock, XMA work, launcher cvars).
#
# Then build the game against it:
#   powershell -File tools/build.ps1 -SdkDir "$env:ProgramData\rexglue-sdk-ocho"
#
# Requires: VS Build Tools, LLVM/clang, Ninja, CMake 3.25+.

param(
    [string]$InstallDir = "$env:ProgramData\rexglue-sdk-ocho",
    [ValidateSet('Debug','Release','RelWithDebInfo')][string]$Config = 'RelWithDebInfo',
    [switch]$SkipPatch
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $repoRoot 'external\rexglue-sdk'

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars)) { throw "vcvars64.bat not found: $vcvars" }

if (-not $SkipPatch) {
    & (Join-Path $PSScriptRoot 'apply-sdk-patches.ps1')
    if ($LASTEXITCODE -ne 0) { throw "patching failed" }
}

$buildDir = Join-Path $sdk 'out\build\win-amd64'
$cmd = @(
    "call `"$vcvars`"",
    "cd /d `"$sdk`"",
    "cmake --preset win-amd64 -DCMAKE_INSTALL_PREFIX=`"$InstallDir`"",
    "cmake --build `"$buildDir`" --config $Config --parallel",
    "cmake --install `"$buildDir`" --config $Config"
) -join " && "

Write-Output "== ReXGlue SDK ($Config) -> $InstallDir =="
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "SDK build failed ($LASTEXITCODE)" }
Write-Output "done. Rebuild the game with: tools/build.ps1 -SdkDir `"$InstallDir`""
