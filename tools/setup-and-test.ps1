# One-shot setup + build + traced test run of Ocho Kart on a Windows PC.
#
# What it does, in order (each step is skipped when already done):
#   1. Installs missing tools with winget: Git, CMake, Ninja, LLVM/Clang,
#      Python, FFmpeg, and Visual Studio 2022 Build Tools (C++ workload).
#   2. Clones the repo (or reuses it), brings in the fix branch from the
#      bundle if it is not on GitHub yet, and fetches all submodules.
#   3. Builds and installs the patched ReXGlue SDK (tools/build-sdk.ps1).
#   4. Creates the analysis project if missing (rexglue init), runs codegen,
#      deploys the launcher, and builds ocho_kart.exe.
#   5. Runs the game with the audio-investigation traces on, then writes a
#      short summary + the full log next to the bundle so it can be reviewed.
#
# Usage (from any PowerShell window; Windows asks for admin once for the
# Build Tools install):
#   powershell -ExecutionPolicy Bypass -File setup-and-test.ps1
#
# Re-running is safe; use -SkipInstall / -SkipBuild / -NoRun to do parts only.

param(
    [string]$DumpPath = "$env:USERPROFILE\Documents\PENDEJADAS DE ALAN\EL CHAVO KART\EL CHAVO KART",
    [string]$RepoDir = "$env:USERPROFILE\Documents\ocho-kart-recomp",
    [string]$RepoUrl = 'https://github.com/Kymie131/ocho-kart-recomp.git',
    [string]$Branch = 'fix/sdk-kernel-setjmp-lzx-docs',
    [string]$Bundle = "$env:USERPROFILE\Documents\PENDEJADAS DE ALAN\EL CHAVO KART\Claude outputs\ocho-kart-fixes.bundle",
    [string]$OutDir = "$env:USERPROFILE\Documents\PENDEJADAS DE ALAN\EL CHAVO KART\Claude outputs",
    [string]$SdkInstallDir = "$env:ProgramData\rexglue-sdk-ocho",
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [switch]$SkipInstall,
    [switch]$SkipBuild,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
$started = Get-Date
$transcript = Join-Path $OutDir 'setup-and-test.transcript.txt'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
try { Start-Transcript -Path $transcript -Force | Out-Null } catch { }

function Step($text) { Write-Host ""; Write-Host "==== $text ====" -ForegroundColor Cyan }

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    foreach ($extra in @("$env:ProgramFiles\LLVM\bin", "$env:ProgramFiles\Git\cmd",
                         "$env:ProgramFiles\CMake\bin", "$env:LOCALAPPDATA\Microsoft\WinGet\Links")) {
        if ((Test-Path -LiteralPath $extra) -and ($env:Path -notlike "*$extra*")) { $env:Path += ";$extra" }
    }
}

