# Roadmap

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | Repo bootstrap | done | private, MIT, CI hello-world |
| 0.5 | Dump audit | done | `docs/reversing-notes.md` |
| 1 | `default.xex` analysis | done | imports signed; sections mapped; setjmp/longjmp and the D3D DPC routine in the manifest |
| 2 | UE3 asset catalog | done | LZX decode; names/imports/exports/classes via `tools/catalog/`; `docs/ue3-catalog.md` (text only) |
| 3 | First compile | done | compiles, links, boots; build via clang + Ninja; patched SDK via `tools/build-sdk.ps1` |
| 4 | Shaders (Xenos → HLSL) | partial | 101 shaders / 87 pipelines translated at runtime (`run-race4.log`) |
| 5 | Kernel shims | done | boots past the intro; peeled pointer/vtable functions; DPC dispatch + cache: mount patched (unmeasured) |
| 6 | Renderer (D3D12/Vulkan) | in progress | Xenos GPU plugin renders the intro |
| 7 | Input / audio / stability | in progress | input OK; guest audio silent: FMOD never opens a bank (host-side music covers it); see `STATE.md` |
| 8 | PC options (res, fps) | partial | launcher exposes fullscreen / vsync / resolution scale |
| 9 | CI releases (code only) | partial | `.github/workflows/release.yml` packages the tooling on tag |
| 10 | Contributor docs | done | `docs/BUILD.md`, `CONTRIBUTING.md`, `docs/STATE.md` |

Rules that do not change per phase: no game assets in git; user supplies their own dump; no affiliation claims.
