# Contributing

Read `docs/roadmap.md` (phases) and `docs/STATE.md` (current state).

## Setup

Install the asset-blocking git hook (once per clone):

```
git config core.hooksPath scripts/hooks        # bash
powershell -File scripts/install-hooks.ps1     # windows
```

## Rules

- **Never commit game assets** (`.xex`, `.xxx`, `.upk`, ISO, textures, audio, video, bytecode). Check `git diff --cached` before every commit.
- This repository never ships game content. Each user supplies their own legal dump.
- No affiliation with Microsoft, Xbox, Epic, Efecto Studios, Televisa, or Grupo Chespirito.
- One phase per branch (`phase/0x-name`). Atomic commits with a real message (`fix: jump table at 0x82012340`).
- Binary-analysis config goes in `tools/config/`. RE notes go in `docs/reversing-notes.md`. Shim status goes in `docs/kernel-shims.md`.
- Do not invent build or test results. If something was not run, say so.
- Legal or architecture questions: open an issue and wait.

## Flow

1. Branch from `main`: `git checkout -b phase/0X-name`
2. Commit the change
3. CI in `.github/workflows/` must pass
4. Open a PR: what changed, how you checked it, assumptions made
