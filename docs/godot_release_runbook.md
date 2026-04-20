# Godot App — Release Readiness Runbook

**Purpose**: bring any Godot 4.x mobile project to the same release-ready state
that `video poker` reached before first TestFlight / Play Internal upload.
This runbook is meant to be consumed by **another Claude instance** running
inside the target project. Execute top to bottom; stop at every checkpoint
and get the user's confirmation before proceeding.

**Reference project** (source of truth for every file/pattern below):
`/Users/vadimprokop/Documents/Godot/video poker/` — if anything in this
runbook is ambiguous, read that project's equivalent file.

**Shared credentials** (team IDs, ASC API keys, sandbox testers):
`/Users/vadimprokop/Downloads/SHARED_ACCOUNTS_REFERENCE.md` — already on
the user's machine. **Never copy those values into committed files.**

---

## 0. Scope of this project vs. casino-specific items

The reference project (`video poker`) is a **social casino** app, so it
included age gate + specific Apple Guideline 5.3 disclaimers. If your project
is not simulated gambling, skip the items tagged **[CASINO-ONLY]** — they'll
get you (harmlessly) extra UI you don't need.

Items tagged **[IAP-ONLY]** are for projects with in-app purchases. If your
app is free with no purchases, skip them.

Everything else is **universal** (required for store submission regardless).

---

## 1. Project-specific substitutions

Before running any step, substitute these placeholders in all instructions
below. In `video poker` everything is branded `VideoPoker` / `com.khralz.videopoker`;
in the target project it's different.

| Placeholder | Video Poker value | BoxMaster value |
|---|---|---|
| `<APP_NAME_PASCAL>` | `VideoPoker` | `BoxMaster` |
| `<APP_NAME_TITLE>` | `Video Poker` | `Box Master` |
| `<APP_NAME_LOWER>` | `videopoker` | `boxmaster` |
| `<BUNDLE_ID>` | `com.khralz.videopoker` | `com.khralz.boxmaster` |
| `<ORIENTATION>` | `landscape` (`0`) | **ask user — portrait or landscape** |
| `<SKU>` | `videopoker-classic-001` | `boxmaster-001` |
| `<PRIVACY_POLICY_URL>` | `https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html` | **ask user to create a page at `https://vadosina-git.github.io/privacy-policy/boxmaster-privacy.html` — same repo, new file. A 4-line template is fine: "This app does not collect personal data. Progress is stored locally and not transmitted."** |

**Shared across all apps on Team `KQBUD75V9A` (from SHARED_ACCOUNTS_REFERENCE.md):**
- Apple Team ID: `KQBUD75V9A`
- ASC API Key ID: `X5959253U4`, Issuer `835ae8fb-4e40-4740-85c6-30a390729c1c`
- IAP Key ID: `XL7R7TRL5N`
- Google Play Developer: `KHRALZ`, Account ID `7220156508452986260`
- Sandbox IAP tester email: `vakhrustalev+sandbox@gmail.com` (password in `.appstore.env`)

---

## 2. Code changes

### 2.1 `project.godot`

Ensure the following keys exist. Add / modify as needed.

```ini
[application]
config/name="<APP_NAME_TITLE>"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "Mobile")
boot_splash/bg_color=Color(0, 0, 0.527, 1)   ; adjust to app brand
boot_splash/stretch_mode=0
boot_splash/image="res://assets/textures/logo_splash.png"
config/icon="res://icon.svg"

[autoload]
; keep existing autoloads; ADD:
SaveManager="*res://scripts/save_manager.gd"
ConfigManager="*res://scripts/config_manager.gd"
Translations="*res://scripts/translations.gd"
IapManager="*res://scripts/iap_manager.gd"          ; [IAP-ONLY]

[display]
; orientation:  0 = landscape, 1 = portrait
window/handheld/orientation=<ORIENTATION_CODE>      ; 0 or 1 per app

[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="gl_compatibility" ; required for emulator + many older devices
```

### 2.2 `scripts/save_manager.gd` — XOR obfuscation + null safety

Changes to apply to the existing SaveManager autoload:

