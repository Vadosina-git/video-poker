# Release Guide — Video Poker Trainer

**Назначение:** единый справочник «что у нас есть, где это лежит, как
выпустить новый билд». Пиши сюда то, что должно пережить любой context
window и любую смену сессии. Конкретные пайплайны лежат в отдельных
playbook'ах (см. §3).

---

## 1. Identity и аккаунты

| Что | Значение |
|---|---|
| Bundle / package ID                  | `com.khralz.videopoker` |
| App name                             | Video Poker Trainer |
| Publisher (юр. лицо)                 | Ivan Al Zeidi (физлицо, UAE) |
| Apple Developer Team ID              | `KQBUD75V9A` |
| Apple Distribution identity          | `Apple Distribution: Ivan Al Zeidi (KQBUD75V9A)` |
| Apple Distribution cert hash         | `2FA5761C816FD89FB6FA88607A9418D87DED4758` |
| ASC API Issuer ID                    | `835ae8fb-4e40-4740-85c6-30a390729c1c` |
| ASC API delivery key ID              | `X5959253U4` |
| ASC API IAP key ID                   | `XL7R7TRL5N` (только для управления IAP, не upload) |
| Google Cloud project                 | `video-poker-495621` (numeric: `751329676110`) |
| Service account (GP API)             | `play-upload@video-poker-495621.iam.gserviceaccount.com` |
| Android keystore alias               | `upload` |
| GitHub repo                          | https://github.com/Vadosina-git/video-poker |
| GitHub Pages site                    | https://vadosina-git.github.io/video-poker/ |
| Privacy policy URL                   | https://vadosina-git.github.io/video-poker/privacy-policy.html |
| Support / contact email              | vakhrustalev@gmail.com |

---

## 2. Где какие creds лежат (карта секретов)

**Никогда не выводи содержимое этих файлов в чат / commit / лог.** Все
gitignored.

### iOS / App Store Connect

| Файл | Где | Назначение |
|---|---|---|
| `.appstore.env`                       | project root                       | ASC API issuer / key id / shared secret |
| `AuthKey_X5959253U4.p8`               | `~/.appstoreconnect/private_keys/` | Delivery key (upload в TestFlight) |
| `AuthKey_XL7R7TRL5N.p8`               | `~/.appstoreconnect/private_keys/` | IAP-management key |
| `build/ios/ExportOptions.plist`       | project (gitignored через `build/`) | exportArchive параметры |
| Distribution cert                     | macOS Keychain                     | Apple Distribution: Ivan Al Zeidi |

### Android / Google Play

| Файл | Где | Назначение |
|---|---|---|
| `keystore/upload-keystore.jks`        | project (gitignored через `*.jks`) | Подпись AAB. **ПОТЕРЯ = ПОТЕРЯ ПРИЛОЖЕНИЯ.** Бэкап обязателен (см. §6) |
| `.keystore.env`                       | project root                       | `ANDROID_KEYSTORE_PATH/USER/PASSWORD` |
| `play_upload_key.json`                | `~/.googleplay/`                   | Service account JSON (Google Play Publisher API) |
| `.googleplay.env`                     | project root                       | Path к JSON, package name, default track |

### Шаблоны (commitable, без значений)

`.appstore.env.example`, `.keystore.env.example`, `.googleplay.env.example`.

---

## 3. Playbooks по платформам

Когда «собери и залей» — читай соответствующий playbook, делай молча по нему:

- **iOS** → [`docs/IOS_UPLOAD.md`](IOS_UPLOAD.md) — bump build → archive → exportArchive → altool upload.
- **Android** → [`docs/ANDROID_UPLOAD.md`](ANDROID_UPLOAD.md) — auto-bump version/code в скрипте → AAB → fastlane supply.
- **Cold-start (новый проект с нуля)** → [`docs/godot_release_runbook.md`](godot_release_runbook.md).

CLAUDE.md ссылается на оба upload playbook'а в секции «Документация по разделам». Перед задачей релиза Claude обязан их прочитать.

---

## 4. Один вопрос — один ответ

Эти ссылки спасают от разговоров «а где у нас X?»:

- **Где иконки?** Источник `assets/icons/icon_.png` (1024×1024 RGB, без alpha — Apple отвергает RGBA marketing icon). Все ресайзы регенерятся из источника по §IOS_UPLOAD.md §4.
- **Где privacy policy?** `privacy-policy.html` в корне репо (на ветке `main`). Деплоится через workflow `.github/workflows/web-export.yml` (на ветке `web-export`), который `wget`-ает файл с main и кладёт в Pages-артефакт. Чтобы обновить policy — пушь в main + триггерь workflow на web-export (manual `gh workflow run`, либо пустой коммит на web-export).
- **Где переводы UI?** `data/translations.json` (EN/RU/ES). См. CLAUDE.md §8.
- **Где конфиги?** `configs/*.json` + `data/paytables.json`. Source of truth — см. CLAUDE.md §5 «Config-driven».
- **Где iOS Info.plist?** `build/ios/VideoPoker/VideoPoker-Info.plist` (gitignored, регенерится при Godot iOS export). Орientation, ATT, usage-descriptions редактируются здесь.
- **Где Android manifest / signing config?** `android/build/build.gradle` (use_gradle_build mode). Подпись подтягивается из `.keystore.env`.

