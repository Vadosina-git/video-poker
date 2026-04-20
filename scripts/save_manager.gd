extends Node

const SAVE_PATH := "user://save.json"
var DEFAULT_CREDITS: int = 20000
var credits: int = DEFAULT_CREDITS
var denomination: int = 1
var last_variant: String = "jacks_or_better"
var hand_count: int = 1  # 1=single, 3=triple, 5=five, 10=ten, 12=twelve, 25=twenty-five
var speed_level: int = 1  # 0-3, default 1 (second speed)
var bet_level: int = 1    # Legacy, kept for backward compat
var bet_levels: Dictionary = {}  # Per-mode: {"single_play": 1, "triple_play": 1, ...}
var ultra_vp: bool = false  # Ultra VP mode flag
var spin_poker: bool = false   # Spin Poker mode flag
var depth_hint_shown: bool = false  # True once the game depth tooltip has been shown
var last_gift_time: int = 0         # Unix timestamp of last gift claim
var pack_claim_times: Dictionary = {}  # product_id → unix ts of last free-timed pack claim
var ultra_multipliers: Dictionary = {}  # Per-machine per-combo multiplier state
var language: String = "system"  # "system" | "en" | "ru" | "es"
var age_gate_confirmed: bool = false  # True once user confirmed age ≥ 18 (see age_gate.gd)
var settings := {
	"sound_fx": true,
	"music": true,
	"casino_ambient": false,
	"game_speed": "normal",
	"auto_hold": false,
	"vibration": true,
}


var _glyphs: Dictionary = {}  # "0".."9", ",", ".", "chip", "K", "M" → Texture2D
const GLYPH_PATH := "res://assets/textures/glyphs/"


func _ready() -> void:
	_load_glyphs()
	load_game()


func _load_glyphs() -> void:
	var mappings := {
		"0": "glyph_0.svg", "1": "glyph_1.svg", "2": "glyph_2.svg",
		"3": "glyph_3.svg", "4": "glyph_4.svg", "5": "glyph_5.svg",
		"6": "glyph_6.svg", "7": "glyph_7.svg", "8": "glyph_8.svg",
		"9": "glyph_9.svg", ",": "glyph_comma.svg", ".": "glyph_dot.svg",
		"chip": "glyph_chip.svg", "K": "glyph_K.svg", "M": "glyph_M.svg",
	}
	for key in mappings:
		var path: String = GLYPH_PATH + mappings[key]
		if ResourceLoader.exists(path):
			_glyphs[key] = load(path)


## Create a currency display widget.
## Returns a Dictionary with "box" (HBoxContainer) for adding to tree.
func create_currency_display(glyph_h: int, color: Color) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return {"box": box, "glyph_h": glyph_h, "color": color}


## Update currency display with a formatted string. Prepends chip icon.
## Pass glyph_h/color to change size/color, or 0/negative to keep current.
## Pass show_chip=false to render without the chip glyph.
func set_currency_value(cd: Dictionary, text: String, glyph_h: int = 0, color: Color = Color(-1, 0, 0), show_chip: bool = true) -> void:
	if glyph_h > 0:
		cd["glyph_h"] = glyph_h
	if color.r >= 0:
		cd["color"] = color
	var box: HBoxContainer = cd["box"]
	var h: int = cd["glyph_h"]
	var col: Color = cd["color"]
	# If only changing style (no text), just update existing glyphs
	if text == "":
		for child in box.get_children():
			if child is TextureRect:
				child.modulate = col
				child.custom_minimum_size.y = h
				var tex: Texture2D = child.texture
				if tex:
					var aspect: float = tex.get_width() / maxf(tex.get_height(), 1.0)
					child.custom_minimum_size.x = int(ceili(h * aspect))
		return
	# Rebuild glyphs
	for child in box.get_children():
		box.remove_child(child)
		child.free()
	if show_chip:
		_add_glyph(box, "chip", h, col)
	for ch in text:
		if ch in _glyphs:
			_add_glyph(box, ch, h, col)


func _add_glyph(box: HBoxContainer, key: String, h: int, color: Color) -> void:
	if key not in _glyphs:
		return
	var tex: Texture2D = _glyphs[key]
	var aspect: float = tex.get_width() / maxf(tex.get_height(), 1.0)
	var w: int = int(ceili(h * aspect))
	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(w, h)
	tex_rect.modulate = color
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tex_rect)


## Format number with commas: 12345 → "12,345"
static func format_money(n: int) -> String:
	var s := str(absi(n))
	var result := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	return "-" + result if n < 0 else result


## Format number shortened: 1500 → "1K", 2000000 → "2M"
static func format_short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	elif n >= 1000:
		return "%.0fK" % (n / 1000.0)
	return str(n)