1. **Add constant + helper** near the top:
   ```gdscript
   const _OBFUSCATION_KEY := 0x5A

   func _obfuscate(text: String) -> PackedByteArray:
       var bytes := text.to_utf8_buffer()
       for i in bytes.size():
           bytes[i] = bytes[i] ^ _OBFUSCATION_KEY
       return bytes

   func _deobfuscate(bytes: PackedByteArray) -> String:
       var copy := PackedByteArray(bytes)  # don't mutate caller's buffer
       for i in copy.size():
           copy[i] = copy[i] ^ _OBFUSCATION_KEY
       return copy.get_string_from_utf8()
   ```

2. **Saving**: write obfuscated bytes instead of plaintext JSON.
   ```gdscript
   func save_game() -> void:
       var data := _serialize_state()  # your existing dict → JSON string
       var obf := _obfuscate(JSON.stringify(data))
       var file := FileAccess.open("user://save.json", FileAccess.WRITE)
       if file == null:
           return  # null safety — don't crash if write fails
       file.store_buffer(obf)
   ```

3. **Loading**: try obfuscated first, fall back to plaintext migration for
   users who had the old save format.
   ```gdscript
   func load_game() -> void:
       var file := FileAccess.open("user://save.json", FileAccess.READ)
       if file == null:
           return
       var raw := file.get_buffer(file.get_length())
       var text := _deobfuscate(raw)
       var parsed: Variant = JSON.parse_string(text)
       if typeof(parsed) != TYPE_DICTIONARY:
           # migration: old plaintext JSON
           parsed = JSON.parse_string(raw.get_string_from_utf8())
       if typeof(parsed) != TYPE_DICTIONARY:
           return
       _deserialize_state(parsed)
   ```

4. **Add `age_gate_confirmed` field** to the state dict (default `false`).
   [CASINO-ONLY]

### 2.3 `scripts/main.gd` — splash screen loader

Call from `_ready()` before loading the first scene:

```gdscript
func _show_splash() -> void:
    var duration: float = float(ConfigManager.init_config.get("splash_duration_sec", 4.0))
    if duration <= 0.0:
        return
    var splash := Control.new()
    splash.set_anchors_preset(Control.PRESET_FULL_RECT)
    splash.z_index = 4096  # IMPORTANT: NOT 10000 — exceeds CANVAS_ITEM_Z_MAX and errors
    add_child(splash)

    var logo := TextureRect.new()
    logo.texture = load("res://assets/textures/logo_splash.png")
    logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    logo.set_anchors_preset(Control.PRESET_CENTER)
    splash.add_child(logo)

    # Optional: add a spinner animation here

    await get_tree().create_timer(duration).timeout
    var fade := splash.create_tween()
    fade.tween_property(splash, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
    fade.tween_callback(splash.queue_free)
    await fade.finished
```

Add to `configs/init_config.json`:
```json
{
  "splash_duration_sec": 4.0
}
```

### 2.4 `scripts/age_gate.gd` — 18+ modal [CASINO-ONLY]

New file. Copy from reference project verbatim — no project-specific tweaks
beyond the translation keys it resolves. Full source:

