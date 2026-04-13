# Video Poker — Classic Edition
## Список доработок (improvements.md)
## Версия: 1.1 | Дата: 2026-04-13

---

# 0. СОСТОЯНИЕ ПРОЕКТА И РАСХОЖДЕНИЯ С CLAUDE.md

Перед выполнением задач — учитывать актуальное состояние проекта из CLAUDE.md v2.0 (2026-04-10).

### Что уже реализовано (не нужно делать заново):
- ✅ Все 10 машин (variants) + BaseVariant система
- ✅ Лобби (Game King style): sidebar 6 режимов + grid 5×2 машин + drag-scroll
- ✅ Multi-hand (3/5/10/12/25 рук)
- ✅ Ultimate X (per-hand множители)
- ✅ Spin Poker (3×5 reel grid)
- ✅ Double or Nothing
- ✅ Магазин (stub с FREE покупками)
- ✅ Локализация EN / RU / ES (autoload Translations + `data/translations.json`)
- ✅ SaveManager autoload
- ✅ SoundManager autoload (stub)

### Расхождения improvements.md ↔ CLAUDE.md — решения:

| # | Тема | CLAUDE.md (текущее) | improvements.md (предложено) | Решение |
|---|---|---|---|---|
| 1 | **Godot версия** | 4.6 | — | Использовать **4.6**. Не упоминать 4.3 |
| 2 | **Renderer** | Mobile | — | Использовать **Mobile** renderer |
| 3 | **Стартовый баланс** | 1000 (§12) | 20000 (init_config.json) | **20000** — по запросу. §12 CLAUDE.md устарел |
| 4 | **Denominations** | [1, 5, 25, 100, 500] (§6.4) | [1, 2, 5, 10, 25, 50, 100] (balance.json) | **[1, 2, 5, 10, 25, 50, 100]** — новая сетка из balance.json |
| 5 | **Файл локализации** | `data/translations.json` (единый, 3 языка) | `configs/localization/en.json` + `ru.json` (раздельно) | **Сохранить единый файл** `data/translations.json` (3 языка в одном, как сейчас). Не разбивать — CLAUDE.md §20 описывает рабочую систему. Перенос в `configs/` — опционально, отдельной задачей |
| 6 | **Языки** | EN / RU / ES (3 языка) | EN / RU (2 языка в примерах) | **Сохранить 3 языка** (EN / RU / ES). Все новые ключи добавлять во все 3 |
| 7 | **Paytable** | `data/paytables.json` | `configs/machines.json` | **Миграция**: данные из `data/paytables.json` переносятся в `configs/machines.json`. Старый файл удаляется. Paytable.gd переписать на чтение из нового пути |
| 8 | **Config** | `data/config.json` | `configs/init_config.json` + др. | **Миграция**: `data/config.json` разбивается на несколько конфигов в `configs/`. Создать ConfigManager autoload |
| 9 | **Ultimate X** | Называется "Ultimate X" везде | Переименовать в "Ultra VP" (§I.1) | **Ultra VP** — новое название. Изменить: lobby_manager.gd (`PLAY_MODES`), SaveManager (`.ultimate_x` → `.ultra_vp`), translations.json, CLAUDE.md |
| 10 | **Sidebar режимы** | 6 штук: SINGLE / TRIPLE / FIVE / TEN / ULTIMATE X / SPIN POKER | lobby_order.json: 5 режимов (без TEN PLAY) | **Сохранить все 6 из CLAUDE.md** + добавить в lobby_order.json. TEN PLAY не удалять |
| 11 | **Режим SPIN POKER** | Отдельный FSM `spin_poker_manager.gd` + `spin_poker_game.tscn` | improvements.md описывает правки | Режим существует, задачи §J — это **правки**, не создание с нуля |
| 12 | **Хардкод текстов** | §20.1: "Никакого хардкода" + §19 Spin Poker: "Хардкод-строки пока присутствуют" | E.3: полный аудит хардкода | Spin Poker — основной кандидат на аудит. Остальные режимы уже локализованы через tr_key |

### Файлы, которые будут мигрированы:

```
ТЕКУЩЕЕ                          →  НОВОЕ
data/config.json                 →  configs/init_config.json (+ разбивка на balance.json, etc.)
data/paytables.json              →  configs/machines.json (расширенный формат)
data/translations.json           →  data/translations.json (БЕЗ ИЗМЕНЕНИЯ пути, по §20)
                                    (новые ключи добавляются в этот же файл)
(не существует)                  →  configs/lobby_order.json (новый)
(не существует)                  →  configs/balance.json (новый)
(не существует)                  →  configs/shop.json (новый)
(не существует)                  →  configs/gift.json (новый)
(не существует)                  →  configs/sounds.json (новый)
(не существует)                  →  configs/animations.json (новый)
(не существует)                  →  configs/ui_config.json (новый)
```

### Autoloads после изменений:

