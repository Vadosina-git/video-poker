# iOS → App Store Connect — Autonomous Upload Playbook

**Цель:** этот файл — единственный источник правды для Claude по сборке
+ архивации + аплоаду iOS-билда в App Store Connect. Все creds, пути,
параметры подписей и типичные грабли — здесь. **Если ты Claude и видишь
задачу "собери и залей в ASC" — выполняй по этому файлу не задавая
уточняющих вопросов.**

Связанный документ: `docs/godot_release_runbook.md` — полный release-flow
для нового проекта (от cold start до первого билда). Этот файл —
повторяющийся upload existing project, без шагов первичной настройки.

---

## 0. Pre-flight checklist (делай молча, не спрашивай)

```bash
# 1. Креды на месте?
test -f .appstore.env && echo "env: OK" || echo "env: MISSING"
test -f ~/.appstoreconnect/private_keys/AuthKey_X5959253U4.p8 && echo "key: OK" || echo "key: MISSING"

# 2. Distribution identity в keychain?
security find-identity -v -p codesigning | grep "Apple Distribution"

# 3. Xcode project на месте?
test -f build/ios/VideoPoker.xcodeproj/project.pbxproj && echo "proj: OK" || echo "proj: MISSING (re-export from Godot first)"
```

Если хоть один MISSING — см. §6 «Troubleshooting».

---

## 1. Где что лежит

| Что | Где | Заметки |
|---|---|---|
| ASC creds (env file)               | `.appstore.env` (project root)                       | Gitignored. Не коммить. |
| Шаблон env                         | `.appstore.env.example`                              | Закоммичен, без значений. |
| ASC API delivery key (.p8)         | `~/.appstoreconnect/private_keys/AuthKey_X5959253U4.p8` | Используется для upload. |
| ASC API IAP key (.p8)              | `~/.appstoreconnect/private_keys/AuthKey_XL7R7TRL5N.p8` | Только для IAP management, не для upload. |
| Issuer UUID                        | `APP_STORE_ISSUER_ID` в `.appstore.env`              | Также `835ae8fb-4e40-4740-85c6-30a390729c1c` (см. `docs/godot_release_runbook.md` §1). |
| Apple Team ID                      | `KQBUD75V9A`                                         | Hardcoded в `ExportOptions.plist`. |
| Bundle ID                          | `com.khralz.videopoker`                              | В `build/ios/VideoPoker.xcodeproj/project.pbxproj`. |
| Xcode project                      | `build/ios/VideoPoker.xcodeproj`                     | **Gitignored** (генерируется Godot iOS export). |
| Xcode scheme                       | `VideoPoker`                                         | Единственная схема. |
| Distribution identity              | `Apple Distribution: Ivan Al Zeidi (KQBUD75V9A)`     | Hash `2FA5761C816FD89FB6FA88607A9418D87DED4758`. |
| Готовый upload-скрипт              | `scripts/upload_testflight.sh`                       | Принимает путь к .ipa. |
| Marketing icon (1024)              | `build/ios/VideoPoker/Images.xcassets/AppIcon.appiconset/Icon-1024.png` | Источник: `assets/icons/icon_.png`. |

---

## 2. Полный пайплайн (копипаст в одну сессию)

```bash
cd "/Users/vadimprokop/Documents/Godot/video poker"

# Шаг 1 — bump build number (ОБЯЗАТЕЛЬНО, иначе ASC отвергнет с 409)
CURRENT=$(grep -m1 "CURRENT_PROJECT_VERSION = " build/ios/VideoPoker.xcodeproj/project.pbxproj | sed -E 's/.*= ([0-9]+);.*/\1/')
NEXT=$((CURRENT + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT;/CURRENT_PROJECT_VERSION = $NEXT;/g" build/ios/VideoPoker.xcodeproj/project.pbxproj
echo "build $CURRENT → $NEXT"

# Шаг 2 — archive (Apple Distribution, automatic signing)
cd build/ios
rm -rf VideoPoker_new.xcarchive export
xcodebuild -project VideoPoker.xcodeproj -scheme VideoPoker \
    -configuration Release -destination "generic/platform=iOS" \
    -archivePath ./VideoPoker_new.xcarchive archive

# Шаг 3 — exportArchive с ExportOptions.plist (см. §3, создать если нет)
xcodebuild -exportArchive \
    -archivePath ./VideoPoker_new.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath ./export

# Шаг 4 — upload через готовый скрипт
cd ../..
./scripts/upload_testflight.sh build/ios/export/VideoPoker.ipa
```

**Ожидаемый успех:** `UPLOAD SUCCEEDED with no errors` + Delivery UUID. ASC обработает билд за 5–30 мин, потом он появится в TestFlight.

---

## 3. `ExportOptions.plist` (если отсутствует)

