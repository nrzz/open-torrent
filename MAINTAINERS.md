# Maintainers

OpenTorrent is jointly maintained. Both maintainers have **admin** access to the repository (code, issues, PRs, releases, settings).

| GitHub | Role |
|--------|------|
| [@nrzz](https://github.com/nrzz) | Co-maintainer |
| [@Dasprakash-Sekar](https://github.com/Dasprakash-Sekar) | Co-maintainer |

## Shared workflow

1. **Accept the collaborator invite** (Dasprakash-Sekar): open https://github.com/nrzz/open-torrent/invitations and accept **Admin**.
2. Clone and push with your own credentials:

```powershell
git clone https://github.com/nrzz/open-torrent.git
cd open-torrent
git checkout -b feature/short-description
# ... work ...
git push -u origin HEAD
```

3. Prefer **pull requests into `main`** even for maintainers when the change is non-trivial — CI must stay green.
4. Either maintainer may review/merge PRs, cut releases (`v*`), and upload artifacts.
5. Tag releases only after `CHANGELOG.md` + `app/pubspec.yaml` version bumps.

## Permissions checklist (already granted)

- [x] Collaborator invite with **admin** (full access)
- [x] CODEOWNERS lists both maintainers
- [x] Security advisories: use GitHub Security Advisories (admins can triage)
- [x] Releases: either maintainer can publish via tag + `gh release`

## Communication

- Use GitHub Issues / Discussions for product decisions.
- Use PR review comments for code decisions.
- Security: [SECURITY.md](SECURITY.md) — private advisories only.
