#!/usr/bin/env bash
# scripts/bundle_native_android.sh — copy libopentorrent_core.so (+ libc++_shared.so) into jniLibs
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JNI_ROOT="$ROOT/app/android/app/src/main/jniLibs"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
NDK="${ANDROID_NDK:-${ANDROID_NDK_HOME:-}}"

declare -A ABI_TRIPLE=(
  [arm64-v8a]=aarch64-linux-android
  [armeabi-v7a]=arm-linux-androideabi
  [x86_64]=x86_64-linux-android
)

PREBUILT=linux-x86_64
if [[ "$(uname -s)" == "Darwin" ]]; then
  PREBUILT=darwin-x86_64
elif [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
  PREBUILT=windows-x86_64
fi

copied=0
for abi in "${!ABI_TRIPLE[@]}"; do
  build_dir="$ROOT/core/build-android-$abi"
  so="$(find "$build_dir" -name 'libopentorrent_core.so' 2>/dev/null | head -n1 || true)"
  if [[ -z "$so" ]]; then
    echo "Skip $abi (no libopentorrent_core.so yet)"
    continue
  fi
  dest="$JNI_ROOT/$abi"
  mkdir -p "$dest"
  cp -a "$so" "$dest/libopentorrent_core.so"
  echo "Copied $so -> $dest"
  if [[ -n "$NDK" ]]; then
    stl="$NDK/toolchains/llvm/prebuilt/$PREBUILT/sysroot/usr/lib/${ABI_TRIPLE[$abi]}/libc++_shared.so"
    if [[ -f "$stl" ]]; then
      cp -a "$stl" "$dest/libc++_shared.so"
      echo "Copied libc++_shared.so for $abi"
    fi
  fi
  copied=$((copied + 1))
done

if [[ "$copied" -eq 0 ]]; then
  echo "No Android .so libraries found. Run build_libtorrent_android.sh first." >&2
  exit 1
fi

mkdir -p "$JNI_ROOT"
cat > "$JNI_ROOT/.gitignore" <<'EOF'
# Keep directory; large .so files are built locally / in CI
*
!.gitignore
EOF

echo "Bundled $copied ABI(s) into $JNI_ROOT"
