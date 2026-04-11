# Multi-Hand Video Poker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-hand play modes (3, 5, 10, 12, 25 hands) to all 10 video poker variants — player holds cards on a primary hand, then each additional hand gets independent draws from separate decks while sharing the held cards.

**Architecture:** The existing single-hand `GameManager` becomes one component inside a new `MultiHandManager` that orchestrates N independent hands. Each hand gets its own `Deck`, but all share the same initial deal and hold decisions. The UI adds a grid of mini-hands above/around the primary hand. The lobby sidebar mode selector (SINGLE/TRIPLE/FIVE/TEN PLAY) controls how many hands are active.

**Tech Stack:** Godot 4.6, GDScript, existing variant system (BaseVariant + 10 variants), existing card/deck/evaluator classes.

---

## How Multi-Hand Works (Domain Knowledge)

1. Player places bet (bet × num_hands is deducted)
2. 5 cards dealt to primary hand (same as single)
3. Player holds/discards on primary hand
4. On DRAW: primary hand draws replacements from its deck. Each additional hand starts with the SAME 5 initial cards, applies the SAME hold pattern, but draws replacements from its OWN independent deck
5. All hands are evaluated independently
6. Total payout = sum of all hand payouts

Key: each extra hand uses a SEPARATE shuffled deck. The held cards are copied, the discarded positions get unique random replacements per hand.

---

## File Map

### New files to create
| File | Responsibility |
|---|---|
| `scripts/multi_hand_manager.gd` | Orchestrates N hands: deals, applies holds, draws from N decks, evaluates all, sums payouts |
| `scripts/mini_hand_display.gd` | Visual for one mini-hand (5 small cards in a row) |
| `scenes/mini_hand.tscn` | Scene for mini-hand display |
| `scenes/multi_hand_game.tscn` | Game screen for multi-hand mode (replaces game.tscn when num_hands > 1) |
| `scripts/multi_hand_game.gd` | UI controller for multi-hand game screen |

### Files to modify
| File | Changes |
|---|---|
| `scripts/game_manager.gd` | Extract shared logic, add `get_initial_hand()` method |
| `scripts/lobby_manager.gd` | Wire sidebar buttons to select hand count, pass to main.gd |
| `scripts/main.gd` | Accept hand_count, load single or multi-hand game scene |
| `scripts/deck.gd` | Add `deal_hand_excluding(excluded: Array[CardData])` for extra hands |
| `scripts/save_manager.gd` | Save/load `hand_count` preference |

---

## Task 1: Extend Deck to support multi-hand draws

**Files:**
- Modify: `scripts/deck.gd`

- [ ] **Step 1: Add method to deal replacements excluding held cards**

In `scripts/deck.gd`, add after `get_replacement()`:

```gdscript
## Deal a full 5-card hand for a secondary multi-hand.
## The held cards are fixed (from primary hand). Only non-held positions
## get new cards from this deck (which is independently shuffled).
func deal_multihand_replacements(primary_hand: Array[CardData], held: Array[bool]) -> Array[CardData]:
	shuffle()
	var result: Array[CardData] = []
	var draw_idx: int = 0
	for i in 5:
		if held[i]:
			result.append(primary_hand[i])
		else:
			# Find next card in deck that isn't one of the held cards
			while draw_idx < _cards.size():
				var card := _cards[draw_idx]
				draw_idx += 1
				var dominated := false
				for j in 5:
					if held[j] and primary_hand[j].index == card.index:
						dominated = true
						break
				if not dominated:
					result.append(card)
					break
	return result
```

- [ ] **Step 2: Verify no parse errors in Godot**

- [ ] **Step 3: Commit**

---

## Task 2: Create MultiHandManager

**Files:**
- Create: `scripts/multi_hand_manager.gd`

- [ ] **Step 1: Create the manager**

```gdscript
class_name MultiHandManager
extends Node

signal all_hands_dealt(hands: Array)  # Array of Array[CardData]
signal all_hands_evaluated(results: Array)  # Array of {hand_rank, hand_name, payout}
signal credits_changed(new_credits: int)
signal bet_changed(new_bet: int)
signal state_changed(new_state: int)

enum State { IDLE, DEALING, HOLDING, DRAWING, EVALUATING, WIN_DISPLAY }

const MAX_BET := 5

var state: State = State.IDLE
var variant: BaseVariant
var num_hands: int = 3
var bet: int = 1

# Primary hand (player interacts with this)
var primary_hand: Array[CardData] = []
var held: Array[bool] = [false, false, false, false, false]

# All hands after draw (index 0 = primary)
var all_hands: Array = []  # Array of Array[CardData]
var all_results: Array = []  # Array of Dictionary

var _primary_deck: Deck
var _extra_decks: Array[Deck] = []


func setup(p_variant: BaseVariant, p_num_hands: int) -> void:
	variant = p_variant
	num_hands = p_num_hands
	_primary_deck = Deck.new(p_variant.paytable.deck_size)
	_extra_decks.clear()
	for i in (num_hands - 1):
		_extra_decks.append(Deck.new(p_variant.paytable.deck_size))


func bet_one() -> void:
	if state != State.IDLE and state != State.WIN_DISPLAY:
		return
	if state == State.WIN_DISPLAY:
		_to_idle()
	bet = wrapi(bet, 1, MAX_BET + 1)
	if bet >= MAX_BET:
		bet = 1
	else:
		bet += 1
	SoundManager.play("bet")
	bet_changed.emit(bet)


func bet_max() -> void:
	if state != State.IDLE and state != State.WIN_DISPLAY:
		return
	if state == State.WIN_DISPLAY:
		_to_idle()
	bet = MAX_BET
	bet_changed.emit(bet)
	SoundManager.play("bet")
	deal()


func deal() -> void:
	if state == State.WIN_DISPLAY:
		_to_idle()
	if state != State.IDLE:
		return

	# Deduct bet × num_hands
	var cost := bet * num_hands * SaveManager.denomination
	if not SaveManager.deduct_credits(cost):
		return
	credits_changed.emit(SaveManager.credits)

	# Deal primary hand
	primary_hand = _primary_deck.deal_hand()
	held = [false, false, false, false, false]
	all_hands.clear()
	all_results.clear()

	state = State.DEALING
	state_changed.emit(state)
	all_hands_dealt.emit([primary_hand])


func on_deal_animation_complete() -> void:
	var hand_rank := variant.evaluate(primary_hand)
	if hand_rank != HandEvaluator.HandRank.NOTHING:
		held = HandEvaluator.get_hold_mask(primary_hand, hand_rank)
	state = State.HOLDING
	state_changed.emit(state)


func toggle_hold(index: int) -> void:
	if state != State.HOLDING:
		return
	held[index] = not held[index]
	SoundManager.play("hold")


func draw() -> void:
	if state != State.HOLDING:
		return
	state = State.DRAWING
	state_changed.emit(state)

	# Draw primary hand
	primary_hand = variant.draw(primary_hand, held)
	all_hands = [primary_hand]

	# Draw extra hands — each from its own deck
	for extra_deck in _extra_decks:
		var extra_hand := extra_deck.deal_multihand_replacements(
			all_hands[0],  # uses the ORIGINAL primary hand before draw
			held
		)
		all_hands.append(extra_hand)


func on_draw_animation_complete() -> void:
	_evaluate_all()


func _evaluate_all() -> void:
	state = State.EVALUATING
	state_changed.emit(state)

	all_results.clear()
	var total_payout: int = 0

	for hand_cards in all_hands:
		var hand_rank := variant.evaluate(hand_cards)
		var payout := variant.get_payout(hand_rank, bet) * SaveManager.denomination
		var hand_name := variant.get_hand_name(hand_rank)
		all_results.append({
			"hand_rank": hand_rank,
			"hand_name": hand_name,
			"payout": payout,
		})
		total_payout += payout

	if total_payout > 0:
		SaveManager.add_credits(total_payout)
		credits_changed.emit(SaveManager.credits)
		SoundManager.play("win_big" if total_payout >= bet * num_hands * SaveManager.denomination * 5 else "win_small")
	else:
		SoundManager.play("lose")

	if SaveManager.credits <= 0:
		SaveManager.credits = SaveManager.DEFAULT_CREDITS
		SaveManager.save_game()
		credits_changed.emit(SaveManager.credits)

	all_hands_evaluated.emit(all_results)
	state = State.WIN_DISPLAY
	state_changed.emit(state)


func _to_idle() -> void:
	state = State.IDLE
	state_changed.emit(state)


func deal_or_draw() -> void:
	match state:
		State.IDLE: deal()
		State.HOLDING: draw()
		State.WIN_DISPLAY: deal()
```

**Important fix:** The extra hands need the ORIGINAL primary hand (before draw) for held cards. Store it before drawing:

