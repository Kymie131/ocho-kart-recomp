# State

Updated 2026-10-03.

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | started — package inventory by name done (320 `.xxx`), class-level catalog pending admin tool |
| 3 compile recomp C++ | done |
| 4 shaders | partially working (101 shaders translated, 87 pipelines — `run-race4.log` 2026-10-03 07:59) |
| 5 kernel shims / boot | **done — runs stable past the intro with GPU** |
| 6 renderer | in progress (Xenos GPU plugin renders the intro) |
| 7 input / audio / stability | in progress — input stabilized, audio silent, cinematics blocked on Bink decoder, stutter is PSO compile |

## InputSystem::RefreshDevices race — CLOSED (2026-10-03)

Closed. Upstream issue: https://github.com/rexglue/rexglue-sdk/issues/475 (full diff posted as a
comment, verified to contain all three files). Local patch of the same diff lives at
`patches/rexglue-sdk-input-refreshdevices-race.patch`, committed in `4e53749` and pushed.

Housekeeping:
- `origin/main` = `4e53749` after push, equal to the local HEAD.
- The vendored submodule `external/rexglue-sdk` stays dirty on purpose; the change is carried by
  the patch and the issue, not committed inside the submodule.

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

## Audio reversing: full chain, contexts never initialized (2026-10-03, chapter 3)

Read-register logging shows the guest reads `0x7FEA1800` (reg `0x600` = ContextArrayAddress): it
does look up the context array base the shim publishes. Write logging shows it then writes only
`0x7FEA1804` (0x02000000) and never a lock/kick register.

Chain (all verified):
1. The title does not use the XMA API (`XMACreateContext`/`XMAInitializeContext`: 0 calls).
2. The shim allocates the 320-context array and publishes its physical address at reg 0x600.
3. The guest reads 0x600 (confirmed), so it finds the array.
4. But the contexts in it were never initialized (the bit 0x4 the driver tests is absent), because
   nothing ran the init the API would do.
5. The driver loops, sees no ready context, exits without kicking; Decode never runs; audio is zero.

So the block is context initialization, not mapping. Next step (reading): check whether the title
calls `XMACreateContext`/`XMAInitializeContext` through a mis-mapped import, or expects contexts
from another path the shim does not drive. Instrumentation reverted.

## Audio reversing: the 0x1FF address was my arithmetic error (2026-10-03, chapter 2)

Corrected the previous claim. The guest's store at `sub_82B8B448` does
`rlwinm r10,r7,2,0,29` before `stwbrx`, so the effective address is `r7 << 2`, not `r7`. With the
base case that is `0x1FFA8690 << 2 = 0x7FEA1A40`, i.e. register **0x690 = Context0Lock**, inside
the `0x7FEA0000` MMIO range the shim maps. So the "unmapped 0x1FF region" hypothesis was wrong;
it was a missing `<<2` in my earlier reading.

Measured again with a log of every distinct (addr, group) MMIO write: the shim still receives only
`0x7FEA1804` (reg 0x601 = 0x02000000), and **no** lock/kick/clear register (0x650/0x690/0x6A0) is
ever written. Combined with the loop logic (first context without bit `0x4` jumps to the loop end),
the guest's XMA software driver finds no prepared contexts and exits without kicking anything.

Root cause now: the title never calls `XMACreateContext`/`XMAInitializeContext` (measured 0 calls),
so no XMA contexts exist for its software driver to process. The missing link is how/where the
title is supposed to register contexts that the shim does not populate. Next step is to find where
the title sets up contexts by another path (kernel memory), which is still reading, not a fix.
Instrumentation reverted.

## Audio reversing: root cause confirmed (2026-10-03)

Instrumented the XMA MMIO write thunk to log every distinct raw address. Over a run, the shim
receives **exactly one** address: `0x7FEA1804`. It never receives the `0x1FFA8690`-range write the
guest's XMA software driver uses to kick each context (`sub_82B8B448`).

Root cause: the guest drives XMA itself and writes its per-context kick/status to the `0x1FF...`
region, which is **not mapped as MMIO** in the shim (only `0x7FEA0000` is). Those writes fall
through to normal guest memory and do nothing, so `XmaContext::Decode` never runs and every audio
buffer stays zero. The `0x7FEA1804` start/end transaction writes do reach the shim but are cosmetic.

Fix is now well defined (not guessed): map/handle the `0x1FF...` XMA register view that the guest
computes, so its per-context enable writes reach the decoder, or determine why the guest targets
that address (a second MMIO view vs a mapping the shim must replicate). This is the concrete,
verified next step. Instrumentation reverted.

## Audio reversing: guest has its own XMA software driver (2026-10-03)

Found the writer of `0x7FEA1804` in the recompiled guest:
`sub_82B8B448` (`ocho_kart_recomp.301.cpp`). It:

