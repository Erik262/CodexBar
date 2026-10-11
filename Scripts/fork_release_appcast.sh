#!/usr/bin/env bash
# Zips a packaged CodexBar.app, signs the archive with an Ed25519 key (Sparkle's EdDSA), and writes a
# one-item appcast.xml next to it. Used by .github/workflows/fork-release.yml for fork releases.
#
# Usage: fork_release_appcast.sh <CodexBar.app> <release-tag> <ed25519-private-key.pem> <out-dir>
# Needs GITHUB_REPOSITORY (owner/repo) to build the download URL.
set -euo pipefail

APP="${1:?app bundle path}"
TAG="${2:?release tag}"
KEY="${3:?ed25519 private key (PEM)}"
OUT="${4:?output directory}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY (owner/repo)}"

OPENSSL="openssl"
if command -v brew >/dev/null 2>&1 && [[ -x "$(brew --prefix openssl@3 2>/dev/null)/bin/openssl" ]]; then
  OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
fi

plist="$APP/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")
short_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
minimum_system=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$plist" 2>/dev/null || echo "")

mkdir -p "$OUT"
archive_name="CodexBar-${TAG}.zip"
archive="$OUT/$archive_name"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$archive"

# Sparkle verifies an Ed25519 signature over the raw archive bytes.
signature=$("$OPENSSL" pkeyutl -sign -rawin -inkey "$KEY" -in "$archive" | base64 | tr -d '\n')
length=$(stat -f%z "$archive")
url="https://github.com/${REPO}/releases/download/${TAG}/${archive_name}"
pub_date=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")
minimum_tag=""
if [[ -n "$minimum_system" ]]; then
  minimum_tag="<sparkle:minimumSystemVersion>${minimum_system}</sparkle:minimumSystemVersion>"
fi

cat > "$OUT/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>CodexBar (${REPO})</title>
    <item>
      <title>${short_version} (${TAG})</title>
      <link>https://github.com/${REPO}/releases/tag/${TAG}</link>
      <sparkle:releaseNotesLink>https://github.com/${REPO}/releases/tag/${TAG}</sparkle:releaseNotesLink>
      <pubDate>${pub_date}</pubDate>
      <sparkle:version>${version}</sparkle:version>
      <sparkle:shortVersionString>${short_version}</sparkle:shortVersionString>
      ${minimum_tag}
      <enclosure url="${url}" length="${length}" type="application/octet-stream" sparkle:edSignature="${signature}"/>
    </item>
  </channel>
</rss>
XML

echo "Wrote $archive (${length} bytes) and $OUT/appcast.xml for ${short_version} (${version})."
