# Video Poker — Classic Edition

**Платформа:** Godot 4.6 (iOS/Android + Desktop) | **Жанр:** Social Casino Video Poker
**Стиль:** IGT Game King (Vegas classic) | **Монетизация:** виртуальная валюта, без реальных денег

---

## Документация по разделам

Подгружай эти файлы когда работаешь с соответствующими темами:

- **`docs/MACHINES_REFERENCE.md`** — ОБЯЗАТЕЛЬНО прочитай при ЛЮБОЙ
  работе с paytable, выплатами конкретной машины, RTP, variance.
  Сводная таблица в §2 не содержит чисел выплат — числа берутся
  только из этого файла. Не отвечай по памяти.

- **`docs/CONFIG_REFERENCE.md`** — ОБЯЗАТЕЛЬНО прочитай при работе
  с любыми JSON в configs/, при добавлении нового ключа конфига,
  при использовании ConfigManager API. Согласно §9, configs/ —
  единственный источник правды для тюнинга.

- **`docs/REMOTE_CONFIG.md`** — ОБЯЗАТЕЛЬНО прочитай при работе с
  Firebase Remote Config: kill-switch, deep-merge, app_instance_id,
  `RemoteConfigManager`, любые правки `_REMOTE_OVERRIDABLE` или
  параметров в Firebase Console. Локалка из `configs/` остаётся
  фундаментом, remote — заплатки поверх.

- **`docs/UI_LAYOUTS.md`** — подгрузи при правке экранов лобби
  или игры, при работе с FSM состояний, шрифтами, типографикой.

- **`docs/MATH_AUDIO.md`** — подгрузи при работе с эвалюатором
  комбинаций, колодой, Fisher-Yates тасовкой, частотами выпадения,
  звуковыми эффектами, анимациями выигрышей.

- **`docs/SPIN_POKER_IMPL.md`** — подгрузи ТОЛЬКО при работе со
  Spin Poker (барабаны, шторки, strip, _rush). НЕ нужен для
  остальных 9 вариантов.

- **`docs/BIG_WIN.md`** — подгрузи только при работе с BIG WIN /
  HUGE WIN overlay (анимация, звук, классификация, debug).

- **`docs/RELEASE.md`** — подгрузи только при подготовке к релизу
  (Store metadata, ASC, Google Play, IAP).

- **`docs/ROADMAP.md`** — подгрузи при обсуждении приоритетов,
  будущих фич, плана работ по фазам.

- **`docs/SAFE_AREA.md`** — ОБЯЗАТЕЛЬНО прочитай при работе с любой
  новой сценой / popup / overlay, при правке `safe_area_manager.gd`,
  `main.gd._make_full_rect`, секции `window/stretch/*` в `project.godot`,
  а также при жалобах от QA «полосы по краям», «затемнение не покрывает
  экран», «контент уходит под notch», «вырез накрывает кнопку».
  Содержит правила full-bleed/inset, симметричный inset для anchor=1,
  меху `safe_area_axes`, разницу letterbox vs notch.

- **`docs/PAIN_LOG.md`** — прочитай в начале сложной задачи, если её
  тема похожа на одну из ранее зафиксированных. Не повторяй ошибки,
  описанные здесь.

- **`docs/DAILY_QUESTS.md`** — подгрузи при работе с ежедневными
  заданиями: добавление нового квеста, правка пула, изменение UI
  попапа/баннера, GO/CLAIM флоу, фильтры по машине/режиму, signals
  DailyQuestManager. Содержит карту трёх autoload'ов (DailyQuestManager
  / QuestBannerOverlay / QuestPopupOverlay) и описание всех 7 типов
  условий. Бизнес-логика квестов; общие UI-трюки (draw-order, cross-
  CanvasLayer cascade) — в `docs/PAIN_LOG.md`.

- **`docs/GLOSSARY.md`** — подгрузи если встретил незнакомый
  термин или нужна ссылка на внешний ресурс.

---

## 1. Игровой процесс

```
[Bet] → [DEAL] → 5 карт → [HOLD] → [DRAW] → замена → evaluate → payout/loss → repeat
```

