extends Control

signal machine_selected(variant_id: String)

var MachineCardScene: PackedScene = null

## Per-machine config: ID + colors + lock flag.
## Display name and mini-description come from translations.json (keys
## `machine.{id}.name` / `machine.{id}.mini`).
const MACHINE_CONFIG := [
	{"id": "deuces_and_joker",   "color": Color(0.05, 0.5, 0.45), "accent": Color(0.8, 0.15, 0.15), "locked": false},
	{"id": "jacks_or_better",    "color": Color(0.2, 0.3, 0.8),   "accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "bonus_poker",        "color": Color(0.75, 0.15, 0.15),"accent": Color(0.75, 0.75, 0.8), "locked": false},
	{"id": "deuces_wild",        "color": Color(0.1, 0.7, 0.2),   "accent": Color(1.0, 0.9, 0.1),   "locked": false},
	{"id": "double_bonus",       "color": Color(0.6, 0.1, 0.1),   "accent": Color(0.75, 0.75, 0.8), "locked": false},
	{"id": "bonus_poker_deluxe", "color": Color(0.5, 0.1, 0.5),   "accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "double_double_bonus","color": Color(0.45, 0.05, 0.15),"accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "triple_double_bonus","color": Color(0.08, 0.08, 0.08),"accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "aces_and_faces",     "color": Color(0.1, 0.5, 0.2),   "accent": Color(0.75, 0.75, 0.8), "locked": false},
	{"id": "joker_poker",        "color": Color(0.4, 0.1, 0.6),   "accent": Color(1.0, 0.9, 0.1),   "locked": false},
]

@onready var _grid: GridContainer = %MachineGrid
@onready var _credits_label: Label = %LobbyCredits
@onready var _cash_label: Label = %CashLabel
@onready var _sidebar: VBoxContainer = %Sidebar

var _cash_cd: Dictionary

var _paytables: Dictionary = {}
var _machine_cards: Array = []

# Card background color by play mode id (all machines in a mode share one tint)
const MODE_CARD_COLORS := {
	"single_play": Color(0.72, 0.10, 0.10),   # red
	"triple_play": Color(0.22, 0.40, 0.78),   # light blue
	"five_play":   Color(0.10, 0.25, 0.65),   # medium blue
	"ten_play":    Color(0.04, 0.12, 0.45),   # dark blue
	"ultra_vp":    Color(0.06, 0.35, 0.15),   # dark green
	"spin_poker":  Color(0.38, 0.08, 0.55),   # purple
}

# Built from lobby_order.json via ConfigManager at _ready()
var PLAY_MODES: Array = []

const MODE_HANDS := {
	"single_play": 1, "triple_play": 3, "five_play": 5,
	"ten_play": 10, "ultra_vp": 5, "spin_poker": 1,
}

func _build_play_modes() -> void:
	PLAY_MODES.clear()
	var lobby_modes := ConfigManager.get_lobby_modes()
	for m in lobby_modes:
		if not m.get("enabled", true):
			continue
		var mode_id: String = m.get("id", "")
		PLAY_MODES.append({
			"id": mode_id,
			"label_key": m.get("label_key", "lobby.mode_" + mode_id),
			"hands": MODE_HANDS.get(mode_id, 1),
			"ultra_vp": mode_id == "ultra_vp",
			"spin_poker": mode_id == "spin_poker",
			"machines": m.get("machines", []),
		})
	if PLAY_MODES.size() == 0:
		# Fallback
		PLAY_MODES = [
			{"id": "single_play", "label_key": "lobby.mode_single_play", "hands": 1, "ultra_vp": false, "spin_poker": false, "machines": []},
		]
var _active_mode: int = 0
var _sidebar_buttons: Array[Button] = []


func _ready() -> void:
	MachineCardScene = load("res://scenes/lobby/machine_card.tscn")
	_build_play_modes()
	_paytables = Paytable.load_all()
	_apply_theme()
	_cash_label.text = Translations.tr_key("lobby.cash")
	_cash_cd = SaveManager.create_currency_display(32, Color.WHITE)
	_cash_label.get_parent().add_child(_cash_cd["box"])
	_cash_label.get_parent().move_child(_cash_cd["box"], _cash_label.get_index() + 1)
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_credits_label.text = Translations.tr_key("lobby.credits_fmt", [SaveManager.credits])
	_build_carousel()
	_build_settings_button()
	_build_gift_widget()


const SAFE_AREA_H := 40

func _apply_theme() -> void:
	$VBoxContainer.add_theme_constant_override("separation", 0)
	$VBoxContainer/SafeArea/ContentHBox.add_theme_constant_override("separation", 0)
	# Safe horizontal inset for sidebar + central panel (keeps them off-edge)
	var safe := $VBoxContainer/SafeArea as MarginContainer
	safe.add_theme_constant_override("margin_left", SAFE_AREA_H)
	safe.add_theme_constant_override("margin_right", SAFE_AREA_H)
	_style_top_bar()
	_style_grid_frame()
	_build_sidebar()
	var scroll := %GridScroll as ScrollContainer
	scroll.get_h_scroll_bar().modulate.a = 0
	_setup_drag_scroll(scroll)
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)


func _style_top_bar() -> void:
	var top_bar := $VBoxContainer/TopBar as HBoxContainer
	top_bar.custom_minimum_size = Vector2(0, 110)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.72, 0.06, 0.06)
	bg.content_margin_left = SAFE_AREA_H
	bg.content_margin_right = SAFE_AREA_H
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	bg.border_color = Color(0.22, 0.0, 0.0)
	bg.border_width_bottom = 4
	top_bar.add_theme_stylebox_override("panel", bg)
	top_bar.draw.connect(func() -> void:
		bg.draw(top_bar.get_canvas_item(), Rect2(Vector2.ZERO, top_bar.size))
	)
	top_bar.add_theme_constant_override("separation", 16)

	# CashLabel: white bold with thin black outline
	_cash_label.add_theme_font_size_override("font_size", 30)
	_cash_label.add_theme_color_override("font_color", Color.WHITE)
	_cash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_cash_label.add_theme_constant_override("outline_size", 3)

	# Wrap CashLabel in a yellow-bordered pill (currency box added later in _ready)
	var cash_idx := _cash_label.get_index()
	var cash_pill := PanelContainer.new()
	cash_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cash_style := StyleBoxFlat.new()
	cash_style.bg_color = Color(0.05, 0.03, 0.03)
	cash_style.set_border_width_all(4)
	cash_style.border_color = Color("FFEC00")
	cash_style.set_corner_radius_all(28)
	cash_style.content_margin_left = 22
	cash_style.content_margin_right = 22
	cash_style.content_margin_top = 4
	cash_style.content_margin_bottom = 4
	cash_pill.add_theme_stylebox_override("panel", cash_style)
	var cash_inner := HBoxContainer.new()
	cash_inner.add_theme_constant_override("separation", 14)
	cash_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	cash_pill.add_child(cash_inner)
	top_bar.add_child(cash_pill)
	top_bar.move_child(cash_pill, cash_idx)
	_cash_label.reparent(cash_inner)

	# Shop button next to cash pill — opens shop popup
	var shop_btn := TextureButton.new()
	var shop_tex: Texture2D = load("res://assets/textures/shop_button_lobby.svg")
	shop_btn.texture_normal = shop_tex
	shop_btn.ignore_texture_size = true
	shop_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	shop_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shop_btn.pressed.connect(_show_shop)
	_attach_press_effect(shop_btn)
	top_bar.add_child(shop_btn)
	top_bar.move_child(shop_btn, cash_pill.get_index() + 1)

	# Match shop button height to cash pill after layout (SVG aspect 60:46 kept)
	cash_pill.resized.connect(func() -> void:
		var h: float = cash_pill.size.y
		shop_btn.custom_minimum_size = Vector2(h * 60.0 / 46.0, h)
	)

	# Thick white "+" drawn geometrically — centered exactly on button rect
	shop_btn.draw.connect(func() -> void:
		var c: Vector2 = shop_btn.size / 2.0
		var arm: float = minf(shop_btn.size.x, shop_btn.size.y) * 0.22
		var th: float = arm * 0.6  # thickness
		shop_btn.draw_rect(Rect2(c.x - arm, c.y - th * 0.5, arm * 2.0, th), Color.WHITE)
		shop_btn.draw_rect(Rect2(c.x - th * 0.5, c.y - arm, th, arm * 2.0), Color.WHITE)
	)

	# Title "VIDEO POKER": yellow with red outline, in oval pill
	var title := %LobbyTitle as Label
	title.text = Translations.tr_key("lobby.title")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var title_idx := title.get_index()
	var title_pill := PanelContainer.new()
	title_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.24, 0.0, 0.0)
	title_style.set_border_width_all(4)
	title_style.border_color = Color("FFEC00")
	title_style.set_corner_radius_all(48)
	title_style.content_margin_left = 40
	title_style.content_margin_right = 40
	title_style.content_margin_top = 4
	title_style.content_margin_bottom = 4
	title_pill.add_theme_stylebox_override("panel", title_style)
	top_bar.add_child(title_pill)
	top_bar.move_child(title_pill, title_idx)
	title.reparent(title_pill)

	_credits_label.visible = false