```gdscript
class_name AgeGate
extends RefCounted

static func show_if_needed(host: Control) -> void:
    if SaveManager.age_gate_confirmed:
        return
    _build(host)

static func _build(host: Control) -> void:
    var overlay := Control.new()
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 2000
    host.add_child(overlay)

    var bg := ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.85)
    overlay.add_child(bg)

    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("0A0F40")
    style.set_border_width_all(3)
    style.border_color = Color("FFEC00")
    style.set_corner_radius_all(16)
    style.content_margin_left = 32
    style.content_margin_right = 32
    style.content_margin_top = 28
    style.content_margin_bottom = 24
    panel.add_theme_stylebox_override("panel", style)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    # PRESET_CENTER alone grows the panel down-right from the anchor, putting
    # it off-center. GROW_DIRECTION_BOTH makes it expand equally in all
    # directions — this is what actually centers the modal.
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    panel.custom_minimum_size = Vector2(620, 0)
    overlay.add_child(panel)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 14)
    panel.add_child(vb)

    var title := Label.new()
    title.text = Translations.tr_key("age_gate.title")
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color("FFEC00"))
    vb.add_child(title)

    var body := Label.new()
    body.text = Translations.tr_key("age_gate.body")
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", 18)
    body.add_theme_color_override("font_color", Color.WHITE)
    vb.add_child(body)

    var disclaimer := Label.new()
    disclaimer.text = Translations.tr_key("age_gate.disclaimer")
    disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    disclaimer.add_theme_font_size_override("font_size", 15)
    disclaimer.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
    vb.add_child(disclaimer)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 6)
    vb.add_child(spacer)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 16)
    vb.add_child(buttons)

    var no_btn := _make_btn(Translations.tr_key("age_gate.no"), Color("8A1A1A"))
    buttons.add_child(no_btn)
    no_btn.pressed.connect(func() -> void:
        host.get_tree().quit()
    )

    var yes_btn := _make_btn(Translations.tr_key("age_gate.yes"), Color("1A7A2A"))
    buttons.add_child(yes_btn)
    yes_btn.pressed.connect(func() -> void:
        SaveManager.age_gate_confirmed = true
        SaveManager.save_game()
        overlay.queue_free()
    )

static func _make_btn(label: String, bg_color: Color) -> Button:
    var btn := Button.new()
    btn.text = label
    btn.custom_minimum_size = Vector2(160, 50)
    btn.add_theme_font_size_override("font_size", 20)
    btn.add_theme_color_override("font_color", Color.WHITE)
    var st := StyleBoxFlat.new()
    st.bg_color = bg_color
    st.set_border_width_all(2)
    st.border_color = Color(1, 1, 1, 0.3)
    st.set_corner_radius_all(10)
    btn.add_theme_stylebox_override("normal", st)
    btn.add_theme_stylebox_override("hover", st)
    btn.add_theme_stylebox_override("pressed", st)
    btn.add_theme_stylebox_override("focus", st)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    return btn
```

Then from the first scene's `_ready()` (lobby or main menu):
```gdscript
AgeGate.show_if_needed(self)
```

### 2.5 `scripts/iap_manager.gd` — IAP abstraction autoload [IAP-ONLY]

New autoload. Copy full content from `video poker/scripts/iap_manager.gd`.
Key points:
- Backend auto-detects `GodotxRevenueCat` plugin singleton; falls back to STUB.
- Signals: `purchase_success`, `purchase_failed`, `purchase_canceled`, `products_fetched`.
- `RC_API_KEY_IOS` / `RC_API_KEY_ANDROID` — leave empty in code, fill via
  Project Settings → Application (see §5.3) or env-inject at build time.
- Expects `SaveManager.add_credits(chips)` and `ConfigManager.get_shop_items()`
  — adapt reward-awarding logic to your project's economy.

### 2.6 Shop UI changes [IAP-ONLY]

In your shop overlay script:

1. Route the Buy button through IapManager:
   ```gdscript
   IapManager.purchase(product_id)
   IapManager.purchase_success.connect(on_success, CONNECT_ONE_SHOT)
   ```

2. **Add a "Restore Purchases" button** — App Store Guideline 3.1.1 requires
   it even for consumable-only shops. Bottom-left is conventional. On press:
   ```gdscript
   IapManager.restore_purchases()
   ```

3. **Do NOT display hard-coded prices** in the UI ("$4.99" etc.). Use
   `IapManager.fetch_products()` → `products_fetched` signal with
   `p.price_string` from the platform (localized pricing tier). Apple rejects
   apps that display prices not coming from StoreKit.

4. **Rename shop title to something Apple won't flag as "payment-like"**
   (Guideline 3.1.1 — external purchase paths). Example:
   `"GET CHIPS" → "FREE CHIPS"`. Prices on individual packs should be shown
   via the platform string (see point 3), not hand-typed in translations.

### 2.7 Privacy policy link in settings

In the settings popup builder (wherever a settings gear opens one):

```gdscript
var privacy_btn := Button.new()
privacy_btn.text = Translations.tr_key("settings.privacy_policy")
privacy_btn.pressed.connect(func() -> void:
    OS.shell_open("<PRIVACY_POLICY_URL>")
)
settings_popup.add_child(privacy_btn)
```

