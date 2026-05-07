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

# Auto-bump version/code (Play Console rejects duplicates with 400). Mirrors
# the iOS pipeline (CURRENT_PROJECT_VERSION bump in build/ios). Override by
# setting BUMP_VERSION=0 in the environment if you need to rebuild the same
# version code (e.g. test build that won't be uploaded).
if [ "${BUMP_VERSION:-1}" = "1" ]; then
    CURRENT_CODE=$(grep -m1 "^version/code=" export_presets.cfg | cut -d= -f2)
    NEXT_CODE=$((CURRENT_CODE + 1))
    sed -i '' "s|^version/code=.*|version/code=$NEXT_CODE|" export_presets.cfg
    echo "version/code: $CURRENT_CODE → $NEXT_CODE"
fi

# Backup AFTER bump so revert preserves the new version/code while wiping
# only the secrets we injected next.
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
