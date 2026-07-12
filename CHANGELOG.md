# Changelog

All notable changes to this project are documented here.

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
