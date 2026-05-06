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
var mode_id: String = "single_play"  # Last selected lobby mode
var mode_hand_counts: Dictionary = {}  # Per-mode saved hand count
var depth_hint_shown: bool = false  # True once the game depth tooltip has been shown
var tutor_shown: bool = false  # True once the first-launch tutorial has been completed
var show_machine_stats: bool = false  # Lobby tile stats panel toggle (Best Combo + Score)
signal show_machine_stats_changed(state: bool)
var last_gift_time: int = 0         # Unix timestamp of last gift claim
var pack_claim_times: Dictionary = {}  # product_id → unix ts of last free-timed pack claim
var ultra_multipliers: Dictionary = {}  # Per-machine per-combo multiplier state
# Per-mode per-machine lobby stats:
#   mode_id → variant_id → {best_rank:int, best_key:String, score:int}
var machine_stats: Dictionary = {}
var language: String = "system"  # "system" | "en" | "ru" | "es"
var age_gate_confirmed: bool = false  # True once user confirmed age ≥ 18 (classic-only, see age_gate.gd)
var theme_name: String = "supercell"  # Active visual theme id (ThemeManager reads on _ready)
var app_instance_id: String = ""  # Stable Firebase Remote Config client id; generated once on first launch
## Player-toggleable settings persisted in save file. Currently only sound_fx
## and vibration have UI controls / runtime consumers — music / casino_ambient /
## game_speed / auto_hold were declared for a never-built settings menu and
## have been removed (Phase 6 will reintroduce them with actual consumers).
var settings := {
	"sound_fx": true,
	"music": true,
	"vibration": true,
}


var _glyphs: Dictionary = {}  # "0".."9", ",", ".", "chip", "K", "M" → Texture2D
const GLYPH_PATH := "res://assets/textures/glyphs/"
const _DEFAULT_CHIP_PATH := "res://assets/textures/glyphs/glyph_chip.svg"


func _ready() -> void:
	_load_glyphs()
	load_game()


## Swap the "chip" glyph used by every currency display (paytable rows
## not included — they have their own coin nodes). ThemeManager calls
## this when the active theme changes so multi-hand / spin / lobby /
## shop currency widgets pick up the supercell coin instead of the
## classic chip without needing to rebuild every dictionary.
##
## Pass an empty string to revert to the default classic chip.
func set_chip_texture(path: String) -> void:
	var resolved := path if path != "" else _DEFAULT_CHIP_PATH
	if not ResourceLoader.exists(resolved):
		resolved = _DEFAULT_CHIP_PATH
	var tex: Texture2D = load(resolved) as Texture2D
	if tex == null:
		return
	if _glyphs.has("chip") and _glyphs["chip"] == tex:
		return
	_glyphs["chip"] = tex


## Returns the currently active chip / coin texture. Anywhere in the
## codebase that used to do `load("res://assets/textures/glyphs/glyph_chip.svg")`
## directly should call this instead — picks up the supercell coin
## automatically once ThemeManager has switched the theme.
func get_chip_texture() -> Texture2D:
	if _glyphs.has("chip"):
		return _glyphs["chip"]
	if ResourceLoader.exists(_DEFAULT_CHIP_PATH):
		return load(_DEFAULT_CHIP_PATH)
	return null


