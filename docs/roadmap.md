# Roadmap

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | Repo bootstrap | done | private, MIT, CI hello-world |
| 0.5 | Dump audit | done | `docs/reversing-notes.md` |
| 1 | `default.xex` analysis | done | imports signed; codegen emits C++ |
| 2 | UE3 asset catalog | pending | UModel; notes only, never commit assets |
| 3 | First compile | pending | codegen output exists; need MSVC or CI |
| 4 | Shaders (Xenos → HLSL) | pending | `GlobalShaderCache-Xbox360.bin` is `GSMB` |
| 5 | Kernel shims | pending | drive from `xex-imports-signed.md` |
| 6 | Renderer (D3D12/Vulkan) | pending | |
| 7 | Input / audio / stability | pending | FSB5 → FMOD or XMA path |
| 8 | PC options (res, fps) | optional | Unleashed-style |
| 9 | CI releases (code only) | pending | installer asks for user dump |
| 10 | Contributor docs | pending | |

Rules that do not change per phase: no game assets in git; user supplies their own dump; no affiliation claims.
