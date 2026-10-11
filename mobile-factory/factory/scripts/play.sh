#!/usr/bin/env bash
# Build the signed release bundle (.aab) and upload it to a Google Play track.
# Run by /play with ANDROID_PROJECT_DIR as the working directory and VERSION_CODE set.
#
# Signing: your upload key, kept outside the repo, via
#   ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
# (read by app/build.gradle.kts). Play App Signing holds the app signing key.
#
# Upload: fastlane's `supply`, with a Play Console service account key:
#   PLAY_JSON_KEY=/path/to/play-service-account.json   (Users and permissions → invite
#   the service account with "Release to testing tracks")
# Without fastlane or PLAY_JSON_KEY it stops after building and exits 3, so the
# bundle can be uploaded by hand. The very first upload of a new app must be
# manual anyway: Play only accepts API uploads once the app exists in the Console.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../config.sh
source "$REPO/factory/config.sh"
SETUP_CMD="$ANDROID_SETUP_CMD"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
: "${VERSION_CODE:?Set VERSION_CODE}"
for v in ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
  [[ -n ${!v:-} ]] || { echo "✗ $v is not set. Release bundles must be signed with the upload key." >&2; exit 1; }
done
[[ -f $ANDROID_KEYSTORE_PATH ]] || { echo "✗ No keystore at $ANDROID_KEYSTORE_PATH" >&2; exit 1; }

V="$(tr '[:lower:]' '[:upper:]' <<<"${VARIANT:0:1}")${VARIANT:1}"
RV="${V%Debug}Release"
OUT="$REPO/build/play"
rm -rf "$OUT"; mkdir -p "$OUT"
if [[ -n $SETUP_CMD ]]; then eval "$SETUP_CMD"; fi

echo "▸ Building $APP_MODULE:bundle$RV, version code $VERSION_CODE"
./gradlew --console=plain -q "$APP_MODULE:bundle$RV" -PversionCode="$VERSION_CODE"
m="${APP_MODULE#:}"
AAB="$(find "${m//://}/build/outputs/bundle" -name '*.aab' -newer "$OUT" | head -1)"
[[ -n $AAB ]] || { echo "✗ No .aab produced under ${m//://}/build/outputs/bundle" >&2; exit 1; }
cp "$AAB" "$OUT/"
AAB="$OUT/$(basename "$AAB")"
echo "  $AAB"

if [[ -z ${PLAY_JSON_KEY:-} ]] || ! command -v fastlane >/dev/null; then
  echo "▸ Not uploading: needs fastlane and PLAY_JSON_KEY. Upload $AAB in Play Console → Test and release → $PLAY_TRACK."
  exit 3
fi

echo "▸ Uploading to Google Play ($PLAY_TRACK track)"
fastlane run upload_to_play_store \
  package_name:"$APPLICATION_ID" aab:"$AAB" track:"$PLAY_TRACK" json_key:"$PLAY_JSON_KEY" \
  release_status:completed skip_upload_metadata:true skip_upload_images:true skip_upload_screenshots:true \
  skip_upload_changelogs:true

echo "✓ Uploaded version code $VERSION_CODE to $PLAY_TRACK"
