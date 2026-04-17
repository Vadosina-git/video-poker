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
	add_to_group("lobby_manager")
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
	_add_top_bar_padding()


func _add_top_bar_padding() -> void:
	# HBoxContainer doesn't honour stylebox content_margin for child layout,
	# so we insert empty spacer Controls at the extreme left & right to inset
	# every top-bar element (cash pill, title, gift, shop +, settings) by SAFE_AREA_H.
	var top_bar := $VBoxContainer/TopBar as HBoxContainer
	var left_pad := Control.new()
	left_pad.custom_minimum_size.x = SAFE_AREA_H
	top_bar.add_child(left_pad)
	top_bar.move_child(left_pad, 0)
	var right_pad := Control.new()
	right_pad.custom_minimum_size.x = SAFE_AREA_H
	top_bar.add_child(right_pad)


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
	_cash_pill = cash_pill
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

	# Shop button — PNG-baked pill (SVG had rasterisation/layout issues inside
	# containers). TextureButton handles click + focus natively.
	var shop_btn := TextureButton.new()
	shop_btn.texture_normal = load("res://assets/textures/shop_button_lobby.png")
	shop_btn.ignore_texture_size = true
	shop_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	shop_btn.custom_minimum_size = Vector2(88, 68)
	shop_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_btn.size_flags_horizontal = 0
	shop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shop_btn.pressed.connect(_show_shop)
	_attach_press_effect(shop_btn)
	top_bar.add_child(shop_btn)
	top_bar.move_child(shop_btn, cash_pill.get_index() + 1)

	# White "+" overlay centered on the button
	shop_btn.draw.connect(func() -> void:
		var c: Vector2 = shop_btn.size * 0.5
		var arm: float = minf(shop_btn.size.x, shop_btn.size.y) * 0.22
		var th: float = arm * 0.6
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
	# Tab wiggle — small rotate bounce on the newly selected tab
	if index < _sidebar_buttons.size():
		var btn: Control = _sidebar_buttons[index]
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "rotation", deg_to_rad(-2.5), 0.08).from(0.0)
		tw.tween_property(btn, "rotation", deg_to_rad(2.0), 0.09)
		tw.tween_property(btn, "rotation", 0.0, 0.1)


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


## Attaches a quick scale-down/scale-up animation on press to a BaseButton,
## plus a tiny hover overscale. Scales around center via pivot_offset.
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
	# Ripple effect on press (anim 2.1)
	_attach_ripple(btn)
	# Hover overscale (skipped on touch-only platforms)
	btn.mouse_entered.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		if btn.button_pressed:
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.14)
	)


## Material-style ripple: on press, a translucent circle expands from the
## click point and fades out. Uses gui_input + draw.connect on the button.
func _attach_ripple(btn: Control) -> void:
	var state := {"center": Vector2.ZERO, "radius": 0.0, "alpha": 0.0, "max_r": 0.0}
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			state["center"] = event.position
			state["max_r"] = Vector2(maxf(event.position.x, btn.size.x - event.position.x), \
				maxf(event.position.y, btn.size.y - event.position.y)).length()
			state["radius"] = 0.0
			state["alpha"] = 0.35
			var tw := btn.create_tween().set_parallel(true)
			tw.tween_method(func(r: float) -> void:
				state["radius"] = r
				btn.queue_redraw()
			, 0.0, state["max_r"], 0.45).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(a: float) -> void:
				state["alpha"] = a
				btn.queue_redraw()
			, 0.35, 0.0, 0.45).set_ease(Tween.EASE_OUT)
	)
	btn.draw.connect(func() -> void:
		if state["alpha"] > 0.001 and state["radius"] > 0.0:
			btn.draw_circle(state["center"], state["radius"], Color(1, 1, 1, state["alpha"]))
	)


## One-shot golden gleam diagonal sweep across a Control — used when a
## button transitions from disabled → enabled (anim 2.4).
func _gleam_once(ctrl: Control, color: Color = Color(1, 0.95, 0.3, 0.85)) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.clip_contents = true
	var state := {"t": -0.3}
	var tw := ctrl.create_tween()
	tw.tween_method(func(val: float) -> void:
		state["t"] = val
		ctrl.queue_redraw()
	, -0.3, 1.3, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	var draw_cb := func() -> void:
		var t: float = state["t"]
		if t < 0.0 or t > 1.0:
			return
		var w: float = ctrl.size.x
		var h: float = ctrl.size.y
		var cx: float = lerp(-w * 0.4, w * 1.1, t)
		var half: float = w * 0.1
		var skew: float = h * 0.6
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(cx - half, -2),
			Vector2(cx + half, -2),
			Vector2(cx + half - skew, h + 2),
			Vector2(cx - half - skew, h + 2),
		])
		ctrl.draw_colored_polygon(poly, color)
	ctrl.draw.connect(draw_cb)
	# Disconnect once the animation finishes so the gleam doesn't linger.
	tw.finished.connect(func() -> void:
		if ctrl.draw.is_connected(draw_cb):
			ctrl.draw.disconnect(draw_cb)
		ctrl.queue_redraw()
	)


