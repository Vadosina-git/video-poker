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
	## Localized display name for the last evaluated hand. Resolves through
	## Paytable.get_hand_display_name (which itself goes through Translations)
	## using the variant-specific paytable key. Variants no longer need to
	## override this — they only override `get_paytable_key`.
	var key := get_paytable_key(hand_rank)
	if key == "":
		return HandEvaluator.HAND_NAMES.get(hand_rank, "")
	return paytable.get_hand_display_name(key)


## Returns the paytable key for the last evaluated hand.
## Override in wild variants that use custom keys (e.g. "wild_royal_flush").
func get_paytable_key(hand_rank: HandEvaluator.HandRank) -> String:
	return Paytable.STANDARD_HAND_KEYS.get(hand_rank, "")


## Returns true if the given card is a wild card in this variant.
## Override in wild variants (Deuces Wild, Joker Poker, etc.).
func is_wild_card(card: CardData) -> bool:
	return false


## Returns which cards to auto-hold for the given hand and rank.
## Override in wild variants to include wild cards in the hold mask.
func get_hold_mask(hand: Array[CardData], hand_rank: HandEvaluator.HandRank) -> Array[bool]:
	return HandEvaluator.get_hold_mask(hand, hand_rank)
