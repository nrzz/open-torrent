# scripts/bundle_native_android.ps1
# Copy libopentorrent_core.so (+ libc++_shared.so) into Flutter jniLibs.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$jniRoot = Join-Path $Root 'app\android\app\src\main\jniLibs'
$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'D:\Android\Sdk' }
$ndk = if ($env:ANDROID_NDK) { $env:ANDROID_NDK } elseif ($env:ANDROID_NDK_HOME) { $env:ANDROID_NDK_HOME } else {
  @(
    (Join-Path $sdk 'ndk\28.2.13676358'),
    (Join-Path $sdk 'ndk\27.0.12077973')
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$abiMap = @{
  'arm64-v8a'   = 'aarch64-linux-android'
  'armeabi-v7a' = 'arm-linux-androideabi'
  'x86_64'      = 'x86_64-linux-android'
}

$copied = 0
foreach ($abi in $abiMap.Keys) {
  $buildDir = Join-Path $Root "core\build-android-$abi"
  $so = Get-ChildItem -Path $buildDir -Recurse -Filter 'libopentorrent_core.so' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $so) {
    Write-Host "Skip $abi (no libopentorrent_core.so yet)"
    continue
  }
  $destDir = Join-Path $jniRoot $abi
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  Copy-Item $so.FullName -Destination (Join-Path $destDir 'libopentorrent_core.so') -Force
  Write-Host "Copied $($so.FullName) -> $destDir"

  # Package C++ shared STL used by the NDK build.
  if ($ndk) {
    $stl = Join-Path $ndk "toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\$($abiMap[$abi])\libc++_shared.so"
    if (Test-Path $stl) {
      Copy-Item $stl -Destination (Join-Path $destDir 'libc++_shared.so') -Force
      Write-Host "Copied libc++_shared.so for $abi"
    }
  }
  $copied++
}

if ($copied -eq 0) { throw 'No Android .so libraries found to bundle. Run build_libtorrent_android.ps1 first.' }

# Ensure jniLibs are not gitignored incorrectly — keep a placeholder ignore for empty dirs only
$gitignore = Join-Path $jniRoot '.gitignore'
@"
# Keep directory; large .so files are built locally / in CI
*
!.gitignore
"@ | Set-Content $gitignore -Encoding UTF8

Write-Host "Bundled $copied ABI(s) into $jniRoot"
