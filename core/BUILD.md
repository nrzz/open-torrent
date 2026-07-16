# Build libtorrent-backed OpenTorrent core

## Windows — stub (no libtorrent)

Useful for CI and validating the C API without vcpkg:

```powershell
cd core
cmake -B build -S . -G "MinGW Makefiles" -DOPENTORRENT_USE_LIBTORRENT=OFF -DCMAKE_BUILD_TYPE=Release
# or: -G Ninja / Visual Studio generator with MSVC
cmake --build build
ctest --test-dir build --output-on-failure
```

## Windows — libtorrent via vcpkg (MSVC)

```powershell
# From repo root
.\scripts\build_libtorrent_windows.ps1
```

Or manually:

```powershell
$env:VCPKG_ROOT = "C:\vcpkg"   # or third_party\vcpkg
vcpkg install libtorrent:x64-windows

cmake -B build-lt -S . `
  -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" `
  -DOPENTORRENT_USE_LIBTORRENT=ON
cmake --build build-lt --config Release
```

Copy the resulting `opentorrent_core.dll` (and libtorrent/OpenSSL DLLs) next to `open_torrent.exe`.

## Android (NDK + vcpkg)

```powershell
# Requires Android SDK/NDK (API 28+). Builds arm64-v8a by default.
.\scripts\build_libtorrent_android.ps1 -OnlyAbi arm64-v8a
.\scripts\package_release_android_live.ps1
.\scripts\e2e_verify_android_live.ps1
```

```bash
# Linux host / CI
export ANDROID_NDK=/path/to/ndk
./scripts/build_libtorrent_android.sh arm64-v8a
./scripts/package_release_android_live.sh
```

The shared library lands in `app/android/app/src/main/jniLibs/<abi>/libopentorrent_core.so` (gitignored). Rebuild the Flutter APK **without** `OPENTORRENT_MOCK`.

## Linux (vcpkg)

```bash
./scripts/build_libtorrent_linux.sh
./scripts/bundle_native_linux.sh   # patchelf RPATH=\$ORIGIN
VERSION=0.3.1 ./scripts/package_release_linux.sh
./scripts/e2e_verify_linux.sh dist/OpenTorrent-linux-x64 --require-live
```

Requires GTK 3, AppIndicator (`libayatana-appindicator3-dev`), and `libsecret-1-dev` for Flutter desktop plugins.

## Manifest mode

[`vcpkg.json`](vcpkg.json) lists the `libtorrent` dependency for manifest-mode installs.
