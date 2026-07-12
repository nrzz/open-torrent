# scripts/bundle_native_windows.ps1
# Copy opentorrent_core.dll (+ libtorrent/OpenSSL/Boost deps) into Flutter Windows native/.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$NativeOut = Join-Path $Root "app\windows\native"
New-Item -ItemType Directory -Force -Path $NativeOut | Out-Null

$candidates = @(
  (Join-Path $Root "core\build-lt\Release\opentorrent_core.dll"),
  (Join-Path $Root "core\build-lt\opentorrent_core.dll")
)
$dll = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dll) {
  Write-Error "opentorrent_core.dll not found. Run scripts\build_libtorrent_windows.ps1 first."
}

$dllDir = Split-Path $dll
Copy-Item (Join-Path $dllDir "*.dll") $NativeOut -Force
Write-Host "Copied runtime DLLs from $dllDir"

$VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { Join-Path $Root "third_party\vcpkg" }
$bin = Join-Path $VcpkgRoot "installed\x64-windows\bin"
if (Test-Path $bin) {
  Copy-Item (Join-Path $bin "*.dll") $NativeOut -Force
  Write-Host "Merged vcpkg bin DLLs from $bin"
}

Write-Host "Native bundle ready at $NativeOut"
Write-Host "Rebuild Flutter WITHOUT --dart-define=OPENTORRENT_MOCK=true"
Get-ChildItem $NativeOut -Filter "*.dll" | Select-Object Name, Length
