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
#   powershell -File tools/run-game.ps1 -DumpPath "..." -Trace   # DPC + file-open + XMA traces
#   powershell -File tools/run-game.ps1 -DumpPath "..." -ExtraArgs '--mount_cache','false' 
#
# Log level defaults to debug so D3D12 pipeline creation (the source of the
# brief black flicker when a challenge first uses a new shader pair) is logged.

param(
    [Parameter(Mandatory = $true)][string]$DumpPath,
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [int]$Language = 5,
    [ValidateSet('info','debug','trace')][string]$LogLevel = 'debug',
    # The game's own FMOD audio works since the manifest fix for 0x82FBFC38;
    # the host-side WAV player is now opt-in (it would double the music).
    [switch]$HostMusic,
    [switch]$NoMusic,   # kept for old command lines; host music is off by default
    # Diagnostics for the audio investigation (docs/STATE.md, "Next").
    [switch]$Trace,
    [string[]]$ExtraArgs = @(),
    [string]$LogFile = '',
    # Where rexgpu-xenos.dll comes from if it is not next to the exe yet.
    [string]$SdkDir = "$env:ProgramData\rexglue-sdk-ocho"
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "not built yet: $exe" }
$plugin = Join-Path (Split-Path -Parent $exe) 'rexgpu-xenos.dll'
if (-not (Test-Path -LiteralPath $plugin)) {
    $src = Join-Path $SdkDir 'bin\rexgpu-xenos.dll'
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination $plugin
        Write-Output "staged GPU plugin: $plugin"
    } else {
        throw "rexgpu-xenos.dll is missing next to the exe and not found in $SdkDir\bin"
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $DumpPath 'default.xex'))) { throw "default.xex not found under: $DumpPath" }

# Optional host-side music (-HostMusic): make sure the tracks exist so the
# runtime can play them. Skipped when FFmpeg is unavailable.
$hostMusic = Join-Path $DumpPath 'host_music'
$extra = @()
if ($HostMusic -and -not $NoMusic) {
    if (-not (Test-Path -LiteralPath (Join-Path $hostMusic 'menu.wav'))) {
        $ff = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($ff) {
            Write-Output "extracting host music (menu.wav/race.wav)..."
            & (Join-Path $PSScriptRoot 'host-music.ps1') -DumpPath $DumpPath
        } else {
            Write-Output "ffmpeg not found; skipping host music (run tools/host-music.ps1 later)"
        }
    }
    if (Test-Path -LiteralPath (Join-Path $hostMusic 'menu.wav')) {
        $extra += '--host_music', 'true'
    }
}
if ($Trace) {
    $extra += '--kernel_trace_dpcs=true', '--trace_file_opens=true', '--xma_trace_writes=true', '--fmod_diag=true'
}
$extra += $ExtraArgs

$log = if ($LogFile) { $LogFile } else { Join-Path $ProjectDir 'docs\run-live.log' }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $log) | Out-Null
Write-Output "launching (GPU plugin xenos, user_language $Language, log $LogLevel). Log: $log"
Write-Output "Close the game window to stop."

# ocho_kart.exe is a GUI (WIN32) program: invoked with & PowerShell returns at
# once instead of waiting, so anything after this line would run while the game
# is still starting. Start-Process -Wait blocks until the window is closed.
$argv = @('--game_data_root', $DumpPath, '--gpu_plugin', 'xenos', '--user_language', "$Language",
          '--log_level', $LogLevel, '--log_file', $log) + $extra
$quoted = $argv | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }
$proc = Start-Process -FilePath $exe -ArgumentList ($quoted -join ' ') `
    -WorkingDirectory (Split-Path -Parent $exe) -Wait -PassThru
Write-Output ("game exited with code {0}" -f $proc.ExitCode)
