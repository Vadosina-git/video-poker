extends SceneTree

## Unit tests for HandEvaluator — pure logic, no autoloads required.
## Run: Godot --headless --path . --script res://tests/test_hand_evaluator.gd

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("=== HandEvaluator tests ===")
	_test_royal_flush()
	_test_straight_flush()
	_test_four_of_a_kind()
	_test_full_house()
	_test_flush()
	_test_straight()
	_test_low_straight_ace()
	_test_three_of_a_kind()
	_test_two_pair()
	_test_jacks_or_better_only_jqka()
	_test_low_pair_is_nothing()
	_test_nothing()
	_test_wheel_straight_flush()
	_test_almost_royal_not_royal()
	_test_hold_mask_three_of_a_kind()
	_test_hold_mask_two_pair()
	_test_hold_mask_four_of_a_kind()
	_test_hold_mask_low_pair_empty()
	_print_summary()
	quit(0 if _failed == 0 else 1)


func _hand(cards: Array) -> Array[CardData]:
	# cards is array of [rank, suit] pairs where suit is a Suit enum int
	var result: Array[CardData] = []
	for c in cards:
		result.append(CardData.new(c[1], c[0]))
	return result


func _assert_rank(name: String, hand: Array[CardData], expected: HandEvaluator.HandRank) -> void:
	var actual := HandEvaluator.evaluate(hand)
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		_failures.append("%s: expected %s, got %s" % [name, HandEvaluator.HandRank.keys()[expected], HandEvaluator.HandRank.keys()[actual]])


func _assert_mask(name: String, actual: Array[bool], expected: Array[bool]) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		_failures.append("%s: expected mask %s, got %s" % [name, expected, actual])


# ─── Hand rank tests ──────────────────────────────────────────────────

func _test_royal_flush() -> void:
	var hand := _hand([
		[CardData.Rank.TEN, CardData.Suit.HEARTS],
		[CardData.Rank.JACK, CardData.Suit.HEARTS],
		[CardData.Rank.QUEEN, CardData.Suit.HEARTS],
		[CardData.Rank.KING, CardData.Suit.HEARTS],
		[CardData.Rank.ACE, CardData.Suit.HEARTS],
	])
	_assert_rank("royal_flush hearts", hand, HandEvaluator.HandRank.ROYAL_FLUSH)


func _test_straight_flush() -> void:
	var hand := _hand([
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
		[CardData.Rank.SIX, CardData.Suit.CLUBS],
		[CardData.Rank.SEVEN, CardData.Suit.CLUBS],
		[CardData.Rank.EIGHT, CardData.Suit.CLUBS],
		[CardData.Rank.NINE, CardData.Suit.CLUBS],
	])
	_assert_rank("straight_flush 5-9 clubs", hand, HandEvaluator.HandRank.STRAIGHT_FLUSH)


func _test_four_of_a_kind() -> void:
	var hand := _hand([
		[CardData.Rank.ACE, CardData.Suit.HEARTS],
		[CardData.Rank.ACE, CardData.Suit.DIAMONDS],
		[CardData.Rank.ACE, CardData.Suit.CLUBS],
		[CardData.Rank.ACE, CardData.Suit.SPADES],
		[CardData.Rank.FIVE, CardData.Suit.HEARTS],
	])
	_assert_rank("four aces + 5 kicker", hand, HandEvaluator.HandRank.FOUR_OF_A_KIND)


func _test_full_house() -> void:
	var hand := _hand([
		[CardData.Rank.KING, CardData.Suit.HEARTS],
		[CardData.Rank.KING, CardData.Suit.DIAMONDS],
		[CardData.Rank.KING, CardData.Suit.CLUBS],
		[CardData.Rank.FIVE, CardData.Suit.SPADES],
		[CardData.Rank.FIVE, CardData.Suit.HEARTS],
	])
	_assert_rank("full house KKK55", hand, HandEvaluator.HandRank.FULL_HOUSE)


