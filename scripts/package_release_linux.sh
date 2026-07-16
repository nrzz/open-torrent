#!/usr/bin/env bash
# scripts/package_release_linux.sh — build portable tar.gz + .deb for OpenTorrent Linux
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
VERSION="${VERSION:-0.3.1}"
mkdir -p "$DIST"

# Prefer live engine if natives exist; otherwise mock for CI smoke.
MOCK_FLAG=""
if [[ ! -f "$ROOT/app/linux/native/libopentorrent_core.so" ]]; then
  echo "WARN: no native .so — building with OPENTORRENT_MOCK=true"
  MOCK_FLAG="--dart-define=OPENTORRENT_MOCK=true"
fi

pushd "$ROOT/app" >/dev/null
flutter pub get
# shellcheck disable=SC2086
flutter build linux --release $MOCK_FLAG
popd >/dev/null

BUNDLE="$ROOT/app/build/linux/x64/release/bundle"
STAGE="$DIST/OpenTorrent-linux-x64"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -a "$BUNDLE/." "$STAGE/"
cp "$ROOT/packaging/linux/opentorrent.desktop" "$STAGE/" 2>/dev/null || true

# Optional: copy icon next to portable bundle for convenience
if [[ -f "$ROOT/packaging/linux/icons/hicolor/256x256/apps/opentorrent.png" ]]; then
  mkdir -p "$STAGE/share/icons/hicolor/256x256/apps"
  cp "$ROOT/packaging/linux/icons/hicolor/256x256/apps/opentorrent.png" \
    "$STAGE/share/icons/hicolor/256x256/apps/"
fi

TAR="$DIST/OpenTorrent-linux-x64-${VERSION}.tar.gz"
tar -C "$DIST" -czf "$TAR" "OpenTorrent-linux-x64"
echo "Wrote $TAR"

# .deb package
DEB_ROOT="$DIST/deb-root"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN" \
  "$DEB_ROOT/usr/lib/opentorrent" \
  "$DEB_ROOT/usr/bin" \
  "$DEB_ROOT/usr/share/applications" \
  "$DEB_ROOT/usr/share/mime/packages" \
  "$DEB_ROOT/usr/share/icons/hicolor/128x128/apps" \
  "$DEB_ROOT/usr/share/icons/hicolor/256x256/apps"

cp -a "$STAGE/." "$DEB_ROOT/usr/lib/opentorrent/"
# Avoid shipping portable-only desktop file under /usr/lib
rm -f "$DEB_ROOT/usr/lib/opentorrent/opentorrent.desktop"

cat > "$DEB_ROOT/usr/bin/opentorrent" <<'EOF'
#!/bin/sh
exec /usr/lib/opentorrent/open_torrent "$@"
EOF
chmod 755 "$DEB_ROOT/usr/bin/opentorrent"

cp "$ROOT/packaging/linux/opentorrent.desktop" "$DEB_ROOT/usr/share/applications/"
cp "$ROOT/packaging/linux/opentorrent-mime.xml" "$DEB_ROOT/usr/share/mime/packages/" 2>/dev/null || true

ICON_SRC="$ROOT/packaging/linux/icons/hicolor"
if [[ -d "$ICON_SRC" ]]; then
  cp -a "$ICON_SRC/." "$DEB_ROOT/usr/share/icons/hicolor/"
fi

cp "$ROOT/packaging/linux/postinst" "$DEB_ROOT/DEBIAN/postinst"
cp "$ROOT/packaging/linux/postrm" "$DEB_ROOT/DEBIAN/postrm"
chmod 755 "$DEB_ROOT/DEBIAN/postinst" "$DEB_ROOT/DEBIAN/postrm"

cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: opentorrent
Version: ${VERSION}
Section: net
Priority: optional
Architecture: amd64
Maintainer: OpenTorrent Maintainers <maintainers@opentorrent.local>
Depends: libgtk-3-0, libsecret-1-0, libayatana-appindicator3-1
Description: Free, ad-free BitTorrent client (libtorrent + Flutter)
 OpenTorrent is an open-source BitTorrent client for Linux.
EOF

DEB="$DIST/OpenTorrent_${VERSION}_amd64.deb"
dpkg-deb --build "$DEB_ROOT" "$DEB"
echo "Wrote $DEB"
