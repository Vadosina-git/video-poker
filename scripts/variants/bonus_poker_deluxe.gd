class_name BonusPokerDeluxe
extends BaseVariant

var _last_hand: Array[CardData] = []


func _init(p_paytable: Paytable) -> void:
	super._init("bonus_poker_deluxe", p_paytable)


func evaluate(hand: Array[CardData]) -> HandEvaluator.HandRank:
	_last_hand = hand
	return HandEvaluator.evaluate(hand)


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	return paytable.get_payout(hand_rank, bet)
