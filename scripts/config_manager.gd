extends Node

## ConfigManager autoload — loads all JSON configs from res://configs/ at startup.
## Provides typed accessors with hardcoded fallback defaults if a file is missing/corrupt.

const CONFIGS_PATH := "res://configs/"

# Loaded config dictionaries
var lobby_order: Dictionary = {}
var init_config: Dictionary = {}
var balance: Dictionary = {}
var machines: Dictionary = {}
var shop: Dictionary = {}
var gift: Dictionary = {}
var sounds: Dictionary = {}
var animations: Dictionary = {}
var features: Dictionary = {}
var vibration: Dictionary = {}
var economy: Dictionary = {}


func _ready() -> void:
	lobby_order = _load_json("lobby_order.json", _default_lobby_order())
	init_config = _load_json("init_config.json", _default_init_config())
	balance = _load_json("balance.json", _default_balance())
	machines = _load_json("machines.json", _default_machines())
	shop = _load_json("shop.json", {})
	gift = _load_json("gift.json", _default_gift())
	sounds = _load_json("sounds.json", {})
	animations = _load_json("animations.json", _default_animations())
	features = _load_json("features.json", _default_features())
	vibration = _load_json("vibration.json", _default_vibration())
	economy = _load_json("economy.json", _default_economy())


# ─── ACCESSORS ────────────────────────────────────────────────────────

func get_machine(machine_id: String) -> Dictionary:
	var m: Dictionary = machines.get("machines", {})
	return m.get(machine_id, {})


func get_mode_balance(mode_id: String) -> Dictionary:
	var modes: Dictionary = balance.get("modes", {})
	return modes.get(mode_id, _default_mode_balance())


func get_denominations(mode_id: String) -> Array:
	var mb := get_mode_balance(mode_id)
	return mb.get("denominations", [1, 2, 5, 10, 25, 50, 100])


func get_starting_balance() -> int:
	return int(init_config.get("starting_balance", 20000))


## Big/huge win animation thresholds. Multiplier is computed as payout / bet
## so larger bets don't overtrigger the celebration. Returns {"big_win": {min, max},
## "huge_win": {min}} ranges.
func get_big_win_thresholds() -> Dictionary:
	var defaults := {
		"big_win": {"min": 4, "max": 7},
		"huge_win": {"min": 8},
	}
	return balance.get("big_win_thresholds", defaults)


## Classify a payout relative to the bet. Returns "huge", "big", or "none".
func classify_big_win(payout: int, bet: int) -> String:
	if bet <= 0 or payout <= 0:
		return "none"
	var mult: float = float(payout) / float(bet)
	var th := get_big_win_thresholds()
	var huge_min: float = float(th.get("huge_win", {}).get("min", 8))
	if mult >= huge_min:
		return "huge"
	var big: Dictionary = th.get("big_win", {})
	var big_min: float = float(big.get("min", 4))
	var big_max: float = float(big.get("max", 7))
	if mult >= big_min and mult <= big_max:
		return "big"
	return "none"


func get_gift_interval_hours() -> int:
	return int(gift.get("interval_hours", 2))


func get_gift_chips() -> int:
	return int(gift.get("chips_amount", 500))


## Returns chip-cascade animation params for gift / shop claim.
## Defaults match the historical hardcoded values.
func get_claim_animation() -> Dictionary:
	var a: Dictionary = gift.get("claim_animation", {})
	return {
		"chip_count": int(a.get("chip_count", 10)),
		"stagger_step_sec": float(a.get("stagger_step_sec", 0.05)),
		"travel_time_sec": float(a.get("travel_time_sec", 0.55)),
	}


func get_animation(key: String, default_val: float = 0.0) -> float:
	return float(animations.get(key, default_val))


func get_shop_items() -> Array:
	return shop.get("iap_items", [])


func get_lobby_modes() -> Array:
	return lobby_order.get("modes", [])


## True when the lobby tab `mode_id` opts into the 100-hand layout.
## The flag lives at the mode level in configs/lobby_order.json and lets a
## designer hide the 100-hand option per tab without touching code.
func is_hands_100_enabled_for_mode(mode_id: String) -> bool:
	for m in get_lobby_modes():
		if str(m.get("id", "")) == mode_id:
			return bool(m.get("hands_100_enabled", false))
	return false


## ─── FEATURE FLAGS (configs/features.json) ───────────────────────────

