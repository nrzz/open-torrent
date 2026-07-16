#!/usr/bin/env bash
# scripts/build_libtorrent_android.sh — vcpkg libtorrent + libopentorrent_core.so for Android
# Usage: ./scripts/build_libtorrent_android.sh [arm64-v8a|armeabi-v7a|x86_64|all]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ONLY_ABI="${1:-arm64-v8a}"
VCPKG_ROOT="${OPENTORRENT_VCPKG_ROOT:-${VCPKG_ROOT:-$ROOT/third_party/vcpkg}}"
if [[ "$VCPKG_ROOT" != "$ROOT/third_party/vcpkg" && ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  VCPKG_ROOT="$ROOT/third_party/vcpkg"
fi
export VCPKG_ROOT

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
NDK="${ANDROID_NDK:-${ANDROID_NDK_HOME:-}}"
if [[ -z "$NDK" || ! -d "$NDK" ]]; then
  for cand in \
    "$SDK/ndk/28.2.13676358" \
    "$SDK/ndk/27.0.12077973" \
    /usr/local/lib/android/sdk/ndk/*; do
    if [[ -n "$cand" && -d "$cand" ]]; then
      NDK="$cand"
      break
    fi
  done
fi
if [[ -z "$NDK" || ! -d "$NDK" ]]; then
  echo "Android NDK not found. Set ANDROID_NDK or install via sdkmanager." >&2
  exit 1
fi
export ANDROID_NDK="$NDK"
export ANDROID_NDK_HOME="$NDK"
echo "Using NDK: $NDK"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  # Cache may restore installed/downloads without the tool — re-clone, keep trees.
  keep="$(mktemp -d)"
  [[ -d "$VCPKG_ROOT/installed" ]] && mv "$VCPKG_ROOT/installed" "$keep/installed"
  [[ -d "$VCPKG_ROOT/downloads" ]] && mv "$VCPKG_ROOT/downloads" "$keep/downloads"
  rm -rf "$VCPKG_ROOT"
  git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
  [[ -d "$keep/installed" ]] && mv "$keep/installed" "$VCPKG_ROOT/installed"
  [[ -d "$keep/downloads" ]] && mv "$keep/downloads" "$VCPKG_ROOT/downloads"
  rm -rf "$keep"
  "$VCPKG_ROOT/bootstrap-vcpkg.sh"
fi

declare -A ABI_TRIPLET=(
  [arm64-v8a]=arm64-android
  [armeabi-v7a]=arm-neon-android
  [x86_64]=x64-android
)

if [[ "$ONLY_ABI" == "all" ]]; then
  ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")
else
  ABIS=("$ONLY_ABI")
fi

for abi in "${ABIS[@]}"; do
  triplet="${ABI_TRIPLET[$abi]:-}"
  if [[ -z "$triplet" ]]; then
    echo "Unknown ABI '$abi'" >&2
    exit 1
  fi
  echo "==> vcpkg install libtorrent:$triplet"
  "$VCPKG_ROOT/vcpkg" install "libtorrent:$triplet"

  build_dir="$ROOT/core/build-android-$abi"
  echo "==> Configure opentorrent_core ($abi / $triplet)"
  cmake -S "$ROOT/core" -B "$build_dir" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
    -DVCPKG_TARGET_TRIPLET="$triplet" \
    -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM=android-28 \
    -DANDROID_STL=c++_shared \
    -DOPENTORRENT_USE_LIBTORRENT=ON \
    -DOPENTORRENT_BUILD_SHARED=ON \
    -DOPENTORRENT_BUILD_TESTS=OFF \
    -DVCPKG_MANIFEST_MODE=OFF
  cmake --build "$build_dir" --config Release -j"$(nproc)"
done

"$ROOT/scripts/bundle_native_android.sh"
echo "Android live engine ready. Rebuild APK WITHOUT OPENTORRENT_MOCK."
