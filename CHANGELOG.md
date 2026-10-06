# Changelog

## Unreleased

- SDK: `KeInsertQueueDpc` now runs DPC routines (`kernel_dispatch_dpcs`); the
  title's D3D DPC routine `0x82B63818` is registered in the manifest.
- SDK: writable `cache:`/`cache0:`/`cache1:` (`mount_cache`);
  `ObCreateSymbolicLink` keeps existing links.
- Codegen: `setjmp`/`longjmp` redirected (`0x830BDFB0` / `0x830BDC90`).
- Catalog: packages are LZX (not LZO); `tools/catalog/ue3lzx.c` helper and a
  rewritten `ue3_catalog.py` decode names, imports, exports and classes.
- Audio diagnosis: the title's audio is FMOD Ex + FMOD Event/Music; menu music
  is an FMOD music cue started by Kismet in `TitleMap`.
- Tooling: `tools/apply-sdk-patches.ps1`, `tools/build-sdk.ps1`.
- Docs: `STATE.md` rewritten as current state with a corrections table; old log
  archived in `docs/history/`; `docs/prior-art.md` (all other Xbox 360 ports).

- Boots past the intro with the Xenos GPU plugin; playable with stable input.
- Launcher: language, controller icons, video options and a host-music toggle.
- Host-side music: `tools/host-music.ps1` extracts the dump's own FSB music to
  `menu.wav`/`race.wav`; the runtime player loops it (opt-in / auto when present).
- FSB5 tool: dependency-free reader/decoder wrapper (`tools/fsb5/`).
- Phase 2 catalog: `tools/catalog/ue3_catalog.py` + `docs/ue3-catalog.md`
  (320 packages; versions, table counts, symbol counts; text only).
- CI: release workflow packaging a code-only tooling bundle on tag.
- Dump audited (Phase 0.5); inventory in `docs/reversing-notes.md`.
- `default.xex` analyzed with ReXGlue v0.10.0; import table signed 307/307 (`docs/toolchain/xex-imports-signed.md`).
- Codegen emits C++ for the title (output kept outside the repo until Phase 3).