function Test-Tool($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Install-WingetPackage($id, $extraArgs = @()) {
    Write-Host "winget install $id"
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent @extraArgs
    $ErrorActionPreference = $old
    # winget returns non-zero for "already installed"; check the tool afterwards instead.
    Update-SessionPath
}

function Invoke-Checked([scriptblock]$block, [string]$what) {
    # Native tools (git, winget) write progress to stderr; under 'Stop' Windows
    # PowerShell 5.1 would turn that into a terminating error, so relax it here
    # and judge success by the exit code only.
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = 0
    try { & $block } finally { $ErrorActionPreference = $old }
    if ($LASTEXITCODE -ne 0) { throw "$what failed ($LASTEXITCODE)" }
}

if (-not (Test-Path -LiteralPath (Join-Path $DumpPath 'default.xex'))) {
    throw "default.xex not found under -DumpPath '$DumpPath'"
}

# ---------------------------------------------------------------- 1. tools
if (-not $SkipInstall) {
    Step '1/5 Tools'
    if (-not (Test-Tool winget)) { throw "winget is missing: install 'App Installer' from the Microsoft Store, then re-run" }
    Update-SessionPath
    $packages = @(
        @{ tool = 'git';    id = 'Git.Git' },
        @{ tool = 'cmake';  id = 'Kitware.CMake' },
        @{ tool = 'ninja';  id = 'Ninja-build.Ninja' },
        @{ tool = 'clang';  id = 'LLVM.LLVM' },
        @{ tool = 'python'; id = 'Python.Python.3.12' },
        @{ tool = 'ffmpeg'; id = 'Gyan.FFmpeg' }
    )
    foreach ($p in $packages) {
        if (Test-Tool $p.tool) { Write-Host "ok: $($p.tool)" } else { Install-WingetPackage $p.id }
    }

    # Same lookup as tools/common.ps1 (inlined: this script may run before the repo exists).
    $haveVc = $false
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $haveVc = [bool](& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    }
    if ($haveVc) {
        Write-Host 'ok: Visual Studio C++ tools'
    } else {
        Write-Host 'Installing Visual Studio 2022 Build Tools (C++ workload, Windows SDK). This takes a while and asks for admin.'
        Install-WingetPackage 'Microsoft.VisualStudio.2022.BuildTools' @('--override',
            '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    }

    foreach ($t in 'git', 'cmake', 'ninja', 'clang', 'python') {
        if (-not (Test-Tool $t)) { throw "$t is still not on PATH after installing. Open a new PowerShell window and re-run." }
    }
    Write-Host ("clang: " + ((& clang --version) | Select-Object -First 1))
}
Update-SessionPath

# ---------------------------------------------------------------- 2. repo
Step '2/5 Repository'
if (-not (Test-Path -LiteralPath (Join-Path $RepoDir '.git'))) {
    Write-Host "cloning $RepoUrl -> $RepoDir (GitHub may ask you to sign in)"
    Invoke-Checked { git clone $RepoUrl $RepoDir } 'git clone'
}
Push-Location $RepoDir
try {
    $ErrorActionPreference = 'Continue'   # git writes progress to stderr
    git fetch origin
    $ErrorActionPreference = 'Stop'
    $hasBranch = git rev-parse --verify --quiet "refs/heads/$Branch"
    if (-not $hasBranch) {
        $remote = git rev-parse --verify --quiet "refs/remotes/origin/$Branch"
        if ($remote) {
            Invoke-Checked { git branch $Branch "origin/$Branch" } 'git branch'
        } elseif (Test-Path -LiteralPath $Bundle) {
            Write-Host "branch not on GitHub yet; taking it from $Bundle"
            Invoke-Checked { git fetch $Bundle "${Branch}:${Branch}" } 'git fetch bundle'
        } else {
            throw "branch $Branch not found on origin and no bundle at $Bundle"
        }
    }
    if (git status --porcelain --ignore-submodules) {
        throw "the repo has uncommitted changes in $RepoDir; commit or stash them, then re-run"
    }
    Invoke-Checked { git checkout $Branch } 'git checkout'
    Write-Host 'fetching submodules (first time downloads several GB)...'
    Invoke-Checked { git submodule update --init --recursive } 'git submodule update'
} finally { Pop-Location }

. (Join-Path $RepoDir 'tools\common.ps1')
$tools = Join-Path $RepoDir 'tools'

# ---------------------------------------------------------------- 3-4. build
$rexglue = Join-Path $SdkInstallDir 'bin\rexglue.exe'
$exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
if (-not $SkipBuild) {
    Step '3/5 Patched ReXGlue SDK'
    & (Join-Path $tools 'apply-sdk-patches.ps1') -StashLocalChanges
    & (Join-Path $tools 'build-sdk.ps1') -InstallDir $SdkInstallDir -SkipPatch

    Step '4/5 Game'
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir 'CMakeLists.txt'))) {
        Write-Host "creating analysis project in $ProjectDir"
        New-Item -ItemType Directory -Force -Path $ProjectDir | Out-Null
        Invoke-Checked { & $rexglue -f init --project-name ocho_kart --xex-path (Join-Path $DumpPath 'default.xex') `
            --game-root $DumpPath --project-root $ProjectDir } 'rexglue init'
    }
    & (Join-Path $tools 'run-codegen.ps1') -DumpPath $DumpPath -ProjectDir $ProjectDir -ReXGlue $rexglue -Force
    if ($LASTEXITCODE -ne 0) { throw "codegen failed ($LASTEXITCODE)" }
    & (Join-Path $tools 'install-launcher.ps1') -ProjectDir $ProjectDir
    & (Join-Path $tools 'build.ps1') -ProjectDir $ProjectDir -SdkDir $SdkInstallDir
}
if (-not (Test-Path -LiteralPath $exe)) { throw "game not built: $exe" }

# ---------------------------------------------------------------- 5. run
if (-not $NoRun) {
    Step '5/5 Traced run'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $log = Join-Path $OutDir "run-trace-$stamp.log"
    $userData = Join-Path $OutDir 'test-user-data'
    Write-Host 'The game starts now. Get to the main menu, wait ~30 s, start one race if you can,'
    Write-Host 'then close the game window. The summary is written when it closes.'
    & (Join-Path $tools 'run-game.ps1') -DumpPath $DumpPath -ProjectDir $ProjectDir -Trace -LogLevel info `
        -LogFile $log -ExtraArgs @("--user_data_root=$userData")

    $lines = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log } else { @() }
    $summary = New-Object System.Collections.Generic.List[string]
    $summary.Add("Ocho Kart traced run $stamp (branch $Branch)")
    $summary.Add("log: $log ($($lines.Count) lines)")
    $summary.Add('')
    $count = { param($pattern) ($lines | Select-String -SimpleMatch $pattern).Count }
    $summary.Add("DPCs dispatched (KeInsertQueueDpc): $(& $count 'KeInsertQueueDpc dpc=')")
    $summary.Add("DPC routine not registered errors:  $(& $count 'is not a registered function')")
    $summary.Add("Symbolic links created by the title:")
    $lines | Select-String -SimpleMatch 'ObCreateSymbolicLink(' | Select-Object -First 20 | ForEach-Object { $summary.Add("  $($_.Line.Trim())") }
    $summary.Add("cache: file opens:")
    $lines | Select-String -Pattern "FILEOPEN.*cache" | Select-Object -First 30 | ForEach-Object { $summary.Add("  $($_.Line.Trim())") }
    $summary.Add("Sound bank / FMOD opens (.fsbcache, FMODAudio):")
    $lines | Select-String -Pattern 'FILEOPEN.*(fsbcache|FMOD)' | Select-Object -First 40 | ForEach-Object { $summary.Add("  $($_.Line.Trim())") }
    $summary.Add("XMA writes logged: $(& $count 'XMA')")
    $summary.Add("FATAL / invalid function lines:")
    $lines | Select-String -Pattern 'FATAL|invalid or unregistered' | Select-Object -First 20 | ForEach-Object { $summary.Add("  $($_.Line.Trim())") }
    $cacheDir = Join-Path $userData 'xbox_cache'
    $summary.Add("Files the title wrote under xbox_cache:")
    if (Test-Path -LiteralPath $cacheDir) {
        Get-ChildItem -LiteralPath $cacheDir -Recurse -File | Select-Object -First 40 |
            ForEach-Object { $summary.Add("  $($_.FullName.Substring($cacheDir.Length)) ($($_.Length) bytes)") }
    } else { $summary.Add('  (folder not created)') }
    $summaryPath = Join-Path $OutDir "run-trace-$stamp.summary.txt"
    $summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host ''
    $summary | ForEach-Object { Write-Host $_ }
    Write-Host ''
    Write-Host "Summary: $summaryPath"
}

Write-Host ("Done in {0:N0} min." -f ((Get-Date) - $started).TotalMinutes)
try { Stop-Transcript | Out-Null } catch { }
