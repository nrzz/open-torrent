# Distribution

Primary channel: **[GitHub Releases](https://github.com/nrzz/open-torrent/releases)**.

## Cutting a release

1. Update [CHANGELOG.md](../CHANGELOG.md) and bump `version` in [`app/pubspec.yaml`](../app/pubspec.yaml).
2. Build artifacts locally (recommended for live Windows):

```powershell
# Windows live (libtorrent)
.\scripts\package_release_windows_live.ps1

# Android APK (requires Android SDK)
cd app
flutter build apk --release --dart-define=OPENTORRENT_MOCK=true
copy build\app\outputs\flutter-apk\app-release.apk ..\dist\OpenTorrent-android.apk
```

3. Tag and push, then attach release assets:

```powershell
git tag v0.2.0
git push origin v0.2.0
gh release upload v0.2.0 dist\OpenTorrent-windows-x64-live.zip dist\OpenTorrent-android.apk --clobber
```

4. The [Release workflow](../.github/workflows/release.yml) also builds CI Windows zip + Android APK on tag push.

## Windows installer (optional)

Compile [`windows/opentorrent.iss`](windows/opentorrent.iss) with [Inno Setup](https://jrsoftware.org/isinfo.php) after a release build, then attach `OpenTorrent-Setup-*.exe` to the release.

## winget

1. After a tagged release, fill in `InstallerSha256` in [`winget/OpenTorrent.OpenTorrent.yaml`](winget/OpenTorrent.OpenTorrent.yaml).
2. Open a PR against [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs).

## F-Droid

1. Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata).
2. Add [`fdroid/org.opentorrent.open_torrent.yml`](fdroid/org.opentorrent.open_torrent.yml) under `metadata/`.
3. Submit a merge request.

## In-app update check

Desktop settings can query:

`https://api.github.com/repos/nrzz/open-torrent/releases/latest`
