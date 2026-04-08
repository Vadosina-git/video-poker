class_name Deck
extends RefCounted

var _cards: Array[CardData] = []
var _draw_index: int = 0


func _init(deck_size: int = 52) -> void:
	_build(deck_size)


func _build(deck_size: int) -> void:
	_cards.clear()
	for suit_val in CardData.Suit.values():
		for rank_val in CardData.Rank.values():
			_cards.append(CardData.new(suit_val, rank_val))


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
