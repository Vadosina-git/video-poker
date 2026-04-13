class_name MultiHandManager
extends Node

signal all_hands_dealt(primary_hand: Array[CardData])
signal all_hands_drawn(all_hands: Array)
signal all_hands_evaluated(results: Array, total_payout: int)
signal credits_changed(new_credits: int)
signal bet_changed(new_bet: int)
signal state_changed(new_state: int)

enum State { IDLE, DEALING, HOLDING, DRAWING, EVALUATING, WIN_DISPLAY }

const MAX_BET := 5

var state: State = State.IDLE
var variant: BaseVariant
var num_hands: int = 3
var bet: int = 1
var ultra_vp: bool = false

var primary_hand: Array[CardData] = []
var held: Array[bool] = [false, false, false, false, false]
var all_hands: Array = []
var all_results: Array = []
# Ultra VP: multiplier for each hand (index 0 = primary, 1+ = extras)
var hand_multipliers: Array[int] = []  # Active multipliers applied this round
var next_multipliers: Array[int] = []   # Earned from last round, shown as "NEXT"

var _extra_decks: Array[Deck] = []


func setup(p_variant: BaseVariant, p_num_hands: int, p_ultra_vp: bool = false) -> void:
	variant = p_variant
	num_hands = p_num_hands
	ultra_vp = p_ultra_vp
	bet = clampi(SaveManager.bet_level, 1, MAX_BET)
	_extra_decks.clear()
	for i in (num_hands - 1):
		_extra_decks.append(Deck.new(p_variant.paytable.deck_size))
	# Initialize all multipliers to 1
	hand_multipliers.clear()
	next_multipliers.clear()
	for i in num_hands:
		hand_multipliers.append(1)
		next_multipliers.append(1)


## Ultra VP multiplier table based on hand rank
static func get_ultra_vp_multiplier(hand_rank: HandEvaluator.HandRank) -> int:
	match hand_rank:
		HandEvaluator.HandRank.JACKS_OR_BETTER: return 2
		HandEvaluator.HandRank.TWO_PAIR: return 3
		HandEvaluator.HandRank.THREE_OF_A_KIND: return 4
		HandEvaluator.HandRank.STRAIGHT: return 5
		HandEvaluator.HandRank.FLUSH: return 6
		HandEvaluator.HandRank.FULL_HOUSE: return 8
		HandEvaluator.HandRank.FOUR_OF_A_KIND: return 10
		HandEvaluator.HandRank.STRAIGHT_FLUSH: return 12
		HandEvaluator.HandRank.ROYAL_FLUSH: return 12
		_: return 1


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
	SaveManager.bet_level = bet
	SaveManager.save_game()
	bet_changed.emit(bet)


func bet_max() -> void:
	if state != State.IDLE and state != State.WIN_DISPLAY:
		return
	if state == State.WIN_DISPLAY:
		_to_idle()
	bet = MAX_BET
	SaveManager.bet_level = bet
	SaveManager.save_game()
	bet_changed.emit(bet)
	SoundManager.play("bet")
	deal()


func deal() -> void:
	if state == State.WIN_DISPLAY:
		_to_idle()
	if state != State.IDLE:
		return

	var ux_active: bool = ultra_vp and bet == MAX_BET
	var bet_multiplier := 2 if ux_active else 1
	var cost: int = bet * num_hands * SaveManager.denomination * bet_multiplier
	if not SaveManager.deduct_credits(cost):
		return
	credits_changed.emit(SaveManager.credits)

	# Ultra VP: activate next_multipliers for this round (only at MAX BET)
	if ux_active:
		hand_multipliers = next_multipliers.duplicate()
	else:
		# Reset all multipliers to 1 when not at max bet
		hand_multipliers.clear()
		for i in num_hands:
			hand_multipliers.append(1)
	next_multipliers.clear()
	for i in num_hands:
		next_multipliers.append(1)

	primary_hand = variant.deal()
	held = [false, false, false, false, false]
	all_hands.clear()
	all_results.clear()

	state = State.DEALING
	state_changed.emit(state)
	all_hands_dealt.emit(primary_hand)


func on_deal_animation_complete() -> void:
	var hand_rank := variant.evaluate(primary_hand)
	if hand_rank != HandEvaluator.HandRank.NOTHING:
		held = variant.get_hold_mask(primary_hand, hand_rank)
	# Always auto-hold wild cards
	for i in 5:
		if variant.is_wild_card(primary_hand[i]):
			held[i] = true
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

	# Save original for extra hands
	var original_hand := primary_hand.duplicate()

	# Draw primary
	primary_hand = variant.draw(primary_hand, held)
	all_hands = [primary_hand]

	# Draw extra hands from independent decks
	for extra_deck in _extra_decks:
		var extra_hand := extra_deck.deal_multihand_replacements(original_hand, held)
		all_hands.append(extra_hand)

	all_hands_drawn.emit(all_hands)


func on_draw_animation_complete() -> void:
	_evaluate_all()


func _evaluate_all() -> void:
	state = State.EVALUATING
	state_changed.emit(state)

	all_results.clear()
	var total_payout: int = 0
	var ux_active: bool = ultra_vp and bet == MAX_BET
	# Earned multipliers for next round
	var earned_multipliers: Array[int] = []

	for i in all_hands.size():
		var hand_cards: Array = all_hands[i]
		var hand_rank := variant.evaluate(hand_cards)
		var base_payout: int = variant.get_payout(hand_rank, bet) * SaveManager.denomination
		var mult: int = hand_multipliers[i] if i < hand_multipliers.size() and ux_active else 1
		var payout: int = base_payout * mult
		var hand_name: String = variant.get_hand_name(hand_rank)
		all_results.append({
			"hand_rank": hand_rank,
			"hand_name": hand_name,
			"payout": payout,
			"base_payout": base_payout,
			"multiplier": mult,
		})
		total_payout += payout
		# Calculate earned multiplier for next round (only at MAX BET)
		if ux_active:
			earned_multipliers.append(get_ultra_vp_multiplier(hand_rank))

	# Store earned multipliers as next_multipliers (to be activated on next deal)
	if ux_active:
		next_multipliers = earned_multipliers

	if total_payout > 0:
		SaveManager.add_credits(total_payout)
		credits_changed.emit(SaveManager.credits)
		if total_payout >= bet * num_hands * SaveManager.denomination * 5:
			SoundManager.play("win_big")
		else:
			SoundManager.play("win_small")
	else:
		SoundManager.play("lose")

	if SaveManager.credits <= 0:
		SaveManager.credits = SaveManager.DEFAULT_CREDITS
		SaveManager.save_game()
		credits_changed.emit(SaveManager.credits)

	all_hands_evaluated.emit(all_results, total_payout)
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
