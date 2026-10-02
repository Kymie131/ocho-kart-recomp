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
| 5 kernel shims (boot to menu) | next |

## Phase 3 result (2026-10-02)

Codegen sealed 73228/73228 functions (0 unresolved). Built with clang 23.1.1 + Ninja against the prebuilt ReXGlue SDK 0.10.0:

- 302 recomp .cpp + init + register compile clean, 0 errors.
- Linked `ocho_kart.exe` (110 MB) at
  `%ProgramData%\rextools\proj-ocho-kart\out\build\win-amd64\ocho_kart.exe`.
- Binary starts, loads the runtime, and runs (windowed app, no immediate crash).

One scaffold fix was needed: `src/main.cpp` included `generated/default/ocho_kart_init.h`; the generated header is `generated/ocho_kart_init.h`.

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` (path set at codegen time) |
| Analysis project + generated C++ + build | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| Prebuilt SDK (link target) | `C:\ProgramData\rexglue-sdk-bin` (v0.10.0) |
| ReXGlue analyzer | `C:\ProgramData\rextools\rexglue.exe` v0.10.0 |
| Codegen manifest | `tools/config/ocho_kart_manifest.toml` |
| Build script | `tools/build.ps1` |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |
| Build log | `%ProgramData%\rextools\proj-ocho-kart\docs\build-run-002.log` |

## Blockers

- None for building. The binary runs but has no game data path wired yet, so it does not reach gameplay.
- Local build needs VS Build Tools (MSVC headers) for clang; already installed on this machine. GitHub Actions path still TBD.

## Next

1. Phase 5: run with the dump wired in (`game://`), implement the kernel shims the boot path hits, chase the first real crash, aim for the main menu. Source of truth for shims: `docs/toolchain/xex-imports-signed.md`.
2. In parallel: UModel over the 320 `.xxx` packages (Phase 2, notes only).
