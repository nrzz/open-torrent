# Flutter app (`open_torrent`)

Cross-platform UI for OpenTorrent (Android + Windows).

## Commands

```powershell
flutter pub get
flutter test
flutter analyze
flutter run -d windows --dart-define=OPENTORRENT_MOCK=true
flutter build apk --release --dart-define=OPENTORRENT_MOCK=true
flutter build windows --release --dart-define=OPENTORRENT_MOCK=true
```

## Layout

```text
lib/
  engine/     FFI bindings, mock engine, TorrentController
  ui/         Screens
  platform/   Android service bridge
  util/       Formatting, magnet validation, update check
android/      APK project + DownloadService
windows/      Desktop runner
test/         Unit / widget / e2e-style tests
```

See the [root README](../README.md) and [architecture notes](../docs/ARCHITECTURE.md).
