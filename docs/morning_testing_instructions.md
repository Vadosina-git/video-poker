# Morning Testing Instructions — release_01

Доброе утро! Пока ты спал, я:
1. Настроил релиз Android + iOS
2. Провёл ревью кода + сторов + безопасности через параллельных агентов
3. Пофиксил все критические issues
4. Написал и прогнал unit tests
5. Пересобрал APK/IPA со всеми фиксами

---

## 1. Критический bugfix в геймплее 🎰

**Нашли через code review**: `DeucesAndJoker` при выпадении jackpot-руки (4 deuces + joker = 10,000 coins) при bet 1-4 платил **0**, а не fallback к Five of a Kind. Т.е. игрок получал джекпот но проигрывал ставку. Исправлено + покрыто тестом.

- `scripts/variants/deuces_and_joker.gd`: `get_payout()` теперь при `_last_hand_key == "four_deuces_joker" and bet < 5` возвращает `_lookup_payout("five_of_a_kind", bet)`.

---

## 2. App Store / Google Play rejection risks

Прогнал через агента общие причины отказов. Критические находки и фиксы:

| Риск | Стор | Было | Стало |
|---|---|---|---|
| Android target SDK 34 | Google Play | `target_sdk=34` | **`target_sdk=35`** (обязательно с Aug 2025) |
| Неиспользуемые permissions | Google Play | INTERNET + ACCESS_NETWORK_STATE | Удалены (не используются) |
| Keystore password в git | Public repo | Был committed | **Убран из cfg → `.keystore.env` (gitignored)** |
| Age gate отсутствует | Google Play (с Jan 2026) | Нет | **Added first-launch 18+ modal** |
| Disclaimer entertainment-only | Apple 5.3 / IARC | Нет | **В age_gate modal + translations** |
| Privacy manifest ИТMS-91053 | Apple | `UserDefaults` не задекларирован | **Добавлен в PrivacyInfo.xcprivacy** |
| Shop "BUY" / "$" | Apple 3.1.1 | Title "GET CHIPS" | **"FREE CHIPS" + no prices displayed** |
| Save file plaintext | User tampering | Plaintext JSON | **XOR obfuscation + plaintext migration** |
| FileAccess crash | Stability | Null ref если open fails | **`if file == null: return`** |

**Остаётся на тебе (не могу автоматизировать):**
- Hosted privacy policy URL — надо опубликовать one-page на GitHub Pages или другом хостинге: "Этот app не собирает персональные данные. Прогресс хранится локально на устройстве, не передаётся."
- App Store Connect: **Age Rating → "Frequent/Intense Simulated Gambling"** → 17+
- Google Play Console: IARC questionnaire → YES на "simulated gambling" → 18+
- App Privacy Details (Apple) → "Data Not Collected" для всех категорий
- Play Data Safety → "no data collected / no data shared"
- App Store Connect: создать app record с bundle `com.khralz.videopoker` под KHRALZ team

---

## 3. Unit tests

Новая директория `tests/` с 3 тестовыми сьютами:
- `tests/test_hand_evaluator.gd` — 19 тестов (royal/straight flush, four of a kind, low straight A-2-3-4-5, wheel SF, jacks-or-better, hold masks, edge cases)
- `tests/test_deck.gd` — 10 тестов (52/53 cards, Fisher-Yates uniqueness, multihand replacement consistency)
- `tests/test_deuces_and_joker.gd` — 11 тестов (jackpot at MAX_BET, **jackpot fallback at bet 1-4**, natural royal, wild royal, 5oak, 3oak min hand)

**Запуск:**
```bash
./tests/run_all.sh
```

Все 40 тестов прошли ✓.

---

## 4. Release артефакты

### Android
- `build/video_poker_release.apk` (81MB, signed с upload keystore `/Users/vadimprokop/upload-keystore.jks`)
- `build/video_poker_debug.apk` (87MB, debug keystore)
- Signing verified: `Signer #1: CN=Ivan Al Zeidi, O=KHRALZ, SHA-256=03:21:61:7D:...`
- Установлен на эмуляторе, проверен: лобби, age gate первого запуска, тап YES → лобби.

**Сборка signed release APK:**
```bash
./scripts/build_android_release.sh  # читает .keystore.env
```

Скрипт инжектит пароль в `export_presets.cfg` только на время export и возвращает файл в исходное состояние (никаких секретов в коммитах).

