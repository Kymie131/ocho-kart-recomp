# Phase 5 boot loop helper: sync manifest, run codegen, build, run the game,
# print the last log lines. Repeats until the game boots or a new blocker.
#
# Usage: powershell -File tools/boot-loop.ps1 -Tag "006"

param(
    [string]$Tag = "run",
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [string]$DumpPath = "C:/Users/israe/OneDrive/Documentos/REPOS/Proyecto_descompilacion/EL CHAVO KART"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
$rexglue = "C:\ProgramData\rextools\rexglue.exe"

# 1. sync manifest with dump path
(Get-Content -LiteralPath "$repoRoot\tools\config\ocho_kart_manifest.toml" -Raw) `
    -replace 'REPLACE_WITH_YOUR_DUMP_ROOT', $DumpPath |
    Set-Content -LiteralPath "$ProjectDir\ocho_kart_manifest.toml" -Encoding UTF8
Write-Output "[1/4] manifest synced"

# 2. codegen
$cg = Start-Process -FilePath $rexglue -ArgumentList @('--force','codegen',"$ProjectDir\ocho_kart_manifest.toml") `
    -WorkingDirectory $ProjectDir -RedirectStandardOutput "$ProjectDir\docs\codegen-$Tag.log" `
    -RedirectStandardError "$ProjectDir\docs\codegen-$Tag.log.err" -NoNewWindow -PassThru
while (-not $cg.HasExited) { Start-Sleep -Seconds 15 }
$seal = Get-Content "$ProjectDir\docs\codegen-$Tag.log.err" -ErrorAction SilentlyContinue |
    Select-String -Pattern 'sealed|cannot seal|Total:|Unresolved' | Select-Object -Last 3
Write-Output "[2/4] codegen done"; $seal | ForEach-Object { $_.Line }

# 3. build
$bdir = "$ProjectDir\out\build\win-amd64"
$cmd = "call `"$vcvars`" && cmake --build `"$bdir`" --parallel"
$bp = Start-Process -FilePath "cmd.exe" -ArgumentList @('/c',$cmd) `
    -RedirectStandardOutput "$ProjectDir\docs\build-$Tag.log" `
    -RedirectStandardError "$ProjectDir\docs\build-$Tag.log.err" -NoNewWindow -PassThru
$deadline = (Get-Date).AddMinutes(25)
while (-not $bp.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 30 }
Get-Content "$ProjectDir\docs\build-$Tag.log" | Select-String -Pattern 'FAILED|error:|Linking' | Select-Object -Last 3 | ForEach-Object { $_.Line }
Write-Output "[3/4] build done"

# 4. run
$exe = Join-Path $bdir "ocho_kart.exe"
$blog = "$ProjectDir\docs\boot-$Tag.log"
Remove-Item $blog,"$blog.err","$blog.out" -Force -ErrorAction SilentlyContinue
$rp = Start-Process -FilePath $exe -ArgumentList @("--game_data_root","`"$DumpPath`"","--gpu_plugin","xenos","--log_file","`"$blog`"","--log_level","info") `
    -WorkingDirectory $bdir -RedirectStandardOutput "$blog.out" -RedirectStandardError "$blog.err" -NoNewWindow -PassThru
Start-Sleep -Seconds 90
$alive = -not $rp.HasExited
if ($alive) { Stop-Process -Id $rp.Id -Force -ErrorAction SilentlyContinue }
Write-Output "[4/4] ran; alive after 90s: $alive"
Get-Content -LiteralPath $blog -Tail 6 -ErrorAction SilentlyContinue