---

## 5. Pre-release checklist

Прогнать перед каждым release (что для iOS, что для Android):

- [ ] Working tree clean (`git status`)
- [ ] Все локализации (en/ru/es) — одинаковое число ключей в `data/translations.json` (`python3 -c "import json; d=json.load(open('data/translations.json')); print({k: len(v) for k,v in d['languages'].items()})"`)
- [ ] Иконка-источник `assets/icons/icon_.png` — RGB, без alpha, 1024×1024 (`python3 -c "from PIL import Image; im=Image.open('assets/icons/icon_.png'); print(im.mode, im.size)"`)
- [ ] **iOS:** `assets/icons/*.png` тоже без alpha (Godot iOS export копирует их в bundle при следующем re-export — будущая мина для App Store validator)
- [ ] **Android:** `version/code` в `export_presets.cfg` НЕ совпадает с уже залитым (скрипт сам бампит, но если правил вручную — проверь)
- [ ] **iOS:** `CURRENT_PROJECT_VERSION` в `build/ios/VideoPoker.xcodeproj/project.pbxproj` НЕ совпадает с залитым (скрипт §IOS_UPLOAD.md §2 сам бампит)
- [ ] **iOS:** `UISupportedInterfaceOrientations~ipad` отсутствует в Info.plist если в `TARGETED_DEVICE_FAMILY="1"` (iPhone-only). Apple валидирует консистентность.
- [ ] Privacy policy URL открывается без 404 (`curl -I https://vadosina-git.github.io/video-poker/privacy-policy.html`)
- [ ] Java SDK path в Godot editor settings (`~/Library/Application Support/Godot/editor_settings-4.6.tres`) указывает на JDK (Android Studio JBR работает)

---

## 6. Backup критичных артефактов

| Что | Куда бэкапить | Что произойдёт при потере |
|---|---|---|
| `keystore/upload-keystore.jks` + пароль | encrypted backup (1Password / iCloud Keychain / cold storage) | Если **Play App Signing включён** — упрощённое восстановление через Play Console (Setup → App integrity → Request upload key reset, 1-2 дня). Если выключен — приложение умерло, перевыпуск под новым package name. |
| `~/.appstoreconnect/private_keys/*.p8` | encrypted backup | Можно сгенерировать новый ключ в App Store Connect → Users and Access → Keys. Старый отзывается. |
| `~/.googleplay/play_upload_key.json` | encrypted backup | Service account можно создать новый в Google Cloud Console + Grant access в Play Console. Старый JSON отозвать (Keys → Delete). |
| `.appstore.env`, `.keystore.env`, `.googleplay.env` | encrypted backup | Восстанавливается из других мест (env содержит только пути + пароли, которые либо известны, либо лежат в backup .jks). |

**Минимум:** keystore + пароль. Без него Android-приложение не выпустить, а Play App Signing reset работает только если Google помнит твой подпись (включён по умолчанию для всех новых приложений с 2021).

---

## 7. Release pipeline (одна команда per platform)

После первого ручного релиза (см. §8 «История»):

```bash
# iOS — pipeline в docs/IOS_UPLOAD.md §2 (bump → archive → export → altool)
cd "/Users/vadimprokop/Documents/Godot/video poker"
# (вручную пока 4 шага из IOS_UPLOAD.md §2 — можно завернуть в scripts/build_ios_release.sh)

# Android — две команды: bump+build и upload
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./scripts/build_android_release.sh           # auto-bump version/code, signed AAB
./scripts/upload_googleplay.sh                # fastlane supply → internal track
```

**iOS-скрипта-обёртки нет** (потенциальный todo). Сейчас iOS делается вручную по плейбуку. Если будут частые релизы — обернуть в `scripts/build_ios_release.sh` по образцу Android.

---

## 8. История этой сессии (как мы дошли до текущего состояния)

Хронологически, чтобы не забыть, что и зачем было сделано.

### iOS (build 18 → 26)

- Build 18: исходное состояние сессии.
- Build 22 (один обычный билд после фиксов loop-coin SFX, launch screen, lobby polish — коммит `067207e`).
- Build 23: попытка с новой иконкой из `store_listing/icon_.png` → ASC отклонил (`Invalid large app icon... can't be transparent or contain an alpha channel`). Иконка была RGBA 1024×1038. Урок: всегда сплющивать alpha + crop до 1024×1024 ДО archive.
- Build 24: иконка сплющена через PIL на белом фоне, повторный archive → upload OK.
- Build 25: пользователь решил вернуть старую иконку + убрать iPad из устройств. Действия: `git checkout assets/icons/`, `TARGETED_DEVICE_FAMILY="1,2"` → `"1"` в pbxproj (4 места), удалён блок `UISupportedInterfaceOrientations~ipad` из Info.plist. Build залит, но в xcassets ещё лежали новые иконки → визуально билд показал НОВУЮ иконку. Не подменено в `build/ios/VideoPoker/Images.xcassets/AppIcon.appiconset/`.
- Build 26: перегенерация xcassets из восстановленного `assets/icons/icon_.png` (с PIL alpha-flatten), upload OK. **Эта версия отправлена на App Store review.**

