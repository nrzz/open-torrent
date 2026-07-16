#!/usr/bin/env bash
# scripts/e2e_verify_linux.sh — smoke-check Linux bundle
# Usage:
#   ./scripts/e2e_verify_linux.sh [bundle_dir] [--require-live]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${1:-$ROOT/app/build/linux/x64/release/bundle}"
REQUIRE_LIVE=0
for a in "$@"; do
  [[ "$a" == "--require-live" ]] && REQUIRE_LIVE=1
done

BIN="$BUNDLE/open_torrent"
SO="$BUNDLE/lib/libopentorrent_core.so"

if [[ ! -x "$BIN" && ! -f "$BIN" ]]; then
  echo "FAIL: missing executable $BIN (build linux first)" >&2
  exit 1
fi
chmod +x "$BIN" 2>/dev/null || true

if [[ -f "$SO" ]]; then
  echo "ok: live .so present ($SO)"
  if command -v strings >/dev/null 2>&1; then
    if strings "$SO" | grep -q 'libtorrent'; then
      echo "ok: libtorrent string in .so"
    else
      echo "FAIL: libtorrent string missing from .so" >&2
      exit 1
    fi
    if strings "$SO" | grep -q 'OpenTorrent/'; then
      echo "ok: OpenTorrent version string in .so"
    else
      echo "WARN: OpenTorrent version string not found in .so"
    fi
  fi
  if command -v ldd >/dev/null 2>&1; then
    if ldd "$SO" 2>/dev/null | grep -qi 'not found'; then
      echo "FAIL: unresolved deps for libopentorrent_core.so:" >&2
      ldd "$SO" || true
      exit 1
    fi
    echo "ok: ldd for core .so"
  fi
elif [[ "$REQUIRE_LIVE" -eq 1 ]]; then
  echo "FAIL: --require-live but $SO missing" >&2
  exit 1
else
  echo "ok: mock mode (no .so)"
fi

if command -v file >/dev/null 2>&1; then
  file "$BIN" | grep -qi elf && echo "ok: ELF binary"
fi
if command -v ldd >/dev/null 2>&1; then
  ldd "$BIN" >/dev/null && echo "ok: ldd resolves binary"
fi

echo "E2E Linux smoke passed"
