# Architecture

OpenTorrent splits the BitTorrent engine from the UI so one Flutter codebase can ship Android and Windows builds.

```text
┌─────────────────────────────────────────┐
│  Flutter app (Dart)                     │
│  UI · settings · RSS · platform hooks   │
│                 │                       │
│         TorrentController               │
│           │           │                 │
│      MockEngine   Dart FFI              │
└───────────┼───────────┼─────────────────┘
            │           │
            │    ┌──────▼──────────┐
            │    │ opentorrent.h   │  flat C ABI
            │    │ (core/)         │
            │    └──────┬──────────┘
            │           │
            │    ┌──────▼──────────┐
            │    │ libtorrent 2.x  │
            │    └─────────────────┘
            ▼
     In-process stub (CI / UI without native DLL)
```

## Layers

1. **`core/`** — C++ session wrapper exposing a stable C API (`opentorrent.h`). Never pass C++ types across the FFI boundary.
2. **`app/lib/engine/`** — Dart models, FFI bindings, mock engine, and `TorrentController` (polling, resume, settings).
3. **`app/lib/ui/`** — Screens: list, detail, settings, RSS.
4. **`app/lib/platform/`** — Android foreground service bridge; Windows uses `window_manager` / `tray_manager`.

## Engine modes

| Mode | When | Behavior |
|------|------|----------|
| **Mock** | `OPENTORRENT_MOCK=true` or native DLL missing | Simulated progress for UI / CI |
| **Native** | `opentorrent_core` DLL/SO loadable | Real libtorrent session |

## Persistence

- Resume data under the app support directory (`resume/`)
- Session meta (settings, RSS, scheduler) in `session_meta.json`

## Platform notes

- **Android:** `DownloadService` foreground service, magnet/`.torrent` intents, Wi‑Fi-only pause via connectivity
- **Windows:** minimize-to-tray, optional Inno Setup associations (see `packaging/windows/`)

## Testing

- `core/tests` — C API edge cases (stub engine)
- `app/test` — validators, mock engine, widget smoke tests
