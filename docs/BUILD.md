# Building and running

This repo is the notes, shims, launcher and tooling for the recompilation. The
recompiled C++ is generated locally from **your own** `default.xex` and is not
committed. Nothing here ships game content.

## What you need

- Windows 10/11 x64.
- El Chavo Kart (Xbox 360) dump on disk (the folder that contains `default.xex`).
  You must own the game; do not upload or share it.
- Visual Studio 2022 **Build Tools** (MSVC headers; no IDE needed).
- LLVM/Clang (the built-in VS clang works), Ninja, CMake 3.25+.
- The ReXGlue toolkit: `rexglue.exe` v0.10.0. The game must link against the
  **patched** SDK built from `external/rexglue-sdk` (step 0 below); the upstream
  prebuilt `rexglue-sdk-bin` lacks this repo's kernel fixes.
- Python 3.10+ (optional) for the UE3 catalog.
- (Optional) FFmpeg on `PATH` for the host-side music extraction.

## Layout on disk

| Thing | Default path |
|---|---|
| Your dump | anywhere, e.g. `...\EL CHAVO KART\default.xex` |
| Analysis project (generated C++) | `%ProgramData%\rextools\proj-ocho-kart` |
| Patched SDK (built here) | `%ProgramData%\rexglue-sdk-ocho` |
| Upstream prebuilt SDK (unpatched) | `%ProgramData%\rexglue-sdk-bin` |
| ReXGlue analyzer | `%ProgramData%\rextools\rexglue.exe` (or the one installed by step 0) |

The analysis project is created by `rexglue` once; afterwards this repo drives it
via `tools/`.

## First build

0. Build the patched SDK once (and after every change in `patches/`):
   ```
   git submodule update --init --recursive
   powershell -File tools/build-sdk.ps1
   ```
   It applies `patches/rexglue-sdk-local-all.patch` to the submodule (idempotent)
   and installs runtime + `rexglue.exe` to `%ProgramData%\rexglue-sdk-ocho`.
1. Codegen from your dump into the analysis project:
   ```
   powershell -File tools/run-codegen.ps1
   ```
   It reads `tools/config/ocho_kart_manifest.toml`, substitutes your dump path,
   and runs `rexglue codegen`.
2. Deploy the launcher (source of truth lives here):
   ```
   powershell -File tools/install-launcher.ps1
   ```
3. Build against the patched SDK:
   ```
   powershell -File tools/build.ps1 -SdkDir "$env:ProgramData\rexglue-sdk-ocho"
   ```

Re-run codegen whenever `tools/config/ocho_kart_manifest.toml` changes (it
carries the `setjmp`/`longjmp` redirection and hand-registered functions).

## Run

```
powershell -File tools/run-game.ps1
```

This launches `ocho_kart.exe --gpu_plugin xenos --user_language 5`. The Xenos
GPU plugin is required for a picture. The pre-boot launcher lets you pick the
language, controller icons, video options, and host music.

Headless/skip the launcher with `REX_LAUNCHER_SKIP=true`.

Runtime switches added by this repo's SDK patches (all match Xenia Canary):

| Cvar | Default | What |
|---|---|---|
| `kernel_dispatch_dpcs` | true | run `KeInsertQueueDpc` routines (upstream never ran them) |
| `kernel_trace_dpcs` | false | log every queued DPC |
| `mount_cache` | true | writable `cache:`/`cache0:`/`cache1:` under `<user data>/xbox_cache` |
| `xma_trace_writes` / `xma_lock_decodes` | false | XMA diagnostics |

## Host-side background music

The title's guest audio mixer is silent upstream (see `docs/STATE.md`), so the
runtime can play the dump's own FSB music on the host. Extract ready-to-play
tracks once (needs FFmpeg):

```
powershell -File tools/host-music.ps1
```

It writes `menu.wav` / `race.wav` into `<dump>/host_music`. The launcher then
defaults the **Background music (host)** toggle on. Launch with
`--host_music true` for a headless run.

## Asset catalog (Phase 2)

The cooked packages are LZX-compressed. Build the small decoder once (needs
the submodule; uses libmspack's `lzxd.c` from it):

```
powershell -File tools/catalog/build.ps1      # -> tools/out/ue3lzx.dll
sh tools/catalog/build.sh                      # Linux/macOS
```

Then (text only, no asset bytes):

```
python tools/catalog/ue3_catalog.py --dir "<dump>/ChavoKartGame/CookedXbox360" --md docs/ue3-catalog.md
python tools/catalog/ue3_catalog.py "<dump>/.../FMODAudio.xxx" --exports
python tools/catalog/ue3_catalog.py --dir "<dump>/.../CookedXbox360" --classes
```

Without the helper the tool still prints the plain summaries (counts only).

## Tests / CI

`.github/workflows/build-*.yml` build the repo scaffolding on Windows and Linux;
`release.yml` packages the code-only tooling on a tag. The game binary itself is
always built locally against your dump.
