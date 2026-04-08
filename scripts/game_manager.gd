class_name GameManager
extends Node

signal state_changed(new_state: int)
signal cards_dealt(hand: Array[CardData])
signal card_replaced(index: int, new_card: CardData)
signal hand_evaluated(hand_rank: int, hand_name: String, payout: int)
signal credits_changed(new_credits: int)
signal bet_changed(new_bet: int)

enum State {
	IDLE,
	DEALING,
	HOLDING,
	DRAWING,
	EVALUATING,
	WIN_DISPLAY,
}

const MAX_BET := 5

var state: State = State.IDLE
var variant: BaseVariant
var hand: Array[CardData] = []
var held: Array[bool] = [false, false, false, false, false]
var bet: int = 1
var last_win: int = 0


func setup(p_variant: BaseVariant) -> void:
	variant = p_variant


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

	var cost := bet * SaveManager.denomination
	if not SaveManager.deduct_credits(cost):
		return

	credits_changed.emit(SaveManager.credits)
	last_win = 0

	hand = variant.deal()
	held = [false, false, false, false, false]

	state = State.DEALING
	state_changed.emit(state)
	cards_dealt.emit(hand)


func on_deal_animation_complete() -> void:
	# Auto-hold all cards if dealt hand is already a winning combination
	var hand_rank := variant.evaluate(hand)
	if hand_rank != HandEvaluator.HandRank.NOTHING:
		held = [true, true, true, true, true]

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

	hand = variant.draw(hand, held)

	for i in 5:
		if not held[i]:
			card_replaced.emit(i, hand[i])


func on_draw_animation_complete() -> void:
	_evaluate()


func _evaluate() -> void:
	state = State.EVALUATING
	state_changed.emit(state)

	var hand_rank := variant.evaluate(hand)
	var payout := variant.get_payout(hand_rank, bet) * SaveManager.denomination
	var hand_name := variant.get_hand_name(hand_rank)

	last_win = payout
	if payout > 0:
		SaveManager.add_credits(payout)
		credits_changed.emit(SaveManager.credits)
		if hand_rank == HandEvaluator.HandRank.ROYAL_FLUSH:
			SoundManager.play("win_royal")
		elif payout >= bet * SaveManager.denomination * 10:
			SoundManager.play("win_big")
		else:
			SoundManager.play("win_small")
	else:
		SoundManager.play("lose")

	# Reset credits if broke
	if SaveManager.credits <= 0:
		SaveManager.credits = SaveManager.DEFAULT_CREDITS
		SaveManager.save_game()
		credits_changed.emit(SaveManager.credits)

	hand_evaluated.emit(hand_rank, hand_name, payout)

	state = State.WIN_DISPLAY
	state_changed.emit(state)


func _to_idle() -> void:
	state = State.IDLE
	last_win = 0
	state_changed.emit(state)


func deal_or_draw() -> void:
	match state:
		State.IDLE:
			deal()
		State.HOLDING:
			draw()
		State.WIN_DISPLAY:
			deal()
