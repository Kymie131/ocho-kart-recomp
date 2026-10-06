#!/usr/bin/env sh
# Build the UE3 LZX helper used by ue3_catalog.py (Linux/macOS).
# Output: tools/out/libue3lzx.so (or .dylib). See build.ps1 for Windows.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
mspack="$root/external/rexglue-sdk/thirdparty/libmspack/libmspack/mspack"
[ -f "$mspack/lzxd.c" ] || { echo "libmspack not found at $mspack (git submodule update --init --recursive)" >&2; exit 1; }
out="${1:-$root/tools/out}"
mkdir -p "$out"
ext=so; [ "$(uname)" = Darwin ] && ext=dylib
${CC:-cc} -O2 -fPIC -shared -I"$mspack" -o "$out/libue3lzx.$ext" "$here/ue3lzx.c" "$mspack/lzxd.c"
echo "built $out/libue3lzx.$ext"