### iOS
- `build/ios/VideoPoker.xcodeproj` — Xcode project, Team=`KQBUD75V9A` (KHRALZ), bundle=`com.khralz.videopoker`, iOS 15+
- Info.plist: оба landscape (Left + Right) на iPhone и iPad
- `PrivacyInfo.xcprivacy`: UserDefaults + FileTimestamp + SystemBootTime + DiskSpace задекларированы, tracking=false
- `xcodebuild iphoneos Release` → **BUILD SUCCEEDED**

**Пересборка iOS:**
```bash
rm -rf build/ios && mkdir -p build/ios
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "iOS" build/ios/VideoPoker.xcodeproj
./scripts/patch_ios_export.sh  # обязательно после каждого re-export!
```

Godot перезаписывает Info.plist и PrivacyInfo.xcprivacy на свои дефолты, скрипт `patch_ios_export.sh` возвращает наши App Store-ready версии.

---

## 5. Как запустить на устройствах

### Android эмулятор

```bash
~/Library/Android/sdk/emulator/emulator -avd VideoPoker_API34 -gpu host &
sleep 30
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
adb install -r "/Users/vadimprokop/Documents/Godot/video poker/build/video_poker_release.apk"
adb shell monkey -p com.khralz.videopoker -c android.intent.category.LAUNCHER 1
```

При первом запуске после clean install увидишь **Age Confirmation dialog**: "Are you 18 years or older?" с YES/NO. YES сохраняет флаг, дальше приложение работает нормально.

### iPhone через TestFlight (KHRALZ team)

Предусловия (разово):
1. В Xcode → Settings → Accounts добавить Apple ID с доступом к team `KQBUD75V9A`.
2. App Store Connect (под KHRALZ) → New App с bundle `com.khralz.videopoker`, Name "Video Poker".
3. Privacy policy URL — подготовить и прикрепить в App Store Connect (см. выше).
4. Age Rating → 17+ через "Frequent/Intense Simulated Gambling".
5. App Privacy → "Data Not Collected" по всем категориям.

Upload:
1. `open "/Users/vadimprokop/Documents/Godot/video poker/build/ios/VideoPoker.xcodeproj"`
2. Target `Any iOS Device (arm64)`
3. Product → **Archive** (5-10 мин)
4. Organizer → Distribute App → App Store Connect → **Export** (не Upload) → `build/ios/export/VideoPoker.ipa`
5. `./scripts/upload_testflight.sh` — закидывает .ipa через ASC API key (см. §11).
6. Через 5-15 мин build появится в TestFlight → iOS Builds
7. Пригласить internal tester'ов (emails в §11) → они принимают приглашение в TestFlight app

Альтернатива шагам 4-5: Organizer → Distribute App → Upload (как раньше, через UI).

### iPhone прямой Run (для быстрой проверки)
1. Подключить iPhone по USB
2. В Xcode выбрать iPhone как target
3. `⌘R`

Твой Apple ID должен быть в KHRALZ team с ролью Developer+ (попроси Ivan добавить если надо).

---

## 6. Что протестировать в первую очередь

Когда игра запустится на реальных устройствах — golden path:

| # | Сценарий | Ожидание |
|---|---|---|
| 1 | Первый запуск после clean install | Age confirmation modal появляется |
| 2 | Тап YES I AM 18+ | Modal исчезает, показывается лобби |
| 3 | Тап NO | App quits |
| 4 | Перезапуск после YES | Modal не появляется (флаг сохранён) |
| 5 | Лобби scroll + тап Jacks or Better | Переход в single-hand игру |
| 6 | DEAL → HOLD → DRAW → Evaluation | Нормальный game loop |
| 7 | Deuces and Joker Wild при bet=1, 4 deuces+joker | **10,000 coins? Нет! 9** (проверка критичного фикса) |
| 8 | Deuces and Joker Wild при bet=5, 4 deuces+joker | **10,000 coins** (jackpot) |
| 9 | Shop ⊕ | Title "FREE CHIPS" (раньше было GET CHIPS) |
| 10 | Multi-hand (Triple/Five/Ten) | Играбельно, multi-hand evaluation корректен |
| 11 | Ultra VP | Per-hand multipliers работают |
| 12 | Spin Poker | 3×5 grid, shutters/reels |
| 13 | BIG WIN / HUGE WIN | Автоматически при mult ≥ 4 |
| 14 | Smooth orientation на iPhone notch/Dynamic Island | Safe area соблюдается |

---

## 7. Git state

Ветка: `release_01` (форк от `main`).  
Последний коммит: `6fd7568 release(android/ios): enable emulator rendering + Apple Team ID`

Не закоммичено (за эту сессию):
- `project.godot` — orientation=0, gl_compatibility
- `export_presets.cfg` — team ID KQBUD75V9A, target_sdk=35, permissions cleanup, password removed
- `.gitignore` — добавлены `.keystore.env`, `.env`
- `data/translations.json` — age_gate + shop.title rename
- `scripts/save_manager.gd` — null check + XOR obfuscation + age_gate_confirmed
- `scripts/paytable.gd` — lazy autoload resolution
- `scripts/lobby_manager.gd` — AgeGate.show_if_needed()
- `scripts/age_gate.gd` — **новый файл**
- `scripts/variants/deuces_and_joker.gd` — jackpot fallback fix
- `scripts/build_android_release.sh` — **новый**
- `scripts/patch_ios_export.sh` — **новый**
- `tests/test_hand_evaluator.gd` — **новый**
- `tests/test_deck.gd` — **новый**
- `tests/test_deuces_and_joker.gd` — **новый**
- `tests/run_all.sh` — **новый**
- `docs/morning_testing_instructions.md` — **этот файл**

Unignored local: `.keystore.env` (содержит пароль, локально) — gitignored.

Когда одобришь изменения, скажи — закоммичу в `release_01`.

---

## 8. Что отложено / не сделано (требует твоего решения)

1. **App Store Connect app record** — нужен Ivan's account access.
2. **Google Play Console**: target audience 18+, IARC, Data safety — заполняется через UI.
3. **RevenueCat dashboard setup** — см. секцию 10 ниже.

## 9. Privacy policy

✅ Есть на GitHub Pages: `https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html`
Ссылка добавлена в Settings popup (шестерёнка → "PRIVACY POLICY" кнопка → открывает в системном браузере).

## 10. RevenueCat интеграция

Добавлена абстракция IAP через autoload `IapManager` (`scripts/iap_manager.gd`). Backend auto-detect:
- **STUB** (editor, dev-билд без плагина): покупка = instant credit из `configs/shop.json`
- **REVENUECAT** (production, плагин включён + API key): через `godotx_revenue_cat` plugin v2.1.0

Shop теперь маршрутизирует "FREE" кнопку через `IapManager.purchase(product_id)` → signals → UI animation.

### Что готово:
- Плагин `godotx_revenue_cat` скачан локально (851MB iOS + 56KB Android binaries)
- iOS + Android native libs установлены в `ios/plugins/revenue_cat/` и `android/revenue_cat/` (gitignored — download via `./scripts/install_revenuecat.sh`)
- GDScript side плагина закомичен в `addons/godotx_revenue_cat/`
- "Restore Purchases" кнопка в shop popup (App Store policy requirement)
- Translations: `shop.restore`, `shop.purchase_failed` в EN/RU/ES

### Что нужно сделать до первого release build:

1. **Установить binaries локально** (уже сделано на этой машине):
   ```bash
   ./scripts/install_revenuecat.sh
   ```

2. **Включить плагин в Godot editor:**
   - Открыть `project.godot` в Godot
   - Project → Project Settings → Plugins → галочка "Godotx RevenueCat"
   - Android export preset → секция Plugins → галочка "GodotxRevenueCat"
   - iOS export preset → секция Plugins → галочка "GodotxRevenueCat"

3. **Настроить RevenueCat dashboard** (~30 мин):
   - Новый проект "Video Poker Classic"
   - Apps: iOS (bundle `com.khralz.videopoker`, upload ASC API key) + Android (package `com.khralz.videopoker`, upload Google Play service account JSON)
   - В App Store Connect: создать 6 consumable IAPs `pack_01..pack_06` с ценами $0.99/$1.99/$5.99/$11.99/$22.99/$49.99
   - В Google Play Console: те же 6 consumable в Monetize → In-app products
   - В RC dashboard → Products: импортнуть/добавить все 6 IDs per store
   - В RC dashboard → Offerings: создать `default` offering со всеми 6 packages
   - Скопировать Public SDK keys: `appl_xxx` (iOS) + `goog_xxx` (Android)

4. **Прописать API keys:**
   - Обновить `scripts/iap_manager.gd`: установить `RC_API_KEY_IOS` + `RC_API_KEY_ANDROID`
   - **Не комитить ключи в публичный репо.** Public keys RC не критичны (их можно светить), но лучше хранить в env / Project Settings → Application

5. **Тестовые покупки:**
   - **iOS TestFlight**: создать Sandbox Testers в App Store Connect → Users and Access → Sandbox. На iPhone выйти из prod Apple ID → попытаться покупку → prompt просит sandbox login.
   - **Android**: загрузить signed AAB в Play Console → **Internal Testing track** (только через Closed Track IAPs работают). Добавить license testers в License Testing.
   - В RC dashboard → Sandbox tab смотреть события отдельно от prod

