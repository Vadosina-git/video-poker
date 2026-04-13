class_name Paytable
extends RefCounted

var variant_id: String
var name: String
var deck_size: int
var rtp: float
var variance: String
var _payout_data: Dictionary = {}

const STANDARD_HAND_KEYS := {
	HandEvaluator.HandRank.ROYAL_FLUSH: "royal_flush",
	HandEvaluator.HandRank.STRAIGHT_FLUSH: "straight_flush",
	HandEvaluator.HandRank.FOUR_OF_A_KIND: "four_of_a_kind",
	HandEvaluator.HandRank.FULL_HOUSE: "full_house",
	HandEvaluator.HandRank.FLUSH: "flush",
	HandEvaluator.HandRank.STRAIGHT: "straight",
	HandEvaluator.HandRank.THREE_OF_A_KIND: "three_of_a_kind",
	HandEvaluator.HandRank.TWO_PAIR: "two_pair",
	HandEvaluator.HandRank.JACKS_OR_BETTER: "jacks_or_better",
}


static func load_all() -> Dictionary:
	var file := FileAccess.open("res://data/paytables.json", FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	json.parse(json_text)
	var data: Dictionary = json.data
	var result := {}
	for vid in data:
		var pt := Paytable.new()
		pt.variant_id = vid
		pt.name = data[vid]["name"]
		pt.deck_size = data[vid]["deck_size"]
		pt.rtp = data[vid]["rtp"]
		pt.variance = data[vid]["variance"]
		pt._payout_data = data[vid]["paytable"]
		result[vid] = pt
	return result


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	var key: String = STANDARD_HAND_KEYS.get(hand_rank, "")
	if key == "" or key not in _payout_data:
		return 0
	var payouts: Array = _payout_data[key]
	var coin_index := clampi(bet - 1, 0, 4)
	return int(payouts[coin_index])


func get_hand_order() -> Array[String]:
	var keys: Array[String] = []
	for key in _payout_data:
		keys.append(key)
	return keys


func get_payout_row(hand_key: String) -> Array:
	return _payout_data.get(hand_key, [0, 0, 0, 0, 0])


func get_hand_display_name(hand_key: String) -> String:
	## Localized display name for a paytable key. Falls back to the key itself
	## (uppercased, underscores stripped) if no translation exists yet.
	var key := "hand." + hand_key
	var translated := Translations.tr_key(key)
	if translated != key:
		return translated
	return hand_key.replace("_", " ").to_upper()
