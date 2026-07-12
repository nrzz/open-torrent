# scripts/package_release_windows_live.ps1
# Build / refresh live Windows portable zip for GitHub Releases.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host '==> Ensuring native DLLs are bundled'
& "$Root\scripts\bundle_native_windows.ps1"

Write-Host '==> Flutter Windows release (live engine, no OPENTORRENT_MOCK)'
Push-Location "$Root\app"
flutter build windows --release
Pop-Location

$src = "$Root\app\build\windows\x64\runner\Release"
$dist = "$Root\dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = "$dist\OpenTorrent-windows-x64-live.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

# Exclude stale plugin DLLs that are no longer in pubspec.
$exclude = @('permission_handler_windows_plugin.dll')
$stage = "$dist\_win_stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Get-ChildItem $src | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
  Copy-Item $_.FullName -Destination $stage -Recurse -Force
}

Compress-Archive -Path "$stage\*" -DestinationPath $zip
Remove-Item $stage -Recurse -Force

$dll = Join-Path $src 'opentorrent_core.dll'
if (-not (Test-Path $dll)) {
  throw "Missing $dll - run build_libtorrent_windows.ps1 first"
}
Write-Host "Packaged: $zip"
Write-Host "Size: $((Get-Item $zip).Length) bytes"