- 1–5 монет ставки (всегда выгоднее Max Bet — Royal Flush 800:1 vs 250:1)
- Колода тасуется перед каждой раздачей (Fisher-Yates)
- Замены тянутся из той же колоды (позиции 6–10), без дубликатов
- При Royal Flush машина авто-фиксирует все карты

---

## 2. Сводная таблица 10 машин

| # | Машина | Колода | Wild | Мин. рука | RTP | Variance |
|---|---|---|---|---|---|---|
| 1 | Jacks or Better | 52 | — | JJ+ | 99.54% | Low |
| 2 | Bonus Poker | 52 | — | JJ+ | 99.17% | Low |
| 3 | Bonus Poker Deluxe | 52 | — | JJ+ | 99.64% | Medium |
| 4 | Double Bonus Poker | 52 | — | JJ+ | 100.17% | Medium-High |
| 5 | Double Double Bonus | 52 | — | JJ+ | 100.07% | High |
| 6 | Triple Double Bonus | 52 | — | JJ+ | 99.58% | Very High |
| 7 | Aces and Faces | 52 | — | JJ+ | 99.26% | Low-Medium |
| 8 | Deuces Wild | 52 | 4 (2s) | 3oaK | 99.73% | Low |
| 9 | Joker Poker | 53 | 1 (Joker) | KK+ | 100.65% | Low-Medium |
| 10 | Deuces and Joker Wild | 53 | 5 (2s+Joker) | 3oaK | 99.07% | Medium-High |

Полные paytable — [`docs/MACHINES_REFERENCE.md`](docs/MACHINES_REFERENCE.md).

---

## 3. Технические спецификации

- **Godot 4.6**, GDScript, Mobile renderer
- Базовое разрешение: 1080×1920 portrait (1920×1080 landscape alt)
- Stretch mode: `canvas_items`, aspect: `keep_height` (portrait)
- Поддержка Safe Area (iOS notch/Dynamic Island, Android cutout, home indicator) — autoload `SafeAreaManager` (`scripts/safe_area_manager.gd`); применяется к каждой игровой сцене из `main.gd._make_full_rect`
- Сборки: Android (APK/AAB), iOS, Windows, macOS, Linux

---

## 4. Структура проекта

```
res://
├── project.godot
├── scenes/
│   ├── main.tscn                    # точка входа, переключение lobby↔game
│   ├── lobby/{lobby,machine_card}.tscn
│   ├── game.tscn                    # single-hand
│   ├── multi_hand_game.tscn         # multi-hand + Ultra VP
│   ├── spin_poker_game.tscn         # 3×5 reel grid
│   ├── card.tscn, mini_hand.tscn, paytable_display.tscn
├── scripts/
│   ├── main.gd                      # загрузка сцен + создание variant
│   ├── game.gd / multi_hand_game.gd / spin_poker_game.gd   # UI слой
│   ├── game_manager.gd / multi_hand_manager.gd / spin_poker_manager.gd  # FSM
│   ├── lobby_manager.gd, machine_card.gd
│   ├── card_data.gd, card_visual.gd, mini_hand_display.gd
│   ├── deck.gd, hand_evaluator.gd, paytable.gd, paytable_display.gd
│   ├── multiplier_glyphs.gd         # SVG-глифы для Ultra VP
│   ├── config_manager.gd            # autoload (JSON configs)
│   ├── save_manager.gd              # autoload (credits, settings)
│   ├── sound_manager.gd             # autoload
│   ├── translations.gd              # autoload (i18n)
│   ├── vibration_manager.gd         # autoload (haptic)
│   ├── big_win_overlay.gd           # autoload (BIG WIN)
│   └── variants/
│       ├── base_variant.gd
│       └── {jacks_or_better, bonus_poker, bonus_poker_deluxe,
│            double_bonus, double_double_bonus, triple_double_bonus,
│            aces_and_faces, deuces_wild, joker_poker, deuces_and_joker}.gd
├── configs/                         # JSON, читается ConfigManager
│   ├── animations.json, balance.json, gift.json, init_config.json
│   ├── lobby_order.json, machines.json, shop.json, sounds.json
│   ├── ui_config.json, economy.json, features.json, vibration.json
│   ├── daily_quests.json
│   └── themes/
├── data/
│   ├── paytables.json               # все 10 таблиц выплат
│   └── translations.json            # i18n EN/RU/ES
├── assets/
│   ├── cards/                       # PNG: card_vp_{rank}{suit}.png
│   ├── cards/cards_spin/            # SVG для Spin Poker
│   ├── big_win/                     # title + glyphs для BIG WIN
│   ├── textures/, sounds/, icons/, fonts/
└── docs/                            # см. таблицу выше
```