func _style_grid_frame() -> void:
	var grid_margin := $VBoxContainer/SafeArea/ContentHBox/GridMargin as MarginContainer
	grid_margin.add_theme_constant_override("margin_left", 30)
	grid_margin.add_theme_constant_override("margin_right", 40)
	grid_margin.add_theme_constant_override("margin_top", 30)
	grid_margin.add_theme_constant_override("margin_bottom", 30)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.08, 0.48)
	frame_style.set_border_width_all(6)
	frame_style.border_color = Color("FFEC00")
	frame_style.set_corner_radius_all(0)
	frame_style.anti_aliasing = false
	grid_margin.draw.connect(func() -> void:
		frame_style.draw(grid_margin.get_canvas_item(), Rect2(Vector2.ZERO, grid_margin.size))
	)


func _build_sidebar() -> void:
	_sidebar.add_theme_constant_override("separation", 14)
	_sidebar.z_index = 5  # draw active tab's extended bg on top of the central panel's yellow border
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color.BLACK
	sb_style.content_margin_left = 18
	sb_style.content_margin_right = 18
	sb_style.content_margin_top = 24
	sb_style.content_margin_bottom = 24
	_sidebar.add_theme_stylebox_override("panel", sb_style)
	_sidebar.draw.connect(func() -> void:
		sb_style.draw(_sidebar.get_canvas_item(), Rect2(Vector2.ZERO, _sidebar.size))
	)
	_sidebar.custom_minimum_size.x = 253

	# Find active mode from SaveManager (match hands + ultra_vp flag)
	for j in PLAY_MODES.size():
		var m: Dictionary = PLAY_MODES[j]
		if m["hands"] == SaveManager.hand_count and m["ultra_vp"] == SaveManager.ultra_vp and m.get("spin_poker", false) == SaveManager.spin_poker:
			_active_mode = j
			break

	_sidebar_buttons.clear()
	for i in PLAY_MODES.size():
		var btn := Button.new()
		btn.text = Translations.tr_key(PLAY_MODES[i]["label_key"])
		btn.custom_minimum_size = Vector2(0, 76)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_sidebar_btn(btn, i == _active_mode)
		btn.pressed.connect(_on_mode_selected.bind(i))
		_sidebar.add_child(btn)
		_sidebar_buttons.append(btn)