### 2.8 `scripts/paytable.gd` (or any script that reads autoloads during test runs)

If you run unit tests via `Godot --headless --script res://tests/test_*.gd`,
autoloads are NOT initialized. Any module loaded by a test script that
references `ConfigManager`/`Translations` at class-load time will fail.
Fix: lazy-resolve autoloads at method call time, with a null guard:

```gdscript
var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
var data: Dictionary = cm.get_data() if cm else {}
```

---

## 3. Configs

### 3.1 `configs/init_config.json`

Ensure it contains (merge with existing):
```json
{
  "splash_duration_sec": 4.0
}
```

### 3.2 `data/translations.json` (or equivalent i18n file)

Add these keys in **all three languages** (`en` / `ru` / `es`):

```jsonc
{
  "en": {
    "settings.privacy_policy": "PRIVACY POLICY",
    "shop.restore": "Restore Purchases",
    "shop.purchase_failed": "Purchase failed",
    // [CASINO-ONLY]:
    "age_gate.title": "AGE CONFIRMATION",
    "age_gate.body": "This app contains simulated gambling for entertainment only. You must be 18 years or older to continue.",
    "age_gate.disclaimer": "No real money gambling. No cash prizes. Virtual chips only.",
    "age_gate.yes": "YES, I AM 18+",
    "age_gate.no": "NO, EXIT"
  },
  "ru": {
    "settings.privacy_policy": "ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ",
    "shop.restore": "Восстановить покупки",
    "shop.purchase_failed": "Покупка не удалась",
    "age_gate.title": "ПОДТВЕРЖДЕНИЕ ВОЗРАСТА",
    "age_gate.body": "Это приложение содержит имитацию азартных игр только для развлечения. Вам должно быть 18 лет или больше, чтобы продолжить.",
    "age_gate.disclaimer": "Никаких настоящих денег. Никаких денежных призов. Только виртуальные фишки.",
    "age_gate.yes": "ДА, МНЕ 18+",
    "age_gate.no": "НЕТ, ВЫЙТИ"
  },
  "es": {
    "settings.privacy_policy": "POLÍTICA DE PRIVACIDAD",
    "shop.restore": "Restaurar compras",
    "shop.purchase_failed": "Compra fallida",
    "age_gate.title": "CONFIRMACIÓN DE EDAD",
    "age_gate.body": "Esta aplicación contiene juego simulado solo para entretenimiento. Debes tener 18 años o más para continuar.",
    "age_gate.disclaimer": "Sin apuestas con dinero real. Sin premios en efectivo. Solo fichas virtuales.",
    "age_gate.yes": "SÍ, TENGO 18+",
    "age_gate.no": "NO, SALIR"
  }
}
```

### 3.3 `export_presets.cfg`

**Android preset:**
- `gradle_build/use_gradle_build=true`
- `gradle_build/min_sdk="24"`
- `gradle_build/target_sdk="35"` ← **required since Aug 2025, else Play Console rejects**
- `package/unique_name="<BUNDLE_ID>"`
- `package/name="<APP_NAME_TITLE>"`
- `permissions/internet=false` (unless the app actually uses network)
- `permissions/access_network_state=false` (same)
- `keystore/release=""` (empty — filled at build-time by script, see §4.1)
- `keystore/release_user=""`
- `keystore/release_password=""`

**iOS preset:**
- `application/bundle_identifier="<BUNDLE_ID>"`
- `application/name="<APP_NAME_TITLE>"`
- `application/app_store_team_id="KQBUD75V9A"`
- `application/provisioning_profile_uuid_debug=""`
- `application/provisioning_profile_uuid_release=""`
- `application/min_ios_version="15.0"`
- **Do not set** `application/code_sign_identity_debug` / `_release` — leaving empty
  avoids the Xcode "conflicting provisioning" error.

### 3.4 `.gitignore`

