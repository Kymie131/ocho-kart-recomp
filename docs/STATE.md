# State

Updated 2026-10-02.

## Where we are

| Phase | Status |
|---|---|
| 0 bootstrap | done |
| 0.5 dump audit | done |
| 1 xex analysis | done |
| 2 UE3 catalog | not started |
| 3 compile recomp C++ | **done** — compiles, links, starts |
| 4 shaders | not started |
| 5 kernel shims / boot | **in progress** — boot advances each round, not yet to menu |

## Phase 3 result

Codegen sealed 73228/73228 functions. Built with clang 23.1.1 + Ninja against the prebuilt ReXGlue SDK 0.10.0. Linked `ocho_kart.exe` (110 MB) at
`%ProgramData%\rextools\proj-ocho-kart\out\build\win-amd64\ocho_kart.exe`. Fix needed: `src/main.cpp` include path (`generated/ocho_kart_init.h`).

## Phase 5 progress (boot loop)

Run with `--game_data_root <dump>`. The runtime boots, mounts the dump at `game:`, loads the XEX, registers 73522 recompiled functions, resolves all 307 signed imports, and executes the game's init. It then dies on:

```
[FATAL] Call to invalid or unregistered function at guest address 0x........
```

### Root cause found

A class of functions is **not discovered by codegen** because it is only reachable through function pointers / vtables (not via any `bl`). Examples: adjustor thunks (`addi r3,r3,-4; b target`), vtable dispatch stubs (`lwz r11,0(r3); lwz r11,off(r11); mtctr r11; bctr`), small getters (`lwz r3,0x18(r3); blr`), and whole methods.

These must be declared in `[entrypoint.functions]`. Each round peels one and the boot advances. Peeled so far (see manifest): `0x82BAEEB8`, `0x82B8AA00/10/18/20`, `0x82405808`, `0x830F6C58`, `0x832431B0`, `0x83243268`, `0x82928C08`, `0x82B186B8`. Last crash: `0x82B3F920`.

Sizing rule that works: **end = next already-registered function start**; do not declare big spans (they swallow sub-functions that are also pointer targets).

### Tools

- `tools/boot-loop.ps1` — sync manifest, codegen, build, run, print tail.
- `tools/peel.ps1` — read last crash address, size it, append, loop (has a known double-run bug; fix before relying on it).

### Boot sequence reached (log evidence)

Filesystem probes for `UPDATE:\`, `D:\Binaries\EpicInternal.txt`, `Splash.bmp`, then the movie list (`VIDEODEMO.bik`, `LOGO_*.xxx`, `INTRO.xxx`). So the game is well into startup before the first missing function.

## Paths

| Thing | Where |
|---|---|
| User dump | local `EL CHAVO KART/default.xex` (set at codegen time) |
| Analysis project + generated C++ + build | `%ProgramData%\rextools\proj-ocho-kart\` (not in git) |
| Prebuilt SDK (link target) | `C:\ProgramData\rexglue-sdk-bin` (v0.10.0) |
| ReXGlue analyzer | `C:\ProgramData\rextools\rexglue.exe` v0.10.0 |
| Manifest | `tools/config/ocho_kart_manifest.toml` |
| Signed imports | `docs/toolchain/xex-imports-signed.md` |

## Blockers

- **Undiscovered pointer-reachable functions.** Manual peeling works but is slow (~4-5 min/round) and the count is unknown. Options: (a) keep peeling; (b) investigate why ReXGlue's VTableScanner misses these (possibly UE3 custom RTTI or a gap region) and fix discovery in bulk.
- GPU not loaded (`gpu_plugin not set`) — expected in native-render mode; Phases 4/6.

## Next

1. Decide peeling vs discovery fix (see Blockers).
2. If peeling: fix `tools/peel.ps1` double-run, run N rounds unattended, watch for the menu.
3. Phase 2 (UModel catalog) can run in parallel.