func _on_mode_selected(index: int) -> void:
	_active_mode = index
	SaveManager.hand_count = PLAY_MODES[index]["hands"]
	SaveManager.ultra_vp = PLAY_MODES[index]["ultra_vp"]
	SaveManager.spin_poker = PLAY_MODES[index].get("spin_poker", false)
	SaveManager.save_game()
	for i in _sidebar_buttons.size():
		_style_sidebar_btn(_sidebar_buttons[i], i == _active_mode)
	_build_carousel()


func _style_sidebar_btn(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if active:
		# Active tab merges seamlessly into the central panel: bg matches panel
		# color, yellow border on 3 sides, flat right edge extending exactly
		# across the 6px yellow frame border (no visible overshoot into panel).
		style.bg_color = Color(0.05, 0.08, 0.48)  # matches central panel bg
		style.border_width_left = 6
		style.border_width_top = 6
		style.border_width_bottom = 6
		style.border_width_right = 0
		style.border_color = Color("FFEC00")
		style.corner_radius_top_left = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_right = 0
		style.expand_margin_right = 6
		style.anti_aliasing = false
	else:
		style.bg_color = Color(0.04, 0.06, 0.28)
		style.set_border_width_all(3)
		style.border_color = Color(0.32, 0.28, 0.08)
		style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	if active:
		# Active tab: no hover/pressed lightening (stays visually flat).
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
	else:
		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.15)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color("FFEC00") if active else Color(0.75, 0.65, 0.15))
	btn.add_theme_color_override("font_hover_color", Color("FFEC00"))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	btn.add_theme_constant_override("outline_size", 4)
	_attach_press_effect(btn)


## Attaches a quick scale-down/scale-up animation on press to a BaseButton.
## Works for Button, TextureButton, etc. Scales around center via pivot_offset.
func _attach_press_effect(btn: BaseButton, target_scale: float = 0.93) -> void:
	var update_pivot := func() -> void:
		btn.pivot_offset = btn.size / 2.0
	update_pivot.call()
	btn.resized.connect(update_pivot)
	btn.button_down.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(target_scale, target_scale), 0.07)
	)
	btn.button_up.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.11)
	)


var _drag_active := false
var _drag_start_x := 0.0
var _drag_scroll_start := 0
var _scroll_ref: ScrollContainer = null
var _inertia_tween: Tween = null
var _velocity_samples: Array = []  # [Vector2(x, time_sec)]
var _overscroll: float = 0.0        # rubber-band offset applied to grid

const OVERSCROLL_RESIST := 0.38
const MAX_OVERSCROLL := 100.0
const INERTIA_MULT := 0.28
const INERTIA_DURATION := 0.85
const SPRING_DURATION := 0.38
const MIN_INERTIA_VELOCITY := 120.0

# On web the mouse/touch-drag direction feels reversed vs. native; flip the
# drag delta + velocity sign so swipe gestures behave naturally in-browser.
var _drag_sign: float = -1.0 if OS.has_feature("web") else 1.0

# Content node whose position.x gets offset for the rubber-band effect
# (defaults to the lobby grid; swapped to the shop row when the shop opens).
var _drag_content: Control = null
# Callable returning the global rect where drag input is accepted.
# Lobby → the grid scroll; shop → the full shop overlay.
var _drag_hit_rect_fn: Callable = Callable()


func _setup_drag_scroll(scroll: ScrollContainer) -> void:
	_scroll_ref = scroll
	_drag_content = _grid
	_drag_hit_rect_fn = func() -> Rect2: return _scroll_ref.get_global_rect() if _scroll_ref else Rect2()


func _max_scroll() -> int:
	return maxi(int(_scroll_ref.get_h_scroll_bar().max_value) - int(_scroll_ref.size.x), 0)


func _set_overscroll(val: float) -> void:
	_overscroll = val
	if _drag_content and _scroll_ref:
		_drag_content.position.x = float(-_scroll_ref.scroll_horizontal) + val


func _calc_velocity() -> float:
	# Use samples from the last ~150 ms for a smoothed throw-velocity
	if _velocity_samples.size() < 2:
		return 0.0
	var last: Vector2 = _velocity_samples[_velocity_samples.size() - 1]
	var start: Vector2 = _velocity_samples[0]
	for s in _velocity_samples:
		var v: Vector2 = s
		if last.y - v.y <= 0.15:
			start = v
			break
	var dt: float = last.y - start.y
	if dt < 0.001:
		return 0.0
	return (start.x - last.x) / dt * _drag_sign  # px/sec; positive = fling forward


