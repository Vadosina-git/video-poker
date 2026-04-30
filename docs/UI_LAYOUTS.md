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

## Шрифты

| Использование | Шрифт |
|---|---|
| Paytable | Monospace / LCD (Digital-7, DSEG7) |
| Credits/Bet/Win | LED (DSEG7 Modern) |
| Названия комбинаций | Bold Sans-Serif |
| Кнопки | Bold uppercase Sans-Serif |
| UI общий | Roboto / Open Sans |