**Note:** `data/config.json` — legacy, удалить (заменено `configs/*`).

---

## 5. Архитектурные паттерны

### Variant system

Каждый вариант — класс наследник `BaseVariant`. Обязательные override'ы:
- `evaluate(hand)` → `HandRank` — для wild-вариантов возвращает ближайший
  стандартный ранг и сохраняет `_last_hand_key`.
- `get_payout(rank, bet)` — для bonus/kicker-вариантов учитывает ранг
  четвёрки и кикера.
- `get_paytable_key(rank)` — возвращает строковый ключ из `paytables.json`
  (`"four_aces_with_234_kicker"` и т.п.). Нужен и для lookup payout, и для
  локализации (`hand.{key}`).
- `get_hand_name(rank)` — **НЕ override'ится**. Базовый класс резолвит через
  `Translations.tr_key("hand." + key)`.

### Config-driven

Все настройки — в `configs/*.json` (12 файлов). `ConfigManager` (autoload,
**первый** в порядке) загружает при старте. Полный справочник API и
ключей — [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md).

### Paytable-driven payouts

Все выплаты — в `data/paytables.json`. Variant'ы используют строковые
ключи, минуя ограничения `HandRank` enum'а. Локализация имён —
`Paytable.get_hand_display_name(key)`.

### Multi-hand

`MultiHandManager` создаёт N-1 дополнительных `Deck`. При draw каждая
extra рука получает те же held-карты, но уникальные replacements из
своей колоды. Флаг `ultra_vp` активирует per-hand множители.

### Ultra VP

При `bet == MAX_BET` активируется per-hand multiplier система: выигрышные
руки генерируют множитель для *следующего* раунда. `MultiHandManager`
держит два массива:
- `hand_multipliers[]` — применяется *сейчас*
- `next_multipliers[]` — переносится в `hand_multipliers[]` на следующий DEAL

UI: `multi_hand_game.gd` + `multiplier_glyphs.gd`. Два Control'а на руку
(`_next_displays[i]` сверху, `_active_displays[i]` снизу). При DEAL:
старый ACTIVE fade out + NEXT (header detach + value сдвиг вниз) + новый
ACTIVE pop-in.

Таблица множителей: JJ→2x, 2P→3x, 3oaK→4x, Straight→5x, Flush→6x, FH→8x,
4oaK→10x, SF/RF→12x. Невыигрышные руки сбрасываются на 1x.

### Spin Poker

Slot-style: 3 ряда × 5 колонок reel grid, 20 линий. `SpinPokerManager` +
`spin_poker_game.gd` + квадратные SVG. Полная техническая реализация
(барабаны, шторки, strip, _rush) — [`docs/SPIN_POKER_IMPL.md`](docs/SPIN_POKER_IMPL.md).

### BIG WIN overlay

Полноэкранная победная анимация. `BigWinOverlay` autoload вызывается из
всех 3 игровых экранов:
```gdscript
BigWinOverlay.show_if_qualifies(self, payout, total_bet)
```
Классификатор `ConfigManager.classify_big_win(payout, bet)` использует
`payout / total_bet`: `[4, 7]` → big, `≥ 8` → huge. Подключение,
ассеты, debug — [`docs/BIG_WIN.md`](docs/BIG_WIN.md).

### Scene structure (game screen)

```
TopSection (VBox, anchor top)        — title, paytable, balance/status
MiddleSection (dynamic anchors)      — карты (+ мини-руки multi-hand)
BottomSection (VBox, anchor bottom)  — total bet, кнопки, padding
```

### Card rendering

