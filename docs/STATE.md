# State

Updated 2026-10-06 (second session). This file is the **current** picture only.
The dated session-by-session log up to 2026-10-06 is kept unchanged in
`docs/history/STATE-log-2026-10.md`; where it disagrees with this file, this
file wins (see "Corrections" below).

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done (307/307 imports signed; image sections, setjmp/longjmp, DPC routine located) |
| 2 UE3 catalog | done (all packages are LZX; names/imports/exports decode with `tools/catalog/`) |
| 3 compile recomp C++ | done |
| 4 shaders | partial (Xenos → DXBC at runtime; 101 shaders / 87 pipelines seen in one race) |
| 5 kernel shims / boot | done; boots past the intro with the Xenos GPU plugin |
| 6 renderer | in progress |
| 7 input / audio / stability | input stable; **guest audio silent** (host music covers it); kernel fixes below pending measurement |
| 8 PC options | partial (fullscreen / vsync / resolution scale) |
| 9 CI releases | partial (code-only tooling bundle on tag) |
| 10 contributor docs | done |

## What changed in this session (2026-10-06, b)

All changes are code/config/doc changes made **without running the game** (no
Windows/D3D12 box in that session). Each one is compile-checked or validated
against the dump as stated, and each needs one measured run on the real build.

1. **SDK: `KeInsertQueueDpc` now runs the DPC** (`patches/rexglue-sdk-dpc-dispatch.patch`,
   cvars `kernel_dispatch_dpcs` (default true) and `kernel_trace_dpcs`).
   Upstream v0.10.0 queued the DPC on a list that nothing drains, so the routine
   never ran (its "going to hang" assert compiles out in Release). Now it runs
   inline at DISPATCH_LEVEL, like Xenia Canary, through
   `FunctionDispatcher::ExecuteTrap` so the importing caller's registers are
   restored afterwards. Compiled against v0.10.0 + the local patch set (Linux,
   clang 18 and clang 20).
   - The title has **one** DPC: KeInitializeDpc at `0x82B639BC`, KeInsertQueueDpc
     at `0x82B577A0`, routine **`0x82B63818`**, all inside the statically linked
     **D3D** library (the code around it calls `Vd*`). The routine stores arg1 in
     a ring and `KeSetEvent`s the D3D worker (`sub_82B63670`), which otherwise
     only wakes on its **30 ms** timeout. So this is a GPU-side latency fix, not
     the audio blocker.
   - The routine has no `.pdata` entry and is only reached through the DPC
     object, so it is now listed in `tools/config/ocho_kart_manifest.toml`
     (`d3d_dpc_82B63818_signal`). **Re-run codegen** before building.
