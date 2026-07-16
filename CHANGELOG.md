# Changelog

All notable changes to this project are documented here.

## [0.3.1] — 2026-07-16

### Fixed
- Linux CI/release builds: install AppIndicator + libsecret deps so `tray_manager` links on Ubuntu runners
- Linux packaging Depends include `libayatana-appindicator3-1`; `.deb` runs `update-desktop-database` / `update-mime-database`

### Added
- Linux CLI deep links: magnet / `.torrent` / http(s) argv open via `addMagnet` / `addTorrentFile`
- Live libtorrent release jobs for **Linux**, **Windows**, and **Android** with vcpkg cache; publish live artifacts + `SHA256SUMS.txt` only
- `patchelf` `$ORIGIN` RPATH on bundled Linux `.so` files; hicolor icons in `.deb`
- `scripts/e2e_verify_windows_live.ps1` and hardened `e2e_verify_linux.sh --require-live`

### Changed
- Version string `OpenTorrent/0.3.1`
- GitHub Release artifacts: `OpenTorrent-linux-x64-0.3.1.tar.gz`, `OpenTorrent_0.3.1_amd64.deb`, Windows live zip (+ Setup when built), Android live APK

## [0.3.0] — 2026-07-14

### Security
- Native C ABI: input length limits, listen-port validation, hex info-hash checks, path traversal rejection
- Resume files: size cap, symlink skip, `save_path` forced under configured download root
- Fixed `ot_last_error` data race (fixed buffer under mutex) and stub `ot_add_torrent_file` deadlock
- Compiler/linker hardening: MSVC `/GS /guard:cf /sdl`; ELF `-fstack-protector-strong`, `_FORTIFY_SOURCE=2`, full RELRO
- Desktop native loading uses absolute exe-relative paths only (no DLL/.so hijacking via bare names)
- Proxy credentials moved out of `session_meta.json` into a private app-support file (Android sandbox / chmod 600)
- HTTPS-first torrent/RSS downloads with size caps, redirect downgrade rejection, bencode validation, SSRF guard
- Android: cleartext disabled, backups disabled, network security config, intent scheme allowlist, R8 minify

### Added
- **Linux desktop** target (`app/linux/`) with `.desktop` magnet/.torrent association
- Packaging: `scripts/package_release_linux.sh` → tar.gz + `.deb`
- CI Linux job + `SHA256SUMS.txt` on GitHub Releases
- Settings toggle: allow HTTP torrent/RSS URLs (off by default)

### Changed
- Version string `OpenTorrent/0.3.0`
- Update checker enabled on Linux; verifies via release checksums (no auto-install)

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
