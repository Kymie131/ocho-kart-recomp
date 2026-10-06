# Extract one subsound from an FSB5 bank and (optionally) decode/play it.
#
# The guest mixer is silent, so this reads the user's own cooked bank directly
# and hands it to a host decoder. XMA subsounds are wrapped in an XMA2 WAVE
# (tools/fsb5/fsb5.exe) and decoded with FFmpeg's xma2 decoder.
#
# Examples:
#   powershell -File tools/fsb5/play.ps1 -Bank "C:\dump\...\95D00942.fsbcache" -Index 0 -Play
#   powershell -File tools/fsb5/play.ps1 -Bank bank.fsbcache -Index 1 -Out track01.wav
#   powershell -File tools/fsb5/play.ps1 -Bank bank.fsbcache -List

param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Bank,
    [Parameter(Position = 1)][int]$Index = 0,
    [string]$Out,
    [switch]$Play,
    [switch]$List,
    [string]$FfmpegDir = "C:\ffmpeg\ffmpeg-master-latest-win64-gpl-shared\bin"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Bank)) { throw "bank not found: $Bank" }

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$exe = Join-Path $repoRoot 'tools\out\fsb5.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Output "fsb5.exe missing; building..."
    & (Join-Path $PSScriptRoot 'build.ps1')
}

if ($List) {
    & $exe list $Bank
    return
}

function Resolve-Tool([string]$name) {
    $local = Join-Path $FfmpegDir "$name.exe"
    if (Test-Path -LiteralPath $local) { return $local }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "$name not found (pass -FfmpegDir with the FFmpeg bin folder)"
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("fsb5_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$encoded = Join-Path $work 'sub.wav'

try {
    & $exe extract $Bank $Index $encoded
    if ($LASTEXITCODE -ne 0) { throw "fsb5 extract failed ($LASTEXITCODE)" }

    $ffmpeg = Resolve-Tool 'ffmpeg'
    if ($Out) {
        $pcm = $Out
    } else {
        $pcm = Join-Path $work 'sub.pcm.wav'
    }
    & $ffmpeg -hide_banner -loglevel warning -y -i $encoded -c:a pcm_s16le $pcm
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg decode failed ($LASTEXITCODE)" }
    if ($Out) { Write-Output "decoded $Out" }

    if ($Play) {
        $ffplay = Resolve-Tool 'ffplay'
        & $ffplay -hide_banner -loglevel warning -autoexit -nodisp $pcm
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
