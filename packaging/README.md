# Distribution

Primary channel: **[GitHub Releases](https://github.com/nrzz/open-torrent/releases)**.

Tagged releases (`v*`) run [`.github/workflows/release.yml`](../.github/workflows/release.yml), which builds **live** libtorrent artifacts for Windows, Android, and Linux, then uploads them with `SHA256SUMS.txt`.

## Cutting a release

1. Update [CHANGELOG.md](../CHANGELOG.md) and bump `version` in [`app/pubspec.yaml`](../app/pubspec.yaml) (keep core `ot_version` / user-agent in sync).
2. Push to `main`, then tag:

```bash
git tag v0.3.1
git push origin v0.3.1
```

3. Wait for the Release workflow (`linux-live`, `windows-live`, `android-live`, `publish`). Confirm assets:

- `OpenTorrent-windows-x64-live.zip` (+ `OpenTorrent-Setup-0.3.1.exe` when Inno builds)
- `OpenTorrent-android-live.apk`
- `OpenTorrent-linux-x64-0.3.1.tar.gz`
- `OpenTorrent_0.3.1_amd64.deb`
- `SHA256SUMS.txt`

### Local live builds (optional)

```powershell
# Windows
.\scripts\build_libtorrent_windows.ps1
.\scripts\package_release_windows_live.ps1
.\scripts\e2e_verify_windows_live.ps1

# Android
.\scripts\build_libtorrent_android.ps1 -OnlyAbi arm64-v8a
.\scripts\package_release_android_live.ps1
.\scripts\e2e_verify_android_live.ps1
```

```bash
# Linux
./scripts/build_libtorrent_linux.sh
./scripts/bundle_native_linux.sh
VERSION=0.3.1 ./scripts/package_release_linux.sh
./scripts/e2e_verify_linux.sh dist/OpenTorrent-linux-x64 --require-live
```

## Windows installer (optional)

Compile [`windows/opentorrent.iss`](windows/opentorrent.iss) with [Inno Setup](https://jrsoftware.org/isinfo.php) after a release build (also attempted in CI via Chocolatey).

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
