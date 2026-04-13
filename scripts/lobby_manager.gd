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

const MODE_COLORS := {
	1: Color(0.75, 0.12, 0.12),    # Single — red
	3: Color(0.12, 0.45, 0.75),    # Triple — blue
	5: Color(0.12, 0.6, 0.25),     # Five — green
	10: Color(0.6, 0.4, 0.1),      # Ten — gold
	12: Color(0.5, 0.15, 0.55),    # 12 — purple
	25: Color(0.15, 0.15, 0.15),   # 25 — dark
}

const PLAY_MODES := [
	{"label_key": "lobby.mode_single_play", "hands": 1, "ultra_vp": false, "spin_poker": false},
	{"label_key": "lobby.mode_triple_play", "hands": 3, "ultra_vp": false, "spin_poker": false},
	{"label_key": "lobby.mode_five_play", "hands": 5, "ultra_vp": false, "spin_poker": false},
	{"label_key": "lobby.mode_ten_play", "hands": 10, "ultra_vp": false, "spin_poker": false},
	{"label_key": "lobby.mode_ultra_vp", "hands": 5, "ultra_vp": true, "spin_poker": false},
	{"label_key": "lobby.mode_spin_poker", "hands": 1, "ultra_vp": false, "spin_poker": true},
]
var _active_mode: int = 0
var _sidebar_buttons: Array[Button] = []


func _ready() -> void:
	MachineCardScene = load("res://scenes/lobby/machine_card.tscn")
	_paytables = Paytable.load_all()
	_apply_theme()
	_cash_label.text = Translations.tr_key("lobby.cash")
	_cash_cd = SaveManager.create_currency_display(40, Color.WHITE)
	_cash_label.get_parent().add_child(_cash_cd["box"])
	_cash_label.get_parent().move_child(_cash_cd["box"], _cash_label.get_index() + 1)
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_credits_label.text = Translations.tr_key("lobby.credits_fmt", [SaveManager.credits])
	_build_carousel()
	_build_settings_button()


func _apply_theme() -> void:
	$VBoxContainer.add_theme_constant_override("separation", 0)

	# TopBar: red gradient background
	var top_bar := $VBoxContainer/TopBar as HBoxContainer
	var top_bar_style := StyleBoxFlat.new()
	top_bar_style.bg_color = Color(0.7, 0.1, 0.1)
	top_bar_style.content_margin_left = 48
	top_bar_style.content_margin_right = 48
	top_bar_style.content_margin_top = 16
	top_bar_style.content_margin_bottom = 16
	top_bar.add_theme_stylebox_override("panel", top_bar_style)
	# HBoxContainer doesn't support "panel" stylebox natively, so use a draw callback
	top_bar.draw.connect(func() -> void:
		top_bar_style.draw(top_bar.get_canvas_item(), Rect2(Vector2.ZERO, top_bar.size))
	)
	top_bar.add_theme_constant_override("separation", 0)

	# CashLabel: white, left
	_cash_label.add_theme_font_size_override("font_size", 40)
	_cash_label.add_theme_color_override("font_color", Color.WHITE)

	# Title "VIDEO POKER": yellow, bold, centered
	var title := %LobbyTitle as Label
	title.text = Translations.tr_key("lobby.title")
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# LobbyCredits: keep for compatibility but hide
	_credits_label.visible = false

	# Sidebar: play mode tabs
	_build_sidebar()

	# Content area spacing
	$VBoxContainer/ContentHBox.add_theme_constant_override("separation", 0)

	# Grid: spacing and margins
	# Scroll: hide scrollbar, enable mouse drag
	var scroll := %GridScroll as ScrollContainer
	scroll.get_h_scroll_bar().modulate.a = 0
	_setup_drag_scroll(scroll)

	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)

	var grid_margin := $VBoxContainer/ContentHBox/GridMargin as MarginContainer
	grid_margin.add_theme_constant_override("margin_left", 30)
	grid_margin.add_theme_constant_override("margin_right", 60)
	grid_margin.add_theme_constant_override("margin_top", 24)
	grid_margin.add_theme_constant_override("margin_bottom", 24)


