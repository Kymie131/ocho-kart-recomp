# Shared helpers for the PowerShell tools. Dot-source it:
#   . (Join-Path $PSScriptRoot 'common.ps1')        # from tools/
#   . (Join-Path (Split-Path -Parent $PSScriptRoot) 'common.ps1')   # from tools/<sub>/

function Find-VcVars {
    # Any VS 2022+ edition (Build Tools, Community, Professional, Enterprise)
    # with the C++ x64 tools. Falls back to the classic Build Tools path.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $inst = & $vswhere -latest -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>$null | Select-Object -First 1
        if ($inst) {
            $p = Join-Path $inst 'VC\Auxiliary\Build\vcvars64.bat'
            if (Test-Path -LiteralPath $p) { return $p }
        }
    }
    $fallback = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    throw "vcvars64.bat not found: install Visual Studio 2022 Build Tools with the 'Desktop development with C++' workload (tools/setup-and-test.ps1 can do it)"
}
