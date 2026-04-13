class_name AcesAndFaces
extends BaseVariant

var _last_hand: Array[CardData] = []


func _init(p_paytable: Paytable) -> void:
	super._init("aces_and_faces", p_paytable)


func evaluate(hand: Array[CardData]) -> HandEvaluator.HandRank:
	_last_hand = hand
	return HandEvaluator.evaluate(hand)


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	if hand_rank == HandEvaluator.HandRank.FOUR_OF_A_KIND:
		var quad_rank := _get_quad_rank(_last_hand)
		var key := ""
		if quad_rank == CardData.Rank.ACE:
			key = "four_aces"
		elif quad_rank >= CardData.Rank.JACK and quad_rank <= CardData.Rank.KING:
			key = "four_jqk"
		else:
			key = "four_twos_tens"
		return _lookup_payout(key, bet)
	return paytable.get_payout(hand_rank, bet)


func get_paytable_key(hand_rank: HandEvaluator.HandRank) -> String:
	if hand_rank == HandEvaluator.HandRank.FOUR_OF_A_KIND:
		var quad_rank := _get_quad_rank(_last_hand)
		if quad_rank == CardData.Rank.ACE:
			return "four_aces"
		elif quad_rank >= CardData.Rank.JACK and quad_rank <= CardData.Rank.KING:
			return "four_jqk"
		return "four_twos_tens"
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


func _lookup_payout(key: String, bet: int) -> int:
	var row: Array = paytable._payout_data.get(key, [])
	if row.is_empty():
		return 0
	var idx := clampi(bet - 1, 0, 4)
	return int(row[idx])
