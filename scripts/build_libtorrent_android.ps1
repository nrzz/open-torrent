# scripts/build_libtorrent_android.ps1
# Cross-compile libtorrent (vcpkg) + libopentorrent_core.so and bundle into jniLibs.
param(
  [string]$OnlyAbi = 'arm64-v8a'  # default to phone ABI; use 'all' for every ABI
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { Join-Path $Root 'third_party\vcpkg' }

$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'D:\Android\Sdk' }
$ndkCandidates = @(
  $env:ANDROID_NDK,
  $env:ANDROID_NDK_HOME,
  (Join-Path $sdk 'ndk\28.2.13676358'),
  (Join-Path $sdk 'ndk\27.0.12077973')
) | Where-Object { $_ -and (Test-Path $_) }
if (-not $ndkCandidates) { throw "Android NDK not found under $sdk\ndk. Install via sdkmanager." }
$AndroidNdk = $ndkCandidates[0]
$env:ANDROID_NDK_HOME = $AndroidNdk
$env:ANDROID_NDK = $AndroidNdk
Write-Host "Using NDK: $AndroidNdk"

$isWin = $IsWindows -or ($env:OS -eq 'Windows_NT')
$vcpkgExe = if ($isWin) { Join-Path $VcpkgRoot 'vcpkg.exe' } else { Join-Path $VcpkgRoot 'vcpkg' }
if (-not (Test-Path $vcpkgExe)) {
  if (-not (Test-Path $VcpkgRoot)) {
    git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
  }
  if ($isWin) {
    & "$VcpkgRoot\bootstrap-vcpkg.bat"
  } else {
    & "$VcpkgRoot/bootstrap-vcpkg.sh"
  }
}

$allAbis = @(
  @{ Abi = 'arm64-v8a'; Triplet = 'arm64-android' },
  @{ Abi = 'armeabi-v7a'; Triplet = 'arm-neon-android' },
  @{ Abi = 'x86_64'; Triplet = 'x64-android' }
)

if ($OnlyAbi -eq 'all') {
  $abis = $allAbis
} else {
  $abis = @($allAbis | Where-Object { $_.Abi -eq $OnlyAbi })
  if (-not $abis) { throw "Unknown ABI '$OnlyAbi'. Use arm64-v8a, armeabi-v7a, x86_64, or all." }
}

# Prefer Ninja if present
$generator = 'Ninja'
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
  $generator = 'MinGW Makefiles'
  Write-Host "Ninja not found; using $generator"
}

foreach ($entry in $abis) {
  $abi = $entry.Abi
  $triplet = $entry.Triplet
  Write-Host "==> vcpkg install libtorrent:$triplet"
  & $vcpkgExe install "libtorrent:$triplet"
  if ($LASTEXITCODE -ne 0) { throw "vcpkg install failed for $triplet" }

  $buildDir = Join-Path $Root "core\build-android-$abi"
  Write-Host "==> Configure opentorrent_core ($abi / $triplet)"
  $cmakeArgs = @(
    '-S', (Join-Path $Root 'core'),
    '-B', $buildDir,
    '-G', $generator,
    '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake",
    "-DVCPKG_TARGET_TRIPLET=$triplet",
    "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$AndroidNdk\build\cmake\android.toolchain.cmake",
    "-DANDROID_ABI=$abi",
    '-DANDROID_PLATFORM=android-28',
    '-DANDROID_STL=c++_shared',
    '-DOPENTORRENT_USE_LIBTORRENT=ON',
    '-DOPENTORRENT_BUILD_SHARED=ON',
    '-DOPENTORRENT_BUILD_TESTS=OFF',
    '-DVCPKG_MANIFEST_MODE=OFF'
  )
  & cmake @cmakeArgs
  if ($LASTEXITCODE -ne 0) { throw "cmake configure failed for $abi" }

  Write-Host "==> Build ($abi)"
  & cmake --build $buildDir --config Release
  if ($LASTEXITCODE -ne 0) { throw "cmake build failed for $abi" }
}

& "$PSScriptRoot\bundle_native_android.ps1"
Write-Host 'Android live engine ready. Rebuild APK WITHOUT OPENTORRENT_MOCK.'
