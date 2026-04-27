#!/usr/bin/env bash
# Post-export patcher for iOS: Godot overwrites Info.plist, PrivacyInfo.xcprivacy
# and project.pbxproj on every export. This script re-applies our App Store-ready
# modifications:
#   - Info.plist: both landscape orientations on iPhone + iPad; drops empty
#     usage descriptions; declares arm64 capability; ITSAppUsesNonExemptEncryption=NO
#     (suppresses the export-compliance prompt on every upload).
#   - PrivacyInfo.xcprivacy: includes NSPrivacyAccessedAPICategoryUserDefaults
#     (required by Godot's internal storage); declares no tracking / no data.
#   - project.pbxproj: TARGETED_DEVICE_FAMILY = "1" (iPhone only — we do not
#     support iPad layout yet).
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
PBXPROJ="build/ios/VideoPoker.xcodeproj/project.pbxproj"

if [ ! -f "$INFO_PLIST" ]; then
    echo "error: $INFO_PLIST not found. Run iOS export first." >&2
    exit 1
fi
if [ ! -f "$PBXPROJ" ]; then
    echo "error: $PBXPROJ not found. Run iOS export first." >&2
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

# Declare no non-exempt encryption — skips the export-compliance prompt
# on every TestFlight upload. True only because we use HTTPS via system APIs
# (exempt per ECCN 5D002 note 4).
data["ITSAppUsesNonExemptEncryption"] = False

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

# -- 3. Patch project.pbxproj: iPhone only --
# Four build configurations (Debug/Release/ReleaseDebug × main + framework target).
if grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' "$PBXPROJ"; then
    sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2"/TARGETED_DEVICE_FAMILY = "1"/g' "$PBXPROJ"
    echo "✓ Patched $PBXPROJ (TARGETED_DEVICE_FAMILY → 1, iPhone only)"
else
    echo "• $PBXPROJ already patched (TARGETED_DEVICE_FAMILY != 1,2)"
fi

# -- 4. Fix code signing conflict: Godot hardcodes `Apple Distribution` for
# Release configs while also setting CODE_SIGN_STYLE = Automatic, which Xcode
# rejects with "conflicting provisioning settings". With Automatic signing,
# Xcode picks Distribution cert for Archive builds automatically; we just need
# to stop overriding the identity on Release. Normalizing to `Apple Development`
# — Xcode overrides it to `Apple Distribution` when you Archive.
if grep -q 'CODE_SIGN_IDENTITY = "Apple Distribution"' "$PBXPROJ"; then
    sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution"/CODE_SIGN_IDENTITY = "Apple Development"/g' "$PBXPROJ"
    echo "✓ Patched $PBXPROJ (CODE_SIGN_IDENTITY Release: Distribution → Development for Automatic signing)"
else
    echo "• $PBXPROJ already patched (no Apple Distribution overrides)"
fi

# -- 5. Force home-screen app name: Godot writes the old
# "Video Poker — Classic Edition" into INFOPLIST_KEY_CFBundleDisplayName.
# Replace with the current trainer-style name.
if grep -q 'INFOPLIST_KEY_CFBundleDisplayName = "Video Poker — Classic Edition"' "$PBXPROJ"; then
    sed -i '' 's/INFOPLIST_KEY_CFBundleDisplayName = "Video Poker — Classic Edition"/INFOPLIST_KEY_CFBundleDisplayName = "Video Poker Trainer"/g' "$PBXPROJ"
    echo "✓ Patched $PBXPROJ (CFBundleDisplayName → Video Poker Trainer)"
else
    echo "• $PBXPROJ CFBundleDisplayName already patched"
fi

echo ""
echo "iOS export patched. Now open build/ios/VideoPoker.xcodeproj in Xcode."
