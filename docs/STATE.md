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
| 7 input / audio / stability | in progress — input stabilized, audio silent, cinematics blocked on Bink decoder, stutter is PSO compile |

## InputSystem race fixed with correct lock design (2026-10-03)

The earlier patch only locked inside `RefreshDevices`/`DriverForDevice`/`DeviceInfoFor`, which
still left a window: `GetState` released the lock between `RefreshDevices()` and the per-device
`DriverForDevice()` loop, so another guest thread could rebuild `devices_` in between and hand out
a dangling `DeviceInfo*`.

Reworked to the lock-per-entry-point design: one `std::recursive_mutex` taken once at the start of
`GetState`, `SetState`, `GetCapabilities`, `GetKeystroke`, `Shutdown` and `SetDeviceAssignment`, and
held for the whole body. `RefreshDevices`, `DriverForDevice` and `DeviceInfoFor` no longer lock
(they document that the caller holds it). Recursive so the helpers can be called from an entry
point already holding the lock without deadlocking. Grep confirms every `devices_`/`device_owners_`
access is now under that contract.

Evidence (Tarea B):
- Two consecutive long runs with the rebuilt runtime and `REX_LAUNCHER_SKIP=true`: 150s and 200s
  alive, no exit, no FATAL, and no `ocho_kart` crash in the Windows Error Reporting log for either
  window. Before the correct design, a run died at about 71s with `0xC0000005` in
  `rexruntimerd.dll` (`_Destroy_range<DeviceInfo>`).
- Result: the `0xC0000005` is gone across both runs. Consistent with one bug (the race) showing as
  several crash signatures. Not proven to be the same as the old `0xC0000374` (that one was a single
  heap-corruption event), but it was the same call site family.

## Audio: guest delivers silence (2026-10-03)

Measured with a temporary RMS/peak log in `SDLAudioDriver::SubmitFrame`. The guest does call
`XAudioSubmitRenderDriverFrame` and `SubmitFrame` (queue fills to ~8), and the SDL endpoint opens
at 2ch/48kHz, but every submitted frame has `peak=0.0 rms=0.0`. So the mute is upstream: the buffer
the guest hands to the callback is all zeros. The XMA `0601` write is a lock register already
ignored on purpose (`xma_decoder.cpp`), not the cause. Next: check whether XMA decode produces
zeros, or the guest never fills the buffer (XMP playlist path for menu music vs XMA for races).

## Audio diagnosis (read-only, 2026-10-03)

Two separate audio paths, both silent for different reasons:

**XMA (races, effects).** The guest calls `XAudioSubmitRenderDriverFrame` and
`SDLAudioDriver::SubmitFrame`, the endpoint opens at 2ch/48kHz, but a temporary RMS/peak log showed
every submitted frame is `peak=0.0 rms=0.0`. The output path is correct; the guest hands over an
all-zero buffer, so the decode upstream is not producing samples. The `XMA: Write to unknown
register (0601)` spam is a lock register already ignored on purpose
(`src/audio/xma_decoder.cpp`, `WriteRegister`), so it is not the cause. Next step (not started):
instrument `XmaContext`/`xma_decoder` decode to see whether it produces non-zero PCM, and check
whether the guest fills the buffer before the callback.

**XMP (menu music).** `src/kernel/xam/apps/xmp_app.cpp` implements `XMPGetPlaybackController`
(case `0x0007001B`) as a no-op: it writes zero to the controller and locked pointers and sleeps. The
playlist calls (`XMPCreateTitlePlaylist`, `XMPPlayTitlePlaylist`) track state but there is no
decoder wired to them, and `XMPRegisterCodec` is a `REX_EXPORT_STUB`. So menu music has no playback
implementation. Next step (not started): a real XMP playback path, or confirm the title falls back
to XA/streaming for menu audio.

Neither shim was implemented in this session, per instruction to document only.

## Open issue: launcher closes with no input (2026-10-03)

Reported twice: the launcher window closes on its own while the user is away from the machine.
Not reproduced in 4 minutes idle (process stayed alive, XEX never loaded), so it needs a longer
idle run or focus/session handling. `ReXApp::OnClosing` hard-exits on a window close request
(`std::_Exit(0)`), so a spurious `SDL_EVENT_WINDOW_CLOSE_REQUESTED` (session lock, remote desktop,
monitor sleep) would explain it. Investigate `OnWindowCloseRequested` / focus hooks.

