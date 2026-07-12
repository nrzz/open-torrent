# OpenTorrent

Free, ad-free, open-source BitTorrent client for **Android** and **Windows**.

Built on [libtorrent-rasterbar](https://libtorrent.org/) with a single [Flutter](https://flutter.dev/) UI. No ads, no telemetry, no paywalls. GPLv3.

> **Legal notice:** OpenTorrent is a tool for transferring files via the BitTorrent protocol. You are responsible for ensuring that any content you download or share is lawful in your jurisdiction.

## Features

- Magnet links, `.torrent` files, and torrent URLs
- DHT, PEX, LSD, uTP, protocol encryption, BitTorrent v2
- File selection and priorities
- Session resume (survives restarts)
- Speed limits, connection limits, encryption modes
- Sequential download / streaming-friendly piece picking
- Bandwidth scheduler, SOCKS5 proxy, IP blocklists
- RSS auto-download with filters
- Categories, tags, queueing
- Android foreground downloads + notifications
- Windows tray, magnet/`.torrent` association, installer + portable zip

## Repository layout

```
core/          C++ C API wrapper around libtorrent
app/           Flutter application (Android + Windows)
packaging/     Inno Setup, winget, F-Droid metadata
.github/       CI and release workflows
```

## Building

### Prerequisites

- CMake 3.20+
- C++17 compiler (MSVC 2022+ / MinGW / NDK for Android)
- [vcpkg](https://vcpkg.io/) for libtorrent (optional for UI work — mock engine works without it)
- Flutter 3.22+
- Android SDK/NDK (for APK)
- **Windows:** enable [Developer Mode](ms-settings:developers) so Flutter can create plugin symlinks

### Native core (Windows, stub / no libtorrent)

```powershell
cd core
cmake -B build -S . -G "MinGW Makefiles" -DOPENTORRENT_USE_LIBTORRENT=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

### Native core with libtorrent (vcpkg + MSVC)

```powershell
.\scripts\build_libtorrent_windows.ps1
```

### Flutter app

```powershell
cd app
flutter pub get
flutter run -d windows --dart-define=OPENTORRENT_MOCK=true
# or
flutter build apk --release
flutter build windows --release
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [core/BUILD.md](core/BUILD.md) for details.

## Downloads

Primary distribution: [GitHub Releases](../../releases). Optional: F-Droid / winget (see `packaging/`).

## License

[GNU GPL v3](LICENSE). libtorrent-rasterbar is BSD-licensed; see third-party notices in `core/THIRD_PARTY.md`.
