# Roadmap

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | Repo bootstrap | done | private, MIT, CI hello-world |
| 0.5 | Dump audit | done | `docs/reversing-notes.md` |
| 1 | `default.xex` analysis | done | imports signed; codegen emits C++ |
| 2 | UE3 asset catalog | pending | UModel; notes only, never commit assets |
| 3 | First compile | done | compiles, links, boots; build via clang 23 + Ninja |
| 4 | Shaders (Xenos → HLSL) | partial | 101 shaders / 87 pipelines translated at runtime (`run-race4.log`) |
| 5 | Kernel shims | done | boots past the intro; 28 peeled pointer/vtable functions |
| 6 | Renderer (D3D12/Vulkan) | in progress | Xenos GPU plugin renders the intro |
| 7 | Input / audio / stability | in progress | input OK; audio silent; race-start crash (see `STATE.md` taxonomy) |
| 8 | PC options (res, fps) | optional | Unleashed-style |
| 9 | CI releases (code only) | pending | installer asks for user dump |
| 10 | Contributor docs | pending | |

Rules that do not change per phase: no game assets in git; user supplies their own dump; no affiliation claims.
