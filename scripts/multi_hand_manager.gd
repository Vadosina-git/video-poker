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

var primary_hand: Array[CardData] = []
var held: Array[bool] = [false, false, false, false, false]
var all_hands: Array = []
var all_results: Array = []

var _extra_decks: Array[Deck] = []


func setup(p_variant: BaseVariant, p_num_hands: int) -> void:
	variant = p_variant
	num_hands = p_num_hands
	bet = clampi(SaveManager.bet_level, 1, MAX_BET)
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

	var cost: int = bet * num_hands * SaveManager.denomination
	if not SaveManager.deduct_credits(cost):
		return
	credits_changed.emit(SaveManager.credits)

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

	for hand_cards in all_hands:
		var hand_rank := variant.evaluate(hand_cards)
		var payout: int = variant.get_payout(hand_rank, bet) * SaveManager.denomination
		var hand_name: String = variant.get_hand_name(hand_rank)
		all_results.append({
			"hand_rank": hand_rank,
			"hand_name": hand_name,
			"payout": payout,
		})
		total_payout += payout

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