## Boolean feature flag from configs/features.json -> feature_flags.<key>.
## Defaults to `default_val` when the file or key is missing.
func is_feature_enabled(key: String, default_val: bool = true) -> bool:
	var flags: Dictionary = features.get("feature_flags", {})
	return bool(flags.get(key, default_val))


## Boolean visibility flag from configs/features.json -> ui_visibility.<key>.
func is_visible(key: String, default_val: bool = true) -> bool:
	var vis: Dictionary = features.get("ui_visibility", {})
	return bool(vis.get(key, default_val))


## Default theme id from configs/features.json -> theme.default_theme.
func get_default_theme() -> String:
	var t: Dictionary = features.get("theme", {})
	return str(t.get("default_theme", "classic"))


# ─── VIBRATION (configs/vibration.json) ──────────────────────────────

func get_vibration_duration_ms(event_name: String) -> int:
	var ev: Dictionary = vibration.get("events", {})
	return int(ev.get(event_name, 0))


func is_heavy_vibration_event(event_name: String) -> bool:
	var heavy: Array = vibration.get("heavy_events", [])
	return event_name in heavy


func get_vibration_heavy_pulse_count() -> int:
	return int(vibration.get("heavy_pulse_count", 3))


func get_vibration_heavy_gap_ms() -> int:
	return int(vibration.get("heavy_inter_pulse_gap_ms", 50))


# ─── ECONOMY (configs/economy.json) ──────────────────────────────────

func get_min_game_depth() -> int:
	var gd: Dictionary = economy.get("game_depth", {})
	return int(gd.get("min_rounds_to_play", 30))


func is_auto_shop_enabled() -> bool:
	var a: Dictionary = economy.get("auto_shop", {})
	return bool(a.get("trigger_below_min_bet", true))


## Per-mode flag for double-or-nothing risk round.
func is_double_enabled_for(mode_id: String) -> bool:
	if not is_feature_enabled("double_or_nothing_enabled", true):
		return false
	var d: Dictionary = economy.get("double_or_nothing", {})
	var key := "enabled_in_" + mode_id
	# Map multi-hand variants to a single multi key.
	if mode_id in ["triple_play", "five_play", "ten_play"]:
		key = "enabled_in_multi"
	if mode_id == "single_play":
		key = "enabled_in_single"
	return bool(d.get(key, true))


# ─── INIT DEFAULTS (configs/init_config.json) ────────────────────────

func get_default_locale() -> String:
	return str(init_config.get("default_locale", "en"))


func get_default_speed() -> int:
	return int(init_config.get("default_speed", 1))


func get_default_mode() -> String:
	return str(init_config.get("default_mode", "single_play"))


func get_default_machine() -> String:
	return str(init_config.get("default_machine", "jacks_or_better"))


## Per-mode index into balance.modes.<mode>.denominations for first-launch selection.
func get_default_denomination_index(mode_id: String) -> int:
	var mb := get_mode_balance(mode_id)
	return int(mb.get("default_denomination_index", 0))


func get_sound_file(event_name: String) -> String:
	var events: Dictionary = sounds.get("events", {})
	var file: String = events.get(event_name, "")
	if file == "":
		return ""
	return sounds.get("sounds_path", "res://assets/sounds/") + file


# ─── JSON LOADING ─────────────────────────────────────────────────────

func _load_json(filename: String, defaults: Dictionary) -> Dictionary:
	var path := CONFIGS_PATH + filename
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("ConfigManager: %s not found, using defaults" % path)
		return defaults
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("ConfigManager: cannot open %s, using defaults" % path)
		return defaults
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("ConfigManager: parse error in %s: %s" % [path, json.get_error_message()])
		return defaults
	if json.data is Dictionary:
		return json.data
	push_warning("ConfigManager: %s root is not a Dictionary, using defaults" % path)
	return defaults


# ─── HARDCODED DEFAULTS ───────────────────────────────────────────────

