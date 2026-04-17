extends PanelContainer

signal play_pressed(variant_id: String)

var variant_id: String = ""
var locked: bool = false
var _bg_color: Color = Color(0.75, 0.12, 0.12)
var _icon_path: String = ""

@onready var _icon_tex: TextureRect = %MachineIcon
@onready var _lock_overlay: ColorRect = %LockOverlay


func setup(p_variant_id: String, p_icon_path: String, p_color: Color, _p_accent: Color, _rtp: float, _mini_info: String, p_locked: bool = false) -> void:
	variant_id = p_variant_id
	locked = p_locked
	_bg_color = p_color
	_icon_path = p_icon_path

	if is_node_ready():
		_apply_setup(p_locked)
	else:
		ready.connect(func() -> void: _apply_setup(p_locked), CONNECT_ONE_SHOT)


func _apply_setup(p_locked: bool) -> void:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = _bg_color if not p_locked else Color(0.30, 0.05, 0.05)
	card_style.set_border_width_all(0)
	card_style.set_corner_radius_all(0)
	card_style.anti_aliasing = false
	# Inset content so icons sit well inside the yellow inner frame (drawn at 12px)
	card_style.content_margin_left = 22
	card_style.content_margin_right = 22
	card_style.content_margin_top = 26
	card_style.content_margin_bottom = 26
	card_style.shadow_color = Color(0, 0, 0, 0.45)
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", card_style)

	if _icon_path != "" and ResourceLoader.exists(_icon_path):
		_icon_tex.texture = load(_icon_path)
	else:
		_icon_tex.texture = null

	# Gentle vertical float on the icon (decorative idle)
	call_deferred("_start_icon_float")

	_lock_overlay.visible = p_locked

	draw.connect(_draw_inner_border)

	mouse_filter = Control.MOUSE_FILTER_PASS
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not p_locked else Control.CURSOR_ARROW


func _start_icon_float() -> void:
	if not is_instance_valid(_icon_tex):
		return
	var base_y: float = _icon_tex.position.y
	var tw := create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var phase: float = float(get_index()) * 0.35
	tw.tween_interval(phase)
	tw.tween_property(_icon_tex, "position:y", base_y - 3.5, 1.2).from(base_y)
	tw.tween_property(_icon_tex, "position:y", base_y, 1.2)


func _draw_inner_border() -> void:
	var inner_rect := Rect2(Vector2(12, 12), size - Vector2(24, 24))
	draw_rect(inner_rect, Color("FFEC00"), false, 3.0)


var _press_pos := Vector2.ZERO
var _is_pressed := false


## Called by lobby_manager before transitioning to a game — plays a quick
## zoom-in on this card so the tap visually "becomes" the game screen.
func play_zoom_in(duration: float = 0.35) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, duration * 0.9) \
		.set_ease(Tween.EASE_IN)
	# Highlight ring
	var ring_tw := create_tween()
	ring_tw.tween_property(self, "modulate", Color(1.6, 1.6, 1.2, 1.0), duration * 0.4)
	ring_tw.tween_property(self, "modulate", Color(1.6, 1.6, 1.2, 0.0), duration * 0.5)

const TAP_MAX_DISTANCE := 12.0  # screen-space px; beyond this release is a drag, not a tap

func _on_gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.global_position
			_animate_press(true)
		else:
			_animate_press(false)
			# Cancel the tap if the lobby carousel absorbed a swipe gesture —
			# otherwise short-distance drags (pressed on a card, scrolled a bit,
			# released) would accidentally load the table.
			if _carousel_absorbed_swipe():
				return
			if event.global_position.distance_to(_press_pos) < TAP_MAX_DISTANCE:
				play_pressed.emit(variant_id)


func _carousel_absorbed_swipe() -> bool:
	for node in get_tree().get_nodes_in_group("lobby_manager"):
		if node.has_method("carousel_drag_moved") and node.carousel_drag_moved():
			return true
	return false


func _animate_press(down: bool) -> void:
	if down == _is_pressed:
		return
	_is_pressed = down
	pivot_offset = size / 2.0
	var target: Vector2 = Vector2(0.95, 0.95) if down else Vector2.ONE
	var duration: float = 0.07 if down else 0.11
	var tilt: float = deg_to_rad(randf_range(-3.0, 3.0)) if down else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", tilt, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	# Restore scale if mouse leaves the card mid-press (e.g. during a drag).
	if what == NOTIFICATION_MOUSE_EXIT and _is_pressed:
		_animate_press(false)
