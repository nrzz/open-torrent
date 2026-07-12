# scripts/build_libtorrent_android.sh
# Cross-compile notes for Android (arm64-v8a + armeabi-v7a).
# Requires ANDROID_NDK and a libtorrent prefix built with the NDK toolchain.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${ANDROID_NDK:?Set ANDROID_NDK to your NDK path}"
ABI="${1:-arm64-v8a}"
PREFIX="${LIBTORRENT_ANDROID_PREFIX:?Set LIBTORRENT_ANDROID_PREFIX to installed libtorrent}"

cmake -S "$ROOT/core" -B "$ROOT/core/build-android-$ABI" \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM=android-24 \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DOPENTORRENT_USE_LIBTORRENT=ON
cmake --build "$ROOT/core/build-android-$ABI" --config Release