In `draw()`, change to:
```gdscript
func draw() -> void:
	if state != State.HOLDING:
		return
	state = State.DRAWING
	state_changed.emit(state)

	# Save original hand for extra hands (held cards come from here)
	var original_hand := primary_hand.duplicate()

	# Draw primary hand
	primary_hand = variant.draw(primary_hand, held)
	all_hands = [primary_hand]

	# Draw extra hands from independent decks
	for extra_deck in _extra_decks:
		var extra_hand := extra_deck.deal_multihand_replacements(original_hand, held)
		all_hands.append(extra_hand)
```

- [ ] **Step 2: Verify no parse errors**

- [ ] **Step 3: Commit**

---

## Task 3: Create MiniHandDisplay (visual for one small hand)

**Files:**
- Create: `scripts/mini_hand_display.gd`
- Create: `scenes/mini_hand.tscn`

- [ ] **Step 1: Create mini_hand_display.gd**

```gdscript
class_name MiniHandDisplay
extends HBoxContainer

## Displays 5 small card textures in a row for multi-hand view.

var _card_textures: Array[TextureRect] = []
var _result_label: Label
var _payout_label: Label

const SUIT_CODES := {
	CardData.Suit.HEARTS: "h", CardData.Suit.DIAMONDS: "d",
	CardData.Suit.CLUBS: "c", CardData.Suit.SPADES: "s",
}
const RANK_CODES := {
	CardData.Rank.TWO: "2", CardData.Rank.THREE: "3", CardData.Rank.FOUR: "4",
	CardData.Rank.FIVE: "5", CardData.Rank.SIX: "6", CardData.Rank.SEVEN: "7",
	CardData.Rank.EIGHT: "8", CardData.Rank.NINE: "9", CardData.Rank.TEN: "10",
	CardData.Rank.JACK: "j", CardData.Rank.QUEEN: "q", CardData.Rank.KING: "k",
	CardData.Rank.ACE: "a",
}


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 5:
		var tex := TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(28, 40)
		_card_textures.append(tex)
		add_child(tex)


func show_hand(hand: Array[CardData]) -> void:
	for i in 5:
		if i < hand.size():
			var path := _get_card_path(hand[i])
			if ResourceLoader.exists(path):
				_card_textures[i].texture = load(path)


func show_back() -> void:
	var back_tex := load("res://assets/cards/card_back.png")
	for tex in _card_textures:
		tex.texture = back_tex


func highlight_win(hand_name: String, payout: int) -> void:
	if payout > 0:
		modulate = Color(1.2, 1.2, 1.0)
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.7)


func _get_card_path(card: CardData) -> String:
	if card.is_joker():
		return "res://assets/cards/card_vp_joker_red.png"
	var r: String = RANK_CODES.get(card.rank, "")
	var s: String = SUIT_CODES.get(card.suit, "")
	return "res://assets/cards/card_vp_%s%s.png" % [r, s]
```

- [ ] **Step 2: Create scenes/mini_hand.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/mini_hand_display.gd" id="1"]

[node name="MiniHand" type="HBoxContainer"]
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

---

## Task 4: Create MultiHandGame scene and script

**Files:**
- Create: `scenes/multi_hand_game.tscn`
- Create: `scripts/multi_hand_game.gd`

- [ ] **Step 1: Create multi_hand_game.tscn**

Scene tree:
```
MultiHandGame (Control, full rect)
├── Background (ColorRect, full rect, #000086)
├── TopSection (VBoxContainer, anchor top)
│   ├── TopBar (GameTitle, BackButton)
│   ├── PaytableMargin > PaytableDisplay
│   └── InfoBarMargin > InfoBar (Balance, LastWin)
├── BottomSection (VBoxContainer, anchor bottom)
│   ├── TotalBetLabel
│   ├── BottomBarMargin > BottomBar (Speed, BetOne, BetAmount, BetMax, Deal)
│   └── BottomPad
└── MiddleSection (VBoxContainer, dynamic anchors)
    ├── MiniHandsGrid (GridContainer) — N mini-hands
    └── PrimaryCardsContainer (HBoxContainer) — 5 main cards
```

This is similar to `game.tscn` but with MiniHandsGrid added above the primary cards.

- [ ] **Step 2: Create multi_hand_game.gd**

The script is similar to `game.gd` but uses `MultiHandManager` instead of `GameManager`, and manages N `MiniHandDisplay` instances.

Key differences from `game.gd`:
- `_multi_manager: MultiHandManager` instead of `_game_manager: GameManager`
- `_mini_hands: Array[MiniHandDisplay]` — created dynamically based on `num_hands`
- On deal: show cards back in all mini-hands
- On draw: show results in each mini-hand, highlight winners
- Total payout = sum displayed in win overlay
- Grid columns adapt: 3 hands = 3×1, 5 = 5×1, 10 = 5×2, 12 = 4×3, 25 = 5×5

- [ ] **Step 3: Commit**

---

## Task 5: Wire lobby sidebar to select hand count

**Files:**
- Modify: `scripts/lobby_manager.gd`
- Modify: `scripts/main.gd`
- Modify: `scripts/save_manager.gd`

- [ ] **Step 1: Add hand_count to SaveManager**

In `scripts/save_manager.gd`, add:
```gdscript
var hand_count: int = 1  # 1=single, 3=triple, 5=five, 10=ten, 12=twelve, 25=twenty-five
```
Save/load it alongside other settings.

- [ ] **Step 2: Update lobby sidebar buttons to set hand_count**

In `scripts/lobby_manager.gd`, change `PLAY_MODES` to include hand counts:
```gdscript
const PLAY_MODES := [
	{"label": "SINGLE PLAY", "hands": 1},
	{"label": "TRIPLE PLAY", "hands": 3},
	{"label": "FIVE PLAY", "hands": 5},
	{"label": "TEN PLAY", "hands": 10},
]
```

Wire button presses to set `SaveManager.hand_count` and update active highlight.

- [ ] **Step 3: Update lobby signal to pass hand_count**

Change `machine_selected` signal to include hand_count:
```gdscript
signal machine_selected(variant_id: String)
```
Keep signal same — `main.gd` reads `SaveManager.hand_count` directly.

- [ ] **Step 4: Update main.gd to load correct game scene**

```gdscript
func _on_machine_selected(variant_id: String) -> void:
	_clear_current()
	var paytable: Paytable = _paytables[variant_id]
	var variant := _create_variant(variant_id, paytable)
	var hand_count := SaveManager.hand_count

	if hand_count <= 1:
		var game: Control = GameScene.instantiate()
		game.setup(variant)
		add_child(game)
		_make_full_rect(game)
		_current_scene = game
		game.back_to_lobby.connect(_show_lobby)
	else:
		var multi_game: Control = load("res://scenes/multi_hand_game.tscn").instantiate()
		multi_game.setup(variant, hand_count)
		add_child(multi_game)
		_make_full_rect(multi_game)
		_current_scene = multi_game
		multi_game.back_to_lobby.connect(_show_lobby)
```

- [ ] **Step 5: Commit**

---

## Task 6: Layout mini-hands grid dynamically

**Files:**
- Modify: `scripts/multi_hand_game.gd`

- [ ] **Step 1: Calculate grid layout based on hand_count**

```gdscript
func _get_grid_columns(n: int) -> int:
	match n:
		3: return 3
		5: return 5
		10: return 5
		12: return 4
		25: return 5
		_: return 5
```

- [ ] **Step 2: Create mini-hand instances**

```gdscript
func _create_mini_hands() -> void:
	var MiniHandScene := load("res://scenes/mini_hand.tscn")
	_mini_hands_grid.columns = _get_grid_columns(_num_hands - 1)
	# Create N-1 mini-hands (primary hand is shown separately)
	for i in (_num_hands - 1):
		var mini := MiniHandScene.instantiate() as MiniHandDisplay
		_mini_hands_grid.add_child(mini)
		_mini_hands.append(mini)
		mini.show_back()
```

- [ ] **Step 3: On draw complete, update all mini-hands**

```gdscript
func _on_all_hands_evaluated(results: Array) -> void:
	var total_payout: int = 0
	# Primary hand (index 0) handled by main card visuals
	for i in range(1, results.size()):
		var r: Dictionary = results[i]
		_mini_hands[i - 1].show_hand(_multi_manager.all_hands[i])
		_mini_hands[i - 1].highlight_win(r["hand_name"], r["payout"])
		total_payout += int(r["payout"])
	# Add primary hand payout
	total_payout += int(results[0]["payout"])
	# Show total
	_set_win_active(total_payout)
	if total_payout > 0:
		_show_win_overlay("TOTAL WIN: $%s" % _format_number(total_payout))
	else:
		_show_lose_overlay()
```

- [ ] **Step 4: Commit**

---

## Task 7: Adapt mini-hand card sizes for different hand counts

**Files:**
- Modify: `scripts/mini_hand_display.gd`
- Modify: `scripts/multi_hand_game.gd`

- [ ] **Step 1: Scale mini-hand card sizes based on total hands**

