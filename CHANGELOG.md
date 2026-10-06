# Changelog

## Unreleased

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
