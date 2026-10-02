# ocho-kart-recomp

Static recompilation of **El Chavo Kart** (Xbox 360, UE3) to native PC via [ReXGlue](https://github.com/rexglue/rexglue-sdk). PPC/Xenos -> C++/HLSL at compile time. Not emulation. No game content in this repo — you supply your own legal dump.

Unaffiliated with Microsoft, Xbox, Epic, Efecto Studios, Televisa, or Grupo Chespirito. Educational/preservation use only.

## Layout

```
docs/          notes, roadmap, signed import table
external/      rexglue-sdk submodule
src/           shims, renderer, input (grows per phase)
tools/         xex-imports.ps1, ReXGlue manifests, run-codegen.ps1
scripts/       env setup
tests/
```

## Status

Phase 1 analysis done: `default.xex` import table signed (307 entries), ReXGlue codegen emits C++. Next is compile (Phase 3) and UE3 package catalog (Phase 2). Details in `docs/STATE.md` and `docs/reversing-notes.md`.

## Credits

Xenia, ReXGlue SDK, Unleashed Recompiled, hells-gate-recomp, Free60, XboxDev. See `THIRD_PARTY_NOTICES.md`.