## Walk a currency display's HBox and re-point any chip TextureRect to
## the current `_glyphs["chip"]`. Use after a theme switch to upgrade
## already-rendered displays in place without rebuilding their text
## children. The chip is conventionally the first child in the box.
func refresh_chip_in_box(cd: Dictionary) -> void:
	if not _glyphs.has("chip"):
		return
	var new_tex: Texture2D = _glyphs["chip"]
	var box: HBoxContainer = cd.get("box", null) as HBoxContainer
	if not is_instance_valid(box):
		return
	if box.get_child_count() == 0:
		return
	var first := box.get_child(0)
	if not (first is TextureRect):
		return
	var tr: TextureRect = first as TextureRect
	if tr.texture == new_tex:
		return
	tr.texture = new_tex
	# Recompute aspect-correct width so the new icon doesn't squish.
	var h: int = int(cd.get("glyph_h", 16))
	var aspect: float = new_tex.get_width() / maxf(new_tex.get_height(), 1.0)
	tr.custom_minimum_size = Vector2(int(ceili(h * aspect)), h)


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
## Pass `outline_color` with non-zero alpha to render every glyph with a
## stroked silhouette via res://shaders/glyph_outline.gdshader — used by
## the lobby cash readout to make the digits pop on the bright top bar.
func create_currency_display(glyph_h: int, color: Color, outline_color: Color = Color(0, 0, 0, 0), outline_size: float = 2.0) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return {
		"box": box,
		"glyph_h": glyph_h,
		"color": color,
		"outline_color": outline_color,
		"outline_size": outline_size,
	}


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
	var outline_col: Color = cd.get("outline_color", Color(0, 0, 0, 0))
	var outline_sz: float = cd.get("outline_size", 2.0)
	if show_chip:
		_add_glyph(box, "chip", h, col, outline_col, outline_sz)
	for ch in text:
		if ch in _glyphs:
			_add_glyph(box, ch, h, col, outline_col, outline_sz)


func _add_glyph(box: HBoxContainer, key: String, h: int, color: Color, outline_color: Color = Color(0, 0, 0, 0), outline_size: float = 2.0) -> void:
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
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Outline shader applies only to digit/punct/K/M glyphs — those are
	# monochrome SVGs (white pixels + alpha) that pair cleanly with a
	# black silhouette. The chip glyph is multi-color (yellow body, dark
	# letter, optional shadow) and looks compressed under the dilated
	# alpha mask, so it stays on the regular modulate path.
	if outline_color.a > 0.0 and key != "chip":
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/glyph_outline.gdshader")
		mat.set_shader_parameter("body_color", color)
		mat.set_shader_parameter("outline_color", outline_color)
		mat.set_shader_parameter("outline_size", outline_size)
		tex_rect.material = mat
		tex_rect.modulate = Color.WHITE
	elif key == "chip":
		# Chip glyph is a full-color PNG (yellow body + dark "C" letter
		# on supercell, ring sprite on classic). Modulating it by the
		# digits' color (e.g. dark brown for picker buttons) crushes the
		# multi-color rendering into a near-black blob — keep it pristine
		# white-modulated so its native colors show through.
		tex_rect.modulate = Color.WHITE
	else:
		tex_rect.modulate = color
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


## Format number shortened with 3-significant-figure precision and TRUNCATION
## (no rounding up). Preserves enough digits that abbreviated 1,892,123 reads
## as "1.89M", not "2M" — and 1,892 reads as "1.89K", not "2K".
##   < 1,000          → "999"      (no abbreviation)
##   1,000..9,999     → "1.89K"    (2 decimals, truncated)
##   10,000..99,999   → "12.3K"    (1 decimal, truncated)
##   100,000..999,999 → "123K"     (integer, truncated)
##   1M+              → same scheme with M suffix; M extends to billions
##                      ("1234M" rather than introduce a B glyph that the
##                      currency-display set doesn't ship).
static func format_short(n: int) -> String:
	var sign := "-" if n < 0 else ""
	var abs_n := absi(n)
	if abs_n >= 1_000_000:
		return sign + _abbrev_truncated(abs_n, 1_000_000, "M")
	if abs_n >= 1_000:
		return sign + _abbrev_truncated(abs_n, 1_000, "K")
	return sign + str(abs_n)