Append (if not already present):
```
# Godot 4+
.godot/
/android/
/ios/
.godot_cache/

# Secrets — NEVER COMMIT
*.keystore
*.jks
.keystore.env
.env
.appstore.env

# macOS / editors
.DS_Store
.vscode/
.idea/
*.swp
```

---

## 4. Scripts (new files in `scripts/`)

All scripts should be `chmod +x` after creation.

### 4.1 `scripts/build_android_release.sh`

```bash
#!/usr/bin/env bash
# Build a signed Android release APK.
# Credentials come from .keystore.env (gitignored). Injects into export_presets.cfg
# just for the export run and reverts the file afterwards.
# Usage: ./scripts/build_android_release.sh [output_path]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f .keystore.env ]; then
    echo "error: .keystore.env not found in project root" >&2
    exit 1
fi

# shellcheck disable=SC1091
source .keystore.env
: "${ANDROID_KEYSTORE_PATH:?ANDROID_KEYSTORE_PATH required}"
: "${ANDROID_KEYSTORE_USER:?ANDROID_KEYSTORE_USER required}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD required}"

OUTPUT="${1:-build/<APP_NAME_LOWER>_release.apk}"
mkdir -p "$(dirname "$OUTPUT")"

cp export_presets.cfg export_presets.cfg.bak
trap 'mv -f export_presets.cfg.bak export_presets.cfg' EXIT

sed -i '' \
    -e "s|keystore/release=\"\"|keystore/release=\"${ANDROID_KEYSTORE_PATH}\"|" \
    -e "s|keystore/release_user=\"\"|keystore/release_user=\"${ANDROID_KEYSTORE_USER}\"|" \
    -e "s|keystore/release_password=\"\"|keystore/release_password=\"${ANDROID_KEYSTORE_PASSWORD}\"|" \
    export_presets.cfg

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . --export-release "Android" "$OUTPUT"

echo "✓ Release APK built: $OUTPUT"
```

### 4.2 `scripts/patch_ios_export.sh`

Post-export patcher. Godot overwrites `Info.plist`, `PrivacyInfo.xcprivacy`
and `project.pbxproj` on every iOS export — this script re-applies our
App Store-ready modifications. Run AFTER every iOS export.

Substitute `<APP_NAME_PASCAL>` in paths (e.g. `build/ios/VideoPoker/...`
→ `build/ios/BoxMaster/...`):

```bash
#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

INFO_PLIST="build/ios/<APP_NAME_PASCAL>/<APP_NAME_PASCAL>-Info.plist"
PRIVACY="build/ios/PrivacyInfo.xcprivacy"
PBXPROJ="build/ios/<APP_NAME_PASCAL>.xcodeproj/project.pbxproj"

[ -f "$INFO_PLIST" ] || { echo "error: $INFO_PLIST not found. Run iOS export first." >&2; exit 1; }
[ -f "$PBXPROJ" ]  || { echo "error: $PBXPROJ not found." >&2; exit 1; }

# 1. Info.plist
python3 - <<PY
import plistlib
from pathlib import Path
path = Path("$INFO_PLIST")
data = plistlib.loads(path.read_bytes())
# Orientation — EDIT per project (landscape shown; portrait equivalents below)
data["UISupportedInterfaceOrientations"] = [
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
]
data["UISupportedInterfaceOrientations~ipad"] = data["UISupportedInterfaceOrientations"]
for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
            "NSMicrophoneUsageDescription"):
    data.pop(key, None)
data["UIRequiredDeviceCapabilities"] = ["arm64"]
data["ITSAppUsesNonExemptEncryption"] = False
path.write_bytes(plistlib.dumps(data))
print(f"✓ Patched {path}")
PY

# 2. PrivacyInfo.xcprivacy — full replacement (App Store-ready)
cat > "$PRIVACY" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>DDA9.1</string><string>C617.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategorySystemBootTime</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>35F9.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>E174.1</string><string>85F4.1</string></array>
    </dict>
  </array>
</dict>
</plist>
EOF
echo "✓ Patched $PRIVACY"

# 3. pbxproj: iPhone only + signing conflict fix
if grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' "$PBXPROJ"; then
    sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2"/TARGETED_DEVICE_FAMILY = "1"/g' "$PBXPROJ"
    echo "✓ iPhone-only"
fi
if grep -q 'CODE_SIGN_IDENTITY = "Apple Distribution"' "$PBXPROJ"; then
    sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution"/CODE_SIGN_IDENTITY = "Apple Development"/g' "$PBXPROJ"
    echo "✓ Signing normalized for Automatic"
fi
echo "Done. Open build/ios/<APP_NAME_PASCAL>.xcodeproj in Xcode."
```

