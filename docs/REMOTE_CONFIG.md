# Remote Config — Firebase Integration

Слой удалённого тюнинга поверх локальных `configs/*.json`. Позволяет менять
балансы, тайминги и фичефлаги без выпуска нового билда. Сами локальные
JSON остаются «фундаментом» — Firebase Remote Config работает как набор
заплаток поверх, применяемых при старте каждой сессии.

Документ описывает: автозагрузки, поток данных, kill-switch, deep-merge,
формат параметров в Firebase Console, операционные сценарии и
ограничения. Для базовой работы с локальными `configs/*.json` см.
[CONFIG_REFERENCE.md](CONFIG_REFERENCE.md).

---

## 1. Архитектура

### Autoload-порядок (project.godot → `[autoload]`)

| # | Autoload | Зависимости |
|---|---|---|
| 1 | `ConfigManager` | — |
| 2 | `SaveManager` | ConfigManager (для `_seed_first_launch_defaults`) |
| 3 | **`RemoteConfigManager`** | ConfigManager + SaveManager |
| 4… | SoundManager / Translations / VibrationManager / BigWinOverlay / ShopOverlay / IapManager / ThemeManager | в основном ConfigManager |

`RemoteConfigManager` зарегистрирован третьим намеренно:
- ConfigManager уже загрузил локальные JSON в свои поля
- SaveManager уже прочитал `app_instance_id` (стабильный Firebase client id)
- ConfigManager в своём `_ready` подключается к сигналу
  `RemoteConfigManager.fetch_completed` — это работает даже до того, как
  `_ready` RemoteConfigManager-а отработал, потому что в Godot 4 все
  autoload-ноды добавляются в SceneTree до того, как у любой запустится `_ready`

### Поток данных при старте сессии

```
1. ConfigManager._ready()
   → грузит configs/*.json в свои var-поля
   → connect(RemoteConfigManager.fetch_completed → _on_remote_fetch_completed)

2. SaveManager._ready()
   → load_game() читает app_instance_id из save.json (или оставляет "" при первом запуске)

3. RemoteConfigManager._ready()
   → читает SaveManager.app_instance_id; если пуст — генерирует UUID и сохраняет
   → POST на Firebase Remote Config REST API
   → таймаут 10 секунд, async (старт игры не блокируется)

4. Когда Firebase ответил (или таймаут):
   → парсит entries (каждое значение — JSON-строка)
   → проверяет kill-switch remote_config_enabled
   → если switch != "true": _remote остаётся пуст, эмиссия fetch_completed(true)
   → если switch == "true": заполняет _remote и эмитит fetch_completed(true)

5. ConfigManager._on_remote_fetch_completed(success):
   → если success: для каждого имени из _REMOTE_OVERRIDABLE
     - берёт текущее (локальное) значение поля
     - делает deep-merge с remote
     - записывает результат обратно через set(name, merged)
```

К моменту, когда игрок нажимает кнопку в лобби, оверрайды уже применены.
В быстрой сети — за 100–300 мс после старта. В худшем случае таймаут 10 с
→ молчаливый fallback на чистую локалку.

---

## 2. Kill-switch

Параметр в Firebase: **`remote_config_enabled`** (тип `Boolean`, по умолчанию `false`).

| Значение в Firebase | Эффект |
|---|---|
| отсутствует | оверрайды НЕ применяются → игра на 100% локальная |
| `false` | оверрайды НЕ применяются |
| `true` | оверрайды применяются (deep-merge поверх локалки) |

Семантика: «opt-in»-предохранитель. Если в Firebase Remote Config никогда
не были опубликованы параметры — клиент работает строго на локальных
`configs/*.json`. Это безопасный default: пустой / неправильно настроенный
проект Firebase не может случайно поломать игру.

### Когда полезен

1. **Аварийный откат.** В Firebase обнаружен кривой параметр, ломающий
   игру у живых пользователей → переключаешь флаг в `false`, **Publish**.
   На следующем запуске у клиента включается локальный fallback — без
   передеплоя билда.
2. **Песочница.** Готовишь новый набор параметров в консоли, не уверен
   что не сломает прод → держишь флаг в `false` до финальной публикации,
   потом одним переключением вкатываешь.
3. **Сегментация.** В будущем при condition-based rollout-е можно
   включать оверрайды только для определённой версии билда / платформы /
   доли пользователей через Firebase conditions.

### Что важно

