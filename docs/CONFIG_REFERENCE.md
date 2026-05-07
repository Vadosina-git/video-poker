# Config Reference — Video Poker

Полный справочник по `configs/`. Все ключи в этом документе **подключены к
коду** — менять JSON и поведение игры синхронно. Advisory-ключи и
описательные `_RESERVED` пометки явно маркированы.

Загрузка через autoload **`ConfigManager`** (`scripts/config_manager.gd`).
ConfigManager стоит **первым** в autoload-порядке — все остальные autoload'ы
(SaveManager, SoundManager, ThemeManager) могут на него рассчитывать.

JSON не поддерживает комментарии; в каждом файле есть `_doc` (и вложенные
`_doc` в секциях) — игнорируется кодом.

> **Remote Config поверх локалки.** Любой из перечисленных файлов может
> быть перекрыт через Firebase Remote Config — deep-merge поверх
> локального JSON, контролируется kill-switch'ом `remote_config_enabled`.
> Архитектура, kill-switch, deep-merge, операционные сценарии и список
> overridable-конфигов — в [REMOTE_CONFIG.md](REMOTE_CONFIG.md).

---

## Файлы

| Файл | Назначение |
|---|---|
| `lobby_order.json`   | Порядок и видимость машин per-mode в лобби |
| `init_config.json`   | First-launch defaults (читаются `SaveManager._seed_first_launch_defaults`) |
| `balance.json`       | Per-mode денежные ладдеры + пороги BIG/HUGE WIN |
| `machines.json`      | Все 10 машин: paytable, deck size, ultra-multipliers |
| `shop.json`          | IAP-пакеты (FREE-tier по cooldown'ам) |
| `gift.json`          | Free-credits таймер + chip-cascade-анимация |
| `sounds.json`        | event → mp3 mapping |
| `animations.json`    | Тайминги (deal/draw/win/blink/spin) |
| `features.json`      | Feature flags + ui_visibility + theme default |
| `vibration.json`     | Длительности haptic + heavy events |
| `economy.json`       | Game depth, double-or-nothing rules (большая часть advisory под будущее) |
| `daily_quests.json`  | Пул ежедневных заданий + `picks_per_day` (читается `DailyQuestManager`) |
| `themes/<id>.json`   | Per-theme дизайн-токены (читаются ThemeManager) |

`ui_config.json` был удалён в этом аудите — все его ключи дублировали
ThemeManager или были мёртвыми.

---

## 1. `lobby_order.json`

Какие машины и в каком порядке доступны для каждого режима.

| Ключ | Что делает |
|---|---|
| `modes[].id` / `label_key`         | id режима + ключ перевода |
| `modes[].enabled`                  | Скрыть режим целиком |
| `modes[].machines[].id`            | id машины |
| `modes[].machines[].enabled`       | Скрыть машину в этом режиме |

> Для скрытия целой фича-группы используй `features.json` →
> `feature_flags.multi_hand_enabled` / `ultra_vp_enabled` /
> `spin_poker_enabled` (применяется поверх per-mode `enabled`).

---

## 2. `init_config.json`

First-launch defaults. Читаются `SaveManager._seed_first_launch_defaults()`
ровно один раз при отсутствии save-файла. После того как игрок что-то
изменил, его сохранённые значения побеждают.

| Ключ | Подключено в |
|---|---|
| `starting_balance`                | `SaveManager.credits` |
| `default_speed` (0..3)            | `SaveManager.speed_level` |
| `default_denomination_index`      | `SaveManager.denomination` (через `balance.modes.<m>.denominations[idx]`) |
| `default_mode`                    | `SaveManager.hand_count` + `ultra_vp` + `spin_poker` |
| `default_machine`                 | `SaveManager.last_variant` |
| `default_locale`                  | `SaveManager.language` (en/ru/es/system) |
| `default_theme`                   | `SaveManager.theme_name` (classic/supercell) |
| `show_speed_button`               | HUD кнопка SPEED в game/multi/spin/supercell |
| `show_double_button`              | HUD кнопка DOUBLE |
| `tutorial_enabled`                | ⚠ reserved (туториала нет) |
| `first_gift_delay_hours`          | сдвигает `last_gift_time` (gift готов через N часов после установки) |

---

## 3. `balance.json`

| Ключ | Что делает |
|---|---|
| `modes.<m>.denominations`             | Доступные номиналы (face value одной монеты) |
| `modes.<m>.default_denomination_index`| Индекс стартового номинала (через init_config) |
| `big_win_thresholds.big_win.min/max`  | Диапазон множителей `payout/total_bet` для BIG WIN |
| `big_win_thresholds.huge_win.min`     | Порог HUGE WIN |

> `max_bet` и `min_bet` — **структурные константы 1..5** (привязаны к
> 5-колонному paytable). Не tunable через config.

---

## 4. `machines.json`

| Ключ | Что делает |
|---|---|
| `machines.<id>.label_key`              | Translations key названия машины |
| `machines.<id>.deck_size`              | 52 / 53 (Joker) |
| `machines.<id>.hands[].id`             | Paytable key (одновременно `hand.<id>` translations key) |
| `machines.<id>.hands[].pays`           | 5-элементный массив выплат для bet 1..5 |
| `machines.<id>.ultra_multipliers`      | Per-rank Ultra VP множители (override стандартной таблицы) |

> `wild_cards`, `min_winning_hand`, `hands[].label_key`, `hands[].note`
> были удалены — wild-логика и min-hand живут в `scripts/variants/<id>.gd`.

---

## 5. `shop.json`

| Ключ | Что делает |
|---|---|
| `images_path`                  | Базовая папка картинок паков |
| `exchange_rate.coins_per_dollar` | Курс «100 coins = $1» в shop UI |
| `exchange_rate.show_label`     | Показать ли строку курса |
| `iap_items[].id`               | Уникальный ID пакета |
| `iap_items[].sort_order`       | Порядок (по возрастанию) |
| `iap_items[].cooldown_seconds` | Через сколько секунд пак снова доступен (FREE-режим) |
| `iap_items[].chips`            | Базовая выплата чипов |
| `iap_items[].bonus_chips`      | Бонус (отображается «+%» зелёным) |
| `iap_items[].color_scheme`     | `purple` / `blue` / etc. |
| `iap_items[].top_badge_key`    | Translations key бейджа (`shop.badge.quick_gift`) |
| `iap_items[].image`            | Имя файла под `images_path` |

> Chip glyph для shop'а приходит из `ThemeManager` (`assets.currency_chip`),
> не из этого файла.

---

## 6. `gift.json`

| Ключ | Что делает |
|---|---|
| `interval_hours`                  | Cooldown между gift'ами |
| `chips_amount`                    | Сколько кредитов выдаётся |
| `claim_animation.chip_count`      | Сколько чипов летит к balance pill |
| `claim_animation.stagger_step_sec`| Задержка между чипами |
| `claim_animation.travel_time_sec` | Время полёта одного чипа |
| `notification.title_key/body_key` | ⚠ reserved (нет push-системы) |

---

## 7. `sounds.json`

`event_name → mp3 file`. Code calls `SoundManager.play("<event>")`.

Подключенные events: `bet`, `hold`, `deal`, `flip`, `win`, `win_small`,
`win_big`, `win_royal`, `lose`, `gift_claim`, `spin_stop`.

⚠ Объявлены, но пока не вызываются: `win_jackpot`, `double_win`,
`double_lose`, `balance_increment`, `shop_purchase`, `spin_reel`,
`multiplier_activate`, `lobby_ambient`, `deal_button_blink`, `button_press`.

> До этого аудита большинство звуков **не играли** — ключи в JSON
> (`bet_change`, `card_deal` и т.д.) не совпадали с тем, что звал код
> (`bet`, `deal`). Теперь приведены в соответствие.

---

## 8. `animations.json`

Все ключи **подключены** (`ConfigManager.get_animation(key, default)`).

| Ключ | Что |
|---|---|
| `card_deal_delay_ms` (80)              | Inter-phase gap при DEAL |
| `card_draw_delay_ms` (80)              | Inter-phase gap при DRAW |
| `deal_button_idle_blink_sec` (5)       | Через сколько секунд бездействия мигает DEAL |
| `deal_button_blink_interval_ms` (600)  | Длительность одного цикла мигания |
| `win_counter_single_ms` (2000)         | Длительность win-counter в single + supercell |
| `win_counter_multi_ms` (1400)          | Длительность win-counter в multi + spin |
| `post_win_pause_sec` (0.5)             | Пауза после выигрыша до разблокировки кнопок (+ DnN reveal) |
| `bet_highlight_single_ms` (800)        | Длительность подсветки ставки (single) |
| `bet_highlight_multi_ms` (400)         | То же (multi) |
| `double_card_flip_ms` (150)            | Время flip'а карты в Double-or-Nothing |
| `spin_reel_speed_factor` (0.6)         | Множитель `cell_h` для пиковой скорости барабана |
| `spin_reel_deceleration_ms` (800)      | Длительность торможения |
| `spin_reel_bounce_px` (5)              | Bounce при остановке барабана |
| `spin_reel_column_delay_ms` (300)      | Задержка остановки между столбцами |
| `spin_filler_cards_count` (20)         | Количество филлеров в полосе барабана |

> Per-speed тайминги (DEAL/DRAW pacing, base spin duration, inertia)
> живут в `SPEED_CONFIGS` массивах в самих UI-скриптах — индексируются
> по `SaveManager.speed_level` (0..3) и не выносятся в конфиг.

---

## 9. `features.json`

Главный switch-board. API: `is_feature_enabled(key)`, `is_visible(key)`,
`get_default_theme()`.

### `feature_flags`

| Ключ | Что |
|---|---|
| `age_gate_enabled`               | First-launch модал «18+» |
| `big_win_overlay_enabled`        | BIG/HUGE WIN полноэкранная анимация |
| `double_or_nothing_enabled`      | DOUBLE-кнопка после выигрыша |
| `ultra_vp_enabled`               | Скрыть Ultra VP в lobby sidebar |
| `spin_poker_enabled`             | Скрыть Spin Poker |
| `multi_hand_enabled`             | Скрыть Triple/Five/Ten Play |
| `auto_shop_on_low_balance`       | Авто-открытие shop'а при недостатке кредитов |
| `deal_button_idle_blink`         | Мигание DEAL после бездействия |
| `lobby_store_indicator`          | Красная точка-нотификация на store-кнопке |
| `exit_confirm_dialog`            | Диалог «выйти из игры?» (false → выход без подтверждения) |
| `sound_fx_default`               | Стартовое значение `SaveManager.settings.sound_fx` |
| `vibration_default`              | То же для `vibration` |

### `ui_visibility`

| Ключ | Что |
|---|---|
| `show_lobby_settings_gear`       | Шестерёнка в top-bar лобби |
| `show_lobby_store_button`        | Store-кнопка в top-bar |
| `show_lobby_gift_button`         | Gift-кнопка в top-bar |
| `show_rtp_in_machine_info`       | RTP pill на карточке машины (только для classic темы) |

### `theme`

| Ключ | Что |
|---|---|
| `default_theme`  | Стартовая тема (`classic` / `supercell`). Mirror `init_config.default_theme` |

---

## 10. `vibration.json`

Все ключи подключены (`vibration_manager.gd`).

| Ключ | Что |
|---|---|
| `events.<name>`              | Длительность вибрации в мс. `0` = отключить событие |
| `heavy_events[]`             | Список «тяжёлых» событий — играется паттерн из импульсов |
| `heavy_pulse_count`          | Количество импульсов в heavy-паттерне |
| `heavy_inter_pulse_gap_ms`   | Пауза между импульсами |

> Глобальное отключение — `features.feature_flags.vibration_default = false`
> (применяется только для нового игрока) ИЛИ через тоггл в UI настроек
> (`SaveManager.settings.vibration`).

---

## 11. `economy.json` (большая часть advisory)

| Секция | Статус |
|---|---|
| `game_depth.min_rounds_to_play` | ✅ wired (заменяет хардкод `MIN_GAME_DEPTH=30`) |
| `game_depth.show_depth_hint` / `warn_below_rounds` | ⚠ advisory |
| `auto_shop.*` | ⚠ advisory (auto-shop сейчас триггерится сразу при `cost > balance`) |
| `double_or_nothing.enabled_in_*` | ✅ доступны через `ConfigManager.is_double_enabled_for(mode_id)`; per-mode логика подключения зависит от уже-подключённого `feature_flags.double_or_nothing_enabled` |
| `double_or_nothing.max_consecutive_doubles / dealer_card_count / player_pick_count / tie_returns_bet / show_warning_first_time` | ⚠ advisory (зашиты в DnN коде) |
| `starting_balance.first_launch_credits` | mirror `init_config.starting_balance` |
| `starting_balance.min_balance_floor / free_credits_when_broke` | ⚠ advisory |

> Эти параметры оставлены как **заглушки под будущие фичи** —
> подключим когда дойдут руки до экономического тюнинга.

---

## 12. `daily_quests.json`

Пул шаблонов ежедневных заданий. `DailyQuestManager` (autoload, после
SaveManager) при первом запуске сессии и при смене локальной даты делает
ролл `picks_per_day` случайных entries (по умолчанию 4) из `pool` с
`enabled=true`. Прогресс пишется в `SaveManager.daily_quest_state`,
переживает закрытие приложения. На полночь — сброс невыполненных
заданий, новые 4. Всё обнуляется при смене даты (анти-чит против
перевода часов отсутствует — повторяет поведение `gift.json`).

| Ключ | Назначение |
|---|---|
| `picks_per_day`           | Сколько заданий выдаётся на день (default 4) |
| `pool[].id`               | Стабильный id (используется в save) |
| `pool[].type`             | Один из 7 типов (см. ниже) |
| `pool[].target`           | Цель счётчика (или сумма монет для total_bet/accumulate_winnings) |
| `pool[].reward`           | Сколько монет начисляется при «Забрать» |
| `pool[].machines`         | Фильтр variant_id; пусто = любая машина |
| `pool[].modes`            | Фильтр lobby mode; пусто = любой режим |
| `pool[].hand_rank`        | Только для `collect_combo` / `score_specific_hand` (имя enum'а) |
| `pool[].enabled`          | `false` исключает из ролла, не теряя историю |

### Типы заданий

| `type` | Что считается |
|---|---|
| `play_hands`              | +1 за каждую сыгранную раздачу (multi/spin: +N за N рук в раунде) |
| `win_hands`               | +1 за каждую руку с payout > 0 |
| `collect_combo`           | +1 за каждую руку, чей `hand_rank` совпадает с `hand_rank` задания |
| `accumulate_winnings`     | +payout за каждую выигрышную руку (в монетах) |
| `score_specific_hand`     | Бинарное завершение: 0→target за первое попадание |
| `total_bet`               | +bet*denom*hand_count за раунд (монеты) |
| `play_different_machines` | +1 за каждую новую (за день) variant_id |

### Remote Config

Конфиг включён в `_REMOTE_OVERRIDABLE` — Firebase может присылать новый
`pool` целиком или править отдельные entries. Не клади в Remote Config
секреты экономики — это публичный JSON (см. `docs/REMOTE_CONFIG.md`).

---

## 13. `themes/<id>.json`

Per-theme дизайн-токены. Все ключи читаются `ThemeManager`.

| Секция | Что |
|---|---|
| `id` / `display_name` / `version` | Мета |
| `colors.*`                       | ~40 named-color tokens |
| `sizes.*`                        | border_width, corner_radius, button_corner_radius, popup_*, … |
| `assets.font`                    | `.ttf` шрифт |
| `assets.card_path` / `spin_card_path` | Папки PNG-карт |
| `assets.currency_chip`           | Chip glyph (через `SaveManager.set_chip_texture`) |
| `assets.multiplier_glyph_path`   | Override папки Ultra VP-глифов |
| `pattern.*`                      | Диагональный stripe-overlay |
| `tiles.display`                  | `"icon"` или `"text"` |
| `tiles.min_size`                 | `[w, h]` карточки машины |
| `background_gradient`            | Радиальный/линейный градиент фона |
| `background_overlay_gradient`    | Доп. градиент сверху |
| `machine_gradients.<id>`         | Per-machine `[top, bot]` цвета |
| `machine_titles.<id>`            | Override названия |
| `machine_labels.<id>`            | Короткая подпись |
| `machine_rtp.<id>`               | RTP% для карточки/info |
| `machine_outlines.<id>`          | Per-machine border |

> **Convention-based ассеты** в `assets/themes/<id>/{backgrounds, modes,
> machines, icons, big_win, glyphs_multipliers}/` — подхватываются
> автоматически без декларации в JSON.

---

## API ConfigManager — шпаргалка

```gdscript
# JSON dictionaries (raw)
ConfigManager.lobby_order / init_config / balance / machines /
ConfigManager.shop / gift / sounds / animations /
ConfigManager.features / vibration / economy

# Высокоуровневые accessor'ы:
ConfigManager.get_starting_balance() -> int
ConfigManager.get_machine(id) -> Dictionary
ConfigManager.get_mode_balance(mode_id) -> Dictionary
ConfigManager.get_denominations(mode_id) -> Array
ConfigManager.get_lobby_modes() -> Array
ConfigManager.get_shop_items() -> Array

ConfigManager.get_big_win_thresholds() -> Dictionary
ConfigManager.classify_big_win(payout, bet) -> "big" | "huge" | "none"

ConfigManager.get_gift_interval_hours() -> int
ConfigManager.get_gift_chips() -> int
ConfigManager.get_claim_animation() -> Dictionary  # chip_count + stagger + travel

ConfigManager.get_animation(key, default) -> float
ConfigManager.get_sound_file(event_name) -> String

# Features
ConfigManager.is_feature_enabled(key, default=true) -> bool
ConfigManager.is_visible(key, default=true) -> bool
ConfigManager.get_default_theme() -> String

# Vibration
ConfigManager.get_vibration_duration_ms(event) -> int
ConfigManager.is_heavy_vibration_event(event) -> bool
ConfigManager.get_vibration_heavy_pulse_count() -> int
ConfigManager.get_vibration_heavy_gap_ms() -> int

# Economy
ConfigManager.get_min_game_depth() -> int
ConfigManager.is_auto_shop_enabled() -> bool
ConfigManager.is_double_enabled_for(mode_id) -> bool

# Init defaults
ConfigManager.get_default_locale() / get_default_speed() /
ConfigManager.get_default_mode() / get_default_machine() /
ConfigManager.get_default_denomination_index(mode_id)
```

---

## Выгоды текущей конфиг-архитектуры

1. **Видимость фич за один флаг** — `features.json` управляет всем что
   игрок видит (режимы, кнопки top-bar'а, индикаторы, диалоги).
2. **Тайминги анимаций** — крутятся в `animations.json` без правки кода.
3. **Темы (skins)** — полностью отделены, переключаются через
   `theme.default_theme` или runtime `ThemeManager.set_theme()`.
4. **Экономика** — paytables, payouts, Ultra VP множители — всё в JSON.
5. **First-launch defaults** — `init_config.json` определяет что
   видит свежеустановленный игрок (баланс, режим, машина, локаль, тема).
6. **Haptic + sound** — externalized, любое событие можно отключить
   выставив `0` или удалив ключ.

---

## Известные advisory-ключи (под будущие фичи)

- `init_config.tutorial_enabled` — нет туториала
- `gift.notification.*` — нет push-уведомлений
- `economy.game_depth.show_depth_hint` / `warn_below_rounds`
- `economy.auto_shop.open_after_failed_bet_attempts` /
  `show_low_balance_toast` / `low_balance_toast_threshold_credits`
- `economy.double_or_nothing.max_consecutive_doubles` / `dealer_card_count`
  / `player_pick_count` / `tie_returns_bet` / `show_warning_first_time`
- `economy.starting_balance.min_balance_floor` / `free_credits_when_broke`
- `sounds.events.*` (10 объявленных, но не вызываемых событий)

Эти ключи документированы для будущей реализации — менять их сейчас не
влияет на поведение.