PNG `res://assets/cards/card_vp_{rank}{suit}.png`. Joker:
`card_vp_joker_red.png`. Spin Poker — квадратные SVG из
`assets/cards/cards_spin/`. Все `theme_override` — из GDScript, не из
`.tscn`.

---

## 6. Autoloads (порядок в `project.godot`)

Порядок: **ConfigManager → SaveManager → RemoteConfigManager** → остальные.
SaveManager стоит до RemoteConfigManager намеренно — RemoteConfigManager
читает/пишет `app_instance_id` через SaveManager.

| Autoload | Назначение |
|---|---|
| **ConfigManager** | Первый. `configs/*.json` → fallback defaults. После старта подписан на `RemoteConfigManager.fetch_completed` — на успехе делает deep-merge remote-оверрайдов поверх локалки в полях `_REMOTE_OVERRIDABLE`. |
| **SaveManager** | `credits`, `denomination`, `last_variant`, `hand_count`, `speed_level`, `bet_level`, `ultra_vp`, `spin_poker`, `language`, `app_instance_id` (стабильный Firebase client id), `daily_quest_state: Dictionary` (см. DailyQuestManager), `settings: Dictionary`. Файл `user://save.json`. Поле `ultra_vp` (ранее `ultimate_x`) — при загрузке принимает оба ключа. Утилиты: `format_money`, `format_short`, `add_credits`, `deduct_credits`. |
| **DailyQuestManager** | После SaveManager. Владеет жизненным циклом ежедневных заданий: на старте сравнивает локальную дату с `daily_quest_state.date_iso`, при смене дня роллит `picks_per_day` (4 по умолчанию) случайных квестов из `configs/daily_quests.json`. `attach_to_game(scene, variant_id, mode)` вызывается из `main.gd` после загрузки игровой сцены — подключается к сигналу game-менеджера и трекает прогресс. API: `get_active_quests()`, `time_to_reset_seconds()`, `claim_reward(id)`, `get_button_state(id)`, `get_navigation_target(id)`. Сигналы `quest_progress_updated/completed/claimed/quests_rolled`. Подробно — [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md) §12. |
| **SafeAreaManager** | Между SaveManager и RemoteConfigManager. Читает `DisplayServer.get_display_safe_area()`, конвертирует в координаты вьюпорта, эмитит `safe_area_changed`. `apply_offsets(control)` — навешивает inset на full-rect Control и пересчитывает на `size_changed` / `NOTIFICATION_APPLICATION_FOCUS_IN`. Используется из `main.gd._make_full_rect`. |
| **RemoteConfigManager** | Firebase Remote Config через REST. На старте делает один POST на endpoint, парсит entries, проверяет kill-switch `remote_config_enabled` (точное `"true"`), эмитит `fetch_completed(success)`. Платформенные ключи через `OS.get_name()` (iOS/Android/Web, остальное → iOS fallback). Подробно — [`docs/REMOTE_CONFIG.md`](docs/REMOTE_CONFIG.md). |
| **NotificationManager** | После RemoteConfigManager. Обёртка над `godot-mobile-plugins/godot-notification-scheduler` (iOS+Android). На неподдерживаемых платформах (Desktop / Web) и при отсутствии плагина — все методы no-op'ят. Master-switch: `SaveManager.notifications_enabled` (UI-свич) И `ConfigManager.is_notifications_feature_enabled()` (kill-switch из `configs/notifications.json`, в `_REMOTE_OVERRIDABLE`). Hooks: `on_gift_claimed()` из `lobby_manager._claim_gift_reward`, `on_shop_pack_claimed(idx, sec)` из `shop_overlay`, `on_daily_quests_rolled()` из `DailyQuestManager._roll_new_quests`. Retention day-2/day-7 пинги планируются на `NOTIFICATION_APPLICATION_FOCUS_OUT`, отменяются на `FOCUS_IN`. Тексты — `notification.*` ключи в `data/translations.json`. Quiet hours 22:00–09:00 локального применяются ко всем уведомлениям (сдвиг вперёд). Подробно — [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md) §13. |
| **SoundManager** | Маппинг событий → файлов из `configs/sounds.json`. 22 placeholder MP3. |
| **Translations** | i18n EN/RU/ES. См. §8 ниже. |
| **VibrationManager** | Haptic для iOS/Android. Паттерны для deal/hold/win/jackpot. |
| **BigWinOverlay** | См. [`docs/BIG_WIN.md`](docs/BIG_WIN.md). |

