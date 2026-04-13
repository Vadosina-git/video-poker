class_name TripleDoubleBonus
extends BaseVariant

var _last_hand: Array[CardData] = []


func _init(p_paytable: Paytable) -> void:
	super._init("triple_double_bonus", p_paytable)


func evaluate(hand: Array[CardData]) -> HandEvaluator.HandRank:
	_last_hand = hand
	return HandEvaluator.evaluate(hand)


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	if hand_rank == HandEvaluator.HandRank.FOUR_OF_A_KIND:
		var quad_rank := _get_quad_rank(_last_hand)
		var kicker_rank := _get_kicker_rank(_last_hand)

		if quad_rank == CardData.Rank.ACE:
			if _has_special_kicker(quad_rank, kicker_rank):
				return _lookup_payout("four_aces_with_234_kicker", bet)
			return _lookup_payout("four_aces", bet)

		if quad_rank >= CardData.Rank.TWO and quad_rank <= CardData.Rank.FOUR:
			if _has_special_kicker(quad_rank, kicker_rank):
				return _lookup_payout("four_234_with_a234_kicker", bet)
			return _lookup_payout("four_twos_threes_fours", bet)

		return _lookup_payout("four_fives_kings", bet)

	return super.get_payout(hand_rank, bet)


func get_paytable_key(hand_rank: HandEvaluator.HandRank) -> String:
	if hand_rank == HandEvaluator.HandRank.FOUR_OF_A_KIND:
		var quad_rank := _get_quad_rank(_last_hand)
		var kicker_rank := _get_kicker_rank(_last_hand)
		if quad_rank == CardData.Rank.ACE:
			if _has_special_kicker(quad_rank, kicker_rank):
				return "four_aces_with_234_kicker"
			return "four_aces"
		if quad_rank >= CardData.Rank.TWO and quad_rank <= CardData.Rank.FOUR:
			if _has_special_kicker(quad_rank, kicker_rank):
				return "four_234_with_a234_kicker"
			return "four_twos_threes_fours"
		return "four_fives_kings"
	return Paytable.STANDARD_HAND_KEYS.get(hand_rank, "")


func _get_quad_rank(hand: Array[CardData]) -> int:
	var counts := {}
	for card in hand:
		var r := card.rank as int
		counts[r] = counts.get(r, 0) + 1
	for r in counts:
		if counts[r] == 4:
			return r
	return 0


func _get_kicker_rank(hand: Array[CardData]) -> int:
	var quad_rank := _get_quad_rank(hand)
	for card in hand:
		if (card.rank as int) != quad_rank:
			return card.rank as int
	return 0


func _has_special_kicker(quad_rank: int, kicker_rank: int) -> bool:
	if quad_rank == CardData.Rank.ACE:
		return kicker_rank >= CardData.Rank.TWO and kicker_rank <= CardData.Rank.FOUR
	elif quad_rank >= CardData.Rank.TWO and quad_rank <= CardData.Rank.FOUR:
		return kicker_rank == CardData.Rank.ACE or (kicker_rank >= CardData.Rank.TWO and kicker_rank <= CardData.Rank.FOUR)
	return false


func _lookup_payout(key: String, bet: int) -> int:
	if key not in paytable._payout_data:
		return 0
	var payouts: Array = paytable._payout_data[key]
	var coin_index := clampi(bet - 1, 0, 4)
	return int(payouts[coin_index])
