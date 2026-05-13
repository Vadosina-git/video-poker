# Android → Google Play — Autonomous Upload Playbook

**Цель:** этот файл — единственный источник правды для Claude по сборке +
подписи + аплоаду Android-билда в Google Play Console. Все creds, пути,
параметры подписей и грабли — здесь. **Если ты Claude и видишь задачу
"собери и залей в Play Console" — выполняй по этому файлу не задавая
уточняющих вопросов.**

Парный документ: `docs/IOS_UPLOAD.md` — тот же подход для iOS / ASC.

---

## 0. Pre-flight checklist (делай молча)

```bash
# 1. Креды на месте?
test -f .keystore.env && echo "keystore env: OK" || echo "keystore env: MISSING"
test -f .googleplay.env && echo "gplay env: OK" || echo "gplay env: MISSING"

# 2. Keystore физически есть?
KS=$(grep -E '^ANDROID_KEYSTORE_PATH=' .keystore.env | cut -d= -f2- | tr -d '"')
test -f "$KS" && echo "keystore: OK ($KS)" || echo "keystore: MISSING"

# 3. Java SDK для Godot Android export
test -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" && \
    echo "JDK: OK" || echo "JDK: MISSING (install Android Studio)"

# 4. Godot editor settings знают про JDK
grep "java_sdk_path" "$HOME/Library/Application Support/Godot/editor_settings-4.6.tres"
# Должно быть: export/android/java_sdk_path = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"

# 5. fastlane (для upload)
which fastlane >/dev/null && echo "fastlane: OK" || echo "fastlane: MISSING (gem install fastlane)"
```

Если хоть один MISSING — см. §6 «Troubleshooting».

---

## 1. Где что лежит

| Что | Где | Заметки |
|---|---|---|
| Upload keystore                    | `keystore/upload-keystore.jks`                       | **Gitignored.** Без него подписать AAB нельзя. **Потеря = потеря приложения**, восстановить можно только через Play App Signing reset (1-2 дня). |
| Keystore creds (env)               | `.keystore.env` (project root)                       | Gitignored. `ANDROID_KEYSTORE_PATH/USER/PASSWORD`. |
| Шаблон keystore env                | `.keystore.env.example`                              | Закоммичен. |
| Google Play service account JSON   | путь в `.googleplay.env` (см. ниже)                  | **НЕ кладть в репо**, держать в `~/.googleplay/` или похожем. |
| Google Play env                    | `.googleplay.env` (project root)                     | Gitignored. `GOOGLE_PLAY_JSON_KEY_PATH`, `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_TRACK`. |
| Шаблон google play env             | `.googleplay.env.example`                            | Закоммичен. |
| Bundle ID                          | `com.khralz.videopoker`                              | В `export_presets.cfg` (`package/unique_name`). |
| Keystore alias                     | `upload`                                             | Hardcoded при генерации. |
| Godot Android export preset        | `export_presets.cfg` `[preset.0]`                    | `gradle_build/export_format=1` (AAB), не APK. |
| Build script                       | `scripts/build_android_release.sh`                   | Подгружает `.keystore.env`, инжектит в preset, экспортит, реверт. |
| Upload script                      | `scripts/upload_googleplay.sh`                       | Подгружает `.googleplay.env`, дёргает `fastlane supply`. |
| Marketing icon (источник)          | `assets/icons/icon_.png` (1024×1024 RGB, без alpha)  | Тот же что для iOS. Godot ресайзит при export. |
| Output AAB                         | `build/video_poker_release.aab`                      | По умолчанию (можно переопределить аргументом скрипта). |

### Маппинг UI → API track names

Названия треков в Play Console UI **не совпадают** с именами треков в
API. `.googleplay.env` → `GOOGLE_PLAY_TRACK="<api-name>"`:

| Play Console UI       | API track name |
|-----------------------|----------------|
| Internal testing      | `internal`     |
| Closed testing        | `alpha`        |
| Open testing          | `beta`         |
| Production            | `production`   |

Custom closed-test треки имеют свои имена — получить можно через
`GET androidpublisher/v3/applications/<pkg>/edits/<id>/tracks`
после открытия edit-сессии.

---

## 2. Полный пайплайн (копипаст в одну сессию)

