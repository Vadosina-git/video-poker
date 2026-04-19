extends SceneTree

## Unit tests for Deck — verify Fisher-Yates correctness, no duplicates.
## Run: Godot --headless --path . --script res://tests/test_deck.gd

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("=== Deck tests ===")
	seed(42)  # deterministic for tests
	_test_deck_size_52()
	_test_deck_size_53_has_joker()
	_test_all_cards_unique_52()
	_test_all_cards_unique_53()
	_test_shuffle_changes_order()
	_test_no_duplicate_in_hand_after_shuffle()
	_test_get_replacement_consistent()
	_test_multihand_replacements_preserves_held()
	_test_multihand_replacements_no_held_duplicate()
	_test_shuffle_still_contains_all_cards()
	_print_summary()
	quit(0 if _failed == 0 else 1)


func _pass(name: String) -> void:
	_passed += 1


func _fail(name: String, reason: String) -> void:
	_failed += 1
	_failures.append("%s: %s" % [name, reason])


func _test_deck_size_52() -> void:
	var deck := Deck.new(52)
	if deck.card_count() == 52:
		_pass("deck size 52")
	else:
		_fail("deck size 52", "got %d" % deck.card_count())


func _test_deck_size_53_has_joker() -> void:
	var deck := Deck.new(53)
	if deck.card_count() != 53:
		_fail("deck 53 size", "got %d" % deck.card_count())
		return
	var has_joker := false
	for i in 53:
		if deck.get_card(i).rank == CardData.Rank.JOKER:
			has_joker = true
			break
	if has_joker:
		_pass("deck 53 has joker")
	else:
		_fail("deck 53 has joker", "joker missing")


func _test_all_cards_unique_52() -> void:
	var deck := Deck.new(52)
	var indices := {}
	for i in 52:
		var idx := deck.get_card(i).index
		if idx in indices:
			_fail("52 unique", "duplicate index %d" % idx)
			return
		indices[idx] = true
	_pass("52 unique")


func _test_all_cards_unique_53() -> void:
	var deck := Deck.new(53)
	var seen := {}
	for i in 53:
		var c := deck.get_card(i)
		var key := "%d_%d" % [c.suit, c.rank]
		if key in seen:
			_fail("53 unique", "duplicate %s" % key)
			return
		seen[key] = true
	_pass("53 unique")


func _test_shuffle_changes_order() -> void:
	var d1 := Deck.new(52)
	var order_before: Array[int] = []
	for i in 52:
		order_before.append(d1.get_card(i).index)
	d1.shuffle()
	var order_after: Array[int] = []
	for i in 52:
		order_after.append(d1.get_card(i).index)
	if order_before != order_after:
		_pass("shuffle changes order")
	else:
		_fail("shuffle changes order", "order identical after shuffle")


func _test_no_duplicate_in_hand_after_shuffle() -> void:
	var deck := Deck.new(52)
	# Run 100 shuffles, each time verify first 10 cards are unique
	for trial in 100:
		var hand := deck.deal_hand()
		var seen_idx := {}
		for c in hand:
			if c.index in seen_idx:
				_fail("hand unique", "trial %d has duplicate card" % trial)
				return
			seen_idx[c.index] = true
		# replacements 5..9 must also be unique from the hand
		for pos in 5:
			var rep := deck.get_replacement(pos)
			if rep.index in seen_idx:
				_fail("replacement unique", "trial %d replacement %d duplicates hand" % [trial, pos])
				return
			seen_idx[rep.index] = true
	_pass("hand + replacements unique over 100 trials")


func _test_get_replacement_consistent() -> void:
	var deck := Deck.new(52)
	deck.deal_hand()
	var r1 := deck.get_replacement(2)
	var r2 := deck.get_replacement(2)
	if r1.index == r2.index:
		_pass("get_replacement consistent")
	else:
		_fail("get_replacement consistent", "different cards for same position")


func _test_multihand_replacements_preserves_held() -> void:
	var primary_deck := Deck.new(52)
	var primary_hand := primary_deck.deal_hand()
	var multi_deck := Deck.new(52)
	var held: Array[bool] = [true, false, true, false, false]
	var replacements := multi_deck.deal_multihand_replacements(primary_hand, held)

	if replacements[0].index != primary_hand[0].index:
		_fail("multihand held[0]", "held card replaced")
		return
	if replacements[2].index != primary_hand[2].index:
		_fail("multihand held[2]", "held card replaced")
		return
	_pass("multihand preserves held cards")


func _test_multihand_replacements_no_held_duplicate() -> void:
	var primary_deck := Deck.new(52)
	var primary_hand := primary_deck.deal_hand()
	var multi_deck := Deck.new(52)
	var held: Array[bool] = [true, true, false, false, false]
	# held cards: primary_hand[0], primary_hand[1]
	# replacements for positions 2,3,4 must NOT match those
	var replacements := multi_deck.deal_multihand_replacements(primary_hand, held)
	var held_indices: Array[int] = [primary_hand[0].index, primary_hand[1].index]
	for i in [2, 3, 4]:
		if replacements[i].index in held_indices:
			_fail("multihand no dup", "pos %d duplicates held" % i)
			return
	_pass("multihand replacements avoid held cards")


func _test_shuffle_still_contains_all_cards() -> void:
	var deck := Deck.new(52)
	deck.shuffle()
	var seen := {}
	for i in 52:
		seen[deck.get_card(i).index] = true
	if seen.size() == 52:
		_pass("shuffle preserves card set")
	else:
		_fail("shuffle preserves card set", "expected 52 unique, got %d" % seen.size())


func _print_summary() -> void:
	print("")
	print("Passed: %d, Failed: %d" % [_passed, _failed])
	if _failed > 0:
		print("\nFailures:")
		for f in _failures:
			print("  - %s" % f)
	else:
		print("All tests passed")
