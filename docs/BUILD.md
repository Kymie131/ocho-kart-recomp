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
- The ReXGlue toolkit: `rexglue.exe` v0.10.0 and either the prebuilt SDK package
  (`rexglue-sdk-bin`) or the initialized `external/rexglue-sdk` submodule.
- (Optional) FFmpeg on `PATH` for the host-side music extraction.

## Layout on disk

| Thing | Default path |
|---|---|
| Your dump | anywhere, e.g. `...\EL CHAVO KART\default.xex` |
| Analysis project (generated C++) | `%ProgramData%\rextools\proj-ocho-kart` |
| Prebuilt SDK | `%ProgramData%\rexglue-sdk-bin` |
| ReXGlue analyzer | `%ProgramData\rextools\rexglue.exe` |

The analysis project is created by `rexglue` once; afterwards this repo drives it
via `tools/`.

## First build

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
3. Build:
   ```
   powershell -File tools/build.ps1 -SdkSourceDir "external/rexglue-sdk"
   ```
   Building from source applies this repo's keyboard-input defaults. The normal
   prebuilt-SDK path remains available with `powershell -File tools/build.ps1`.

## Run

```
powershell -File tools/run-game.ps1
```

This launches `ocho_kart.exe --gpu_plugin xenos --user_language 5`. The Xenos
GPU plugin is required for a picture. The pre-boot launcher lets you pick the
language, controller icons, keyboard controls, video options, and host music.
Keyboard controls are enabled by default: W/S accelerate/brake, A/D steer,
Space=A, Backspace=B, E/Q=X/Y, R/F=shoulders, Enter=Start, Tab=Back. The
in-game `Input/Keybinds/Controller` settings can remap them.

Headless/skip the launcher with `REX_LAUNCHER_SKIP=true`.

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

Inventory and class-level counts (text only, no asset bytes):

```
python tools/catalog/ue3_catalog.py --dir "<dump>/ChavoKartGame/CookedXbox360" --md docs/ue3-catalog.md
```

## Tests / CI

`.github/workflows/build-*.yml` build the repo scaffolding on Windows and Linux;
`release.yml` packages the code-only tooling on a tag. The game binary itself is
always built locally against your dump.