## Crossfade + rotate swap between two textures on a TextureRect (anim 2.5).
## Fades current texture out with a 90° spin, swaps to `new_tex`, spins in.
func _morph_texture(tex_rect: TextureRect, new_tex: Texture2D, duration: float = 0.25) -> void:
	if not is_instance_valid(tex_rect):
		return
	tex_rect.pivot_offset = tex_rect.size * 0.5
	var half: float = duration * 0.5
	var tw := tex_rect.create_tween().set_parallel(true)
	tw.tween_property(tex_rect, "rotation", deg_to_rad(90), half).set_ease(Tween.EASE_IN)
	tw.tween_property(tex_rect, "modulate:a", 0.0, half).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		tex_rect.texture = new_tex
		tex_rect.rotation = deg_to_rad(-90)
	)
	tw.chain().tween_property(tex_rect, "rotation", 0.0, half).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex_rect, "modulate:a", 1.0, half).set_ease(Tween.EASE_OUT)


## Short "success" pop on any Control — over-scale pulse + modulate flash.
func _success_pop(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween().set_parallel(true)
	tw.tween_property(ctrl, "scale", Vector2(1.18, 1.18), 0.1).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(ctrl, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "modulate", Color(1.5, 1.5, 1.0), 0.1).from(Color.WHITE)
	tw.chain().tween_property(ctrl, "modulate", Color.WHITE, 0.2)


var _drag_active := false
var _drag_start_x := 0.0
var _drag_scroll_start := 0
var _scroll_ref: ScrollContainer = null
var _inertia_tween: Tween = null
var _velocity_samples: Array = []  # [Vector2(x, time_sec)]
var _overscroll: float = 0.0        # rubber-band offset applied to grid
var _drag_moved: bool = false        # set true once drag crosses tap-cancel threshold

const DRAG_TAP_CANCEL_PX := 10.0    # movement beyond this in any drag cancels a tap

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


## Public: machine cards call this in their release handler to decide
## whether a short press should count as a tap (false) or was absorbed by a
## carousel swipe (true).
func carousel_drag_moved() -> bool:
	return _drag_moved


## Fade the horizontal scrollbar of the active scroll container in/out
## (anim 4.5) — visible while dragging, invisible at rest.
func _fade_scrollbar(visible: bool) -> void:
	if _scroll_ref == null:
		return
	var sb := _scroll_ref.get_h_scroll_bar()
	if sb == null:
		return
	var target_a: float = 0.6 if visible else 0.0
	var tw := sb.create_tween()
	tw.tween_property(sb, "modulate:a", target_a, 0.25)


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
				_drag_moved = false
				_drag_start_x = event.global_position.x
				_drag_scroll_start = _scroll_ref.scroll_horizontal
				_velocity_samples.clear()
				_velocity_samples.append(Vector2(event.global_position.x, Time.get_ticks_msec() / 1000.0))
				if _inertia_tween and _inertia_tween.is_running():
					_inertia_tween.kill()
				_fade_scrollbar(true)
		else:
			if _drag_active:
				_drag_active = false
				_release_drag(_calc_velocity())
				_fade_scrollbar(false)
	elif event is InputEventMouseMotion and _drag_active:
		var now: float = Time.get_ticks_msec() / 1000.0
		_velocity_samples.append(Vector2(event.global_position.x, now))
		while _velocity_samples.size() > 8:
			_velocity_samples.pop_front()
		var delta: float = (_drag_start_x - event.global_position.x) * _drag_sign
		if not _drag_moved and absf(_drag_start_x - event.global_position.x) > DRAG_TAP_CANCEL_PX:
			_drag_moved = true
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
		# Phase 1 decelerates to peak (v→0). Phase 2 returns to 0 via SINE
		# EASE_IN_OUT so it also starts at v=0, avoiding the velocity
		# discontinuity at the peak that looked like an extra bounce.
		var excess: float = float(-target)
		var peak: float = -minf(excess * 0.35, MAX_OVERSCROLL)
		_scroll_ref.scroll_horizontal = 0
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, 0.0, peak, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_inertia_tween.tween_method(_set_overscroll, peak, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	elif target > m:
		var excess2: float = float(target - m)
		var peak2: float = minf(excess2 * 0.35, MAX_OVERSCROLL)
		_scroll_ref.scroll_horizontal = m
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, 0.0, -peak2, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_inertia_tween.tween_method(_set_overscroll, -peak2, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
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

	# Build a quick lookup: machine_id → MACHINE_CONFIG entry.
	var config_by_id: Dictionary = {}
	for c in MACHINE_CONFIG:
		config_by_id[c["id"]] = c

	# Collect configs in the order defined by the mode's `machines` list
	# (from lobby_order.json). If the mode has no list, fall back to
	# MACHINE_CONFIG source order.
	var configs: Array = []
	if mode_machines.size() > 0:
		for mm in mode_machines:
			if not mm.get("enabled", true):
				continue
			var mid: String = mm.get("id", "")
			if mid in config_by_id:
				configs.append(config_by_id[mid])
	else:
		for c in MACHINE_CONFIG:
			configs.append(c)

	# GridContainer fills row-major (left→right, top→bottom). We want the
	# visual order to be COLUMN-MAJOR (top→bottom within each column, columns
	# left→right), so remap the add order: visual (row, col) gets
	# configs[col * rows + row].
	var cols: int = maxi(int(_grid.columns), 1)
	var rows: int = int(ceil(float(configs.size()) / float(cols)))
	for row in range(rows):
		for col in range(cols):
			var src_idx: int = col * rows + row
			if src_idx >= configs.size():
				continue
			var config: Dictionary = configs[src_idx]
			var machine_id: String = config["id"]
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
			# Decorative shimmer sweep (anim 1.2): fast highlight pass.
			# 1s sweep + 10.2s pause = 11.2s total cycle; alpha 0.35.
			# Hosted on a clipped overlay Control so the polygon is confined
			# to the card rect (avoids leaking and keeps the drop shadow).
			var shim_host := Control.new()
			shim_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shim_host.clip_contents = true
			card_node.add_child(shim_host)
			_attach_shimmer_sweep(shim_host, 1.0, Color(1, 1, 1, 0.35), 10.2)
			_machine_cards.append(card_node)

	# Stagger fade-in: cards appear sequentially with a slight upward slide.
	for i in _machine_cards.size():
		var card: Control = _machine_cards[i]
		card.modulate.a = 0.0
		card.position.y += 20
		var delay: float = float(i) * 0.04
		var tw := card.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(card, "position:y", card.position.y - 20, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


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
	# Zoom-in on the tapped card (anim 6.2) before the transition
	for card in _machine_cards:
		if is_instance_valid(card) and card.variant_id == variant_id:
			if card.has_method("play_zoom_in"):
				card.play_zoom_in(0.3)
			break
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

const GIFT_ICON_SIZE := 56  # matches pill height so the icon never exceeds button bounds
const GIFT_BTN_W := 180
const GIFT_BTN_H := 56
const GIFT_ICON_OVERLAP := 22  # icon overlaps pill button by this much on left

var _gift_btn: Control = null
var _gift_icon_rect: TextureRect = null
var _gift_label_area: VBoxContainer = null
var _gift_ready: bool = false


func _build_gift_widget() -> void:
	var top_bar := $VBoxContainer/TopBar as HBoxContainer

	var widget_w: int = GIFT_ICON_SIZE + GIFT_BTN_W - GIFT_ICON_OVERLAP
	var widget_h: int = GIFT_ICON_SIZE

	var root := Control.new()
	root.custom_minimum_size = Vector2(widget_w, widget_h)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.pivot_offset = Vector2(widget_w, widget_h) * 0.5

	# Green pill button background
	var pill := TextureRect.new()
	pill.texture = load("res://assets/shop/gift_box_button.png")
	pill.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	pill.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	pill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pill.stretch_mode = TextureRect.STRETCH_SCALE
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)

	# Label area centered on the pill (text is rebuilt by _update_gift_state)
	_gift_label_area = VBoxContainer.new()
	_gift_label_area.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	_gift_label_area.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	_gift_label_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_gift_label_area.add_theme_constant_override("separation", 0)
	_gift_label_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gift_label_area)

	# Icon (overlaps pill on the left)
	_gift_icon_rect = TextureRect.new()
	_gift_icon_rect.position = Vector2(0, 0)
	_gift_icon_rect.size = Vector2(GIFT_ICON_SIZE, GIFT_ICON_SIZE)
	_gift_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gift_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gift_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gift_icon_rect)

	root.gui_input.connect(_on_gift_gui_input)
	_gift_btn = root

	top_bar.add_child(_gift_btn)
	if is_instance_valid(_settings_btn):
		top_bar.move_child(_gift_btn, _settings_btn.get_index())
	# Force initial rebuild of labels + icon
	_gift_ready = not _is_gift_ready()
	_update_gift_state()


func _process(_delta: float) -> void:
	if _gift_btn and not _gift_ready:
		_update_gift_state()
	# Keep shop-side timer in sync while gift is recharging
	if _shop_gift_label_area and is_instance_valid(_shop_gift_label_area) and not _gift_ready:
		var shop_timer := _shop_gift_label_area.get_node_or_null("Timer") as Label
		if shop_timer:
			var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
			var remaining: int = interval_sec - (int(Time.get_unix_time_from_system()) - SaveManager.last_gift_time)
			var h: int = remaining / 3600
			var m: int = (remaining % 3600) / 60
			var s: int = remaining % 60
			shop_timer.text = "%dH %dM %dS" % [h, m, s]
	# Re-apply rubber-band offset after ScrollContainer's sort resets content.position
	if _overscroll != 0.0 and _drag_content and _scroll_ref:
		_drag_content.position.x = float(-_scroll_ref.scroll_horizontal) + _overscroll


func _is_gift_ready() -> bool:
	var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - SaveManager.last_gift_time
	return elapsed >= interval_sec or SaveManager.last_gift_time == 0


func _update_gift_state() -> void:
	if not _gift_icon_rect or not _gift_label_area:
		return
	var ready: bool = _is_gift_ready()
	if ready != _gift_ready:
		_gift_ready = ready
		_rebuild_gift_content(ready)
	if not ready:
		var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
		var remaining: int = interval_sec - (int(Time.get_unix_time_from_system()) - SaveManager.last_gift_time)
		var h: int = remaining / 3600
		var m: int = (remaining % 3600) / 60
		var s: int = remaining % 60
		var timer_label := _gift_label_area.get_node_or_null("Timer") as Label
		if timer_label:
			timer_label.text = "%dH %dM %dS" % [h, m, s]


func _rebuild_gift_content(ready: bool) -> void:
	for child in _gift_label_area.get_children():
		_gift_label_area.remove_child(child)
		child.queue_free()

	if ready:
		_gift_icon_rect.texture = load("res://assets/shop/gift_box_ready_icon.png")

		var collect_label := Label.new()
		collect_label.text = "COLLECT!"
		collect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		collect_label.add_theme_font_size_override("font_size", 22)
		collect_label.add_theme_color_override("font_color", Color.WHITE)
		collect_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		collect_label.add_theme_constant_override("outline_size", 3)
		_gift_label_area.add_child(collect_label)

		var amount_hb := HBoxContainer.new()
		amount_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		amount_hb.add_theme_constant_override("separation", 4)
		amount_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var chip_tex: Texture2D = load("res://assets/textures/glyphs/glyph_chip.svg")
		if chip_tex:
			var chip := TextureRect.new()
			chip.texture = chip_tex
			chip.custom_minimum_size = Vector2(20, 20)
			chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.modulate = Color("FFEC00")
			amount_hb.add_child(chip)

		var amount_lab := Label.new()
		amount_lab.add_theme_font_size_override("font_size", 18)
		amount_lab.add_theme_color_override("font_color", Color("FFEC00"))
		amount_lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		amount_lab.add_theme_constant_override("outline_size", 2)
		_set_chip_amount_text(amount_lab, ConfigManager.get_gift_chips(), GIFT_BTN_W - 40)
		amount_hb.add_child(amount_lab)
		_gift_label_area.add_child(amount_hb)
	else:
		_gift_icon_rect.texture = load("res://assets/shop/gift_box_icon.png")

		var timer_label := Label.new()
		timer_label.name = "Timer"
		timer_label.text = "--H --M --S"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 22)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		timer_label.add_theme_constant_override("outline_size", 3)
		_gift_label_area.add_child(timer_label)


