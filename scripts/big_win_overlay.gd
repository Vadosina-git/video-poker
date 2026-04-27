extends Node
## Autoload. Shows a full-screen BIG WIN / HUGE WIN celebration.
## Any game screen can call:
##   BigWinOverlay.show_if_qualifies(self, payout, total_bet)
## The classifier uses payout / total_bet (bet-normalized multiplier) so larger
## bets don't over-trigger the animation. Single source of truth.


const COUNTER_DURATION := 4.0
const COUNTER_HEIGHT := 130  # px tall glyphs

var _glyphs: Dictionary = {}
var _glyphs_theme_id: String = ""  # which theme cache was built for
var _overlay: Control = null
var _tap_ready := false


## Returns the path for a Big Win asset under the active theme's folder
## (assets/themes/<id>/big_win/<rel>). Each theme is expected to ship its
## own copy of every asset; there is no shared fallback.
func _theme_big_win_path(rel: String) -> String:
	return ThemeManager.theme_folder() + "big_win/" + rel


## Classify via ConfigManager, then show if the payout qualifies.
## `host` is the Control the overlay is parented to (the game screen).
func show_if_qualifies(host: Node, payout: int, total_bet: int) -> void:
	var level := ConfigManager.classify_big_win(payout, total_bet)
	if level == "none":
		return
	show_win(host, payout, level)


