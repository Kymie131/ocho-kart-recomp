# Launch the recompiled game so you can watch it run.
# The Xenos GPU plugin is required for a picture; without it the window is black.
#
# Usage:
#   powershell -File tools/run-game.ps1
#   powershell -File tools/run-game.ps1 -DumpPath "D:/Games/EL CHAVO KART"

param(
    [string]$DumpPath = "C:/Users/israe/OneDrive/Documentos/REPOS/Proyecto_descompilacion/EL CHAVO KART",
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart"
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "not built yet: $exe" }
if (-not (Test-Path -LiteralPath (Join-Path $DumpPath 'default.xex'))) { throw "default.xex not found under: $DumpPath" }

$log = Join-Path $ProjectDir 'docs\run-live.log'
Write-Output "launching (GPU plugin xenos). Log: $log"
Write-Output "Close the game window to stop."

& $exe --game_data_root $DumpPath --gpu_plugin xenos --log_file $log
