class_name Deck
extends RefCounted

var _cards: Array[CardData] = []
var _draw_index: int = 0


func _init(deck_size: int = 52) -> void:
	_build(deck_size)


func _build(deck_size: int) -> void:
	_cards.clear()
	# Standard 52 cards (skip JOKER_SUIT and JOKER rank)
	for suit_val in [CardData.Suit.HEARTS, CardData.Suit.DIAMONDS, CardData.Suit.CLUBS, CardData.Suit.SPADES]:
		for rank_val in CardData.Rank.values():
			if rank_val == CardData.Rank.JOKER:
				continue
			_cards.append(CardData.new(suit_val, rank_val))
	# Add Joker for 53-card decks
	if deck_size >= 53:
		_cards.append(CardData.new(CardData.Suit.JOKER_SUIT, CardData.Rank.JOKER))


func shuffle() -> void:
	for i in range(_cards.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var temp := _cards[i]
		_cards[i] = _cards[j]
		_cards[j] = temp
	_draw_index = 0


func deal_hand() -> Array[CardData]:
	shuffle()
	_draw_index = 5
	var hand: Array[CardData] = []
	for i in 5:
		hand.append(_cards[i])
	return hand


func get_replacement(position: int) -> CardData:
	return _cards[5 + position]


func get_card(index: int) -> CardData:
	return _cards[index]


func card_count() -> int:
	return _cards.size()


## For multi-hand: shuffle this deck independently, then build a 5-card hand
## where held positions keep cards from primary_hand, and non-held positions
## get unique cards from this deck (skipping any card that matches a held card).
func deal_multihand_replacements(primary_hand: Array[CardData], held: Array[bool]) -> Array[CardData]:
	shuffle()
	var result: Array[CardData] = []
	var draw_idx: int = 0
	for i in 5:
		if held[i]:
			result.append(primary_hand[i])
		else:
			while draw_idx < _cards.size():
				var card := _cards[draw_idx]
				draw_idx += 1
				var is_held_card := false
				for j in 5:
					if held[j] and primary_hand[j].index == card.index:
						is_held_card = true
						break
				if not is_held_card:
					result.append(card)
					break
	return result
