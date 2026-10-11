# Fork updates

Builds of this fork can update themselves through Sparkle from the fork's own GitHub releases, without a
Developer ID. Publishing a release runs `.github/workflows/fork-release.yml`, which builds the app, signs
the archive with the fork's Ed25519 key, and attaches `CodexBar-<tag>.zip` plus `appcast.xml` to the
release. Installed builds check `releases/latest/download/appcast.xml`.

Upstream (`steipete/CodexBar`) skips the workflow, and builds made without the variables below keep the
upstream feed and signing rules.

## One-time setup

1. Create a signing key on your Mac and keep the file private:

   ```bash
   brew install openssl@3
   "$(brew --prefix openssl@3)/bin/openssl" genpkey -algorithm ed25519 -out ~/codexbar-sparkle.pem
   ```

2. Add it as the repository secret `SPARKLE_ED25519_PEM` (Settings → Secrets and variables → Actions),
   pasting the whole file, or run `gh secret set SPARKLE_ED25519_PEM < ~/codexbar-sparkle.pem`.

Losing the key means installed builds reject later updates; reinstall manually with a new key.

## Shipping an update

1. Merge your changes into `main`.
2. Publish a GitHub release with a new tag, for example `v0.74.1-fork.1`.
3. Wait for the "Fork release" workflow; it attaches the zip and `appcast.xml` to the release.

Alternatively, run "Fork release" from the Actions tab on `main` with a new tag: it builds that commit and
creates the release itself.

The build number is `BUILD_NUMBER` from `version.env` plus the workflow run number (for example
`167.12`), so every release is newer than the previous one and than a local build of the same version.
The build targets Apple silicon (`ARCHES=arm64`).

## First install

Download the zip from the release, unzip it, and move `CodexBar.app` to `/Applications`. The app is
ad-hoc signed and not notarized, so open it once with Control-click → Open (or allow it under System
Settings → Privacy & Security). After that, Sparkle installs new releases from the menu's update check or
automatically.

Builds from `./Scripts/compile_and_run.sh` stay local: they have no feed and never update themselves.

## Notes

- Ad-hoc signatures change with every build, so macOS may ask again for Keychain access after an update.
- Publishing a release also runs the upstream `release-cli` and `release-linux-desktop` workflows.
- Packaging variables: `CODEXBAR_FEED_URL`, `CODEXBAR_SPARKLE_PUBLIC_KEY`, `CODEXBAR_ALLOW_ADHOC_UPDATES=1`,
  and `CODEXBAR_BUILD_NUMBER` (see `Scripts/package_app.sh`).
