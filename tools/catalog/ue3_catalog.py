#!/usr/bin/env python3
"""UE3 package catalog for El Chavo Kart (Xbox 360).

Reads the cooked .xxx package headers from the user's own dump and reports the
package summary, name map, import table and export table (symbol names and
class names only; no asset bytes, no bytecode).

Compression (verified 2026-10-06 against the dump):
  * Every package uses LZX (UE3 ECompressionFlags 0x4 = COMPRESS_LZX), the
    Xbox 360 XMemCompress codec - not LZO (0x2) as earlier notes said.
  * "Fully compressed" packages (the ones shipped with a `.uncompressed_size`
    sibling, e.g. Core/Engine/FMODAudio/Startup) are one FArchive::
    SerializeCompressed stream: Tag, BlockSize, {CompressedSize,
    UncompressedSize}, one {CompressedSize, UncompressedSize} per block, then
    the blocks.
  * The other packages have a plain summary whose CompressedChunks table maps
    uncompressed ranges to compressed streams laid out the same way.

LZX blocks are decoded by the small helper library built from ue3lzx.c
(tools/catalog/build.ps1 or build.sh -> tools/out/ue3lzx.dll /
libue3lzx.so). Without it the tool still prints what the plain summaries give
(counts only), exactly like before.

Layout notes for this build (summary v860, licensee 0, engine 10246, cooker
136): name entries are FString + uint64 flags; imports are 28 bytes
(ClassPackage, ClassName, Outer, ObjectName); exports are 68 bytes (Class,
Super, Outer, ObjectName, Archetype, ObjectFlags u64, SerialSize,
SerialOffset, ExportFlags, NetObjectCount array, Guid, PackageFlags; no
ComponentMap).
The export table is checked against DependsOffset before it is trusted.

Usage:
  python tools/catalog/ue3_catalog.py <pkg.xxx> [--names] [--imports] [--exports] [--limit N]
  python tools/catalog/ue3_catalog.py --dir "<dump>/ChavoKartGame/CookedXbox360" --md docs/ue3-catalog.md
  python tools/catalog/ue3_catalog.py --dir ... --classes   # export classes per package
"""

import argparse
import ctypes
import os
import struct
import sys

TAG = 0x9E2A83C1
COMPRESS_ZLIB = 0x1
COMPRESS_LZO = 0x2
COMPRESS_LZX = 0x4

# UE3 object versions at which summary fields appear.
V_ADDED_TOTAL_HEADERSIZE = 249
V_ADDED_FOLDER_NAME = 269
V_ADDED_DEPENDS = 415
V_ADDED_IMPORT_EXPORT_GUIDS = 623
V_ADDED_THUMBNAILS = 584
V_ADDED_NET_OBJECT_COUNT = 322
V_ADDED_COOKER_VERSION = 277
V_ADDED_COMPRESSION = 334
V_ADDED_ARCHETYPE = 220

_LZX = None
_LZX_TRIED = False


def _load_lzx():
    global _LZX, _LZX_TRIED
    if _LZX_TRIED:
        return _LZX
    _LZX_TRIED = True
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(os.path.dirname(here), "out")
    candidates = [os.environ.get("UE3LZX_LIB", "")]
    for name in ("ue3lzx.dll", "libue3lzx.so", "libue3lzx.dylib"):
        candidates.append(os.path.join(out, name))
    for path in candidates:
        if path and os.path.isfile(path):
            try:
                lib = ctypes.CDLL(path)
                fn = lib.ue3_lzx_decompress
                fn.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
                fn.restype = ctypes.c_int
                _LZX = fn
                break
            except OSError:
                continue
    return _LZX


class DecodeError(Exception):
    pass


def lzx_decompress(block, out_size):
    fn = _load_lzx()
    if fn is None:
        raise DecodeError("LZX helper not built (run tools/catalog/build.ps1 or build.sh)")
    buf = ctypes.create_string_buffer(out_size)
    rc = fn(block, len(block), buf, out_size)
    if rc != 0:
        raise DecodeError(f"LZX decode failed ({rc})")
    return buf.raw


def u32(data, off):
    return struct.unpack_from(">I", data, off)[0]


def i32(data, off):
    return struct.unpack_from(">i", data, off)[0]


