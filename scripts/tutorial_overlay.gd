class_name TutorialOverlay
extends Control
## First-launch tutorial. Three non-interactive slides walking the player
## through the deal/draw flow. Tap anywhere to advance; after the third
## slide is fully shown, tapping marks `SaveManager.tutor_shown = true`
## and dismisses.
##
## Gating (see `should_show`): SaveManager.tutor_shown must be false,
## ConfigManager.tutorial_enabled flag must be true, and the active
## ThemeManager theme must ship `tutor/tutor_girl1.png` (resource gate
## that automatically excludes themes without illustrations — currently
## only supercell ships them).

signal tutorial_finished

const SHADER_PATH := "res://shaders/text_gradient.gdshader"
const BG_SHADER_PATH := "res://shaders/tutorial_bg.gdshader"
# Slide 1 character entrance: brief delay so the dim has time to settle,
# then a snappy slide-in from off-screen. Sharp deceleration via EXPO.
const ENTRANCE_DELAY := 0.30
const ENTRANCE_DURATION := 0.55
# Slide swap is intentionally near-instant — only a quick cross-fade so
# the figures don't pop. No scaling, no wobble, no idle motion.
const SWAP_DURATION := 0.18
const FINAL_FADE := 0.35

# Gradient stops sampled from the supplied design references.
const C_TEAL := Color("00C7D1")
const C_GREEN := Color("46D100")
const C_OLIVE := Color("D1B200")
const C_CREAM := Color("FFF1B9")
const C_LIME := Color("9DFF00")

# Identical character rect on every slide so the girl never jumps in
# size or position when slides cross-fade. Right edge stops at 0.34 so
# the slide-3 illustration grid (which begins at 0.36) and slide-4 tile
# grid (0.42) clear it without overlap.
const GIRL_ANCHOR_LEFT := 0.02
const GIRL_ANCHOR_RIGHT := 0.34
const GIRL_ANCHOR_TOP := 0.10
const GIRL_ANCHOR_BOTTOM := 0.74

var _shader: Shader = null
var _content: Control = null
var _slides: Array[Control] = []
var _girls: Array[TextureRect] = []
var _current: int = -1
var _input_locked: bool = true
# Slide index that the overlay should land on after build. 0 = full
# entrance flow with girl-1 sliding in from off-screen; >0 = direct
# fade-in at the requested slide (used by the in-game TUTOR button).
var _start_index: int = 0


## Returns true when the tutorial should be shown right now. Cheap to call
## from main.gd — does not load any heavy assets, just a save flag, a
## config flag, and a single ResourceLoader.exists() probe.
static func should_show() -> bool:
	if SaveManager.tutor_shown:
		return false
	if not ConfigManager.is_feature_enabled("tutorial_enabled", true):
		return false
	var probe := ThemeManager.theme_folder() + "tutor/tutor_girl1.png"
	return ResourceLoader.exists(probe)


## Build a TUTOR button styled identically to `speed_btn`, insert it
## just to the left of speed_btn in the same parent container, and wire
## up: (a) tap → present tutorial starting at slide 2; (b) round-state
## driven enable/disable via the supplied `manager`'s `state_changed`
## signal. `manager` must expose a state enum with IDLE = 0 and
## WIN_DISPLAY = 5 (true for GameManager / MultiHandManager /
## SpinPokerManager — verified at the manager class level).
##
## Returns the new button (or null if speed_btn is unparented). Caller
## holds the reference so it can refresh the label on language switch.
static func attach_tutor_button(speed_btn: Button, manager: Object) -> Button:
	if speed_btn == null or not is_instance_valid(speed_btn):
		return null
	var bar: Node = speed_btn.get_parent()
	if bar == null:
		return null
	var btn := Button.new()
	btn.text = Translations.tr_key("controls.tutor")
	var f: Font = ThemeManager.font()
	if f != null:
		btn.add_theme_font_override("font", f)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.custom_minimum_size = speed_btn.custom_minimum_size
	btn.focus_mode = Control.FOCUS_NONE
	# Mirror the speed button's stylebox (PNG plate or flat fill) across
	# every state. Using the *same* stylebox instance keeps ThemeManager
	# theme-switches in sync — when speed_btn's plate updates, the tutor
	# button picks it up automatically.
	for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
		var src := speed_btn.get_theme_stylebox(slot)
		if src != null:
			btn.add_theme_stylebox_override(slot, src)
	bar.add_child(btn)
	bar.move_child(btn, speed_btn.get_index())

	btn.pressed.connect(func() -> void:
		var host: Node = btn.get_tree().current_scene
		if host == null:
			host = bar
		# Guard against double-tap stacking the overlay.
		for child in host.get_children():
			if child is TutorialOverlay:
				return
		TutorialOverlay.present(host, 1)
	)

	if manager != null and manager.has_signal("state_changed"):
		manager.state_changed.connect(func(new_state: int) -> void:
			if not is_instance_valid(btn):
				return
			# IDLE (0) and WIN_DISPLAY (5) are the only states where the
			# player isn't actively mid-round — only enable the button
			# there, disable everywhere else.
			btn.disabled = not (new_state == 0 or new_state == 5)
		)
	return btn