### 4.3 `scripts/upload_testflight.sh`

```bash
#!/usr/bin/env bash
# Upload a signed .ipa to TestFlight via ASC API key.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

[ -f .appstore.env ] || { echo "error: .appstore.env missing"; exit 1; }
set -a; source .appstore.env; set +a
APP_STORE_API_KEY_PATH="$(eval echo "$APP_STORE_API_KEY_PATH")"
: "${APP_STORE_ISSUER_ID:?}"
: "${APP_STORE_API_KEY_ID:?}"
[ -f "$APP_STORE_API_KEY_PATH" ] || { echo "error: $APP_STORE_API_KEY_PATH missing"; exit 1; }

IPA="${1:-build/ios/export/<APP_NAME_PASCAL>.ipa}"
[ -f "$IPA" ] || { echo "error: $IPA missing. Archive in Xcode first."; exit 1; }

xcrun altool --upload-app --file "$IPA" --type ios \
    --apiKey "$APP_STORE_API_KEY_ID" --apiIssuer "$APP_STORE_ISSUER_ID"
echo "✓ Uploaded. Check https://appstoreconnect.apple.com → TestFlight."
```

### 4.4 `scripts/install_revenuecat.sh` [IAP-ONLY]

Downloads & extracts the `godotx_revenue_cat` plugin binaries (not committed
because iOS xcframeworks are ~850MB). Copy full content from
`video poker/scripts/install_revenuecat.sh`.

---

## 5. Secrets / env files

### 5.1 `.keystore.env` (gitignored)

```
ANDROID_KEYSTORE_PATH=/Users/vadimprokop/<APP_NAME_LOWER>-upload-keystore.jks
ANDROID_KEYSTORE_USER=upload
ANDROID_KEYSTORE_PASSWORD=<set-during-keystore-gen>
```

