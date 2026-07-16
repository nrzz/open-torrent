#!/usr/bin/env bash
# scripts/package_release_android_live.sh — build live-engine Android APK
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SO="$ROOT/app/android/app/src/main/jniLibs/arm64-v8a/libopentorrent_core.so"
if [[ ! -f "$SO" ]]; then
  echo "Missing $SO — run scripts/build_libtorrent_android.sh first." >&2
  exit 1
fi

pushd "$ROOT/app" >/dev/null
flutter build apk --release
popd >/dev/null

mkdir -p "$ROOT/dist"
OUT="$ROOT/dist/OpenTorrent-android-live.apk"
cp -f "$ROOT/app/build/app/outputs/flutter-apk/app-release.apk" "$OUT"

if ! unzip -l "$OUT" | grep -q 'lib/.*/libopentorrent_core.so'; then
  echo "APK missing libopentorrent_core.so" >&2
  exit 1
fi
echo "Packaged: $OUT ($(wc -c <"$OUT") bytes)"
