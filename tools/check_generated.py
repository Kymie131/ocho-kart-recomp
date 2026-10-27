#!/usr/bin/env python3
"""Find recompiled functions that fall off the end of their body.

A function whose last translated instruction is not a return, a branch, a
tail call or a no-return call was cut short: usually a hand-written
[entrypoint.functions] entry in tools/config/ocho_kart_manifest.toml with a
`size` that is too small. Such a function silently returns whatever is left
in r3, e.g. 0x82FBFC38 (size 4 instead of 16) made FMOD's EventSystem::load
return a pointer instead of FMOD_OK and the game ran with no sound.

Usage: python tools/check_generated.py <project>/generated[/default]
Exit code 1 if any function is cut short.
"""
import pathlib
import re
import sys

OK_LAST = re.compile(r"(return|goto|__restgpr|ppc_longjmp|ppc_trap|\w+\(ctx, base\);)")


def scan(root: pathlib.Path):
    bad = []
    for f in sorted(root.glob("*_recomp.*.cpp")):
        cur = last = None
        for line in f.read_text(errors="replace").splitlines():
            m = re.match(r"DEFINE_REX_FUNC\((\w+)\)", line)
            if m:
                cur, last = m.group(1), None
                continue
            if cur and line == "}":
                if last and not OK_LAST.match(last) and "REX_FATAL" not in last:
                    bad.append((cur, f.name, last))
                cur = None
                continue
            s = line.strip()
            if cur and s and not s.startswith("//") and not s.endswith(":"):
                last = s
    return bad


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "generated")
    if not any(root.glob("*_recomp.*.cpp")) and (root / "default").is_dir():
        root = root / "default"
    files = list(root.glob("*_recomp.*.cpp"))
    if not files:
        print(f"no *_recomp.*.cpp under {root}")
        return 2
    bad = scan(root)
    for name, fname, last in bad:
        print(f"CUT SHORT: {name} ({fname}) ends with: {last}")
    print(f"checked {len(files)} files: {len(bad)} function(s) cut short")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
