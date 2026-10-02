# xex-imports.ps1 - volcador de la tabla de imports (ordinales) de un default.xex
#
# PARA QUE EXISTE
#   Fase 2/toolchain. La firma de los 17 imp_xboxkrnl_* requiere el ORDINAL real de
#   cada thunk. rexglue no lo emite (codegen de 104 s no escribe ordinales en el
#   manifest, verificado en sesion 2026-09-18). Este script parsea el layout XEX2
#   segun Free60 wiki (XEX_HEADER_IMPORT_LIBRARIES = 0x103FF) para leer ese ordinal.
#
# CONDICION (importante, no es un "bug" del script)
#   Un default.xex RETAIL esta cifrado/compreso con LDIC. La tabla de imports NO
#   es legible como bytes planos hasta descifrar/descomprimir. Por eso este script:
#     - si recibe un XEX ya volcado/descomprimido (xextool -d, devkit, dump de
#       rexglue) -> extrae ordinals de verdad y firma.
#     - si recibe el default.xex retail crudo -> NO encuentra 0x103FF en texto
#       plano, lo DICE y termina. No inventa la firma.
#
# USO
#   powershell -File tools/xex-imports.ps1 -Xex <ruta>
#
# REFERENCIA (verificada en vivo contra Free60 wiki el 2026-09-18)
#   file_header_offset @ 0x10, header_count @ 0x14; cada optional header: 16 B.
#   ID & 0xFF == 0xFF  -> header data = { size u32, offset u32 } (layout wiki).
#   ID 0x103FF         -> XEX_HEADER_IMPORT_LIBRARIES.
#   Registro de import (xenia/xbox360-emu): el thunk vive en un slot 0x82....;
#   el ORDINAL se lee del valor in-memory en ese slot: (val >> 24) = tipo,
#   (val & 0xFFFF) = ordinal.