## Pulses a "COLLECT!" label (or any label) with a gentle scale loop.
## Tween is bound to the label, so it auto-dies when the label is freed.
func _pulse_collect_label(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	label.resized.connect(func() -> void: label.pivot_offset = label.size * 0.5)
	var tw := label.create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "scale", Vector2(1.08, 1.08), 0.45).from(Vector2.ONE)
	tw.tween_property(label, "scale", Vector2.ONE, 0.45)


## Sets chip-count text on a label, switching to the short format ("1.2M")
## if the full comma-separated form wouldn't fit within `max_w` pixels.
func _set_chip_amount_text(label: Label, amount: int, max_w: float) -> void:
	label.text = SaveManager.format_money(amount)
	var min_size: Vector2 = label.get_minimum_size()
	if min_size.x > max_w:
		label.text = SaveManager.format_short(amount)


func _on_gift_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_gift_press_tween(true)
		else:
			_gift_press_tween(false)
			_on_gift_pressed()


func _gift_press_tween(down: bool) -> void:
	if not is_instance_valid(_gift_btn):
		return
	var target: Vector2 = Vector2(0.93, 0.93) if down else Vector2.ONE
	var dur: float = 0.07 if down else 0.11
	var tw := _gift_btn.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gift_btn, "scale", target, dur)


