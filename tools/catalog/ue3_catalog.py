#!/usr/bin/env python3
"""UE3 package catalog for El Chavo Kart (Xbox 360).

Reads the cooked .xxx package headers directly (never the game content) and
reports the package version, tables and name map. This is the Phase 2
class-level catalog: it names the packages and their symbol counts without
extracting or shipping any asset bytes.

Xbox 360 cooked UE3 packages are big-endian (FSB5 banks are little-endian; this
tool is only for .xxx). The header follows UELib's PackageFileSummary for UE3:
Tag uint32, Version|Licensee packed in one uint32, HeaderSize int32 (>= v224?),
FolderName FString (>= v200?), PackageFlags uint32, NameCount/NameOffset,
ExportCount/ExportOffset, ImportCount/ImportOffset, DependsOffset, ... Only the
fields needed to reach the name map are read.

Usage:
  python tools/catalog/ue3_catalog.py <pkg.xxx> [--names] [--limit N]
  python tools/catalog/ue3_catalog.py --dir "<dump>/ChavoKartGame/CookedXbox360" --md out.md
"""

import argparse
import os
import struct
import sys

TAG = 0x9E2A83C1

# UE3 object versions at which summary fields appear (see UELib PackageObjectLegacyVersion).
V_ADDED_TOTAL_HEADERSIZE = 224
V_ADDED_FOLDER_NAME = 200
V_ADDED_DEPENDS = 207


def read_int(data, off, be=True):
    return int.from_bytes(data[off:off + 4], "big" if be else "little", signed=True)


def read_uint(data, off, be=True):
    return int.from_bytes(data[off:off + 4], "big" if be else "little", signed=False)


def read_u16(data, off, be=True):
    return int.from_bytes(data[off:off + 2], "big" if be else "little", signed=False)


def read_fstring(data, off, be=True):
    """UE3 FString: int32 length + bytes (ANSI, null-terminated) or -len UTF-16."""
    ln = read_int(data, off, be)
    off += 4
    if ln < 0:
        n = -ln
        raw = data[off:off + n * 2]
        off += n * 2
        s = raw.decode("utf-16-be" if be else "utf-16-le", errors="replace")
    else:
        raw = data[off:off + ln]
        off += ln
        s = raw.split(b"\x00", 1)[0].decode("latin-1")
    return s.rstrip("\x00"), off


class Package:
    def __init__(self):
        self.version = 0
        self.licensee = 0
        self.header_size = 0
        self.folder = ""
        self.flags = 0
        self.name_count = 0
        self.name_offset = 0
        self.export_count = 0
        self.export_offset = 0
        self.import_count = 0
        self.import_offset = 0
        self.names = []
        self.compressed = False
        self.error = ""