## Build and parent the overlay onto `host`. Returns the overlay so the
## caller can `await overlay.tutorial_finished` if needed. Safe to call
## even when assets are missing — `should_show()` is the gate.
##
## `start_index` defaults to 0 (first-launch flow with the girl-1 slide
## entrance animation). The in-game TUTOR button passes 1 to skip
## straight to slide 2 — matching the spec that the cheat re-shows the
## tutorial "starting from the second slide".
static func present(host: Node, start_index: int = 0) -> TutorialOverlay:
	var overlay := TutorialOverlay.new()
	host.add_child(overlay)
	overlay._start_index = start_index
	overlay._build()
	return overlay


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 2000
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _build() -> void:
	_shader = load(SHADER_PATH) as Shader
	var folder := ThemeManager.theme_folder() + "tutor/"

	# Translucent backdrop with a slow drifting glow — lobby behind stays
	# visible at ~22% so the player feels overlaid, not detached. Glow
	# motion is shader-driven (TIME) so there are no per-frame tweens.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.WHITE  # shader fully overrides COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_shader: Shader = load(BG_SHADER_PATH) as Shader
	if bg_shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = bg_shader
		mat.set_shader_parameter("base_color", Color(0, 0, 0, 0.90))
		mat.set_shader_parameter("glow_color", Color(0.18, 0.36, 0.50, 1.0))
		mat.set_shader_parameter("speed", 0.15)
		bg.material = mat
	add_child(bg)

	# Inner safe-area-respecting holder. Texts and characters inset off
	# notch / home indicator; the black bg above stays full-bleed.
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	SafeAreaManager.apply_offsets(_content, "all")

	_slides.append(_build_slide_simple(folder, 1))
	_slides.append(_build_slide_simple(folder, 2))
	_slides.append(_build_slide_three(folder))
	_slides.append(_build_slide_four(folder))
	for s in _slides:
		s.visible = false
		s.modulate.a = 0.0
		_content.add_child(s)

	# Defer to next frame so layout has run and girl rects are sized.
	call_deferred("_show_slide_at", _start_index)


func _build_slide_simple(folder: String, index: int) -> Control:
	var slide := Control.new()
	slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Single shared rect across all four slides — see GIRL_ANCHOR_*.
	var girl := _make_girl(folder + "tutor_girl%d.png" % index)
	girl.anchor_left = GIRL_ANCHOR_LEFT
	girl.anchor_right = GIRL_ANCHOR_RIGHT
	girl.anchor_top = GIRL_ANCHOR_TOP
	girl.anchor_bottom = GIRL_ANCHOR_BOTTOM
	slide.add_child(girl)
	_girls.append(girl)

	var vb := VBoxContainer.new()
	vb.anchor_left = 0.38
	vb.anchor_right = 0.96
	vb.anchor_top = 0.28
	vb.anchor_bottom = 0.62
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(vb)

	# Slide 1+2 follow the same gradient pair on both lines per references.
	vb.add_child(_make_grad_label(
		Translations.tr_key("tutor.slide%d_l1" % index), 64, C_TEAL, C_GREEN))
	vb.add_child(_make_grad_label(
		Translations.tr_key("tutor.slide%d_l2" % index), 60, C_TEAL, C_GREEN))

	# Slide 1 only: subdued legal-style disclaimer in the bottom-left so
	# the player understands up-front this is a trainer, not a gambling
	# product. Subtle styling — low opacity, small font, no gradient.
	if index == 1:
		slide.add_child(_make_disclaimer_label())

	slide.add_child(_make_corner_hint("tutor.tap_to_continue"))
	return slide