- Сам ключ `remote_config_enabled` в `_remote` НЕ попадает — он только
  управляющий, не данные. Цикл его явно пропускает.
- Лог `[RemoteConfig] kill-switch active, using local configs`
  выводится **всегда**, не зависит от `_DEBUG`. Это критическое
  состояние, которое должно быть видно в продакшене.

---

## 3. Deep-merge

Применение remote происходит **рекурсивно**, не по принципу «полная замена
файла». Алгоритм в `ConfigManager._deep_merge(base, override)`:

```
для каждого ключа в override:
    если result[key] и override[key] оба Dictionary
        → рекурсия (мердж в глубину)
    иначе
        → override[key] перетирает result[key]
```

### Следствия

| Сценарий | Поведение |
|---|---|
| Поле есть только в локалке | сохраняется в итоге |
| Поле есть только в remote | добавляется в итог |
| Поле в обоих, оба — Dictionary | сливаются рекурсивно |
| Поле в обоих, скаляр / число / строка / bool | remote выигрывает |
| Поле в обоих, **массив vs массив** | **remote перетирает целиком**, не объединяет по индексу |
| Поле есть в локалке, в remote `null` | результат `null` (deep-merge не «умеет удалять») |

### Защита от потери полей

Главное преимущество vs полной замены: если в Firebase ты задаёшь
**частичный** параметр — например, `gift = {"chips": 99999}` без
`interval_hours` — игрок получит изменённое количество монет, а
интервал останется из локального `gift.json`. Это уменьшает объём
тестирования: меньше шанс сломать соседние поля.

### Когда массивы могут удивить

Если локальный конфиг содержит массив (например, `paytable` в
`machines.machines.<id>.paytable`), а в Firebase ты публикуешь тот же
массив, но короче — лишние элементы из локалки потеряются. Если нужно
«добавить одну строчку выплаты» через remote — это не получится через
текущий мердж: массивы заменяются целиком. Нужно публиковать полный
массив.

---

## 4. Список overridable конфигов

`ConfigManager._REMOTE_OVERRIDABLE` (13 имён). Любое из этих имён может
быть положено в Firebase как параметр типа JSON.

| Имя в Firebase | Локальный файл | Что покрывает |
|---|---|---|
| `animations` | `configs/animations.json` | Тайминги deal/draw/win/blink |
| `balance` | `configs/balance.json` | Per-mode денежные ладдеры, BIG/HUGE WIN пороги |
| `economy` | `configs/economy.json` | Game depth, double-or-nothing rules |
| `features` | `configs/features.json` | Feature flags + UI visibility + default theme |
| `gift` | `configs/gift.json` | Free-credits таймер + chip-cascade |
| `init_config` | `configs/init_config.json` | First-launch defaults |
| `lobby_order` | `configs/lobby_order.json` | Порядок и видимость машин per-mode |
| `machines` | `configs/machines.json` | Все 10 машин, paytables, deck, ultra-multipliers |
| `shop` | `configs/shop.json` | IAP-пакеты, FREE-tier cooldown'ы |
| `sounds` | `configs/sounds.json` | event → mp3 mapping |
| `vibration` | `configs/vibration.json` | Длительности haptic + heavy events |
| `classic` | — *(remote-only)* | Зарезервировано под remote-overrides темы Classic |
| `supercell` | — *(remote-only)* | Зарезервировано под remote-overrides темы Supercell |

`classic` и `supercell` инициализированы пустыми `{}` в ConfigManager —
локальных файлов под них нет. Зарезервированы для будущей интеграции
ThemeManager-а с remote.

---

## 5. Платформенные ключи

`OS.get_name()` определяет какие credentials использовать:

| OS | Используется |
|---|---|
| `iOS` | iOS API key + iOS App ID |
| `Android` | Android API key + Android App ID |
| `Web` | Web API key + Web App ID |
| **прочее** (macOS / Windows / Linux Editor) | iOS как fallback |

Все три набора ключей **захардкожены в `_IOS_API_KEY` / `_IOS_APP_ID` /
`_ANDROID_API_KEY` / …** в `scripts/remote_config_manager.gd`. Это норма
для Firebase REST API — клиентские ключи Remote Config не являются
секретами, они встроены в любые публичные сборки и видны при
декомпиляции. Безопасность Firebase строится на App Check + Security
Rules, а не на скрытии ключей.

