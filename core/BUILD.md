# Build libtorrent-backed OpenTorrent core

## Windows (vcpkg)

```powershell
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
$env:VCPKG_ROOT = "C:\vcpkg"
vcpkg install libtorrent:x64-windows

cmake -B build -S . `
  -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" `
  -DOPENTORRENT_USE_LIBTORRENT=ON
cmake --build build --config Release
ctest --test-dir build -C Release
```

## Stub mode (no libtorrent)

```powershell
cmake -B build -S . -DOPENTORRENT_USE_LIBTORRENT=OFF
cmake --build build --config Release
```

## Android (NDK)

```powershell
# After installing Android NDK and building libtorrent with the NDK toolchain:
cmake -B build-android -S . `
  -DCMAKE_TOOLCHAIN_FILE=$env:ANDROID_NDK/build/cmake/android.toolchain.cmake `
  -DANDROID_ABI=arm64-v8a `
  -DANDROID_PLATFORM=android-24 `
  -DOPENTORRENT_USE_LIBTORRENT=ON `
  -DCMAKE_PREFIX_PATH=<path-to-libtorrent-android-prefix>
cmake --build build-android --config Release
```

Prebuilt scripts live in `scripts/` at the repo root.
