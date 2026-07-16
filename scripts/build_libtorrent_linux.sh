#!/usr/bin/env bash
# scripts/build_libtorrent_linux.sh — install libtorrent via vcpkg and build hardened core
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VCPKG_ROOT="${OPENTORRENT_VCPKG_ROOT:-${VCPKG_ROOT:-$ROOT/third_party/vcpkg}}"
# Prefer repo-local tool; avoid host VCPKG_ROOT that is only a cache stub.
if [[ "$VCPKG_ROOT" != "$ROOT/third_party/vcpkg" && ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  VCPKG_ROOT="$ROOT/third_party/vcpkg"
fi
export VCPKG_ROOT

ensure_vcpkg() {
  if [[ -x "$VCPKG_ROOT/vcpkg" ]]; then
    return 0
  fi
  # actions/cache may restore installed/downloads and create the directory
  # without the vcpkg tool or .git — re-clone while preserving those trees.
  local keep
  keep="$(mktemp -d)"
  if [[ -d "$VCPKG_ROOT/installed" ]]; then
    mv "$VCPKG_ROOT/installed" "$keep/installed"
  fi
  if [[ -d "$VCPKG_ROOT/downloads" ]]; then
    mv "$VCPKG_ROOT/downloads" "$keep/downloads"
  fi
  rm -rf "$VCPKG_ROOT"
  git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
  if [[ -d "$keep/installed" ]]; then
    mv "$keep/installed" "$VCPKG_ROOT/installed"
  fi
  if [[ -d "$keep/downloads" ]]; then
    mv "$keep/downloads" "$VCPKG_ROOT/downloads"
  fi
  rm -rf "$keep"
  "$VCPKG_ROOT/bootstrap-vcpkg.sh"
}

ensure_vcpkg

"$VCPKG_ROOT/vcpkg" install libtorrent:x64-linux

cmake -S "$ROOT/core" -B "$ROOT/core/build-linux" \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DVCPKG_TARGET_TRIPLET=x64-linux \
  -DVCPKG_MANIFEST_MODE=OFF \
  -DOPENTORRENT_USE_LIBTORRENT=ON \
  -DOPENTORRENT_BUILD_SHARED=ON
cmake --build "$ROOT/core/build-linux" --config Release -j"$(nproc)"

echo "Built core at $ROOT/core/build-linux"