## Findings 2026-10-03 (later): input, stutter, cinematics

**Input heap corruption: fixed and confirmed.** The stack was `XamInputGetState`/`XamInputSetState`
into `rex::input::InputSystem::RefreshDevices`, which rebuilds `devices_`/`device_owners_` with no
lock while guest threads can call it concurrently. Full page heap trapped it; the fix serializes
the access. Patch in `docs/toolchain/rexglue-input-lock-and-launcher-cvar.patch` (also adds the
`launcher_button_icons` cvar), runtime rebuilt and
deployed. The vendored `external/rexglue-sdk` keeps the change uncommitted for an upstream PR.

**Stutter is not the clock.** Measured the xenos vblank worker with a temporary log: both with and
without `clock_no_scaling`, it marks exactly 60.0 vblanks/s with about 3 ms worst tick stall. The
clock is not the cause. The real cost is D3D12 PSO creation when a new VS/PS pair first appears
(`Creating graphics pipeline` in the logs), which shows up as hitches when a track loads. The
runtime does not persist a pipeline cache: `CommandProcessor::InitializeShaderStorage` is an empty
body (`src/graphics/command_processor.cpp`). Caching that set to disk is the fix, and it is an
upstream change, not a local one.

**Cinematics are blocked on naming and a decoder, not path mapping.** The title asks for
`D:\ChavoKartGame\Movies\INTRO.xxx`, `LOGO_*.xxx` and `*_ESM.bik`, but the dump ships raw
`INTRO.BIK`, `LOGO_*.BIK`, `DISCLAIMER01.BIK` with no `.xxx` container and no `.txt` descriptor.
VFS resolution is case-insensitive (`entry.cpp`), and `D:` maps correctly, so the failure is the
missing `.xxx`/`.txt`, not casing. Even if renamed, these are Bink video and the runtime has no
Bink decoder, so the picture would still be missing. This needs the UE3 packaging (Phase 2) and a
Bink decoder, not a path alias.

**Launcher options scaffold.** The `launcher_button_icons` cvar (`auto|xbox|playstation|nintendo`)
is registered in the runtime and shows up under the `Launcher` category of the settings overlay.
Language is already covered by `user_language` (`--user_language 5` selects Spanish MX); the
launcher should map friendly names onto it. Glyph drawing for PS/Nintendo is launcher UI work, not
a runtime setting, because the game's own prompts are baked into its assets. Design notes in
`docs/language-and-launcher.md`.

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
threads, so concurrent calls race on those vectors and the allocator.

**Confirmed (page heap, 2026-10-03).** With full page heap (`cdb` + `!gflag +hpa`) the heap itself
traps the corruption:

```
HEAP[ocho_kart.exe]: Invalid address specified to RtlFreeHeap( ..., 00000268F3948C50 )
std::_Destroy_range<allocator<DeviceInfo>>+0x25
 -> InputSystem::RefreshDevices+0x641
 -> InputSystem::SetState+0xfd
 -> XamInputSetState_entry -> _imp__XamInputSetState
 -> ocho_kart!sub_830D9E08   (guest)
 -> XThread::Execute -> XHostThread::Execute
```

Note the entry point here is `XamInputSetState` (rumble), a *different* XInput entry than the
`XamInputGetState` AV above — both funnel into the unlocked `RefreshDevices()`. Earlier trace
samples only saw single-threaded `GetState`, which is why the race looked unconfirmed; the
`SetState` path is the one that traps it. Upstream SDK bug in `rex::input::InputSystem`.

## Next

1. Fix `rex::input::InputSystem`: guard `devices_`/`device_owners_` (and `RefreshDevices`) with a mutex, or make `RefreshDevices` idempotent/skip when nothing changed. Rebuild `rexruntimerd` from `external/rexglue-sdk` and re-run with page heap to confirm the trap is gone.
2. Report upstream to `rexglue-sdk` with both stacks (`GetState` AV and `SetState` heap trap).
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