## Force-show (used by the debug cheat buttons in game.gd).
func show_win(host: Node, amount: int, level: String = "big") -> void:
	if is_instance_valid(_overlay):
		return
	if not is_instance_valid(host):
		return
	_load_glyphs()

	# 1) Lightning strikes four times.
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.85, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 998
	host.add_child(flash)
	var flash_tw := flash.create_tween()
	for i in 4:
		flash_tw.tween_property(flash, "color:a", 0.45, 0.07).set_ease(Tween.EASE_OUT)
		var decay: float = 0.32 if i == 3 else 0.12
		flash_tw.tween_property(flash, "color:a", 0.0, decay).set_ease(Tween.EASE_IN)
		if i < 3:
			flash_tw.tween_interval(0.07)
	flash_tw.tween_callback(flash.queue_free)

	# 2) Full-screen dimmed overlay that catches taps.
	_tap_ready = false
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 999
	host.add_child(overlay)
	_overlay = overlay

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var dim_tw := dim.create_tween()
	dim_tw.tween_property(dim, "color:a", 0.80, 0.4).set_ease(Tween.EASE_OUT)

	# 3) Coin rain layer — added LAST so it draws on top.
	var rain := Control.new()
	rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain.z_index = 1500
	rain.z_as_relative = false
	_spawn_coin_rain(rain)

	# 4) Decorative pattern behind the title.
	var pattern := TextureRect.new()
	pattern.texture = load(_theme_big_win_path("big_win_pattern.png"))
	pattern.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pattern.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.modulate.a = 0.0
	overlay.add_child(pattern)

	# 4b) Title image "BIG WIN" / "HUGE WIN".
	var title_path := _theme_big_win_path("huge_win.png" if level == "huge" else "big_win.png")
	var title := TextureRect.new()
	title.texture = load(title_path)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.modulate.a = 0.0
	title.scale = Vector2(0.3, 0.3)
	overlay.add_child(title)
	await get_tree().process_frame
	var tex_size: Vector2 = title.texture.get_size() if title.texture else Vector2(800, 300)
	var aspect: float = tex_size.x / maxf(tex_size.y, 1.0)
	var max_w: float = overlay.size.x * 0.55
	var max_h: float = overlay.size.y * 0.55
	var target_w: float = minf(max_w, max_h * aspect)
	var target_h: float = target_w / aspect
	title.custom_minimum_size = Vector2(target_w, target_h)
	title.size = title.custom_minimum_size
	title.pivot_offset = title.size * 0.5
	title.position = Vector2(
		overlay.size.x * 0.5 - title.size.x * 0.5,
		overlay.size.y * 0.32 - title.size.y * 0.5,
	)
	var tt := title.create_tween().set_parallel(true)
	tt.tween_property(title, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tt.tween_property(title, "scale", Vector2.ONE, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Pattern sizing: 80% viewport width, aspect preserved, centered on title.
	if pattern.texture:
		var p_tex: Vector2 = pattern.texture.get_size()
		var p_aspect: float = p_tex.y / maxf(p_tex.x, 1.0)
		var p_w: float = overlay.size.x * 0.80
		var p_h: float = p_w * p_aspect
		pattern.custom_minimum_size = Vector2(p_w, p_h)
		pattern.size = pattern.custom_minimum_size
		var title_center_y: float = title.position.y + title.size.y * 0.5
		pattern.position = Vector2(
			overlay.size.x * 0.5 - p_w * 0.5,
			title_center_y - p_h * 0.5,
		)
	var pt := pattern.create_tween()
	pt.tween_property(pattern, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

	# 5) Counter box.
	var counter_box := HBoxContainer.new()
	counter_box.add_theme_constant_override("separation", 0)
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(counter_box)
	# Build fixed-width slot pool based on the final value. All slots have
	# the same width (monospaced glyphs) and always reserve space; unused
	# slots are hidden via modulate.a = 0 so layout never shifts.
	_init_counter_slots(counter_box, amount)
	_update_counter(counter_box, 0)
	await get_tree().process_frame
	var counter_max_w: float = counter_box.size.x
	var gap: float = 12.0
	var counter_top: float = title.position.y + title.size.y + gap
	counter_box.position = Vector2(
		overlay.size.x * 0.5 - counter_max_w * 0.5,
		counter_top,
	)
	var counter_state := {"val": 0}
	var counter_tw := overlay.create_tween()
	counter_tw.tween_method(func(v: float) -> void:
		var ival := int(v)
		if ival != counter_state["val"]:
			counter_state["val"] = ival
			_update_counter(counter_box, ival)
	, 0.0, float(amount), COUNTER_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	counter_tw.tween_callback(func() -> void:
		_update_counter(counter_box, amount)
		_tap_ready = true
	)

	# 6) "tap to continue..." hint.
	var hint := Label.new()
	hint.text = "tap to continue..."
	hint.add_theme_font_size_override("font_size", 32)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -80
	hint.offset_top = -140
	overlay.add_child(hint)

	# Finally add rain on top of everything else.
	overlay.add_child(rain)

	var hint_tw := hint.create_tween()
	hint_tw.tween_interval(COUNTER_DURATION + 0.2)
	hint_tw.tween_property(hint, "modulate:a", 1.0, 0.4)
	hint_tw.tween_property(hint, "modulate:a", 0.4, 0.8).set_ease(Tween.EASE_IN_OUT)
	hint_tw.set_loops()
	hint_tw.tween_property(hint, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if not _tap_ready:
			return
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			_dismiss()
	)


func _dismiss() -> void:
	if not is_instance_valid(_overlay):
		return
	var ov := _overlay
	_overlay = null
	_tap_ready = false
	_counter_slots.clear()  # slots will be freed with the overlay subtree
	var tw := ov.create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ov.queue_free)


func _load_glyphs() -> void:
	# Cache is keyed by the theme id — if the player switched themes since
	# the last Big Win, we need to reload from the new theme's folder.
	var current_theme: String = ThemeManager.current_id
	if not _glyphs.is_empty() and current_theme == _glyphs_theme_id:
		return
	_glyphs.clear()
	_glyphs_theme_id = current_theme
	var names := {
		"0": "glyph_0.png", "1": "glyph_1.png", "2": "glyph_2.png",
		"3": "glyph_3.png", "4": "glyph_4.png", "5": "glyph_5.png",
		"6": "glyph_6.png", "7": "glyph_7.png", "8": "glyph_8.png",
		"9": "glyph_9.png", ",": "glyph_comma.png", ".": "glyph_dot.png",
		"chip": "glyph_chip.png", "K": "glyph_K.png", "M": "glyph_M.png",
	}
	for key in names:
		var path: String = _theme_big_win_path("glyphs/" + names[key])
		if ResourceLoader.exists(path):
			_glyphs[key] = load(path)


## Odometer-style counter. All slots are the same width (monospaced glyphs)
## and always contribute to HBox layout — unused slots use modulate.a = 0 so
## they still reserve space but don't render. Result: visible digits never
## move during the increment tween.
var _counter_slots: Array = []
## Number of slots = 1 (chip) + final formatted char count. Set once in show_win.
var _counter_total_slots: int = 0
## Pixel width of each slot (monospaced).
var _counter_slot_w: int = 0


## Initialise the slot pool for a specific max-value string. Call once before
## starting the increment tween. Builds N+1 equal-width slots in the HBox.
func _init_counter_slots(box: HBoxContainer, max_value: int) -> void:
	# Drop any stale refs from a previous overlay.
	_counter_slots.clear()
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	var final_text := SaveManager.format_money(max_value)
	_counter_total_slots = 1 + final_text.length()  # +1 for chip prefix
	var h: int = COUNTER_HEIGHT
	# Use the digit "0" glyph to define the slot width (monospaced digits).
	var ref_tex: Texture2D = _glyphs.get("0", null)
	if ref_tex:
		var aspect: float = ref_tex.get_width() / maxf(ref_tex.get_height(), 1.0)
		_counter_slot_w = int(ceili(h * aspect))
	else:
		_counter_slot_w = h
	for i in _counter_total_slots:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(1, 0.95, 0.25, 0.0)  # hidden by default
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.custom_minimum_size = Vector2(_counter_slot_w, h)
		box.add_child(tr)
		_counter_slots.append(tr)


func _update_counter(box: HBoxContainer, value: int) -> void:
	# If slots aren't built yet (defensive), build now using the current value.
	if _counter_slots.is_empty():
		_init_counter_slots(box, value)

	var visible_color := Color(1, 0.95, 0.25, 1)
	var hidden_color := Color(1, 0.95, 0.25, 0.0)
	var text := SaveManager.format_money(value)
	# Layout strategy: total width stays fixed (final amount) so the
	# already-visible digits don't shift as the count grows. The chip is
	# glued to the LEFT of the leftmost visible digit — its slot index
	# moves left as the number gains characters, never leaving a gap.
	#
	# Slot map for total_slots = N+1, current digit count = D:
	#   pad        = N - D                  (hidden leading slots)
	#   slots 0..pad-1     → hidden
	#   slot  pad          → chip
	#   slots pad+1..pad+D → digits left→right
	var digit_slots: int = _counter_total_slots - 1
	var pad: int = digit_slots - text.length()
	var chip_idx: int = pad  # one slot to the left of first digit
	for i in _counter_slots.size():
		var tr: TextureRect = _counter_slots[i]
		if not is_instance_valid(tr):
			continue
		if i == chip_idx:
			tr.texture = _glyphs.get("chip", null)
			tr.modulate = visible_color
			continue
		if i < chip_idx:
			tr.modulate = hidden_color
			continue
		var text_idx: int = i - chip_idx - 1
		if text_idx < 0 or text_idx >= text.length():
			tr.modulate = hidden_color
			continue
		var ch: String = text[text_idx]
		if ch in _glyphs:
			tr.texture = _glyphs[ch]
			tr.modulate = visible_color
		else:
			tr.modulate = hidden_color


func _spawn_coin_rain(layer: Control) -> void:
	var coin_timer := Timer.new()
	coin_timer.wait_time = 0.12
	coin_timer.autostart = true
	layer.add_child(coin_timer)
	coin_timer.timeout.connect(func() -> void:
		if not is_instance_valid(layer) or not is_instance_valid(_overlay):
			return
		_spawn_single_coin(layer)
	)
	var confetti_timer := Timer.new()
	confetti_timer.wait_time = 0.035
	confetti_timer.autostart = true
	layer.add_child(confetti_timer)
	confetti_timer.timeout.connect(func() -> void:
		if not is_instance_valid(layer) or not is_instance_valid(_overlay):
			return
		_spawn_confetti_flake(layer)
	)


func _spawn_confetti_flake(layer: Control) -> void:
	var flake := ColorRect.new()
	var sz_w: int = randi_range(6, 14)
	var sz_h: int = randi_range(14, 28)
	flake.size = Vector2(sz_w, sz_h)
	flake.custom_minimum_size = flake.size
	flake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flake.pivot_offset = flake.size * 0.5
	var palette := [
		Color(1.0, 0.85, 0.2),
		Color(1.0, 0.65, 0.1),
		Color(0.95, 0.95, 0.35),
		Color(0.4, 0.7, 1.0),
		Color(0.95, 0.3, 0.5),
	]
	flake.color = palette[randi() % palette.size()]
	var w: float = layer.size.x
	var h: float = layer.size.y
	flake.position = Vector2(randf_range(0, w - sz_w), -sz_h)
	flake.rotation = randf_range(-PI, PI)
	layer.add_child(flake)
	var duration: float = randf_range(1.4, 2.4)
	var tw := flake.create_tween().set_parallel(true)
	tw.tween_property(flake, "position:y", h + 40, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(flake, "position:x", flake.position.x + randf_range(-120, 120), duration)
	tw.tween_property(flake, "rotation", flake.rotation + randf_range(-TAU * 2, TAU * 2), duration)
	tw.chain().tween_callback(flake.queue_free)


func _spawn_single_coin(layer: Control) -> void:
	var chip_tex: Texture2D = _glyphs.get("chip", null)
	if chip_tex == null:
		return
	var tr := TextureRect.new()
	# IMPORTANT: set expand_mode BEFORE size — default EXPAND_KEEP_SIZE uses
	# the texture's native size as the min size, clamping any smaller size up.
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = chip_tex
	var sz: int = randi_range(48, 96)
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.size = Vector2(sz, sz)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = Color(1, 0.95, 0.3, 1)
	tr.pivot_offset = Vector2(sz, sz) * 0.5
	# Keep coins off the central band where the BIG WIN title sits.
	var w: float = layer.size.x
	var h: float = layer.size.y
	var x_pos: float
	if randf() < 0.5:
		x_pos = randf_range(0, w * 0.30 - sz)
	else:
		x_pos = randf_range(w * 0.70, w - sz)
	tr.position = Vector2(x_pos, -sz)
	layer.add_child(tr)
	var duration: float = randf_range(1.6, 2.6)
	var tw := tr.create_tween().set_parallel(true)
	tw.tween_property(tr, "position:y", h + 40, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(tr, "position:x", tr.position.x + randf_range(-60, 60), duration)
	tw.tween_property(tr, "rotation", randf_range(-TAU, TAU), duration)
	tw.chain().tween_callback(tr.queue_free)
