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
| xam (118 imports) | pending — list in signed table |
| xgi | not imported by this title (D3D9LTCG / XGRAPHC static libs) |
| xmp | static lib v2.0.21250.0, not an import library |

## Done

- (none)

## Notes

- 2026-10-02: import table signed; shims must follow that table, not a generic xboxkrnl export list.