---

## 7. Как добавить новый вариант покера

1. `scripts/variants/new_variant.gd` — `class_name NewVariant extends BaseVariant`.
2. Реализовать `evaluate()`, `get_paytable_key()`, опционально `get_payout()`.
   **НЕ** переопределять `get_hand_name()`.
3. Добавить paytable в `data/paytables.json`.
4. Добавить `match` ветку в `main.gd → _create_variant()`.
5. Добавить конфиг машины в `configs/machines.json` + порядок в `configs/lobby_order.json`.
6. **Локализация:** добавить во все три языка `data/translations.json`
   ключи `machine.{id}.name` (всегда английское), `machine.{id}.mini`,
   `machine.{id}.feature`. Если новые имена рук — `hand.{key}`.
7. **Валидация математики:** прогнать через тесты RTP (если есть
   test runner в `tests/`) или валидировать paytable вручную
   против эталонного источника (Wizard of Odds, vpFREE2).
   Не считать вариант готовым, пока RTP не сходится.

---

## 8. Локализация (i18n)

Поддерживаемые языки: **`en`**, **`ru`**, **`es`**. Никакого хардкода
пользовательского текста — всё через `Translations.tr_key()`.

### Архитектура

- `data/translations.json` — `{ version: 1, languages: { en/ru/es: { key: str } } }`. Ключи плоские, через точку: `модуль.назначение[.подтип]`.
- `scripts/translations.gd` (autoload `Translations`) — парсит JSON один раз. Детектит OS-локаль через `OS.get_locale_language()` если `SaveManager.language == "system"`, иначе использует сохранённый выбор. Фолбэк: язык → `en` → сам ключ.
- `SaveManager.language: String` — `"system"` | `"en"` | `"ru"` | `"es"`.
- Шестерёнка ⚙ в лобби → settings popup → LANGUAGE sub-popup → `Translations.set_language(code)` + `reload_current_scene()`.

### API

```gdscript
label.text = Translations.tr_key("game.place_your_bet")
label.text = Translations.tr_key("game.bet_one_fmt", [bet])           # %s/%d
msg.text   = Translations.tr_key("double.msg_fmt",
    [SaveManager.format_money(amount), SaveManager.format_money(doubled)])

# Имена рук — всегда через Paytable
var name := paytable.get_hand_display_name(key)   # → tr_key("hand." + key)

# Машины
Translations.tr_key("machine.%s.name" % variant_id)
Translations.tr_key("machine.%s.mini" % variant_id)
Translations.tr_key("machine.%s.feature" % variant_id)
```

### Пространства имён ключей

| Префикс | Использование |
|---|---|
| `common.*` | YES/NO/GOT IT/FREE/X/OK |
| `lobby.*` | Кнопки режимов, top-bar, cash |
| `settings.*` | Popup настроек, выбор языка |
| `game.*` | Игровое поле: deal/draw/double/bet_one_fmt/total_bet/balance/win_label/no_win/place_your_bet/held/winnings/try_again |
| `game_depth.*` | Тултип Game Depth |
| `bet_select.*` | Popup выбора номинала |
| `shop.*` | Shop popup |
| `info.*` | Info-popup: правила, таблицы множителей и машин |
| `info_card.*` | Боковая Ultra VP info-карточка |
| `double.*` | Double-or-Nothing popup |
| `hand.*` | **Все** имена комбинаций. Ключ = ключ из `paytables.json` |
| `machine.{id}.*` | Per-variant: `name`/`mini`/`feature` |

**Важно:** `machine.*.name` — английские во всех трёх языках (бренды).
`ULTRA VP` — тоже английское.

### Что резолвится автоматически

- Имена рук в результатах/бейджах — через `BaseVariant.get_hand_name()` → `Paytable.get_hand_display_name(key)` → `tr_key("hand." + key)`.
- Paytable-бейджи в `_build_paytable_badges` — через `_variant.paytable.get_hand_display_name(key)`.

