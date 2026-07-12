# Changelog

All notable changes to this project are documented here.

## [0.2.1] — 2026-07-12

### Added
- **Android live libtorrent engine** via NDK + vcpkg (`scripts/build_libtorrent_android.ps1`)
- `jniLibs` packaging for `libopentorrent_core.so` (arm64-v8a+)
- Live Android APK packaging + offline e2e verifier scripts

### Fixed
- Mock banner on Android release builds when native `.so` is present
- FFI loader looks up Android system libraries by SONAME

## [0.2.0] — 2026-07-12

### Added
- Android release APK on GitHub Releases (`OpenTorrent-android.apk`)
- Windows live libtorrent portable zip packaging (`OpenTorrent-windows-x64-live.zip`)
- Magnet / `.torrent` deep-link handling on Android (`MainActivity` → Dart)
- Runtime notification permission request (Android 13+)
- Download notification progress (%) for active torrents
- Wi‑Fi-only auto-resume when connectivity returns
- IP blocklist loader in the native session (P2P `start - end` lines)
- UPnP / NAT-PMP enabled by default in the live engine
- `compileSdk 36` for current Flutter Android plugin metadata

### Fixed
- Android CI APK build failing on AAR `compileSdk` 34 vs plugin requirement 36
- Mock-by-default confusion: live Windows path documented; release attaches Android APK

### Notes
- **Windows live:** build with `scripts/build_libtorrent_windows.ps1` (no `OPENTORRENT_MOCK`).
- **Android live:** build with `scripts/build_libtorrent_android.ps1` (API 28+, arm64-v8a).
- See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for engine modes.

## [0.1.0] — 2026-07-12

### Added

- Flutter UI for Android and Windows (torrent list, details, settings, RSS)
- C API wrapper around libtorrent (`core/`) with in-process stub/mock fallback
- Session resume, sequential download, categories/tags, bandwidth scheduler
- SOCKS5 proxy and IP blocklist path settings
- Android foreground download service, notifications, magnet/`.torrent` intents
- Windows tray / minimize-to-tray and Inno Setup packaging script
- GitHub Actions CI (core tests, Flutter tests, Windows + Android builds)
- Release workflow that publishes Windows zip and Android APK
- winget and F-Droid packaging stubs

### Notes

- Default public builds use the mock engine until `opentorrent_core` is linked against libtorrent.
- See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for engine modes.