## Format `n / divisor` with `suffix` using 3 significant figures and
## floor-truncation so e.g. 1,892,123 / 1M = 1.892… → "1.89M" (never "2M").
## Trailing zeros after the decimal point are stripped — "1.50K" → "1.5K",
## "1.00K" → "1K", "12.0K" → "12K" — since a fixed-precision format that
## ends in zero gives no extra information to the player.
##   v in [100, 1000): integer, no decimals  → "234M"
##   v in [10, 100):   one decimal           → "12.3M" / "12M" if .0
##   v in [1, 10):     two decimals          → "1.89M" / "1.5M" / "1M"
static func _abbrev_truncated(abs_n: int, divisor: int, suffix: String) -> String:
	var v: float = float(abs_n) / float(divisor)
	if v >= 100.0:
		# >100K / >100M — three integer digits is plenty.
		return str(int(v)) + suffix
	if v >= 10.0:
		# 12.3 — one decimal. Multiply×10 + int() floors to tenths.
		var v10: int = int(v * 10.0)
		var tenths: int = v10 % 10
		if tenths == 0:
			return "%d%s" % [v10 / 10, suffix]
		return "%d.%d%s" % [v10 / 10, tenths, suffix]
	# 1.89 — two decimals. Multiply×100 + int() floors to hundredths.
	var v100: int = int(v * 100.0)
	var int_part: int = v100 / 100
	var frac: int = v100 % 100
	if frac == 0:
		return "%d%s" % [int_part, suffix]
	# Strip a trailing zero from the hundredths slot — "1.50" → "1.5".
	if frac % 10 == 0:
		return "%d.%d%s" % [int_part, frac / 10, suffix]
	return "%d.%02d%s" % [int_part, frac, suffix]


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
		"mode_id": mode_id,
		"mode_hand_counts": mode_hand_counts,
		"depth_hint_shown": depth_hint_shown,
		"tutor_shown": tutor_shown,
		"show_machine_stats": show_machine_stats,
		"last_gift_time": last_gift_time,
		"pack_claim_times": pack_claim_times,
		"ultra_multipliers": ultra_multipliers,
		"machine_stats": machine_stats,
		"language": language,
		"age_gate_confirmed": age_gate_confirmed,
		"theme_name": theme_name,
		"app_instance_id": app_instance_id,
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
		_seed_first_launch_defaults()
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
	mode_id = String(data.get("mode_id", "single_play"))
	var saved_mode_hands: Dictionary = data.get("mode_hand_counts", {})
	mode_hand_counts.clear()
	for key in saved_mode_hands:
		mode_hand_counts[str(key)] = int(saved_mode_hands[key])
	depth_hint_shown = bool(data.get("depth_hint_shown", false))
	tutor_shown = bool(data.get("tutor_shown", false))
	show_machine_stats = bool(data.get("show_machine_stats", false))
	last_gift_time = int(data.get("last_gift_time", 0))
	var saved_claims: Dictionary = data.get("pack_claim_times", {})
	pack_claim_times.clear()
	for key in saved_claims:
		pack_claim_times[str(key)] = int(saved_claims[key])
	ultra_multipliers = data.get("ultra_multipliers", {})
	var saved_stats: Dictionary = data.get("machine_stats", {})
	machine_stats.clear()
	for mk in saved_stats:
		var raw: Variant = saved_stats[mk]
		if raw is Dictionary and raw.has("best_rank"):
			# Legacy flat shape (variant_id → entry). Migrate under single_play.
			var bucket: Dictionary = machine_stats.get("single_play", {})
			bucket[str(mk)] = {
				"best_rank": int(raw.get("best_rank", 0)),
				"best_key": String(raw.get("best_key", "")),
				"score": int(raw.get("score", 0)),
			}
			machine_stats["single_play"] = bucket
			continue
		if not (raw is Dictionary):
			continue
		var inner: Dictionary = {}
		for vk in raw:
			var entry: Dictionary = raw[vk]
			inner[str(vk)] = {
				"best_rank": int(entry.get("best_rank", 0)),
				"best_key": String(entry.get("best_key", "")),
				"score": int(entry.get("score", 0)),
			}
		machine_stats[str(mk)] = inner
	language = String(data.get("language", "system"))
	age_gate_confirmed = bool(data.get("age_gate_confirmed", false))
	theme_name = String(data.get("theme_name", "supercell"))
	# Force-migrate any pre-release "classic" save to supercell so existing
	# tester installs don't get stuck on the hidden theme after update.
	if theme_name != "supercell":
		theme_name = "supercell"
	app_instance_id = String(data.get("app_instance_id", ""))
	var saved_settings: Dictionary = data.get("settings", {})
	for key in saved_settings:
		if key in settings:
			settings[key] = saved_settings[key]


