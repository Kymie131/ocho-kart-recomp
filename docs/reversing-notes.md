# Notes

Text and metadata only. No game bytes, no assets. Paths assume the user's own dump; nothing here is uploaded to git.

## Dump (legal, local)

| Path | What | Tool |
|---|---|---|
| `default.xex` 28.61 MB, SHA1 `EB3B307A29F8AD7DBB26431139EA24A62F5ABE61` | XEX2, Title 475807D7 (GX-2007), load 0x82000000, entry 0x830DB568, retail encrypted | ReXGlue, XexTool-RE |
| `ChavoKartGame\CookedXbox360\` — 320 `.xxx`, ~1.4 GB | UE3 cooked packages, v860/licensee 0, engine 10246, cooker 136, LZX-compressed (Core/Engine/GFxUI/GameFramework/FMODAudio, tracks `CO/EN/CT/PO/TA/SU/RET`, `KartPawn*`) | UModel / UE Explorer |
| `*.tfc` | texture caches | UModel |
| `*.fsbcache` (15) + `FMODAudio.xxx` | FSB5 sound banks, XMA codec, played by the statically linked FMOD Ex 4.x / FMOD Event | `tools/fsb5/` |
| `Coalesced_*.bin` | UE3 loc | UModel |
| `GlobalShaderCache-Xbox360.bin` | magic `GSMB` — Xenos microcode | Phase 4 |
| `Config\*.ini`, `Movies\*.BIK`, TOC txt | runtime ref / catalog | direct read |
| `AvatarAssetPack`, `nxeart` | PIRS magic, not UE3 | ignore for now |

Dump audit: 399 files, ~1.81 GB. 13 TOC entries missing (splash variants + UE3 editor stats HTML) — no runtime impact. Dump is usable.

## XEX analysis

Retail XEX2 is AES+LZX; import table is not plaintext on disk. Dumped with **XexTool-RE** (built from source, MinGW; not in repo):

```
xextool-re list default.xex
xextool-re idc default.xex default.idc
xextool-re extract default.xex default-base.xex   # outside repo
```

`default.idc` lists every IAT slot + ordinal. Mapped against xbox360-emu retail ordinals (`xboxkrnl.ord` / `xam.ord`, same numbering as Xenia). OpenXDK `.def` is a different (devkit) numbering — do not mix.

**Result: 307/307 signed.** Table: `docs/toolchain/xex-imports-signed.md` + `.csv`.

| Lib | func | data |
|---|---|---|
| xboxkrnl.exe | 176 | 13 |
| xam.xex | 118 | 0 |

IAT lives at 0x82000600–0x82000ACC. Thunk stubs at 0x834DAxxx.

### What the ReXGlue "17 unresolved" actually are

Not kernel imports. Byte dump of the decrypted basefile (base 0x82000000):

| Addr | Pattern | Class |
|---|---|---|
| 0x82FBFBC0 / FC38 / FCE8 / FCF8 / FD08 / FD18 / FD28 | `lwz r11,0(r3); lwz r11,off(r11); mtctr r11; bctr` | vtable thunks (16 B) |
| 0x82FB2774, 0x82FD097C, 0x82FD0A94 | `li r3,0; blr` | ret-0 stubs |
| 0x82FB277C | `lfs`/`stfs; blr` | float-copy stub |
| 0x82FCB148 | `li r3,0x25; blr` | STATUS_NOT_IMPLEMENTED |
| 0x82B90068, 0x82E514C8 | `b <target>` + pad | branch stubs |
| 0x82FBFCB8, 0x82FBFDA8 | loop / stores | mid-function frags |
| 0x82E4D8D8, 0x832C3910, 0x832D9690 | branch / FP load / lwz chain | real .text |

Mid-thunk tails (e.g. 0x82FBFBC8) are not separate functions.

### ReXGlue manifest

v0.10.0 reads `[functions]` **only inside `[entrypoint]`** (`manifest.cpp` → `LoadFromTable(entrypoint)`). Top-level `[functions]` is ignored. Config in `tools/config/ocho_kart_manifest.toml` uses `[entrypoint.functions]` with the 19 named entries above.

Codegen run (debug, `--force`): imports resolve as `__imp__<Name>` (`__imp__NtWriteFile`, …). Output written outside the repo (`%ProgramData%\rextools\proj-ocho-kart\generated\`, ~276 MB). Analyzer completed; `frag_82FBFCB8_loop` still pending seal (beq to 0x82FBFC9C outside its 24 B window).

## Phase 2 — UE3 asset catalog (started 2026-10-03)

Inventory is by package name and size only. No package contents, class bytecode, textures or
models are stored here or anywhere in the repo.

Package organization in `ChavoKartGame\CookedXbox360\` (320 `.xxx`):

| Group | Count | What it is |
|---|---|---|
| `KartPawn<Name>Arch_SF` / `KartPawn<Name>SP0_SF` | 24 | Playable karts. 12 characters, each with an `Arch` variant and an `SP0` variant. |
| `Pista<X>_Arte` / `_Arte_1` | 23 | Track art packages (visuals), some split in two parts. |
| `Pista<X>_Acc` | 20 | Track accessory/decoration packages. |
| `CO-<X>_Circuito*` | 20 | Per-track `CO` packages (circuito). |
| `CT-<X>_Circuito*` | 20 | Per-track `CT` packages. |
| `EN-<X>_Circuito*` | 20 | Per-track `EN` packages. |
| `RET-*` / challenge packages | 37 | Challenges/minigames. |
| `TitleMap`, `StartMenu` | 1 each | Menu/map packages. |
| `ChavoKartGame_LOC_{ESM,ESN,INT,PTB}` | 4 | Localization tables. |
| `ChavoKartEntry`, `ChavoKartGame` | 2 | Title entry and main game package. |
| Other engine/support packages | rest | Core/Engine/GFxUI/GameFramework/FMODAudio and misc. |

The 12 playable characters, from the `KartPawn*` package names:
Chavo, Quico, Cleotilde, Don Ramon, Florinda, Godinez, Nono, Paty, Popis, ProfJirafales, Rufino,
SrBarriga. Each has `Arch` and `SP0` variants (likely a "stat/arch" default and a "SP0" gameplay
variant), suggesting the karts are data-driven per character.

Track naming: `<Prefix>-Pista<Name>_Circuito<N>` and `Pista<Name>_Arte/Acc`, e.g. `PistaElEspacio`,
`PistaCiudad`, `PistaBrasilM`, `PistaBrasilC`, `PistaAcapulco`, `PistaMuseo`, `PistaTanga`,
`PistaLaFeria`. So each track has art, accessories, and up to two circuit variants.

### Package format (resolved 2026-10-06)

The earlier blocker (UE Explorer needed admin; a header parser "did not decode
the name table") came from treating the packages as LZO. They are **LZX**
(UE3 `ECompressionFlags` 0x4, XMemCompress framing: per frame a 2-byte block
size, or `FF` + frame size + block size), decoded with a 128 KiB window:

- 15 packages ship a `.uncompressed_size` sibling and are **compressed whole**
  (Core, Engine, FMODAudio, GameFramework, GFxUI, IpDrv, OnlineSubsystemLive,
  ChavoKartGame, Startup, and the `_LOC_*` ones).
- The rest have a plain summary and a `CompressedChunks` table.
- Name entry = FString + u64 flags; import = 28 bytes; export = 68 bytes
  (+4 per NetObjectCount entry), no ComponentMap; validated against
  `DependsOffset` on every package decoded.

`tools/catalog/ue3_catalog.py` (+ the `ue3lzx` helper) prints names, imports,
exports and export classes. See `docs/ue3-catalog.md`, including the
audio-relevant objects (FMOD project, 15 sound banks, the Kismet music cue).

### Relation to the binary side

Not yet mapped. The runtime work so far is kernel/input/render. The gameplay classes (menu, race
start, power-ups) live in these packages and would be read for reference only; UnrealScript
bytecode is never extracted into the repo.

## Decrypted image (2026-10-06)

Loaded with XenonRecomp's `XenonUtils` (AES + LZX) into a flat image at
`0x82000000` (`0x1DB0000` bytes, entry `0x830DB568`). Sections:

| Section | Address | Note |
|---|---|---|
| `.rdata` | `0x82000600` | IAT at the start |
| `.pdata` | `0x8225B400` | function table (begin + length), used to size functions |
| `BINKCONS`, `BINK`, `BINKDATA`, `BINKBSS`, `RADCODE`, `RADDATA` | `0x822C1A00`… | **Bink is linked into the XEX** and runs as guest code |
| `.text` | `0x822D0000` | `0x120B3F8` bytes |
| `.data` | `0x834F6000` | |
| `.XBMOVIE`, `.XBLD`, `.edata`, `.idata`, `.reloc` | | |

Located by reading the code (addresses are for SHA1 `EB3B307A…`):

| What | Address | How |
|---|---|---|
| `longjmp` | `0x830BDC90` | restores f14–f31 @0, r13–r31 @0x98, v64–v127 @0x140, LR @0x134, r1 @0x90, CR @0x130; far path calls `RtlUnwind` (thunk `0x834DAA14`) |
| `setjmp` | `0x830BDFB0` | mirror store sequence, leaf without `.pdata`; 7 callers |
| D3D DPC routine | `0x82B63818` | `KeInitializeDpc` at `0x82B639BC`, `KeInsertQueueDpc` at `0x82B577A0`; sets the D3D worker's event (worker `sub_82B63670`, 30 ms timeout) |
| FMOD Ex / FMOD Event | strings `0x8204ED10`–`0x82078C2C` | `fmod_output_xenon.cpp`, `fmod_codec_xma.cpp`, `fmod_musicsystemi.cpp`, … |
| UE3 FMODAudio natives | name strings `0x8223B24F`–`0x8223C2F0` | `UFMODLoadingSetexecLoad`, `UFMODMusicSystemexecPromptCue`, … |
| Utility-drive cache paths | `0x820ABDF0`, `0x820AD230` | `cache:\$cache$\dir`, `\??\cache:`, `\Device\Harddisk0\Cache%u` |

## Open

- Audio: the title's FMOD never opens a sound bank under ReXGlue (see `STATE.md`).
- Cinematics: play from the guest's own Bink; `VIDEODEMO.bik` and `*_ESM.bik`
  are not on the disc, nothing else is missing.
