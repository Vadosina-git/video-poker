class_name HandEvaluator
extends RefCounted

enum HandRank {
	NOTHING,
	JACKS_OR_BETTER,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH,
}

const HAND_NAMES := {
	HandRank.NOTHING: "",
	HandRank.JACKS_OR_BETTER: "JACKS OR BETTER",
	HandRank.TWO_PAIR: "TWO PAIR",
	HandRank.THREE_OF_A_KIND: "THREE OF A KIND",
	HandRank.STRAIGHT: "STRAIGHT",
	HandRank.FLUSH: "FLUSH",
	HandRank.FULL_HOUSE: "FULL HOUSE",
	HandRank.FOUR_OF_A_KIND: "FOUR OF A KIND",
	HandRank.STRAIGHT_FLUSH: "STRAIGHT FLUSH",
	HandRank.ROYAL_FLUSH: "ROYAL FLUSH",
}


static func evaluate(hand: Array[CardData]) -> HandRank:
	var ranks: Array[int] = []
	var suits: Array[int] = []
	for card in hand:
		ranks.append(card.rank as int)
		suits.append(card.suit as int)
	ranks.sort()

	var is_flush := _check_flush(suits)
	var is_straight := _check_straight(ranks)
	var counts := _rank_counts(ranks)
	var count_values: Array[int] = []
	for v in counts.values():
		count_values.append(v)
	count_values.sort()

	if is_flush and is_straight:
		if ranks[0] == CardData.Rank.TEN and ranks[4] == CardData.Rank.ACE:
			return HandRank.ROYAL_FLUSH
		return HandRank.STRAIGHT_FLUSH

	if 4 in count_values:
		return HandRank.FOUR_OF_A_KIND

	if count_values == [2, 3]:
		return HandRank.FULL_HOUSE

	if is_flush:
		return HandRank.FLUSH

	if is_straight:
		return HandRank.STRAIGHT

	if 3 in count_values:
		return HandRank.THREE_OF_A_KIND

	var pair_count := count_values.count(2)
	if pair_count == 2:
		return HandRank.TWO_PAIR

	if pair_count == 1:
		for rank_key in counts:
			if counts[rank_key] == 2 and rank_key >= CardData.Rank.JACK:
				return HandRank.JACKS_OR_BETTER
		return HandRank.NOTHING

	return HandRank.NOTHING


static func _check_flush(suits: Array[int]) -> bool:
	for i in range(1, suits.size()):
		if suits[i] != suits[0]:
			return false
	return true


static func _check_straight(sorted_ranks: Array[int]) -> bool:
	if sorted_ranks == [2, 3, 4, 5, 14]:
		return true
	for i in range(1, 5):
		if sorted_ranks[i] != sorted_ranks[i - 1] + 1:
			return false
	return true


static func _rank_counts(ranks: Array[int]) -> Dictionary:
	var counts := {}
	for rank in ranks:
		counts[rank] = counts.get(rank, 0) + 1
	return counts
