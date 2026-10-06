# State

Updated 2026-10-06.

## Session: tooling, host music, Phase 2 catalog (2026-10-06)

Measured boot→menu file opens with the instrumented runtime (temporary, now
reverted): the title opens `D:\ChavoKartGame\CookedXbox360\FMODAudio.xxx`
(success) and never opens any `*.fsbcache`, confirming the earlier diagnosis:
the blocker is the title's own UE3/FMOD activation, not the VFS. The same trace
shows the movies that exist on the dump **do** resolve (`INTRO.bik`,
`LOGO_*.bik`, `DISCLAIMER01.bik` all `result=0x0`); the failed probes are the
`.xxx`/`.txt`/`_ESM` variants and `VIDEODEMO.bik`, which the dump does not ship.
So the "movie paths do not resolve" note below is wrong for the current build —
the VFS maps `D:` correctly and is case-insensitive. Whether the picture shows is
the separate Bink-decoder question.

What changed this session:

- **Runtime cleanup.** Reverted the temporary instrumentation in the vendored
  SDK (`xboxkrnl_io.cpp` AUDIOFILE/OPEN/BT, `xboxkrnl_rtl.cpp` ANSISTR,
  `xboxkrnl_threading.cpp` THREADCREATE/BT). Kept the intentional changes (Input
  race lock, launcher cvars, XMA/Downpour audio work). Rebuilt
  `rexruntimerd.dll` (RelWithDebInfo) and deployed it to the game build; boot
  verified alive 110 s with no FATAL. The game's generated code still carries the
  old guest traces (`MIXTRACE`/`WORKER`/`THREADSTART`) — that lives in the
  analysis project, not the repo, and is removed by a forced codegen.
