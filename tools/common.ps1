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

function Repair-GitSymlinks {
    # Git for Windows checks symlinks out as small text files holding the
    # target path unless Developer Mode / core.symlinks is on. The SDK's
    # libmspack submodule compiles cabextract/mspack/*.c, which are such
    # symlinks, so clang sees "../../libmspack/mspack/lzxd.c" as source code.
    # Replace every symlink-as-text in the repo and its submodules with a copy of
    # its target and hide the change from git status.
    param([Parameter(Mandatory = $true)][string]$Root)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $repos = @($Root) + @(& git -C $Root submodule --quiet foreach --recursive 'echo $toplevel/$sm_path' 2>$null |
            ForEach-Object { $_.Trim() })
        $fixed = 0
        foreach ($repo in $repos) {
            if (-not (Test-Path -LiteralPath $repo)) { continue }
            $links = & git -C $repo ls-files -s 2>$null | Where-Object { $_ -match '^120000 ' } |
                ForEach-Object { ($_ -split "`t", 2)[1] }
            foreach ($rel in $links) {
                $path = Join-Path $repo $rel
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
                $item = Get-Item -LiteralPath $path
                if ($item.LinkType) { continue }            # a real symlink already
                if ($item.Length -gt 1024) { continue }     # already replaced by a copy
                $target = (Get-Content -LiteralPath $path -Raw).Trim()
                $resolved = Join-Path (Split-Path -Parent $path) $target
                if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { continue }
                Copy-Item -LiteralPath $resolved -Destination $path -Force
                & git -C $repo update-index --assume-unchanged -- $rel 2>$null
                $fixed++
            }
        }
        if ($fixed) { Write-Output "replaced $fixed git symlink(s) with copies of their targets" }
    } finally { $ErrorActionPreference = $old }
}
