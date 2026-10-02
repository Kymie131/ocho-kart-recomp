# Auto-peel: read the last crashed address from the newest boot log, compute a
# safe size (next registered function start), append it to the manifest, then
# run the full codegen+build+boot loop. Repeat N times.
#
# Usage: powershell -File tools/peel.ps1 -Rounds 5

param(
    [int]$Rounds = 5,
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [string]$DumpPath = "C:/Users/israe/OneDrive/Documentos/REPOS/Proyecto_descompilacion/EL CHAVO KART"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = "$repoRoot\tools\config\ocho_kart_manifest.toml"

function Get-RegisteredAddrs {
    $reg = Get-ChildItem -LiteralPath "$ProjectDir\generated" -Filter 'ocho_kart_register.cpp' -ErrorAction SilentlyContinue
    if (-not $reg) { return @() }
    $addrs = Select-String -LiteralPath $reg.FullName -Pattern 'SetFunction\(0x([0-9A-Fa-f]+)' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { [Convert]::ToInt64($_.Groups[1].Value,16) }
    return ($addrs | Sort-Object -Unique)
}

for ($round = 1; $round -le $Rounds; $round++) {
    $tag = "peel-$round"
    Write-Output "=== round $round ==="

    # find the most recent boot log
    $lastBoot = Get-ChildItem -LiteralPath "$ProjectDir\docs" -Filter 'boot-*.log' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $lastBoot) { throw "no boot log found" }
    $fatal = Get-Content -LiteralPath $lastBoot.FullName | Select-String -Pattern 'unregistered function at guest address 0x([0-9A-Fa-f]+)' |
        Select-Object -Last 1
    if (-not $fatal) { Write-Output "no FATAL in $($lastBoot.Name) -> nothing to peel"; break }
    $addr = [Convert]::ToInt64($fatal.Matches[0].Groups[1].Value,16)
    Write-Output ("crashed at 0x{0:X8}" -f $addr)

    # size = next registered function start after addr
    $regs = Get-RegisteredAddrs
    $next = $regs | Where-Object { $_ -gt $addr } | Select-Object -First 1
    if (-not $next) { $next = $addr + 16 }
    $size = $next - $addr
    Write-Output ("next registered 0x{0:X8} -> size {1} (0x{1:X})" -f $next, $size)

    # skip if already present
    if ((Get-Content -LiteralPath $manifest -Raw) -match ("0x{0:X8}\s*=" -f $addr)) {
        Write-Output "already in manifest; stopping to avoid loop"; break
    }

    # append to [entrypoint.functions]
    $entry = ("0x{0:X8} = {{ name = ""sub_{0:X8}_peel"", size = {1} }}" -f $addr, $size)
    Add-Content -LiteralPath $manifest -Value $entry
    Write-Output "appended: $entry"

    # run the full loop (codegen + build + boot)
    & powershell -File "$PSScriptRoot\boot-loop.ps1" -Tag $tag -ProjectDir $ProjectDir -DumpPath $DumpPath | Select-Object -Last 8

    # if the game stayed alive, we booted
    $blog = "$ProjectDir\docs\boot-$tag.log"
    if (Test-Path $blog) {
        $aliveLine = & powershell -File "$PSScriptRoot\boot-loop.ps1" -Tag "$tag-x" -ProjectDir $ProjectDir -DumpPath $DumpPath -ErrorAction SilentlyContinue 2>&1 | Select-String 'alive after'
    }
}
Write-Output "peel done"
