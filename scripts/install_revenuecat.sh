#!/usr/bin/env bash
# Install / refresh the Godotx RevenueCat plugin binaries.
#
# The GDScript side of the plugin lives in addons/godotx_revenue_cat/ and is
# committed to the repo. Native iOS and Android binaries are NOT committed
# (iOS xcframeworks are ~850MB total) — this script downloads them from the
# plugin's GitHub release and places them where Godot expects.
#
# Usage: ./scripts/install_revenuecat.sh [version]
#   version defaults to 2.1.0
#
# Run once per dev machine, and again if upgrading the plugin.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

VERSION="${1:-2.1.0}"
ZIP_URL="https://github.com/godot-x/revenuecat/releases/download/${VERSION}/godotx_revenue_cat.zip"
WORK_DIR=".godot_cache/revenuecat_install"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "→ downloading godotx_revenue_cat v${VERSION}..."
curl -sfL "$ZIP_URL" -o plugin.zip
echo "  $(ls -lh plugin.zip | awk '{print $5}')"

echo "→ extracting..."
rm -rf extracted
unzip -qo plugin.zip -d extracted

cd "$PROJECT_ROOT"

echo "→ copying addons/ (GDScript plugin)..."
rm -rf addons/godotx_revenue_cat
cp -r "$WORK_DIR/extracted/godotx_revenue_cat/addons/godotx_revenue_cat" addons/

echo "→ copying android/revenue_cat/ (AAR binaries)..."
mkdir -p android
rm -rf android/revenue_cat
cp -r "$WORK_DIR/extracted/godotx_revenue_cat/android/revenue_cat" android/

echo "→ copying ios/plugins/revenue_cat/ (xcframeworks, large)..."
mkdir -p ios/plugins
rm -rf ios/plugins/revenue_cat
cp -r "$WORK_DIR/extracted/godotx_revenue_cat/ios/plugins/revenue_cat" ios/plugins/

echo ""
echo "✓ RevenueCat plugin installed (v${VERSION})"
echo ""
echo "Next steps:"
echo "  1. Open project in Godot editor"
echo "  2. Project → Project Settings → Plugins → enable 'Godotx RevenueCat'"
echo "  3. In Android export preset, enable 'GodotxRevenueCat' in plugins list"
echo "  4. In iOS export preset, enable 'GodotxRevenueCat' in plugins list"
echo "  5. Fill in RC_API_KEY_IOS / RC_API_KEY_ANDROID in scripts/iap_manager.gd"