def decompress_stream(data, off, flags=COMPRESS_LZX):
    """Decode one SerializeCompressed stream starting at `off`. Returns bytes."""
    if u32(data, off) != TAG:
        raise DecodeError(f"no compressed-stream tag at {off:#x}")
    block_size = u32(data, off + 4)
    total_uncompressed = u32(data, off + 12)
    if block_size == 0:
        raise DecodeError("zero block size")
    count = (total_uncompressed + block_size - 1) // block_size
    table = off + 16
    pos = table + count * 8
    out = bytearray()
    for i in range(count):
        csize = u32(data, table + i * 8)
        usize = u32(data, table + i * 8 + 4)
        block = bytes(data[pos:pos + csize])
        if flags & COMPRESS_LZX:
            out += lzx_decompress(block, usize)
        elif flags & COMPRESS_ZLIB:
            import zlib
            out += zlib.decompress(block)
        else:
            raise DecodeError(f"unsupported compression flags {flags:#x}")
        pos += csize
    return bytes(out)


class Reader:
    def __init__(self, data, off=0):
        self.data = data
        self.off = off

    def u32(self):
        v = u32(self.data, self.off)
        self.off += 4
        return v

    def i32(self):
        v = i32(self.data, self.off)
        self.off += 4
        return v

    def u64(self):
        v = struct.unpack_from(">Q", self.data, self.off)[0]
        self.off += 8
        return v

    def skip(self, n):
        self.off += n

    def fstring(self):
        n = self.i32()
        if n < 0:
            raw = self.data[self.off:self.off - 2 * n]
            self.off += -2 * n
            return raw.decode("utf-16-be", errors="replace").rstrip("\x00")
        if n > 0x10000:
            raise DecodeError(f"implausible FString length {n}")
        raw = self.data[self.off:self.off + n]
        self.off += n
        return raw.split(b"\x00", 1)[0].decode("latin-1")


class Package:
    def __init__(self):
        self.version = 0
        self.licensee = 0
        self.engine = 0
        self.cooker = 0
        self.header_size = 0
        self.folder = ""
        self.flags = 0
        self.name_count = self.name_offset = 0
        self.export_count = self.export_offset = 0
        self.import_count = self.import_offset = 0
        self.depends_offset = 0
        self.compression = 0
        self.fully_compressed = False
        self.names = []
        self.imports = []  # (class_package, class_name, outer, object_name)
        self.exports = []  # (class_index, super_index, outer_index, object_name, size, offset)
        self.exports_ok = False
        self.decoded = False
        self.error = ""

    def object_name(self, index):
        if index < 0 and -index - 1 < len(self.imports):
            return self.imports[-index - 1][3]
        if index > 0 and index - 1 < len(self.exports):
            return self.exports[index - 1][3]
        return "Class" if index == 0 else f"?{index}"

    def export_classes(self):
        counts = {}
        for e in self.exports:
            cls = self.object_name(e[0])
            counts[cls] = counts.get(cls, 0) + 1
        return counts


def read_summary(pkg, data):
    r = Reader(data, 0)
    if r.u32() != TAG:
        raise DecodeError("bad tag")
    v = r.u32()
    pkg.version = v & 0xFFFF
    pkg.licensee = (v >> 16) & 0xFFFF
    if pkg.version >= V_ADDED_TOTAL_HEADERSIZE:
        pkg.header_size = r.i32()
    if pkg.version >= V_ADDED_FOLDER_NAME:
        pkg.folder = r.fstring()
    pkg.flags = r.u32()
    pkg.name_count, pkg.name_offset = r.i32(), r.i32()
    pkg.export_count, pkg.export_offset = r.i32(), r.i32()
    pkg.import_count, pkg.import_offset = r.i32(), r.i32()
    if pkg.version >= V_ADDED_DEPENDS:
        pkg.depends_offset = r.i32()
    if pkg.version >= V_ADDED_IMPORT_EXPORT_GUIDS:
        r.skip(12)  # ImportExportGuidsOffset, ImportGuidsCount, ExportGuidsCount
    if pkg.version >= V_ADDED_THUMBNAILS:
        r.skip(4)  # ThumbnailTableOffset
    r.skip(16)  # Guid
    generations = r.i32()
    if not 0 <= generations < 1024:
        raise DecodeError(f"implausible generation count {generations}")
    r.skip(generations * (12 if pkg.version >= V_ADDED_NET_OBJECT_COUNT else 8))
    pkg.engine = r.i32()
    if pkg.version >= V_ADDED_COOKER_VERSION:
        pkg.cooker = r.i32()
    chunks = []
    if pkg.version >= V_ADDED_COMPRESSION:
        pkg.compression = r.u32()
        n = r.i32()
        if not 0 <= n < 4096:
            raise DecodeError(f"implausible chunk count {n}")
        for _ in range(n):
            chunks.append((r.i32(), r.i32(), r.i32(), r.i32()))
    return chunks


