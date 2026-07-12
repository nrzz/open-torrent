# scripts/build_libtorrent_windows.ps1
# Install libtorrent via vcpkg and build the OpenTorrent core for Windows x64.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { Join-Path $Root "third_party\vcpkg" }

if (-not (Test-Path $VcpkgRoot)) {
  git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
  & "$VcpkgRoot\bootstrap-vcpkg.bat"
}

& "$VcpkgRoot\vcpkg.exe" install libtorrent:x64-windows

$BuildDir = Join-Path $Root "core\build-lt"
cmake -S (Join-Path $Root "core") -B $BuildDir `
  -DCMAKE_TOOLCHAIN_FILE="$VcpkgRoot\scripts\buildsystems\vcpkg.cmake" `
  -DOPENTORRENT_USE_LIBTORRENT=ON
cmake --build $BuildDir --config Release
Write-Host "Built core with libtorrent at $BuildDir"
