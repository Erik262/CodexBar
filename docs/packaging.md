---
summary: "Packaging, signing, and bundled CLI notes."
read_when:
  - Packaging/signing builds
  - Updating bundle layout or CLI bundling
---

# Packaging & signing

## Scripts
- `Scripts/package_app.sh`: builds host arch with ad-hoc signing by default; set `ARCHES="arm64 x86_64"` for universal. Verifies slices. Stable-certificate packaging requires explicit `CODEXBAR_SIGNING=identity` plus `APP_IDENTITY`.
- The bundled Developer ID provisioning profile and CloudKit entitlements apply only to upstream-team release builds. An alternate resolved `APP_TEAM_ID` retains its matching app/widget groups without that upstream profile; direct callers remain responsible for selecting a team consistent with their identity.
- `Scripts/compile_and_run.sh`: uses host arch; pass `--release-universal` or `--release-arches="arm64 x86_64"` for release packaging.
- `Scripts/compile_and_run.sh --fast`: debug build (incremental, much quicker after the first run) and skips the widget extension. Use it for day-to-day UI work; use the default release build before shipping.
- `Scripts/sign-and-notarize.sh`: explicitly selects Developer ID signing, notarizes, staples, and zips (accepts `ARCHES` for universal).
- `Scripts/make_appcast.sh`: wrapper around the shared `mac-release make-appcast` helper; app metadata comes from `.mac-release.env`.
- `Scripts/changelog-to-html.sh`: converts the per-version changelog section to HTML for Sparkle.
- `Scripts/verify_packaged_app_launch.sh`: checks resource loading and AppKit liveness with a temporary home, disabled synthetic provider config, no inherited credentials, test-safe background work, and a sandbox guard against writes to the real home directory.

## Bundle contents
- `CodexBarWidget.appex` is built by `WidgetExtension/CodexBarWidgetExtension.xcodeproj` as a real macOS app extension, then bundled with app-group entitlements.
- When updating dependencies, refresh both the root `Package.resolved` and the widget workspace's `Package.resolved`, and verify their pinned revisions agree. Packaging deliberately disables automatic dependency resolution.
- `CodexBarCLI` copied to `CodexBar.app/Contents/Helpers/` for symlinking.
- SwiftPM resource bundles (e.g. `KeyboardShortcuts_KeyboardShortcuts.bundle`) copied into `Contents/Resources` (required for `KeyboardShortcuts.Recorder`).

## Releases
- Full checklist in `docs/RELEASING.md`.

## Fork update feeds
Official builds are unchanged; these variables are only read when set. A fork that publishes its own releases can
point its builds at its own appcast without a Developer ID certificate:
- `CODEXBAR_FEED_URL`: appcast URL written to `SUFeedURL` (e.g. `https://github.com/<owner>/CodexBar/releases/latest/download/appcast.xml`).
- `CODEXBAR_SPARKLE_PUBLIC_KEY`: base64 Ed25519 public key written to `SUPublicEDKey`; sign each update zip with the matching private key.
- `CODEXBAR_ALLOW_ADHOC_UPDATES=1`: keeps the feed for ad-hoc signed builds and sets `CodexBarAllowsAdHocUpdates`, so
  `SparkleUpdatePolicy` enables Sparkle without Developer ID. Updates are still verified against the EdDSA key.
- `CODEXBAR_BUILD_NUMBER`: overrides `BUILD_NUMBER` from `version.env` so each fork release has a higher `CFBundleVersion`.

See also: `docs/sparkle.md`.
