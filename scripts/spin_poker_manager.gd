class_name SpinPokerManager
extends RefCounted

## FSM and game logic for Spin Poker (3×5 grid, 20 lines, one shared deck).

signal deal_spin_complete(middle_row: Array[CardData])
signal draw_spin_complete(grid: Array)
signal lines_evaluated(results: Array, total_payout: int)
signal credits_changed(new_credits: int)
signal bet_changed(new_bet: int)
signal state_changed(new_state: int)

enum State { IDLE, SPINNING, HOLDING, DRAW_SPINNING, EVALUATING, WIN_DISPLAY }

const NUM_LINES := 20
const MAX_BET := 5

# 20 line patterns: each array is [col0_row, col1_row, col2_row, col3_row, col4_row]
# Row 0=Top, 1=Middle, 2=Bottom
const LINES := [
	[1,1,1,1,1],  # 1  M-M-M-M-M  straight middle
	[0,0,0,0,0],  # 2  T-T-T-T-T  straight top
	[2,2,2,2,2],  # 3  B-B-B-B-B  straight bottom
	[0,1,2,1,0],  # 4  T-M-B-M-T  V-shape
	[2,1,0,1,2],  # 5  B-M-T-M-B  inverted V
	[0,0,1,2,2],  # 6  T-T-M-B-B  descending diagonal
	[2,2,1,0,0],  # 7  B-B-M-T-T  ascending diagonal
	[1,0,1,2,1],  # 8  M-T-M-B-M  zigzag up-down
	[1,2,1,0,1],  # 9  M-B-M-T-M  zigzag down-up
	[0,1,1,1,0],  # 10 T-M-M-M-T  shallow V
	[2,1,1,1,2],  # 11 B-M-M-M-B  shallow inverted V
	[1,1,0,1,1],  # 12 M-M-T-M-M  bump up center
	[1,1,2,1,1],  # 13 M-M-B-M-M  bump down center
	[0,0,2,0,0],  # 14 T-T-B-T-T  dip from top
	[2,2,0,2,2],  # 15 B-B-T-B-B  peak from bottom
	[0,1,0,1,0],  # 16 T-M-T-M-T  W-shape
	[2,1,2,1,2],  # 17 B-M-B-M-B  M-shape
	[1,0,0,0,1],  # 18 M-T-T-T-M  top plateau
	[1,2,2,2,1],  # 19 M-B-B-B-M  bottom plateau
	[0,2,0,2,0],  # 20 T-B-T-B-T  extreme zigzag
]

const LINE_COLORS := [
	Color("FF0000"),  # 1  Red
	Color("0055FF"),  # 2  Blue
	Color("000088"),  # 3  Dark Blue
	Color("FFAA77"),  # 4  Peach
	Color("FF88CC"),  # 5  Pink
	Color("FF8800"),  # 6  Orange
	Color("9933FF"),  # 7  Purple
	Color("00CC44"),  # 8  Green
	Color("FFDD00"),  # 9  Yellow
	Color("66FF66"),  # 10 Light Green
	Color("00CCCC"),  # 11 Teal
	Color("AAFF00"),  # 12 Lime
	Color("FF6666"),  # 13 Coral
	Color("00DDFF"),  # 14 Cyan
	Color("FF00FF"),  # 15 Magenta
	Color("FFD700"),  # 16 Gold
	Color("C0C0C0"),  # 17 Silver
	Color("88CCFF"),  # 18 Sky Blue
	Color("AA6633"),  # 19 Brown
	Color("FFFFFF"),  # 20 White
]

var state: State = State.IDLE
var variant: BaseVariant
var bet: int = 5  # coins per line (1-5)

# Grid: grid[row][col] — row 0=top, 1=mid, 2=bot
var grid: Array = [[], [], []]
var middle_row: Array[CardData] = []
var held: Array[bool] = [false, false, false, false, false]

var _draw_pool: Array[CardData] = []


func setup(p_variant: BaseVariant) -> void:
	variant = p_variant
	state = State.IDLE