func _on_gift_pressed() -> void:
	if not _gift_ready:
		return
	# When the gift is ready, the top-bar gift widget opens the shop; the
	# shop itself shows a duplicate gift widget that actually claims the reward.
	_show_shop()


func _claim_gift_reward(from_pos: Vector2 = Vector2.ZERO) -> void:
	if not _gift_ready:
		return
	var chips: int = ConfigManager.get_gift_chips()
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(chips)
	SaveManager.last_gift_time = int(Time.get_unix_time_from_system())
	SaveManager.save_game()
	_update_gift_state()
	SoundManager.play("gift_claim")
	# Shop-side widget stays visible; just swap to the timer state.
	if _shop_gift_widget and is_instance_valid(_shop_gift_widget):
		_rebuild_shop_gift_content(false)
	if from_pos != Vector2.ZERO:
		_spawn_confetti_burst(from_pos)
		_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)
	else:
		_animate_balance_increment(old_credits, SaveManager.credits, 0.9)


## Returns the currency_display dict of the currently visible balance pill.
## Shop pill while shop is open, lobby pill otherwise.
func _active_cash_cd() -> Dictionary:
	if _shop_overlay and not _shop_cash_cd.is_empty():
		return _shop_cash_cd
	return _cash_cd


## Returns the PanelContainer of the currently visible balance pill.
func _active_cash_pill() -> Control:
	if _shop_overlay and is_instance_valid(_shop_cash_pill):
		return _shop_cash_pill
	return _cash_pill


