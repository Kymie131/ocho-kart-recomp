# Kernel shims

Status table for Xbox 360 kernel/XAM calls the title actually imports. Source of truth: `docs/toolchain/xex-imports-signed.md` (307 entries, retail ordinals).

Implement against Free60 / Xenia. Do not mix OpenXDK ordinal numbering.

## Priority (seen in IAT, high traffic)

| Lib | Ord | Name | Area |
|---|---|---|---|
| xboxkrnl | 9 | ExAllocatePool | heap |
| xboxkrnl | 10 | ExAllocatePoolWithTag | heap |
| xboxkrnl | 15 | ExFreePool | heap |
| xboxkrnl | 157 | KeSetEvent | threads |
| xboxkrnl | 210 | NtCreateFile | fs |
| xboxkrnl | 240 | NtReadFile | fs |
| xboxkrnl | 255 | NtWriteFile | fs |
| xam | 401 | XamInputGetState | pad |
| xam | 490 | XamAlloc | heap |
| xam | 528 | XamUserGetSigninState | profile |
| xam | 601 | XamContentCreateEx | save |

## Xam / Xgi / Xmp

| Group | Status |
|---|---|
| xam (118 imports) | served by ReXGlue's XAM; see the signed table |
| xgi | not imported by this title (D3D9LTCG / XGRAPHC static libs) |
| xmp | static lib v2.0.21250.0, not an import library; the title calls `XMPSetPlaybackController` to take playback itself |

## Done (local changes on top of ReXGlue v0.10.0)

All carried by `patches/rexglue-sdk-local-all.patch`.

| Area | Change | Patch / cvar | Measured |
|---|---|---|---|
| Input | `InputSystem` entry points serialized with one recursive mutex (fixes the `RefreshDevices` heap race) | `rexglue-sdk-input-refreshdevices-race.patch`, upstream #475 | yes: two long runs, no AV |
| Threading | `KeInsertQueueDpc` runs the DPC routine inline at DISPATCH_LEVEL (was queued and never run) | `rexglue-sdk-dpc-dispatch.patch`, `kernel_dispatch_dpcs`, `kernel_trace_dpcs` | compiled only |
| VFS | writable `cache:`/`cache0:`/`cache1:` under `<user_data_root>/xbox_cache`; `ObCreateSymbolicLink` keeps existing links, strips `\System??\` | `rexglue-sdk-cache-mount.patch`, `mount_cache` | compiled only |
| Audio | Downpour's XMA/audio port, downmix, SDL driver changes | consolidated patch | runs; no effect on the silent mixer |
| Audio (diag) | `xma_trace_writes`, `xma_lock_decodes` (default off) | `rexglue-sdk-xma-trace-and-lock-decode.patch` | yes |
| Launcher | `launcher_skip`, `launcher_button_icons` | consolidated patch | yes |

## Known stubs this title reaches

| Import | Upstream behaviour | Note |
|---|---|---|
| `StfsCreateDevice` / `StfsControlDevice` | stub, success | utility-drive mount; harmless once `cache:` is pre-mounted |
| `IoDismountVolume*` | stub, success | |
| `FscSetCacheElementCount` | success | |
| `XMPRegisterCodec` | stub | the title owns playback (FMOD); XMP is only the ownership handshake |

## Notes

- 2026-10-02: import table signed; shims must follow that table, not a generic xboxkrnl export list.
