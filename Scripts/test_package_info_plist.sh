#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE_SCRIPT="$ROOT/Scripts/package_app.sh"
PLIST_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/codexbar-package-info-plist-script.XXXXXX")
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/codexbar-package-info-plist.XXXXXX")
trap 'rm -f "$PLIST_SCRIPT"; rm -rf "$TEMP_DIR"' EXIT

python3 - "$PACKAGE_SCRIPT" "$PLIST_SCRIPT" <<'PY'
import sys
from pathlib import Path

script = Path(sys.argv[1]).read_text()
start = script.index('cat > "$APP/Contents/Info.plist" <<PLIST')
end = script.index('\nPLIST\n', start) + len('\nPLIST\n')
Path(sys.argv[2]).write_text(script[start:end])
PY

APP="$TEMP_DIR/CodexBar.app"
mkdir -p "$APP/Contents"
BUNDLE_ID=com.steipete.codexbar.test
MARKETING_VERSION=0.0.0
BUILD_NUMBER=0
FEED_URL=https://example.invalid/appcast.xml
AUTO_CHECKS=false
BUILD_TIMESTAMP=2026-01-01T00:00:00Z
GIT_COMMIT=test
APP_TEAM_ID=TESTTEAM
source "$PLIST_SCRIPT"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$APP/Contents/Info.plist"
fi
python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

plist = plistlib.loads(Path(sys.argv[1]).read_bytes())
declarations = plist.get("UTExportedTypeDeclarations")
assert declarations == [{
    "UTTypeIdentifier": "com.steipete.codexbar.menu-layout-item",
    "UTTypeDescription": "CodexBar menu bar layout token",
    "UTTypeConformsTo": ["public.data"],
    "UTTypeTagSpecification": {},
}]
PY

python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

plist = plistlib.loads(Path(sys.argv[1]).read_bytes())
assert plist["SUPublicEDKey"] == "AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI="
assert "CodexBarAllowsAdHocUpdates" not in plist
PY

# A fork build can point at its own appcast and EdDSA key and opt ad-hoc signed builds into updates.
CODEXBAR_SPARKLE_PUBLIC_KEY=Zm9ya2tleQ== CODEXBAR_ALLOW_ADHOC_UPDATES=1 source "$PLIST_SCRIPT"
python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

plist = plistlib.loads(Path(sys.argv[1]).read_bytes())
assert plist["SUPublicEDKey"] == "Zm9ya2tleQ=="
assert plist["SUFeedURL"] == "https://example.invalid/appcast.xml"
assert plist["CodexBarAllowsAdHocUpdates"] is True
PY

echo "Package Info.plist tests passed."