func _animate_balance_increment(from: int, to: int, duration: float) -> void:
	var target_cd: Dictionary = _active_cash_cd()
	# Also keep the background (hidden) lobby pill in sync so the final value
	# is up-to-date the instant the shop closes.
	if target_cd != _cash_cd and not _cash_cd.is_empty():
		SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(to))
	var tw := create_tween()
	tw.tween_method(func(val: int) -> void:
		SaveManager.set_currency_value(target_cd, SaveManager.format_money(val))
	, from, to, duration).set_ease(Tween.EASE_OUT)


## Spawns a visual cascade of chip icons that fly from `from_pos` (global)
## toward the currently-visible balance pill, while the balance counter +
## pill flash run in parallel. Falls back to a plain number tween if
## the pill isn't available.
func _spawn_chip_cascade(from_pos: Vector2, old_credits: int, new_credits: int) -> void:
	var target_cd: Dictionary = _active_cash_cd()
	var pill_inner: Control = target_cd.get("box", null) as Control
	if not is_instance_valid(pill_inner):
		_animate_balance_increment(old_credits, new_credits, 0.9)
		return
	var target_pos: Vector2 = pill_inner.global_position + pill_inner.size * 0.5

	var chip_tex: Texture2D = load("res://assets/textures/glyphs/glyph_chip.svg")
	if chip_tex == null:
		_animate_balance_increment(old_credits, new_credits, 0.9)
		return

	var chip_count: int = 10
	var stagger_step: float = 0.05
	var travel_time: float = 0.55
	var chip_size: Vector2 = Vector2(52, 52)  # bigger, per spec
	var chip_color: Color = Color("FFEC00")    # yellow, per spec

	for i in chip_count:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.custom_minimum_size = chip_size
		chip.size = chip_size
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.pivot_offset = chip_size * 0.5
		chip.z_index = 500
		var jitter := Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
		chip.global_position = from_pos + jitter - chip_size * 0.5
		chip.modulate = Color(chip_color.r, chip_color.g, chip_color.b, 0.0)
		add_child(chip)

		var stagger: float = float(i) * stagger_step
		var tw := chip.create_tween()
		tw.tween_interval(stagger)
		tw.tween_property(chip, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(chip, "global_position",
			target_pos - chip_size * 0.5, travel_time
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(chip, "scale", Vector2(0.6, 0.6), travel_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(chip, "modulate:a", 0.0, 0.1)
		tw.tween_callback(chip.queue_free)

		# Particle trail (anim 3.4): spawn small fading ghost copies along the
		# chip's path to create a motion smear.
		_spawn_chip_trail(chip_tex, chip_size, chip_color, from_pos + jitter, target_pos, stagger, travel_time)

	var total_duration: float = travel_time + stagger_step * float(chip_count - 1)
	_animate_balance_increment(old_credits, new_credits, total_duration)
	_flash_balance_pill(total_duration)
	# Big-win screen-wide golden tint (anim 3.3)
	if new_credits - old_credits >= 10000:
		_screen_gold_flash()


## Spawns ~5 shrinking ghost chips along the trajectory of a cascade chip.
## They stagger in time along the path and quickly fade, producing a trail.
func _spawn_chip_trail(tex: Texture2D, size: Vector2, color: Color, start: Vector2, end: Vector2, base_stagger: float, travel: float) -> void:
	var trail_count: int = 5
	for k in trail_count:
		var ghost := TextureRect.new()
		ghost.texture = tex
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.custom_minimum_size = size
		ghost.size = size
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.pivot_offset = size * 0.5
		ghost.z_index = 490
		ghost.modulate = Color(color.r, color.g, color.b, 0.0)
		ghost.global_position = start - size * 0.5
		add_child(ghost)
		var progress: float = float(k + 1) / float(trail_count + 1)
		var ghost_pos: Vector2 = start.lerp(end, progress)
		var ghost_delay: float = base_stagger + travel * progress * 0.7
		var tw := ghost.create_tween()
		tw.tween_interval(ghost_delay)
		tw.tween_property(ghost, "global_position", ghost_pos - size * 0.5, 0.01)
		tw.parallel().tween_property(ghost, "modulate:a", 0.45 * (1.0 - progress), 0.01)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ghost, "scale", Vector2(0.4, 0.4), 0.28).set_ease(Tween.EASE_OUT)
		tw.tween_callback(ghost.queue_free)


func _flash_balance_pill(duration: float) -> void:
	var pill: Control = _active_cash_pill()
	if not is_instance_valid(pill):
		return
	var flashes: int = 3
	var half: float = duration / float(flashes * 2)
	var tw := pill.create_tween()
	for i in flashes:
		tw.tween_property(pill, "modulate", Color(1.55, 1.55, 0.85), half)
		tw.tween_property(pill, "modulate", Color.WHITE, half)
	# Coin flip on the chip glyph inside the pill (anim 3.2)
	_coin_flip_chip()


## Finds the first chip glyph in the active pill's currency box and flips
## it around its Y axis (fake 3D via scale.x) once.
func _coin_flip_chip() -> void:
	var cd: Dictionary = _active_cash_cd()
	var box: Node = cd.get("box", null)
	if not is_instance_valid(box):
		return
	for child in box.get_children():
		if child is TextureRect:
			var tex_rect: TextureRect = child
			tex_rect.pivot_offset = tex_rect.size * 0.5
			var tw := tex_rect.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(tex_rect, "scale:x", 0.0, 0.18)
			tw.tween_property(tex_rect, "scale:x", 1.0, 0.18)
			break  # only the chip glyph (first TextureRect in the HBox)


## Full-screen golden tint flash for large incoming chip gains (anim 3.3).
## Only triggers when delta exceeds a threshold (10,000+).
func _screen_gold_flash() -> void:
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.85, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 999
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.22, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(flash.queue_free)


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
var _shop_cash_cd: Dictionary = {}
var _shop_cash_pill: Control = null
var _shop_gift_widget: Control = null
var _shop_gift_icon: TextureRect = null
var _shop_gift_label_area: VBoxContainer = null
var _cash_pill: Control = null  # lobby top-bar cash pill, captured in _style_top_bar
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

	# Full-screen dark-navy backdrop (fades in from transparent)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.22, 0.0)
	_shop_overlay.add_child(bg)
	bg.create_tween().tween_property(bg, "color:a", 1.0, 0.2)

	# Shop open animation: slide-up + bounce scale on the whole overlay contents
	_shop_overlay.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y)
	_shop_overlay.scale = Vector2(0.95, 0.95)
	_shop_overlay.position.y = 40
	_shop_overlay.modulate.a = 0.0
	var intro := _shop_overlay.create_tween().set_parallel(true)
	intro.tween_property(_shop_overlay, "modulate:a", 1.0, 0.22)
	intro.tween_property(_shop_overlay, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	intro.tween_property(_shop_overlay, "position:y", 0.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

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

	# Balance pill (top-left) — mirrors lobby's cash pill
	var bal_pill := _build_shop_balance_pill()
	_shop_overlay.add_child(bal_pill)
	bal_pill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bal_pill.offset_left = 24
	bal_pill.offset_top = 24

	# Horizontal scroll of pack cards
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 110
	scroll.offset_bottom = -140  # reserve room for exchange-rate label + gift widget
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

	# Duplicate gift widget in the bottom-right — shows COLLECT! when ready,
	# then switches to the timer (mirror of the top-bar widget) after claim.
	var shop_gift := _build_shop_gift_widget()
	_shop_gift_widget = shop_gift
	_shop_overlay.add_child(shop_gift)
	shop_gift.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var gw: float = shop_gift.custom_minimum_size.x
	var gh: float = shop_gift.custom_minimum_size.y
	shop_gift.offset_left = -gw - 24
	shop_gift.offset_top = -gh - 24
	shop_gift.offset_right = -24
	shop_gift.offset_bottom = -24


func _build_shop_balance_pill() -> PanelContainer:
	# Yellow-bordered pill with "CASH" label + current chip count (mirrors the
	# top-bar cash pill in the lobby).
	var pill := PanelContainer.new()
	_shop_cash_pill = pill
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.03)
	style.set_border_width_all(4)
	style.border_color = Color("FFEC00")
	style.set_corner_radius_all(28)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", style)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(inner)

	var cash_label := Label.new()
	cash_label.text = Translations.tr_key("lobby.cash")
	cash_label.add_theme_font_size_override("font_size", 30)
	cash_label.add_theme_color_override("font_color", Color.WHITE)
	cash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cash_label.add_theme_constant_override("outline_size", 3)
	inner.add_child(cash_label)

	var cd := SaveManager.create_currency_display(32, Color.WHITE)
	inner.add_child(cd["box"])
	SaveManager.set_currency_value(cd, SaveManager.format_money(SaveManager.credits))
	_shop_cash_cd = cd
	return pill


func _build_shop_gift_widget() -> Control:
	var widget_w: int = GIFT_ICON_SIZE + GIFT_BTN_W - GIFT_ICON_OVERLAP
	var widget_h: int = GIFT_ICON_SIZE

	var root := Control.new()
	root.custom_minimum_size = Vector2(widget_w, widget_h)
	root.size = Vector2(widget_w, widget_h)
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.pivot_offset = Vector2(widget_w, widget_h) * 0.5

	# Pill bg
	var pill := TextureRect.new()
	pill.texture = load("res://assets/shop/gift_box_button.png")
	pill.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	pill.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	pill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pill.stretch_mode = TextureRect.STRETCH_SCALE
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)

	# Label area (COLLECT!+amount for ready state, timer for waiting state)
	var la := VBoxContainer.new()
	la.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	la.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	la.alignment = BoxContainer.ALIGNMENT_CENTER
	la.add_theme_constant_override("separation", 0)
	la.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(la)
	_shop_gift_label_area = la

	# Icon (overlaps pill on the left)
	var icon := TextureRect.new()
	icon.position = Vector2(0, 0)
	icon.size = Vector2(GIFT_ICON_SIZE, GIFT_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_shop_gift_icon = icon

	_rebuild_shop_gift_content(_is_gift_ready())

	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var target: Vector2 = Vector2(0.93, 0.93) if event.pressed else Vector2.ONE
			var dur: float = 0.07 if event.pressed else 0.11
			var tw := root.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(root, "scale", target, dur)
			if not event.pressed and _gift_ready:
				var spawn_pos: Vector2 = root.global_position + root.size * 0.5
				_claim_gift_reward(spawn_pos)
	)
	return root


func _rebuild_shop_gift_content(ready: bool) -> void:
	if not _shop_gift_label_area or not _shop_gift_icon:
		return
	for child in _shop_gift_label_area.get_children():
		_shop_gift_label_area.remove_child(child)
		child.queue_free()

	if ready:
		_shop_gift_icon.texture = load("res://assets/shop/gift_box_ready_icon.png")

		var collect := Label.new()
		collect.text = "COLLECT!"
		collect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		collect.add_theme_font_size_override("font_size", 22)
		collect.add_theme_color_override("font_color", Color.WHITE)
		collect.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		collect.add_theme_constant_override("outline_size", 3)
		_shop_gift_label_area.add_child(collect)

		var amount_hb := HBoxContainer.new()
		amount_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		amount_hb.add_theme_constant_override("separation", 4)
		amount_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_gift_label_area.add_child(amount_hb)

		var chip_tex: Texture2D = load("res://assets/textures/glyphs/glyph_chip.svg")
		if chip_tex:
			var chip := TextureRect.new()
			chip.texture = chip_tex
			chip.custom_minimum_size = Vector2(20, 20)
			chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.modulate = Color("FFEC00")
			amount_hb.add_child(chip)

		var amt := Label.new()
		amt.add_theme_font_size_override("font_size", 18)
		amt.add_theme_color_override("font_color", Color("FFEC00"))
		amt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		amt.add_theme_constant_override("outline_size", 2)
		_set_chip_amount_text(amt, ConfigManager.get_gift_chips(), GIFT_BTN_W - 40)
		amount_hb.add_child(amt)
	else:
		_shop_gift_icon.texture = load("res://assets/shop/gift_box_icon.png")

		var timer_label := Label.new()
		timer_label.name = "Timer"
		timer_label.text = "--H --M --S"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 22)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		timer_label.add_theme_constant_override("outline_size", 3)
		_shop_gift_label_area.add_child(timer_label)


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
	# Idle tilt: tiny back-and-forth rotation with randomised phase per card
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	var tilt_phase: float = randf_range(0.0, 1.5)
	var tilt := card.create_tween()
	tilt.set_loops()
	tilt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tilt.tween_interval(tilt_phase)
	tilt.tween_property(card, "rotation", deg_to_rad(1.2), 1.8).from(deg_to_rad(-1.2))
	tilt.tween_property(card, "rotation", deg_to_rad(-1.2), 1.8)

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
	buy_btn.pressed.connect(func() -> void:
		var spawn_pos: Vector2 = buy_btn.global_position + buy_btn.size * 0.5
		_on_shop_buy(total, spawn_pos)
	)
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
	pc.clip_contents = true
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
	# Diagonal shine sweep every ~3 sec
	_attach_shimmer_sweep(pc, 3.0, Color(1, 1, 1, 0.7))
	return pc


