# Third-party notices

This project builds on the work of the Xbox 360 preservation and reverse-engineering community. Credits and licenses are listed here and will be updated as exact dependency versions get pinned (see `docs/STATE.md`).

## Reference projects and planned components

| Project | Usage | Reference |
|---|---|---|
| **ReXGlue SDK** | Recompilation runtime base: PPC→C++ and Xenos shader→HLSL | github.com/rexglue/rexglue-sdk (submodule at `external/`) |
| **Xenia** | Kernel/XEX reference and source of the compatibility layer | github.com/xenia-project/xenia |
| **XenonRecomp / XenosRecomp** | Pioneers of static PPC→C++ and shader→HLSL recompilation | rexdex's projects / community repos |
| **DirectXShaderCompiler (DXC)** | HLSL → DXIL/SPIR-V compilation | github.com/microsoft/DirectXShaderCompiler |
| **SDL2 / XInput** | Cross-platform input and audio | github.com/libsdl-org/SDL |
| **Unleashed Recompiled** | Methodological reference (Sonic Unleashed) | github.com/hedge-dev/UnleashedRecomp |
| **hells-gate-recomp** | Methodological reference (Dante's Inferno, UE3) | github.com/hedge-dev/hells-gate-recomp |

## Legal note

- This repository **does not include or distribute any assets** from "El Chavo Kart" or any of the involved brands. The credits above refer strictly to **software/tools** and methodology.
- Each dependency's license will be acknowledged here before it is incorporated into the build. This project's own code is distributed under **MIT**.