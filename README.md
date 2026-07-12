# OpenTorrent

Free, ad-free, open-source BitTorrent client for **Android** and **Windows**.

Built on [libtorrent-rasterbar](https://libtorrent.org/) with a single [Flutter](https://flutter.dev/) UI. No ads, no telemetry, no paywalls. Licensed under **GPLv3**.

> **Legal notice:** OpenTorrent transfers files with the BitTorrent protocol. You are responsible for using it only with content that is lawful in your jurisdiction.

## Status

| Platform | Artifact | Notes |
|----------|----------|--------|
| Windows | `OpenTorrent-windows-x64-live.zip` | Live libtorrent (`scripts/package_release_windows_live.ps1`) |
| Android | `OpenTorrent-android-live.apk` | Live libtorrent arm64 (`scripts/build_libtorrent_android.ps1`) |

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

### Live engine (Windows — real BitTorrent)

```powershell
git clone https://github.com/nrzz/open-torrent.git
cd open-torrent

# Build libtorrent + opentorrent_core.dll and copy into app/windows/native/
.\scripts\build_libtorrent_windows.ps1

cd app
flutter pub get
flutter build windows --release
.\build\windows\x64\runner\Release\open_torrent.exe
```

Engine line / About should show `OpenTorrent/0.2.1 libtorrent` — not `mock`. Do **not** pass `OPENTORRENT_MOCK` for live builds.

### Live engine (Android)

```powershell
.\scripts\build_libtorrent_android.ps1 -OnlyAbi arm64-v8a
.\scripts\package_release_android_live.ps1
# APK: dist\OpenTorrent-android-live.apk
# Requires Android 9+ (API 28), arm64 devices
```

### UI-only (mock engine — no native libtorrent)

```powershell
cd open-torrent\app
flutter pub get
flutter run -d windows --dart-define=OPENTORRENT_MOCK=true
```

### Native core tests (stub, no libtorrent)

```powershell
cd core
cmake -B build -S . -G "MinGW Makefiles" -DOPENTORRENT_USE_LIBTORRENT=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
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

## Maintainers

Co-maintained by [@nrzz](https://github.com/nrzz) and [@Dasprakash-Sekar](https://github.com/Dasprakash-Sekar). Shared access and workflow: [MAINTAINERS.md](MAINTAINERS.md).

## License

[GNU GPL v3](LICENSE). Third-party notices: [core/THIRD_PARTY.md](core/THIRD_PARTY.md).