- **Host music made usable.** New `tools/host-music.ps1` extracts `menu.wav`
  (`95D00942` #29 `Main_full_02`, 170 s) and `race.wav` (#45 `Acapulco_final_02`)
  from the dump's own banks using `tools/out/fsb5.exe` + FFmpeg. The pre-boot
  launcher gains a **Background music (host)** toggle (auto-on when tracks exist)
  plus **Fullscreen / VSync / resolution scale** video options. `install-launcher.ps1`
  now also deploys `src/audio/host_music.h`. Verified: boot with `--host_music true`
  logs `host_music: writing/playing 'menu.wav'` and stays alive.
- **Phase 2 catalog.** `tools/catalog/ue3_catalog.py` parses the big-endian UE3
  summary from each `.xxx` and writes `docs/ue3-catalog.md` (**320** packages, all
  v860/0, with name/export/import counts). The name map itself is stored in LZO
  chunks in these cooked packages, so symbol *names* are marked compressed and not
  listed yet; the counts are from the uncompressed summary and are reliable.
- **Phase 9/10.** Added `.github/workflows/release.yml` (code-only tooling
  bundle on tag, refuses tracked game assets) and `docs/BUILD.md`; refreshed
  `README.md`, `CHANGELOG.md`, `docs/roadmap.md`.

Not run/verified this session: audible output of host music (no audio capture
here), the launcher UI on screen, and the release workflow (no CI run).

## Audio guest diagnosis: the title never loads the sound banks (2026-10-04, latest)

Ran the game under a symbolized LLDB debugger and captured the guest call stack
for the `FMODAudio.xxx` open:

`NtCreateFile_entry <- sub_830D0FA0 <- sub_829E4F40 <- sub_822EB0F0 <-
sub_822EB888 <- sub_8235CB60 <- sub_830E9C98 (thread)`.

What is measured and closed:
- ReXGlue opens `FMODAudio.xxx` but **never any `.fsbcache`**; Xenia opens 7 banks
  (`<hash>.xxx` -> `<hash>.fsbcache` fallback loader). In ReXGlue **no sound asset**
  goes through the UE3 package loader, so the title's audio system **never
  activates voices** -> silent mixer. The intro audio the user hears does not come
  from UE3 sound assets.
- The engine/hilos work: the mixer (`sub_82BB1188`) runs and submits frames; the
  workers `sub_82BAD4B0`/`sub_82ED1B98` are created and run with the **same
  start/context as Xenia**.
- Not a shim: no `XAudio*` stub is invoked (only `XamVoiceSetMicArrayIdleUsers`);
  not profile/mute; not VFS (no failed bank opens); not the decoder (Downpour's
  audio was ported with no effect). Updating to the Oct-2 nightly would not help
  either (its 24 commits are UI/input/build; 63 lines in kernel/fs).
- Conclusion: the title's UE3 audio **activation** does not fire in ReXGlue. This
  is game logic -> needs UE3 audio-system reversing, not a one-line shim patch.

Tooling left in place: `tools/debug-audio.ps1` (LLDB + exe/runtime PDBs, symbolized
guest stacks; space-free junction `C:\Users\israe\ocho_dump`). The runtime also has
Downpour's `src/audio/*` ported, plus temporary guest instrumentation
(`AUDIOFILE`/`BT`/`DIRQUERY`/`THREADCREATE` in `xboxkrnl_io.cpp`/`xboxkrnl_threading.cpp`,
`MIXTRACE`/`THREADSTART`/`WORKER`/`WAIT` in generated `.cpp`) to revert later.

## Audio host-side player in the runtime (2026-10-04, latest)

Wired an in-process host music player into the game overlay so the dump's music
plays during the game regardless of the silent guest mixer.

- `src/audio/host_music.h` (source of truth; mirrored to
  `%ProgramData%\rextools\proj-ocho-kart\src\audio\host_music.h`):
  `ocho::audio::HostMusic` opens a 48 kHz stereo s16 `SDL_AudioStream`, loops
  pre-decoded WAVs, and converts any PCM16 rate/channel layout to the device
  format with linear interpolation.
- `src/launcher/ocho_kart_app.h` (mirrored to the project's
  `src/ocho_kart_app.h`): `OnPostSetup` starts it (guest memory via
  `runtime()->memory()->TranslateVirtual`), `OnShutdown` stops it.
- **Placement:** menu track by default; switches to the race track when the guest
  XMA voice array (`0x83C12330`) has entries; `host_music_start_delay_ms` (default
  15000) keeps it silent during the intro so it does not overlap.
- Opt-in cvar `host_music` (default false); alt cvars `host_music_dir`,
  `host_music_menu`, `host_music_race`, `host_music_gain`,
  `host_music_state_addr/stride/count`, `host_music_poll_ms`,
  `host_music_start_delay_ms`. Fails safe.

Measured (2026-10-04): starts after the delay and plays `menu.wav`; game stays
alive. (An intermittent launcher self-close is separate, see the open issue.)

## Audio host-side: FSB5 parser + XMA decode → audible (2026-10-04)

Chose the host-side fallback for audio over more guest chasing. New tool reads the
user's own cooked sound banks directly and reproduces the title's XMA audio on the
PC without touching the guest or the runtime:

- `tools/fsb5/fsb5.cpp` — dependency-free C++17 FSB5 reader (version 1; codec
  `0x0A` XMA plus PCM8/16) and WAV writer. XMA subsounds are wrapped in a WAV with
  an `XMA2` chunk (XMA2WAVEFORMAT v4); FFmpeg's WAV demuxer turns it into decoder
  extradata and its native `xma2` decoder produces PCM.
  Commands: `list`, `extract <bank> <idx> <out.wav>`, `extract-all <bank> <dir>`.
- `tools/fsb5/build.ps1` — builds to `tools/out/fsb5.exe` (gitignored) with
  clang + VS Build Tools.
- `tools/fsb5/play.ps1` — extract + `ffmpeg` decode + optional `ffplay` playback
  (`-Play`) or save (`-Out`).

Measured (2026-10-04):
- All **15** `*.fsbcache` banks parse clean (FSB5 v1, codec `0x0A`): **7034
  subsounds**, zero warnings; readable names where present (e.g.
  `brasil_soccer_final_01`).
- Music bank `95D00942` #0 (2ch/48kHz): 2.47 s, `mean -29.2 dB`, `max -10.5 dB`;
  #1: 44.54 s, `mean -23.0 dB`, `max -8.8 dB` — real audio.
- `649B9BA1`: `extract-all` writes all 25 with zero failures; all decode with
  signal (`mean ≈ -19 dB`).
- A Python prototype in temp produced the same `mean -29.2 dB`; the C++ parser
  matches.

This closes the host-side fallback: the dump's music/effects are decodable and
audible now, independent of the still-silent guest mixer. Optional follow-up:
wire a host-side player into the runtime and pick the subsound from game state.
The C++ parser is ready to reuse there. See `docs/audio-restart.md`.

## Audio: Kick DOES exist in the guest; menu has no context at all (2026-10-03, latest)

The previous "fresh review" claim that the title "never writes Kick (0x650); only Lock
0x690 and Clear 0x6A0" is **wrong** — it only looked at `.89` and `.301`. There is a third
`s twbrx` target: **`sub_82B8B5B8` (`ocho_kart_recomp.92.cpp:17351`)**. Its arithmetic
(`addis r9,r9,8187` + `addi r9,r9,-31152`, then `rlwinm r9,r9,2,0,29`) resolves to physical
`0x1FFA8650` → virtual `0x7FEA1940` → **reg `0x650` = Context0Kick**. It is the "kick" pass
over the voice list and it clears flag `0x20000` on the way out. It is called from
`sub_82B875B8` (`ocho_kart_recomp.200.cpp:17041`), which is a virtual method (no direct
callers). So the guest driver does have: `sub_82B8AC20` = create+Clear, `sub_82B8B448` =
tick+Lock, `sub_82B8B5B8` = kick. The shim's Kick → `Enable()` + `Work()` path is correct.

Instrumented and measured this session (runtime rebuilt + deployed):
- Added cvar `xma_trace_writes` (logs each Kick/Lock/Clear and the deduped `0x601` write)
  and `xma_lock_decodes` (experimental, default off). Patch:
  `patches/rexglue-sdk-xma-trace-and-lock-decode.patch`.
- **Boot→menu, 130 s, `REX_XMA_TRACE_WRITES=true`: 35 283 writes, all to `0x601`
  (`0x02`/`0x03`). Zero Kick, zero Lock, zero Clear.** So in the menu no XMA context is
  ever created; the 320-slot array is empty and only the `0x601` transaction from
  `sub_82B8B448` runs. `xma_lock_decodes` cannot help the menu because no Lock is written
  either.
- The decisive missing measurement is now **boot→race** with `xma_trace_writes` on: it
  settles whether the effects path really kicks (and thus decodes), separating "menu never
  starts the music" (upstream title logic) from "shim never decodes".

Root cause of silent menu music remains upstream of the shim: the title never registers a
music voice in the menu, so `sub_82B893A0`/`sub_82B8B5B8` never run there. Next step is to
find what the title waits for before starting the menu music (a game-state/asset/notification
gate), which needs either a race trace or an interactive debugger.

## Audio fresh review from zero: two corrections (2026-10-03, latest)

Re-read the whole audio path from scratch (shim sources in `external/rexglue-sdk/src/audio/*`,
`src/kernel/xboxkrnl/xboxkrnl_audio*.cpp`, `src/kernel/xam/apps/xmp_app.cpp`, the register table, and
the game's recompiled audio code in `generated/ocho_kart_recomp.44/60/77/86/89/92/191/227/246/266/
274/299/301.cpp`), plus the one real run log that reaches the menu
(`out/build/win-amd64/logs/ocho_kart_008.log`). Two things the earlier notes state wrongly:

1. **The shim is NOT line-for-line faithful to Xenia.** The claim in the
   "shim compared to Xenia XmaContextNew; faithful" section is too strong. The vendored
   `xma_decoder.cpp`/`xma_context.cpp` carry deliberate ReXGlue changes that diverge from Xenia
   Canary's current `xma_context_new.cc`/`xma_decoder.cc`:
   - **Kick decodes inline.** Xenia enables the context, signals the worker, and (with a dedicated
     thread) blocks on `WaitForWorkDone()`. ReXGlue instead calls `context.Work()` inline inside
     `WriteRegister` (commit `29eaa8a`) and never waits. Behaviour differs if the guest reads the
     context struct immediately after the kick.
   - **`XmaContext::Work()` is a simplified port.** It lacks Xenia's "no input" stall-detector branch
     (NFS: Carbon/MW read `output_buffer_write_offset`), its double-check before invalidating the
     output buffer, and Xenia's "don't abandon a partially consumed frame / decode stalled" loop
     guards. Also the loop/`carry_frame`/`kDecoderStartPadding` machinery in the ReXGlue port is a
     ReXGlue-only interpretation, not Xenia.
   - These are candidate bugs, not proven to be *the* blocker, but the previous "no divergence found"
     statement must not be relied on.

2. **The game drives XMA by MMIO and never writes a Kick (0x650); it writes Lock (0x690) and Clear
   (0x6A0).** Confirmed by decoding the guest's own arithmetic:
   - It imports only `XMACreateContext`/`XMAReleaseContext` (ordinals 548/550 in
     `docs/toolchain/xex-imports-signed.md`) — **not** `XMAEnableContext`/`XMADisableContext`. So it
     cannot Enable by API.
   - `sub_82B8AC20` (`ocho_kart_recomp.89`), the per-voice creator called from `sub_82B8B8C0`, calls
     `XMACreateContext`, maps the context with `MmMapIoSpace`, then writes a per-context bit to
     physical `0x7FEA1A80` = reg `0x6A0` = **Context0Clear**.
   - `sub_82B8B448` (`ocho_kart_recomp.301`), the engine tick that does run, sweeps the 320-slot list
     at `0x83C12330` and for each ready context writes to physical `0x7FEA1A40` = reg `0x690` =
     **Context0Lock**. It never writes Kick.
   - Only three `stwbrx` sites target the XMA MMIO window (`.89`, `.92`, `.301`); none resolves to
     `0x650` (Kick). `0x601` (`0x7FEA1804`, `0x02`/`0x03`) is bracketing/lock traffic only.

   In the shim, Kick is the **only** path that calls `context.Enable()`; Lock calls `Disable()` and
   Clear calls `Clear()`. So a context created by this title is never enabled → `Work()` returns
   false → no decode. That is consistent with the measured zero/garbage mix buffer. If gameplay
   effects are audible (as reported earlier), there must be a Kick path not found by static reading,
   or the effect audio comes from a different client. This is the one thing that must be measured,
   not argued.

Concrete next step (small, bounded): add a temporary log in `XmaDecoder::WriteRegister` printing
every `(r, value)` for `r` in `0x610..0x6AF` plus `0x601`, and run a boot→menu→race. That settles
whether any Kick ever reaches the shim. If none does, the fix is either (a) find the guest's real
kick gesture, or (b) make the shim treat Clear-after-init as the decode trigger the title expects —
but only after Xenia is confirmed to do the same (it currently does not, so (b) is a guess and must be
validated against Xenia on the same title). No code changed in this review; analysis only.

## Audio: Xenia comparison narrows it to the title's XAudio mixer producing zeros (2026-10-03)

Ran the same dump under **Xenia Canary** (downloaded, outside the repo) to compare the audio path, per
the plan in the previous sections. Findings:

- **Xenia registers 2 XAudio render clients** (`AudioSystem::RegisterClient` for index 0 and 1);
  ReXGlue also registers 2 (confirmed by instrumenting `XAudioRegisterRenderDriverClient_entry`: the
  title calls it twice, callbacks `0x7018F558` and `0x7018CC18`, both with guest callback
  `0x82BB13A8`). So client registration is *not* the gap — both emulators get two clients.
- **Both clients submit to the same guest buffer `0x83C12870`**, and instrumenting
  `AudioSystem::SubmitFrame` shows every submitted frame is `peak=0` (all zeros), for both indices,
  all through the menu. So the guest's mixer hands the emulator silence.
- The render-driver callback is `0x82BB13A8` → `sub_82BB1188` (the mixer loop): it waits on events,
  reads the guest mix source at `+60`, and copies 256 frames x 6 channels through `sub_82BB0FC8`.
  The XMA engine (`sub_82B8B448`, sweeping the 320-slot list at `0x83C12330`) is a **separate**
  system that is empty in the menu (`nonnull=0/320`, measured).
- Xenia also fails `XamVoiceSetMicArrayIdleUsers` (logs "not implemented"), so that stub is not the
  cause either.

Conclusion: the emulator side behaves correctly (clients registered, frames pulled, endpoint open at
2ch/48kHz). The title's own XAudio mixer produces an all-zero buffer and its XMA voice list is never
populated — the same "engine never registers voices" blocker, now confirmed title-side, not a
registration/shim gap. All instrumentation reverted (generated `.cpp`, `audio_system.cpp`,
`xboxkrnl_audio.cpp`, and a stray `sdl_audio_driver.cpp` diag left by the previous session); runtime
and game rebuilt and deployed clean.

## Audio: the game's own audio engine (not XMP, not the shim) is the blocker (2026-10-03)

Deeper session on the engine side, with temporary in-`.cpp` diagnostics added to the generated
recomp files (`ocho_kart_recomp.274/301/89/299.cpp`), reverted after each run; the instrumented
copies are kept outside the repo and the final build is clean. Key measured facts on the current
build, from a fresh boot through the intro into the menu:

- **The voice-list manager `sub_82B893A0` never runs.** It was instrumented at its single return
  site; across an 80 s boot-to-menu it was reached **0 times**. This is the function that assembles
  the per-voice work list and calls the context creator `sub_82B8B8C0` → `sub_82B8AC20` →
  `XMACreateContext`.
- **The engine tick `sub_82B8B448` runs constantly** (~27.5k calls in 75 s across two guest threads),
  but it only sweeps the 320-slot context array at `0x83C12330` and finds it empty. So the engine is
  on, but **no voices/contexts were ever registered**, which is exactly why the mix buffer stays
  zero (or uninitialised garbage).
- **`sub_82B8B8C0` and `sub_82B8AC20` are never called** in that same run — not even the single
  context creation the earlier session had recorded (that one came from a different moment/run where
  the engine had reached the codec path). Confirms the list is never built in the menu.
- **The device bring-up works.** `sub_82BB18B8` runs and calls `sub_82B8A128(0,3,6,48000,32,32,63,128)`
  (the mixer/device create) → stores the device at voice-frame `+56`, a callback buffer via
  `sub_82B7BA48` at `+60`, then `sub_82BAD368` three times (three voice workers at `+76/+80/+84`) —
  those `sub_82BAD368` calls were seen (6 across two boot phases, args `r3=0/1`). So the codec/device
  path is exercised, but the **playback** path that registers XMA voices is not.
- **XMP is a dead end for this title.** Separately re-confirmed: the title calls
  `XMPGetPlaybackController` once after the intro, gets "unhandled" (shim writes 0), then immediately
  calls `XMPSetPlaybackController(xmp_client=0, controller=1)` — i.e. it declares *itself* the
  playback owner and from then on plays everything through its own mixer. It never calls
  `XMPCreateTitlePlaylist`/`XMPPlayTitlePlaylist` (0 calls). So XMP playback is not the mechanism the
  title uses; the `Bink Snd` threads are the cinematic audio and are not the menu/race mixer.

Conclusion: menu music and engine sound are silent because the title's own mixer/XAudio path never
registers voices, and that is title logic reached only when the engine decides to play. The shim
(XMA, XAudio, XMP) is not the blocker: XMA exports are never called, XMP is used only for the
ownership handshake, and the audio endpoint opens correctly at 2ch/48kHz. Fixing this is a dedicated
engine-debug session (find what the title waits for before it builds its voice list — a system/state
gesture, an XMP/notification signal, or an asset it fails to load), not a one-line shim patch. No
code change was kept; the runtime and generated files are reverted and rebuilt clean.

## Audio: the innermost blocker is XMP, and it is now proven on the current build (2026-10-03)

Re-ran the audio front on the current build with fresh, reverify-able instrumentation (a small
`xma_diag` counter in `xma_decoder.cpp`, reverted after the run; the instrumented copy is kept
outside the repo). A 15 s menu run produced an unambiguous picture:

- **The XMA context-array read never happens.** The `XMA_DIAG` log on `ReadRegister` for
  `ContextArrayAddress` (reg `0x600`) did not fire once. The worker's periodic line never fired
  either, because the XMA worker thread did ~0 work: **`AllocateContext` was never called** during
  the menu, and the shim received **no kick/lock/clear** (reg `0x650/0x690/0x6A0`).
- **The only XMA traffic is the scalar `0x0601` scribble.** Two guest threads hammer
  reg `0x601` with `0x02000000`/`0x03000000` (~24k writes in 15 s). Xenia ignores this register on
  purpose, and the guest's `sub_82B8B448` keeps *its own* context metadata in guest RAM
  (`sub_82B8AC20` reads cache-line tag words with `REX_MM_LOAD`, so that copy is streamed/uncached,
  updated directly by the guest's software XMA driver).
- **The title is parked in XMP, not XMA.** During the same menu, `XMPGetPlaybackController`
  (arg `0x0007001B`, xmp_client `2`, `controller_ptr`/`locked_ptr` in guest RAM) is called **once per
  second**, and *nothing else* — no XMA API call, no `XMPCreateTitlePlaylist`, no
  `XMPPlayTitlePlaylist`.

Combined with the shim's `case 0x0007001B` handler, which writes `0` into the controller/locked
outputs (`src/kernel/xam/apps/xmp_app.cpp:408`), this gives the concrete innermost blocker for menu
music: **the title polls the XMP playback controller, gets "controller = 0" forever, and therefore
never starts playback.** The `0x0601` scribble is the XMA *engine* running (and finding no work),
not the thing holding playback back.

This corrects the earlier "guest only writes 0x1804 and never reads 0x600" line: on this build the
`0x600` read is simply *never made* — the title has not reached the context-array path, it is
sitting in the XMP poll. The earlier reading of a one-entry context list was measured at a different
moment (a run whose audio subsystem had reached the XMA path).

Next, concrete and small enough for a session: determine the controller value the title expects
(what the real XAM writes on a playback-capable console) and return it from `0x0007001B`, then
observe whether the title proceeds to create/play a playlist. That is a real, bounded fix candidate
for **menu music**; the XMA kick path remains the separate race/effects gap. No shim change was made
in this session (analysis only).

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | done — 320 packages catalogued (`docs/ue3-catalog.md`); symbol names still LZO-chunked |
| 3 compile recomp C++ | done |
| 4 shaders | partially working (101 shaders translated, 87 pipelines — `run-race4.log` 2026-10-03 07:59) |
| 5 kernel shims / boot | **done — runs stable past the intro with GPU** |
| 6 renderer | in progress (Xenos GPU plugin renders the intro) |
| 7 input / audio / stability | in progress — input stabilized, guest audio silent (host-side music covers it), cinematics blocked on Bink decoder |
| 8 PC options | partial — launcher has fullscreen / vsync / resolution scale |
| 9 CI releases | partial — `release.yml` packages code-only tooling on tag |
| 10 contributor docs | done — `docs/BUILD.md` |

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

## Audio: shim compared to Xenia XmaContextNew (2026-10-03, final)

Fetched Xenia Canary's current `xma_decoder.cc` and `xma_context_new.cc` and compared against the
shim's `xma_decoder.cpp`/`xma_context.cpp`. On every point the shim matches Xenia: Work() gating on
is_enabled/is_allocated and clearing enable, the Kick/Lock/Clear handling, the Consume/Decode
stalling rules, PrepareOutputRingBuffer, StoreContextMerged. The shim's `xma_context.cpp` is the
ported XmaContextNew. No shim divergence found.

Ran Xenia on the dump (installed `Xenia.XeniaCanary`): it boots and runs; at the intro it also issues
exactly **one** `XMACreateContext`, same as the recomp. So the recomp is not creating fewer
contexts. Xenia's funcall trace lists only exports, not internal `82B8...` calls, so the difference
in the guest driver cannot be seen from its log.

Conclusion (closed): the shim is faithful to Xenia and the count matches. The remaining gap is
purely inside the guest's software audio driver, and isolating it needs an interactive guest
debugger (`xenia --debug` with a breakpoint in the voice manager `sub_82B893A0`), which this
environment cannot drive. No further shim-side fix is warranted by evidence; a speculative change
would risk the effects that currently work. Documented as the stopping point.

## Audio: shim hypotheses all refuted by measurement (2026-10-03, final)

Compared ReXGlue's shim against Xenia's current `xma_decoder.cc` line by line and tested each
candidate:
- register ranges Kick/Lock/Clear: identical to Xenia. Correct.
- kContextCount 320, AllocateContext, BitMap Acquire/Release: correct.
- `MmGetPhysicalAddress` for the context: measured `0xFFC9A000 -> 0x1FC9B000`, no failure. Correct.
- context array base published at reg 0x600 and read by the guest: confirmed working.

So every shim-side hypothesis is refuted with runtime data. The shim is faithful to Xenia. The
remaining unknown is why the guest never writes a context Kick (only the 0x1804 transaction), which
is inside the title's own software audio driver and its voice list. Resolving it needs an
interactive debugger on the guest at the point `sub_82B893A0`/`sub_82B8B8C0` build the voice list,
which is beyond static reading. Xenia is installed (`Xenia.XeniaCanary`) to eventually compare
context-creation counts; not run yet (needs the same input/GPU constraints). No shim change; all
instrumentation reverted.

## Audio manager located (2026-10-03)

Traced the title's audio manager chain:
`sub_82B893A0` (manager) -> `sub_82B8B8C0` (dispatch/construct, called with channel count 6) ->
`sub_82B8AC20` (creates one XMA context per voice via `XMACreateContext`) -> `XMACreateContext`.
`sub_82B8B6C0` is the voice teardown (frees a slot in the 320-entry array at `0x83C12330`).

So the manager does intend multiple channels (6), yet only one XMA context is created at runtime.
The deciding input is the voice/channel list the manager walks (`sub_82B893A0` iterates pointers
via `88(r27)` and a linked list at `16256`). Confirming why that list yields one entry needs runtime
inspection, not more static reading. Next step for a real fix: run the same title under Xenia (which
plays audio) and compare how many contexts its XMA decoder is asked to create at the same point;
the divergence will show what the shim answers differently. No speculative shim change was made.

## Audio: shim verified correct; block is the game's own software XMA driver (2026-10-03)

Checked the shim end to end against Xenia: `kContextCount = 320` (matches the guest), `AllocateContext`
returns a real guest pointer, `BitMap::Acquire/Release` are correct, and `WriteRegister` handles
Kick/Lock/Clear exactly like Xenia. The shim is not the bug.

The title imports only `XMACreateContext`/`XMAReleaseContext` (no Enable/Disable/SetBuffer), and its
`sub_82B8AC20`/`sub_82B8B448` drive XMA entirely in software: they fill context structs in guest
memory, `MmMapIoSpace` them, and write context registers. During a career run only **one** XMA
context is created, and the MMIO log shows only `0x7FEA1804` start/end writes, no kick. So the
game's own context sweep finds an empty list and never decodes music; effects play from the one
context.

This means the fix is not a shim change: it depends on why the game's voice list yields a single
context. That is title logic, needs reading the game's audio manager (the list at `0x83C12330` and
the caller chain into `sub_82B8AC20`/`sub_82B8B6C0`). No speculative audio shim was written.
Instrumentation reverted; runtime clean. This is the honest stopping point for the audio session.

## Audio: guest only writes the 0x1804 transaction reg, never a kick (2026-10-03, closed)

Logged the first 200 XMA MMIO writes during a career run. Every write is `0x7FEA1804`
(reg 0x601) alternating `0x02000000`/`0x03000000`, i.e. start/end of the driver's 320-context
sweep. The shim **never** receives a kick (0x650), lock (0x690) or clear (0x6A0) write. So the
guest's context loop has nothing to process: no context ever carries the ready bit it tests, and no
decode is kicked. Combined with the mix buffer flipping silence<->garbage (~9.1e30) every ~10ms, the
music stream decodes uninitialized memory.

Full chain (all verified): the guest creates one XMA context (an effect that audibly plays) and
drives the rest of audio in software (`sub_82B8AC20` / `sub_82B8B448`) by writing context registers
it never actually kicks, because the contexts it expects to iterate are never marked ready. The shim
implements Kick/Lock/Clear registers but they are never hit.

Fix direction (not a one-liner): make the driver's context sweep find ready contexts. Either the
shim must publish contexts as ready (the state the guest tests before its `stwbrx` to 0x650/0x6A0),
or find why the guest's voice list only yields one context. This needs a focused session comparing
against Xenia's XmaContext behaviour. All instrumentation reverted; runtime clean.

## Audio: mix buffer alternates silence and garbage every ~10ms (2026-10-03)

Final measurement: logged silence<->signal transitions on the shared mix buffer. It flips
SILENCE (peak 0) <-> SIGNAL (peak ~9.1e30, a huge non-PCM value) about every 10ms. So the guest
writes uninitialized/garbage floats into the shared stream buffer, alternating with zeros. That is
the signature of decoding reading uninitialized memory, consistent with the XMA context never
being populated for music. Effects play because their one context is set; the music stream feeds
garbage. All instrumentation now reverted; runtime rebuilt clean.

## Audio: single mix stream; music has no XMA context (2026-10-03, next)

The system has a single XAudio client (callback 82BB13A8, buffer 83C12870); music and effects share
one stream. The guest creates only one XMA context (for the effect that plays), so there is no
decoded music to mix. The context-creation loop is `sub_82B8AC20` (called from `sub_82B8B6C0` in
`ocho_kart_recomp.299`) iterating a list at `0(r3)`; only one entry ran, so the music voice never
gets a context.

Next step: find why the voice list only yields one XMA context (why the music/BGM voice is absent),
which is the concrete fix for background music. Reading only, no runtime change yet.

## Audio: gameplay effects work, background music does not (2026-10-03)

User observation while playing: sound plays when the kart crashes/respawns (gameplay effects), but
after the intro cinematic, at the Start menu, there is no music. So the game's XMA path is not
universally dead; effects work.

Instrumented `XmaDecoder::AllocateContext` (INFO). A career run created **exactly one XMA context**
(`id=0 guest=0xFFCA6000`). One context is enough for the effect that plays, but background music
likely needs its own context/stream that never gets created, or goes through the XMP system, whose
playback is unimplemented (`XMPRegisterCodec` stub) and which the title only touches via
Get/SetPlaybackController.

So the remaining audio gap is **background music** specifically, not effects. `SDLAudioDriver::`
`SubmitFrame` still shows the mixed buffer at zero then FLT_MAX garbage, consistent with the music
stream feeding uninitialized data. Instrumentation is local only; the shim log will be reverted.

## Audio measured live: intro works, game buffer is zero then garbage (2026-10-03)

Live test report: audio plays through the intro cinematic, then goes silent once in the menu; the
user completed a full cup (5 races) and 2-player works. So it is not total silence.

Measured `SDLAudioDriver::SubmitFrame` (thread-safe RMS/peak per second):
- first ~9s: `rms=0.0 peak=0.0` (silence)
- then: `peak ≈ 3.4e38` (FLT_MAX) and `rms=nan` every second.

3.4e38 is float overflow/uninitialized memory, not valid samples. So the game's XAudio buffer
(`83C12870`) is all zeros at first and later full of garbage. The audio that is audible in the
intro therefore does **not** come through this buffer (the cinematic has its own track/path); the
game's own mix (menu/effects) is the buffer that is zero/garbage. This ties back to the XMA context
never being initialized: the guest reads uninitialized state and pushes bad floats.

Instrumentation reverted (this time thread-safe: atomic counters, no shared std::set; the earlier
`static std::set` in a multithreaded thunk is what caused the 17:24 double-free crash).

## Heap crash reanalysis: it is D3D12 presenter, not input (2026-10-03)

Re-checked dump `ocho_kart.exe.39732.dmp` (11:31) which had not been looked at before:
`HEAP_CORRUPTION_ACTIONABLE_BlockNotBusy_DOUBLE_FREE` in `ucrtbase!free_base` /
`ntdll!RtlFreeHeap`. Stack: `rexruntimerd+0x121195` <- `rexruntimerd+0x11d581`.

I first assumed this was the InputSystem race because the offsets sat near `+0x1211d1`. objdump
disproves that: `rexruntimerd+0x11d581` is inside `ui::d3d12::D3D12Presenter` (a
`unique_ptr<D3D12Presenter>` destructor), not `RefreshDevices`. So the `0xC0000374` double-free is a
**separate bug in the D3D12 presenter teardown**, not the input race. Correcting the earlier
guess. The input fix does not address this one. A fresh symbolicated stack (matching PDB) is needed;
the current PDB is newer than this dump. Also note the two 17:24-17:25 crashes were from
instrumented runs (a `static std::set` in a multithreaded MMIO thunk is itself unsafe) and are not
worth chasing.

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

1. Audio. **Engine is the blocker (2026-10-03, latest):** the title's own mixer never registers voices
   (`sub_82B893A0` runs 0 times; `sub_82B8B8C0`/`sub_82B8AC20` never called), while the engine tick
   `sub_82B8B448` runs constantly over an empty 320-slot array. XMP is only the ownership handshake
   (`GetPlaybackController` → 0, then `SetPlaybackController(0,1)`), and XMA exports are never called.
   Needs a dedicated engine-debug session to find what the title waits for before building its voice
   list. See the top section. Not a one-line shim change.
   **Fresh-review corrections (2026-10-03):** (a) the shim is *not* line-for-line faithful to Xenia
   (inline kick decode; simplified `Work()`); (b) the title drives XMA by MMIO writing Lock `0x690`
   and Clear `0x6A0`, never Kick `0x650`, and imports only `XMACreateContext`/`XMAReleaseContext`.
   The one decisive measurement still missing: log every XMA `(r,value)` write from boot to a race to
   settle whether any Kick ever arrives. See the new top section.
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
| FSB5 audio parser/extractor | `tools/fsb5/fsb5.cpp` (build `tools/fsb5/build.ps1` → `tools/out/fsb5.exe`) |
| FSB5 decode/play | `tools/fsb5/play.ps1` |
| Host music player (runtime) | `src/audio/host_music.h` + `src/launcher/ocho_kart_app.h` |
| Audio debugger (LLDB + PDBs) | `tools/debug-audio.ps1` + `tools/debug-audio/audio.lldb` (junction `C:\Users\israe\ocho_dump`) |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |
