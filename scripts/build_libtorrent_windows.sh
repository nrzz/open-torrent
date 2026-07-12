#!/usr/bin/env bash
# scripts/build_libtorrent_windows.sh — install libtorrent via vcpkg and build core
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VCPKG_ROOT="${VCPKG_ROOT:-$ROOT/third_party/vcpkg}"

if [[ ! -d "$VCPKG_ROOT" ]]; then
  git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
  "$VCPKG_ROOT/bootstrap-vcpkg.sh" || "$VCPKG_ROOT/bootstrap-vcpkg.bat"
fi

"$VCPKG_ROOT/vcpkg" install libtorrent:x64-windows

cmake -S "$ROOT/core" -B "$ROOT/core/build-lt" \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DOPENTORRENT_USE_LIBTORRENT=ON
cmake --build "$ROOT/core/build-lt" --config Release
