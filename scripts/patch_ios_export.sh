#!/usr/bin/env bash
# Post-export patcher for iOS: Godot overwrites Info.plist and PrivacyInfo.xcprivacy
# on every export. This script re-applies our App Store-ready modifications:
#   - Info.plist: both landscape orientations on iPhone + iPad; drops empty
#     usage descriptions; declares arm64 capability.
#   - PrivacyInfo.xcprivacy: includes NSPrivacyAccessedAPICategoryUserDefaults
#     (required by Godot's internal storage); declares no tracking / no data.
#
# Run AFTER every `Godot --export-release iOS`:
#   ./scripts/build_android_release.sh
#   Godot --headless --path . --export-release "iOS" build/ios/VideoPoker.xcodeproj
#   ./scripts/patch_ios_export.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

INFO_PLIST="build/ios/VideoPoker/VideoPoker-Info.plist"
PRIVACY="build/ios/PrivacyInfo.xcprivacy"

if [ ! -f "$INFO_PLIST" ]; then
    echo "error: $INFO_PLIST not found. Run iOS export first." >&2
    exit 1
fi

# -- 1. Patch Info.plist --
python3 <<'PY'
import plistlib
from pathlib import Path

path = Path("build/ios/VideoPoker/VideoPoker-Info.plist")
# Read with xml mode (Godot emits XML)
raw = path.read_bytes()
data = plistlib.loads(raw)

# Both landscapes on iPhone + iPad.
data["UISupportedInterfaceOrientations"] = [
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
]
data["UISupportedInterfaceOrientations~ipad"] = [
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
]

# Drop empty usage descriptions (Apple flags these even when blank).
for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
            "NSMicrophoneUsageDescription"):
    data.pop(key, None)

# Declare arm64 device capability (replaces empty array).
data["UIRequiredDeviceCapabilities"] = ["arm64"]

path.write_bytes(plistlib.dumps(data))
print(f"✓ Patched {path}")
PY

# -- 2. Replace PrivacyInfo.xcprivacy with App Store-ready version --
cat > "$PRIVACY" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>DDA9.1</string>
				<string>C617.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategorySystemBootTime</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>35F9.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryDiskSpace</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>E174.1</string>
				<string>85F4.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF
echo "✓ Patched $PRIVACY"

echo ""
echo "iOS export patched. Now open build/ios/VideoPoker.xcodeproj in Xcode."