```bash
cd "/Users/vadimprokop/Documents/Godot/video poker"

# Шаг 1 — bump version/code (ОБЯЗАТЕЛЬНО, иначе Play Console отклонит как duplicate)
CURRENT=$(grep -m1 "^version/code=" export_presets.cfg | cut -d= -f2)
NEXT=$((CURRENT + 1))
sed -i '' "s|^version/code=.*|version/code=$NEXT|" export_presets.cfg
echo "version/code: $CURRENT → $NEXT"

# Шаг 2 — собрать подписанный AAB
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
./scripts/build_android_release.sh

# Шаг 3 — upload в Play Console через fastlane supply
./scripts/upload_googleplay.sh
```

**Ожидаемый успех:** AAB по пути `build/video_poker_release.aab`, fastlane
печатает `Successfully finished the upload to Google Play`. Через 5-15 мин
билд появится во внутреннем тестовом треке (или в выбранном `GOOGLE_PLAY_TRACK`).

---

## 3. Первая загрузка — она ручная

Google Play API **не позволяет** загружать в приложение, у которого нет ни
одного релиза. Поэтому **первый AAB** загружается через Play Console
вручную:

1. Создаёшь app в Play Console (один раз).
2. Заполняешь обязательные данные (privacy policy, content rating, targeting).
3. Загружаешь `build/video_poker_release.aab` через UI: **Internal testing →
   Create new release → Upload → выбрать .aab**.
4. Нажимаешь **Save → Review release → Start rollout**.

После этого **все последующие** загрузки идут через `scripts/upload_googleplay.sh`.

---

## 4. Setup Google Play API (один раз)

Чтобы скрипт работал, нужен service account с правами на upload:

### 4.1 Создать service account

1. Открой Google Cloud Console → выбери проект, привязанный к Play Console
   (или создай новый).
2. **IAM & Admin → Service Accounts → Create service account**.
3. Имя: `play-upload`. Роль не обязательна на этом шаге (даём в Play Console).
4. После создания → **Keys → Add Key → Create new key → JSON**. Скачается
   файл вида `<project>-<id>.json`. **Это твой ключ. Не теряй, не коммить.**

### 4.2 Привязать в Play Console

1. Play Console → **Settings (Setup) → API access**.
2. Найди созданный service account (Google автоматически покажет email
   вида `play-upload@<project>.iam.gserviceaccount.com`).
3. **Grant access**. Минимальные permissions для upload в internal/closed:
   - View app information and download bulk reports
   - Manage testing tracks (для internal/alpha/beta)
   - Release apps to testing tracks
4. Apply.

### 4.3 Положить ключ + создать env

```bash
mkdir -p ~/.googleplay
mv ~/Downloads/<скачанный-ключ>.json ~/.googleplay/play_upload_key.json
chmod 600 ~/.googleplay/play_upload_key.json

# Заполнить .googleplay.env (см. .googleplay.env.example)
cat > .googleplay.env <<EOF
GOOGLE_PLAY_JSON_KEY_PATH="$HOME/.googleplay/play_upload_key.json"
GOOGLE_PLAY_PACKAGE_NAME="com.khralz.videopoker"
GOOGLE_PLAY_TRACK="internal"
EOF
```

### 4.4 Поставить fastlane

```bash
gem install fastlane          # или: brew install fastlane
fastlane --version
```

После этого `./scripts/upload_googleplay.sh` готов к работе.

---

## 5. Что коммитить, что нет

| Путь | Git |
|---|---|
| `keystore/upload-keystore.jks`        | ❌ gitignored |
| `keystore/`                            | каталог пустой по умолчанию (только содержимое gitignored через `*.jks`) |
| `.keystore.env`                        | ❌ gitignored |
| `.keystore.env.example`                | ✅ commit (шаблон) |
| `.googleplay.env`                      | ❌ gitignored |
| `.googleplay.env.example`              | ✅ commit (шаблон) |
| `~/.googleplay/play_upload_key.json`   | ❌ — лежит вне репо |
| `docs/ANDROID_UPLOAD.md` (этот файл)   | ✅ commit |
| `scripts/build_android_release.sh`     | ✅ commit |
| `scripts/upload_googleplay.sh`         | ✅ commit |
| `build/`                               | ❌ gitignored (включая `.aab`) |

---

## 6. Troubleshooting

### `error: .keystore.env not found in project root`
Заполни по `.keystore.env.example`. Креды от текущего keystore пишутся в этот
файл (alias всегда `upload`).

### `Cannot export project with preset "Android" due to configuration errors:
Требуется указать верный путь к Java SDK в настройках редактора.`
В editor_settings-4.6.tres пустой `java_sdk_path`. Прописать:
```bash
sed -i '' 's|export/android/java_sdk_path = ""|export/android/java_sdk_path = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"|' \
    "$HOME/Library/Application Support/Godot/editor_settings-4.6.tres"
