# UI Layouts & Lobby Visual Spec

Ссылка из CLAUDE.md §5, §7. Детали layout'а лобби и игровых экранов.

---

## Лобби (Game King стиль)

```
┌──────────────────────────────────────────────────────┐
│ [chip] $24,383        VIDEO POKER           [⚙]      │   ← TopBar (красный)
├──────┬───────────────────────────────────────────────┤
│SINGLE│                                               │
│ PLAY │  [JOB] [Bonus] [BPD] [DBL] [DDB]              │
│TRIPLE│                                               │
│ PLAY │  [TDB] [A&F] [DW]  [JP]  [D&J]                │
│ FIVE │                                               │
│ PLAY │         (drag-scroll горизонтально)           │
│ TEN  │                                               │
│ PLAY │                                               │
│ULT X │                                               │
│SPIN  │                                               │
│POKER │                                               │
└──────┴───────────────────────────────────────────────┘
```

### Карточка машины
- `PanelContainer` с именем сверху (жёлтый bold) и мини-описанием внизу
- Цвет фона меняется динамически по выбранному режиму (`MODE_COLORS` в `lobby_manager.gd`)
- Lock overlay для заблокированных (на данный момент все разблокированы)
- Тап → `_on_play_pressed` → `machine_selected` сигнал

### Sidebar — режимы

`PLAY_MODES` в `lobby_manager.gd`:

| Режим | hands | ultra_vp | spin_poker | Сцена |
|---|---|---|---|---|
| SINGLE PLAY | 1 | false | false | `game.tscn` |
| TRIPLE PLAY | 3 | false | false | `multi_hand_game.tscn` |
| FIVE PLAY | 5 | false | false | `multi_hand_game.tscn` |
| TEN PLAY | 10 | false | false | `multi_hand_game.tscn` |
| ULTRA VP | 5 | **true** | false | `multi_hand_game.tscn` |
| SPIN POKER | 1 | false | **true** | `spin_poker_game.tscn` |

Сохранение: `SaveManager.hand_count`, `.ultra_vp`, `.spin_poker`.

### Цветовая схема машин

| Машина | Цвет | Акцент |
|---|---|---|
| Jacks or Better | Синий | Золотой |
| Bonus Poker | Красный | Серебро |
| Bonus Poker Deluxe | Пурпурный | Золотой |
| Double Bonus | Тёмно-красный | Хром |
| Double Double Bonus | Бордовый | Золотой |
| Triple Double Bonus | Чёрный | Золотой |
| Aces and Faces | Зелёный | Серебро |
| Deuces Wild | Ярко-зелёный | Жёлтый |
| Joker Poker | Фиолетовый | Жёлтый |
| Deuces and Joker Wild | Изумрудный | Красный |

### Навигация
- Drag-скролл grid'а (`_setup_drag_scroll`)
- Шестерёнка ⚙ → settings popup → LANGUAGE sub-popup
- Баланс — top bar (чипсы + сумма)

---

## Игровой экран — Portrait

```
┌────────────────────────────────┐
│         PAYTABLE               │
│  (таблица выплат, 9 строк)     │
├────────────────────────────────┤
│   [Card1] [Card2] [Card3]     │
│       [Card4] [Card5]         │
│   [HOLD]  [HOLD]  [HOLD]      │
│       [HOLD]  [HOLD]          │
├────────────────────────────────┤
│  CREDITS: 1000  WIN: 0        │
│  BET: 5                       │
├────────────────────────────────┤
│ [BET 1] [BET MAX] [DEAL/DRAW] │
└────────────────────────────────┘
```

## Игровой экран — Landscape

```
┌──────────────────────────────────────────────┐
│                   PAYTABLE                    │
├──────────────────────────────────────────────┤
│   [Card1] [Card2] [Card3] [Card4] [Card5]   │
│   [HOLD]  [HOLD]  [HOLD]  [HOLD]  [HOLD]    │
├──────────────────────────────────────────────┤
│  CREDITS: 1000    BET: 5     WIN: 45         │
├──────────────────────────────────────────────┤
│  [BET 1] [BET MAX]         [DEAL/DRAW]       │
└──────────────────────────────────────────────┘
```

## Элементы UI

| Элемент | Описание |
|---|---|
| Paytable | Постоянно отображается, строка текущей ставки подсвечена, мигает при выигрыше |
| Карты | 5 карт. При HOLD — "HELD" поверх |
| HOLD | Под каждой картой, toggle |
| BET ONE | Цикл 1→2→3→4→5→1 |
| BET MAX | 5 + auto Deal |
| DEAL/DRAW | Одна кнопка, меняет надпись |
| Credits/Bet/Win | LED-стиль |
| Win label | Название комбинации |

## Denomination

| Den | Bet 1 | Bet 5 |
|---|---|---|
| 1 | 1 | 5 |
| 5 | 5 | 25 |
| 25 | 25 | 125 |
| 100 | 100 | 500 |
| 500 | 500 | 2500 |

## Game State Machine

```
IDLE → BETTING → DEALING → HOLDING → DRAWING → EVALUATING → WIN_DISPLAY → IDLE
```

| State | Доступные действия |
|---|---|
| IDLE | Bet One, Bet Max, Deal |
| BETTING | Bet One, Bet Max, Deal |
| DEALING | — |
| HOLDING | Hold toggles, Draw |
| DRAWING | — |
| EVALUATING | автоматически |
| WIN_DISPLAY | любая кнопка → IDLE |

## Scene structure (game screen)

```
TopSection (VBox, anchor top)     — title, paytable, balance/status
MiddleSection (dynamic anchors)   — карты (+ мини-руки в multi-hand)
BottomSection (VBox, anchor bottom) — total bet, кнопки, padding
```