func _build_sidebar() -> void:
	_sidebar.add_theme_constant_override("separation", 12)
	# Sidebar background
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb_style.content_margin_left = 16
	sb_style.content_margin_right = 16
	sb_style.content_margin_top = 24
	sb_style.content_margin_bottom = 24
	_sidebar.add_theme_stylebox_override("panel", sb_style)
	# Draw background manually since VBoxContainer doesn't support panel
	_sidebar.draw.connect(func() -> void:
		sb_style.draw(_sidebar.get_canvas_item(), Rect2(Vector2.ZERO, _sidebar.size))
	)
	_sidebar.custom_minimum_size.x = 360

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
		btn.custom_minimum_size = Vector2(320, 80)
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
	_recolor_machines()


func _style_sidebar_btn(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.53) if active else Color(0.12, 0.12, 0.35)
	style.set_border_width_all(4)
	style.border_color = Color(0.7, 0.6, 0.2) if active else Color(0.3, 0.3, 0.5)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color("FFEC00") if active else Color(0.8, 0.8, 0.6))


var _drag_active := false
var _drag_start_x := 0.0
var _drag_scroll_start := 0
var _scroll_ref: ScrollContainer = null

func _setup_drag_scroll(scroll: ScrollContainer) -> void:
	_scroll_ref = scroll


func _input(event: InputEvent) -> void:
	if _scroll_ref == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if click is within scroll area
			var scroll_rect := _scroll_ref.get_global_rect()
			if scroll_rect.has_point(event.global_position):
				_drag_active = true
				_drag_start_x = event.global_position.x
				_drag_scroll_start = _scroll_ref.scroll_horizontal
		else:
			_drag_active = false
	elif event is InputEventMouseMotion and _drag_active:
		var delta: float = _drag_start_x - event.global_position.x
		_scroll_ref.scroll_horizontal = _drag_scroll_start + int(delta)


func _build_carousel() -> void:
	_machine_cards.clear()
	for config in MACHINE_CONFIG:
		var card_node: PanelContainer = MachineCardScene.instantiate()
		_grid.add_child(card_node)
		var rtp: float = 0.0
		if config["id"] in _paytables:
			rtp = _paytables[config["id"]].rtp
		var display_name := Translations.tr_key("machine.%s.name" % config["id"])
		var mini_text := Translations.tr_key("machine.%s.mini" % config["id"])
		card_node.setup(
			config["id"],
			display_name,
			config["color"],
			config["accent"],
			rtp,
			mini_text,
			config["locked"],
		)
		card_node.play_pressed.connect(_on_play_pressed)
		_machine_cards.append(card_node)
	_recolor_machines()


func _recolor_machines() -> void:
	var hands: int = PLAY_MODES[_active_mode]["hands"]
	var base_color: Color = MODE_COLORS.get(hands, Color(0.75, 0.12, 0.12))
	for card in _machine_cards:
		card.set_color(base_color)


func _on_play_pressed(variant_id: String) -> void:
	SaveManager.last_variant = variant_id
	machine_selected.emit(variant_id)


func refresh_credits() -> void:
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_credits_label.text = Translations.tr_key("lobby.credits_fmt", [SaveManager.credits])


# --- Settings popup ----------------------------------------------------------

var _settings_btn: Button
var _settings_overlay: Control = null

func _build_settings_button() -> void:
	_settings_btn = Button.new()
	_settings_btn.text = "⚙"
	_settings_btn.add_theme_font_size_override("font_size", 40)
	_settings_btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	_settings_btn.add_theme_stylebox_override("normal", style)
	_settings_btn.add_theme_stylebox_override("hover", style)
	_settings_btn.add_theme_stylebox_override("pressed", style)
	_settings_btn.custom_minimum_size = Vector2(56, 56)
	_settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_settings_btn.pressed.connect(_show_settings)
	# Add to top bar (after the cash currency display)
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

	# Close button
	var close_btn := Button.new()
	close_btn.text = Translations.tr_key("settings.close")
	close_btn.custom_minimum_size = Vector2(280, 48)
	_style_lang_btn(close_btn, false)
	close_btn.pressed.connect(_hide_settings)
	vbox.add_child(close_btn)


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