func _input(event: InputEvent) -> void:
	if _scroll_ref == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var scroll_rect: Rect2 = _drag_hit_rect_fn.call() if _drag_hit_rect_fn.is_valid() else _scroll_ref.get_global_rect()
			if scroll_rect.has_point(event.global_position):
				_drag_active = true
				_drag_start_x = event.global_position.x
				_drag_scroll_start = _scroll_ref.scroll_horizontal
				_velocity_samples.clear()
				_velocity_samples.append(Vector2(event.global_position.x, Time.get_ticks_msec() / 1000.0))
				if _inertia_tween and _inertia_tween.is_running():
					_inertia_tween.kill()
		else:
			if _drag_active:
				_drag_active = false
				_release_drag(_calc_velocity())
	elif event is InputEventMouseMotion and _drag_active:
		var now: float = Time.get_ticks_msec() / 1000.0
		_velocity_samples.append(Vector2(event.global_position.x, now))
		while _velocity_samples.size() > 8:
			_velocity_samples.pop_front()
		var delta: float = (_drag_start_x - event.global_position.x) * _drag_sign
		var target: int = _drag_scroll_start + int(delta)
		var m: int = _max_scroll()
		if target < 0:
			_scroll_ref.scroll_horizontal = 0
			_set_overscroll(minf(float(-target) * OVERSCROLL_RESIST, MAX_OVERSCROLL))
		elif target > m:
			_scroll_ref.scroll_horizontal = m
			_set_overscroll(maxf(float(m - target) * OVERSCROLL_RESIST, -MAX_OVERSCROLL))
		else:
			_scroll_ref.scroll_horizontal = target
			_set_overscroll(0.0)


