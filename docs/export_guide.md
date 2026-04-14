# Export Guide — iOS & Android

## Предварительные требования

### Godot 4.6
- Скачать export templates: Editor → Manage Export Templates → Download
- Нужны templates для Android и iOS

### Android
1. **Android SDK** — установить через Android Studio
2. **JDK 17** — `brew install openjdk@17`
3. **Godot → Editor Settings → Export → Android:**
   - Android SDK Path: `/Users/<user>/Library/Android/sdk`
   - Java SDK Path: `/usr/local/opt/openjdk@17`
4. **Debug keystore** (создаётся автоматически при первом экспорте)
5. **Release keystore:**
   ```bash
   keytool -genkeypair -v \
     -keystore release.keystore \
     -alias video_poker \
     -keyalg RSA -keysize 2048 \
     -validity 10000 \
     -storepass YOUR_PASSWORD \
     -keypass YOUR_PASSWORD \
     -dname "CN=Video Poker, O=Your Company"
   ```
   - Положить `release.keystore` в корень проекта (добавить в .gitignore!)
   - В export_presets.cfg заполнить `keystore/release`, `release_user`, `release_password`

### iOS
1. **macOS + Xcode 15+** — обязательно
2. **Apple Developer Account** ($99/год)
3. **В Xcode:**
   - Signing & Capabilities → Team → выбрать аккаунт
   - Bundle Identifier: `com.videopoker.classicedition`
4. **Provisioning Profile** — создать в Apple Developer Portal
5. В export_presets.cfg заполнить:
   - `app_store_team_id`
   - `provisioning_profile_uuid_debug`
   - `provisioning_profile_uuid_release`

---

## Настройки проекта (уже сделано)

| Параметр | Значение | Файл |
|---|---|---|
| Renderer | Mobile | project.godot |
| Viewport | 1476×680 | project.godot |
| Stretch Mode | canvas_items | project.godot |
| Stretch Aspect | keep_height | project.godot |
| Orientation | Landscape | project.godot (`orientation=1`) |
| Touch emulation | true | project.godot |
| ETC2/ASTC compression | true | project.godot |
| Boot splash | Hidden, bg=#000086 | project.godot |
| Min Android SDK | 24 (Android 7.0) | export_presets.cfg |
| Min iOS | 15.0 | export_presets.cfg |
| Architecture | arm64-v8a only | export_presets.cfg |

---

## Иконки (уже созданы)

| Файл | Размер | Платформа |
|---|---|---|
| icon_1024.png | 1024×1024 | iOS App Store |
| icon_512.png | 512×512 | Google Play |
| icon_192.png | 192×192 | Android launcher |
| icon_180.png | 180×180 | iPhone @3x |
| icon_167.png | 167×167 | iPad Pro |
| icon_152.png | 152×152 | iPad @2x |
| icon_144.png | 144×144 | Android xxhdpi |
| icon_120.png | 120×120 | iPhone @2x |
| icon_96.png | 96×96 | Android xhdpi |
| icon_72.png | 72×72 | Android hdpi |
| icon_48.png | 48×48 | Android mdpi |

**ВАЖНО:** Текущие иконки — placeholder (синий фон + VP текст). Заменить на финальные перед публикацией!

---

## Экспорт Android

### Debug APK (для тестирования)
1. Godot → Project → Export → Android
2. Нажать "Export Project"
3. Выбрать путь: `build/video_poker_debug.apk`
4. Установить на устройство: `adb install build/video_poker_debug.apk`

### Release AAB (для Google Play)
1. В export_presets.cfg:
   - `gradle_build/export_format=1` (AAB вместо APK)
   - Заполнить keystore пути и пароли
2. Godot → Export → Android → Export Project (Release)
3. Загрузить .aab в Google Play Console

### Permissions
- `VIBRATE` — для вибрации ✅
- `INTERNET` — для будущих IAP ✅
- `ACCESS_NETWORK_STATE` — проверка сети ✅

---

## Экспорт iOS

### Xcode Project
1. Godot → Project → Export → iOS
2. Нажать "Export Project"
3. Выбрать папку: `build/ios/`
4. Откроется .xcodeproj

### В Xcode
1. Открыть `build/ios/Video Poker.xcodeproj`
2. Target → General:
   - Bundle Identifier: `com.videopoker.classicedition`
   - Version: 1.0.0
   - Build: 1
   - Deployment Target: 15.0
   - Device Orientation: Landscape Left + Landscape Right
3. Signing & Capabilities:
   - Team: выбрать Apple Developer аккаунт
   - Signing Certificate: автоматически
4. Build → Any iOS Device → Archive
5. Distribute App → App Store Connect

### Info.plist дополнения
Добавить в Xcode → Info tab:
```
UIRequiresFullScreen = YES
UISupportedInterfaceOrientations = UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight
```

### Safe Area (notch/island)
Проект использует `canvas_items` stretch mode — Godot автоматически обрабатывает safe area. Контент не попадёт под notch.

---

## Тестирование перед публикацией

### Чеклист
- [ ] Все 10 машин загружаются и играются
- [ ] Single/Multi/Ultra VP/Spin Poker — все режимы работают
- [ ] Ставки корректно списываются и начисляются
- [ ] Подарок (gift) работает с таймером
- [ ] Магазин открывается, покупка добавляет кредиты
- [ ] Настройки: язык, вибрация, удаление аккаунта
- [ ] Вибрация работает (Android)
- [ ] Ландшафтная ориентация — нет portrait
- [ ] Safe area — ничего не обрезано
- [ ] Звуки не крашат (placeholder тихие файлы)
- [ ] Сохранение/загрузка работает между сессиями
- [ ] Baланс не уходит в минус

### Устройства для тестирования
- Android: минимум 1 устройство с API 24+ (arm64)
- iOS: минимум iPhone с iOS 15+ (реальное устройство, не симулятор для вибрации)

---

## .gitignore дополнения

Добавить в .gitignore:
```
# Export builds
build/
*.apk
*.aab
*.ipa

# Keystore (СЕКРЕТ!)
*.keystore
*.jks

# Xcode
*.xcworkspace
*.xcuserdata
DerivedData/

# Godot export
.export/
```

---

## Структура билдов

```
build/
├── android/
│   ├── video_poker_debug.apk
│   └── video_poker_release.aab
└── ios/
    └── Video Poker.xcodeproj
```
