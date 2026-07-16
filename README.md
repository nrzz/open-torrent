# OpenTorrent

Free, ad-free, open-source BitTorrent client for **Android**, **Windows**, and **Linux**.

Built on [libtorrent-rasterbar](https://libtorrent.org/) with a single [Flutter](https://flutter.dev/) UI. No ads, no telemetry, no paywalls. Licensed under **GPLv3**.

> **Legal notice:** OpenTorrent transfers files with the BitTorrent protocol. You are responsible for using it only with content that is lawful in your jurisdiction.

## Status

| Platform | Artifact | Notes |
|----------|----------|--------|
| Windows | `OpenTorrent-windows-x64-live.zip` (+ Setup) | Live libtorrent; CI builds on tag |
| Android | `OpenTorrent-android-live.apk` | Live libtorrent arm64; CI builds on tag |
| Linux | `OpenTorrent-linux-x64-0.3.1.tar.gz` / `.deb` | Live libtorrent; magnet CLI + desktop MIME |

Latest builds: **[GitHub Releases](https://github.com/nrzz/open-torrent/releases)** — always verify `SHA256SUMS.txt`.

## Security (v0.3.1+)

- Hardened native C ABI + compiler flags (CFG / stack protector / RELRO)
- Absolute-path native library loading (anti DLL hijacking)
- HTTPS-first downloads, SSRF guards on RSS, size-capped HTTP
- Proxy passwords in OS secure storage (not plaintext JSON)
- Android: no cleartext, no backup of settings, validated intents

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
- Linux `.desktop` magnet / `.torrent` association

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

Engine line / About should show `OpenTorrent/0.3.1 libtorrent` — not `mock`. Do **not** pass `OPENTORRENT_MOCK` for live builds.

### Live engine (Android)

```powershell
.\scripts\build_libtorrent_android.ps1 -OnlyAbi arm64-v8a
.\scripts\package_release_android_live.ps1
# APK: dist\OpenTorrent-android-live.apk
# Requires Android 9+ (API 28), arm64 devices
```

### Live engine (Linux)

```bash
./scripts/build_libtorrent_linux.sh
./scripts/bundle_native_linux.sh
VERSION=0.3.1 ./scripts/package_release_linux.sh
./scripts/e2e_verify_linux.sh dist/OpenTorrent-linux-x64 --require-live
# Artifacts: dist/OpenTorrent-linux-x64-0.3.1.tar.gz and OpenTorrent_0.3.1_amd64.deb
# Magnets: `opentorrent 'magnet:?xt=urn:btih:...'` or click a magnet in the browser
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
cmake -B build -S . -DOPENTORRENT_USE_LIBTORRENT=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

Full native build notes: [core/BUILD.md](core/BUILD.md)

## Repository layout

```text
app/           Flutter UI (Android + Windows + Linux)
core/          C API around libtorrent (+ stub fallback)
scripts/       libtorrent / NDK / Linux build helpers
packaging/     Inno Setup, winget, Linux .desktop, F-Droid metadata
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
- Android SDK (for APK); Linux: GTK3 + clang
- [vcpkg](https://vcpkg.io/) when linking real libtorrent
- Windows: enable [Developer Mode](ms-settings:developers) for Flutter plugin symlinks

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Keep the app free of ads, trackers, and paywalls.

## Maintainers

Co-maintained by [@nrzz](https://github.com/nrzz) and [@Dasprakash-Sekar](https://github.com/Dasprakash-Sekar). Shared access and workflow: [MAINTAINERS.md](MAINTAINERS.md).

## License

[GNU GPL v3](LICENSE). Third-party notices: [core/THIRD_PARTY.md](core/THIRD_PARTY.md).