func _release_drag(velocity: float) -> void:
	if _inertia_tween and _inertia_tween.is_running():
		_inertia_tween.kill()

	# Already overscrolled: spring back.
	if absf(_overscroll) > 0.5:
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, _overscroll, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		return

	if absf(velocity) < MIN_INERTIA_VELOCITY:
		return

	var current: int = _scroll_ref.scroll_horizontal
	var m: int = _max_scroll()
	var target: int = current + int(velocity * INERTIA_MULT)

	if target < 0:
		# Inertia carries past the left edge → overshoot then spring back.
		var excess: float = float(-target)
		var peak: float = -minf(excess * 0.35, MAX_OVERSCROLL)
		_scroll_ref.scroll_horizontal = 0
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, 0.0, peak, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_inertia_tween.tween_method(_set_overscroll, peak, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	elif target > m:
		var excess2: float = float(target - m)
		var peak2: float = minf(excess2 * 0.35, MAX_OVERSCROLL)
		_scroll_ref.scroll_horizontal = m
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, 0.0, -peak2, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_inertia_tween.tween_method(_set_overscroll, -peak2, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_inertia_tween = create_tween()
		_inertia_tween.tween_property(_scroll_ref, "scroll_horizontal", target, INERTIA_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


func _build_carousel() -> void:
	_machine_cards.clear()
	# Clear existing children
	for child in _grid.get_children():
		child.queue_free()
	# Get machine list for current mode
	var mode_machines: Array = []
	if _active_mode < PLAY_MODES.size():
		mode_machines = PLAY_MODES[_active_mode].get("machines", [])
	# Filter MACHINE_CONFIG by mode machines (or show all if empty)
	for config in MACHINE_CONFIG:
		var machine_id: String = config["id"]
		if mode_machines.size() > 0:
			var found := false
			for mm in mode_machines:
				if mm.get("id", "") == machine_id and mm.get("enabled", true):
					found = true
					break
			if not found:
				continue
		var card_node: PanelContainer = MachineCardScene.instantiate()
		_grid.add_child(card_node)
		var rtp: float = 0.0
		if machine_id in _paytables:
			rtp = _paytables[machine_id].rtp
		var mini_text := Translations.tr_key("machine.%s.mini" % machine_id)
		var icon_path := _icon_path_for(machine_id)
		card_node.setup(
			machine_id,
			icon_path,
			_mode_card_color(),
			config["accent"],
			rtp,
			mini_text,
			config["locked"],
		)
		card_node.play_pressed.connect(_on_play_pressed)
		_machine_cards.append(card_node)


func _mode_card_color() -> Color:
	if _active_mode >= 0 and _active_mode < PLAY_MODES.size():
		var mode_id: String = PLAY_MODES[_active_mode].get("id", "single_play")
		return MODE_CARD_COLORS.get(mode_id, MODE_CARD_COLORS["single_play"])
	return MODE_CARD_COLORS["single_play"]


# Icon filename prefix per variant_id (assets/lobby/{prefix}_{suffix}.png)
const ICON_VARIANT_PREFIX := {
	"jacks_or_better":     "jacks_or_better",
	"bonus_poker":         "bonus_poker",
	"bonus_poker_deluxe":  "bonus_deluxe",
	"double_bonus":        "double_bonus",
	"double_double_bonus": "double_double_bonus",
	"triple_double_bonus": "triple_double_bonus",
	"aces_and_faces":      "aces_faces",
	"deuces_wild":         "deuces_wild",
	"joker_poker":         "joker_poker",
	"deuces_and_joker":    "deuces_joker",
}

# Icon filename suffix per play-mode id
const ICON_MODE_SUFFIX := {
	"single_play": "classic",
	"triple_play": "multi",
	"five_play":   "multi",
	"ten_play":    "multi",
	"ultra_vp":    "ultra",
	"spin_poker":  "spin",
}


func _icon_path_for(variant_id: String) -> String:
	var prefix: String = ICON_VARIANT_PREFIX.get(variant_id, variant_id)
	var mode_id: String = "single_play"
	if _active_mode >= 0 and _active_mode < PLAY_MODES.size():
		mode_id = PLAY_MODES[_active_mode].get("id", "single_play")
	var suffix: String = ICON_MODE_SUFFIX.get(mode_id, "classic")
	return "res://assets/lobby/%s_%s.png" % [prefix, suffix]


func _on_play_pressed(variant_id: String) -> void:
	SaveManager.last_variant = variant_id
	machine_selected.emit(variant_id)


func refresh_credits() -> void:
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_credits_label.text = Translations.tr_key("lobby.credits_fmt", [SaveManager.credits])


# --- Settings popup ----------------------------------------------------------

var _settings_btn: BaseButton
var _settings_overlay: Control = null

func _build_settings_button() -> void:
	var tex_btn := TextureButton.new()
	tex_btn.texture_normal = load("res://assets/textures/menu_icon.svg")
	tex_btn.ignore_texture_size = true
	tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tex_btn.custom_minimum_size = Vector2(56, 56)
	tex_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	tex_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tex_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tex_btn.pressed.connect(_show_settings)
	_attach_press_effect(tex_btn)
	_settings_btn = tex_btn
	var top_bar := $VBoxContainer/TopBar as HBoxContainer
	top_bar.add_child(_settings_btn)


func _show_settings() -> void:
	if _settings_overlay:
		return
	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.z_index = 100
	add_child(_settings_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_settings()
	)
	_settings_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.18, 0.96)
	pstyle.set_border_width_all(3)
	pstyle.border_color = Color("FFEC00")
	pstyle.set_corner_radius_all(12)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_settings_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("settings.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	vbox.add_child(title)

	# LANGUAGE row — single button that opens a sub-popup with options.
	# Format: "LANGUAGE: English". Tapping it reveals the full picker.
	var current := Translations.get_saved_language()
	var lang_btn := Button.new()
	lang_btn.text = "%s: %s" % [
		Translations.tr_key("settings.language"),
		Translations.display_name_for_code(current),
	]
	lang_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(lang_btn, false)
	lang_btn.pressed.connect(_show_language_picker)
	vbox.add_child(lang_btn)

	# Vibration toggle
	var vib_on: bool = SaveManager.settings.get("vibration", true)
	var vib_btn := Button.new()
	vib_btn.text = "%s: %s" % [
		Translations.tr_key("settings.vibration"),
		Translations.tr_key("common.on") if vib_on else Translations.tr_key("common.off"),
	]
	vib_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(vib_btn, vib_on)
	vib_btn.pressed.connect(func() -> void:
		var new_val: bool = not SaveManager.settings.get("vibration", true)
		SaveManager.settings["vibration"] = new_val
		SaveManager.save_game()
		vib_btn.text = "%s: %s" % [
			Translations.tr_key("settings.vibration"),
			Translations.tr_key("common.on") if new_val else Translations.tr_key("common.off"),
		]
		_style_lang_btn(vib_btn, new_val)
	)
	vbox.add_child(vib_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = Translations.tr_key("settings.close")
	close_btn.custom_minimum_size = Vector2(280, 48)
	_style_lang_btn(close_btn, false)
	close_btn.pressed.connect(_hide_settings)
	vbox.add_child(close_btn)

	# Delete account button (red, at bottom)
	var del_btn := Button.new()
	del_btn.text = Translations.tr_key("settings.delete_account")
	del_btn.custom_minimum_size = Vector2(280, 48)
	var del_style := StyleBoxFlat.new()
	del_style.bg_color = Color(0.6, 0.1, 0.1)
	del_style.set_border_width_all(2)
	del_style.border_color = Color(0.8, 0.2, 0.2)
	del_style.set_corner_radius_all(8)
	del_btn.add_theme_stylebox_override("normal", del_style)
	var del_hover := del_style.duplicate()
	del_hover.bg_color = Color(0.7, 0.15, 0.15)
	del_btn.add_theme_stylebox_override("hover", del_hover)
	del_btn.add_theme_font_size_override("font_size", 18)
	del_btn.add_theme_color_override("font_color", Color.WHITE)
	del_btn.pressed.connect(_delete_account_step1)
	_attach_press_effect(del_btn)
	vbox.add_child(del_btn)


func _style_lang_btn(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.53) if active else Color(0.12, 0.12, 0.35)
	style.set_border_width_all(3)
	style.border_color = Color(0.85, 0.7, 0.2) if active else Color(0.3, 0.3, 0.5)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color("FFEC00") if active else Color.WHITE)
	_attach_press_effect(btn)


func _delete_account_step1() -> void:
	_hide_settings()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 110
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.8)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.3, 0.05, 0.05, 0.95)
	ps.set_border_width_all(3)
	ps.border_color = Color(0.8, 0.2, 0.2)
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 32
	ps.content_margin_right = 32
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var msg := Label.new()
	msg.text = Translations.tr_key("settings.delete_confirm_1")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size.x = 400
	vbox.add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)
	var cancel := Button.new()
	cancel.text = Translations.tr_key("settings.delete_cancel")
	cancel.custom_minimum_size = Vector2(140, 44)
	_style_lang_btn(cancel, false)
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(cancel)
	var cont := Button.new()
	cont.text = Translations.tr_key("settings.delete_continue")
	cont.custom_minimum_size = Vector2(140, 44)
	_style_lang_btn(cont, true)
	cont.pressed.connect(func() -> void:
		overlay.queue_free()
		_delete_account_step2()
	)
	btns.add_child(cont)