| Autoload | Файл | Статус |
|---|---|---|
| SaveManager | `scripts/save_manager.gd` | ✅ Существует, расширить (gift timer, ultra_vp rename) |
| SoundManager | `scripts/sound_manager.gd` | ✅ Существует (stub), подключить к sounds.json |
| Translations | `scripts/translations.gd` | ✅ Существует, без изменений архитектуры |
| **ConfigManager** | `scripts/config_manager.gd` | 🆕 Новый autoload — загрузка всех configs/*.json |

### ⚠ Предупреждения для Claude Code

1. **Двойной roadmap в CLAUDE.md:** §6 показывает все фазы как ✅ done, а §16 — тот же roadmap со старыми `[ ]` чекбоксами. **§6 — актуален. §16 — устаревший дубль. Все фичи из Phase 1–5 + Ultimate X + Spin Poker + Double or Nothing + Локализация + Shop stub — уже реализованы.** Не создавать заново.

2. **Сломанная нумерация секций в CLAUDE.md:** §7 содержит подсекции "6.1"/"6.2", §8 содержит подсекции "9.1"/"9.2". Это косметический баг документа. При ссылках опираться на заголовки секций, а не на номера подсекций.

3. **Миграция paytables.json → machines.json:** подробности в §A.4 ниже (пометка ⚠).

---

# A. СИСТЕМА КОНФИГОВ (JSON)

## A.0 Общая архитектура

Все конфиги хранятся в `res://configs/`. Читаются один раз при старте клиента (splash/loading screen). В runtime доступны через синглтон `ConfigManager` (autoload). Если конфиг отсутствует или повреждён — используются hardcoded defaults + warning в лог.

**Структура папки:**
```
res://configs/
├── lobby_order.json
├── init_config.json
├── balance.json
├── machines.json          # миграция из data/paytables.json (расширенный)
├── shop.json
├── gift.json
├── sounds.json
├── animations.json
├── ui_config.json

res://data/
├── translations.json      # БЕЗ ИЗМЕНЕНИЯ — единый файл EN/RU/ES (см. CLAUDE.md §20)
```

**ConfigManager (autoload):**
```gdscript
# Загружает все конфиги при _ready()
# Предоставляет API: ConfigManager.get_machine("jacks_or_better"), ConfigManager.get_shop(), etc.
# Валидирует структуру, логирует ошибки, fallback на defaults
```

---

## A.1 lobby_order.json

Управляет структурой лобби: порядком табов режимов (sidebar) и порядком/доступностью машин внутри каждого режима.

**Правила:**
- Если режим удалён из JSON → таб исчезает из лобби
- Если машина удалена из списка → тайл исчезает из сетки
- Порядок в массиве = порядок отображения (сверху вниз для табов, слева направо / сверху вниз для машин)
- Поле `enabled` позволяет скрыть без удаления

```json
{
  "version": 1,
  "modes": [
    {
      "id": "single_play",
      "label_key": "lobby.mode_single_play",
      "enabled": true,
      "machines": [
        { "id": "jacks_or_better", "enabled": true },
        { "id": "bonus_poker", "enabled": true },
        { "id": "bonus_poker_deluxe", "enabled": true },
        { "id": "double_bonus", "enabled": true },
        { "id": "double_double_bonus", "enabled": true },
        { "id": "triple_double_bonus", "enabled": true },
        { "id": "aces_and_faces", "enabled": true },
        { "id": "deuces_wild", "enabled": true },
        { "id": "joker_poker", "enabled": true },
        { "id": "deuces_and_joker", "enabled": true }
      ]
    },
    {
      "id": "triple_play",
      "label_key": "lobby.mode_triple_play",
      "enabled": true,
      "machines": [
        { "id": "jacks_or_better", "enabled": true },
        { "id": "bonus_poker", "enabled": true },
        { "id": "deuces_wild", "enabled": true }
      ]
    },
    {
      "id": "five_play",
      "label_key": "lobby.mode_five_play",
      "enabled": true,
      "machines": [
        { "id": "jacks_or_better", "enabled": true },
        { "id": "bonus_poker", "enabled": true }
      ]
    },
    {
      "id": "ten_play",
      "label_key": "lobby.mode_ten_play",
      "enabled": true,
      "machines": [
        { "id": "jacks_or_better", "enabled": true },
        { "id": "bonus_poker", "enabled": true }
      ]
    },
    {
      "id": "ultra_vp",
      "label_key": "lobby.mode_ultra_vp",
      "enabled": true,
      "machines": [
        { "id": "jacks_or_better", "enabled": true },
        { "id": "double_double_bonus", "enabled": true }
      ]
    },
    {
      "id": "spin_poker",
      "label_key": "lobby.mode_spin_poker",
      "enabled": true,
      "machines": [
        { "id": "jacks_or_better", "enabled": true }
      ]
    }
  ]
}
```

---

## A.2 init_config.json

Настройки для нового аккаунта / первого запуска.

```json
{
  "version": 1,
  "starting_balance": 20000,
  "default_speed": 2,
  "default_denomination": 1,
  "default_mode": "single_play",
  "default_machine": "jacks_or_better",
  "default_locale": "en",
  "tutorial_enabled": true,
  "first_gift_delay_hours": 0
}
```

---

## A.3 balance.json

Ставки и рекомендованные глубины (denomination levels) для каждого режима. В будущем разные режимы могут иметь разные сетки ставок.

```json
{
  "version": 1,
  "modes": {
    "single_play": {
      "denominations": [1, 2, 5, 10, 25, 50, 100],
      "default_denomination_index": 0,
      "max_bet_multiplier": 5,
      "recommended_min_balance_multiplier": 200
    },
    "triple_play": {
      "denominations": [1, 2, 5, 10, 25],
      "default_denomination_index": 0,
      "max_bet_multiplier": 5,
      "recommended_min_balance_multiplier": 600
    },
    "five_play": {
      "denominations": [1, 2, 5, 10],
      "default_denomination_index": 0,
      "max_bet_multiplier": 5,
      "recommended_min_balance_multiplier": 1000
    },
    "ten_play": {
      "denominations": [1, 2, 5, 10],
      "default_denomination_index": 0,
      "max_bet_multiplier": 5,
      "recommended_min_balance_multiplier": 2000
    },
    "ultra_vp": {
      "denominations": [1, 2, 5, 10, 25],
      "default_denomination_index": 0,
      "max_bet_multiplier": 5,
      "recommended_min_balance_multiplier": 800,
      "note": "При MAX_BET ставка ×2 (активация множителей)"
    },
    "spin_poker": {
      "denominations": [1, 2, 5, 10],
      "default_denomination_index": 0,
      "max_bet_multiplier": 5,
      "recommended_min_balance_multiplier": 1000
    }
  }
}
```

---

## A.4 machines.json

Полная конфигурация каждой машины: комбинации, wild-карты, множители для каждого уровня ставки, экстра-множители для Ultra VP.

**⚠ Миграция:** при внедрении `configs/machines.json` необходимо переписать `scripts/paytable.gd` для чтения нового формата. Текущий `data/paytables.json` использует другую структуру (плоские ключи → массивы выплат). Новый формат (ниже) группирует данные по машинам и добавляет wild_cards, ultra_multipliers. Порядок действий:
1. Создать `configs/machines.json` в новом формате
2. Переписать `paytable.gd` → читать из `ConfigManager.get_machine(id)`
3. Обновить все вызовы в variant-скриптах (`get_payout`, `get_paytable_key`)
4. Убедиться что `Paytable.get_hand_display_name()` продолжает работать через `Translations.tr_key("hand." + key)`
5. Только после полной проверки — удалить старый `data/paytables.json`

**Правила:**
- Если комбинация удалена из `hands` → paytable на экране перестраивается (меньше строк)
- `wild_cards` — массив карт, которые считаются wild (гибко: можно назначить любые)
- `pays` — массив из 5 значений (для bet 1–5)
- `ultra_multipliers` — множители для режима Ultra VP (по комбинациям)

```json
{
  "version": 1,
  "machines": {
    "jacks_or_better": {
      "label_key": "machine.jacks_or_better",
      "deck_size": 52,
      "wild_cards": [],
      "min_winning_hand": "jacks_or_better",
      "hands": [
        {
          "id": "royal_flush",
          "label_key": "hand.royal_flush",
          "pays": [250, 500, 750, 1000, 4000]
        },
        {
          "id": "straight_flush",
          "label_key": "hand.straight_flush",
          "pays": [50, 100, 150, 200, 250]
        },
        {
          "id": "four_of_a_kind",
          "label_key": "hand.four_of_a_kind",
          "pays": [25, 50, 75, 100, 125]
        },
        {
          "id": "full_house",
          "label_key": "hand.full_house",
          "pays": [9, 18, 27, 36, 45]
        },
        {
          "id": "flush",
          "label_key": "hand.flush",
          "pays": [6, 12, 18, 24, 30]
        },
        {
          "id": "straight",
          "label_key": "hand.straight",
          "pays": [4, 8, 12, 16, 20]
        },
        {
          "id": "three_of_a_kind",
          "label_key": "hand.three_of_a_kind",
          "pays": [3, 6, 9, 12, 15]
        },
        {
          "id": "two_pair",
          "label_key": "hand.two_pair",
          "pays": [2, 4, 6, 8, 10]
        },
        {
          "id": "jacks_or_better",
          "label_key": "hand.jacks_or_better",
          "pays": [1, 2, 3, 4, 5]
        }
      ],
      "ultra_multipliers": {
        "royal_flush": 2,
        "straight_flush": 2,
        "four_of_a_kind": 7,
        "full_house": 5,
        "flush": 4,
        "straight": 3,
        "three_of_a_kind": 2,
        "two_pair": 1,
        "jacks_or_better": 1
      }
    },
    "deuces_wild": {
      "label_key": "machine.deuces_wild",
      "deck_size": 52,
      "wild_cards": ["2H", "2D", "2C", "2S"],
      "min_winning_hand": "three_of_a_kind",
      "hands": [
        {
          "id": "natural_royal_flush",
          "label_key": "hand.natural_royal_flush",
          "pays": [250, 500, 750, 1000, 4000]
        },
        {
          "id": "four_deuces",
          "label_key": "hand.four_deuces",
          "pays": [200, 400, 600, 800, 1000]
        },
        {
          "id": "wild_royal_flush",
          "label_key": "hand.wild_royal_flush",
          "pays": [25, 50, 75, 100, 125]
        },
        {
          "id": "five_of_a_kind",
          "label_key": "hand.five_of_a_kind",
          "pays": [15, 30, 45, 60, 75]
        },
        {
          "id": "straight_flush",
          "label_key": "hand.straight_flush",
          "pays": [9, 18, 27, 36, 45]
        },
        {
          "id": "four_of_a_kind",
          "label_key": "hand.four_of_a_kind",
          "pays": [4, 8, 12, 16, 20]
        },
        {
          "id": "full_house",
          "label_key": "hand.full_house",
          "pays": [4, 8, 12, 16, 20]
        },
        {
          "id": "flush",
          "label_key": "hand.flush",
          "pays": [3, 6, 9, 12, 15]
        },
        {
          "id": "straight",
          "label_key": "hand.straight",
          "pays": [2, 4, 6, 8, 10]
        },
        {
          "id": "three_of_a_kind",
          "label_key": "hand.three_of_a_kind",
          "pays": [1, 2, 3, 4, 5]
        }
      ],
      "ultra_multipliers": {
        "natural_royal_flush": 2,
        "four_deuces": 4,
        "wild_royal_flush": 3,
        "five_of_a_kind": 3,
        "straight_flush": 2,
        "four_of_a_kind": 6,
        "full_house": 5,
        "flush": 4,
        "straight": 3,
        "three_of_a_kind": 2
      }
    },
    "deuces_and_joker": {
      "label_key": "machine.deuces_and_joker",
      "deck_size": 53,
      "wild_cards": ["2H", "2D", "2C", "2S", "JOKER"],
      "min_winning_hand": "three_of_a_kind",
      "hands": [
        {
          "id": "five_wilds",
          "label_key": "hand.five_wilds",
          "pays": [0, 0, 0, 0, 10000],
          "note": "Pays ONLY on max bet"
        },
        {
          "id": "natural_royal_flush",
          "label_key": "hand.natural_royal_flush",
          "pays": [250, 500, 750, 1000, 4000]
        },
        {
          "id": "four_deuces",
          "label_key": "hand.four_deuces",
          "pays": [25, 50, 75, 100, 125]
        },
        {
          "id": "wild_royal_flush",
          "label_key": "hand.wild_royal_flush",
          "pays": [12, 24, 36, 48, 60]
        },
        {
          "id": "five_of_a_kind",
          "label_key": "hand.five_of_a_kind",
          "pays": [9, 18, 27, 36, 45]
        },
        {
          "id": "straight_flush",
          "label_key": "hand.straight_flush",
          "pays": [6, 12, 18, 24, 30]
        },
        {
          "id": "four_of_a_kind",
          "label_key": "hand.four_of_a_kind",
          "pays": [3, 6, 9, 12, 15]
        },
        {
          "id": "full_house",
          "label_key": "hand.full_house",
          "pays": [3, 6, 9, 12, 15]
        },
        {
          "id": "flush",
          "label_key": "hand.flush",
          "pays": [3, 6, 9, 12, 15]
        },
        {
          "id": "straight",
          "label_key": "hand.straight",
          "pays": [2, 4, 6, 8, 10]
        },
        {
          "id": "three_of_a_kind",
          "label_key": "hand.three_of_a_kind",
          "pays": [1, 2, 3, 4, 5]
        }
      ],
      "ultra_multipliers": {}
    }
  }
}
```

> **Примечание:** для краткости показаны 3 машины. Остальные 7 (Bonus Poker, Bonus Poker Deluxe, Double Bonus, Double Double Bonus, Triple Double Bonus, Aces and Faces, Joker Poker) оформляются по аналогии с учётом их paytable из claude.md.

---

## A.5 shop.json

Конфигурация магазина: перечень IAP, сортировка, бонусные фишки, рекламные плашки, иконки.

```json
{
  "version": 1,
  "currency_icon": "chip",
  "iap_items": [
    {
      "id": "pack_01",
      "sort_order": 1,
      "price_usd": 0.99,
      "chips": 5000,
      "bonus_chips": 0,
      "badge": null,
      "image": "shop_pack_01.svg"
    },
    {
      "id": "pack_02",
      "sort_order": 2,
      "price_usd": 2.99,
      "chips": 18000,
      "bonus_chips": 2000,
      "badge": "SPECIAL_VALUE",
      "image": "shop_pack_02.svg"
    },
    {
      "id": "pack_03",
      "sort_order": 3,
      "price_usd": 4.99,
      "chips": 40000,
      "bonus_chips": 10000,
      "badge": "BEST_VALUE",
      "image": "shop_pack_03.svg"
    },
    {
      "id": "pack_04",
      "sort_order": 4,
      "price_usd": 9.99,
      "chips": 100000,
      "bonus_chips": 30000,
      "badge": "BEST_SELLER",
      "image": "shop_pack_04.svg"
    },
    {
      "id": "pack_05",
      "sort_order": 5,
      "price_usd": 19.99,
      "chips": 250000,
      "bonus_chips": 100000,
      "badge": "BEST_VALUE",
      "image": "shop_pack_05.svg"
    }
  ],
  "badge_labels": {
    "SPECIAL_VALUE": "shop.badge.special_value",
    "BEST_VALUE": "shop.badge.best_value",
    "BEST_SELLER": "shop.badge.best_seller"
  },
  "images_path": "res://assets/shop/",
  "bonus_display": {
    "show_strikethrough_base": true,
    "show_total_highlighted": true,
    "show_bonus_percent": true
  }
}
```

**Логика bonus_chips в UI:**
- Если `bonus_chips > 0`:
  - Показать ~~5000~~ зачёркнутым (chips без бонуса)
  - Показать **7000** ярко (chips + bonus_chips = total)
  - Показать "+40%" динамически рассчитанный процент: `round(bonus_chips / chips * 100)`
- Если `bonus_chips == 0`: показать просто число chips

---

## A.6 gift.json

Конфигурация системы подарков (бесплатные фишки каждые N часов).

```json
{
  "version": 1,
  "interval_hours": 2,
  "chips_amount": 500,
  "notification": {
    "title_key": "gift.notification.title",
    "body_key": "gift.notification.body"
  },
  "claim_animation_duration_sec": 5,
  "show_lobby_indicator": true
}
```

---

## A.7 sounds.json (дополнительный конфиг — best practice)

Маппинг всех звуковых событий на файлы. Позволяет менять звуки без изменения кода.

```json
{
  "version": 1,
  "sounds_path": "res://assets/sounds/",
  "events": {
    "button_press": "sfx_button_press.mp3",
    "card_deal": "sfx_card_deal.mp3",
    "card_flip": "sfx_card_flip.mp3",
    "card_hold": "sfx_card_hold.mp3",
    "bet_change": "sfx_bet_change.mp3",
    "win_small": "sfx_win_small.mp3",
    "win_medium": "sfx_win_medium.mp3",
    "win_large": "sfx_win_large.mp3",
    "win_royal_flush": "sfx_win_royal_flush.mp3",
    "win_jackpot": "sfx_win_jackpot.mp3",
    "lose": "sfx_lose.mp3",
    "double_win": "sfx_double_win.mp3",
    "double_lose": "sfx_double_lose.mp3",
    "balance_increment": "sfx_balance_increment.mp3",
    "gift_claim": "sfx_gift_claim.mp3",
    "shop_purchase": "sfx_shop_purchase.mp3",
    "spin_reel": "sfx_spin_reel.mp3",
    "spin_stop": "sfx_spin_stop.mp3",
    "multiplier_activate": "sfx_multiplier_activate.mp3",
    "lobby_ambient": "sfx_lobby_ambient.mp3",
    "deal_button_blink": "sfx_deal_blink.mp3"
  }
}
```

---

## A.8 animations.json (дополнительный конфиг — best practice)

Тайминги всех анимаций. Позволяет тюнить feel без пересборки.

```json
{
  "version": 1,
  "card_deal_delay_ms": 100,
  "card_draw_delay_ms": 150,
  "bet_highlight_duration_ms": 1000,
  "win_counter_duration_ms": 3000,
  "win_highlight_hold_sec": 3,
  "balance_increment_duration_sec": 5,
  "gift_increment_duration_sec": 5,
  "deal_button_idle_blink_sec": 5,
  "deal_button_blink_interval_ms": 600,
  "spin_reel_stop_delay_ms": 2000,
  "spin_stop_inertia_ms": 700,
  "double_card_flip_ms": 800,
  "lobby_machine_tap_transition_ms": 400
}
```

---

## A.9 ui_config.json (дополнительный конфиг — best practice)

UI-параметры, которые могут меняться: отступы, размеры шрифтов, форматы отображения.

```json
{
  "version": 1,
  "chip_format": "{icon}{amount}",
  "chip_icon_glyph": "🪙",
  "number_format": "comma_separated",
  "balance_font_size": 28,
  "paytable_top_hand_font_size": 22,
  "paytable_top_hand_color": "#FF6666",
  "exit_icon_size": 48,
  "control_bar_padding_px": 12,
  "multihand_badge_height_px": 32,
  "multihand_badge_line_spacing_px": 2,
  "ultra_info_panel_fixed_height_px": 120
}
```

---

# B. ЛОББИ

### B.1 Инерция свайпа
- **Задача:** добавить инерцию (momentum scroll) при свайпе списка машин в лобби
- **Детали:** после отпускания пальца список продолжает двигаться с замедлением (deceleration). Стандартное поведение ScrollContainer в Godot — проверить `scroll_deadzone` и включить `follow_focus`. Если используется кастомная карусель, добавить Tween с easing `EASE_OUT`
- **Платформа:** touch (mobile) + mouse drag (desktop)

---

# C. НАСТРОЙКИ

### C.1 Кнопка "Удалить аккаунт"
- **Расположение:** экран Settings, внизу, красная кнопка
- **Логика:**
  1. Тап → первое предупреждение: "Вы уверены? Все данные будут удалены." [Отмена] [Продолжить]
  2. Тап "Продолжить" → второе предупреждение: "Это действие необратимо. Баланс, статистика и прогресс будут сброшены." [Отмена] [Удалить]
  3. Тап "Удалить" → очистить `user://save.json`, применить `init_config.json` (стартовый баланс 20000, дефолты), вернуть на экран лобби
- **Локализация:** все тексты через ключи

---

# D. ФИЧА: ПОДАРОК (FREE GIFT)

### D.1 Описание
- Каждые **N часов** (из `gift.json`) игроку становится доступен бесплатный подарок из **X фишек**
- Таймер обратного отсчёта виден в лобби (формат `HH:MM:SS`)
- По истечении таймера — кнопка подарка становится активной (пульсирует)
- После клейма: таймер сбрасывается, начинается новый отсчёт
- Анимация начисления: инкремент баланса в течение 5 секунд (из `animations.json`)

### D.2 Нотификации
- При готовности подарка — push notification (iOS/Android)
- Заголовок и тело из `gift.json` → ключи локализации в `data/translations.json`
- Добавить ключи во все 3 языка (EN / RU / ES):
  - EN: `"gift.notification.title": "Your gift is ready!"`, `"gift.notification.body_fmt": "Claim your free %s chips now!"`
  - RU: `"gift.notification.title": "Ваш подарок готов!"`, `"gift.notification.body_fmt": "Заберите %s бесплатных фишек!"`
  - ES: `"gift.notification.title": "¡Tu regalo está listo!"`, `"gift.notification.body_fmt": "¡Reclama tus %s fichas gratis!"`

### D.3 UI
- Лобби: виджет подарка рядом с балансом или внизу экрана
- Состояние "не готов": иконка + таймер обратного отсчёта, неактивная
- Состояние "готов": иконка пульсирует, кнопка "CLAIM" / "ЗАБРАТЬ"
- После клейма: анимация вылета фишек → инкремент баланса (5 сек)

---

# E. ЛОКАЛИЗАЦИЯ

### E.1 MAX BET — не переведена
- **Баг:** кнопка `MAX BET` захардкожена
- **Фикс:** заменить на ключ `game.bet_max`. EN = "MAX BET", RU = "МАКС. СТАВКА", ES = "APUESTA MÁX."
- Примечание: ключ `game.bet_max` может уже существовать в translations.json (проверить §20.3: `game.*` namespace)

### E.2 Кнопка BET → BET LVL
- **Изменение:** вместо "BET" показывать "BET LVL 5" / "Ур. ставки 5"
- **Ключ:** `game.bet_level_fmt` → EN: "BET LVL %s", RU: "Ур. ставки %s"
- Вызов: `tr_key("game.bet_level_fmt", [bet_level])`
- **Важно:** текст должен помещаться в кнопку. Если не влезает — уменьшить шрифт автоматически (`auto_shrink` или `clip_text` + уменьшение size). Вылезаний быть не должно

### E.3 Полный аудит хардкода
- **Задача:** пройтись по ВСЕМ `.tscn` и `.gd` файлам, найти все строковые литералы на экране
- Перевести каждый в ключ локализации через `Translations.tr_key()`
- Добавить ключи в `data/translations.json` во все 3 языка (EN / RU / ES) — по правилам §20 CLAUDE.md
- **Приоритет:** Spin Poker (§19 CLAUDE.md: "хардкод-строки пока присутствуют")

**Известные хардкоды для проверки:**
- "DEAL", "DRAW", "HELD" — **НЕ переводятся** (покерные термины, остаются на EN во всех локалях)
- "MAX BET" → ключ
- "BET ONE" → ключ
- "BALANCE:" → ключ
- "LAST WIN:" → ключ
- "TOTAL BET:" → ключ `label.total_bet` → RU: "ОБЩАЯ СТАВКА:"
- "PLACE YOUR BET" → ключ
- "HOLD CARDS, THEN DRAW" → ключ, учесть что HOLD и DRAW остаются на EN: "Выберите карты и жмите DRAW"
- "JACKS OR BETTER" (заголовок paytable) → из `machines.json` label_key
- Все названия комбинаций → из `machines.json` hand label_key
- "5 рук" → RU: "Рук: 5" / "Рук: 3"
- "Мутиль-рука" → "Мультихенд"
- "ВСЕГО СТАВКА" → "ОБЩАЯ СТАВКА"

### E.4 Система переменных в локализации
- **Текущее состояние (CLAUDE.md §20.2):** Translations уже поддерживает `%s` / `%d` интерполяцию через `tr_key("key_fmt", [arg1, arg2])`
- **Задача:** убедиться, что все новые строки с переменными используют `_fmt` суффикс в ключе и `%s`/`%d` placeholders
- Пример: `"double.msg_fmt": "Вы выиграли %s. Удвоить до %s?"` → вызов: `tr_key("double.msg_fmt", [format_money(amount), format_money(doubled)])`
- Иконка фишек: вставляется через `SaveManager.format_money()` (возвращает строку с глифом)
- **Не использовать** `{variable}` формат — это расходится с текущим API

### E.5 RichText в локализации
- Ключи могут содержать BBCode теги для выделения
- Пример: `"rules.point.1": "Минимальная выигрышная рука — [color=yellow]пара Вальтов[/color] или выше"`
- UI использует `RichTextLabel` для отображения таких строк

---

# F. SINGLE HAND — UI ПРАВКИ

### F.1 Popup правил — улучшение форматирования
- Таблицу особенностей машины — **выровнять по центру**
- Под каждый текстовый блок — **тёмно-синяя подложка** (полупрозрачная, `#1a1a66cc`)
- Список правил — **RichTextLabel** с BBCode
- Ключевые слова в каждом пункте выделить **жёлтым** (`[color=yellow]...[/color]`)
- Теги BBCode хранятся в файле локализации (не в коде)

### F.2 Максимальный выигрыш — цвет и размер
- Текст максимального выигрыша за самую редкую комбинацию (Royal Flush 4000):
  - Цвет: с красного `#FF0000` на **светло-красный** `#FF6666`
  - Шрифт: **увеличить на 2-4pt** относительно текущего

### F.3 Бейдж выигрышной комбинации — позиционирование
- **Баг:** после раунда бейджик с названием комбинации смещён вправо от центра руки
- **Фикс:** позиция бейджа = та же X-позиция что у бейджа "ВЫИГРЫШ: XXX". Оба бейджа центрированы горизонтально внутри области руки
- Проверить anchors/offsets у обоих бейджей

### F.4 Поля "Выигрыш" / "Последний выигрыш" — иконка фишек
- **Баг:** нет значка фишек рядом с числом
- **Фикс:** добавить иконку/глиф фишки перед числом. Формат: `{icon} {amount}`

### F.5 Разделить "Выигрыш/Последний выигрыш" и подсказку
- **Сейчас:** подсказка "Выберите карты и жмите DRAW" рядом с полями выигрыша
- **Как надо:** подсказку вынести и разместить **прямо над главной рукой** (над картами)
- Проверить отсутствие наложений (overlay) с другими элементами

### F.6 Баланс — увеличить шрифт
- Поле "БАЛАНС" — **увеличить размер шрифта** (из `ui_config.json` → `balance_font_size`)

---

# G. ВСЕ РЕЖИМЫ — ОБЩИЕ ПРАВКИ

### G.1 Подсветка ставки — увеличить длительность
- При переключении ставки подсветка текущего столбца в paytable — **увеличить в 2 раза**
- Значение из `animations.json` → `bet_highlight_duration_ms` (1000 ms → проверить текущее, удвоить)

### G.2 HELD / DEAL / DRAW — не переводить
- Слова HELD, DEAL, DRAW остаются на **английском** во всех локалях
- В подсказках, где упоминается HOLD/DRAW, оставить их на EN внутри переведённого предложения
- Пример RU: "Выберите карты и жмите DRAW"

### G.3 Окно подтверждения DOUBLE
- **Поменять местами** кнопки: [НЕТ] слева, [ДА] справа (сейчас наоборот)
- В тексте "Вы выиграли 100. Удвоить до 200" — **добавить иконку фишек**: "Вы выиграли {icon}100. Удвоить до {icon}200?"
- **Аудит:** проверить ВСЕ места с упоминанием фишек — везде должен быть формат `{icon}{amount}`

### G.4 Анимация накрутки выигрыша
- **Увеличить длительность в 2 раза** (из `animations.json` → `win_counter_duration_ms`)
- После окончания накрутки — **выделение фишек ещё 3 секунды** (пульсация/подсветка) для привлечения внимания (из `animations.json` → `win_highlight_hold_sec`)

### G.5 Анимация инкремента баланса при покупке/подарке
- **Новая фича:** после покупки IAP или клейма подарка — анимировать инкремент баланса в течение **5 секунд**
- Баланс плавно "считает" от старого значения к новому
- Из `animations.json` → `balance_increment_duration_sec`

### G.6 "ВСЕГО СТАВКА" → "ОБЩАЯ СТАВКА"
- Ключ `game.total_bet` → EN: "TOTAL BET:", RU: "ОБЩАЯ СТАВКА:", ES: "APUESTA TOTAL:"

### G.7 Кнопка выхода из-за стола
- **Сейчас:** стрелка влево
- **Изменение:** заменить на **иконку выхода** (door/exit icon), сделать **крупнее и заметнее**
- Размер: из `ui_config.json` → `exit_icon_size` (48px)
- Выровнять **по левому краю** контролбара
- При нажатии — **диалог подтверждения**: "Выйти из-за стола?" [Остаться] [Выйти]

### G.8 Центрирование "ОБЩАЯ СТАВКА: XXXX"
- Поле должно быть **отцентровано строго над кнопкой выбора ставки**
- **Баг:** сейчас текст съехал вправо
- Касается **всех режимов** (single, multi, ultra, spin)

### G.9 Дизейбл кнопки ставки во время раунда
- Во время раунда (states: DEALING, HOLDING, DRAWING, EVALUATING) кнопка выбора ставки должна быть **визуально задизейблена** (серая, не реагирует)
- Сейчас кнопка выглядит активной, но не нажимается — нужно визуальное отключение

### G.10 Фича: мигание кнопки DEAL/DRAW при idle
- Если игрок idle **5 секунд** → кнопка DEAL (или DRAW, в зависимости от state) начинает **пульсировать/мигать**
- Параметры из `animations.json` → `deal_button_idle_blink_sec`, `deal_button_blink_interval_ms`
- Мигание прекращается при любом действии игрока

### G.11 Фича: автооткрытие магазина при нехватке фишек
- Если игрок пытается поставить, но баланса не хватает:
  1. **Мигнуть балансом 2 раза** (красная подсветка)
  2. Автоматически **открыть магазин**

### G.12 Запоминание лейаута рук при выходе
- При выходе из-за стола (multihand, ultra) запоминать количество рук в `user://save.json`
- При следующем входе — восстановить

---

# H. MULTIHAND — ПРАВКИ

### H.1 Бейджи по бокам — увеличить высоту
- Увеличить **высоту** каждого блока бейджа (не меняя ширину)
- Значение из `ui_config.json` → `multihand_badge_height_px`

### H.2 "5 рук" → "Рук: 5"
- RU: `"game.hands_count_fmt": "Рук: %s"`
- EN: `"game.hands_count_fmt": "Hands: %s"`
- ES: `"game.hands_count_fmt": "Manos: %s"`

### H.3 Подсказка — переместить над главной рукой
- Убрать подсказку слева
- Разместить **оверлеем прямо над главной рукой**
- Убедиться: вёрстка рук **не едет** (подсказка абсолютно позиционирована, не влияет на layout)

### H.4 Контролбар — сделать уже
- Сдвинуть боковые группы кнопок **ближе к центру**
- Уменьшить padding/margins контролбара

### H.5 Уменьшить отступ между строками бейджей
- Из `ui_config.json` → `multihand_badge_line_spacing_px`

### H.6 Исправить русский перевод
- "Мутиль-рука" → **"Мультихенд"**
- Ключ `lobby.mode_multi_hand` → EN: "MULTI-HAND", RU: "МУЛЬТИХЕНД", ES: "MULTI-MANO"
- Примечание: в CLAUDE.md sidebar использует отдельные кнопки TRIPLE/FIVE/TEN PLAY, но если есть общее название режима — обновить

### H.7 Вкладки информации — форматирование
- Выравнивание по **центру**
- **Подложка** (тёмно-синяя) под весь блок текста
- Пункты правил — **RichText** с выделением главных слов **ярким зелёным** (`[color=#00FF88]...[/color]`)

---

# I. ULTRA VP (бывш. Ultimate) — ПРАВКИ

### I.1 Переименование
- **Ultimate → Ultra VP** во всех местах (код, UI, локализация, конфиги)
- Причина: "Ultimate" — торговая марка
- Ключ: `lobby.mode_ultra_vp` → EN: "Ultra VP", RU: "Ultra VP", ES: "Ultra VP"

### I.2 Контролбар — уже
- Аналогично multihand (H.4)

### I.3 Множители — фиксация при анимации карт
- **Баг:** активные множители двигаются вместе с картой при анимации
- **Фикс:** множители **стоят на месте**, карты анимируются под ними
- Добавить **полупрозрачную тёмную подложку** под множители для контрастности

### I.4 Подсказка — над главной рукой
- Аналогично multihand (H.3)

### I.5 Информационная плашка — фиксированная высота
- **Баг:** разная высота в состоянии "активно" и "неактивно"
- **Фикс:** фиксировать размер плашки (из `ui_config.json` → `ultra_info_panel_fixed_height_px`)
- Если текст не влезает — уменьшить `font_size` автоматически (auto-fit)
- В активном состоянии: лёгкая **пульсация** плашки + слова "АКТИВНО!" (tween scale 1.0 → 1.03 → 1.0, loop, ~2 сек цикл). Не навязчиво, но заметно

### I.6 Бейджи побед — ширина
- **Баг:** бейджи сжимаются по ширине текста
- **Фикс:** повторить логику multihand — фиксированная минимальная ширина бейджа

### I.7 Окно правил — форматирование
- Выравнивание по центру, подложки (аналогично H.7)
- Таблицу множителей — **сделать яркой**: строки раскрасить в цвет бейджей
- Числа множителей в формате глифов: **"5X"**, **"7X"** и т.д.

---

# J. SPIN POKER — ПРАВКИ

### J.1 Иконки линий — расположение
- **Баг:** цифры линий расположены кучно
- **Фикс:** каждая цифра должна быть **возле той строки, где начинается эта линия**
- Распределение: по 3 линии на каждой строке, кроме левой нижней — там 4
- Каждую цифру **упаковать в ленточку** (ribbon/flag), указывающую в сторону линии

### J.2 Скин рубашки карт
- **Баг:** скин рубашки пропал
- **Фикс:** вернуть отображение рубашки (card back texture)

### J.3 Контролбар — уже
- Аналогично multihand (H.4)

### J.4 See Pays — интерактивный экран
- Добавить **кнопку X** для закрытия
- Справа от пейтейбла — **таблица номеров линий**, раскрашенных в цвета линий
- При тапе на номер — **подсветить выбранную линию**
- Автоматическая **карусель** (автопролистывание линий) продолжает работать; тап просто меняет текущую позицию
- Пейтейбл — оформить как **таблицу** (с рамками/сеткой)

### J.5 Кнопка выхода
- **Баг:** кнопка выхода пропала
- **Фикс:** добавить идентичную всем остальным режимам (G.7)

### J.6 Увеличение автомата
- Увеличить весь автомат Spin Poker пока он **не упрётся в контролбар** (оставить 60px отступ)
- **Пропорции не менять** — масштабирование uniform scale

### J.7 Анимация закрытия строк
- **Баг:** потерялась анимация закрытия верхней и нижней строки при сбросе карт
- **Фикс:** восстановить анимацию fold/collapse крайних строк

### J.8 Скорости — замедлить
- Все скорости анимации **замедлить в 5 раз**
- Добавить **эффект остановки рилов** — торможение в течение 2 секунд (из `animations.json` → `spin_reel_stop_delay_ms`)

### J.9 Кнопка STOP — инерция
- Не мгновенная остановка, а **с инерцией 700ms** (из `animations.json` → `spin_stop_inertia_ms`)

### J.10 Баланс и ставка — полный формат
- Отображать без сокращений: `20,000` вместо `20K`

### J.11 Анимация рилов — эффект барабана слот-автомата
- **Сейчас:** карты просто сменяют друг друга мгновенно (random swap)
- **Как надо:** эффект настоящего слот-барабана (drum reel)
- **Реализация:**
  - Каждый столбец карт — вертикальная лента (strip) из спрайтов карт
  - При спине лента **прокручивается сверху вниз** (или снизу вверх) с высокой скоростью
  - Между целевыми картами — случайные промежуточные карты (blur filler), создающие эффект мелькания
  - Остановка: лента **замедляется** (ease-out deceleration), последняя карта "встаёт на место" с лёгким **отскоком** (overshoot bounce: проскакивает на ~5px вниз, возвращается)
  - Столбцы останавливаются **последовательно** слева направо с задержкой ~300ms между ними
  - Во время вращения — **motion blur** эффект (вертикальное размытие или просто быстрая смена спрайтов 20+ fps)
- **Параметры (в animations.json):**
  - `spin_reel_speed_px_per_sec`: 3000 (скорость прокрутки)
  - `spin_reel_deceleration_ms`: 800 (время торможения)
  - `spin_reel_bounce_px`: 5 (амплитуда отскока)
  - `spin_reel_column_delay_ms`: 300 (задержка между остановкой столбцов)
  - `spin_filler_cards_count`: 15 (количество промежуточных карт в ленте)
- **Godot подход:** ClipContent на контейнере столбца + Tween `position.y` ленты спрайтов, либо Shader с вертикальным UV-сдвигом

---

# K. ОТДЕЛЬНЫЕ ЗАДАЧИ

### K.1 Система вибраций (iOS / Android)
- **Платформы:** iOS (UIImpactFeedbackGenerator), Android (Vibrator)
- **События для вибрации:**

| Событие | Тип вибрации |
|---|---|
| Нажатие любой кнопки | Light (10ms) |
| Переворот карты (deal/draw) | Light (15ms) |
| Hold toggle | Light (10ms) |
| Выигрышный раунд | Medium (30ms) |
| Royal Flush / Jackpot | Heavy (100ms, pattern) |
| Спин автомата (Spin Poker) | Light continuous (во время спина) |
| Остановка рила | Medium (20ms) |
| Подарок claimed | Medium (40ms) |

- Добавить toggle в Settings: "Вибрация ON/OFF"
- Реализация: Godot plugin или нативный вызов через `OS.request_permission()` / Java/Swift bridge

### K.2 Система звуков — полный список + placeholder файлы

**Папка:** `res://assets/sounds/`

| Файл | Событие |
|---|---|
| `sfx_button_press.mp3` | Нажатие любой кнопки UI |
| `sfx_card_deal.mp3` | Раздача одной карты (deal) |
| `sfx_card_flip.mp3` | Переворот карты (draw replacement) |
| `sfx_card_hold.mp3` | Toggle HOLD на карте |
| `sfx_bet_change.mp3` | Изменение ставки (bet one / denomination) |
| `sfx_win_small.mp3` | Малый выигрыш (Jacks or Better, Two Pair) |
| `sfx_win_medium.mp3` | Средний выигрыш (Full House, Flush, Straight) |
| `sfx_win_large.mp3` | Крупный выигрыш (Four of a Kind, Straight Flush) |
| `sfx_win_royal_flush.mp3` | Royal Flush (фанфары, длинный) |
| `sfx_win_jackpot.mp3` | Jackpot (5 wilds в Deuces & Joker) |
| `sfx_lose.mp3` | Проигрыш (тишина или тихий звук) |
| `sfx_double_win.mp3` | Выигрыш в Double |
| `sfx_double_lose.mp3` | Проигрыш в Double |
| `sfx_balance_increment.mp3` | Тикание при анимации инкремента баланса |
| `sfx_gift_claim.mp3` | Клейм подарка |
| `sfx_shop_purchase.mp3` | Покупка в магазине |
| `sfx_spin_reel.mp3` | Кручение рилов Spin Poker (loop) |
| `sfx_spin_stop.mp3` | Остановка одного рила |
| `sfx_multiplier_activate.mp3` | Активация множителя (Ultra VP) |
| `sfx_lobby_ambient.mp3` | Фоновый амбиент казино (loop) |
| `sfx_deal_blink.mp3` | Мигание кнопки DEAL при idle |
| `sfx_notification.mp3` | Push notification sound |

**Действие:** создать файлы-заглушки (тихие .mp3) с правильными именами. Вадим заменит на реальные звуки, сохраняя имена.

---

# L. СВОДНАЯ ТАБЛИЦА ЗАДАЧ ПО ПРИОРИТЕТУ

| # | Задача | Секция | Критичность |
|---|---|---|---|
| 1 | JSON конфиги: архитектура + ConfigManager | A.0 | High |
| 2 | machines.json + paytable rebuild | A.4 | High |
| 3 | lobby_order.json | A.1 | High |
| 4 | balance.json | A.3 | Medium |
| 5 | init_config.json | A.2 | Medium |
| 6 | shop.json + bonus chips UI | A.5 | Medium |
| 7 | gift.json + Gift feature | A.6, D | Medium |
| 8 | sounds.json + placeholder files | A.7, K.2 | Low |
| 9 | animations.json | A.8 | Low |
| 10 | ui_config.json | A.9 | Low |
| 11 | Локализация: полный аудит хардкода | E.3 | High |
| 12 | Локализация: переменные в строках | E.4 | High |
| 13 | Локализация: RichText BBCode | E.5 | Medium |
| 14 | Локализация: MAX BET, BET LVL, etc. | E.1, E.2 | Medium |
| 15 | Иконка фишек везде | G.3, F.4 | High |
| 16 | Single hand: бейдж центрирование | F.3 | Medium |
| 17 | Single hand: popup правил | F.1 | Low |
| 18 | Single hand: подсказка над рукой | F.5 | Medium |
| 19 | Кнопка выхода: иконка + диалог | G.7 | Medium |
| 20 | ОБЩАЯ СТАВКА центрирование | G.8 | Medium |
| 21 | Дизейбл кнопки ставки в раунде | G.9 | Medium |
| 22 | Анимация накрутки × 2 | G.4 | Low |
| 23 | Подсветка ставки × 2 | G.1 | Low |
| 24 | Мигание DEAL при idle | G.10 | Low |
| 25 | Автооткрытие магазина | G.11 | Medium |
| 26 | Multihand: подсказка, контролбар, бейджи | H | Medium |
| 27 | Ultra VP: переименование | I.1 | High |
| 28 | Ultra VP: множители фикс | I.3 | High |
| 29 | Ultra VP: плашка фиксированная высота | I.5 | Medium |
| 30 | Ultra VP: бейджи ширина | I.6 | Medium |
| 31 | Spin: иконки линий | J.1 | Medium |
| 32 | Spin: скорости ×5 медленнее | J.8 | Medium |
| 33 | Spin: See Pays интерактивный | J.4 | Low |
| 34 | Spin: увеличение автомата | J.6 | Medium |
| 35 | Удалить аккаунт | C.1 | Low |
| 36 | Лобби: инерция свайпа | B.1 | Low |
| 37 | Вибрации (iOS/Android) | K.1 | Low |
| 38 | Баланс инкремент анимация | G.5 | Low |
| 39 | Запоминание лейаута рук | G.12 | Low |
| 40 | Double: кнопки ДА/НЕТ swap | G.3 | Medium |
| 41 | Spin: рубашка карт | J.2 | High |
| 42 | Spin: кнопка выхода | J.5 | High |
| 43 | Spin: STOP инерция | J.9 | Medium |
| 44 | Spin: анимация fold строк | J.7 | Medium |
| 45 | Multihand: "Мультихенд" перевод | H.6 | Medium |
| 46 | Ultra VP: окно правил | I.7 | Low |
| 47 | Single hand: шрифт баланса | F.6 | Low |
| 48 | Spin: полный формат баланса | J.10 | Low |
| 49 | Spin: анимация барабана рилов | J.11 | High |

---

*Документ создан: 2026-04-13*
*Версия: 1.1 (выверено с CLAUDE.md v2.0)*
