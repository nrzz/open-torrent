# scripts/package_release_android_live.ps1
# Build live-engine Android APK (requires jniLibs from build_libtorrent_android.ps1).
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$env:ANDROID_HOME = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'D:\Android\Sdk' }
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

$so = Join-Path $Root 'app\android\app\src\main\jniLibs\arm64-v8a\libopentorrent_core.so'
if (-not (Test-Path $so)) {
  throw "Missing $so - run .\scripts\build_libtorrent_android.ps1 first"
}

Push-Location (Join-Path $Root 'app')
try {
  Write-Host '==> flutter build apk (live engine, no OPENTORRENT_MOCK)'
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
} finally {
  Pop-Location
}

$apk = Join-Path $Root 'app\build\app\outputs\flutter-apk\app-release.apk'
$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$out = Join-Path $dist 'OpenTorrent-android-live.apk'
Copy-Item $apk $out -Force

# Smoke: APK must contain the native library
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($out)
try {
  $entry = $zip.Entries | Where-Object { $_.FullName -like 'lib/*/libopentorrent_core.so' } | Select-Object -First 1
  if (-not $entry) { throw 'APK missing libopentorrent_core.so - native engine not packaged' }
  Write-Host "Packaged native: $($entry.FullName) ($($entry.Length) bytes)"
} finally {
  $zip.Dispose()
}

Write-Host "Packaged: $out ($((Get-Item $out).Length) bytes)"