func _make_disclaimer_label() -> Label:
	var lab := Label.new()
	lab.text = Translations.tr_key("tutor.disclaimer")
	var f: Font = ThemeManager.font()
	if f != null:
		lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor horizontally under the girl rect (uses GIRL_ANCHOR_*).
	# Vertically: just below the girl, leaving a small gap above the
	# bottom-edge icons of the lobby behind the dim.
	lab.anchor_left = GIRL_ANCHOR_LEFT
	lab.anchor_right = GIRL_ANCHOR_RIGHT
	lab.anchor_top = GIRL_ANCHOR_BOTTOM
	lab.anchor_bottom = GIRL_ANCHOR_BOTTOM
	lab.offset_left = 0
	lab.offset_right = 0
	lab.offset_top = 16
	lab.offset_bottom = 120
	return lab


func _build_slide_three(folder: String) -> Control:
	var slide := Control.new()
	slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Character — slightly smaller and pushed up so the three illustration
	# rows + their text counterparts have more vertical real estate.
	var girl := _make_girl(folder + "tutor_girl3.png")
	girl.anchor_left = GIRL_ANCHOR_LEFT
	girl.anchor_right = GIRL_ANCHOR_RIGHT
	girl.anchor_top = GIRL_ANCHOR_TOP
	girl.anchor_bottom = GIRL_ANCHOR_BOTTOM
	slide.add_child(girl)
	_girls.append(girl)

	# 2-column grid: text lines on the left, illustration rows on the
	# right. GridContainer keeps each text aligned with its hand image.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.anchor_left = 0.36
	grid.anchor_right = 0.97
	grid.anchor_top = 0.18
	grid.anchor_bottom = 0.78
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(grid)

	# Row 0: text 1 (teal→green) + hand 1
	var t1 := _make_grad_label(
		Translations.tr_key("tutor.slide3_l1"), 44, C_TEAL, C_GREEN)
	t1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(t1)
	grid.add_child(_make_illustration(folder + "tutor_hand.png"))

	# Row 1: spacer + arrow 1
	grid.add_child(_make_spacer())
	grid.add_child(_make_arrow(folder + "tutor_arrow_down1.png"))

	# Row 2: text 2 (green→olive) + hand 2
	var t2 := _make_grad_label(
		Translations.tr_key("tutor.slide3_l2"), 44, C_GREEN, C_OLIVE)
	t2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(t2)
	grid.add_child(_make_illustration(folder + "tutor_hand2.png"))

	# Row 3: spacer + arrow 2
	grid.add_child(_make_spacer())
	grid.add_child(_make_arrow(folder + "tutor_arrow_down2.png"))

	# Row 4: text 3 (cream→lime) + hand 3
	var t3 := _make_grad_label(
		Translations.tr_key("tutor.slide3_l3"), 44, C_CREAM, C_LIME)
	t3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(t3)
	grid.add_child(_make_illustration(folder + "tutor_hand3.png"))

	# Slide 3 is no longer the final slide — corner hint reverts to
	# "tap to continue…" since slide 4 follows.
	slide.add_child(_make_corner_hint("tutor.tap_to_continue"))
	return slide


# Compact mini-tile palette mirroring the supplied design reference.
# Order matches the screenshot left-to-right, row 1 then row 2.
const _SLIDE4_TILES := [
	{"key": "classic_draw", "color": "1F8B4C"},
	{"key": "mega_quads", "color": "C25B0E"},
	{"key": "kicker_blitz", "color": "C82F6E"},
	{"key": "aces_and_faces", "color": "5FA02C"},
	{"key": "joker_draw", "color": "7E3CB1"},
	{"key": "quad_hunt", "color": "C32A2A"},
	{"key": "double_quads", "color": "C9A21A"},
	{"key": "extreme_kicker", "color": "2A86C5"},
	{"key": "wild_twos", "color": "1FA68A"},
	{"key": "five_wilds", "color": "8C2DAA"},
]


func _build_slide_four(folder: String) -> Control:
	var slide := Control.new()
	slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var girl := _make_girl(folder + "tutor_girl4.png")
	girl.anchor_left = GIRL_ANCHOR_LEFT
	girl.anchor_right = GIRL_ANCHOR_RIGHT
	girl.anchor_top = GIRL_ANCHOR_TOP
	girl.anchor_bottom = GIRL_ANCHOR_BOTTOM
	slide.add_child(girl)
	_girls.append(girl)

	# Title + subtitle on the upper-right (matches reference layout).
	var header := VBoxContainer.new()
	header.anchor_left = 0.42
	header.anchor_right = 0.97
	header.anchor_top = 0.10
	header.anchor_bottom = 0.40
	header.add_theme_constant_override("separation", 14)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(header)
	header.add_child(_make_grad_label(
		Translations.tr_key("tutor.slide4_title"), 60, C_GREEN, C_GREEN))
	header.add_child(_make_grad_label(
		Translations.tr_key("tutor.slide4_subtitle"), 40, C_TEAL, C_GREEN))

	# 5×2 mini-tile grid — raised closer to the subtitle so it doesn't
	# pool at the bottom of the screen with empty space above.
	var grid := GridContainer.new()
	grid.columns = 5
	grid.anchor_left = 0.42
	grid.anchor_right = 0.97
	grid.anchor_top = 0.34
	grid.anchor_bottom = 0.74
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(grid)
	for tile_def in _SLIDE4_TILES:
		grid.add_child(_make_machine_tile(tile_def["key"], Color(tile_def["color"])))

	slide.add_child(_make_corner_hint("tutor.start_your_game"))
	return slide


## Renders a single mini machine tile for slide 4 — rounded rectangle
## fill, white outline, centered title + tagline. Pure procedural draw
## so we don't need per-tile PNGs.
func _make_machine_tile(key: String, fill: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 130)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	var title := Label.new()
	title.text = Translations.tr_key("tutor.tile.%s.title" % key)
	var f: Font = ThemeManager.font()
	if f != null:
		title.add_theme_font_override("font", f)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	var tagline := Label.new()
	tagline.text = Translations.tr_key("tutor.tile.%s.tagline" % key)
	if f != null:
		tagline.add_theme_font_override("font", f)
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tagline)
	return panel


func _make_girl(path: String) -> TextureRect:
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pivot will be set after layout so the wobble rotates around the
	# character's actual center, not (0,0).
	return tr


func _make_illustration(path: String) -> TextureRect:
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Mipmapped linear sampling — the source PNGs (504×162) are slightly
	# downscaled at the final layout size, and the project's default
	# canvas filter sometimes lands on NEAREST which makes the hand
	# illustrations read as fuzzy. Force linear+mipmaps for crispness.
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(0, 150)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _make_arrow(path: String) -> TextureRect:
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Source PNGs are 47×62. SHRINK_CENTER so the arrow doesn't stretch
	# vertically to fill the grid row's height (otherwise it visually
	# dominates the column when neighbouring hand rows expand).
	tr.custom_minimum_size = Vector2(0, 32)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _make_spacer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Build a Label with the gradient shader applied. `top` and `bottom` are
