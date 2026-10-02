# State

Updated 2026-10-02.

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | not started |
| 3 compile recomp C++ | done |
| 4 shaders | not started |
| 5 kernel shims / boot | done (runs stable) |
| 6 renderer | next (no picture yet) |

## Phase 5 result

The game boots and **runs stably** (60s, no fatal). It loads the XEX, registers the recompiled functions, resolves all 307 signed imports, initializes audio, and walks the intro asset sequence (disclaimer, UE3 logo, game logos).

No GPU plugin is loaded, so there is no picture yet — that is Phase 6.

Remaining (non-fatal) warnings: the game probes movie/splash paths (`D:\ChavoKartGame\Movies\*`, `Splash.bmp`) that the VFS does not resolve. Path/device mapping for those assets is pending.

## How the boot was stabilised

Runtime crashed repeatedly with `Call to invalid or unregistered function` on functions that codegen cannot discover because they are reached only through pointers/vtables (never via a `bl`). `tools/peel.ps1` reads each crash address from the boot log, sizes it (next registered function start), appends it to `[entrypoint.functions]`, and reruns codegen+build+boot. Added this way:

```
0x82B3F920 (setter, 8)
0x82A8E828 (16)
0x82A62EE8 (16)
0x82ADB388 (16)
```

Earlier manual entries in the same category are also in the manifest (vtable thunks, getters, veneers).

A bulk alternative (`tools/gen-ptr-funcs.ps1`, scan data sections for code pointers) added 479 entries but produced false positives that broke hundreds of branches, so it was reverted. The directed peel is the working method.

Ironically the additions made earlier this session (before the bulk) were kept because they were verified by the runtime reaching past them.

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` |
| Analysis project + generated C++ + build | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| Prebuilt SDK | `C:\ProgramData\rexglue-sdk-bin` (v0.10.0) |
| ReXGlue analyzer | `C:\ProgramData\rextools\rexglue.exe` v0.10.0 |
| Manifest | `tools/config/ocho_kart_manifest.toml` |
| Build | `tools/build.ps1` |
| Codegen+build+run loop | `tools/boot-loop.ps1` |
| Directed crash peeler | `tools/peel.ps1` |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |

## Next

1. Phase 6: load the GPU plugin / native renderer to get a picture. Then see how far the menu is.
2. Fix the movie/splash path mapping so intro assets load.
3. Phase 2 (UModel catalog) in parallel.
4. Keep `tools/peel.ps1` handy — new code paths may hit more undiscovered pointer functions.
