# State

Updated 2026-10-03.

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | not started |
| 3 compile recomp C++ | done |
| 4 shaders | partially working (101 shaders translated, 87 pipelines — `run-race4.log` 2026-10-03 07:59) |
| 5 kernel shims / boot | **done — runs stable past the intro with GPU** |
| 6 renderer | in progress (Xenos GPU plugin renders the intro) |
| 7 input / audio / stability | in progress — input OK, audio silent, race-start crash (see taxonomy) |

## Milestone: stable boot with GPU (2026-10-03)

`ocho_kart.exe` with `--gpu_plugin xenos` and the dump wired:

- D3D12 device on the RTX 4050, shader storage initialized.
- Plays the whole intro asset sequence in real time: disclaimer, UE3/Slang/Televisa/Efecto logos, INTRO cinematic.
- Runs **>3 minutes with no fatal** (was crashing mid-init before).

The window stays open after the intro. There is no movie decoder for the Bink/`.xxx` cinematics and the splash/movie paths (`D:\ChavoKartGame\Movies\*`) still do not resolve in the VFS, so the post-cinematic state is likely blank — needs the asset path mapping.

## How it was stabilised

Repeated `Call to invalid or unregistered function` came from functions codegen cannot discover (reached only via pointers/vtables, never a `bl`). `tools/peel.ps1` runs codegen+build+boot, reads each crash address from the boot log, sizes it (next registered start), appends to `[entrypoint.functions]`, and repeats. **28** function entries are peeled so far (counted in `tools/config/ocho_kart_manifest.toml`, 2026-10-03). Builds are done by `tools/boot-loop.ps1` (codegen + clang/Ninja + run, 90s window).

A bulk scan approach (`gen-ptr-funcs.ps1`) was tried and reverted: false positives broke hundreds of branches. The directed peel is the working method.

## Crash taxonomy (2026-10-03, from WER event log + boot logs)

Three distinct failures, previously conflated. `REX_FATAL` logs then calls `std::abort()`
(`external/rexglue-sdk/include/rex/logging/assert.h:24`), so the abort surfaces as a separate
Windows code:

| Code | Module | Cause | Frequency |
|---|---|---|---|
| `0xC0000409` (BEX64, P9=7) | ucrtbase.dll+0xA527E | `std::abort()` from the `Call to invalid or unregistered function` trap (`external/rexglue-sdk/src/system/function_dispatcher.cpp:38`). **Not** stack corruption. | every run that hits an unregistered target (deterministic) |
| `0xC0000374` | ntdll.dll | genuine host heap corruption; log stops with no FATAL (`run-race2.log`, 07:45:27) | once so far |
| `0xC0000005` | rexgpu-xenosrd.dll+0x1D281 | access violation inside the Xenos GPU plugin (`run-race3.log`, 07:58:28) | once so far |

The abort offset `ucrtbase+0xA527E` is identical across all `0xC0000409` events, pinpointing the abort path.
Latest unpeeled target: `0x833E8B00` (run-race4, 07:59); note `0x833E8B08` is already in the manifest.

## Next

1. Peel `0x833E8B00` (continue `tools/peel.ps1`) — the race-start blocker is a missing function, not memory corruption.
2. Investigate the genuine `0xC0000374` (run-race2) separately: page heap / ASan, only after the peeling noise is gone.
3. Investigate the `0xC0000005` in the GPU plugin (run-race3) separately.
4. Map the movie/splash asset paths so the cinematics and post-intro screens load.
5. Phase 2 (UModel catalog) in parallel.

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` |
| Analysis project + generated C++ + build | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| Prebuilt SDK | `C:\ProgramData\rexglue-sdk-bin` (v0.10.0) |
| ReXGlue analyzer | `C:\ProgramData\rextools\rexglue.exe` v0.10.0 |
| Manifest | `tools/config/ocho_kart_manifest.toml` |
| Build | `tools/build.ps1` |
| Codegen+build+run | `tools/boot-loop.ps1` |
| Crash peeler | `tools/peel.ps1` |
| Launch for viewing | `tools/run-game.ps1` |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |
