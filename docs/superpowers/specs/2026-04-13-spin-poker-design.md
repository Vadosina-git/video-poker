# Spin Poker — Design Spec

**Date:** 2026-04-13
**Branch:** feature/spin-poker

---

## Overview

Spin Poker — гибрид видеопокера и слота. Игровое поле — сетка 3×5 (15 карточных позиций). Игрок взаимодействует только со средним рядом (hold). При draw удержанные карты дублируются в верхний/нижний ряды, неудержанные позиции заполняются из одной общей колоды. 20 фиксированных линий формируют независимые 5-карточные руки для оценки.

---

## File Structure

| File | Purpose |
|---|---|
| `scripts/spin_poker_manager.gd` | FSM + game logic (deck, lines, evaluation) |
| `scripts/spin_poker_game.gd` | UI: 3×5 grid, spin animations, buttons, line display |
| `scenes/spin_poker_game.tscn` | Scene (root Control, anchors_preset=15) |
| `scripts/lobby_manager.gd` | Add "SPIN POKER" to PLAY_MODES sidebar |
| `scripts/main.gd` | Route to spin_poker_game.tscn when SaveManager.spin_poker |
| `scripts/save_manager.gd` | Add `spin_poker: bool` field |

---

## FSM (spin_poker_manager.gd)

```
IDLE → SPINNING → HOLDING → DRAW_SPINNING → EVALUATING → WIN_DISPLAY → IDLE
```

| State | Description | User Actions |
|---|---|---|
| IDLE | Awaiting bet/deal | Bet, Bet Max, Deal Spin |
| SPINNING | Deal spin animation (middle row) | Stop Spin (instant stop) |
| HOLDING | Player selects holds on middle row | Tap cards, Draw Spin |
| DRAW_SPINNING | Draw spin animation (all 3 rows) | Stop Spin (instant stop) |
| EVALUATING | Evaluate all 20 lines | — (automatic) |
| WIN_DISPLAY | Show wins, animate credits | Deal Spin (new round) |

### Signals

```gdscript
signal deal_spin_complete(middle_row: Array[CardData])
signal draw_spin_complete(grid: Array)  # 3×5 array
signal lines_evaluated(results: Array, total_payout: int)
signal credits_changed(new_credits: int)
signal bet_changed(new_bet: int)
signal state_changed(new_state: int)
```

---

## Grid & Card Layout

### 3×5 Grid (15 positions)

```
| col0    | col1    | col2    | col3    | col4    |
|---------|---------|---------|---------|---------|
| top[0]  | top[1]  | top[2]  | top[3]  | top[4]  |  ← Row 0 (top)
| mid[0]  | mid[1]  | mid[2]  | mid[3]  | mid[4]  |  ← Row 1 (middle, interactive)
| bot[0]  | bot[1]  | bot[2]  | bot[3]  | bot[4]  |  ← Row 2 (bottom)
```

- 15 CardVisual nodes arranged in GridContainer (3 rows × 5 cols)
- Middle row: interactive (hold toggleable)
- Top/bottom rows: non-interactive, filled during draw
- Before deal: all positions show card backs or empty placeholder
- After deal spin: only middle row shows face-up cards
- After draw spin: all 15 positions show face-up cards

---

## 20 Lines Definition

Each line picks one row position (T=0, M=1, B=2) per column:

| Line | Color | Pattern [col0,col1,col2,col3,col4] | Description |
|---|---|---|---|
| 1 | Red | M-M-M-M-M | Straight middle |
| 2 | Blue | T-T-T-T-T | Straight top |
| 3 | Dark Blue | B-B-B-B-B | Straight bottom |
| 4 | Peach | T-M-B-M-T | V-shape |
| 5 | Pink | B-M-T-M-B | Inverted V |
| 6 | Orange | T-T-M-B-B | Descending diagonal |
| 7 | Purple | B-B-M-T-T | Ascending diagonal |
| 8 | Green | M-T-M-B-M | Zigzag up-down |
| 9 | Yellow | M-B-M-T-M | Zigzag down-up |
| 10 | Light Green | T-M-M-M-T | Shallow V |
| 11 | Teal | B-M-M-M-B | Shallow inverted V |
| 12 | Lime | M-M-T-M-M | Bump up center |
| 13 | Coral | M-M-B-M-M | Bump down center |
| 14 | Cyan | T-T-B-T-T | Dip from top |
| 15 | Magenta | B-B-T-B-B | Peak from bottom |
| 16 | Gold | T-M-T-M-T | W-shape |
| 17 | Silver | B-M-B-M-B | M-shape |
| 18 | Sky Blue | M-T-T-T-M | Top plateau |
| 19 | Brown | M-B-B-B-M | Bottom plateau |
| 20 | White | T-B-T-B-T | Extreme zigzag |

Data structure:
```gdscript
const LINES := [
    [1,1,1,1,1],  # Line 1: M-M-M-M-M
    [0,0,0,0,0],  # Line 2: T-T-T-T-T
    [2,2,2,2,2],  # Line 3: B-B-B-B-B
    [0,1,2,1,0],  # Line 4: T-M-B-M-T
    [2,1,0,1,2],  # Line 5: B-M-T-M-B
    [0,0,1,2,2],  # Line 6: T-T-M-B-B
    [2,2,1,0,0],  # Line 7: B-B-M-T-T
    [1,0,1,2,1],  # Line 8: M-T-M-B-M
    [1,2,1,0,1],  # Line 9: M-B-M-T-M
    [0,1,1,1,0],  # Line 10: T-M-M-M-T
    [2,1,1,1,2],  # Line 11: B-M-M-M-B
    [1,1,0,1,1],  # Line 12: M-M-T-M-M
    [1,1,2,1,1],  # Line 13: M-M-B-M-M
    [0,0,2,0,0],  # Line 14: T-T-B-T-T
    [2,2,0,2,2],  # Line 15: B-B-T-B-B
    [0,1,0,1,0],  # Line 16: T-M-T-M-T
    [2,1,2,1,2],  # Line 17: B-M-B-M-B
    [1,0,0,0,1],  # Line 18: M-T-T-T-M
    [1,2,2,2,1],  # Line 19: M-B-B-B-M
    [0,2,0,2,0],  # Line 20: T-B-T-B-T
]
```

---

## Deck & Deal Mechanics

### One shared deck per round

- Standard 52-card deck (53 for Joker variants)
- Fisher-Yates shuffle before each round
- Deal: first 5 cards → middle row
- Draw: remaining cards fill unheld positions across all 3 rows

### Draw card distribution

After hold selection, cards are distributed left-to-right by column:

```
For each column (0..4):
    if column is held:
        top[col] = mid[col]  (duplicate)
        bot[col] = mid[col]  (duplicate)
    else:
        top[col] = next card from deck
        mid[col] = next card from deck
        bot[col] = next card from deck
```

Total cards needed: 5 (deal) + unheld_columns × 3 (draw) = 5 to 20 cards from 52.

---

## Betting

- 20 lines (fixed, not configurable)
- Bet per line: 1-5 (coins_per_line)
- Total bet = 20 × coins_per_line × denomination
- BET button cycles coins_per_line 1→2→3→4→5→1
- BET MAX sets coins_per_line=5 and auto-deals

---

## Spin Animation

### Deal Spin (first spin)

1. All 15 positions start blank/backs
2. Each column "spins" vertically — rapid card texture cycling (slot reel effect)
3. Columns stop left-to-right with ~150ms delay between stops
4. Only middle row card is revealed; top/bottom show placeholder (purple gradient or card back)
5. STOP SPIN button: instantly stops all columns

### Draw Spin (second spin)

1. Held columns: middle card duplicated to top/bottom with brief appear animation
2. Unheld columns: all 3 positions spin (vertical reel effect)
3. Columns stop left-to-right
4. All 15 cards revealed
5. STOP SPIN button: instantly stops all columns

### Reel animation approach

