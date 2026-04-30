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

## Event durations and heavy-event list now live in configs/vibration.json.
## ConfigManager exposes them as get_vibration_duration_ms / is_heavy_vibration_event.
## The constants below are kept only as a safety fallback for headless tests that
## bypass autoloads.
const FALLBACK_EVENTS := {
	"button_press": 10, "card_hold": 10, "bet_change": 10,
	"card_deal": 15, "card_flip": 15,
	"win_small": 30, "win_medium": 40, "win_large": 60,
	"win_royal_flush": 100, "win_jackpot": 100,
	"spin_reel": 8, "spin_stop": 20,
	"double_win": 30, "double_lose": 20,
	"gift_claim": 40, "multiplier_activate": 25,
}
const FALLBACK_HEAVY := ["win_royal_flush", "win_jackpot"]


func vibrate(event_name: String) -> void:
	if not _is_enabled():
		return
	var duration_ms: int = _duration_for(event_name)
	if duration_ms <= 0:
		return
	if _is_heavy(event_name):
		_vibrate_pattern(duration_ms)
	else:
		Input.vibrate_handheld(duration_ms)


func _duration_for(event_name: String) -> int:
	var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
	if cm and cm.vibration.size() > 0:
		return cm.get_vibration_duration_ms(event_name)
	return int(FALLBACK_EVENTS.get(event_name, 0))


func _is_heavy(event_name: String) -> bool:
	var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
	if cm and cm.vibration.size() > 0:
		return cm.is_heavy_vibration_event(event_name)
	return event_name in FALLBACK_HEAVY


## Multi-burst pattern for heavy events. Pulse count + gap come from config.
func _vibrate_pattern(total_ms: int) -> void:
	var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
	var pulses: int = cm.get_vibration_heavy_pulse_count() if cm else 3
	var gap_ms: int = cm.get_vibration_heavy_gap_ms() if cm else 50
	if pulses <= 0:
		pulses = 1
	var pulse_ms: int = total_ms / pulses
	for i in pulses:
		Input.vibrate_handheld(pulse_ms)
		if i < pulses - 1:
			await get_tree().create_timer(pulse_ms / 1000.0 + gap_ms / 1000.0).timeout


func _is_enabled() -> bool:
	return SaveManager.settings.get("vibration", true)
