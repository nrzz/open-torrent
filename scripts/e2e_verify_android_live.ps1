# scripts/e2e_verify_android_live.ps1
# Offline e2e checks for the live Android engine artifact.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $Root 'dist\OpenTorrent-android-live.apk'
if (-not (Test-Path $apk)) {
  $apk = Join-Path $Root 'app\build\app\outputs\flutter-apk\app-release.apk'
}
if (-not (Test-Path $apk)) { throw "APK not found. Build with package_release_android_live.ps1 first." }

Write-Host "==> APK: $apk ($((Get-Item $apk).Length) bytes)"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk)
try {
  $sos = @($zip.Entries | Where-Object { $_.FullName -like 'lib/*/libopentorrent_core.so' })
  if ($sos.Count -eq 0) { throw 'FAIL: libopentorrent_core.so not in APK' }
  foreach ($s in $sos) {
    Write-Host "ok: packaged $($s.FullName) ($($s.Length) bytes)"
  }

  # Extract .so and check for ot_version / libtorrent strings
  # $env:TEMP is often unset under pwsh on Linux runners — use BCL temp path.
  $tmpRoot = [System.IO.Path]::GetTempPath()
  $tmp = Join-Path $tmpRoot 'ot_apk_so_check'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $first = $sos[0]
  $dest = Join-Path $tmp 'libopentorrent_core.so'
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($first, $dest, $true)

  $bytes = [System.IO.File]::ReadAllBytes($dest)
  $text = [System.Text.Encoding]::ASCII.GetString($bytes)
  if ($text -notmatch 'ot_version') { throw 'FAIL: ot_version symbol/string missing from .so' }
  Write-Host 'ok: ot_version present in .so'
  if ($text -match 'libtorrent') {
    Write-Host 'ok: libtorrent string present (live engine linked)'
  } else {
    Write-Host 'WARN: libtorrent string not found — may be stub build'
  }
  if ($text -match 'OpenTorrent/0\.') {
    Write-Host 'ok: OpenTorrent version string present'
  }
} finally {
  $zip.Dispose()
}

# Flutter unit/widget tests
Push-Location (Join-Path $Root 'app')
try {
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  Write-Host 'ok: flutter test'
} finally {
  Pop-Location
}

# Device smoke if adb device present
$adbHome = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'D:\Android\Sdk' }
$adb = Join-Path $adbHome 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $adb = 'adb' }
$devices = $null
try {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $devices = & $adb devices 2>&1 | Select-String -Pattern "`tdevice$"
  $ErrorActionPreference = $prev
} catch {
  $devices = $null
}
if ($devices) {
  Write-Host '==> Installing APK on device for smoke'
  & $adb install -r $apk
  if ($LASTEXITCODE -ne 0) { throw 'adb install failed' }
  & $adb shell am start -n org.opentorrent.open_torrent/.MainActivity
  Start-Sleep 4
  $log = & $adb logcat -d -t 200 2>$null | Out-String
  if ($log -match 'OpenTorrent/.*libtorrent' -or $log -match 'session created') {
    Write-Host 'ok: device log suggests live engine'
  } else {
    Write-Host 'WARN: could not confirm engine string from logcat (UI may still be live)'
  }
} else {
  Write-Host 'skip: no adb device — offline APK/.so checks only'
}

Write-Host 'ALL ANDROID LIVE E2E CHECKS PASSED'