Each column uses a tween that rapidly cycles through random card textures at ~30ms intervals, then decelerates and stops on the target card. Implementation: timer-based texture swap in a loop, then final flip to real card.

---

## Win Display

### Line evaluation

After draw, all 20 lines evaluated:
```gdscript
for line_idx in 20:
    var hand: Array[CardData] = []
    for col in 5:
        var row: int = LINES[line_idx][col]
        hand.append(grid[row][col])
    var rank = variant.evaluate(hand)
    var payout = variant.get_payout(rank, coins_per_line)
```

### Win presentation

1. All winning lines highlighted simultaneously with colored Line2D paths
2. Then cycle through each winning line individually:
   - Draw colored line through grid
   - Highlight the 5 cards of that line with colored border
   - Show badge on center card: "HAND NAME\nPAYS X"
   - Status bar: "FULL HOUSE PAYS 15"
3. After cycling: "GAME PAYS {total}" in status bar
4. Total payout = sum of all line payouts × denomination

### Line number indicators

- Left side of grid: line numbers 1-10 (small colored labels with bet amount)
- Right side of grid: line numbers 11-20
- Each label colored to match its line color

---

## UI Layout

```
┌──────────────────────────────────────────────────┐
│              SPIN POKER  20 LINES                │
│          [Variant Name: Jacks or Better]         │
├──────────────────────────────────────────────────┤
│  [5] ┌─────┬─────┬─────┬─────┬─────┐ [5]       │
│  [5] │ T0  │ T1  │ T2  │ T3  │ T4  │ [5]       │
│  [5] ├─────┼─────┼─────┼─────┼─────┤ [5]       │
│  [5] │ M0  │ M1  │ M2  │ M3  │ M4  │ [5]       │
│  [5] ├─────┼─────┼─────┼─────┼─────┤ [5]       │
│  [5] │ B0  │ B1  │ B2  │ B3  │ B4  │ [5]       │
│  [5] └─────┴─────┴─────┴─────┴─────┘ [5]       │
│  [5]                                   [5]       │
│  [5]                                   [5]       │
├──────────────────────────────────────────────────┤
│  [Status: SELECT REELS TO HOLD...]               │
│  [GAME PAYS 30]                                  │
├──────────────────────────────────────────────────┤
│ WIN [xx] BET [xx]  [DEAL/DRAW SPIN]  [BET][MAX] │
│ [chip XX] [BACK]   [SEE PAYS][SPEED] [chip XX]  │
└──────────────────────────────────────────────────┘
```

### Buttons

| Button | Action |
|---|---|
| DEAL SPIN | Start new round (in IDLE/WIN_DISPLAY) |
| STOP SPIN | Instant stop during spin animation |
| DRAW SPIN | Draw after hold selection (in HOLDING) |
| BET | Cycle coins_per_line 1→5 |
| BET MAX | Set max coins + auto deal |
| SEE PAYS | Show paytable popup |
| SPEED | Cycle speed 1→4 |
| BACK | Return to lobby |
| Denomination | Open bet picker |

---

## Integration

### lobby_manager.gd

Add to PLAY_MODES:
```gdscript
{"label": "SPIN POKER", "hands": 1, "spin_poker": true, "ultimate_x": false}
```

### main.gd

```gdscript
if SaveManager.spin_poker:
    # Load spin_poker_game.tscn
elif hand_count > 1 or ultimate_x:
    # Load multi_hand_game.tscn
else:
    # Load game.tscn
```

### save_manager.gd

Add field: `var spin_poker: bool = false`
Serialize/deserialize in save_game/load_game.

---

## Supported Variants

All existing 10 variants work with Spin Poker. The variant determines:
- Deck size (52 or 53)
- Wild cards
- Hand evaluation logic
- Paytable

No variant-specific changes needed — existing BaseVariant interface is sufficient.

---

## Out of Scope

- Super Times Pay (random multiplier)
- Ultimate X Spin Poker (multipliers)
- Triple Spin Poker (3 independent grids)
- Dream Card
- Configurable line count (fixed at 20)
