# Проектный справочник Codex

Адаптирован из CLAUDE.md; исходник сохранён. Исторические числа состояния,
сторов, тестов и целевые деревья проверять по текущему коду и профильным docs.
Фактические точки входа и автозагрузки — в CODEX_ARCHITECTURE.md.

Правила исполнения имеют приоритет над историческими примерами ниже:
- Инструменты выбираются из текущей сессии: exec_command/rg для файлов, apply_patch для правок, view_image для PNG, web для web; не выдумывать tool IDs.
- Slash-сценарии вызываются как $имя или через /skills.
- Секреты читать только по необходимости в процессе без вывода значений; не выполнять cat .env или широкий grep секретов из старых рецептов.
- Делегирование — только авторизованные collaboration tools; при отсутствии инструментов последовательная работа. Роли передавать с текстом и границами, результат сохранять на диск.
- Claude settings, auth и bypassPermissions не дают разрешений Codex. Хуки только после /hooks; доверие не обходить.
- Поддерживать AGENTS.md и документы Codex; не менять Claude originals ради совместимости.

# Video Poker — Classic Edition

**Платформа:** Godot 4.6 (iOS/Android + Desktop) | **Жанр:** Social Casino (агрегатор игр)
**Архитектура:** платформа-агрегатор игровых модулей с единой метой — см. `docs/GAME_INTEGRATION.md`
**Стиль:** IGT Game King (Vegas classic) | **Монетизация:** виртуальная валюта, без реальных денег

**Первым делом прочитай `../GODOT_CONVENTIONS.md`** (лежит выше корня проекта, сам не подгружается) — общие конвенции Godot-флота (язык, стиль кода, git, mobile-секреты, сторы, саморефлексия).

---

## Документация по разделам

Подгружай эти файлы когда работаешь с соответствующими темами:

- **`docs/GAME_INTEGRATION.md`** — ОБЯЗАТЕЛЬНО прочитай при добавлении
  новой игры, правке GameRegistry / манифестов games/<id>/game.json /
  configs/games.json / контракта round_finished / сейв-отсеков.
  Новая игра добавляется ТОЛЬКО через слеш-команду `$add-new-game`.

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

- **`docs/IOS_UPLOAD.md`** — ОБЯЗАТЕЛЬНО прочитай при ЛЮБОЙ задаче
  «собери / архивируй / залей iOS-билд / upload в App Store Connect /
  TestFlight». Содержит: расположение creds (`.appstore.env`,
  `~/.appstoreconnect/private_keys/`), готовый пайплайн (bump build →
  archive → exportArchive → altool upload), шаблон
  `ExportOptions.plist`, ресайз иконок, troubleshooting типичных
  ошибок (409 duplicate version, signing fail, и т.д.). Все вопросы
  «где issuer ID / какой ключ / как подписывать» — ответы там.
  НЕ спрашивай пользователя — читай файл и делай.

- **`docs/RELEASE_GUIDE.md`** — единый справочник по релизам (iOS + Android +
  privacy policy hosting). Содержит: identity и аккаунты (Team ID, issuer ID,
  package name, service account email), карту секретов (где что лежит,
  что gitignored), pre-release checklist, backup-стратегию для keystore,
  историю предыдущих релизов с уроками, TODO. Подгрузи при ЛЮБОМ обсуждении
  релиза, перед сборкой/аплоадом, перед изменением version/code или
  CURRENT_PROJECT_VERSION. **Global Rating ID (IARC):**
  `997f76d6-e771-83f3-85a0-3f3d6b3e40fa` — вводить в других сторах
  вместо повторной анкеты возрастного рейтинга.

- **`docs/ANDROID_UPLOAD.md`** — ОБЯЗАТЕЛЬНО прочитай при ЛЮБОЙ задаче
  «собери / подпиши / залей Android-билд / upload в Google Play Console».
  Содержит: расположение creds (`.keystore.env`, `.googleplay.env`,
  `keystore/upload-keystore.jks`), готовый пайплайн (bump version/code →
  build_android_release.sh → upload_googleplay.sh через fastlane supply),
  setup service account для API, troubleshooting (Java SDK path в Godot,
  duplicate version code, потеря пароля keystore через Play App Signing
  reset). Все вопросы «где keystore / какой alias / какой package» —
  ответы там. НЕ спрашивай пользователя — читай файл и делай.

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