1. Enters a critical section (`RtlEnterCriticalSection`).
2. Writes `0x02000000` to `0x7FEA1804` (start of a work transaction).
3. Iterates 320 contexts, and for each with bit `0x4` set and `0x20000` clear it updates
   buffers/offsets and writes a per-context enable bit to a computed register address.
4. Writes `0x03000000` to `0x7FEA1804` (end of transaction).
5. Leaves the critical section.

So `0x02`/`0x03` on `0x1804` are a start/end transaction marker, not a command the shim must decode;
Xenia ignoring it is consistent. The guest drives XMA in software itself.

Important detail: in step 3 the guest writes to `0x1FFA8690`-range addresses
(`addis r7,r7,8187` then `-31088`), which is **not** inside the `0x7FEA0000` MMIO range the shim
maps. So either the guest uses a second XMA register view the shim does not map, or those are normal
guest memory. Deciding which requires one more measurement (does the shim receive writes outside
`0x7FEA`, or is the kick written to an unmapped register view?).

Candidate fix path, grounded in this code: on the `0x02000000` write to `0x7FEA1804`, the shim
should drive the XMA context processing (the same work the exports path does) instead of ignoring
it, since the guest clearly brackets a 320-context processing pass with that value. Verify the
`0x1FF...` write target first so the fix lands on the right register.

## Audio: the title drives XMA by MMIO, not the XMA exports (2026-10-03)

Key finding from a debug run (music/menu phase): **zero** calls to the XMA kernel exports
(`XMACreateContext`, `XMAInitializeContext`, `XMAEnableContext`, `XMASetInputBuffer*`,
`XMASetOutputBuffer*`). The only XMA traffic is **32518 writes to MMIO register `0x0601`** (physical
`0x1804`), and nothing else. So the title does not use the XMA API this shim implements; it drives
XMA by writing `0x1804` directly (this maps through `(addr & 0xFFFF) / 4` to `0x601`).

`0x0601`/`0x1804` is listed as `???` in the XMA register table
(`include/rex/audio/xma/register_table.inc`), and Xenia also ignores it on purpose. No verified
semantics exist for it here, so it must not be guessed. The XMP path is unrelated: the title never
calls `XMPCreateTitlePlaylist` either; only `XMPGetPlaybackController`/`XMPSetPlaybackController`.

Next step (reversing, not a shim): read the recompiled guest code that writes `0x1804` to learn the
handshake (what the `0x02`/`0x03` values mean and what the guest expects to happen), then implement
that in the XMA MMIO write path. That is the only path this title uses for audio.

## Audio: what actually blocks it (2026-10-03, concluded)

Two independent gaps, both upstream-scale, no one-line fix:

1. **XMP (menu music).** The title calls `XMPGetPlaybackController` and
   `XMPSetPlaybackController`; it never asks the VFS for any `.fsb`/`.xma`/`.wav` for music. The
   XMP path in `src/kernel/xam/apps/xmp_app.cpp` tracks playlists but has no decoder wired, and
   `XMPRegisterCodec` is a `REX_EXPORT_STUB`. So menu music has no playback implementation at all.
2. **XMA (races/effects).** `XmaContext::Consume` never runs, so no PCM is decoded. The guest
   writes `0x0601` (a register Xenia also ignores on purpose) and the XMA context is never kicked
   in a way this shim drives. The XMA subsystem (contexts, indexed registers, kick/lock/clear via
   the XMA exports) needs the full path verified against the title's sequence.

Cross-check against Xenia: the `0601` handling is identical to Xenia upstream, so it is not the
bug. Fixing audio means implementing XMP playback and validating the XMA kick sequence, which is a
dedicated audio session, not a shim tweak. Instrumentation reverted; runtime rebuilt clean.

## Audio: XMA decode never runs (2026-10-03, deeper)

Instrumented `XmaContext::Consume` (temporary peak log). Over a 40s run: `XMA_DIAG` never printed,
so the XMA decoder never produces PCM. Cross-checked the same run: `XMA: Write` ~27k times (the
`0601` lock writes), `XMPGetPlaybackController` once, `XAudioSubmitRenderDriverFrame` 10,
`SubmitFrame` 20. So it is not "buffers with zeros downstream" alone: the XMA pipeline never
starts. The guest hammers the `0601` register with `0x02`/`0x03` (a lock/handshake) and the shim
ignores it, so no decode is kicked. Menu music is the XMP path, which has no playback
implementation at all (`XMPRegisterCodec` is a stub). Two real fixes needed: (1) implement the XMA
context kick/handshake so `Decode` actually runs, (2) implement XMP playback or confirm menu audio
falls back to XA. Both are upstream-scale, not a one-line shim. Instrumentation reverted.

