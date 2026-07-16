#!/usr/bin/env bash
# scripts/bundle_native_linux.sh — copy libopentorrent_core.so (+ deps) into Flutter linux/native
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE_OUT="$ROOT/app/linux/native"
mkdir -p "$NATIVE_OUT"

candidates=(
  "$ROOT/core/build-linux/libopentorrent_core.so"
  "$ROOT/core/build-linux/Release/libopentorrent_core.so"
)
SO=""
for c in "${candidates[@]}"; do
  if [[ -f "$c" ]]; then SO="$c"; break; fi
done
if [[ -z "$SO" ]]; then
  echo "libopentorrent_core.so not found. Run scripts/build_libtorrent_linux.sh first." >&2
  exit 1
fi

cp -a "$SO" "$NATIVE_OUT/"
# Copy SONAME-linked deps from vcpkg if present
VCPKG_ROOT="${VCPKG_ROOT:-$ROOT/third_party/vcpkg}"
LIBDIR="$VCPKG_ROOT/installed/x64-linux/lib"
if [[ -d "$LIBDIR" ]]; then
  for pattern in libtorrent-rasterbar.so* libssl.so* libcrypto.so* libboost_system.so*; do
    # shellcheck disable=SC2086
    cp -a $LIBDIR/$pattern "$NATIVE_OUT/" 2>/dev/null || true
  done
fi

# Ensure bundled .so files resolve siblings in the same directory at runtime.
if command -v patchelf >/dev/null 2>&1; then
  shopt -s nullglob
  for f in "$NATIVE_OUT"/*.so "$NATIVE_OUT"/*.so.*; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
  done
  shopt -u nullglob
  echo "ok: patchelf RPATH=\$ORIGIN applied"
else
  echo "WARN: patchelf not found — install patchelf for reliable runtime linking"
fi

echo "Native bundle ready at $NATIVE_OUT"
ls -la "$NATIVE_OUT"
