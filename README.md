# OpenTorrent

Free, ad-free, open-source BitTorrent client for **Android** and **Windows**.

Built on [libtorrent-rasterbar](https://libtorrent.org/) with a single [Flutter](https://flutter.dev/) UI. No ads, no telemetry, no paywalls. Licensed under **GPLv3**.

> **Legal notice:** OpenTorrent transfers files with the BitTorrent protocol. You are responsible for using it only with content that is lawful in your jurisdiction.

## Status

| Platform | Artifact | Notes |
|----------|----------|--------|
| Windows | Portable zip / installer | Mock engine works out of the box; real transfers need libtorrent |
| Android | APK (GitHub Releases / CI) | Foreground service + notifications |

Latest builds: **[GitHub Releases](https://github.com/nrzz/open-torrent/releases)**

## Features

- Magnet links, `.torrent` files, and torrent URLs
- DHT, PEX, LSD, uTP, protocol encryption, BitTorrent v2 (via libtorrent)
- File selection and priorities, sequential / streaming-friendly download
- Session resume across restarts
- Speed limits, connection limits, encryption modes
- Bandwidth scheduler, SOCKS5 proxy, IP blocklist path
- RSS auto-download with filters; categories and tags
- Android foreground downloads + notifications; Wi‑Fi-only option
- Windows tray, magnet / `.torrent` association, Inno Setup + portable zip

## Quick start

### Run the UI (mock engine — no native libtorrent required)

```powershell
git clone https://github.com/nrzz/open-torrent.git
cd open-torrent\app
flutter pub get
flutter run -d windows --dart-define=OPENTORRENT_MOCK=true
```

### Build release binaries

```powershell
# Windows
flutter build windows --release --dart-define=OPENTORRENT_MOCK=true

# Android APK
flutter build apk --release --dart-define=OPENTORRENT_MOCK=true
```

### Native core (optional — real BitTorrent)

```powershell
# Stub core (tests / no libtorrent)
cd core
cmake -B build -S . -G "MinGW Makefiles" -DOPENTORRENT_USE_LIBTORRENT=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure

# With libtorrent (MSVC + vcpkg)
..\scripts\build_libtorrent_windows.ps1
```

Full native build notes: [core/BUILD.md](core/BUILD.md)

## Repository layout

```text
app/           Flutter UI (Android + Windows)
core/          C API around libtorrent (+ stub fallback)
scripts/       libtorrent / NDK build helpers
packaging/     Inno Setup, winget, F-Droid metadata
docs/          Architecture and design notes
.github/       CI, release workflows, issue templates
```

## Documentation

| Doc | Purpose |
|-----|---------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Dev setup, PR guidelines |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Engine ↔ Flutter design |
| [core/BUILD.md](core/BUILD.md) | Native / vcpkg / NDK builds |
| [packaging/README.md](packaging/README.md) | Releases, winget, F-Droid |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting |

## Prerequisites

- Flutter 3.22+
- CMake 3.20+ and a C++17 toolchain (MSVC Build Tools recommended on Windows)
- Android SDK (for APK)
- [vcpkg](https://vcpkg.io/) when linking real libtorrent
- Windows: enable [Developer Mode](ms-settings:developers) for Flutter plugin symlinks

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Keep the app free of ads, trackers, and paywalls.

## License

[GNU GPL v3](LICENSE). Third-party notices: [core/THIRD_PARTY.md](core/THIRD_PARTY.md).
