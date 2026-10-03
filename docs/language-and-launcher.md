# Language and launcher design

Notes for the eventual PC launcher (options menu, language, input devices). No game
assets are referenced by path here beyond what the title itself requests.

## How the title handles language

On Xbox 360 the language belongs to the console, not the game. The title asks the
kernel and then loads the matching localization set:

1. The game calls `ExGetXConfigSetting(XCONFIG_USER, XCONFIG_USER_LANGUAGE)`.
2. The kernel returns an `XLanguage` value (`1` English, `2` Japanese, `5` Spanish,
   `9` Portuguese).
3. The runtime answers that call from the `user_language` cvar
   (`src/kernel/xboxkrnl/xboxkrnl_xconfig.cpp`, setting `0x0009`). Default is `1`.
4. The title then loads `Coalesced_<code>.bin` and `ChavoKartGame_LOC_<code>.xxx`
   for that code.

The dump ships `Coalesced_ESM/ESN/INT/PTB.bin` and `ChavoKartGame_LOC_ESM/ESN/INT/PTB.xxx`:

| Code | Meaning |
|---|---|
| ESM | Spanish (Mexico). The one to default to for Latin America. |
| ESN | Spanish (neutral). |
| INT | International (English base). |
| PTB | Portuguese (Brazil). |

The game has no in-game language menu because the 360 dashboard played that role.

## What the launcher should do

The launcher replaces the dashboard, so it owns the selector:

- Show a language dropdown with the codes the title actually ships (ESM, ESN, INT, PTB).
- Map the choice to `user_language` and pass it before boot (`--user_language N`).
- Persist the choice in user data, never in the dump.
- The launcher's own UI needs its own i18n table (the SDK has none); keep it separate
  from the game language.

Default for this project: Spanish (Mexico), `user_language 5`.

## Caveats

- `user_language` selects localization content that exists. It does not create audio or
  text the studio never recorded or wrote for a region.
- Language does not fix missing assets. Cinematics (`Movies/*_ESM.bik`) and some
  localized files still fail to resolve in the VFS; that is path mapping work, separate
  from the language selector.
- Region / AV setup (`XCONFIG_SECURED_AV_REGION`) is a different axis; do not fold it
  into the language control unless a specific need appears.

## Input devices

Multiple backends already exist in the runtime (`sdl`, `xinput`, plus a keyboard/mouse
driver and a NOP stand-in), selected by the `input_backend` cvar. A launcher device
selector should expose that cvar and let the SDL driver handle the wide hardware range,
rather than adding per-device code.

## Launcher implementation

The pre-boot launcher lives in `src/launcher/ocho_kart_app.h` and is deployed into the
analysis project by `tools/install-launcher.ps1`. It overrides
`rex::ReXApp::OnFinalizePaths`, returns `std::nullopt` to pause startup, and shows an
ImGui dialog (language, controller icons, game folder, Play/Quit). Play applies
`user_language` and `launcher_button_icons`, saves the config, and calls the resume
callback with the chosen `game_data_root`, which lets the XEX load.

Notes:

- `OnFinalizePaths` is the runtime's documented async wizard hook; the event loop keeps
  drawing while it is paused, so no thread needs to block.
- Codegen writes `src/<name>_app.h` once (`RegeneratePolicy::FirstInitOnly`) and then
  preserves it, so the file here is the source of truth and the script re-deploys it.
- Options persist through `rex::cvar::SaveConfig` / `LoadConfig` at the path in
  `PathConfig::config_path` (next to the exe).
- Verified live: the dialog appears, the game waits for Play, Play boots the XEX, Quit
  exits, and the chosen language changes the in-game text.
- The launcher draws its own button prompt preview (Xbox, PlayStation, Nintendo) with the
  ImGui draw list, no game assets. Nintendo uses its swapped face layout.
- Still to do: the in-game prompts are baked into the game's assets, so the setting only
  changes the launcher preview today. Making the game itself show PS/Nintendo glyphs would
  need UI interposition or asset replacement (the latter is not allowed), the same hard
  problem Unleashed Recompiled only solved for PlayStation.
