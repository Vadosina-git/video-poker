extends PanelContainer

signal play_pressed(variant_id: String)

var variant_id: String = ""
var locked: bool = false

@onready var _name_label: Label = %MachineName
@onready var _lock_overlay: ColorRect = %LockOverlay


func setup(p_variant_id: String, p_name: String, p_color: Color, _p_accent: Color, _rtp: float, _mini_info: String, p_locked: bool = false) -> void:
	variant_id = p_variant_id
	locked = p_locked

	if is_node_ready():
		_apply_setup(p_name, p_locked)
	else:
		ready.connect(func() -> void: _apply_setup(p_name, p_locked), CONNECT_ONE_SHOT)


func _apply_setup(p_name: String, p_locked: bool) -> void:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.75, 0.12, 0.12)
	card_style.set_border_width_all(6)
	card_style.border_color = Color(0.1, 0.1, 0.3)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", card_style)

	_name_label.text = p_name.to_upper()
	_name_label.add_theme_font_size_override("font_size", 36)
	_name_label.add_theme_color_override("font_color", Color("FFEC00"))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 4)
	_name_label.add_theme_constant_override("shadow_offset_y", 4)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_lock_overlay.visible = p_locked
	if p_locked:
		card_style.bg_color = Color(0.35, 0.08, 0.08)

	draw.connect(_draw_inner_border)

	mouse_filter = Control.MOUSE_FILTER_PASS
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			for grandchild in child.get_children():
				if grandchild is Control:
					grandchild.mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not p_locked else Control.CURSOR_ARROW


func set_color(bg_color: Color) -> void:
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style = style.duplicate()
		style.bg_color = bg_color
		add_theme_stylebox_override("panel", style)
		queue_redraw()


func _draw_inner_border() -> void:
	var inner_rect := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_rect(inner_rect, Color(0.7, 0.6, 0.2), false, 2.0)


var _press_pos := Vector2.ZERO

func _on_gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		else:
			if event.position.distance_to(_press_pos) < 10:
				play_pressed.emit(variant_id)
