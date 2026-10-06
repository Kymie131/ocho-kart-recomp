# ocho-kart-recomp

Static recompilation of **El Chavo Kart** (Xbox 360, UE3) to native PC via [ReXGlue](https://github.com/rexglue/rexglue-sdk). PPC/Xenos -> C++/HLSL at compile time. Not emulation. No game content in this repo — you supply your own legal dump.

Unaffiliated with Microsoft, Xbox, Epic, Efecto Studios, Televisa, or Grupo Chespirito. Educational/preservation use only.

## Status

The game boots past the intro with the Xenos GPU plugin and is playable (input
stable; effects that reach the guest XMA path are audible). Two upstream-scale
gaps remain: the title's own UE3/FMOD audio activation never fires (the guest
mixer hands the runtime silence, so menu/race music is silent), and the Bink
cinematics have no in-runtime decoder. A host-side music player covers the
former from the user's own dump.

Build and run steps: `docs/BUILD.md`. Current state and open issues:
`docs/STATE.md`.

## Layout

```
docs/          notes, roadmap, build guide, package catalog, signed import table
external/      rexglue-sdk submodule (carries local shim patches)
src/           launcher + host-side audio (grows per phase)
tools/         codegen/build/run scripts, FSB5 audio tools, UE3 catalog
patches/       SDK patches applied to the vendored submodule
scripts/       env setup, asset-blocking git hook
tests/
```

## Documentation

| File | What |
|---|---|
| `docs/BUILD.md` | Build and run from your own dump |
| `docs/STATE.md` | Current state, measurements, open issues |
| `docs/roadmap.md` | Phase table |
| `docs/reversing-notes.md` | Dump/asset RE findings |
| `docs/ue3-catalog.md` | Package catalog (names/counts only) |
| `docs/audio-restart.md` | Audio work log and facts |

## Credits

Xenia, ReXGlue SDK, Unleashed Recompiled, hells-gate-recomp, Free60, XboxDev. See `THIRD_PARTY_NOTICES.md`.