## the two color stops sampled vertically across the label's local rect.
func _make_grad_label(text: String, font_size: int, top: Color, bottom: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	var f: Font = ThemeManager.font()
	if f != null:
		lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("color_top", top)
	mat.set_shader_parameter("color_bottom", bottom)
	mat.set_shader_parameter("rect_height", 100.0)
	lab.material = mat
	# Re-push the height each time the label resizes so wrapped multi-line
	# labels span the gradient across their full vertical extent.
	lab.resized.connect(func() -> void:
		if lab.material is ShaderMaterial:
			(lab.material as ShaderMaterial).set_shader_parameter(
				"rect_height", maxf(lab.size.y, 1.0))
	)
	return lab


func _make_corner_hint(key: String) -> Label:
	var lab := Label.new()
	lab.text = Translations.tr_key(key)
	var f: Font = ThemeManager.font()
	if f != null:
		lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lab.offset_left = -560
	lab.offset_top = -100
	lab.offset_right = -40
	lab.offset_bottom = -36
	return lab


# ---------------------------------------------------------------- flow ---


func _show_slide_at(index: int) -> void:
	if _slides.is_empty():
		return
	index = clampi(index, 0, _slides.size() - 1)
	if index != 0:
		# In-game cheat path: skip the girl-1 entrance entirely. Show the
		# requested slide with a quick fade-in and unlock input once the
		# fade settles.
		_current = index
		var s: Control = _slides[index]
		s.visible = true
		s.modulate.a = 0.0
		var tw := s.create_tween()
		tw.tween_property(s, "modulate:a", 1.0, 0.25)
		tw.tween_callback(func() -> void:
			_input_locked = false
		)
		return
	_current = 0
	var slide: Control = _slides[0]
	slide.visible = true
	slide.modulate.a = 1.0

	# Girl 1 entrance: brief settle delay, then a snappy slide-in from
	# off the left edge. Smooth deceleration via EXPO EASE_OUT — fast
	# travel, decisive halt, no overshoot. Character stays still after
	# arrival (no idle wobble).
	await get_tree().process_frame
	var girl: TextureRect = _girls[0]
	var rest_pos := girl.position
	girl.position = Vector2(rest_pos.x - girl.size.x - 80.0, rest_pos.y)

	# Fade in everything except the girl (so her arrival reads).
	for child in slide.get_children():
		if child is TextureRect and child == girl:
			continue
		if child is Control:
			(child as Control).modulate.a = 0.0

	var fade := slide.create_tween()
	fade.tween_interval(0.05)
	fade.tween_callback(func() -> void:
		for child in slide.get_children():
			if child is TextureRect and child == girl:
				continue
			if child is Control:
				var c := child as Control
				c.create_tween().tween_property(c, "modulate:a", 1.0, 0.4)
	)

	var entrance := girl.create_tween()
	entrance.tween_interval(ENTRANCE_DELAY)
	entrance.tween_property(girl, "position", rest_pos, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	entrance.tween_callback(func() -> void:
		_input_locked = false
	)


func _advance_to(next_index: int) -> void:
	if next_index >= _slides.size():
		_finish()
		return
	_input_locked = true

	var prev_slide: Control = _slides[_current]
	var next_slide: Control = _slides[next_index]
	var prev_girl: TextureRect = _girls[_current]
	var next_girl: TextureRect = _girls[next_index]

	next_slide.visible = true
	next_slide.modulate.a = 0.0

	# Quick cross-fade only — no scale, no slide. Girls swap "instantly"
	# behind a small alpha blend so the change still reads as smooth.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(prev_slide, "modulate:a", 0.0, SWAP_DURATION) \
		.set_ease(Tween.EASE_IN)
	tw.tween_property(next_slide, "modulate:a", 1.0, SWAP_DURATION) \
		.set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		prev_slide.visible = false
		_current = next_index
		_input_locked = false
	)


func _finish() -> void:
	_input_locked = true
	SaveManager.mark_tutor_shown()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FINAL_FADE) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		emit_signal("tutorial_finished")
		queue_free()
	)


func _on_gui_input(event: InputEvent) -> void:
	if _input_locked:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if not pressed:
		return
	if _current >= _slides.size() - 1:
		_finish()
	else:
		_advance_to(_current + 1)


