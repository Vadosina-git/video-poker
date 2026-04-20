#!/usr/bin/env bash
# Upload a signed .ipa to App Store Connect / TestFlight via App Store Connect API key.
#
# Prerequisites:
#   1. .appstore.env in repo root (copy from .appstore.env.example, fill real values).
#      Gitignored — never commit.
#   2. API key .p8 file at $APP_STORE_API_KEY_PATH
#      (default: ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8).
#   3. Archive exported to .ipa from Xcode:
#        Product → Archive → Distribute App → App Store Connect → Export → .ipa
#      Typical output: build/ios/export/VideoPoker.ipa
#
# Usage:
#   ./scripts/upload_testflight.sh [path/to/VideoPoker.ipa]
#
# If path is omitted, defaults to build/ios/export/VideoPoker.ipa.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ENV_FILE=".appstore.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "error: $ENV_FILE not found. Copy .appstore.env.example → .appstore.env and fill values." >&2
    exit 1
fi
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

# Expand $HOME inside values that the env file stored literally.
APP_STORE_API_KEY_PATH="$(eval echo "$APP_STORE_API_KEY_PATH")"

: "${APP_STORE_ISSUER_ID:?APP_STORE_ISSUER_ID missing in $ENV_FILE}"
: "${APP_STORE_API_KEY_ID:?APP_STORE_API_KEY_ID missing in $ENV_FILE}"
: "${APP_STORE_API_KEY_PATH:?APP_STORE_API_KEY_PATH missing in $ENV_FILE}"

if [ ! -f "$APP_STORE_API_KEY_PATH" ]; then
    echo "error: API key file not found: $APP_STORE_API_KEY_PATH" >&2
    echo "Apple issues .p8 files only once — retrieve from 1Password or regenerate in App Store Connect." >&2
    exit 1
fi

IPA="${1:-build/ios/export/VideoPoker.ipa}"
if [ ! -f "$IPA" ]; then
    echo "error: .ipa not found at $IPA" >&2
    echo "Archive in Xcode first: Product → Archive → Distribute App → App Store Connect → Export." >&2
    exit 1
fi

# altool looks up API keys in one of four locations. We use ~/.appstoreconnect/private_keys.
KEY_DIR="$(dirname "$APP_STORE_API_KEY_PATH")"
if [[ "$KEY_DIR" != *"/private_keys" ]]; then
    echo "warn: API key not in a standard private_keys/ directory — altool may not find it." >&2
fi

echo "Uploading $IPA to TestFlight…"
echo "  Issuer: $APP_STORE_ISSUER_ID"
echo "  Key ID: $APP_STORE_API_KEY_ID"
echo "  Key:    $APP_STORE_API_KEY_PATH"
echo ""

xcrun altool --upload-app \
    --file "$IPA" \
    --type ios \
    --apiKey "$APP_STORE_API_KEY_ID" \
    --apiIssuer "$APP_STORE_ISSUER_ID"

echo ""
echo "✓ Upload submitted. Processing takes ~5–30 min."
echo "Track status: https://appstoreconnect.apple.com → My Apps → TestFlight → Builds."