func _default_lobby_order() -> Dictionary:
	return {
		"modes": [
			{"id": "single_play", "label_key": "lobby.mode_single_play", "enabled": true,
			 "machines": [
				{"id": "jacks_or_better"}, {"id": "bonus_poker"}, {"id": "bonus_poker_deluxe"},
				{"id": "double_bonus"}, {"id": "double_double_bonus"}, {"id": "triple_double_bonus"},
				{"id": "aces_and_faces"}, {"id": "deuces_wild"}, {"id": "joker_poker"}, {"id": "deuces_and_joker"}
			]},
			{"id": "triple_play", "label_key": "lobby.mode_triple_play", "enabled": true,
			 "machines": [{"id": "jacks_or_better"}, {"id": "bonus_poker"}, {"id": "deuces_wild"}]},
			{"id": "five_play", "label_key": "lobby.mode_five_play", "enabled": true,
			 "machines": [{"id": "jacks_or_better"}, {"id": "bonus_poker"}]},
			{"id": "ten_play", "label_key": "lobby.mode_ten_play", "enabled": true,
			 "machines": [{"id": "jacks_or_better"}, {"id": "bonus_poker"}]},
			{"id": "ultra_vp", "label_key": "lobby.mode_ultra_vp", "enabled": true,
			 "machines": [{"id": "jacks_or_better"}, {"id": "double_double_bonus"}]},
			{"id": "spin_poker", "label_key": "lobby.mode_spin_poker", "enabled": true,
			 "machines": [{"id": "jacks_or_better"}]},
		]
	}


func _default_init_config() -> Dictionary:
	return {
		"starting_balance": 20000,
		"default_speed": 2,
		"default_denomination": 1,
		"default_mode": "single_play",
		"default_machine": "jacks_or_better",
	}


func _default_balance() -> Dictionary:
	return {"modes": {
		"single_play": _default_mode_balance(),
		"triple_play": {"denominations": [1,2,5,10,25], "max_bet_multiplier": 5},
		"five_play": {"denominations": [1,2,5,10], "max_bet_multiplier": 5},
		"ten_play": {"denominations": [1,2,5,10], "max_bet_multiplier": 5},
		"ultra_vp": {"denominations": [1,2,5,10,25], "max_bet_multiplier": 5},
		"spin_poker": {"denominations": [1,2,5,10], "max_bet_multiplier": 5},
	}}


func _default_mode_balance() -> Dictionary:
	return {"denominations": [1,2,5,10,25,50,100], "max_bet_multiplier": 5}


func _default_machines() -> Dictionary:
	return {"machines": {}}


func _default_gift() -> Dictionary:
	return {"interval_hours": 2, "chips_amount": 500}


func _default_animations() -> Dictionary:
	return {
		"card_deal_delay_ms": 100,
		"card_draw_delay_ms": 150,
		"bet_highlight_duration_ms": 1000,
		"win_counter_duration_ms": 3000,
		"win_highlight_hold_sec": 3,
		"balance_increment_duration_sec": 5,
		"deal_button_idle_blink_sec": 5,
		"deal_button_blink_interval_ms": 600,
		"spin_reel_stop_delay_ms": 2000,
		"spin_stop_inertia_ms": 700,
	}


func _default_features() -> Dictionary:
	return {
		"feature_flags": {
			"age_gate_enabled": true,
			"big_win_overlay_enabled": true,
			"double_or_nothing_enabled": true,
			"ultra_vp_enabled": true,
			"spin_poker_enabled": true,
			"multi_hand_enabled": true,
			"auto_shop_on_low_balance": true,
			"deal_button_idle_blink": true,
			"vibration_default": true,
			"sound_fx_default": true,
		},
		"ui_visibility": {},
		"theme": {"default_theme": "classic", "allow_theme_switching": false, "available_themes": ["classic"]},
		"debug": {},
	}


func _default_vibration() -> Dictionary:
	return {
		"events": {
			"button_press": 10, "card_hold": 10, "bet_change": 10,
			"card_deal": 15, "card_flip": 15,
			"win_small": 30, "win_medium": 40, "win_large": 60,
			"win_royal_flush": 100, "win_jackpot": 100,
			"spin_reel": 8, "spin_stop": 20,
			"double_win": 30, "double_lose": 20,
			"gift_claim": 40, "multiplier_activate": 25,
		},
		"heavy_events": ["win_royal_flush", "win_jackpot"],
		"heavy_pulse_count": 3,
		"heavy_inter_pulse_gap_ms": 50,
	}


func _default_economy() -> Dictionary:
	return {
		"game_depth": {"min_rounds_to_play": 30, "show_depth_hint": true},
		"auto_shop": {"trigger_below_min_bet": true},
		"double_or_nothing": {
			"enabled_in_single": true, "enabled_in_multi": true,
			"enabled_in_spin_poker": true, "enabled_in_ultra_vp": true,
		},
		"min_bet_per_mode": {},
		"max_bet_per_mode": {},
	}
