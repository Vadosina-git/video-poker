#!/usr/bin/env bash
# Upload a signed Android AAB to Google Play Console via fastlane supply.
#
# Credentials come from .googleplay.env (gitignored). The service account JSON
# key referenced by GOOGLE_PLAY_JSON_KEY_PATH must be downloaded from Google
# Cloud Console and granted access in Play Console → Setup → API access.
#
# Prerequisites:
#   - First AAB for this app already uploaded MANUALLY through Play Console UI
#     (Google rejects API uploads for apps with no prior release).
#   - fastlane installed (`gem install fastlane`).
#
# Usage: ./scripts/upload_googleplay.sh [aab_path]
#   aab_path defaults to build/video_poker_release.aab

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f .googleplay.env ]; then
    echo "error: .googleplay.env not found in project root" >&2
    echo "       see .googleplay.env.example for required vars." >&2
    echo "       see docs/ANDROID_UPLOAD.md §4 for setup steps." >&2
    exit 1
fi

# shellcheck disable=SC1091
source .googleplay.env
: "${GOOGLE_PLAY_JSON_KEY_PATH:?GOOGLE_PLAY_JSON_KEY_PATH required}"
: "${GOOGLE_PLAY_PACKAGE_NAME:?GOOGLE_PLAY_PACKAGE_NAME required}"
: "${GOOGLE_PLAY_TRACK:=internal}"

if [ ! -f "$GOOGLE_PLAY_JSON_KEY_PATH" ]; then
    echo "error: service account JSON not found at: $GOOGLE_PLAY_JSON_KEY_PATH" >&2
    exit 1
fi

if ! command -v fastlane >/dev/null 2>&1; then
    echo "error: fastlane not installed" >&2
    echo "       run: gem install fastlane" >&2
    exit 1
fi

AAB="${1:-build/video_poker_release.aab}"
if [ ! -f "$AAB" ]; then
    echo "error: AAB not found at: $AAB" >&2
    echo "       run ./scripts/build_android_release.sh first." >&2
    exit 1
fi

echo "Uploading $AAB to Google Play…"
echo "  package:  $GOOGLE_PLAY_PACKAGE_NAME"
echo "  track:    $GOOGLE_PLAY_TRACK"
echo "  json key: $GOOGLE_PLAY_JSON_KEY_PATH"
echo

# fastlane supply uploads to the named track. --skip-upload-* flags suppress
# everything we don't want to touch (metadata, screenshots, changelogs are
# managed manually in the Play Console UI; here we ONLY ship the binary).
fastlane supply \
    --aab "$AAB" \
    --package_name "$GOOGLE_PLAY_PACKAGE_NAME" \
    --json_key "$GOOGLE_PLAY_JSON_KEY_PATH" \
    --track "$GOOGLE_PLAY_TRACK" \
    --skip_upload_metadata true \
    --skip_upload_changelogs true \
    --skip_upload_images true \
    --skip_upload_screenshots true \
    --release_status "draft"

echo
echo "✓ Upload submitted. Open Play Console to promote:"
echo "  https://play.google.com/console → ${GOOGLE_PLAY_PACKAGE_NAME} → Testing → ${GOOGLE_PLAY_TRACK}"