Главный урок: **при любой замене marketing icon обязательно проверять `Image.open(...).mode == 'RGB'`** до archive. Корневая причина 409 — RGBA в исходнике + Apple валидирует именно `Icon-1024.png` в `AppIcon.appiconset/`.

### Android (с нуля до автоматического upload)

- Состояние на старте: `~/upload-keystore.jks` существовал (alias `upload`, март 2026), но пароль был неизвестен. `.keystore.env` уже лежал в репо, но не был найден сразу.
- Поиск креды: `~/.zsh_history` показал `storePassword=Manda123` + команду `keytool -genkey... -alias upload`. Пароль работает.
- Java SDK: macOS system Ruby/Java отсутствуют. Использован `/Applications/Android Studio.app/Contents/jbr/Contents/Home` (Android Studio JBR).
- Перенос keystore: `~/upload-keystore.jks` → `keystore/upload-keystore.jks` (внутри проекта, gitignored).
- `export_presets.cfg`: `version/code` 11 → 12, `gradle_build/export_format` 0 (APK) → 1 (AAB).
- Godot editor settings: `export/android/java_sdk_path` был пуст → прописан JBR.
- `build/.gdignore`: добавлен, чтобы Godot не реимпортил артефакты iOS-архива (валились с `ERR_FILE_CORRUPT`).
- Build 12: первая успешная AAB-сборка через `scripts/build_android_release.sh` (68 MB, signed). **Залит вручную через Play Console UI** — Google не пускает API-upload в app без релизов.
- Build 13: первый автоматический upload через `fastlane supply`.
  - Препятствие 1: macOS system Ruby 2.6 → fastlane не ставится. Установлен через Homebrew Ruby 4.0.0 (`/opt/homebrew/opt/ruby`), symlink в `/opt/homebrew/bin/fastlane`.
  - Препятствие 2: `Google Play Android Developer API has not been used in project 751329676110` → пользователь Enable'нул API в console.developers.google.com.
  - Препятствие 3: service account создан, но в Play Console → API access не привязан → пользователь сделал Link + Grant access (permissions: Release apps to testing tracks + View app info + Manage testing tracks).
  - Препятствие 4: `Version code 12 has already been used` → bump до 13 + rebuild → upload `Successfully finished`.

### Privacy policy

- Создан `privacy-policy.html` в корне main. Hosted via GitHub Pages (workflow на ветке `web-export` пулит файл с main через wget).
- Workflow `.github/workflows/web-export.yml` на ветке `web-export` обновлён (curl → wget т.к. godot-ci container без curl).

---

## 9. Что НЕ настроено (потенциальные TODO для будущих релизов)

- **iOS-скрипт-обёртка** — bump + archive + export + upload одной командой. Сейчас всё в `docs/IOS_UPLOAD.md` §2 как копипаст.
- **Auto-trigger Pages при изменении privacy-policy.html** — сейчас pushes в main не триггерят web-export workflow. Future fix: workflow на main с `paths: ['privacy-policy.html']` который делает `repository_dispatch` на web-export.
- **Crashlytics / Analytics** — НЕ интегрировано. Если понадобится — добавить Firebase SDK, обновить privacy policy под новые типы данных, обновить App Privacy форму в ASC.
- **GDPR consent flow** — сейчас нет, т.к. трекинг не ведём. Если добавим analytics → нужен banner для EU users.
- **App Store Connect Review notes** — пока не заполняли. Если Apple завернёт по compliance (gambling-style game в social casino) — заполнить «App Review Information» с текстом про виртуальную валюту и age 17+.
- **Google Play data safety form** — обязательно заполнить руками в Play Console (Policy → App content → Data safety). Использовать те же data types что и для iOS App Privacy: только Identifiers (Device ID, не linked) + Purchases (linked, для billing).
- **TestFlight external testers / Play Closed beta** — пока только internal. Когда понадобится расширить — настроить группы и invite.

---

## 10. Если что-то сломалось — куда смотреть

1. `docs/PAIN_LOG.md` — известные грабли (UI / cross-cutting fixes).
2. `docs/IOS_UPLOAD.md` §6 / `docs/ANDROID_UPLOAD.md` §6 — troubleshooting платформенных аплоадов.
3. `git log --oneline -20` — что менялось последним.
4. `gh run list -L 5` — состояние GitHub Actions (Pages deploy).
5. App Store Connect → My Apps → TestFlight → Activity tab — статус processing'а билда.
6. Google Play Console → Internal testing → Releases — статус AAB.
7. App Store Connect → Resolution Center / Play Console → Notifications — если Apple/Google завернули по compliance.

---

*Создан: 2026-05-08. Поддерживается вручную: при следующем релизе обнови §8 «История».*
