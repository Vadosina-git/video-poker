class_name DeucesWild
extends BaseVariant

var _last_hand: Array[CardData] = []
var _last_hand_key: String = ""


func _init(p_paytable: Paytable) -> void:
	super._init("deuces_wild", p_paytable)


func evaluate(hand: Array[CardData]) -> HandEvaluator.HandRank:
	_last_hand = hand
	_last_hand_key = _evaluate_wild(hand)
	match _last_hand_key:
		"natural_royal_flush":
			return HandEvaluator.HandRank.ROYAL_FLUSH
		"four_deuces":
			return HandEvaluator.HandRank.FOUR_OF_A_KIND
		"wild_royal_flush":
			return HandEvaluator.HandRank.ROYAL_FLUSH
		"five_of_a_kind":
			return HandEvaluator.HandRank.FOUR_OF_A_KIND
		"straight_flush":
			return HandEvaluator.HandRank.STRAIGHT_FLUSH
		"four_of_a_kind":
			return HandEvaluator.HandRank.FOUR_OF_A_KIND
		"full_house":
			return HandEvaluator.HandRank.FULL_HOUSE
		"flush":
			return HandEvaluator.HandRank.FLUSH
		"straight":
			return HandEvaluator.HandRank.STRAIGHT
		"three_of_a_kind":
			return HandEvaluator.HandRank.THREE_OF_A_KIND
	return HandEvaluator.HandRank.NOTHING


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	return _lookup_payout(_last_hand_key, bet)


func get_paytable_key(hand_rank: HandEvaluator.HandRank) -> String:
	return _last_hand_key


func is_wild_card(card: CardData) -> bool:
	return card.rank == CardData.Rank.TWO


func get_hold_mask(hand: Array[CardData], hand_rank: HandEvaluator.HandRank) -> Array[bool]:
	if hand_rank == HandEvaluator.HandRank.NOTHING:
		return [false, false, false, false, false]
	# For pat hands (straight, flush, full house, straight flush, royal), hold all
	if hand_rank in [HandEvaluator.HandRank.ROYAL_FLUSH, HandEvaluator.HandRank.STRAIGHT_FLUSH,
			HandEvaluator.HandRank.STRAIGHT, HandEvaluator.HandRank.FLUSH,
			HandEvaluator.HandRank.FULL_HOUSE]:
		return [true, true, true, true, true]
	# For rank-based hands, hold wilds + cards contributing to the combination
	var mask: Array[bool] = [false, false, false, false, false]
	var counts := {}
	for i in 5:
		if not is_wild_card(hand[i]):
			var r := hand[i].rank as int
			counts[r] = counts.get(r, 0) + 1
	# Find the most frequent non-wild rank
	var best_rank: int = -1
	var best_count: int = 0
	for r in counts:
		if counts[r] > best_count:
			best_count = counts[r]
			best_rank = r
	for i in 5:
		if is_wild_card(hand[i]):
			mask[i] = true
		elif hand[i].rank as int == best_rank:
			mask[i] = true
	return mask


func _evaluate_wild(hand: Array[CardData]) -> String:
	var wilds: int = 0
	var non_wild_ranks: Array[int] = []
	var non_wild_suits: Array[int] = []
	for card in hand:
		if card.rank == CardData.Rank.TWO:
			wilds += 1
		else:
			non_wild_ranks.append(card.rank as int)
			non_wild_suits.append(card.suit as int)
	non_wild_ranks.sort()

	# Four deuces is a special top-tier hand
	if wilds == 4:
		return "four_deuces"

	# Count rank occurrences among non-wild cards
	var counts := _count_ranks(non_wild_ranks)
	var max_count: int = 0
	for c in counts.values():
		if c > max_count:
			max_count = c

	# Five of a kind: max matching rank + wilds >= 5
	if max_count + wilds >= 5:
		return "five_of_a_kind"

	# Check if all non-wild cards share the same suit
	var all_same_suit := true
	if non_wild_suits.size() > 1:
		for i in range(1, non_wild_suits.size()):
			if non_wild_suits[i] != non_wild_suits[0]:
				all_same_suit = false
				break

	# Check if a straight is possible with wilds filling gaps
	var is_straight_possible := _can_make_straight(non_wild_ranks, wilds)

	# Royal flush: all same suit, straight possible, all non-wild ranks >= 10
	if all_same_suit and is_straight_possible:
		var has_high := true
		for r in non_wild_ranks:
			if r < CardData.Rank.TEN:
				has_high = false
				break
		if has_high and non_wild_ranks.size() > 0:
			if wilds == 0:
				return "natural_royal_flush"
			else:
				return "wild_royal_flush"

	# Straight flush: all same suit and straight possible
	if all_same_suit and is_straight_possible:
		return "straight_flush"

	# Four of a kind
	if max_count + wilds >= 4:
		return "four_of_a_kind"

	# Full house: need groups totaling 5 (3 + 2)
	var sorted_counts: Array = counts.values()
	sorted_counts.sort()
	sorted_counts.reverse()
	if sorted_counts.size() >= 2:
		if sorted_counts[0] + sorted_counts[1] + wilds >= 5:
			if sorted_counts[0] + wilds >= 3:
				return "full_house"

	if all_same_suit:
		return "flush"

	if is_straight_possible:
		return "straight"

	if max_count + wilds >= 3:
		return "three_of_a_kind"

	# No payout in Deuces Wild for less than three of a kind
	return ""


func _can_make_straight(sorted_ranks: Array[int], wilds: int) -> bool:
	if sorted_ranks.is_empty():
		return true  # All wilds can make any straight
	# Build list including ace-low (ace as 1)
	var all_ranks := sorted_ranks.duplicate()
	for r in sorted_ranks:
		if r == CardData.Rank.ACE:
			all_ranks.append(1)  # Ace as low
	all_ranks.sort()
	# Remove duplicates
	var unique: Array[int] = []
	for r in all_ranks:
		if unique.is_empty() or unique[-1] != r:
			unique.append(r)
	# Try each possible 5-card straight window
	for start in range(1, 11):  # 1 (ace-low) to 10 (10-A)
		var end := start + 4
		if end > 14:
			break
		var needed: int = 0
		for val in range(start, end + 1):
			if val not in unique:
				needed += 1
		if needed <= wilds:
			return true
	return false


func _count_ranks(ranks: Array[int]) -> Dictionary:
	var c := {}
	for r in ranks:
		c[r] = c.get(r, 0) + 1
	return c


func _lookup_payout(key: String, bet: int) -> int:
	if key == "":
		return 0
	var row: Array = paytable._payout_data.get(key, [])
	if row.is_empty():
		return 0
	return int(row[clampi(bet - 1, 0, 4)])
