# Contributing to OpenTorrent

Thanks for helping build a free, ad-free torrent client.

## Maintainers

This repo is co-maintained by [@nrzz](https://github.com/nrzz) and [@Dasprakash-Sekar](https://github.com/Dasprakash-Sekar) (both have admin access). See [MAINTAINERS.md](MAINTAINERS.md) for the shared workflow.

External contributors: fork → branch → PR. Maintainers: branch → PR (preferred) or direct push for trivial fixes.

## Ground rules

- Keep the app free of ads, trackers, telemetry, and paywalls.
- Prefer small, focused pull requests.
- Do **not** pass C++ types across the FFI boundary — only the flat C API in [`core/include/opentorrent.h`](core/include/opentorrent.h).
- Match existing style in each layer (C++ / Dart / Kotlin).

## Development setup

1. Install Flutter 3.22+, CMake 3.20+, and a C++17 toolchain.
2. On Windows, enable [Developer Mode](ms-settings:developers) (Flutter plugin symlinks).
3. Optional for real transfers: install [vcpkg](https://vcpkg.io/) and set `VCPKG_ROOT`.

```powershell
git clone https://github.com/nrzz/open-torrent.git
cd open-torrent\app
flutter pub get
flutter run -d windows --dart-define=OPENTORRENT_MOCK=true
```

### Mock vs native engine

| Goal | Command |
|------|---------|
| UI / integration without libtorrent | `--dart-define=OPENTORRENT_MOCK=true` |
| Link real libtorrent | Build `core/` with vcpkg (see [core/BUILD.md](core/BUILD.md)), place DLL next to the app |

## Testing

```powershell
# Native stub tests
cd core
cmake -B build -S . -DOPENTORRENT_USE_LIBTORRENT=OFF
cmake --build build
ctest --test-dir build --output-on-failure

# Flutter
cd ..\app
flutter test
flutter analyze --no-fatal-infos
```

CI runs the same checks on every push/PR (see `.github/workflows/ci.yml`).

## Pull requests

- Describe **why** the change exists.
- Include screenshots for UI changes.
- Keep CI green (core tests, Flutter tests, Android APK, Windows build).
- Update [CHANGELOG.md](CHANGELOG.md) for user-facing changes.
- Request review from a co-maintainer when the change is large (`@nrzz` / `@Dasprakash-Sekar`).

## Project docs

- [MAINTAINERS.md](MAINTAINERS.md) — co-maintainer access and release flow
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — design overview
- [packaging/README.md](packaging/README.md) — release / store packaging
- [SECURITY.md](SECURITY.md) — vulnerability reports

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