func bet_one() -> void:
	if state != State.IDLE and state != State.WIN_DISPLAY:
		return
	if state == State.WIN_DISPLAY:
		_to_idle()
	bet = (bet % MAX_BET) + 1
	bet_changed.emit(bet)


func bet_max() -> void:
	if state != State.IDLE and state != State.WIN_DISPLAY:
		return
	if state == State.WIN_DISPLAY:
		_to_idle()
	bet = MAX_BET
	bet_changed.emit(bet)


func get_total_bet() -> int:
	return NUM_LINES * bet * SaveManager.denomination


func deal() -> void:
	if state != State.IDLE and state != State.WIN_DISPLAY:
		return
	if state == State.WIN_DISPLAY:
		_to_idle()

	var cost: int = get_total_bet()
	if not SaveManager.deduct_credits(cost):
		return
	credits_changed.emit(SaveManager.credits)

	# Shuffle and deal 5 cards for middle row
	variant.deck.shuffle()
	middle_row.clear()
	for i in 5:
		middle_row.append(variant.deck.get_card(i))
	held = [false, false, false, false, false]

	# Clear grid
	grid = [[], [], []]
	for row in 3:
		grid[row] = []
		for _col in 5:
			grid[row].append(null)
	# Middle row filled
	for col in 5:
		grid[1][col] = middle_row[col]

	state = State.SPINNING
	state_changed.emit(state)
	deal_spin_complete.emit(middle_row)


func on_deal_spin_complete() -> void:
	state = State.HOLDING
	state_changed.emit(state)


func toggle_hold(col: int) -> void:
	if state != State.HOLDING:
		return
	if col < 0 or col >= 5:
		return
	held[col] = not held[col]


func draw() -> void:
	if state != State.HOLDING:
		return

	# Build draw pool: remaining cards after the 5 dealt
	_draw_pool.clear()
	var deck_size: int = variant.deck.card_count()
	for i in range(5, deck_size):
		_draw_pool.append(variant.deck.get_card(i))
	# Shuffle draw pool
	_shuffle_pool()

	var draw_idx: int = 0

	# Fill grid column by column, left to right
	for col in 5:
		if held[col]:
			# Duplicate held card to all 3 rows
			grid[0][col] = middle_row[col]
			grid[1][col] = middle_row[col]
			grid[2][col] = middle_row[col]
		else:
			# 3 new cards from draw pool (top, mid, bot)
			for row in 3:
				if draw_idx < _draw_pool.size():
					grid[row][col] = _draw_pool[draw_idx]
					draw_idx += 1

	state = State.DRAW_SPINNING
	state_changed.emit(state)
	draw_spin_complete.emit(grid)


func on_draw_spin_complete() -> void:
	_evaluate_all()


func _evaluate_all() -> void:
	state = State.EVALUATING
	state_changed.emit(state)

	var results: Array = []
	var total_payout: int = 0

	for line_idx in NUM_LINES:
		var hand: Array[CardData] = []
		for col in 5:
			var row: int = LINES[line_idx][col]
			hand.append(grid[row][col])
		var hand_rank = variant.evaluate(hand)
		var payout: int = variant.get_payout(hand_rank, bet) * SaveManager.denomination
		var hand_name: String = variant.get_hand_name(hand_rank)
		results.append({
			"line_idx": line_idx,
			"hand_rank": hand_rank,
			"hand_name": hand_name,
			"payout": payout,
			"hand": hand,
		})
		total_payout += payout

	if total_payout > 0:
		SaveManager.add_credits(total_payout)
		credits_changed.emit(SaveManager.credits)
		SoundManager.play("win_small")
	else:
		SoundManager.play("lose")

	if SaveManager.credits <= 0:
		SaveManager.credits = SaveManager.DEFAULT_CREDITS
		SaveManager.save_game()
		credits_changed.emit(SaveManager.credits)

	lines_evaluated.emit(results, total_payout)
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


func _shuffle_pool() -> void:
	for i in range(_draw_pool.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: CardData = _draw_pool[i]
		_draw_pool[i] = _draw_pool[j]
		_draw_pool[j] = tmp