## Overlays a diagonal white shimmer stripe that sweeps across the control
## from left to right once every `period` seconds. Works on any Control via
## `draw.connect`. Only shows inside clip_contents.
func _attach_shimmer_sweep(ctrl: Control, period: float = 3.0, color: Color = Color(1, 1, 1, 0.4), pause: float = -1.0) -> void:
	# We animate a float "shimmer_t" 0..1, then use it in _draw to paint a
	# slanted polygon moving across the control's rect.
	var state := {"t": -0.2}
	var pause_time: float = pause if pause >= 0.0 else period * 0.4
	var tick := func() -> void:
		var tw := ctrl.create_tween()
		tw.set_loops()
		tw.tween_method(func(val: float) -> void:
			state["t"] = val
			ctrl.queue_redraw()
		, -0.3, 1.3, period).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(pause_time)
	tick.call()
	ctrl.draw.connect(func() -> void:
		var t: float = state["t"]
		if t < 0.0 or t > 1.0:
			return
		var w: float = ctrl.size.x
		var h: float = ctrl.size.y
		var cx: float = lerp(-w * 0.4, w * 1.1, t)
		var half: float = w * 0.08
		var skew: float = h * 0.6
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(cx - half, -2),
			Vector2(cx + half, -2),
			Vector2(cx + half - skew, h + 2),
			Vector2(cx - half - skew, h + 2),
		])
		ctrl.draw_colored_polygon(poly, color)
	)


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


