# Distribution

## GitHub Releases (primary)

1. Tag a version: `git tag v0.1.0 && git push origin v0.1.0`
2. The [Release workflow](../.github/workflows/release.yml) builds:
   - `OpenTorrent-windows-x64.zip` (portable)
   - `app-release.apk`
3. Optionally compile [Inno Setup](windows/opentorrent.iss) locally and attach `OpenTorrent-Setup-*.exe`.

## winget

Update SHA256 in [winget/OpenTorrent.OpenTorrent.yaml](winget/OpenTorrent.OpenTorrent.yaml) after the first release, then PR to `microsoft/winget-pkgs`.

## F-Droid

Fork `fdroiddata`, add [fdroid/org.opentorrent.open_torrent.yml](fdroid/org.opentorrent.open_torrent.yml), point `Repo`/`SourceCode` at your GitHub URL, and submit an MR.

## Auto-update

Desktop builds can check `https://api.github.com/repos/OWNER/open-torrent/releases/latest` (wire OWNER after publishing).
