# Build the recompiled game (Phase 3).
# Requires: VS Build Tools (MSVC headers), LLVM/clang, Ninja, CMake, and the
# prebuilt ReXGlue SDK. Generated C++ lives in the analysis project.

param(
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [string]$SdkDir     = "$env:ProgramData\rexglue-sdk-bin",
    [ValidateSet('clang','msvc')][string]$Toolchain = 'clang',
    [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars)) { throw "vcvars64.bat not found: $vcvars" }
if (-not (Test-Path -LiteralPath $SdkDir)) { throw "SDK not found: $SdkDir" }
if (-not (Test-Path -LiteralPath $ProjectDir)) { throw "project not found: $ProjectDir" }

$sdkFwd = ($SdkDir -replace '\\','/')
$genDir = Join-Path $ProjectDir 'generated'
if (-not (Test-Path -LiteralPath (Join-Path $genDir 'sources.cmake'))) {
    throw "generated/sources.cmake missing - run tools/run-codegen.ps1 first"
}

$compilerArgs = if ($Toolchain -eq 'msvc') {
    "-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl"
} else {
    "-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++"
}

$buildType = 'RelWithDebInfo'
$cmd = @(
    "call `"$vcvars`"",
    "cmake -S `"$ProjectDir`" -B `"$ProjectDir\out\build\win-amd64`" -G Ninja -DCMAKE_BUILD_TYPE=$buildType -DCMAKE_PREFIX_PATH=`"$sdkFwd`" $compilerArgs"
) -join " && "

Write-Output "== configure ($Toolchain / $buildType) =="
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "configure failed ($LASTEXITCODE)" }

if (-not $ConfigureOnly) {
    Write-Output "== build =="
    cmd /c "call `"$vcvars`" && cmake --build `"$ProjectDir\out\build\win-amd64`" --parallel"
    if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
}

Write-Output "done"