## Estimate pixel width of a currency string rendered at given glyph height.
func estimate_currency_width(text: String, glyph_h: int, show_chip: bool = true) -> float:
	var total: float = 0.0
	if show_chip and "chip" in _glyphs:
		var tex: Texture2D = _glyphs["chip"]
		total += glyph_h * (tex.get_width() / maxf(tex.get_height(), 1.0))
	for ch in text:
		if ch in _glyphs:
			var tex: Texture2D = _glyphs[ch]
			total += glyph_h * (tex.get_width() / maxf(tex.get_height(), 1.0))
	return total


## Format number: prefer full format ("1,024"), fall back to short ("1K") if too wide.
func format_auto(n: int, max_width: float, glyph_h: int) -> String:
	var full := format_money(n)
	if estimate_currency_width(full, glyph_h) <= max_width:
		return full
	return format_short(n)


func save_game() -> void:
	var data := {
		"credits": credits,
		"denomination": denomination,
		"last_variant": last_variant,
		"hand_count": hand_count,
		"speed_level": speed_level,
		"bet_level": bet_level,
		"bet_levels": bet_levels,
		"ultra_vp": ultra_vp,
		"spin_poker": spin_poker,
		"depth_hint_shown": depth_hint_shown,
		"last_gift_time": last_gift_time,
		"pack_claim_times": pack_claim_times,
		"ultra_multipliers": ultra_multipliers,
		"language": language,
		"age_gate_confirmed": age_gate_confirmed,
		"settings": settings,
	}
	var json_text := JSON.stringify(data, "\t")
	var obfuscated := _obfuscate(json_text)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("save_game: failed to open %s for writing" % SAVE_PATH)
		return
	file.store_buffer(obfuscated)
	file.close()


const _OBFUSCATION_KEY := 0x5A


func _obfuscate(text: String) -> PackedByteArray:
	var bytes := text.to_utf8_buffer()
	for i in bytes.size():
		bytes[i] = bytes[i] ^ _OBFUSCATION_KEY
	return bytes


func _deobfuscate(bytes: PackedByteArray) -> String:
	var out := bytes.duplicate()
	for i in out.size():
		out[i] = out[i] ^ _OBFUSCATION_KEY
	return out.get_string_from_utf8()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("load_game: failed to open %s" % SAVE_PATH)
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()
	# Try obfuscated format first; if that fails, try plaintext (legacy migration).
	var json_text := _deobfuscate(bytes)
	var json := JSON.new()
	if json.parse(json_text) != OK:
		# Fallback for existing plaintext save files created before obfuscation.
		json_text = bytes.get_string_from_utf8()
		if json.parse(json_text) != OK:
			return
	var data: Dictionary = json.data
	credits = int(data.get("credits", DEFAULT_CREDITS))
	denomination = int(data.get("denomination", 1))
	last_variant = data.get("last_variant", "jacks_or_better")
	hand_count = int(data.get("hand_count", 1))
	speed_level = int(data.get("speed_level", 1))
	bet_level = int(data.get("bet_level", 1))
	var saved_bets: Dictionary = data.get("bet_levels", {})
	bet_levels.clear()
	for key in saved_bets:
		bet_levels[key] = int(saved_bets[key])
	ultra_vp = bool(data.get("ultra_vp", data.get("ultimate_x", false)))
	spin_poker = bool(data.get("spin_poker", false))
	depth_hint_shown = bool(data.get("depth_hint_shown", false))
	last_gift_time = int(data.get("last_gift_time", 0))
	var saved_claims: Dictionary = data.get("pack_claim_times", {})
	pack_claim_times.clear()
	for key in saved_claims:
		pack_claim_times[str(key)] = int(saved_claims[key])
	ultra_multipliers = data.get("ultra_multipliers", {})
	language = String(data.get("language", "system"))
	age_gate_confirmed = bool(data.get("age_gate_confirmed", false))
	var saved_settings: Dictionary = data.get("settings", {})
	for key in saved_settings:
		if key in settings:
			settings[key] = saved_settings[key]


func get_bet_level(mode_id: String) -> int:
	return int(bet_levels.get(mode_id, 1))


func set_bet_level(mode_id: String, level: int) -> void:
	bet_levels[mode_id] = level
	bet_level = level  # keep legacy field in sync
	save_game()


func add_credits(amount: int) -> void:
	credits += amount
	save_game()


## Free-timed shop packs: returns remaining cooldown in seconds (0 if ready to claim).
func get_pack_cooldown_remaining(product_id: String, cooldown_seconds: int) -> int:
	if cooldown_seconds <= 0:
		return 0
	var last_claim: int = int(pack_claim_times.get(product_id, 0))
	if last_claim == 0:
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	var remaining: int = cooldown_seconds - (now - last_claim)
	return max(remaining, 0)


func mark_pack_claimed(product_id: String) -> void:
	pack_claim_times[product_id] = int(Time.get_unix_time_from_system())
	save_game()


func deduct_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	save_game()
	return true
