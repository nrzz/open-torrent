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
  # Prefer runtime shared objects commonly needed by libtorrent
  for pattern in libtorrent-rasterbar.so* libssl.so* libcrypto.so* libboost_system.so*; do
    # shellcheck disable=SC2086
    cp -a $LIBDIR/$pattern "$NATIVE_OUT/" 2>/dev/null || true
  done
fi

echo "Native bundle ready at $NATIVE_OUT"
ls -la "$NATIVE_OUT"
