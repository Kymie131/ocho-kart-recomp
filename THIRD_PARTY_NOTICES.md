# Third-party notices

This project builds on the work of the Xbox 360 preservation and reverse-engineering community. Credits and licenses are listed here and will be updated as exact dependency versions get pinned (see `docs/STATE.md`).

## Reference projects and planned components

| Project | Usage | Reference |
|---|---|---|
| **ReXGlue SDK** | Recompilation runtime base: PPC→C++ and Xenos shader→HLSL | github.com/rexglue/rexglue-sdk (submodule at `external/`) |
| **Xenia / Xenia Canary** | Kernel/XEX reference; the DPC dispatch and cache-mount patches follow Canary's behaviour (BSD-3-Clause) | github.com/xenia-project/xenia, github.com/xenia-canary/xenia-canary |
| **XenonRecomp / XenosRecomp** | Pioneers of static PPC→C++ and shader→HLSL recompilation; `XenonUtils` used offline to decrypt the XEX for analysis | github.com/hedge-dev/XenonRecomp, github.com/hedge-dev/XenosRecomp |
| **DirectXShaderCompiler (DXC)** | HLSL → DXIL/SPIR-V compilation | github.com/microsoft/DirectXShaderCompiler |
| **SDL3** | Input, audio, windowing (via the SDK) | github.com/libsdl-org/SDL |
| **libmspack** (LGPL-2.1) | `lzxd.c` from the SDK submodule is compiled into the optional `tools/out/ue3lzx` helper at build time; not vendored in this repo, not shipped in releases | github.com/kyz/libmspack |
| **FFmpeg** (LGPL/GPL, external) | Optional, user-installed; decodes the dump's XMA for host music | ffmpeg.org |
| **Unleashed Recompiled** | Methodological reference (Sonic Unleashed) | github.com/hedge-dev/UnleashedRecomp |
| **hells-gate-recomp** | Methodological reference (Dante's Inferno, ReXGlue) | github.com/florinp93/hells-gate-recomp |
| **Other ports** | Methodological references (see `docs/prior-art.md`), e.g. Gears of War: Judgment, Silent Hill: Downpour, CrownParkComputing's ReXGlue fork | — |

## Legal note

- This repository **does not include or distribute any assets** from "El Chavo Kart" or any of the involved brands. The credits above refer strictly to **software/tools** and methodology.
- Each dependency's license will be acknowledged here before it is incorporated into the build. This project's own code is distributed under **MIT**.