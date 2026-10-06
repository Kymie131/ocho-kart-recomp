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
    # Release is always built: it is the only configuration that installs
    # rexglue.exe. Add another one (e.g. RelWithDebInfo for PDBs) with -Config.
    [ValidateSet('Debug','Release','RelWithDebInfo')][string]$Config = 'Release',
    [switch]$SkipPatch
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $repoRoot 'external\rexglue-sdk'

. (Join-Path $PSScriptRoot 'common.ps1')
$vcvars = Find-VcVars

if (-not $SkipPatch) {
    & (Join-Path $PSScriptRoot 'apply-sdk-patches.ps1')
    if ($LASTEXITCODE -ne 0) { throw "patching failed" }
}

# libmspack ships its cabextract/mspack sources as git symlinks; see common.ps1.
Repair-GitSymlinks -Root $sdk

$buildDir = Join-Path $sdk 'out\build\win-amd64'
$configs = @('Release')
if ($Config -ne 'Release') { $configs += $Config }
$steps = @("call `"$vcvars`"", "cd /d `"$sdk`"",
           "cmake --preset win-amd64 -DCMAKE_INSTALL_PREFIX=`"$InstallDir`"")
foreach ($c in $configs) {
    $steps += "cmake --build `"$buildDir`" --config $c --parallel"
    $steps += "cmake --install `"$buildDir`" --config $c"
}
$cmd = $steps -join " && "

Write-Output "== ReXGlue SDK ($($configs -join ', ')) -> $InstallDir =="
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "SDK build failed ($LASTEXITCODE)" }
$rexglue = Join-Path $InstallDir 'bin\rexglue.exe'
if (-not (Test-Path -LiteralPath $rexglue)) { throw "install finished but $rexglue is missing" }
Write-Output "done: $rexglue"
Write-Output "Next: tools/run-codegen.ps1 -ReXGlue `"$rexglue`" ..., then tools/build.ps1 -SdkDir `"$InstallDir`""
