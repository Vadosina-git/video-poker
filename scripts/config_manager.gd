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
var ui_config: Dictionary = {}


func _ready() -> void:
	lobby_order = _load_json("lobby_order.json", _default_lobby_order())
	init_config = _load_json("init_config.json", _default_init_config())
	balance = _load_json("balance.json", _default_balance())
	machines = _load_json("machines.json", _default_machines())
	shop = _load_json("shop.json", {})
	gift = _load_json("gift.json", _default_gift())
	sounds = _load_json("sounds.json", {})
	animations = _load_json("animations.json", _default_animations())
	ui_config = _load_json("ui_config.json", {})


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


func get_gift_interval_hours() -> int:
	return int(gift.get("interval_hours", 2))


func get_gift_chips() -> int:
	return int(gift.get("chips_amount", 500))


func get_animation(key: String, default_val: float = 0.0) -> float:
	return float(animations.get(key, default_val))


func get_shop_items() -> Array:
	return shop.get("iap_items", [])


func get_lobby_modes() -> Array:
	return lobby_order.get("modes", [])


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