### Чеклист добавления текста

1. Ключ `модуль.назначение` (или `..._fmt` если с `%s`/`%d`).
2. Добавить во **все три** блока `languages.en/ru/es`.
3. В коде: `Translations.tr_key("ключ", [args])`.
4. В `.tscn` оставлять пустым — финальное значение в `_ready()`.
5. Новая рука → `hand.{paytable_key}` во все языки. Новая машина → `machine.{id}.name/mini/feature`.

### Bulk-добавление (3+ ключей × 3 языка)

Серия `Edit` по `data/translations.json` хрупкая: Read tool показывает
`\t\t\t<text>` где первый таб — line-prefix, а реальная индентация на
один таб меньше; легко получить «String not found» и потерять время.
Для пакетного добавления использовать Python:

```python
import json
path = 'data/translations.json'
d = json.load(open(path))
new_keys = {
    "en": {"tutor.slide1_l1": "Welcome!", ...},
    "ru": {"tutor.slide1_l1": "Привет!", ...},
    "es": {"tutor.slide1_l1": "¡Bienvenido!", ...},
}
for lang, kv in new_keys.items():
    for k, v in kv.items():
        d['languages'][lang][k] = v
json.dump(d, open(path,'w'), indent='\t', ensure_ascii=False)
print({k: len(v) for k, v in d['languages'].items()})
```

Бонусы: автоматическая валидация JSON-синтаксиса, единая индентация,
немедленная проверка parity через распечатку длин словарей.

### Валидация

```bash
python3 -c "import json; d=json.load(open('data/translations.json')); print({k: len(v) for k,v in d['languages'].items()})"
```
Должно вернуть одинаковое число для en/ru/es.

Если в интерфейсе виден сам ключ (`game.place_your_bet`) — двухуровневый
фолбэк не сработал, ключ отсутствует и в `en`.

---

## 9. Правила для Claude Code

- **Всегда отвечать на русском языке.**
- **Не коммитить без явного одобрения пользователя.**
- **Сборка / архивация / upload в App Store Connect — выполняй
  автономно, не задавая уточняющих вопросов.** Запускай
  `xcodebuild archive` / `xcrun altool` / `notarytool` / Godot
  export командами сам, разбирайся с подписями и сертификатами по
  ходу. Прерывайся только если действительно нет credentials в
  системе и их невозможно достать (`security find-identity`,
  keychain, env vars). Промежуточные «можно я запущу archive?» —
  не нужны: если пользователь сказал собрать/залить, он уже
  одобрил всю цепочку команд.
- Все стили — в GDScript, не в `.tscn` (Godot 4.6 парсер отвергает `theme_override_`).
- Использовать `load()` вместо `preload()` для сцен (circular dependencies).
- Корневые ноды сцен: `anchors_preset = 15` без `layout_mode`.
- Карты: `TextureRect` с `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`.
- **Никаких новых hardcode-параметров** — сначала смотри
  [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md). Прежде чем
  зашить число/флаг/строку в `*.gd`, проверь, есть ли ключ в
  `configs/*.json`. Если нет — добавь ключ + accessor в `ConfigManager`.
  `configs/` — единственный источник правды для тюнинга.
