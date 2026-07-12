# Distribution

Primary channel: **[GitHub Releases](https://github.com/nrzz/open-torrent/releases)**.

## Cutting a release

1. Update [CHANGELOG.md](../CHANGELOG.md) and bump `version` in [`app/pubspec.yaml`](../app/pubspec.yaml).
2. Commit, then tag and push:

```powershell
git tag v0.1.1
git push origin v0.1.1
```

3. The [Release workflow](../.github/workflows/release.yml) builds independently:
   - `OpenTorrent-windows-x64.zip`
   - `app-release.apk`  
   and attaches both to the GitHub Release.

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