Полные paytable — [`docs/MACHINES_REFERENCE.md`](MACHINES_REFERENCE.md).

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
├── core/                            # МЕТА (autoload'ы + оболочка)
│   ├── main.gd, lobby_manager.gd, splash.gd, age_gate.gd
│   ├── config_manager.gd, save_manager.gd, game_registry.gd
│   ├── daily_quest_manager.gd, quest_matcher.gd, quest_*_overlay.gd
│   ├── shop_overlay.gd, iap_manager.gd, notification_manager.gd
│   ├── remote_config_manager.gd, translations.gd, theme_manager.gd
│   ├── sound_manager.gd, vibration_manager.gd, safe_area_manager.gd
│   ├── big_win_overlay.gd, top_bar_builder.gd
│   └── ui/credit_glyphs.gd
├── libs/
│   └── poker/                       # разделяемая покерная библиотека
│       ├── scripts/  (game*, multi_hand*, spin_poker*, deck,
│       │              hand_evaluator, card_*, paytable*, machine_card,
│       │              variant_factory, variants/, themes/supercell/)
│       └── scenes/   (game, multi_hand_game, spin_poker_game, card,
│                      mini_hand, paytable_display, machine_card, themes/)
├── games/                           # игровые модули = вкладки лобби
│   ├── vp_classic/  (game.json + machines_order.json)
│   ├── vp_3play/  vp_5play/  vp_10play/  vp_ultra/  vp_spin/
│   └── <новая игра>/ (game.json, scenes/, scripts/, assets/, configs/)
├── scenes/                          # оболочка: main.tscn, splash, lobby/
├── configs/                         # общие JSON + games.json (реестр)
├── data/                            # paytables.json, translations.json
├── assets/, shaders/, tests/, docs/
```

**Note:** структура «игра = модуль» описана в `docs/GAME_INTEGRATION.md`.


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
ключей — [`docs/CONFIG_REFERENCE.md`](CONFIG_REFERENCE.md).

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
(барабаны, шторки, strip, _rush) — [`docs/SPIN_POKER_IMPL.md`](SPIN_POKER_IMPL.md).

### BIG WIN overlay

Полноэкранная победная анимация. `BigWinOverlay` autoload вызывается из
всех 3 игровых экранов:
```gdscript
BigWinOverlay.show_if_qualifies(self, payout, total_bet)
```
Классификатор `ConfigManager.classify_big_win(payout, bet)` использует
`payout / total_bet`: `[4, 7]` → big, `≥ 8` → huge. Подключение,
ассеты, debug — [`docs/BIG_WIN.md`](BIG_WIN.md).

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

Порядок: **ConfigManager → SaveManager → GameRegistry → RemoteConfigManager** → остальные.
SaveManager стоит до RemoteConfigManager намеренно — RemoteConfigManager
читает/пишет `app_instance_id` через SaveManager.

| Autoload | Назначение |
|---|---|
| **ConfigManager** | Первый. `configs/*.json` → fallback defaults. После старта подписан на `RemoteConfigManager.fetch_completed` — на успехе делает deep-merge remote-оверрайдов поверх локалки в полях `_REMOTE_OVERRIDABLE`. |
| **SaveManager** | Файл `user://save.json`, `save_version: 2`. Глобально: `credits`, `xp`, `bet_level`, `denomination`, `language`, `theme_name`, `app_instance_id`, gift/pack-таймеры, `daily_quest_state`, `settings`. Per-модуль: отсеки `games.<game_id>.*` (`get_game_state` / `set_game_value` / `set_active_game`); плоские poker-поля (`last_variant`, `hand_count`, `ultra_vp`, `spin_poker`) — рабочая копия активного модуля. Миграция v1→v2 автоматическая с бэкапом `save.json.bak` (тест `tests/test_save_migration.gd`). Утилиты: `format_money`, `format_short`, `add_credits`, `deduct_credits`, `add_xp`. Валютные glyph-виджеты — делегаты в `core/ui/credit_glyphs.gd` (CreditGlyphs). |
| **GameRegistry** | После SaveManager. Реестр игровых модулей: читает `configs/games.json` + манифесты `games/<id>/game.json`, строит вкладки лобби, отдаёт entry-сцены/launch-параметры, подключает мету к играм через контракт-сигнал `round_finished` (`attach_meta`), начисляет XP. Kill-switch per-игра через remote-ключ `games`. |
| **DailyQuestManager** | После SaveManager. Владеет жизненным циклом ежедневных заданий: на старте сравнивает локальную дату с `daily_quest_state.date_iso`, при смене дня роллит `picks_per_day` (4 по умолчанию) случайных квестов из `configs/daily_quests.json`. `attach_to_round_source(source, game_id)` вызывается из `GameRegistry.attach_meta` после загрузки игровой сцены — подписка на контракт-сигнал `round_finished` любой игры. Математика типов условий — `core/quest_matcher.gd` (QuestMatcher). API: `get_active_quests()`, `time_to_reset_seconds()`, `claim_reward(id)`, `get_button_state(id)`, `get_navigation_target(id)`. Сигналы `quest_progress_updated/completed/claimed/quests_rolled`. Подробно — [`docs/CONFIG_REFERENCE.md`](CONFIG_REFERENCE.md) §12. |
| **SafeAreaManager** | Между SaveManager и RemoteConfigManager. Читает `DisplayServer.get_display_safe_area()`, конвертирует в координаты вьюпорта, эмитит `safe_area_changed`. `apply_offsets(control)` — навешивает inset на full-rect Control и пересчитывает на `size_changed` / `NOTIFICATION_APPLICATION_FOCUS_IN`. Используется из `main.gd._make_full_rect`. |
| **RemoteConfigManager** | Firebase Remote Config через REST. На старте делает один POST на endpoint, парсит entries, проверяет kill-switch `remote_config_enabled` (точное `"true"`), эмитит `fetch_completed(success)`. Платформенные ключи через `OS.get_name()` (iOS/Android/Web, остальное → iOS fallback). Подробно — [`docs/REMOTE_CONFIG.md`](REMOTE_CONFIG.md). |
| **NotificationManager** | После RemoteConfigManager. Обёртка над `godot-mobile-plugins/godot-notification-scheduler` (iOS+Android). На неподдерживаемых платформах (Desktop / Web) и при отсутствии плагина — все методы no-op'ят. Master-switch: `SaveManager.notifications_enabled` (UI-свич) И `ConfigManager.is_notifications_feature_enabled()` (kill-switch из `configs/notifications.json`, в `_REMOTE_OVERRIDABLE`). Hooks: `on_gift_claimed()` из `lobby_manager._claim_gift_reward`, `on_shop_pack_claimed(idx, sec)` из `shop_overlay`, `on_daily_quests_rolled()` из `DailyQuestManager._roll_new_quests`. Retention day-2/day-7 пинги планируются на `NOTIFICATION_APPLICATION_FOCUS_OUT`, отменяются на `FOCUS_IN`. Тексты — `notification.*` ключи в `data/translations.json`. Quiet hours 22:00–09:00 локального применяются ко всем уведомлениям (сдвиг вперёд). Подробно — [`docs/CONFIG_REFERENCE.md`](CONFIG_REFERENCE.md) §13. |
| **SoundManager** | Маппинг событий → файлов из `configs/sounds.json`. 22 placeholder MP3. |
| **Translations** | i18n EN/RU/ES. См. §8 ниже. |
| **VibrationManager** | Haptic для iOS/Android. Паттерны для deal/hold/win/jackpot. |
| **BigWinOverlay** | См. [`docs/BIG_WIN.md`](BIG_WIN.md). |

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

## 9. Правила для Codex (проектные, общие — в конвенциях)

- **Сборка / архивация / upload в App Store Connect — выполняй
  автономно по `docs/IOS_UPLOAD.md`.** НЕ спрашивай про issuer
  ID / API ключи / пути — всё лежит в `.appstore.env` (project root,
  gitignored) + `~/.appstoreconnect/private_keys/`. **Перед тем как
  спросить «где creds»** выполни в таком порядке:
  прочитать `docs/IOS_UPLOAD.md`, проверить наличие нужных файлов без вывода значений секретов. Если пользователь сказал
  «собери/залей/архивируй» — запускай весь пайплайн §2 из
  `docs/IOS_UPLOAD.md` без промежуточных подтверждений
  (bump build → archive → exportArchive → altool upload).
  **Bump `CURRENT_PROJECT_VERSION` всегда делай превентивно** —
  не дожидаясь 409 от ASC.
- **Новая игра — только через `$add-new-game`** (`.agents/skills/add-new-game/SKILL.md`): rip референс-APK → порт в `games/<id>/` по контракту `docs/GAME_INTEGRATION.md`. Ядро (`core/`) при добавлении игры не трогается.
- Использовать `load()` вместо `preload()` для сцен (circular dependencies).
- Корневые ноды сцен: `anchors_preset = 15` без `layout_mode`.
- Карты: `TextureRect` с `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`.
- **Никаких новых hardcode-параметров** — сначала смотри
  [`docs/CONFIG_REFERENCE.md`](CONFIG_REFERENCE.md). Прежде чем
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
  [`docs/REMOTE_CONFIG.md`](REMOTE_CONFIG.md).
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

---

*Создан: 2026-04-08 · Обновлён: 2026-05-05 · Версия: 3.2 (layout-rules)*

*Размер файла: ~19.7k символов (целевой бюджет: ≤ 35k). Если превышает —
вынести редкие разделы в `docs/` и обновить эту строку через `wc -m CLAUDE.md`.*