Generate the keystore (one-time per app — **never reuse across apps**):
```bash
keytool -genkey -v -keystore ~/<APP_NAME_LOWER>-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Prompt will ask for a password — remember it, put it in `.keystore.env`.

### 5.2 `.appstore.env` (gitignored)

```
APP_STORE_ISSUER_ID=835ae8fb-4e40-4740-85c6-30a390729c1c
APP_STORE_API_KEY_ID=X5959253U4
APP_STORE_API_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_X5959253U4.p8
APP_STORE_IAP_KEY_ID=XL7R7TRL5N
APP_STORE_IAP_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_XL7R7TRL5N.p8
APP_STORE_APP_APPLE_ID=
APP_STORE_BUNDLE_ID=<BUNDLE_ID>
APP_STORE_SANDBOX_EMAIL=vakhrustalev+sandbox@gmail.com
APP_STORE_SANDBOX_PASSWORD=<from SHARED_ACCOUNTS_REFERENCE.md §6>
```

`.p8` files should already be at `~/.appstoreconnect/private_keys/` from the
`video poker` setup. If not, see SHARED_ACCOUNTS_REFERENCE.md §1.

Also create `.appstore.env.example` (tracked) with the same keys but empty
values — so future contributors know what shape the env file should have.

### 5.3 `.appstore.env.example` (tracked in git)

Same keys as `.appstore.env`, all values blank.

---

## 6. External setup (user must do — can't be automated)

### 6.1 Apple Developer Portal — register App ID

1. `developer.apple.com/account` → sign in (Apple ID with Admin role in Team `KQBUD75V9A`).
2. Certificates, Identifiers & Profiles → **Identifiers** → **+**.
3. App IDs → App → Continue.
4. Description: `<APP_NAME_TITLE>`; Bundle ID: **Explicit** = `<BUNDLE_ID>`.
5. Capabilities: leave defaults.
6. Continue → Register.

### 6.2 App Store Connect — create app record

1. `appstoreconnect.apple.com` → My Apps → **+** → New App.
2. Platform: iOS; Name: `<APP_NAME_TITLE>`; Language: English (U.S.);
   Bundle ID: select `<BUNDLE_ID>` (propagates from step 6.1 — if not visible,
   wait 5 min and refresh); SKU: `<SKU>`; Full Access.
3. After creation: copy the 10-digit "Apple ID" under the app name →
   fill into `.appstore.env` → `APP_STORE_APP_APPLE_ID=`.
4. Side menu → **App Privacy** → "Does your app collect data?" → **No** → Publish.
5. **Age Rating** — if CASINO-ONLY: "Frequent/Intense Simulated Gambling" → 17+.
   Otherwise fill the questionnaire honestly.
6. Privacy Policy URL → `<PRIVACY_POLICY_URL>`.

### 6.3 Google Play Console — create app record

1. `play.google.com/console` → Create app.
2. App name: `<APP_NAME_TITLE>`; default language: English (US);
   Game or App: **Game** (for games); Free; Accept declarations.
3. Dashboard → complete these questionnaires:
   - **App content** → Privacy Policy URL, Ads declaration, App access,
     Content ratings (IARC — if simulated gambling: 18+), Target audience
     (18+ for casino, or appropriate for your game), News app (No),
     Data safety (if no data collected: all No → submit).
   - **Store listing** → screenshots, icon, short/full description.
4. **Monetization → In-app products** (if IAP) — create the products with
   matching IDs per §7.2 (RevenueCat offering names).

### 6.4 RevenueCat [IAP-ONLY]

1. `app.revenuecat.com` → Vadim's account → New Project `<APP_NAME_TITLE>`.
2. Project Settings → Apps:
   - iOS app: Bundle `<BUNDLE_ID>`; upload **IAP key** `AuthKey_XL7R7TRL5N.p8`,
     Key ID `XL7R7TRL5N`, Issuer `835ae8fb-4e40-4740-85c6-30a390729c1c`.
   - Android app: Package `<BUNDLE_ID>`; upload Google Cloud service account
     JSON (see SHARED_ACCOUNTS_REFERENCE.md §10 — create new SA per project).
3. Products → add the product IDs for each platform (must match ASC + Play).
4. Offerings → create `default` offering, add packages.
5. Public SDK Keys → copy `appl_*` and `goog_*` — either:
   - Paste into `scripts/iap_manager.gd` `RC_API_KEY_IOS` / `RC_API_KEY_ANDROID`
     — public RC keys are NOT secret (safe to commit), OR
   - Put into Project Settings → Application for stricter hygiene.

### 6.5 Privacy policy page

User must publish a short HTML page at `<PRIVACY_POLICY_URL>` before ASC
allows submission. Template:
```html
<!DOCTYPE html><html><head><title><APP_NAME_TITLE> Privacy Policy</title></head>
<body><h1><APP_NAME_TITLE> Privacy Policy</h1>
<p>Last updated: 2026.</p>
<p>This app does not collect, store, or transmit any personal data.</p>
<p>Game progress is saved locally on your device and is not accessible to the developer.</p>
<p>Contact: vakhrustalev@gmail.com</p>
</body></html>
```
Add to `Vadosina-git/privacy-policy` GitHub repo, commit, wait 1 min for Pages.

---

## 7. Build & test workflow

### 7.1 Android

```bash
./scripts/build_android_release.sh  # signed APK at build/<APP_NAME_LOWER>_release.apk
# Install on emulator / device:
adb install -r build/<APP_NAME_LOWER>_release.apk
adb shell monkey -p <BUNDLE_ID> -c android.intent.category.LAUNCHER 1
```

For Play Console upload: prefer AAB — change output extension + rebuild.

### 7.2 iOS

```bash
# 1. Godot export
rm -rf build/ios && mkdir -p build/ios
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "iOS" build/ios/<APP_NAME_PASCAL>.xcodeproj

# 2. Post-export patches
./scripts/patch_ios_export.sh

