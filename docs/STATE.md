# State

Updated 2026-10-02.

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | not started |
| 3 compile recomp C++ | next — codegen output exists, not built yet |

**Done (Phase 1):** import table signed 307/307 (`docs/toolchain/xex-imports-signed.md`); manifest with `[entrypoint.functions]` (`tools/config/ocho_kart_manifest.toml`); ReXGlue codegen emits C++ outside the repo.

**Not done:** local compile; UE3 package map; kernel shims; anything that runs.

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` (path set at codegen time) |
| Analysis project + generated C++ | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| XexTool-RE build | temp dir (not in git) |
| ReXGlue prebuilt | `C:\ProgramData\rextools\rexglue.exe` v0.10.0 |
| Manifest for codegen | `tools/config/ocho_kart_manifest.toml` |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |

## Blockers

- **Phase 3 compile:** this machine's clang has no MSVC headers. Either install VS Build Tools (MSVC C++ workload) or build only on GitHub Actions. Pick one before wiring CMake to `generated/`.
- **`frag_82FBFCB8_loop`:** does not seal (`beq` → 0x82FBFC9C outside 24 B window). Fix size/parent when touching the manifest again.
- Some codegen Write partitions (~252–265) failed to write in the last run; ~612 files still landed. Re-run Write if Phase 3 needs a complete set.

## Next

1. Decide MSVC local vs CI-only.
2. Point CMake at generated output; compile until first link.
3. In parallel: UModel over the 320 `.xxx` packages (notes only).
