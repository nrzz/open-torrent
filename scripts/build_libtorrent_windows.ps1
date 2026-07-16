# scripts/build_libtorrent_windows.ps1
# Install libtorrent via vcpkg and build the OpenTorrent core DLL for Windows x64.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

# Prefer repo-local vcpkg. GitHub windows-latest often sets VCPKG_ROOT to a
# Visual Studio copy that has no classic-mode ports — do not use that by default.
$VcpkgRoot = if ($env:OPENTORRENT_VCPKG_ROOT) {
  $env:OPENTORRENT_VCPKG_ROOT
} else {
  Join-Path $Root "third_party\vcpkg"
}
$env:VCPKG_ROOT = $VcpkgRoot

function Ensure-Vcpkg {
  $exe = Join-Path $VcpkgRoot "vcpkg.exe"
  if (Test-Path $exe) { return }

  # Cache may restore installed/downloads without the tool — re-clone, keep cache trees.
  $keep = Join-Path ([System.IO.Path]::GetTempPath()) ("ot_vcpkg_keep_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $keep | Out-Null
  foreach ($name in @("installed", "downloads")) {
    $src = Join-Path $VcpkgRoot $name
    if (Test-Path $src) {
      Move-Item $src (Join-Path $keep $name) -Force
    }
  }
  if (Test-Path $VcpkgRoot) {
    Remove-Item $VcpkgRoot -Recurse -Force
  }
  git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
  if ($LASTEXITCODE -ne 0) { throw "git clone vcpkg failed" }
  foreach ($name in @("installed", "downloads")) {
    $src = Join-Path $keep $name
    if (Test-Path $src) {
      Move-Item $src (Join-Path $VcpkgRoot $name) -Force
    }
  }
  Remove-Item $keep -Recurse -Force -ErrorAction SilentlyContinue

  & "$VcpkgRoot\bootstrap-vcpkg.bat"
  if ($LASTEXITCODE -ne 0) { throw "bootstrap-vcpkg failed" }
  if (-not (Test-Path $exe)) { throw "vcpkg.exe missing after bootstrap" }
}

Ensure-Vcpkg
Write-Host "Using vcpkg at $VcpkgRoot"
& "$VcpkgRoot\vcpkg.exe" install libtorrent:x64-windows
if ($LASTEXITCODE -ne 0) { throw "vcpkg install libtorrent:x64-windows failed" }

$BuildDir = Join-Path $Root "core\build-lt"
# Ninja + ambient MSVC (ilammy/msvc-dev-cmd) — VS 2022 generator is missing on
# newer windows-latest images that ship Visual Studio 18.
$generator = if (Get-Command ninja -ErrorAction SilentlyContinue) { "Ninja" } else { "NMake Makefiles" }
Write-Host "Configuring with generator: $generator"
& cmake -S (Join-Path $Root "core") -B $BuildDir `
  -G $generator `
  -DCMAKE_BUILD_TYPE=Release `
  "-DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=x64-windows `
  -DVCPKG_MANIFEST_MODE=OFF `
  -DOPENTORRENT_USE_LIBTORRENT=ON `
  -DOPENTORRENT_BUILD_SHARED=ON
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

& cmake --build $BuildDir --config Release
if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

$dll = Get-ChildItem -Path $BuildDir -Recurse -Filter "opentorrent_core.dll" -ErrorAction SilentlyContinue |
  Select-Object -First 1
if (-not $dll) { throw "opentorrent_core.dll was not produced under $BuildDir" }
Write-Host "Built core with libtorrent: $($dll.FullName)"

& "$PSScriptRoot\bundle_native_windows.ps1"
