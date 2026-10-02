# State

Updated 2026-10-02.

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | not started |
| 3 compile recomp C++ | **done** — compiles, links, starts |
| 4 shaders | not started |
| 5 kernel shims / boot | **in progress** — boots deep into init, class-B functions bulk-added |

## Phase 3 result

Codegen sealed all functions. Built with clang 23.1.1 + Ninja against prebuilt ReXGlue SDK 0.10.0. Linked `ocho_kart.exe` (110 MB). Fix: `src/main.cpp` include path (`generated/ocho_kart_init.h`).

## Phase 5 result (this session)

Runtime boots, mounts the dump at `game:`, loads the XEX, registers ~73500 functions, resolves all 307 signed imports, and runs the game's startup (filesystem probes, movie list `VIDEODEMO.bik` / `LOGO_*.xxx` / `INTRO.xxx`).

### Root cause of the "unregistered function" crashes — resolved in bulk

The crashes were functions **not discovered by codegen** because they are only reachable through function pointers / vtables (never via a `bl`). Two sub-classes:

- **A (in PDATA)**: PDATA has 52365 function starts in the code range; after the fix all are registered.
- **B (not in PDATA)**: vtable slots, adjustor thunks, veneers, leaf getters. Found by scanning `.rdata`/`.data` for dwords pointing into `.text` at unregistered, 4-aligned addresses → **479 candidates**.

`tools/gen-ptr-funcs.ps1` generates `[entrypoint.functions]` entries for those 479 (size = next known start in the combined set, to avoid overlaps). Adding them advanced the boot past the previous crashes.

### Known issue with the bulk entries

Some of the 479 candidates are **false positives** (data that looks like a code pointer). Declaring them creates a few wrong function boundaries, which show up as codegen `Unresolved branch` warnings and runtime `Unresolved branch from X to Y`. Observed:

- codegen: `Unresolved function 0x83238D88 from 0x83238EB8`
- codegen: `Unresolved conditional branch to 0x83240964 from 0x83240BD8`
- runtime: `[FATAL] Unresolved branch from 0x830DEE1C to 0x830DEED4`

The three targets (0x830DEED4, 0x83238D88, 0x83240964) are `0x00000000` padding → not real functions. So the fix is to **prune false-positive candidates** or give those enclosing functions correct sizes, not to add the targets.

### Tools

- `tools/boot-loop.ps1` — manifest sync + codegen + build + run.
- `tools/gen-ptr-funcs.ps1` — scan data sections for pointer targets, append manifest entries (`-Append`).
- `tools/peel.ps1` — auto-peel single crash (has a double-run bug; superseded by the bulk approach).

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` |
| Analysis project + generated C++ + build | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| Prebuilt SDK | `C:\ProgramData\rexglue-sdk-bin` (v0.10.0) |
| ReXGlue analyzer | `C:\ProgramData\rextools\rexglue.exe` v0.10.0 |
| Manifest | `tools/config/ocho_kart_manifest.toml` |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |

## Next

1. Prune false-positive `ptr_*` entries in the manifest (or correct the few bad sizes) so codegen reports 0 unresolved branches.
2. Re-run `boot-loop`; iterate until the menu.
3. If bulk pruning is painful: revert the 479 block and instead drive discovery from actual unresolved `bl`/`b` targets only.