Дублирующая копия лежит в `firebase/google-services.json` (Android) и
`firebase/GoogleService-Info.plist` (iOS) — gitignored, хранятся для
будущей интеграции нативного Firebase SDK через Godot-плагин (если
понадобится Analytics / Crashlytics / FCM).

`PROJECT_ID = video-poker-trainer-59777` — общий для всех платформ.

### Edge case: macOS Editor

В редакторе `OS.get_name()` возвращает `macOS` → берутся iOS ключи. Для
fetch'а это работает (REST API не валидирует платформу строго), но в
Firebase Analytics редакторские запросы будут засчитаны как iOS-трафик.
Не критично для Remote Config (там аналитики нет), но при будущей
интеграции Analytics-SDK имей в виду.

---

## 6. `app_instance_id`

Стабильный Firebase client identifier. Генерируется один раз при первом
запуске, сохраняется в `SaveManager.app_instance_id`, читается на всех
последующих запусках.

### Зачем стабильный

1. **Сегментация / A-B тесты в Firebase.** Если `instance_id` меняется
   при каждом старте, Firebase видит каждую сессию как нового клиента и
   не может удерживать игрока в одной экспериментальной когорте.
2. **Кэш на стороне Firebase.** Firebase Remote Config держит ответ
   ~12 часов на стороне сервера, ключ кэша = `instance_id`. Стабильный
   ID = меньше нагрузки на endpoint и меньше расхода квоты.

### Жизненный цикл

```
Первый запуск:
  SaveManager.app_instance_id = ""  → RemoteConfigManager генерирует UUID
  → пишет в SaveManager.app_instance_id
  → SaveManager.save_game() сразу пишет на диск
  → ID живёт до удаления save.json

Последующие запуски:
  SaveManager.app_instance_id уже заполнен → используется как есть
```

### Когда нужно сбросить

Если меняешь параметры в Firebase Console и хочешь увидеть свежий ответ
от REST API НЕ дожидаясь TTL кэша:

```bash
rm "$HOME/Library/Application Support/Godot/app_userdata/Video Poker Trainer/save.json"
```

При следующем запуске `_seed_first_launch_defaults` пересоздаст save с
новым `instance_id` → Firebase отдаст свежий шаблон, не из кеша.

В продакшене этого делать **не нужно** — игроки всё равно получат
обновления в течение 12 часов автоматически.

### Безопасность

`app_instance_id` хранится в `save.json` под XOR-обфускацией (ключ `0x5A`,
см. `SaveManager._obfuscate`). Это не криптография, а защита от
случайного просмотра. Игрок может расшифровать и подменить ID — Firebase
любую строку проглотит. Подмена откроет окно для попадания в другую
A/B-когорту, но ничего ценного через Remote Config обычно не
передаётся. Не клади в Remote Config выплаты, RTP, балансы реальной
экономики.

---

## 7. Debug-логи

Флаг `const _DEBUG := false` в `scripts/remote_config_manager.gd:8`.
По умолчанию выключен.

### Что выводится при `_DEBUG := false` (продакшен)

- `[RemoteConfig] kill-switch active, using local configs` — когда флаг
  не `true` (выводится **безусловно**)
- `[ConfigManager] remote overrides applied: [...]` — когда оверрайды
  применились (выводится **безусловно**, не зависит от `_DEBUG`)
- `push_warning(...)` — при сетевых / парсинг-ошибках

### Что добавляется при `_DEBUG := true` (отладка)

