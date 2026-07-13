#!/usr/bin/env bash
# scripts/build_libtorrent_linux.sh — install libtorrent via vcpkg and build hardened core
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VCPKG_ROOT="${VCPKG_ROOT:-$ROOT/third_party/vcpkg}"

if [[ ! -d "$VCPKG_ROOT" ]]; then
  git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
  "$VCPKG_ROOT/bootstrap-vcpkg.sh"
fi

"$VCPKG_ROOT/vcpkg" install libtorrent:x64-linux

cmake -S "$ROOT/core" -B "$ROOT/core/build-linux" \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DOPENTORRENT_USE_LIBTORRENT=ON \
  -DOPENTORRENT_BUILD_SHARED=ON
cmake --build "$ROOT/core/build-linux" --config Release -j"$(nproc)"

echo "Built core at $ROOT/core/build-linux"
