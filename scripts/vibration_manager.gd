extends Node

## VibrationManager — haptic feedback for game events.
##
## Android: uses Input.vibrate_handheld(ms) — works out of the box.
## iOS: uses Input.vibrate_handheld(ms) as fallback (limited to one
##      pattern). For full UIImpactFeedbackGenerator support, install
##      a GDExtension plugin (see docs/vibration_setup.md).
##
## Toggle via SaveManager.settings["vibration"] (defaults to true).
## Call VibrationManager.vibrate("event_name") from any script.

## Duration presets per event type (milliseconds)
const EVENTS := {
	# UI
	"button_press":      10,
	"card_hold":         10,
	"bet_change":        10,
	# Cards
	"card_deal":         15,
	"card_flip":         15,
	# Wins
	"win_small":         30,
	"win_medium":        40,
	"win_large":         60,
	"win_royal_flush":   100,
	"win_jackpot":       100,
	# Spin Poker
	"spin_reel":         8,
	"spin_stop":         20,
	# Misc
	"double_win":        30,
	"double_lose":       20,
	"gift_claim":        40,
	"multiplier_activate": 25,
}

## Heavy pattern: multiple short bursts for Royal Flush / Jackpot
const HEAVY_EVENTS := ["win_royal_flush", "win_jackpot"]


func vibrate(event_name: String) -> void:
	if not _is_enabled():
		return
	var duration_ms: int = EVENTS.get(event_name, 0)
	if duration_ms <= 0:
		return
	if event_name in HEAVY_EVENTS:
		_vibrate_pattern(duration_ms)
	else:
		Input.vibrate_handheld(duration_ms)


## Multi-burst pattern for heavy events (3 pulses)
func _vibrate_pattern(total_ms: int) -> void:
	var pulse_ms: int = total_ms / 3
	for i in 3:
		Input.vibrate_handheld(pulse_ms)
		if i < 2:
			await get_tree().create_timer(pulse_ms / 1000.0 + 0.05).timeout


func _is_enabled() -> bool:
	return SaveManager.settings.get("vibration", true)