## Audio: guest delivers silence (2026-10-03)

Measured with a temporary RMS/peak log in `SDLAudioDriver::SubmitFrame`. The guest does call
`XAudioSubmitRenderDriverFrame` and `SubmitFrame` (queue fills to ~8), and the SDL endpoint opens
at 2ch/48kHz, but every submitted frame has `peak=0.0 rms=0.0`. So the mute is upstream: the buffer
the guest hands to the callback is all zeros. The XMA `0601` write is a lock register already
ignored on purpose (`xma_decoder.cpp`), not the cause. Next: check whether XMA decode produces
zeros, or the guest never fills the buffer (XMP playlist path for menu music vs XMA for races).

## Phase 2 kickoff and GPU AV recheck (2026-10-03)

**GPU plugin AV not reproduced.** Four runs with the current locally built plugin
(`REX_LAUNCHER_SKIP=true`), 90s each: all alive, no exit, no crash in the Windows Error Reporting
log. Closed as not reproduced on the current build; possibly resolved by rebuilding the plugin.
Reopen if it returns.

**Phase 2 started.** Package inventory of the 320 cooked `.xxx` by name and size is written to
`docs/reversing-notes.md` (no contents). Highlights: 12 playable characters (KartPawn, each with
`Arch`/`SP0` variants), per-track `Pista<X>_Arte/_Acc` plus `CO/CT/EN` circuit packages, challenge
packages, menu packages, and 4 localization packages. Class-level catalog attempt: UE Explorer's MSI was extracted without admin via `msiexec /a`
(elevation-free), giving `Eliot.UELib.dll`. A .NET reader was built against `UELib` and calls
`UnrealPackage.DeserializePackage`; some packages read (one showed 89 names / 35 exports / 31
imports, package version 860, big-endian), but results are not stable run to run and many packages
throw `EndOfStream`. The cooked packages are LZO-compressed (`CompressionFlags:4`), and UELib needs
the compressing-version / decompressor configured for Xbox cooked data, which was not done. So a
reliable class list is still pending. Next step: either run the UE Explorer GUI with the right Xbox
settings, or prepare UModel (portable, no admin) which handles cooked packages. UELib and the reader
live outside the repo (temp); no package contents were written anywhere.

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

## Launcher auto-close: defensive veto added (2026-10-03)

Symptom: the launcher closed on its own while the machine was unattended. Root path is
`SDL_EVENT_WINDOW_CLOSE_REQUESTED` -> `Window::SendCloseRequestToListeners` -> if no listener
vetoes, `ReXApp::OnClosing` -> `std::_Exit(0)`. `OnWindowCloseRequested` defaulted to true, so
nothing refused an external close.

Could not reproduce in a 180s idle run (process stayed alive, no close request logged). Since the
symptom is real to the user but not reproducible headlessly, a defensive fix was applied instead:
`OchoKartApp::OnWindowCloseRequested` refuses the close while the launcher is still waiting
(`resume_` set), and the Quit button now goes through `ReportClose()` which clears `resume_` first
so it still closes. Verified: launcher stayed alive 40s with the veto active and the gate intact,
and the `launcher_skip` path still boots to the game. A stray `WM_CLOSE` (focus/session) can no
longer dismiss the menu. Reopen if it still closes while waiting.

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

## Next (updated 2026-10-03)

Done since the previous list: the InputSystem lock fix (committed `73f6691`), the upstream issue
#475 with the full diff, and the local patch saved.

Still open:

1. Audio. XMA delivers all-zero frames (decode upstream) and the XMP menu path has no playback
   implementation (`XMPRegisterCodec` is a stub). See the two audio sections above. This is a
   deliberate session of its own.
2. Launcher closes with no input while the machine is unattended (not reproduced in a 4-minute idle
   run). See "Open issue" above. Suspected external window close request.
3. `0xC0000005` seen once in the GPU plugin. **Checked on the current build: not reproduced.**
   Original: dump `ocho_kart.exe.36364.dmp`, `INVALID_POINTER_READ` at `rexgpu-xenosrd.dll+0x1d281`
   (module timestamp `0x6a88d2d8` = 2026-08-21, the prebuilt SDK plugin; no matching PDB).
   On the current locally built plugin (own `rexgpu-xenosrd.pdb`), four runs with
   `REX_LAUNCHER_SKIP=true` each survived 90s alive with no exit and no crash in the Windows Error
   Reporting log. Closed as not reproduced on the current build; possibly fixed by the plugin
   rebuild. Reopen if it reappears.
4. Cinematics: title asks for `.xxx`/`.txt` movie containers, the dump ships raw `.BIK`, and the
   runtime has no Bink decoder. Needs UE3 packaging plus a decoder, not just path mapping.
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
