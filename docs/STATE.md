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
| `0xC0000005` | rexruntimerd.dll+0x1211D1 | `std::_Destroy_range<std::allocator<rex::input::DeviceInfo>>` freeing a `DeviceInfo` whose `guid` string has a bad pointer — input subsystem (`run-long2.log`, 2026-10-03 09:24:47, ~71s in) | frontier after 5 peels |

The abort offset `ucrtbase+0xA527E` is identical across all `0xC0000409` events, pinpointing the abort path.
2026-10-03: 5 peels added (`0x833E8B00` 8, `0x8249B218` 16, `0x82C1A430` 24, `0x824A8810` 28, `0x826C84C0` 40); manifest 28→33 `_peel` entries. The long debug run then survived ~71s (vs 36-74s before) and hit the `rexruntimerd.dll+0x1211D1` AV above.

Full stack for that AV (cdb `kv` on `CrashDumps\ocho_kart.exe.4996.dmp`; no `rexruntimerd.pdb`, but the DLL's own symbols resolve):

```
ThreadStartRoutine -> XHostThread::Execute -> XThread::Execute
 -> ocho_kart!sub_830E9C98 -> sub_8235CB60 -> sub_829F5BD0   (guest)
 -> rexruntimerd!_imp__XamInputGetState -> XamInputGetState_entry
 -> rex::input::InputSystem::GetState+0x109
 -> rex::input::InputSystem::RefreshDevices+0x641
 -> std::_Destroy_range<std::allocator<rex::input::DeviceInfo>>+0x61   (AV: rcx = 0)
```

`GetState`, `SetState`, `GetCapabilities` and `GetKeystroke` each call `RefreshDevices()`
(`src/input/input_system.cpp:194,221,260,302`), which mutates the shared
`devices_`/`device_owners_` vectors with **no lock** (`:81`). These entry points run on guest
threads, so a concurrent call would race on those vectors and the allocator.

**Unconfirmed.** In the runs we could observe, `XamInputGetState` was called from a *single* host
thread (trace logging, `xam_input.cpp:99`): a 20s run had 5 calls from one thread, and a 120s run
made zero input calls. So the missing lock is a real latent defect, but we have **not** shown it
is what corrupts the `DeviceInfo`. Both the AV and the `0xC0000374` are host-heap corruption; the
actual corruptor is still unidentified. Likely upstream SDK, not game code.

## Next

1. The AV/`0xC0000374` are host-heap corruption with an unidentified corruptor. Best tool: build `rexruntimerd` with AddressSanitizer (source is vendored under `external/rexglue-sdk`) and reproduce, or enable full page heap. Neither is set up yet; `gflags`/`appverif` are not installed.
2. `RefreshDevices` has no lock and is a genuine latent defect; patch it as a defensive fix, but do not expect it to explain the crash without confirmation.
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