Лежит в `build/ios/ExportOptions.plist`. **Gitignored** — пересоздавай если отсутствует:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>KQBUD75V9A</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
    <key>uploadSymbols</key>
    <true/>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
```

---

## 4. Замена иконок (если пересобираешь под новый арт)

Источник всегда `assets/icons/icon_.png` (1024×1024 PNG). После замены источника пересоздай все ресайзы:

```bash
SRC="assets/icons/icon_.png"

# assets/icons (для project.godot icon path + general use)
for sz in 48 72 96 120 144 152 167 180 192 512; do
    sips -Z $sz "$SRC" --out "assets/icons/icon_${sz}.png" >/dev/null
done
cp "$SRC" assets/icons/icon_1024.png

# build/ios xcassets — gitignored, перезапишется на след. Godot export
IOS=build/ios/VideoPoker/Images.xcassets/AppIcon.appiconset
for sz in 40 58 60 76 80 87 114 120 128 136 152 167 180 192; do
    sips -Z $sz "$SRC" --out "$IOS/Icon-${sz}.png" >/dev/null
done
cp "$SRC" "$IOS/Icon-1024.png"
cp "$IOS/Icon-120.png" "$IOS/Icon-120-1.png"
```

Marketing icon (1024) — то что появляется в App Store Connect карточке. Подтянется автоматически из xcassets при следующем archive.

---

## 5. Что коммитить, что нет

| Путь | Git |
|---|---|
| `assets/icons/icon_*.png`            | ✅ commit (source of truth) |
| `build/ios/**`                       | ❌ gitignored (Godot regenerates) |
| `.appstore.env`                      | ❌ gitignored (содержит creds) |
| `.appstore.env.example`              | ✅ commit (шаблон) |
| `docs/IOS_UPLOAD.md` (этот файл)     | ✅ commit |
| `scripts/upload_testflight.sh`       | ✅ commit |

После Godot iOS export любые правки в `build/ios/` (включая bump версии и иконки) **исчезнут**. Workflow: после каждого Godot export повторяй §2 и §4.

---

## 6. Troubleshooting

### `409 ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` / `bundle version must be higher`
Причина: версия билда уже залита. Решение: bump `CURRENT_PROJECT_VERSION` и повтори archive + export + upload (§2 шаг 1 уже это делает).

### `No signing certificate "iOS Distribution" found`
Причина: keychain без Distribution cert. Проверка:
```bash
security find-identity -v -p codesigning | grep "Apple Distribution"
```
Если пусто — попроси пользователя поставить cert через Xcode → Settings → Accounts → Manage Certificates → "+ Apple Distribution".

### `Invalid issuer ID` / `Authentication failed`
Причина: env не загружен или issuer пустой. Проверка:
```bash
set -a; . ./.appstore.env; set +a
echo "issuer=$APP_STORE_ISSUER_ID key=$APP_STORE_API_KEY_ID"
```

### `error: .appstore.env missing`
Креды не на месте. Шаги:
1. Скопируй `.appstore.env.example` → `.appstore.env`
2. Заполни значения (issuer и key id — см. `docs/godot_release_runbook.md` §1; sandbox creds — `~/Downloads/SHARED_ACCOUNTS_REFERENCE.md`)

### Archive падает с `Code Signing Error: No matching profiles found`
`signingStyle = automatic` в ExportOptions.plist обычно решает. Если нет — переоткрой проект в Xcode хотя бы раз чтобы automatic provisioning синхронизировался с Apple Developer.

### Иконка в ASC не обновилась после upload
Проверь что `Icon-1024.png` в `build/ios/.../AppIcon.appiconset/` действительно новый перед archive. ASC берёт marketing icon из бандла, не отдельно. Если перезалил — отправь ещё один билд (с bump версии).

---

## 7. Правила для Claude

1. **Не спрашивай где креды** — они в `.appstore.env`. Просто `cat .appstore.env` и используй.
2. **Не спрашивай "можно ли запускать xcodebuild"** — если пользователь сказал "собери и залей", запускай весь пайплайн §2.
3. **Не спрашивай про issuer ID** — он в env-файле. Если env отсутствует — сначала grep по проекту (`grep -r "ISSUER" .` найдёт `.appstore.env` мгновенно), потом смотри `~/Downloads/SHARED_ACCOUNTS_REFERENCE.md`.
4. **Перед `xcrun altool` всегда bump build number** — иначе 409. Не жди ошибки, делай превентивно.
5. Прерывайся ТОЛЬКО если: (а) `.appstore.env` отсутствует И значения issuer/key не находятся ни в `~/Downloads/SHARED_ACCOUNTS_REFERENCE.md`, ни в `docs/godot_release_runbook.md`; (б) keychain без Distribution cert; (в) сам пользователь явно отменил действие.
