#!/usr/bin/env bash
# Build a signed Android release APK.
#
# Credentials come from .keystore.env (gitignored). This script injects them
# into export_presets.cfg just for the export run and reverts the file
# afterwards so secrets never land in git.
#
# Usage: ./scripts/build_android_release.sh [output_path]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f .keystore.env ]; then
    echo "error: .keystore.env not found in project root" >&2
    echo "       create it with ANDROID_KEYSTORE_PATH / USER / PASSWORD" >&2
    exit 1
fi

# shellcheck disable=SC1091
source .keystore.env
: "${ANDROID_KEYSTORE_PATH:?ANDROID_KEYSTORE_PATH required}"
: "${ANDROID_KEYSTORE_USER:?ANDROID_KEYSTORE_USER required}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD required}"

OUTPUT="${1:-build/video_poker_release.aab}"
mkdir -p "$(dirname "$OUTPUT")"

# Backup clean preset
cp export_presets.cfg export_presets.cfg.bak
trap 'mv -f export_presets.cfg.bak export_presets.cfg' EXIT

# Inject credentials (macOS sed)
sed -i '' \
    -e "s|keystore/release=\"\"|keystore/release=\"${ANDROID_KEYSTORE_PATH}\"|" \
    -e "s|keystore/release_user=\"\"|keystore/release_user=\"${ANDROID_KEYSTORE_USER}\"|" \
    -e "s|keystore/release_password=\"\"|keystore/release_password=\"${ANDROID_KEYSTORE_PASSWORD}\"|" \
    export_presets.cfg

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . --export-release "Android" "$OUTPUT"

echo ""
echo "✓ Release AAB built: $OUTPUT"