func _delete_account_step2() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 110
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.8)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.4, 0.05, 0.05, 0.95)
	ps.set_border_width_all(3)
	ps.border_color = Color(1, 0.2, 0.2)
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 32
	ps.content_margin_right = 32
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var msg := Label.new()
	msg.text = Translations.tr_key("settings.delete_confirm_2")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size.x = 400
	vbox.add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)
	var cancel := Button.new()
	cancel.text = Translations.tr_key("settings.delete_cancel")
	cancel.custom_minimum_size = Vector2(140, 44)
	_style_lang_btn(cancel, false)
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(cancel)
	var del := Button.new()
	del.text = Translations.tr_key("settings.delete_confirm")
	del.custom_minimum_size = Vector2(140, 44)
	var del_style := StyleBoxFlat.new()
	del_style.bg_color = Color(0.7, 0.1, 0.1)
	del_style.set_border_width_all(2)
	del_style.border_color = Color(1, 0.3, 0.3)
	del_style.set_corner_radius_all(8)
	del.add_theme_stylebox_override("normal", del_style)
	del.add_theme_font_size_override("font_size", 22)
	del.add_theme_color_override("font_color", Color.WHITE)
	del.pressed.connect(func() -> void:
		overlay.queue_free()
		_perform_account_delete()
	)
	_attach_press_effect(del)
	btns.add_child(del)


func _perform_account_delete() -> void:
	# Clear save file
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	# Reset to defaults
	SaveManager.credits = ConfigManager.get_starting_balance()
	SaveManager.denomination = 1
	SaveManager.hand_count = 1
	SaveManager.ultra_vp = false
	SaveManager.spin_poker = false
	SaveManager.speed_level = 1
	SaveManager.bet_level = 1
	SaveManager.depth_hint_shown = false
	SaveManager.save_game()
	# Refresh lobby
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_credits_label.text = "CREDITS: %d" % SaveManager.credits


func _hide_settings() -> void:
	_hide_language_picker()
	if _settings_overlay:
		_settings_overlay.queue_free()
		_settings_overlay = null


# --- Language picker (sub-popup of settings) ---

var _lang_picker_overlay: Control = null

func _show_language_picker() -> void:
	if _lang_picker_overlay:
		return
	_lang_picker_overlay = Control.new()
	_lang_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lang_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_lang_picker_overlay.z_index = 110  # above the settings popup
	add_child(_lang_picker_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_language_picker()
	)
	_lang_picker_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.18, 0.98)
	pstyle.set_border_width_all(3)
	pstyle.border_color = Color("FFEC00")
	pstyle.set_corner_radius_all(12)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_lang_picker_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("settings.language")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	vbox.add_child(title)

	var current := Translations.get_saved_language()
	for code in Translations.get_available_codes():
		var btn := Button.new()
		btn.text = Translations.display_name_for_code(code)
		btn.custom_minimum_size = Vector2(280, 56)
		_style_lang_btn(btn, code == current)
		btn.pressed.connect(_on_language_chosen.bind(code))
		vbox.add_child(btn)


func _hide_language_picker() -> void:
	if _lang_picker_overlay:
		_lang_picker_overlay.queue_free()
		_lang_picker_overlay = null


func _on_language_chosen(code: String) -> void:
	_hide_language_picker()
	if code == Translations.get_saved_language():
		_hide_settings()
		return
	Translations.set_language(code)
	# Force a full game reload so every cached label / built scene updates.
	get_tree().call_deferred("reload_current_scene")


# --- Gift widget ---

var _gift_btn: Button = null
var _gift_timer_label: Label = null
var _gift_ready: bool = false

func _build_gift_widget() -> void:
	var top_bar := $VBoxContainer/TopBar as HBoxContainer
	_gift_btn = Button.new()
	_gift_btn.custom_minimum_size = Vector2(180, 52)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.5, 0.1)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.8, 0.3)
	style.set_corner_radius_all(8)
	_gift_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.15, 0.6, 0.15)
	_gift_btn.add_theme_stylebox_override("hover", hover)
	_gift_btn.add_theme_font_size_override("font_size", 18)
	_gift_btn.add_theme_color_override("font_color", Color.WHITE)
	_gift_btn.pressed.connect(_on_gift_pressed)
	_attach_press_effect(_gift_btn)
	top_bar.add_child(_gift_btn)
	if is_instance_valid(_settings_btn):
		top_bar.move_child(_gift_btn, _settings_btn.get_index())
	_update_gift_state()


func _process(_delta: float) -> void:
	if _gift_btn and not _gift_ready:
		_update_gift_state()
	# Re-apply rubber-band offset after ScrollContainer's sort resets content.position
	if _overscroll != 0.0 and _drag_content and _scroll_ref:
		_drag_content.position.x = float(-_scroll_ref.scroll_horizontal) + _overscroll


func _update_gift_state() -> void:
	var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - SaveManager.last_gift_time
	if elapsed >= interval_sec or SaveManager.last_gift_time == 0:
		_gift_ready = true
		_gift_btn.text = Translations.tr_key("gift.claim")
		_gift_btn.modulate = Color.WHITE
	else:
		_gift_ready = false
		var remaining: int = interval_sec - elapsed
		var h: int = remaining / 3600
		var m: int = (remaining % 3600) / 60
		var s: int = remaining % 60
		_gift_btn.text = "%02d:%02d:%02d" % [h, m, s]
		_gift_btn.modulate = Color(0.6, 0.6, 0.6)


