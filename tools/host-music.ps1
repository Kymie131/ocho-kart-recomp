# Populate <dump>/host_music with decoded tracks for the host-side music player.
#
# The title's guest XAudio/XMA mixer hands the runtime silence (the UE3 voice
# list is never populated upstream), so the game has no background music. This
# script reads the user's own cooked FSB5 banks and writes ready-to-play WAVs
# (menu.wav / race.wav) that the runtime's host player loops. No game content is
# written into the repo; everything lands under the user's dump.
#
# Requires FFmpeg (the System FFmpeg on PATH, or -FfmpegDir). The fsb5 tool comes
# from this repo and wraps XMA subsounds in an XMA2 WAVE that FFmpeg decodes.
#
# Usage:
#   powershell -File tools/host-music.ps1
#   powershell -File tools/host-music.ps1 -DumpPath "D:/Games/EL CHAVO KART"
#   powershell -File tools/host-music.ps1 -All       # also dump every music subsound
#
# Then launch with `--host_music true` (the pre-boot launcher has a Music toggle).

param(
    [string]$DumpPath = "C:/Users/israe/OneDrive/Documentos/REPOS/Proyecto_descompilacion/EL CHAVO KART",
    [string]$OutDir = "",
    [string]$FfmpegDir = "",
    [switch]$All,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$cooked = Join-Path $DumpPath 'ChavoKartGame\CookedXbox360'
if (-not (Test-Path -LiteralPath $cooked)) { throw "cooked folder not found: $cooked (pass -DumpPath)" }
if (-not $OutDir) { $OutDir = Join-Path $DumpPath 'host_music' }

$fsb5 = Join-Path $repoRoot 'tools\out\fsb5.exe'
if (-not (Test-Path -LiteralPath $fsb5)) {
    Write-Output "fsb5.exe missing; building..."
    & (Join-Path $repoRoot 'tools\fsb5\build.ps1')
}

function Resolve-Ffmpeg([string]$name) {
    if ($FfmpegDir) {
        $local = Join-Path $FfmpegDir "$name.exe"
        if (Test-Path -LiteralPath $local) { return $local }
    }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$ffmpeg = Resolve-Ffmpeg 'ffmpeg'
if (-not $ffmpeg) {
    throw "ffmpeg not found on PATH (pass -FfmpegDir with the FFmpeg bin folder)"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Index every bank once: name -> (bank path, subsound index).
$index = @{}
$banks = Get-ChildItem -LiteralPath $cooked -Filter '*.fsbcache' -File
foreach ($bank in $banks) {
    $lines = & $fsb5 list $bank.FullName 2>$null
    foreach ($line in $lines) {
        # Format: "  #N    ch=2 rate=48000 samples=... [loop] \"name\""
        if ($line -match '^\s*#(\d+)\b.*"([^"]+)"\s*$') {
            $idx = [int]$Matches[1]
            $name = $Matches[2]
            if (-not $index.ContainsKey($name)) {
                $index[$name] = [pscustomobject]@{ Bank = $bank.FullName; Index = $idx; Name = $name }
            }
        }
    }
}

if ($index.Count -eq 0) { throw "no named subsounds found under $cooked" }

function Pick-Track([string[]]$Candidates, [string]$KindRegex) {
    foreach ($c in $Candidates) {
        if ($index.ContainsKey($c)) { return $index[$c] }
    }
    # Fall back to the longest subsound whose name matches the kind.
    $best = $null
    foreach ($kv in $index.GetEnumerator()) {
        if ($kv.Key -match $KindRegex) {
            if (-not $best) { $best = $kv.Value }
        }
    }
    return $best
}

$menu = Pick-Track @('Main_full_02', 'Main_full_01') '^Main_'
$race = Pick-Track @('Acapulco_final_02', 'Museo_full_02', 'Feria_full_03') '(_full_|_final_)'

function Decode-Track($track, [string]$outFile) {
    if (-not $track) { Write-Output "  no track found for $outFile"; return }
    if ((Test-Path -LiteralPath $outFile) -and -not $Force) {
        Write-Output "  exists: $outFile (use -Force to redo)"; return
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ocho_" + [guid]::NewGuid().ToString('N') + '.wav')
    try {
        & $fsb5 extract $track.Bank $track.Index $tmp | Out-Null
        & $ffmpeg -hide_banner -loglevel error -y -i $tmp -c:a pcm_s16le $outFile
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg decode failed for $($track.Name)" }
        Write-Output "  $($track.Name) -> $outFile"
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "host music -> $OutDir"
Decode-Track $menu (Join-Path $OutDir 'menu.wav')
Decode-Track $race (Join-Path $OutDir 'race.wav')

if ($All) {
    $tracks = Join-Path $OutDir 'tracks'
    New-Item -ItemType Directory -Force -Path $tracks | Out-Null
    foreach ($kv in $index.GetEnumerator()) {
        $safe = ($kv.Key -replace '[^A-Za-z0-9_.-]', '_')
        $out = Join-Path $tracks ($safe + '.wav')
        if ((Test-Path -LiteralPath $out) -and -not $Force) { continue }
        Decode-Track $kv.Value $out
    }
}

Write-Output "done. Launch with --host_music true (or tick Music in the launcher)."
