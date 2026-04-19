extends SceneTree

## Unit tests for DeucesAndJoker variant — specifically the jackpot hand
## "four_deuces_joker" (all 5 wilds) payout behavior at bet 1-4 vs bet 5.
##
## Run: Godot --headless --path . --script res://tests/test_deuces_and_joker.gd

const DeucesAndJokerClass = preload("res://scripts/variants/deuces_and_joker.gd")

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("=== DeucesAndJoker tests ===")
	_test_jackpot_at_max_bet()
	_test_jackpot_fallback_at_bet_1()
	_test_jackpot_fallback_at_bet_4()
	_test_natural_royal_payout()
	_test_four_deuces_payout()
	_test_wild_royal_payout()
	_test_five_of_a_kind_payout()
	_test_three_of_a_kind_min_hand()
	_test_nothing_no_payout()
	_print_summary()
	quit(0 if _failed == 0 else 1)


func _make_variant():
	var pt := Paytable.new()
	pt.variant_id = "deuces_and_joker"
	pt.name = "Deuces and Joker Wild"
	pt.deck_size = 53
	pt._payout_data = {
		"four_deuces_joker":   [0, 0, 0, 0, 10000],
		"natural_royal_flush": [250, 500, 750, 1000, 4000],
		"four_deuces":         [25, 50, 75, 100, 125],
		"wild_royal_flush":    [12, 24, 36, 48, 60],
		"five_of_a_kind":      [9, 18, 27, 36, 45],
		"straight_flush":      [6, 12, 18, 24, 30],
		"four_of_a_kind":      [3, 6, 9, 12, 15],
		"full_house":          [3, 6, 9, 12, 15],
		"flush":               [3, 6, 9, 12, 15],
		"straight":            [2, 4, 6, 8, 10],
		"three_of_a_kind":     [1, 2, 3, 4, 5],
	}
	return DeucesAndJokerClass.new(pt)


func _jackpot_hand() -> Array[CardData]:
	# 4 deuces + joker
	return [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.SPADES, CardData.Rank.TWO),
		CardData.new(CardData.Suit.JOKER_SUIT, CardData.Rank.JOKER),
	]


func _assert(name: String, actual, expected) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		_failures.append("%s: expected %s, got %s" % [name, expected, actual])


func _test_jackpot_at_max_bet() -> void:
	var v = _make_variant()
	v.evaluate(_jackpot_hand())
	_assert("jackpot bet=5", v.get_payout(HandEvaluator.HandRank.FOUR_OF_A_KIND, 5), 10000)


func _test_jackpot_fallback_at_bet_1() -> void:
	# At bet 1, jackpot should NOT pay 0 — should fall back to five_of_a_kind (9)
	var v = _make_variant()
	v.evaluate(_jackpot_hand())
	_assert("jackpot bet=1 fallback to 5oak=9", v.get_payout(HandEvaluator.HandRank.FOUR_OF_A_KIND, 1), 9)


func _test_jackpot_fallback_at_bet_4() -> void:
	var v = _make_variant()
	v.evaluate(_jackpot_hand())
	_assert("jackpot bet=4 fallback to 5oak=36", v.get_payout(HandEvaluator.HandRank.FOUR_OF_A_KIND, 4), 36)


func _test_natural_royal_payout() -> void:
	var v = _make_variant()
	var hand: Array[CardData] = [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.TEN),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.JACK),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.QUEEN),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.KING),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.ACE),
	]
	v.evaluate(hand)
	_assert("natural royal bet=5", v.get_payout(HandEvaluator.HandRank.ROYAL_FLUSH, 5), 4000)
	_assert("natural royal bet=1", v.get_payout(HandEvaluator.HandRank.ROYAL_FLUSH, 1), 250)


func _test_four_deuces_payout() -> void:
	var v = _make_variant()
	var hand: Array[CardData] = [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.SPADES, CardData.Rank.TWO),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.ACE),
	]
	v.evaluate(hand)
	_assert("four deuces no joker bet=1", v.get_payout(HandEvaluator.HandRank.FOUR_OF_A_KIND, 1), 25)
	_assert("four deuces no joker bet=5", v.get_payout(HandEvaluator.HandRank.FOUR_OF_A_KIND, 5), 125)


func _test_wild_royal_payout() -> void:
	# 10,J,Q,K hearts + one deuce (wild standing for ace)
	var v = _make_variant()
	var hand: Array[CardData] = [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.TEN),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.JACK),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.QUEEN),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.KING),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.TWO),
	]
	v.evaluate(hand)
	_assert("wild royal bet=1", v.get_payout(HandEvaluator.HandRank.ROYAL_FLUSH, 1), 12)


func _test_five_of_a_kind_payout() -> void:
	# Three aces + 2 wilds
	var v = _make_variant()
	var hand: Array[CardData] = [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.TWO),
		CardData.new(CardData.Suit.JOKER_SUIT, CardData.Rank.JOKER),
	]
	v.evaluate(hand)
	_assert("5oak bet=1", v.get_payout(HandEvaluator.HandRank.FOUR_OF_A_KIND, 1), 9)


func _test_three_of_a_kind_min_hand() -> void:
	# Pair of aces + 1 wild = 3oak (minimum paid hand)
	var v = _make_variant()
	var hand: Array[CardData] = [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.SEVEN),
		CardData.new(CardData.Suit.SPADES, CardData.Rank.NINE),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.TWO),
	]
	v.evaluate(hand)
	_assert("3oak bet=1", v.get_payout(HandEvaluator.HandRank.THREE_OF_A_KIND, 1), 1)


func _test_nothing_no_payout() -> void:
	# Pair of aces without wild — below min hand — returns 0
	var v = _make_variant()
	var hand: Array[CardData] = [
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.ACE),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.SEVEN),
		CardData.new(CardData.Suit.SPADES, CardData.Rank.NINE),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.KING),
	]
	v.evaluate(hand)
	_assert("pair of aces no wild = 0 payout", v.get_payout(HandEvaluator.HandRank.NOTHING, 1), 0)


func _print_summary() -> void:
	print("")
	print("Passed: %d, Failed: %d" % [_passed, _failed])
	if _failed > 0:
		print("\nFailures:")
		for f in _failures:
			print("  - %s" % f)
	else:
		print("All tests passed")
