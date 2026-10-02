# Directed peel: read the last crashed address from the newest boot log, size it
# (next registered function start), append it to the manifest, then run the full
# codegen+build+boot loop. Repeat. This only adds addresses the runtime actually
# called -> no false positives (unlike a data-section pointer scan).
#
# Usage: powershell -File tools/peel.ps1 [-Rounds 10]

param(
    [int]$Rounds = 10,
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
        ForEach-Object { $_.Matches } | ForEach-Object { [Convert]::ToUInt32($_.Groups[1].Value, 16) }
    return ($addrs | Sort-Object -Unique)
}

for ($round = 1; $round -le $Rounds; $round++) {
    Write-Output "=== peel round $round/$Rounds ==="

    $lastBoot = Get-ChildItem -LiteralPath "$ProjectDir\docs" -Filter 'boot-*.log' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $lastBoot) { throw "no boot log found" }

    $fatal = Get-Content -LiteralPath $lastBoot.FullName |
        Select-String -Pattern 'unregistered function at guest address 0x([0-9A-Fa-f]+)' | Select-Object -Last 1
    if (-not $fatal) {
        Write-Output "no 'unregistered function' in $($lastBoot.Name) -> not a peel crash; stopping"
        break
    }
    $addr = [Convert]::ToUInt32($fatal.Matches[0].Groups[1].Value, 16)

    if ((Get-Content -LiteralPath $manifest -Raw) -match ("0x{0:X8}\s*=" -f $addr)) {
        Write-Output ("0x{0:X8} already in manifest -> stopping to avoid loop" -f $addr); break
    }

    $regs = Get-RegisteredAddrs
    $next = $regs | Where-Object { $_ -gt $addr } | Select-Object -First 1
    if (-not $next) { $next = $addr + 16 }
    $size = [int]($next - $addr)
    if ($size -le 0 -or $size -gt 8192) { $size = 16 }

    $entry = ("0x{0:X8} = {{ name = ""sub_{0:X8}_peel"", size = {1} }}" -f $addr, $size)
    Add-Content -LiteralPath $manifest -Value $entry
    Write-Output ("crashed 0x{0:X8}; next reg 0x{1:X8}; appended: {2}" -f $addr, $next, $entry)

    & powershell -File "$PSScriptRoot\boot-loop.ps1" -Tag ("peel{0:D2}" -f $round) `
        -ProjectDir $ProjectDir -DumpPath $DumpPath | Select-Object -Last 7
}
Write-Output "peel run complete"