func _on_shop_buy(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(amount)
	SaveManager.save_game()
	# Shop stays open — cascade flies to the shop-side cash pill.
	if from_pos != Vector2.ZERO:
		_spawn_confetti_burst(from_pos)
		_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)
	else:
		_animate_balance_increment(old_credits, SaveManager.credits, 0.9)


## Local confetti burst — 14 coloured squares that fly out radially from
## `from_pos`, rotate, fade, and free themselves. Pure Control-based (no
## GPUParticles2D so it works fine on the web renderer).
func _spawn_confetti_burst(from_pos: Vector2) -> void:
	var colors: Array = [
		Color("FFEC00"), Color("FF5577"), Color("49C8FF"),
		Color("7FE7A0"), Color("FF9A2E"), Color("D67AFF"),
	]
	for i in 14:
		var piece := ColorRect.new()
		var sz := randf_range(6.0, 10.0)
		piece.custom_minimum_size = Vector2(sz, sz)
		piece.size = Vector2(sz, sz)
		piece.color = colors[i % colors.size()]
		piece.pivot_offset = piece.size * 0.5
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 600
		piece.global_position = from_pos - piece.size * 0.5
		add_child(piece)

		var angle: float = randf_range(-PI, PI)
		var dist: float = randf_range(80.0, 180.0)
		var target: Vector2 = piece.global_position + Vector2(cos(angle), sin(angle)) * dist
		var duration: float = randf_range(0.45, 0.75)
		var tw := piece.create_tween().set_parallel(true)
		tw.tween_property(piece, "global_position", target, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(piece, "rotation", randf_range(-TAU, TAU), duration)
		tw.tween_property(piece, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(piece.queue_free)


func _hide_shop() -> void:
	if _shop_overlay:
		# Kill any active shop drag/inertia before tearing down
		if _inertia_tween and _inertia_tween.is_running():
			_inertia_tween.kill()
		_drag_active = false
		_overscroll = 0.0
		_shop_overlay.queue_free()
		_shop_overlay = null
	_shop_cash_cd = {}
	_shop_cash_pill = null
	_shop_gift_widget = null
	_shop_gift_icon = null
	_shop_gift_label_area = null
	# Restore lobby drag-scroll target
	if _lobby_scroll_backup:
		_scroll_ref = _lobby_scroll_backup
		_drag_content = _lobby_drag_content_backup
		_drag_hit_rect_fn = _lobby_hit_rect_backup
		_lobby_scroll_backup = null
		_lobby_drag_content_backup = null
		_lobby_hit_rect_backup = Callable()