func _test_flush() -> void:
	var hand := _hand([
		[CardData.Rank.TWO, CardData.Suit.SPADES],
		[CardData.Rank.FIVE, CardData.Suit.SPADES],
		[CardData.Rank.SEVEN, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.SPADES],
		[CardData.Rank.KING, CardData.Suit.SPADES],
	])
	_assert_rank("flush spades mixed ranks", hand, HandEvaluator.HandRank.FLUSH)


func _test_straight() -> void:
	var hand := _hand([
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
		[CardData.Rank.TEN, CardData.Suit.DIAMONDS],
		[CardData.Rank.JACK, CardData.Suit.CLUBS],
		[CardData.Rank.QUEEN, CardData.Suit.SPADES],
		[CardData.Rank.KING, CardData.Suit.HEARTS],
	])
	_assert_rank("straight 9-K mixed suits", hand, HandEvaluator.HandRank.STRAIGHT)


func _test_low_straight_ace() -> void:
	var hand := _hand([
		[CardData.Rank.ACE, CardData.Suit.HEARTS],
		[CardData.Rank.TWO, CardData.Suit.DIAMONDS],
		[CardData.Rank.THREE, CardData.Suit.CLUBS],
		[CardData.Rank.FOUR, CardData.Suit.SPADES],
		[CardData.Rank.FIVE, CardData.Suit.HEARTS],
	])
	_assert_rank("wheel straight A-2-3-4-5", hand, HandEvaluator.HandRank.STRAIGHT)