```gdscript
# In multi_hand_game.gd
func _size_mini_cards() -> void:
	# Fewer hands = bigger mini-cards
	var card_w: int
	var card_h: int
	match _num_hands:
		3: card_w = 50; card_h = 70
		5: card_w = 36; card_h = 50
		10: card_w = 28; card_h = 40
		12: card_w = 24; card_h = 34
		25: card_w = 18; card_h = 26
		_: card_w = 28; card_h = 40
	for mini in _mini_hands:
		mini.set_card_size(card_w, card_h)
```

```gdscript
# In mini_hand_display.gd
func set_card_size(w: int, h: int) -> void:
	for tex in _card_textures:
		tex.custom_minimum_size = Vector2(w, h)
```

- [ ] **Step 2: Adjust grid separation based on count**

```gdscript
func _size_grid() -> void:
	var sep: int = 8 if _num_hands <= 5 else 4 if _num_hands <= 12 else 2
	_mini_hands_grid.add_theme_constant_override("h_separation", sep)
	_mini_hands_grid.add_theme_constant_override("v_separation", sep)
```

- [ ] **Step 3: Commit**

---

## Task 8: TOTAL BET display for multi-hand

**Files:**
- Modify: `scripts/multi_hand_game.gd`

- [ ] **Step 1: Update total bet to show bet × num_hands**

```gdscript
func _update_bet_display(bet: int) -> void:
	var total: int = bet * _num_hands * SaveManager.denomination
	_total_bet_label.text = "TOTAL BET: $%s (%d hands)" % [_format_number(total), _num_hands]
```

- [ ] **Step 2: Commit**

---

## Task 9: Enable all sidebar modes (remove disabled state)

**Files:**
- Modify: `scripts/lobby_manager.gd`

- [ ] **Step 1: Make all sidebar buttons functional**

Remove `btn.disabled = true` and `btn.modulate.a = 0.5` for non-SINGLE modes. Wire each button to update `SaveManager.hand_count` and refresh highlight.

```gdscript
btn.pressed.connect(func() -> void:
	_active_mode = i
	SaveManager.hand_count = PLAY_MODES[i]["hands"]
	SaveManager.save_game()
	_refresh_sidebar()
)
```

Add `_refresh_sidebar()` that re-styles all buttons based on `_active_mode`.

- [ ] **Step 2: Add 12-hand and 25-hand modes**

```gdscript
const PLAY_MODES := [
	{"label": "SINGLE PLAY", "hands": 1},
	{"label": "TRIPLE PLAY", "hands": 3},
	{"label": "FIVE PLAY", "hands": 5},
	{"label": "TEN PLAY", "hands": 10},
	{"label": "12 PLAY", "hands": 12},
	{"label": "25 PLAY", "hands": 25},
]
```

- [ ] **Step 3: Commit**

---

## Task 10: Integration test — full multi-hand game loop

- [ ] **Step 1: Test TRIPLE PLAY (3 hands)**

1. In lobby, select TRIPLE PLAY in sidebar
2. Tap any machine
3. Verify: game loads with 2 mini-hands above primary hand
4. Deal → 5 cards appear in primary hand + 2 mini-hands show card backs
5. Hold cards → Draw → all 3 hands get results
6. Total win = sum of all 3 hands
7. Verify credits deducted = bet × 3

- [ ] **Step 2: Test TEN PLAY (10 hands)**

Same flow but with 9 mini-hands in 5×2 grid.

- [ ] **Step 3: Test 25 PLAY**

Same flow, 24 mini-hands in 5×5 grid. Cards should be tiny but visible.

- [ ] **Step 4: Commit any fixes**

---

## Summary

| Task | Description | Files |
|---|---|---|
| 1 | Deck multi-hand draw | `deck.gd` |
| 2 | MultiHandManager | `multi_hand_manager.gd` |
| 3 | MiniHandDisplay | `mini_hand_display.gd`, `mini_hand.tscn` |
| 4 | MultiHandGame scene/script | `multi_hand_game.tscn`, `multi_hand_game.gd` |
| 5 | Lobby → main wiring | `lobby_manager.gd`, `main.gd`, `save_manager.gd` |
| 6 | Dynamic grid layout | `multi_hand_game.gd` |
| 7 | Adaptive card sizes | `mini_hand_display.gd`, `multi_hand_game.gd` |
| 8 | Total bet display | `multi_hand_game.gd` |
| 9 | Enable all modes | `lobby_manager.gd` |
| 10 | Integration test | — |
