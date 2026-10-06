# SDK patches

These are diffs against the vendored `external/rexglue-sdk` submodule. The
submodule is kept dirty on purpose while the changes are upstreamed; the patch is
the source of truth for what this project adds.

Apply with `tools/apply-sdk-patches.ps1` (idempotent; applies the consolidated
patch), or by hand from the repo root:

```
git -C external/rexglue-sdk apply ../../patches/rexglue-sdk-local-all.patch
```

All patches are made against upstream v0.10.0 (`c94f5eb`) and each one applies
cleanly to it on its own. Apply **either** the consolidated patch **or** the
focused ones, never both.

| Patch | What |
|---|---|
| `rexglue-sdk-local-all.patch` | Consolidated snapshot of every local change: Downpour XMA/audio port (`xma_context.cpp`, `xma_decoder.cpp`, `audio_system.cpp`, `downmix.*`, `conversion.h`, SDL driver), the `InputSystem` lock rework, the `launcher_button_icons` / `launcher_skip` cvars, the XMA audio-xma tweak, DPC dispatch and the `cache:` mount. |
| `rexglue-sdk-dpc-dispatch.patch` | `KeInsertQueueDpc` runs the routine inline at DISPATCH_LEVEL like Xenia Canary (upstream queued it and never ran it). Cvars `kernel_dispatch_dpcs` (true), `kernel_trace_dpcs` (false). Subset of the consolidated patch; candidate for upstream. |
| `rexglue-sdk-file-open-trace.patch` | Cvar `trace_file_opens` (false): logs every `NtCreateFile`/`NtOpenFile`/`NtQueryFullAttributesFile` path and result at info level, for the "does FMOD ever open a bank" measurement. Subset of the consolidated patch. |
| `rexglue-sdk-cache-mount.patch` | Writable `cache:`/`cache0:`/`cache1:` under `<user_data_root>/xbox_cache` (cvar `mount_cache`, true) and `ObCreateSymbolicLink` keeping existing links / stripping `\System??\`, like Canary. Subset of the consolidated patch; candidate for upstream. |
| `rexglue-sdk-input-refreshdevices-race.patch` | The focused `InputSystem::RefreshDevices` race fix (upstream issue rexglue/rexglue-sdk#475). Subset of the consolidated patch. |
| `rexglue-sdk-xma-trace-and-lock-decode.patch` | Temporary XMA diagnostics (`xma_trace_writes`, `xma_lock_decodes`); default off. Kept for the audio investigation. |

`rexglue-sdk-local-all.patch` is regenerated from the current submodule state;
prefer it when rebuilding a clean checkout.

## Regenerating

Write patches with git itself, never with PowerShell `>` (that produces UTF-16 +
CRLF, which `git apply` rejects; `rexglue-sdk-input-refreshdevices-race.patch`
was in that state until 2026-10-06):

```
git -C external/rexglue-sdk diff --output=../../patches/rexglue-sdk-local-all.patch
```

CI (`build-linux.yml`, job `tooling`) checks that every patch here applies to
the pinned submodule.