2. **SDK: writable `cache:` / `cache0:` / `cache1:`** (`patches/rexglue-sdk-cache-mount.patch`,
   cvar `mount_cache`, default true). Mounted under `<user_data_root>/xbox_cache/`.
   `ObCreateSymbolicLink` now keeps an existing link (and strips `\System??\`),
   like Canary.
   - Why: the title carries the XDK utility-drive / DVD file-cache code
     (`cache:\$cache$\dir`, `cache:\$cache$\spc`, `DvdCache`,
     `\Device\Harddisk0\Cache%u`; imports `StfsCreateDevice`,
     `ObCreateSymbolicLink`, `IoDismountVolume*`, `FscSetCacheElementCount`).
     Upstream deliberately left `cache:` unmounted, so when the title links
     `cache:` itself the link lands on the `\Device\Harddisk0\Cache0` **NullDevice**:
     writes "succeed" and reads return nothing. Xenia mounts real folders there.
     This is one of the few measurable ReXGlue-vs-Xenia differences on this
     title's I/O path; whether it is *the* audio blocker is not proven.
3. **Codegen: `setjmp`/`longjmp` redirected** (`longjmp_address = 0x830BDC90`,
   `setjmp_address = 0x830BDFB0` in the manifest). The title has 7 setjmp and 18
   longjmp call sites; a recompiled longjmp cannot unwind the host stack, so
   without the redirection the first longjmp is undefined behaviour. Identified
   from the decrypted image (register save/restore layout, RtlUnwind on the far
   path). **Re-run codegen.**
   Verified with a full `rexglue codegen` of the real `default.xex` on Linux
   using this manifest (SDK built from the patched submodule): 611 files, no
   warnings, 7 `ppc_setjmp` and 21 `ppc_longjmp` sites emitted, and
   `d3d_dpc_82B63818_signal` registered in `ocho_kart_register.cpp`.
4. **Catalog: LZX, not LZO.** Every compressed `.xxx` is LZX (UE3 flag `0x4`,
   XMemCompress framing). `tools/catalog/ue3lzx.c` + `build.ps1`/`build.sh` build
   a small helper over libmspack's `lzxd.c` (from the vendored submodule) and
   `ue3_catalog.py` now decodes whole-file and chunked packages and prints
   names / imports / exports / export classes. Export tables validate against
   `DependsOffset` on every package tried.
5. **Reproducible SDK build:** `tools/apply-sdk-patches.ps1` (idempotent) and
   `tools/build-sdk.ps1` (patch + build + install to
   `%ProgramData%\rexglue-sdk-ocho`). Before this the runtime was rebuilt by hand.
6. Docs restructured: this file is current-state only; the audio facts are in
   `docs/audio-restart.md`; the history is archived.

## First traced run on the patched build (2026-10-06, 13:56, Windows, Quadro T2000)

Built from scratch with `tools/setup-and-test.ps1` (SDK + 611 generated files),
booted, intro movies, menu, one race on `PistaCiudad_Circuito0`, closed after
~3.5 min. Log: `run-trace-20261006-135620.log` (172 lines, `-Trace`).

- **The menu music the user heard is the host-side player**
  (`host_music: playing 'menu.wav'`), not the game. In the race there were no
  voices, engine or ambience: **guest audio is still silent.**
- **No `.fsbcache` and no `<hash>.xxx` bank was ever requested** — not even a
  failed open — although `FMODAudio.xxx`, `ChavoKartGame.xxx` (the FMOD project),
  the kart packages and `PistaCiudad_Circuito0_Sonidos.xxx` all loaded fine.
  FMOD never asks for a bank, so this is upstream of the VFS.
- **`ObCreateSymbolicLink` was never called** and nothing was written under
  `xbox_cache`: the title did not use the utility/cache partition in this run,
  so the `cache:` mount is not what blocks audio here.
- **`KeInsertQueueDpc` was never called**: the D3D DPC path is not used either.
- No `FATAL`, no unregistered-function trap, no crash; `setjmp`/`longjmp`
  redirection did not break anything.
- Host music never switched to `race.wav`: its menu/race heuristic watches
  FMOD's XMA voice array, which stays empty because FMOD plays nothing.

Working hypothesis now: FMOD's EventSystem (or its Xenon output) fails to
initialise or to load the project under ReXGlue, so no event group ever loads
its bank. Next: find the FMOD `EventSystem::init` / `load` call sites in the
XEX and log their return codes.

## Audio: what the title actually uses (decoded 2026-10-06)

- **FMOD Ex 4.x + FMOD Event + FMOD Music System**, statically linked
  (`fmod_output_xenon.cpp` "FMOD Xenon Output", `fmod_codec_xma.cpp`,
  `fmod_eventsystemi.cpp`, `fmod_musicsystemi.cpp`; threads "FMOD mixer thread",
  "FMOD stream thread", "FMOD file thread", "FMOD nonblocking thread"). The
  "game's own software XMA driver" in the history log (`sub_82B8…`, the
  320-slot array at `0x83C12330`, the `0x601` scribble) is **FMOD's** XMA codec
  pool and Xenon output, not UE3 code and not a bespoke driver.
- The UE3 side is the FMODAudio integration (`UnFMODProject.cpp`,
  `UnFMODMusicSystem.cpp`, `UnFMODLoadingSet.cpp`, ...).
- `ChavoKartGame.xxx` holds `FMODProject CHAVO_KART_FMOD_PROJECT` (the FEV data)
  and **15** `FMODSoundBank` objects, one per `<hash>.fsbcache` in the dump.
- **Menu music** is an FMOD **music cue** (`CHAVO_KART_FMOD_PROJECT_MAIN_THEME`)
  started by **Kismet** (`SeqAct_FMODMusicCueControl_0` in `TitleMap.xxx`), not
  XMP and not a UE3 `SoundCue`. `StartMenu.xxx` resets it
  (`SeqAct_FMODMusicReset_0`).
- Measured earlier and still true: the title opens `FMODAudio.xxx` but never a
  `.fsbcache`; Xenia opens 7 banks. The mixer runs; no voices exist.

So the question is now concrete: **why does FMOD never open a bank under
ReXGlue?** Break on the FMOD project/bank load (the natives behind
`UFMODProject` / `UFMODLoadingSet::execLoad` / `UFMODMusicSystem::execPromptCue`;
their name strings are at `0x8223B24F`–`0x8223B760`), and watch the FMOD threads
above being created.

## Corrections to the history log

| Old statement | Correct |
|---|---|
| Packages are "LZO compressed"; symbol names unreadable | LZX; names decode (`tools/catalog/`). |
| "The runtime has no Bink decoder"; cinematics blocked | Bink is **in the XEX** (sections `BINK`, `BINKCONS`, `BINKDATA`, `BINKBSS`, `RADCODE`) and runs as guest code; the intro, logos and disclaimer already play. `VIDEODEMO.bik` and `*_ESM.bik` are simply not on the disc. |
| "No persistent pipeline cache: `InitializeShaderStorage` is an empty body" | That is the base class. The D3D12 override stores pipeline descriptions in `<cache_root>/shaders/shareable/<title>.*.d3d12.xpso` and pre-creates them at boot (`rex_app.cpp` calls it when `cache_root` is set). Hitches are first-run only; driver PSO blobs are not stored. |
| "The game's own software XMA driver" | FMOD Ex's XMA codec / Xenon output. |
| "XMP is the innermost blocker" | Superseded: the title takes playback ownership itself (FMOD). |
| "12 `.fsbcache` banks" (audio log) | 15 banks. |
| "The title never calls `XMACreateContext`" vs "exactly one context is created" | Both appear in the log from different runs/builds; neither is current. Re-measure on the new build with `xma_trace_writes`. |
| "SoundCue del menú no se dispara" (audio log) | It is an FMOD music cue started by Kismet. |

## Open issues

1. **Guest audio** (see above). Next measurement on the patched build:
   `--kernel_trace_dpcs true`, log `NtCreateFile` for `cache:`/`.fsbcache`, and a
   boot→menu→race with `xma_trace_writes`. Then the guest breakpoints above.
2. **Launcher closes with no input** while unattended. Defensive close-veto in
   place; not reproduced in a 4-minute idle run.
3. **`0xC0000005` in the GPU plugin** seen once; not reproduced on the current build.
4. **D3D12 presenter double free** (`0xC0000374`, `D3D12Presenter` teardown) seen
   once; needs a fresh symbolized dump.
5. **Function discovery**: 28+ functions were peeled by hand. CrownPark's ReXGlue
   fork has a GapFill rewrite and an `unregistered_function_nonfatal` mode worth
   porting (see `docs/prior-art.md`).

## Next

1. `tools/build-sdk.ps1`, then `tools/run-codegen.ps1`, `tools/install-launcher.ps1`,
   `tools/build.ps1 -SdkDir "$env:ProgramData\rexglue-sdk-ocho"`.
2. Boot → menu with `tools/run-game.ps1 -Trace` (DPC, file-open and XMA
   traces; `tools/setup-and-test.ps1` does steps 1-2 and summarises the log);
   confirm the DPC routine `82B63818` runs and nothing regresses (intro, input,
   2-player).
3. Check `<user_data_root>/xbox_cache/` after a run: if the title wrote
   `$cache$` files there, the cache mount is live. Compare with Xenia's
   `cache0`/`cache1`.
4. Watch for a `.fsbcache` open. If none, break on the FMOD natives listed above.
5. If both fixes are neutral for audio, set `kernel_dispatch_dpcs`/`mount_cache`
   back to false only if something regresses; they match Xenia either way.

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` |
| Analysis project + generated C++ + build | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| Patched SDK install | `%ProgramData%\rexglue-sdk-ocho` (`tools/build-sdk.ps1`) |
| Prebuilt upstream SDK | `%ProgramData%\rexglue-sdk-bin` (v0.10.0, unpatched) |
| Manifest | `tools/config/ocho_kart_manifest.toml` |
| SDK patches | `patches/` (apply with `tools/apply-sdk-patches.ps1`) |
| Codegen / build / run | `tools/run-codegen.ps1`, `tools/build.ps1`, `tools/run-game.ps1` |
| Crash peeler | `tools/peel.ps1` |
| FSB5 tool / host music | `tools/fsb5/`, `tools/host-music.ps1`, `src/audio/host_music.h` |
| UE3 catalog | `tools/catalog/` → `docs/ue3-catalog.md` |
| Audio debugger | `tools/debug-audio.ps1` |
| Prior art (other ports) | `docs/prior-art.md` |