## Layout архитектура — два паттерна, один правильный

В проекте сосуществуют **два разных способа** разместить секции
(Top / Middle / Bottom) внутри игровой сцены. На практике один
оказался хрупким, другой — устойчивым.

### Sibling-of-root (Classic single-hand) — НЕ для новых сцен

`scenes/game.tscn`:
```
Game (Control, FULL_RECT)
├── Background (FULL_RECT)
├── TopSection (anchor top, auto-size)
├── MiddleSection (anchors считаются вручную)
└── BottomSection (anchor bottom, grow up)
```

Секции — прямые дети корня сцены, каждая со своими anchors. Между
TopSection и BottomSection положение MiddleSection не очевидно из
.tscn — нужен runtime-код, который его рассчитает (в `game.gd`
это `_layout_middle()`).

Эта схема обернулась чередой проблем (см. PAIN_LOG 2026-05-05):
- `_layout_middle` пишет offsets, а entrance-animation твинит
  `position:y` — гонка, position перезаписывает offsets
- Paytable догружается за несколько кадров, сечение `resized`
  фиссится сериями, нужны listener'ы + lock-после-init, чтобы
  in-game text changes не triggered re-layout
- Безопасное чтение «settled» позиций требует аналитической
  формулы вместо `position.y`

Полный набор защит — в `scripts/game.gd`: lock-флаг
`_layout_locked`, listener'ы на `TopSection.resized` /
`BottomSection.resized` / `safe_area_changed` / `viewport.size_changed`,
аналитический расчёт `top_y` / `bot_y` без чтения `position.y`.

### VBoxContainer-as-parent (multi-hand, supercell-multi) — паттерн на будущее

`scenes/multi_hand_game.tscn`:
```
MultiHandGame (Control, FULL_RECT)
├── Background
└── VBoxContainer (FULL_RECT)
    ├── TitleBar
    ├── HandsArea (size_flags_vertical = EXPAND_FILL)
    └── BottomSection
```

Все секции — дети `VBoxContainer`. Родитель **сам** распределяет
вертикальное место по детям через `size_flags_vertical` (FILL /
EXPAND_FILL / SHRINK_*). Никаких ручных offset-записей, никаких
`_layout_middle`, никаких listener'ов на resize.

Все «драмы» из PAIN_LOG'а **физически невозможны** в этой схеме,
потому что в ней нет того места, где Race condition могла бы
произойти. Multi-hand за 11 билдов этой волны фиксов не получил
ни одной layout-правки — он работал из коробки.

### Рекомендация

**Новые игровые сцены делать через VBoxContainer-as-parent.**
Sibling-of-root паттерн в `game.tscn` оставлен как есть (build 11
закрыл все известные баги), но рефакторить его на VBoxContainer —
в roadmap, не в текущей итерации.

Если **обязательно** нужна sibling-of-root схема (например, для
overlap-эффектов, когда секции должны рисоваться поверх друг
друга или с z-index трюками), скопируй защитный набор из
`game.gd` целиком — иначе грабли вернутся.

## Status / hint label с переменной длиной текста

Подсказка между BALANCE и WIN (`PLACE YOUR BET`, `HOLD CARDS, THEN
DRAW`, `DOUBLE OR NOTHING?` и т. д.) — частая точка, где UI ломается
из-за того, что разные тексты имеют разную ширину.

### Антипаттерн

```gdscript
_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
_status_label.text = "HOLD CARDS, THEN DRAW"  # длиннее предыдущего
```

Без `clip_text` Label вычисляет `minimum_size.x` из ширины текста.
EXPAND_FILL даёт ему **leftover-долю** ширины, но если min_size
больше leftover-доли, Container уважает min — тащит ширину родителя.
В цепочке `Label → HBoxContainer → MarginContainer → VBoxContainer`
это порождает каскад «разъезжаний» соседних виджетов
(BALANCE-pill, кнопок, paytable-grid).

### Паттерн правильно (см. `scripts/game.gd._fit_status_font`)

```gdscript
_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
_status_label.custom_minimum_size = Vector2(0, 0)  # min ВЫРУБЛЕНО
_status_label.clip_text = true                      # overflow → клип

# При каждом set'е текста — auto-fit font:
func _fit_status_font() -> void:
    var avail: float = _status_label.size.x - 4.0
    var font: Font = _status_label.get_theme_font("font")
    var picked := 12  # floor
    for fs in [20, 18, 16, 14, 12]:
        var w := font.get_string_size(_status_label.text,
            HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
        if w <= avail:
            picked = fs
            break
    _status_label.add_theme_font_size_override("font_size", picked)
```

### Правила

1. Любой Label с **переменным текстом**, сидящий в HBox/VBox среди
   других виджетов фиксированных размеров, должен иметь
   `custom_minimum_size.x = 0` + `clip_text = true`. Иначе текст
   диктует ширину родителю.
2. Если читаемость важна (а для подсказок игроку — важна), добавь
   auto-fit font: набор ступеней размера, выбираем максимальный
   при котором текст влезает. Floor — минимум ниже которого читать
   нельзя (в проекте 12pt).
3. Soft-clip через `clip_text = true` — fallback на случай если
   даже floor-размер не влезает. Лучше срез, чем сломанный layout.

## Шрифты

| Использование | Шрифт |
|---|---|
| Paytable | Monospace / LCD (Digital-7, DSEG7) |
| Credits/Bet/Win | LED (DSEG7 Modern) |
| Названия комбинаций | Bold Sans-Serif |
| Кнопки | Bold uppercase Sans-Serif |
| UI общий | Roboto / Open Sans |
