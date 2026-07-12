# Contributing to OpenTorrent

Thanks for helping build a free, ad-free torrent client.

## Ground rules

- Keep the app free of ads, trackers, and paywalls.
- Prefer small, focused PRs.
- Do not pass C++ types across the FFI boundary — only the flat C API in `core/include/opentorrent.h`.
- Match existing code style in each layer (C++ / Dart).

## Development setup

1. Install Flutter, CMake, a C++ toolchain, and vcpkg.
2. Set `VCPKG_ROOT` and install packages:

```text
vcpkg install libtorrent:x64-windows openssl:x64-windows
```

3. Build `core/` then `app/` as described in the README.

### Mock engine mode

If libtorrent is not built yet, the Flutter app can run with `--dart-define=OPENTORRENT_MOCK=true` for UI work.

## Testing

```powershell
cd core && ctest --test-dir build
cd app && flutter test
```

## Pull requests

- Describe *why* the change exists.
- Include screenshots for UI changes.
- Ensure CI is green.

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
