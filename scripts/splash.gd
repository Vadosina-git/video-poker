extends Control

const FADE_IN_SEC := 0.18
const FADE_OUT_SEC := 0.32
const NEXT_SCENE := "res://scenes/main.tscn"

# Reuse the supercell tutorial palette + animated bg so the splash and
# the tutor overlay read as the same family.
const BG_SHADER_PATH := "res://shaders/tutorial_bg.gdshader"
const TEXT_SHADER_PATH := "res://shaders/text_gradient.gdshader"
const BG_BASE_COLOR := Color(0, 0, 0, 0.90)
const BG_GLOW_COLOR := Color(0.18, 0.36, 0.50, 1.0)
const BG_SPEED := 0.15

# Tutorial slide-3 row 0 / row 2 gradient stops.
const TITLE_TOP_TOP := Color("00C7D1")    # teal
const TITLE_TOP_BOT := Color("46D100")    # green
const TITLE_BOT_TOP := Color("46D100")    # green
const TITLE_BOT_BOT := Color("D1B200")    # olive

# Bar sizing.
const BAR_WIDTH_PX := 520.0
const BAR_HEIGHT_PX := 18.0
const BAR_SPACING_PX := 64  # gap between title and bar

# Jerky fill schedule. Each entry = [target_percent, work_share, pause_share].
# work_share + pause_share are normalised so the total matches the
# configured splash_duration_sec. The pattern is intentionally uneven so
# the bar feels like it stalls on heavy chunks and bursts on cheap ones.
const FILL_STEPS := [
	[0.10, 0.6, 0.4],
	[0.13, 0.4, 1.6],
	[0.45, 1.0, 0.3],
	[0.50, 0.5, 1.4],
	[0.78, 0.9, 0.4],
	[0.84, 0.5, 1.7],
	[1.00, 0.8, 0.0],
]

var _bar_fill: ColorRect = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_background()
	var stack := _build_stack()
	add_child(stack)

	stack.modulate.a = 0.0
	var tin := stack.create_tween()
	tin.tween_property(stack, "modulate:a", 1.0, FADE_IN_SEC).set_ease(Tween.EASE_OUT)

	var hold: float = ConfigManager.get_animation("splash_duration_sec", 3.0)
	_animate_bar(hold)
	await get_tree().create_timer(hold).timeout

	var tout := create_tween()
	tout.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC).set_ease(Tween.EASE_IN)
	await tout.finished
	get_tree().change_scene_to_file(NEXT_SCENE)


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color.BLACK

	var sh: Shader = load(BG_SHADER_PATH)
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("base_color", BG_BASE_COLOR)
		mat.set_shader_parameter("glow_color", BG_GLOW_COLOR)
		mat.set_shader_parameter("speed", BG_SPEED)
		bg.material = mat
	add_child(bg)


func _build_stack() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	center.add_child(box)

	box.add_child(_make_line("VIDEO POKER", 132, TITLE_TOP_TOP, TITLE_TOP_BOT))
	box.add_child(_make_line("TRAINER", 132, TITLE_BOT_TOP, TITLE_BOT_BOT))

	# Spacer between title and bar.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, BAR_SPACING_PX)
	box.add_child(spacer)

	# Bar — frame + fill, centred via inner HBox with shrink.
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bar_row)
	bar_row.add_child(_build_bar())

	return center


func _make_line(text: String, font_size: int, top: Color, bottom: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var f := ThemeManager.font()
	if f != null:
		lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", font_size)

	var sh: Shader = load(TEXT_SHADER_PATH)
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color_top", top)
		mat.set_shader_parameter("color_bottom", bottom)
		mat.set_shader_parameter("rect_height", float(font_size))
		lab.material = mat
		lab.resized.connect(func() -> void:
			if lab.material is ShaderMaterial:
				(lab.material as ShaderMaterial).set_shader_parameter(
					"rect_height", maxf(lab.size.y, 1.0)
				)
		)
	else:
		lab.add_theme_color_override("font_color", top)
	return lab


func _build_bar() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(BAR_WIDTH_PX, BAR_HEIGHT_PX)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.55)
	st.border_color = ThemeManager.color("title_text", Color.WHITE)
	st.set_border_width_all(2)
	st.set_corner_radius_all(int(BAR_HEIGHT_PX * 0.5))
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)

	var track := Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(track)

	_bar_fill = ColorRect.new()
	_bar_fill.color = ThemeManager.color("title_text", Color.WHITE)
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_right = 0.0  # animated 0 → 1
	_bar_fill.anchor_bottom = 1.0
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_bar_fill)

	return frame


# Drives _bar_fill.anchor_right through FILL_STEPS, scaling the schedule's
# work + pause shares to fit the configured total duration.
func _animate_bar(total_sec: float) -> void:
	if _bar_fill == null:
		return
	var share_total: float = 0.0
	for s in FILL_STEPS:
		share_total += float(s[1]) + float(s[2])
	if share_total <= 0.0:
		return
	var unit_sec: float = total_sec / share_total

	var tw := _bar_fill.create_tween()
	for s in FILL_STEPS:
		var target: float = float(s[0])
		var work_sec: float = float(s[1]) * unit_sec
		var pause_sec: float = float(s[2]) * unit_sec
		if work_sec > 0.0:
			tw.tween_property(_bar_fill, "anchor_right", target, work_sec)
		else:
			tw.tween_callback(func() -> void:
				if is_instance_valid(_bar_fill):
					_bar_fill.anchor_right = target
			)
		if pause_sec > 0.0:
			tw.tween_interval(pause_sec)