## Called by load_game when no save file exists (fresh install / wiped data).
## Seeds first-launch defaults from configs/init_config.json + balance.json
## via ConfigManager. Then writes the seeded state to disk so subsequent
## launches skip this branch.
func _seed_first_launch_defaults() -> void:
	var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
	if cm == null:
		return

	credits = cm.get_starting_balance()
	speed_level = cm.get_default_speed()
	last_variant = cm.get_default_machine()

	# Map default_mode -> hand_count + ultra_vp + spin_poker flags.
	var default_mode: String = cm.get_default_mode()
	mode_id = default_mode
	match default_mode:
		"single_play":
			hand_count = 1; ultra_vp = false; spin_poker = false
		"triple_play":
			hand_count = 3; ultra_vp = false; spin_poker = false
		"five_play":
			hand_count = 5; ultra_vp = false; spin_poker = false
		"ten_play":
			hand_count = 10; ultra_vp = false; spin_poker = false
		"ultra_vp":
			hand_count = 5; ultra_vp = true; spin_poker = false
		"spin_poker":
			hand_count = 1; ultra_vp = false; spin_poker = true
		_:
			hand_count = 1; ultra_vp = false; spin_poker = false

	# Translate balance.modes.<m>.default_denomination_index -> denomination.
	var denoms: Array = cm.get_denominations(default_mode)
	var d_idx: int = clampi(cm.get_default_denomination_index(default_mode), 0, denoms.size() - 1)
	if denoms.size() > 0:
		denomination = int(denoms[d_idx])

	language = cm.get_default_locale()
	theme_name = cm.get_default_theme()

	# first_gift_delay_hours: shift last_gift_time so the first gift becomes
	# claimable exactly delay_hours after fresh install. delay=0 means ready
	# immediately, delay=N means wait N hours from now.
	var delay_hours: int = int(cm.init_config.get("first_gift_delay_hours", 0))
	var interval_hours: int = cm.get_gift_interval_hours()
	last_gift_time = int(Time.get_unix_time_from_system()) + (delay_hours - interval_hours) * 3600

	# Per-feature setting defaults (read from features.json -> feature_flags).
	settings["sound_fx"] = cm.is_feature_enabled("sound_fx_default", true)
	settings["vibration"] = cm.is_feature_enabled("vibration_default", true)

	save_game()


## Single global bet level shared across all modes (Single / Triple /
## Five / Ten / Ultra VP / Spin). Picking a bet in one mode applies
## everywhere on the next scene load. `mode_id` is kept in the signature
## for call-site compatibility but ignored — the per-mode `bet_levels`
## dict is mirrored to the same global value for save-file legacy.
func get_bet_level(_mode_id: String = "") -> int:
	return bet_level


func set_bet_level(_mode_id: String, level: int) -> void:
	bet_level = level
	# Mirror into every known per-mode slot so any legacy reader sees
	# the same global value — no mode "remembers" its own stale bet.
	for key in bet_levels:
		bet_levels[key] = level
	save_game()


func mark_tutor_shown() -> void:
	if tutor_shown:
		return
	tutor_shown = true
	save_game()


func set_show_machine_stats(state: bool) -> void:
	if show_machine_stats == state:
		return
	show_machine_stats = state
	save_game()
	show_machine_stats_changed.emit(state)


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


## Per-machine lobby stats — best combo (highest HandRank ever) + cumulative
## payout sum. Called from game / multi_hand_game / spin_poker_game once a
## round resolves; the lobby supercell card reads via get_machine_stats().
func record_machine_win(p_mode_id: String, variant_id: String, rank: int, paytable_key: String, payout: int) -> void:
	if variant_id == "" or p_mode_id == "":
		return
	var bucket: Dictionary = machine_stats.get(p_mode_id, {})
	var entry: Dictionary = bucket.get(variant_id, {
		"best_rank": 0, "best_key": "", "score": 0,
	})
	if rank > int(entry.get("best_rank", 0)) and paytable_key != "":
		entry["best_rank"] = rank
		entry["best_key"] = paytable_key
	entry["score"] = int(entry.get("score", 0)) + maxi(payout, 0)
	bucket[variant_id] = entry
	machine_stats[p_mode_id] = bucket
	save_game()


func get_machine_stats(p_mode_id: String, variant_id: String) -> Dictionary:
	var bucket: Dictionary = machine_stats.get(p_mode_id, {})
	return bucket.get(variant_id, {
		"best_rank": 0, "best_key": "", "score": 0,
	})


func deduct_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	save_game()
	return true