param(
    [Parameter(Mandatory = $true)][string]$Xex
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

function Read-U32BE([byte[]]$b, [int]$o) {
    return ([uint32]$b[$o] -shl 24) -bor ([uint32]$b[$o + 1] -shl 16) -bor
           ([uint32]$b[$o + 2] -shl 8) -bor ([uint32]$b[$o + 3])
}
function Read-U16BE([byte[]]$b, [int]$o) {
    return ([uint32]$b[$o] -shl 8) -bor ([uint32]$b[$o + 1])
}
function Read-U8([byte[]]$b, [int]$o) { return [int]$b[$o] }

Write-Host "== xex-imports.ps1 =="
Write-Host ("  entrada: {0} ({1} B)" -f $Xex, (Get-Item -LiteralPath $Xex).Length)

$b = [System.IO.File]::ReadAllBytes($Xex)
$magic = '{0}{1}{2}{3}' -f [char]$b[0], [char]$b[1], [char]$b[2], [char]$b[3]
Write-Host ("  magic: '{0}'" -f $magic)

$kern = ($magic -join '') -eq $null  # placeholder, se recalcula abajo
$KERNEL_MAGIC = [string]([char]0x4E) + [char]0x4E + [char]0x1A + [char]0x3D

if ($magic -ne 'XEX2') {
    if ($magic -eq $KERNEL_MAGIC) {
        Write-Host "  ESTO ES CONTENEDOR DE KERNEL (magic 4E4E1A3D): rexglue no lo lee, este parser tampoco."
        Write-Host "  RESULTADO: 17 siguen PENDIENTES. No firmo de oido."
        exit 0
    }
    Write-Host "  NO es XEX2 (magic '$magic'). Nada que firmar desde esta entrada."
    exit 1
}

$hdrOff = Read-U32BE $b 0x10
$hdrCnt = Read-U32BE $b 0x14
Write-Host ("  file-header-offset=0x{0:X}  header-count={1}" -f $hdrOff, $hdrCnt)

$found = $null
for ($s = 0; $s -lt $hdrCnt; $s++) {
    $o = $hdrOff + $s * 16
    if ($o + 16 -gt $b.Length) { break }
    $id = Read-U32BE $b $o
    $size = Read-U32BE $b ($o + 4)
    $off = Read-U32BE $b ($o + 8)
    if ($id -eq 0x103FF) {
        $found = @{ opff = $o; off = $off; size = $size }
        Write-Host ("  >>> XEX_HEADER_IMPORT_LIBRARIES (0x103FF) en 0x{0:X}, {1} B" -f $off, $size)
        break
    }
}
if (-not $found) {
    Write-Host "  NO se encontro 0x103FF en texto plano -> retail cifrado/compreso."
    Write-Host "  RESULTADO honesto: 17 PENDIENTES; falta volcado descifrado (xextool -d)."
    exit 0
}

$p = $found.off
$xsz = $b.Length
$stSize = Read-U32BE $b $p
$stCount = Read-U32BE $b ($p + 4)
$names = @()
$ss = $p + 8
if ($stSize -gt 0 -and $ss -lt $xsz) {
    $limit = [Math]::Min($ss + $stSize, $xsz)
    $i = 0
    while ($ss + $i -lt $limit) {
        $start = $ss + $i
        $e = $start
        while ($e -lt $limit -and $b[$e] -ne 0) { $e++ }
        $len = $e - $start
        if ($len -gt 0 -and $len -lt 260) {
            $names += [System.Text.Encoding]::ASCII.GetString($b[$start..($e - 1)])
        }
        $i = ($e - $ss) + 1
    }
}
Write-Host ("  string-table: {0} cadenas  ->  {1}" -f $names.Count, ($names -join ', '))

$libOff = $ss + $stSize
if ($libOff % 4 -ne 0) { $libOff += 4 - ($libOff % 4) }

$total = 0
$saved = @()
while ($libOff + 4 -le $xsz) {
    if ($libOff -ge ($p + $found.size)) { break }
    $libSize = Read-U32BE $b $libOff
    if ($libSize -eq 0) { break }
    $nameIdx = Read-U32BE $b ($libOff + 4) -band 0xFF
    $verM = Read-U16BE $b ($libOff + 6)   # high = major, low = minor
    $verm = Read-U16BE $b ($libOff + 8)
    $count = Read-U16BE $b ($libOff + 10) # xenia: version, version_min, count
    $libName = if ($nameIdx -lt $names.Count) { $names[$nameIdx] } else { 'lib?' }
    Write-Host ("  lib '{0}' ver={1}.{2} min={3}.{4} imports={5}" -f `
        $libName, ($verM -shr 8), ($verM -band 0xFF), ($verm -shr 8), ($verm -band 0xFF), $count)

    $rec = $libOff + 12
    for ($i = 0; $i -lt $count; $i++) {
        if ($rec + 4 -gt $xsz) { break }
        $slotAddr = Read-U32BE $b $rec
        $imgOff = 0
        if ($slotAddr -ge 0x82000000 -and ($slotAddr - 0x82000000) + 4 -le $xsz) {
            $imgOff = $slotAddr - 0x82000000
            $val = Read-U32BE $b $imgOff
            $typ = ($val -shr 24) -band 0xFF
            $ord = $val -band 0xFFFF
            Write-Host ("    thunk 0x{0:X8}  tipo={1}  ORDINAL={2}  (slot value 0x{3:X8})" -f $slotAddr, $typ, $ord, $val)
            $total++
            $saved += [pscustomobject]@{ Addr = $slotAddr; Ord = $ord }
        } else {
            Write-Host ("    slot 0x{0:X8} no resolubile como imagen plana (cifrado)" -f $slotAddr)
        }
        $rec += 4
    }
    $libOff += $libSize
    if ($libSize -lt 16) { break }
}

Write-Host ("== RESULTADO: {0} imports legibles en texto plano ==" -f $total)
if ($total -gt 0) {
    Write-Host "  Tabla ordinal mas los nombres de la tabla Free60/OpenXDK -> FIRMA lista."
    $json = ($saved | ConvertTo-Json -Compress)
    Write-Host "  saved=$json"
} else {
    Write-Host "  0 imports en texto plano -> sigue PENDIENTE (retail no descifrado). Honesto."
}