def read_tables(pkg, data):
    r = Reader(data, pkg.name_offset)
    names = []
    for _ in range(pkg.name_count):
        names.append(r.fstring())
        r.skip(8)  # object flags
    pkg.names = names

    def fname(rd):
        idx = rd.i32()
        num = rd.i32()
        base = names[idx] if 0 <= idx < len(names) else f"?{idx}"
        return base if num == 0 else f"{base}_{num - 1}"

    r = Reader(data, pkg.import_offset)
    for _ in range(pkg.import_count):
        cp = fname(r)
        cn = fname(r)
        outer = r.i32()
        on = fname(r)
        pkg.imports.append((cp, cn, outer, on))

    r = Reader(data, pkg.export_offset)
    exports = []
    try:
        for _ in range(pkg.export_count):
            cls, sup, outer = r.i32(), r.i32(), r.i32()
            on = fname(r)
            if pkg.version >= V_ADDED_ARCHETYPE:
                r.skip(4)
            r.skip(8)  # object flags
            size, off = r.i32(), r.i32()
            # No ComponentMap in this build (removed before v860).
            r.skip(4)  # export flags
            if pkg.version >= V_ADDED_NET_OBJECT_COUNT:
                nets = r.i32()
                if not 0 <= nets < 4096:
                    raise DecodeError("bad net object count")
                r.skip(nets * 4)
                r.skip(16)  # package guid
                r.skip(4)  # package flags
            exports.append((cls, sup, outer, on, size, off))
        pkg.exports_ok = (pkg.depends_offset == 0 or r.off == pkg.depends_offset)
    except (DecodeError, struct.error):
        pkg.exports_ok = False
    if pkg.exports_ok:
        pkg.exports = exports


def uncompressed_view(pkg, data, chunks):
    """Rebuild the uncompressed package image (header + decoded chunks)."""
    end = max(c[0] + c[1] for c in chunks)
    out = bytearray(end)
    first = min(c[0] for c in chunks)
    out[:first] = data[:first]
    for uoff, usize, coff, _csize in chunks:
        block = decompress_stream(data, coff, pkg.compression or COMPRESS_LZX)
        out[uoff:uoff + usize] = block[:usize]
    return bytes(out)


def parse(path, want_tables=True):
    pkg = Package()
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        pkg.error = str(e)
        return pkg
    if len(data) < 32 or u32(data, 0) != TAG:
        pkg.error = "not a UE3 package (bad tag)"
        return pkg
    try:
        # Fully compressed: Tag, BlockSize (0x20000), CompressedSize, UncompressedSize.
        if u32(data, 4) == 0x00020000 and u32(data, 8) <= len(data):
            pkg.fully_compressed = True
            pkg.compression = COMPRESS_LZX
            data = decompress_stream(data, 0)
            pkg.decoded = True
            chunks = read_summary(pkg, data)
            pkg.compression = COMPRESS_LZX  # outer container; inner summary says 0
        else:
            chunks = read_summary(pkg, data)
            if chunks and want_tables:
                data = uncompressed_view(pkg, data, chunks)
                pkg.decoded = True
            elif not chunks:
                pkg.decoded = True
        if want_tables and pkg.decoded:
            read_tables(pkg, data)
    except DecodeError as e:
        pkg.error = str(e)
    except (struct.error, IndexError) as e:
        pkg.error = f"parse error: {e}"
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


def compression_name(flags):
    return {0: "none", COMPRESS_ZLIB: "zlib", COMPRESS_LZO: "lzo", COMPRESS_LZX: "lzx"}.get(
        flags, f"{flags:#x}")