- **Remote Config — поверх локалки.** При старте сессии
  `RemoteConfigManager` (REST к Firebase, autoload #3) делает deep-merge
  remote-оверрайдов поверх 13 имён из `ConfigManager._REMOTE_OVERRIDABLE`.
  Kill-switch `remote_config_enabled` (`Boolean=true` в Firebase
  Console) — opt-in: при отсутствии или `false` оверрайды игнорируются.
  При добавлении нового конфигурируемого поля — сначала в локальный JSON
  + accessor в ConfigManager, потом (опционально) публикация в Firebase.
  **Не клади в Remote Config paytables / RTP / IAP product_id** —
  только косметику, балансы экономики и feature flags. Подробно —
  [`docs/REMOTE_CONFIG.md`](docs/REMOTE_CONFIG.md).
- **Никаких хардкодов пользовательского текста** — только
  `Translations.tr_key()`. Перед добавлением любой надписи (`Label.text`,
  `Button.text`, заголовки popup'ов, статусы, win-бейджи, info-popup,
  имена новых рук/машин) сначала добавь ключ в `data/translations.json`
  во все три языка. Имена рук — всегда через
  `Paytable.get_hand_display_name(key)`. Текст в `.tscn` оставляй пустым.
- **Цветные эмодзи в UI — через SVG-ассет, не через шрифт.** Эмодзи
  (👑🔥🃏 и т. п.) рендерятся через системный fallback font. iOS/Android
  работают, HTML5 web-export — НЕТ (Godot не бандлит emoji-font в
  web build). Если эмодзи нужен в UI — клади SVG (Twemoji CC-BY 4.0
  ок: `cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/<codepoint>.svg`)
  в `assets/themes/<id>/icons/` и рендерь через `TextureRect`.
  Текстовая Label-эмодзи допустима только как fallback при отсутствии
  файла. Пример: `machine_card.gd._make_emoji_node()`.
- **OS permission'ы — всегда через двух-шаговый prompt.** Любая
  системная разрешалка (notifications, ATT/IDFA, location, camera,
  contacts) — сначала наш in-house pre-prompt с описанием выгоды
  и кнопками ALLOW/NOT NOW; только при ALLOW → системный prompt.
  Холодный системный диалог на старте даёт 60-70% автоотказов
  и сжигает one-shot OS dialog. Apple HIG и Google guidance оба
  это рекомендуют. Реализованный пример:
  `lobby_manager.gd._show_notifications_pre_prompt`.
- **Магические числа в layout-коде запрещены без объяснения.** Любой
  hardcoded литерал > 20 в позиционировании / margin / padding / offset
  должен либо иметь комментарий с обоснованием и тюнинг-контекстом
  (что подбиралось, под какой viewport, почему именно столько), либо
  быть вынесен в `configs/*.json` через ConfigManager. Без этого числа
  превращаются в мины замедленного действия — нашли `var side_m := 160`
  в `game.gd`, который ел 22% ширины экрана, и никто не помнил откуда.
- **При cross-cutting layout-фиксе** — после исправления класса бага
  в одной из 6 игровых сцен (Classic/Supercell × single/multi/spin),
  пройдись грепом по остальным на тот же паттерн. Магические числа,
  status-label-pushing-layout, race conditions между deferred-корутинами
  — всё это с большой вероятностью существует и в других сценах.
  Примеры аудитов есть в `docs/PAIN_LOG.md`.
- **При признаках застоя** — если ты сделал три итерации по одной
  задаче и проблема не решена, ОСТАНОВИСЬ и сообщи мне коротко:
  «Ой, кажется я запутался. Может проведём саморефлексию?».
  НЕ выполняй `/stop-analyze` самостоятельно. Дождись моего ответа:
  - Если я отвечу «да» (или «давай», «проведи») — выполни команду
    `/stop-analyze`.
  - Если я отвечу «нет» (или «продолжай», «всё нормально») —
    продолжай работу над задачей в обычном режиме.
  - Не считай новые попытки как новый «счётчик трёх итераций» —
    после моего «нет» ты можешь делать ещё попытки, и при следующем
    застое снова сообщить.
- **При обнаружении пробела в документации** — если ты пришёл к
  решению ТОЛЬКО ПОСЛЕ нескольких неудачных попыток (3+), и причина
  была в отсутствии нужной информации в проекте, после успешного
  решения сообщи коротко:
  «Заметил пробел в документации: [тема в одну фразу]. Зафиксируем
  урок?». НЕ выполняй `/lesson-log` самостоятельно. Дождись моего
  ответа:
  - Если я отвечу «да» — выполни команду `/lesson-log`.
  - Если я отвечу «нет» (или промолчу о фиксации) — продолжай
    работу, не возвращайся к этому вопросу в текущей сессии.

---

*Создан: 2026-04-08 · Обновлён: 2026-05-05 · Версия: 3.2 (layout-rules)*

*Размер файла: ~19.7k символов (целевой бюджет: ≤ 35k). Если превышает —
вынести редкие разделы в `docs/` и обновить эту строку через `wc -m CLAUDE.md`.*