def parse(path):
    pkg = Package()
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        pkg.error = str(e)
        return pkg

    if len(data) < 32 or read_uint(data, 0) != TAG:
        pkg.error = "not a UE3 package (bad tag)"
        return pkg

    # Whole-package LZO container: tag then BlockSize 0x00020000 (the real
    # summary is inside the first compressed block). We do not decode LZO here.
    if read_uint(data, 4) == 0x00020000:
        pkg.compressed = True
        pkg.error = "LZO compressed container (summary not decoded)"
        return pkg

    off = 4
    v = read_uint(data, off)  # Version | Licensee in one BE uint32
    off += 4
    pkg.version = v & 0xFFFF
    pkg.licensee = (v >> 16) & 0xFFFF
    if pkg.version == 0:
        pkg.error = "unreadable summary (compressed?)"
        return pkg

    if pkg.version >= V_ADDED_TOTAL_HEADERSIZE:
        pkg.header_size = read_int(data, off)
        off += 4
    if pkg.version >= V_ADDED_FOLDER_NAME:
        pkg.folder, off = read_fstring(data, off)

    pkg.flags = read_uint(data, off)
    off += 4
    # PackageFlag::Compressed / Unversioned bits (UE3).
    pkg.compressed = bool(pkg.flags & (0x00000004 | 0x00002000))

    pkg.name_count = read_int(data, off)
    pkg.name_offset = read_int(data, off + 4)
    off += 8
    pkg.export_count = read_int(data, off)
    pkg.export_offset = read_int(data, off + 4)
    off += 8
    pkg.import_count = read_int(data, off)
    pkg.import_offset = read_int(data, off + 4)

    # Cooked Xbox 360 packages store the name map inside an LZO chunk, so the
    # offset usually does not point at plain FStrings. Only expose the map when
    # it decodes cleanly and starts with the universal first name "None".
    if 0 <= pkg.name_offset < len(data) and pkg.name_count > 0:
        p = pkg.name_offset
        raw_names = []
        ok = True
        for _ in range(pkg.name_count):
            if p >= len(data):
                ok = False
                break
            try:
                name, p = read_fstring(data, p)
            except Exception:
                ok = False
                break
            raw_names.append(name)
        if ok and raw_names and raw_names[0] == "None" and len(raw_names) == pkg.name_count:
            pkg.names = raw_names
        else:
            pkg.compressed = True
    return pkg


def iter_packages(path, recursive=False):
    if os.path.isdir(path):
        for root, _dirs, files in os.walk(path):
            for name in files:
                if name.lower().endswith(".xxx"):
                    yield os.path.join(root, name)
            if not recursive:
                break
    else:
        yield path


def main():
    ap = argparse.ArgumentParser(description="UE3 package catalog")
    ap.add_argument("package", nargs="?", help="package path or directory")
    ap.add_argument("--dir", dest="directory", help="directory of .xxx packages")
    ap.add_argument("--recursive", action="store_true")
    ap.add_argument("--names", action="store_true", help="print the name map")
    ap.add_argument("--limit", type=int, default=0, help="limit names printed (0 = all)")
    ap.add_argument("--md", help="write a markdown table to this file")
    args = ap.parse_args()

    target = args.directory or args.package
    if not target:
        ap.error("pass a package or --dir")
    if not os.path.exists(target):
        ap.error(f"not found: {target}")

    results = []
    for path in sorted(iter_packages(target, args.recursive)):
        pkg = parse(path)
        results.append((path, pkg))

    md_lines = ["| Package | Version | Licensee | Names | Exports | Imports | Compressed |",
                "|---|---|---|---|---|---|---|"]
    for path, pkg in results:
        name = os.path.basename(path)
        if pkg.error:
            md_lines.append(f"| {name} | - | - | - | - | - | {pkg.error} |")
            continue
        md_lines.append(
            f"| {name} | {pkg.version} | {pkg.licensee} | {pkg.name_count} | "
            f"{pkg.export_count} | {pkg.import_count} | {'yes' if pkg.compressed else 'no'} |")

    if args.md:
        with open(args.md, "w", encoding="utf-8") as f:
            f.write("# UE3 package catalog\n\n")
            f.write("Generated by `tools/catalog/ue3_catalog.py` from the user's own dump.\n")
            f.write("Text only: versions, table counts and symbol counts, no asset bytes.\n\n")
            f.write("\n".join(md_lines) + "\n")
        print(f"wrote {args.md} ({len(results)} packages)")

    if not args.md or args.names:
        for path, pkg in results:
            name = os.path.basename(path)
            if pkg.error:
                print(f"{name}: {pkg.error}")
                continue
            print(f"{name}: v{pkg.version}/{pkg.licensee} names={pkg.name_count} "
                  f"exports={pkg.export_count} imports={pkg.import_count} "
                  f"folder='{pkg.folder}' compressed={'yes' if pkg.compressed else 'no'}")
            if args.names:
                names = pkg.names if not args.limit else pkg.names[:args.limit]
                for n in names:
                    print(f"  {n}")


if __name__ == "__main__":
    sys.exit(main())