func _test_three_of_a_kind() -> void:
	var hand := _hand([
		[CardData.Rank.SEVEN, CardData.Suit.HEARTS],
		[CardData.Rank.SEVEN, CardData.Suit.DIAMONDS],
		[CardData.Rank.SEVEN, CardData.Suit.CLUBS],
		[CardData.Rank.TWO, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	_assert_rank("three sevens", hand, HandEvaluator.HandRank.THREE_OF_A_KIND)


func _test_two_pair() -> void:
	var hand := _hand([
		[CardData.Rank.KING, CardData.Suit.HEARTS],
		[CardData.Rank.KING, CardData.Suit.DIAMONDS],
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
		[CardData.Rank.FIVE, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	_assert_rank("two pair KK 55", hand, HandEvaluator.HandRank.TWO_PAIR)


func _test_jacks_or_better_only_jqka() -> void:
	# Pair of jacks — winning
	var jacks := _hand([
		[CardData.Rank.JACK, CardData.Suit.HEARTS],
		[CardData.Rank.JACK, CardData.Suit.DIAMONDS],
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
		[CardData.Rank.SEVEN, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	_assert_rank("pair of jacks", jacks, HandEvaluator.HandRank.JACKS_OR_BETTER)

	# Pair of aces — also winning
	var aces := _hand([
		[CardData.Rank.ACE, CardData.Suit.HEARTS],
		[CardData.Rank.ACE, CardData.Suit.DIAMONDS],
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
		[CardData.Rank.SEVEN, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	_assert_rank("pair of aces", aces, HandEvaluator.HandRank.JACKS_OR_BETTER)


func _test_low_pair_is_nothing() -> void:
	# Pair of tens — NOT a win in Jacks or Better
	var hand := _hand([
		[CardData.Rank.TEN, CardData.Suit.HEARTS],
		[CardData.Rank.TEN, CardData.Suit.DIAMONDS],
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
		[CardData.Rank.SEVEN, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	_assert_rank("pair of tens = nothing", hand, HandEvaluator.HandRank.NOTHING)


func _test_nothing() -> void:
	var hand := _hand([
		[CardData.Rank.TWO, CardData.Suit.HEARTS],
		[CardData.Rank.FIVE, CardData.Suit.DIAMONDS],
		[CardData.Rank.SEVEN, CardData.Suit.CLUBS],
		[CardData.Rank.NINE, CardData.Suit.SPADES],
		[CardData.Rank.KING, CardData.Suit.HEARTS],
	])
	_assert_rank("no combo", hand, HandEvaluator.HandRank.NOTHING)


func _test_wheel_straight_flush() -> void:
	# A-2-3-4-5 all clubs = straight flush (NOT royal, since royal requires 10-J-Q-K-A)
	var hand := _hand([
		[CardData.Rank.ACE, CardData.Suit.CLUBS],
		[CardData.Rank.TWO, CardData.Suit.CLUBS],
		[CardData.Rank.THREE, CardData.Suit.CLUBS],
		[CardData.Rank.FOUR, CardData.Suit.CLUBS],
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
	])
	_assert_rank("wheel straight flush", hand, HandEvaluator.HandRank.STRAIGHT_FLUSH)


func _test_almost_royal_not_royal() -> void:
	# 9-10-J-Q-K all hearts = straight flush, NOT royal
	var hand := _hand([
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
		[CardData.Rank.TEN, CardData.Suit.HEARTS],
		[CardData.Rank.JACK, CardData.Suit.HEARTS],
		[CardData.Rank.QUEEN, CardData.Suit.HEARTS],
		[CardData.Rank.KING, CardData.Suit.HEARTS],
	])
	_assert_rank("9-K straight flush is not royal", hand, HandEvaluator.HandRank.STRAIGHT_FLUSH)


# ─── Hold mask tests ─────────────────────────────────────────────────

func _test_hold_mask_three_of_a_kind() -> void:
	var hand := _hand([
		[CardData.Rank.SEVEN, CardData.Suit.HEARTS],
		[CardData.Rank.TWO, CardData.Suit.DIAMONDS],
		[CardData.Rank.SEVEN, CardData.Suit.CLUBS],
		[CardData.Rank.NINE, CardData.Suit.SPADES],
		[CardData.Rank.SEVEN, CardData.Suit.DIAMONDS],
	])
	var mask := HandEvaluator.get_hold_mask(hand, HandEvaluator.HandRank.THREE_OF_A_KIND)
	_assert_mask("hold mask 3oak sevens", mask, [true, false, true, false, true])


func _test_hold_mask_two_pair() -> void:
	var hand := _hand([
		[CardData.Rank.KING, CardData.Suit.HEARTS],
		[CardData.Rank.FIVE, CardData.Suit.DIAMONDS],
		[CardData.Rank.KING, CardData.Suit.CLUBS],
		[CardData.Rank.FIVE, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	var mask := HandEvaluator.get_hold_mask(hand, HandEvaluator.HandRank.TWO_PAIR)
	_assert_mask("hold mask 2 pair KK 55", mask, [true, true, true, true, false])


func _test_hold_mask_four_of_a_kind() -> void:
	var hand := _hand([
		[CardData.Rank.ACE, CardData.Suit.HEARTS],
		[CardData.Rank.ACE, CardData.Suit.DIAMONDS],
		[CardData.Rank.ACE, CardData.Suit.CLUBS],
		[CardData.Rank.ACE, CardData.Suit.SPADES],
		[CardData.Rank.FIVE, CardData.Suit.HEARTS],
	])
	var mask := HandEvaluator.get_hold_mask(hand, HandEvaluator.HandRank.FOUR_OF_A_KIND)
	_assert_mask("hold mask 4oak aces kicker", mask, [true, true, true, true, false])


func _test_hold_mask_low_pair_empty() -> void:
	# When rank is NOTHING (low pair isn't considered winning), mask should be empty
	var hand := _hand([
		[CardData.Rank.TEN, CardData.Suit.HEARTS],
		[CardData.Rank.TEN, CardData.Suit.DIAMONDS],
		[CardData.Rank.FIVE, CardData.Suit.CLUBS],
		[CardData.Rank.SEVEN, CardData.Suit.SPADES],
		[CardData.Rank.NINE, CardData.Suit.HEARTS],
	])
	var mask := HandEvaluator.get_hold_mask(hand, HandEvaluator.HandRank.NOTHING)
	_assert_mask("hold mask nothing = all false", mask, [false, false, false, false, false])


func _print_summary() -> void:
	print("")
	print("Passed: %d, Failed: %d" % [_passed, _failed])
	if _failed > 0:
		print("\nFailures:")
		for f in _failures:
			print("  - %s" % f)
	else:
		print("All tests passed")
