# Launch the recompiled game so you can watch it run.
# The Xenos GPU plugin is required for a picture; without it the window is black.
#
# On a 360 the console picks the language, not the game. The title reads
# XCONFIG_USER_LANGUAGE through ExGetXConfigSetting and loads its Coalesced/LOC
# set for that value. The runtime exposes it as the user_language cvar; this
# launcher defaults to Spanish (Mexico) because the title ships ESM content.
#
# XLanguage values: 1 English, 5 Spanish, 9 Portuguese, etc.
#
# Usage:
#   powershell -File tools/run-game.ps1
#   powershell -File tools/run-game.ps1 -DumpPath "D:/Games/EL CHAVO KART"
#   powershell -File tools/run-game.ps1 -Language 1
#   powershell -File tools/run-game.ps1 -LogLevel info
#
# Log level defaults to debug so D3D12 pipeline creation (the source of the
# brief black flicker when a challenge first uses a new shader pair) is logged.

param(
    [string]$DumpPath = "C:/Users/israe/OneDrive/Documentos/REPOS/Proyecto_descompilacion/EL CHAVO KART",
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [int]$Language = 5,
    [ValidateSet('info','debug','trace')][string]$LogLevel = 'debug'
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "not built yet: $exe" }
if (-not (Test-Path -LiteralPath (Join-Path $DumpPath 'default.xex'))) { throw "default.xex not found under: $DumpPath" }

$log = Join-Path $ProjectDir 'docs\run-live.log'
Write-Output "launching (GPU plugin xenos, user_language $Language, log $LogLevel). Log: $log"
Write-Output "Close the game window to stop."

& $exe --game_data_root $DumpPath --gpu_plugin xenos --user_language $Language --log_level $LogLevel --log_file $log