func _on_gift_pressed() -> void:
	if not _gift_ready:
		return
	var chips: int = ConfigManager.get_gift_chips()
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(chips)
	SaveManager.last_gift_time = int(Time.get_unix_time_from_system())
	SaveManager.save_game()
	_gift_ready = false
	_update_gift_state()
	SoundManager.play("gift_claim")
	# G.5: Animate balance increment over 5 seconds
	_animate_balance_increment(old_credits, SaveManager.credits, 5.0)


func _animate_balance_increment(from: int, to: int, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(val: int) -> void:
		SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(val))
	, from, to, duration).set_ease(Tween.EASE_OUT)


# --- Shop popup (IGT Game King style — horizontal scroll of pack cards) ---

const SHOP_COLOR_SCHEMES := {
	"blue": {
		"bg": Color("131BC7"),
		"border": Color("6AD6FC"),
		"image_frame": Color("0A0FB0"),
		"bonus_ribbon": Color("49C8FF"),
	},
	"purple": {
		"bg": Color("8C1FA6"),
		"border": Color("F24EB9"),
		"image_frame": Color("5D1177"),
		"bonus_ribbon": Color("49C8FF"),
	},
}

var _shop_overlay: Control = null
var _lobby_scroll_backup: ScrollContainer = null
var _lobby_drag_content_backup: Control = null
var _lobby_hit_rect_backup: Callable = Callable()


func _show_shop() -> void:
	if _shop_overlay:
		return
	_shop_overlay = Control.new()
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.z_index = 100
	add_child(_shop_overlay)

	# Full-screen dark-navy backdrop
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.22, 1.0)
	_shop_overlay.add_child(bg)

	# Close X button (top-right, yellow circle)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 64)
	close_btn.add_theme_font_size_override("font_size", 40)
	close_btn.add_theme_color_override("font_color", Color.BLACK)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("FFEC00")
	cs.set_corner_radius_all(32)
	cs.set_border_width_all(3)
	cs.border_color = Color(0.35, 0.28, 0.0)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_stylebox_override("hover", cs)
	close_btn.add_theme_stylebox_override("pressed", cs)
	close_btn.add_theme_stylebox_override("focus", cs)
	close_btn.pressed.connect(_hide_shop)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_attach_press_effect(close_btn)
	_shop_overlay.add_child(close_btn)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -88
	close_btn.offset_right = -24
	close_btn.offset_top = 24
	close_btn.offset_bottom = 88

	# Horizontal scroll of pack cards
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 110
	scroll.offset_bottom = -90
	_shop_overlay.add_child(scroll)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(row)

	# Swap drag-scroll target to shop (any swipe on the overlay scrolls the row)
	if _inertia_tween and _inertia_tween.is_running():
		_inertia_tween.kill()
	_drag_active = false
	_set_overscroll(0.0)
	_lobby_scroll_backup = _scroll_ref
	_lobby_drag_content_backup = _drag_content
	_lobby_hit_rect_backup = _drag_hit_rect_fn
	_scroll_ref = scroll
	_drag_content = row
	_drag_hit_rect_fn = func() -> Rect2:
		return _shop_overlay.get_global_rect() if _shop_overlay else Rect2()

	var items := ConfigManager.get_shop_items()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
	)
	for it in items:
		row.add_child(_build_pack_card(it))

	# Exchange-rate label at the bottom ("100 [chip] = $1.00 Game Dollar")
	var rate_cfg: Dictionary = ConfigManager.shop.get("exchange_rate", {})
	if rate_cfg.get("show_label", false):
		var rate_hb := _build_exchange_rate_row(int(rate_cfg.get("coins_per_dollar", 100)))
		_shop_overlay.add_child(rate_hb)
		rate_hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		rate_hb.grow_horizontal = Control.GROW_DIRECTION_BOTH
		rate_hb.offset_top = -56
		rate_hb.offset_bottom = -20