### Gotchas:
- Плагин `godotx_revenue_cat` — community, вышел 15 April 2026 (4 дня назад). Pin на version 2.1.0, fallback план если что — REST API подход через `godot-iap` + RC receipt endpoint.
- iOS xcframeworks большие (~850MB). Гит их не тянет — gitignored. Каждый новый dev машинно-запускает `./scripts/install_revenuecat.sh` разово.
- "Restore Purchases" для consumable — no-op логически, но **обязательно** иметь кнопку (App Store rejection reason 3.1.1).
- Цены должны браться из платформы (`product.price_string`), не из `configs/shop.json` `price_usd`. Apple/Google требуют localized pricing tiers.

---

## 9. Потенциальные проблемы

- **Эмулятор чёрный экран** — убедись что запущен с `-gpu host`, не `swiftshader_indirect`.
- **Провал tap на YES в age gate** — кнопка маленькая (160x50), на 2340x1080 landscape центрируется. Physical tap должен попадать в центр ~(2087, 992) на чистом landscape.
- **«Untrusted developer» на iPhone** — Settings → General → VPN & Device Management → Trust.
- **iOS provisioning profile fails** — Ivan должен пригласить тебя в KHRALZ team с Developer+ role.

---

## 11. App Store Connect API + TestFlight / Sandbox (общие аккаунты KHRALZ)

Данные взяты из общего справочника `SHARED_ACCOUNTS_REFERENCE.md`. Работают для любого app на Team `KQBUD75V9A`.

### API key (автоматизация загрузок в TestFlight)

Уже на машине:
- `~/.appstoreconnect/private_keys/AuthKey_X5959253U4.p8` (основной ASC API key, права `600`)
- `~/.appstoreconnect/private_keys/AuthKey_XL7R7TRL5N.p8` (In-App Purchase / Subscription key)

Переменные — в `.appstore.env` (gitignored). Шаблон — `.appstore.env.example`.
Скрипт загрузки — `scripts/upload_testflight.sh`.

```bash
./scripts/upload_testflight.sh build/ios/export/VideoPoker.ipa
# Использует xcrun altool + ASC API key, не требует пароля/2FA.
```

Про патч iOS-экспорта: `scripts/patch_ios_export.sh` теперь также проставляет
`ITSAppUsesNonExemptEncryption = false` (убирает export-compliance prompt)
и `TARGETED_DEVICE_FAMILY = "1"` (iPhone only — iPad layout не готов).

### Sandbox IAP тестер (один на все apps team KQBUD75V9A)

Email: `vakhrustalev+sandbox@gmail.com` (страна — США).
**Пароль — в `.appstore.env` → `APP_STORE_SANDBOX_PASSWORD`** (gitignored, не в публичном репо).

Добавляется в App Store Connect → Users and Access → Sandbox Testers (добавлен заранее — переиспользуем).
На iPhone: выйти из prod Apple ID в Settings → Media & Purchases → Sign Out → запустить app из TestFlight → при попытке покупки iOS предложит sandbox login.

### TestFlight internal testers

Раз создана запись в App Store Connect, пригласить:

| Email | Кто |
|-------|-----|
| `alzeydi@gmail.com` | Иван (владелец dev-аккаунта) |
| `ardnaskela91@mail.ru` | Александра |
| `vadimprokop12@gmail.com` | Вадим (Admin) |

Внутренние тестеры не требуют Beta Review — билд доступен сразу после обработки.

### App Store Connect app record — когда создавать

| Параметр | Значение |
|----------|----------|
| Name | `Video Poker` |
| Bundle ID | `com.khralz.videopoker` |
| SKU | `videopoker-classic-001` (любой уникальный) |
| Primary language | English (U.S.) |
| Platforms | iOS |
| Team | KHRALZ (`KQBUD75V9A`) |
| Privacy Policy URL | `https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html` |

После создания записи: скопировать `Apple ID` (числовой, не bundle) в `.appstore.env` → `APP_STORE_APP_APPLE_ID=`.

### RevenueCat привязка

RC проект **Video Poker Classic** создаётся на RC-аккаунте Вадима (не на аккаунте Ивана).
Привязка к App Store: в RC → Project Settings → Apps → iOS → загрузить **In-App Purchase key** (`AuthKey_XL7R7TRL5N.p8`, Key ID `XL7R7TRL5N`, Issuer `835ae8fb-4e40-4740-85c6-30a390729c1c`).
Привязка к Google Play: отдельный Service Account JSON — пока не настроен, см. §10 шаги 3.
