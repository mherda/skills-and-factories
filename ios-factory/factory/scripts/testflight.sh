#!/usr/bin/env bash
# Archive a Release build and upload it to TestFlight. Run by /testflight with
# PROJECT_DIR as the working directory and BUILD_NUMBER set.
#
# Signing: either your Apple ID in Xcode (Settings → Accounts), or an App Store
# Connect API key (Users and Access → Integrations → Keys, role "App Manager").
# Keep the .p8 outside the repo and export:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../config.sh
source "$REPO/factory/config.sh"
: "${TEAM_ID:?Set TEAM_ID in factory/config.sh}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
OUT="$REPO/build/testflight"
ARCHIVE="$OUT/$SCHEME.xcarchive"

AUTH=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_ID:-}" ]]; then
  : "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (with ASC_KEY_ID)}"
  : "${ASC_KEY_PATH:?Set ASC_KEY_PATH (with ASC_KEY_ID)}"
  AUTH+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

rm -rf "$OUT"; mkdir -p "$OUT"
if [[ -n $SETUP_CMD ]]; then eval "$SETUP_CMD"; fi

echo "▸ Archiving $SCHEME build $BUILD_NUMBER"
xcodebuild archive "${XCODE_CONTAINER[@]}" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet "${AUTH[@]}"

cat >"$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST

echo "▸ Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" "${AUTH[@]}"

echo "✓ Uploaded build $BUILD_NUMBER"