func _build_pack_card(item: Dictionary) -> PanelContainer:
	var scheme_name: String = item.get("color_scheme", "blue")
	var scheme: Dictionary = SHOP_COLOR_SCHEMES.get(scheme_name, SHOP_COLOR_SCHEMES["blue"])
	var chips: int = int(item.get("chips", 0))
	var bonus_chips: int = int(item.get("bonus_chips", 0))
	var total: int = chips + bonus_chips
	var top_badge_key: Variant = item.get("top_badge_key", null)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 460)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = scheme["bg"]
	card_style.set_border_width_all(4)
	card_style.border_color = scheme["border"]
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vb)

	# Top ribbon (SPECIAL PACK / MOST POPULAR)
	if top_badge_key != null and str(top_badge_key) != "":
		vb.add_child(_build_top_ribbon(Translations.tr_key(str(top_badge_key))))

	# Strikethrough base price
	if bonus_chips > 0 and chips > 0:
		var strike_hb := _build_chips_display(chips, 22, Color.WHITE)
		strike_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_add_strike_line(strike_hb)
		vb.add_child(strike_hb)

		var bonus_pct: int = int(round(float(bonus_chips) / float(chips) * 100.0))
		vb.add_child(_build_bonus_banner(bonus_pct))

	# Total chips (big yellow)
	var total_hb := _build_chips_display(total, 32, Color("FFEC00"))
	total_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(total_hb)

	# Pack image
	var img_panel := PanelContainer.new()
	img_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var img_style := StyleBoxFlat.new()
	img_style.bg_color = scheme["image_frame"]
	img_style.set_border_width_all(2)
	img_style.border_color = scheme["border"]
	img_style.set_corner_radius_all(12)
	img_style.content_margin_left = 6
	img_style.content_margin_right = 6
	img_style.content_margin_top = 6
	img_style.content_margin_bottom = 6
	img_panel.add_theme_stylebox_override("panel", img_style)
	vb.add_child(img_panel)

	var img := TextureRect.new()
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.custom_minimum_size = Vector2(160, 160)
	var img_path: String = str(ConfigManager.shop.get("images_path", "res://assets/shop/")) + str(item.get("image", ""))
	if ResourceLoader.exists(img_path):
		img.texture = load(img_path)
	img_panel.add_child(img)

	# Bonus chips ribbon (bottom)
	if bonus_chips > 0:
		var extra := _build_extra_ribbon(bonus_chips, scheme["bonus_ribbon"])
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(extra)

	# FREE buy button
	var buy_btn := _build_buy_button()
	buy_btn.pressed.connect(_on_shop_buy.bind(total))
	vb.add_child(buy_btn)

	return card


func _build_chips_display(amount: int, font_size: int, color: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	var num := Label.new()
	num.text = SaveManager.format_money(amount)
	num.add_theme_font_size_override("font_size", font_size)
	num.add_theme_color_override("font_color", color)
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	num.add_theme_constant_override("outline_size", 3)
	hb.add_child(num)
	var chip_tex: Texture2D = load("res://assets/textures/glyphs/glyph_chip.svg")
	if chip_tex:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		var h: int = int(font_size * 0.95)
		chip.custom_minimum_size = Vector2(h, h)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(chip)
	return hb


func _add_strike_line(ctrl: Control) -> void:
	ctrl.draw.connect(func() -> void:
		var y: float = ctrl.size.y * 0.55
		ctrl.draw_line(Vector2(-2, y), Vector2(ctrl.size.x + 2, y), Color(1.0, 0.25, 0.25, 0.95), 3.0)
	)


func _build_bonus_banner(percent: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color("FFEC00")
	st.set_corner_radius_all(4)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var lab := Label.new()
	lab.text = Translations.tr_key("shop.bonus_percent_fmt", [percent])
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color.BLACK)
	pc.add_child(lab)
	return pc


func _build_top_ribbon(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color("FFEC00")
	st.set_corner_radius_all(6)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color.BLACK)
	pc.add_child(lab)
	return pc


func _build_extra_ribbon(bonus_chips: int, bg: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(6)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	pc.add_child(hb)
	var lab := Label.new()
	lab.text = "+" + SaveManager.format_money(bonus_chips)
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 3)
	hb.add_child(lab)
	var chip_tex: Texture2D = load("res://assets/textures/glyphs/glyph_chip.svg")
	if chip_tex:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		chip.custom_minimum_size = Vector2(18, 18)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(chip)
	return pc


func _build_buy_button() -> Button:
	var btn := Button.new()
	btn.text = Translations.tr_key("common.free")
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.05, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.15, 0.80, 0.35)
	st.set_border_width_all(2)
	st.border_color = Color(0.04, 0.40, 0.12)
	st.set_corner_radius_all(22)
	btn.add_theme_stylebox_override("normal", st)
	var hover := st.duplicate()
	hover.bg_color = Color(0.20, 0.88, 0.40)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", st)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_attach_press_effect(btn)
	return btn


func _build_exchange_rate_row(coins_per_dollar: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	var n_label := Label.new()
	n_label.text = str(coins_per_dollar)
	n_label.add_theme_font_size_override("font_size", 22)
	n_label.add_theme_color_override("font_color", Color("FFEC00"))
	hb.add_child(n_label)
	var chip_tex: Texture2D = load("res://assets/textures/glyphs/glyph_chip.svg")
	if chip_tex:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		chip.custom_minimum_size = Vector2(22, 22)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(chip)
	var eq_label := Label.new()
	eq_label.text = Translations.tr_key("shop.exchange_rate_fmt", [1.0])
	eq_label.add_theme_font_size_override("font_size", 22)
	eq_label.add_theme_color_override("font_color", Color.WHITE)
	hb.add_child(eq_label)
	return hb


func _on_shop_buy(amount: int) -> void:
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(amount)
	SaveManager.save_game()
	_hide_shop()
	_animate_balance_increment(old_credits, SaveManager.credits, 1.0)


func _hide_shop() -> void:
	if _shop_overlay:
		# Kill any active shop drag/inertia before tearing down
		if _inertia_tween and _inertia_tween.is_running():
			_inertia_tween.kill()
		_drag_active = false
		_overscroll = 0.0
		_shop_overlay.queue_free()
		_shop_overlay = null
	# Restore lobby drag-scroll target
	if _lobby_scroll_backup:
		_scroll_ref = _lobby_scroll_backup
		_drag_content = _lobby_drag_content_backup
		_drag_hit_rect_fn = _lobby_hit_rect_backup
		_lobby_scroll_backup = null
		_lobby_drag_content_backup = null
		_lobby_hit_rect_backup = Callable()
