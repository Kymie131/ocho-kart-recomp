# SDK patches

These are diffs against the vendored `external/rexglue-sdk` submodule. The
submodule is kept dirty on purpose while the changes are upstreamed; the patch is
the source of truth for what this project adds.

Apply from the submodule root:

```
git -C external/rexglue-sdk apply ../../patches/<file>.patch
```

| Patch | What |
|---|---|
| `rexglue-sdk-local-all.patch` | Consolidated snapshot of every local change: Downpour XMA/audio port (`xma_context.cpp`, `xma_decoder.cpp`, `audio_system.cpp`, `downmix.*`, `conversion.h`, SDL driver), the `InputSystem` lock rework, the `launcher_button_icons` / `launcher_skip` cvars, and the XMA audio-xma tweak. |
| `rexglue-sdk-input-refreshdevices-race.patch` | The focused `InputSystem::RefreshDevices` race fix (upstream issue rexglue/rexglue-sdk#475). Subset of the consolidated patch. |
| `rexglue-sdk-xma-trace-and-lock-decode.patch` | Temporary XMA diagnostics (`xma_trace_writes`, `xma_lock_decodes`); default off. Kept for the audio investigation. |

`rexglue-sdk-local-all.patch` is regenerated from the current submodule state;
prefer it when rebuilding a clean checkout.
