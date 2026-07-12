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

## Android (NDK)

```bash
# Requires ANDROID_NDK and a libtorrent prefix built for the ABI
./scripts/build_libtorrent_android.sh arm64-v8a
```

See script comments for `LIBTORRENT_ANDROID_PREFIX`.

## Manifest mode

[`vcpkg.json`](vcpkg.json) lists the `libtorrent` dependency for manifest-mode installs.
