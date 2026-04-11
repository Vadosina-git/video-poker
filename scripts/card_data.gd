class_name CardData
extends RefCounted

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES, JOKER_SUIT }
enum Rank {
	TWO = 2, THREE = 3, FOUR = 4, FIVE = 5, SIX = 6,
	SEVEN = 7, EIGHT = 8, NINE = 9, TEN = 10,
	JACK = 11, QUEEN = 12, KING = 13, ACE = 14,
	JOKER = 15
}

const SUIT_SYMBOLS := {
	Suit.HEARTS: "♥",
	Suit.DIAMONDS: "♦",
	Suit.CLUBS: "♣",
	Suit.SPADES: "♠",
}

const RANK_SYMBOLS := {
	Rank.TWO: "2", Rank.THREE: "3", Rank.FOUR: "4", Rank.FIVE: "5",
	Rank.SIX: "6", Rank.SEVEN: "7", Rank.EIGHT: "8", Rank.NINE: "9",
	Rank.TEN: "10", Rank.JACK: "J", Rank.QUEEN: "Q", Rank.KING: "K",
	Rank.ACE: "A",
}

var suit: Suit = Suit.HEARTS
var rank: Rank = Rank.TWO
var index: int  # 0–51 unique id


func _init(p_suit: Suit, p_rank: Rank) -> void:
	suit = p_suit
	rank = p_rank
	index = p_suit * 13 + (p_rank - 2)


func get_suit_symbol() -> String:
	return SUIT_SYMBOLS[suit]


func get_rank_symbol() -> String:
	return RANK_SYMBOLS[rank]


func is_red() -> bool:
	return suit == Suit.HEARTS or suit == Suit.DIAMONDS


func is_joker() -> bool:
	return rank == Rank.JOKER


func get_display_name() -> String:
	if is_joker():
		return "JOKER"
	return get_rank_symbol() + get_suit_symbol()