# 3. Open in Xcode, verify Signing & Capabilities:
open build/ios/<APP_NAME_PASCAL>.xcodeproj
# - ☑ Automatically manage signing
# - Team: Ivan Al Zeidi (KQBUD75V9A)
# - Provisioning Profile: Xcode Managed Profile
# - Signing Certificate: Apple Development: Ivan Al Zeidi

# 4. Product → Archive → Distribute App → App Store Connect → Export → .ipa
#    Resulting .ipa typically at: build/ios/export/<APP_NAME_PASCAL>.ipa

# 5. Upload to TestFlight
./scripts/upload_testflight.sh build/ios/export/<APP_NAME_PASCAL>.ipa
```

### 7.3 Sandbox IAP testing [IAP-ONLY]

iPhone → Settings → Media & Purchases → Sign Out of prod Apple ID. Then
Settings → App Store → **Sandbox Account** → sign in with
`vakhrustalev+sandbox@gmail.com` (password in `.appstore.env`). Launch app
from TestFlight, trigger purchase — iOS asks for sandbox confirmation.

---

## 8. Completion checklist

Before considering the project release-ready, verify:

- [ ] `project.godot` has renderer=`mobile`/`gl_compatibility`, orientation set, required autoloads
- [ ] `export_presets.cfg` has correct Bundle ID, Team ID `KQBUD75V9A`, `target_sdk=35`, no committed keystore password
- [ ] `.gitignore` covers `.keystore.env`, `.env`, `.appstore.env`, `*.keystore`, `*.jks`, `.godot/`, `/ios/`, `/android/`
- [ ] `.keystore.env` exists with valid keystore (and keystore file is at the declared path)
- [ ] `.appstore.env` exists with Issuer ID + Key ID + Key path
- [ ] `.p8` files present at `~/.appstoreconnect/private_keys/`
- [ ] `scripts/build_android_release.sh` produces a signed APK
- [ ] `scripts/patch_ios_export.sh` runs cleanly on a fresh iOS export
- [ ] Age gate shows on first launch, quits on NO, persists confirmation on YES [CASINO-ONLY]
- [ ] Privacy Policy button in settings opens `<PRIVACY_POLICY_URL>` in system browser
- [ ] Shop displays platform prices (not hard-coded), has Restore Purchases button [IAP-ONLY]
- [ ] `xcodebuild` for Release iphoneos succeeds (no signing errors)
- [ ] Android APK installs & launches on emulator
- [ ] App ID registered in Developer Portal
- [ ] App record created in App Store Connect
- [ ] App record created in Google Play Console
- [ ] RevenueCat project created + apps linked [IAP-ONLY]
- [ ] Privacy policy page live at `<PRIVACY_POLICY_URL>`

---

## 9. Getting help during execution

If something doesn't match the reference:

- **Read** the equivalent file at `/Users/vadimprokop/Documents/Godot/video poker/`.
- **Consult** `SHARED_ACCOUNTS_REFERENCE.md` for credentials/IDs.
- **Ask the user** before:
  - committing anything (see §10)
  - modifying files not explicitly listed in this runbook
  - running `git push`, `git reset --hard`, or any destructive command
  - uploading a build to a store

## 10. Commit policy

**Never commit without explicit user approval.** When you've completed a
logical group of changes, summarize what's changed and ask to commit. Use
a descriptive commit message; never include secrets in messages or files.

Typical grouping:
1. `chore(gitignore): secrets + build artifacts`
2. `feat(save): XOR obfuscation + null safety`
3. `feat(iap): IapManager facade with RevenueCat backend` [IAP-ONLY]
4. `feat(age-gate): 18+ confirmation modal` [CASINO-ONLY]
5. `feat(settings): privacy policy link`
6. `chore(build): Android release script with keystore env`
7. `chore(ios): post-export patcher for App Store readiness`
8. `chore(ios): TestFlight upload script`
9. `feat(splash): 4s splash screen loader`
10. `feat(i18n): EN/RU/ES translation keys for new UI`

---

*Generated by Claude from the `video poker` reference project, 2026-04-19.
Keep this file in sync when the reference project evolves.*
