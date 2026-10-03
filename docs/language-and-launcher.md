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