def main():
    ap = argparse.ArgumentParser(description="UE3 package catalog")
    ap.add_argument("package", nargs="?", help="package path or directory")
    ap.add_argument("--dir", dest="directory", help="directory of .xxx packages")
    ap.add_argument("--recursive", action="store_true")
    ap.add_argument("--names", action="store_true", help="print the name map")
    ap.add_argument("--imports", action="store_true", help="print the import table")
    ap.add_argument("--exports", action="store_true", help="print exports as Class Name")
    ap.add_argument("--classes", action="store_true", help="print export class counts")
    ap.add_argument("--limit", type=int, default=0, help="limit entries printed (0 = all)")
    ap.add_argument("--md", help="write a markdown table to this file")
    args = ap.parse_args()

    target = args.directory or args.package
    if not target:
        ap.error("pass a package or --dir")
    if not os.path.exists(target):
        ap.error(f"not found: {target}")
    if _load_lzx() is None:
        print("note: LZX helper not built; compressed packages show counts only "
              "(tools/catalog/build.ps1 or build.sh)", file=sys.stderr)

    results = [(p, parse(p)) for p in sorted(iter_packages(target, args.recursive))]

    def lim(seq):
        return seq if not args.limit else seq[:args.limit]

    if args.md:
        lines = ["| Package | Version | Engine | Storage | Names | Exports | Imports | Top export classes |",
                 "|---|---|---|---|---|---|---|---|"]
        for path, pkg in results:
            name = os.path.basename(path)
            if pkg.error:
                lines.append(f"| {name} | - | - | - | - | - | - | error: {pkg.error} |")
                continue
            storage = ("whole-file " if pkg.fully_compressed else "chunked ") + \
                compression_name(pkg.compression) if pkg.compression else "plain"
            top = ""
            if pkg.exports:
                cls = sorted(pkg.export_classes().items(), key=lambda kv: (-kv[1], kv[0]))[:4]
                top = ", ".join(f"{c} {n}" for c, n in cls)
            elif not pkg.decoded:
                top = "(not decoded)"
            lines.append(f"| {name} | {pkg.version}/{pkg.licensee} | {pkg.engine}/{pkg.cooker} | "
                         f"{storage} | {pkg.name_count} | {pkg.export_count} | {pkg.import_count} | {top} |")
        with open(args.md, "w", encoding="utf-8") as f:
            f.write("# UE3 package catalog\n\n")
            f.write("Generated by `tools/catalog/ue3_catalog.py` from the user's own dump.\n")
            f.write("Text only: versions, table counts and export class names; no asset bytes.\n")
            f.write("Storage: every compressed package is LZX (UE3 flag 0x4), not LZO.\n\n")
            f.write("\n".join(lines) + "\n")
        print(f"wrote {args.md} ({len(results)} packages)")

    if not args.md or args.names or args.imports or args.exports or args.classes:
        for path, pkg in results:
            name = os.path.basename(path)
            if pkg.error:
                print(f"{name}: {pkg.error}")
                continue
            print(f"{name}: v{pkg.version}/{pkg.licensee} engine={pkg.engine} cooker={pkg.cooker} "
                  f"names={pkg.name_count} exports={pkg.export_count} imports={pkg.import_count} "
                  f"compression={compression_name(pkg.compression)}"
                  f"{' (whole file)' if pkg.fully_compressed else ''} decoded={'yes' if pkg.decoded else 'no'}")
            if args.names:
                for n in lim(pkg.names):
                    print(f"  {n}")
            if args.imports:
                for cp, cn, outer, on in lim(pkg.imports):
                    print(f"  import {cp}.{cn} {on} (outer {pkg.object_name(outer) if outer else '-'})")
            if args.exports:
                if not pkg.exports_ok:
                    print("  (export table did not validate against DependsOffset)")
                for e in lim(pkg.exports):
                    outer = pkg.object_name(e[2]) if e[2] else "-"
                    print(f"  export {pkg.object_name(e[0])} {e[3]} (outer {outer}, {e[4]} bytes)")
            if args.classes:
                for cls, n in sorted(pkg.export_classes().items(), key=lambda kv: (-kv[1], kv[0])):
                    print(f"  {n:5d} {cls}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
