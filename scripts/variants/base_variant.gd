class_name BaseVariant
extends RefCounted

var variant_id: String
var paytable: Paytable
var deck: Deck


func _init(p_variant_id: String, p_paytable: Paytable) -> void:
	variant_id = p_variant_id
	paytable = p_paytable
	deck = Deck.new(p_paytable.deck_size)


func deal() -> Array[CardData]:
	return deck.deal_hand()


func draw(hand: Array[CardData], held: Array[bool]) -> Array[CardData]:
	var new_hand: Array[CardData] = []
	for i in 5:
		if held[i]:
			new_hand.append(hand[i])
		else:
			new_hand.append(deck.get_replacement(i))
	return new_hand


func evaluate(hand: Array[CardData]) -> HandEvaluator.HandRank:
	return HandEvaluator.evaluate(hand)


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	return paytable.get_payout(hand_rank, bet)


func get_hand_name(hand_rank: HandEvaluator.HandRank) -> String:
	return HandEvaluator.HAND_NAMES.get(hand_rank, "")