```

### Godot reimports артефакты из `build/ios/*.xcarchive` / `build/android/...` и валится с `ERR_FILE_CORRUPT`
Положи `.gdignore` в `build/` (или в подкаталог, который не должен импортироваться):
```bash
touch build/.gdignore
```

### `400 apkUpgradeVersionConflict` / `Version code N has already been used`
Ты не bump'нул `version/code`. См. §2 шаг 1.

### `Only releases with status draft may be created on draft app`
App в state «draft» (Production пустой / первый review не пройден).
Google требует чтобы **все** releases в edit-сессии были `draft`.
Existing internal release с `status=completed` (опубликованный для
internal testers) автоматически копируется в новый edit и валит
commit, даже если PUT шёл только на другой track.

**Воркараунд:** первый release в каждом новом track (Closed/Open/Production)
делать через Play Console UI вручную (drag-and-drop AAB).
После того как app выйдет из draft state (= после первого
Production approval) — API/fastlane заработают полностью.
До этого `./scripts/upload_googleplay.sh` работает только на
`internal` track. См. `docs/PAIN_LOG.md` запись от 2026-05-11.

### `Your app targets Android 13 (API 33) or above. You must declare the use of advertising ID in Play Console.`
Декларировать в Play Console → Policy and programs → App content →
Advertising ID. У нас игра **не использует** Advertising ID. Проверка:
```bash
java -jar /tmp/bundletool.jar dump manifest --bundle build/video_poker_release.aab | grep -iE "AD_ID|advertis"
```
Если пусто — `permission com.google.android.gms.permission.AD_ID`
отсутствует. Ответ в форме: **No, my app does not use advertising ID**.

### `403 The caller does not have permission`
Service account не привязан в Play Console → Settings → API access, либо у него
нет permission «Release apps to testing tracks». Проверь email service account
в Play Console.

### `fastlane: command not found`
Поставь: `gem install fastlane`. Если ругается на права — `sudo gem install
fastlane` (на macOS системный Ruby требует sudo). Лучше — поставить через
`rbenv`/`asdf` свой Ruby.

### `Could not find package_name`
В `.googleplay.env` пустой `GOOGLE_PLAY_PACKAGE_NAME`. Должен быть
`com.khralz.videopoker` (тот же bundle ID что и в Godot preset
`package/unique_name`).

### Иконка в Play Console не обновилась после upload
Иконка приложения в Play Console — отдельный артефакт (1024×1024 PNG,
без альфы). Загружай через UI: **Main store listing → App icon**. AAB
обновляет только in-app launcher icon, не маркетинговую.

### Потерял пароль от upload keystore
Не паника. Если включён **Play App Signing** (включён по умолчанию для всех
новых приложений с 2021):
1. Сгенерируй **новый** upload keystore: `keytool -genkey -v -keystore
   keystore/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000
   -alias upload`.
2. Экспортируй сертификат: `keytool -export -rfc -keystore
   keystore/upload-keystore.jks -alias upload -file new_upload_certificate.pem`.
3. Play Console → Setup → App integrity → Upload key certificate → **Request
   upload key reset**, приложи `.pem`. Google ответит за 1-2 дня.

Если Play App Signing **выключен** (старый flow до 2021) — приложение умерло,
надо публиковать как новое с другим package name.

---

## 7. Правила для Claude

1. **Не спрашивай где креды** — они в `.keystore.env` и `.googleplay.env`. Грепай
   их перед задачей вопросов.
2. **Не спрашивай "можно ли запускать gradle/fastlane"** — если пользователь
   сказал "собери и залей", запускай весь пайплайн §2.
3. **Перед сборкой всегда bump `version/code`** — иначе Play Console отвергнет
   с 400. Делай превентивно, не дожидайся ошибки.
4. **Никогда не выводи в чат** содержимое `.keystore.env`, `.googleplay.env`,
   `*.jks`, JSON-ключ Google Cloud. Используй `source` / `set -a; .`, не
   `cat`. Если нужно проверить что переменная задана — печатай только
   `<set>`/`<empty>`.
5. **Никогда не коммить keystore или JSON-ключ** — даже если git status
   показывает их (значит .gitignore сломан, чини .gitignore, не игнорируй).
6. Прерывайся ТОЛЬКО если: (а) `.keystore.env` отсутствует И значения нельзя
   вывести из других проектных файлов; (б) keystore физически отсутствует;
   (в) пользователь явно отменил действие.
