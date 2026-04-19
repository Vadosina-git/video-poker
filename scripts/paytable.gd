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
	# Primary: read from ConfigManager (configs/machines.json).
	# Resolved lazily so headless unit-test scripts (which don't load autoloads)
	# can preload this class without hitting an "Identifier not found" error.
	var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
	var machines_data: Dictionary = cm.machines.get("machines", {}) if cm else {}
	if machines_data.size() > 0:
		return _load_from_machines(machines_data)
	# Fallback: read from legacy data/paytables.json
	var path := "res://data/paytables.json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	json.parse(json_text)
	var data: Dictionary = json.data
	var result := {}
	for vid in data:
		var pt := Paytable.new()
		pt.variant_id = vid
		pt.name = data[vid].get("name", vid)
		pt.deck_size = int(data[vid].get("deck_size", 52))
		pt.rtp = float(data[vid].get("rtp", 99.0))
		pt.variance = data[vid].get("variance", "")
		pt._payout_data = data[vid].get("paytable", {})
		result[vid] = pt
	return result


static func _load_from_machines(machines_data: Dictionary) -> Dictionary:
	var result := {}
	for vid in machines_data:
		var m: Dictionary = machines_data[vid]
		var pt := Paytable.new()
		pt.variant_id = vid
		# Name from localization, fallback to id
		var label_key: String = m.get("label_key", "machine." + vid)
		var tr: Node = Engine.get_main_loop().root.get_node_or_null("/root/Translations")
		var translated: String = tr.tr_key(label_key) if tr else label_key
		pt.name = translated if translated != label_key else vid.replace("_", " ").capitalize()
		pt.deck_size = int(m.get("deck_size", 52))
		pt.rtp = 0.0
		pt.variance = ""
		# Build payout_data from hands array
		var hands: Array = m.get("hands", [])
		for hand in hands:
			var hand_id: String = hand.get("id", "")
			var pays: Array = hand.get("pays", [0, 0, 0, 0, 0])
			if hand_id != "":
				pt._payout_data[hand_id] = pays
		result[vid] = pt
	return result


func get_payout(hand_rank: HandEvaluator.HandRank, bet: int) -> int:
	var key: String = STANDARD_HAND_KEYS.get(hand_rank, "")
	return get_payout_by_key(key, bet)


func get_payout_by_key(key: String, bet: int) -> int:
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
	var tr: Node = Engine.get_main_loop().root.get_node_or_null("/root/Translations")
	if tr:
		var translated: String = tr.tr_key(key)
		if translated != key:
			return translated
	return hand_key.replace("_", " ").to_upper()
