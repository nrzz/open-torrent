# scripts/e2e_verify_windows_live.ps1 — smoke-check live Windows portable zip / Release folder
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$zip = Join-Path $Root 'dist\OpenTorrent-windows-x64-live.zip'
$releaseDir = Join-Path $Root 'app\build\windows\x64\runner\Release'

$probeDir = $null
$tmp = $null
if (Test-Path $zip) {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ot_win_e2e_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $probeDir = $tmp
  Write-Host "ok: inspecting zip $zip"
} elseif (Test-Path $releaseDir) {
  $probeDir = $releaseDir
  Write-Host "ok: inspecting Release folder $releaseDir"
} else {
  throw 'FAIL: neither dist\OpenTorrent-windows-x64-live.zip nor Windows Release folder found'
}

try {
  $dll = Join-Path $probeDir 'opentorrent_core.dll'
  if (-not (Test-Path $dll)) {
    throw "FAIL: opentorrent_core.dll missing under $probeDir"
  }
  Write-Host "ok: opentorrent_core.dll present ($((Get-Item $dll).Length) bytes)"

  $bytes = [System.IO.File]::ReadAllBytes($dll)
  $text = [System.Text.Encoding]::ASCII.GetString($bytes)
  if ($text -notmatch 'libtorrent') {
    throw 'FAIL: libtorrent string missing from opentorrent_core.dll (not a live build?)'
  }
  Write-Host 'ok: libtorrent string in DLL'
  if ($text -match 'OpenTorrent/0\.') {
    Write-Host 'ok: OpenTorrent version string in DLL'
  } else {
    Write-Host 'WARN: OpenTorrent version string not found in DLL'
  }

  $exe = Get-ChildItem $probeDir -Filter 'open_torrent.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $exe) { throw 'FAIL: open_torrent.exe missing' }
  Write-Host "ok: $($exe.Name) present"
} finally {
  if ($tmp -and (Test-Path $tmp)) {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host 'E2E Windows live smoke passed'
