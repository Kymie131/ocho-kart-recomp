# Generate manifest entries for pointer-reachable code addresses that codegen
# did not register. Scans non-executable sections for dwords pointing into .text.
#
# Usage: powershell -File tools/gen-ptr-funcs.ps1 [-Append]

param(
    [switch]$Append,
    [string]$BaseFile = "$env:TEMP\opencode\xex-work\default-base.xex",
    [string]$RegisterCpp = "$env:ProgramData\rextools\proj-ocho-kart\generated\ocho_kart_register.cpp",
    [string]$Manifest = "$(Split-Path -Parent $PSScriptRoot)\tools\config\ocho_kart_manifest.toml"
)

$ErrorActionPreference = 'Stop'

function Read-U32BE([byte[]]$b, [int]$o) {
    return ([uint32]$b[$o] -shl 24) -bor ([uint32]$b[$o+1] -shl 16) -bor ([uint32]$b[$o+2] -shl 8) -bor [uint32]$b[$o+3]
}

# registered function starts
$regList = New-Object System.Collections.Generic.List[uint32]
Select-String -LiteralPath $RegisterCpp -Pattern 'SetFunction\(0x([0-9A-Fa-f]+)' -AllMatches |
    ForEach-Object { $_.Matches } |
    ForEach-Object { $regList.Add([Convert]::ToUInt32($_.Groups[1].Value, 16)) }
$regArr = $regList | Sort-Object -Unique
$regset = New-Object 'System.Collections.Generic.HashSet[uint32]'
$regArr | ForEach-Object { [void]$regset.Add($_) }

$codeLo = [Convert]::ToUInt32('822D0000', 16)
$codeHi = [Convert]::ToUInt32('834EF4F4', 16)
$bytes = [System.IO.File]::ReadAllBytes($BaseFile)

$dataRanges = @(
    @(0x82000600, 0x8225B3FC),
    @(0x834F6000, 0x83D2C7E0),
    @(0x83D2CA00, 0x83D2F570)
)

$cand = New-Object 'System.Collections.Generic.HashSet[uint32]'
foreach ($r in $dataRanges) {
    $lo = $r[0] - 0x82000000
    $hi = $r[1] - 0x82000000
    for ($o = $lo; $o -lt ($hi - 4); $o += 4) {
        $v = ([uint32]$bytes[$o] -shl 24) -bor ([uint32]$bytes[$o+1] -shl 16) -bor ([uint32]$bytes[$o+2] -shl 8) -bor [uint32]$bytes[$o+3]
        if ($v -ge $codeLo -and $v -lt $codeHi -and (($v -band 3) -eq 0) -and (-not $regset.Contains($v))) {
            [void]$cand.Add($v)
        }
    }
}

# binary search for next registered start
# combine candidates + registered so a candidate's end is the nearest known start
# (avoids overlapping CONFIG boundaries between adjacent candidates)
$combined = New-Object System.Collections.Generic.List[uint32]
foreach ($x in $regArr) { $combined.Add($x) }
foreach ($x in $cand) { $combined.Add($x) }
$combinedArr = $combined | Sort-Object -Unique

function Next-Reg([uint32]$a) {
    $lo = 0; $hi = $combinedArr.Count - 1; $ans = $null
    while ($lo -le $hi) {
        $mid = [int](($lo + $hi) / 2)
        if ($combinedArr[$mid] -gt $a) { $ans = $combinedArr[$mid]; $hi = $mid - 1 } else { $lo = $mid + 1 }
    }
    return $ans
}

$entries = New-Object System.Collections.Generic.List[string]
foreach ($a in ($cand | Sort-Object)) {
    $next = Next-Reg $a
    if ($null -eq $next) { continue }
    $size = [int]($next - $a)
    if ($size -le 0 -or $size -gt 4096) { $size = 16 }
    $entries.Add(("0x{0:X8} = {{ name = ""ptr_{0:X8}"", size = {1} }}" -f $a, $size))
}

Write-Output ("candidates: {0}" -f $entries.Count)

if ($Append) {
    $block = "`n# Bulk: pointer-reachable code addresses found in .rdata/.data that codegen did`n# not register (vtable slots, thunks, veneers). size = next registered function.`n" + ($entries -join "`n")
    Add-Content -LiteralPath $Manifest -Value $block -Encoding UTF8
    Write-Output "appended to $Manifest"
} else {
    $entries | Select-Object -First 20 | ForEach-Object { Write-Output $_ }
}
