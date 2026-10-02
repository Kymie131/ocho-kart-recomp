# Notes

Text and metadata only. No game bytes, no assets. Paths assume the user's own dump; nothing here is uploaded to git.

## Dump (legal, local)

| Path | What | Tool |
|---|---|---|
| `default.xex` 28.61 MB, SHA1 `EB3B307A29F8AD7DBB26431139EA24A62F5ABE61` | XEX2, Title 475807D7 (GX-2007), load 0x82000000, entry 0x830DB568, retail encrypted | ReXGlue, XexTool-RE |
| `ChavoKartGame\CookedXbox360\` — 320 `.xxx`, ~1.4 GB | UE3 cooked packages (Core/Engine/GFxUI/GameFramework/FMODAudio, tracks `CO/EN/CT/PO/TA/SU/RET`, `KartPawn*`) | UModel / UE Explorer |
| `*.tfc` | texture caches | UModel |
| `*.fsbcache` + `FMODAudio.xxx` | FSB5 (FMOD v5) | FMOD tools |
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

## Open

- Phase 3 compile: need MSVC headers locally, or build via GitHub Actions only.
- Phase 2: catalog 320 `.xxx` with UModel — gameplay map, not committed.
- Re-run codegen Write after fixing the frag if a full partition set is required.