- `[RemoteConfig] platform=… app_id=… instance_id=…` (на старте fetch'а)
- `[RemoteConfig] POST -> <full URL with API key>` ⚠️ **API ключ в URL** —
  не делай скриншоты Output для публичных каналов с включённым debug
- `[RemoteConfig] response result=… http=… bytes=…`
- `[RemoteConfig] state=UPDATE | NO_CHANGE | NO_TEMPLATE | …`
- `[RemoteConfig] applied overrides: [...]`
- При HTTP-ошибке — первые 500 байт тела ответа (часто содержат
  человекочитаемое сообщение от Firebase)

Включай `_DEBUG := true` только для локальной отладки и не коммить в
таком состоянии.

---

## 8. Типы параметров в Firebase Console

Поведение зависит от `Data type`, который выбран при создании параметра:

| Data type в консоли | Что приходит в `entries[key]` | Корректно ли парсится |
|---|---|---|
| **JSON** | строка с JSON-объектом | ✅ парсится в Dictionary, кладётся в `_remote` |
| **Boolean** | строка `"true"` или `"false"` | ✅ для `remote_config_enabled` (kill-switch) |
| **Number** | строка вида `"42"` | ❌ НЕ Dictionary → `push_warning`, пропускается |
| **String** | сырая строка | ❌ если не валидный JSON-объект — пропускается |

### Правило

- `remote_config_enabled` — тип **Boolean**
- Все 13 overridable конфигов (`balance`, `gift`, `machines` и т.д.) —
  тип **JSON**

Если случайно создашь параметр `gift` со типом String и значением
`"hello"` — увидишь в логе `RemoteConfig: entry 'gift' is not a JSON
object, skipped`, оверрайд не применится.

### Пример параметра JSON

В Firebase Console → Add parameter → Name: `gift` → Data type: JSON →
Default value:

```json
{
  "interval_hours": 0.5,
  "chips": 50000,
  "claim_animation": {"duration": 1.5}
}
```

Important: значение **должно быть JSON-объектом** (`{...}`), не массивом
и не скаляром. Массивы и скаляры пропускаются с warning.

После заведения / правки параметра — обязательно нажать **Publish
changes** в правом верхнем углу консоли. Без публикации REST API будет
отдавать предыдущую версию шаблона.

---

## 9. Операционные сценарии

### Опубликовать новый оверрайд

1. Firebase Console → Remote Config → **Add parameter**
2. Имя = одно из 13 (`balance` / `gift` / …) или `remote_config_enabled`
3. Тип = JSON (для конфигов) или Boolean (для kill-switch'а)
4. Значение
5. **Publish changes**

### Аварийный откат

1. Firebase Console → Remote Config → найти `remote_config_enabled`
2. Изменить значение на `false` → **Publish changes**
3. На следующем запуске у всех клиентов включится полная локалка

### Локально проверить, что доехало

1. Включить `_DEBUG := true` в `scripts/remote_config_manager.gd:8`
2. Удалить save: `rm "$HOME/Library/Application Support/Godot/app_userdata/Video Poker Trainer/save.json"`
3. Перезапустить проект (F5 в Godot)
4. В Output смотреть на блок `[RemoteConfig] …` и финальный
   `[ConfigManager] remote overrides applied: [...]`
5. После проверки `_DEBUG := false`

### Прогон без редактора (headless)

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path "/Users/vadimprokop/Documents/Godot/video poker" \
  --headless --quit-after 600 2>&1 | grep -E "RemoteConfig|ConfigManager"
```

---

## 10. Что НЕ класть в Firebase

В Remote Config приемлемо хранить:
- ✅ Тайминги анимаций (`animations`)
- ✅ Тайминг подарка (`gift.interval_hours`, `gift.chips`)
- ✅ Feature flags (`features.feature_flags.*`)
- ✅ UI visibility (`features.ui_visibility.*`)
- ✅ Default theme (`features.theme.default_theme`)
- ✅ Game depth / auto-shop правила (`economy`)
- ✅ Цены IAP-пакетов в чипах (`shop.packs[].chips`) — но не цены $
- ✅ Лобби-порядок (`lobby_order`)

**НЕ класть в Remote Config:**
- ❌ **Paytables** (`machines.machines.<id>.paytable`). Случайная правка
  в консоли = моментальное изменение выплат у живых игроков, потенциально
  миллион чипов уходят за 30 секунд. Paytables — статика, контролируемая
  через билд + ревью PR.
- ❌ **RTP, частоты wild-карт, deck size**. То же — это математика игры,
  которую нельзя править на лету без QA.
- ❌ **Стартовый баланс реальный** (`init_config.starting_balance`) можно
  менять, но осторожно: новые игроки получат другие стартовые суммы.
- ❌ **IAP product IDs** (`shop.packs[].product_id`). Должны точно
  совпадать с App Store Connect и Google Play. Случайная правка = битые
  покупки.
- ❌ **Локализационные строки** — для них есть `data/translations.json`,
  не Remote Config.

### Чек перед публикацией параметра

1. Этот параметр когда-нибудь нужно будет крутить дистанционно? Если нет
   — пусть остаётся только в локальном JSON.
2. Если в Firebase окажется кривое значение, можно ли об этом узнать
   из аналитики? Если нет — сначала добавь телеметрию, потом публикуй.
3. Пройдёт ли это значение QA так же тщательно, как код?

---

## 11. Edge cases / known limitations

### Race condition между fetch и потребителями

Между моментом запуска приложения и завершением fetch (100–300 мс или до
10 с при таймауте) другие autoload'ы и сцены могут уже прочитать
`ConfigManager.balance` / `.machines` и т.д. Они получат **локальные**
значения, а не remote-merged. После `_on_remote_fetch_completed`
ConfigManager обновит свои поля — но кешированные копии у потребителей
останутся старые до перезаупска экрана.

Сейчас потребители (lobby_manager, game_manager и т.д.) НЕ слушают
`fetch_completed` и НЕ переинициализируются. Это приемлемо для:
- параметров, читаемых при заходе в новый экран (paytable, balance) —
  они подхватятся при следующем visit'е
- параметров, читаемых лениво по событию (gift cooldown, BIG WIN
  thresholds) — они всегда читают текущее значение из ConfigManager

Это **не** приемлемо для:
- лобби-порядка (`lobby_order`) — лобби строится один раз при старте
- темы (`features.theme.default_theme`) — ThemeManager применяется
  на старте

Если нужен мгновенный пересчёт UI после fetch — потребитель должен
подписаться на `RemoteConfigManager.fetch_completed` и вызвать своё
обновление. Сейчас этого нет нигде.

### Удаление параметров

Через текущий deep-merge **невозможно** удалить поле из локалки. Если
локально есть `gift.notification.enabled = false`, и ты хочешь это поле
убрать через remote — не получится. Можно только перетереть значением
(`true`/`false`/`null`).

### Кэш Firebase

Firebase Remote Config держит ответ ~12 часов на сервере по `instance_id`.
Если поправил параметр и не видишь изменения — либо подожди, либо
сбрось save для появления нового `instance_id`. В продакшене у игроков
обновления естественно докатятся со следующим запуском после TTL.

### Web-платформа

Firebase Remote Config REST endpoint поддерживает CORS. Но при экспорте
в Web (HTML5) могут вылезти специфические ограничения браузера или
`HTTPRequest` через WebAssembly. Сейчас поведение НЕ протестировано на
Web — fallback на локалку отработает, оверрайды могут не доехать. Если
будешь экспортировать на Web — отдельный QA.

### Расход места в save

`app_instance_id` добавляет ~36 байт к save.json. Незначительно.

### Плагин Firebase SDK

Сейчас используется только REST API. Файлы `firebase/google-services.json`
и `firebase/GoogleService-Info.plist` лежат в проекте gitignored как
основа для будущей интеграции Firebase Analytics / Crashlytics / FCM
через нативные плагины. При интеграции потребуется их положить в
`/android/build/` (Android) и в Xcode-проект (iOS) при экспорте.

---

## 12. Файлы

| Путь | Назначение |
|---|---|
| `scripts/remote_config_manager.gd` | Autoload, REST fetch + парсинг + kill-switch |
| `scripts/config_manager.gd` | Автозагрузка локалки + handler `_on_remote_fetch_completed` + `_deep_merge` |
| `scripts/save_manager.gd` | Хранит `app_instance_id` |
| `firebase/google-services.json` | Android Firebase config (gitignored) |
| `firebase/GoogleService-Info.plist` | iOS Firebase config (gitignored) |
| `.firebase.env` | Сводка credentials (gitignored) |
| `export_presets.cfg` | Android: `permissions/internet=true` |

## 13. API в коде

### `RemoteConfigManager`

```gdscript
signal fetch_completed(success: bool)

# Главный публичный метод. Возвращает remote-Override если есть,
# иначе фолбэк через ConfigManager.get(name) (Object property by name).
func get_config(config_name: String) -> Dictionary

# То же, но БЕЗ фолбэка. Используется ConfigManager при re-apply,
# чтобы не сливать локалку саму с собой.
func get_remote(config_name: String) -> Dictionary

# True после того, как fetch завершился (успешно или нет).
func is_fetched() -> bool
```

### `ConfigManager`

```gdscript
const _REMOTE_OVERRIDABLE := [
    "animations", "balance", "economy", "features", "gift",
    "init_config", "lobby_order", "machines", "shop", "sounds",
    "vibration", "classic", "supercell",
]

# Вызывается RemoteConfigManager.fetch_completed.
func _on_remote_fetch_completed(success: bool) -> void

# Рекурсивный мердж. base не мутируется (deep-copy).
func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary
```

---

*Создан: 2026-04-30*
