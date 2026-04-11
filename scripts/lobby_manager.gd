extends Control

signal machine_selected(variant_id: String)

var MachineCardScene: PackedScene = null

const MACHINE_CONFIG := [
	{
		"id": "deuces_and_joker",
		"name": "Deuces & Joker",
		"color": Color(0.05, 0.5, 0.45),
		"accent": Color(0.8, 0.15, 0.15),
		"mini": "5 wild cards (4 Deuces + Joker)\nMin hand: Three of a Kind\n4 Deuces+Joker at Max Bet: 10,000\nNatural Royal: 4000\nHighest jackpot among all variants",
		"locked": false,
	},
	{
		"id": "jacks_or_better",
		"name": "Jacks or Better",
		"color": Color(0.2, 0.3, 0.8),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "The classic 9/6 full pay variant\nMin hand: Pair of Jacks+\nRoyal Flush: 4000 (Max Bet)\nFull House: 9 | Flush: 6\nRTP: 99.54% | Low variance",
		"locked": false,
	},
	{
		"id": "bonus_poker",
		"name": "Bonus Poker",
		"color": Color(0.75, 0.15, 0.15),
		"accent": Color(0.75, 0.75, 0.8),
		"mini": "Enhanced Four of a Kind payouts by rank\n4 Aces: 80 | 4 Twos-Fours: 40\nFull House: 8 | Flush: 5\nRTP: 99.17% | Low variance",
		"locked": false,
	},
	{
		"id": "deuces_wild",
		"name": "Deuces Wild",
		"color": Color(0.1, 0.7, 0.2),
		"accent": Color(1.0, 0.9, 0.1),
		"mini": "All four 2s are wild cards\nMin hand: Three of a Kind\n4 Deuces: 200 | Natural Royal: 4000\n5 of a Kind possible!\nRTP: 99.73% | Low variance",
		"locked": false,
	},
	{
		"id": "double_bonus",
		"name": "Double Bonus",
		"color": Color(0.6, 0.1, 0.1),
		"accent": Color(0.75, 0.75, 0.8),
		"mini": "Doubled Four of a Kind payouts\n4 Aces: 160 | 4 2s-4s: 80 | 4 5s-Ks: 50\nTwo Pair pays only 1\nRTP: 100.17% | Medium-High variance",
		"locked": false,
	},
	{
		"id": "bonus_poker_deluxe",
		"name": "Bonus Poker Deluxe",
		"color": Color(0.5, 0.1, 0.5),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "All Four of a Kind pays 80\nSimpler than Bonus Poker\nTwo Pair pays only 1\nFull House: 9 | Flush: 6\nRTP: 99.64% | Medium variance",
		"locked": false,
	},
	{
		"id": "double_double_bonus",
		"name": "Double Double Bonus",
		"color": Color(0.45, 0.05, 0.15),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "Kicker bonus on Four of a Kind!\n4 Aces + 2/3/4 kicker: 400\n4 2s-4s + A/2/3/4 kicker: 160\nTwo Pair pays only 1\nRTP: 100.07% | High variance",
		"locked": false,
	},
	{
		"id": "triple_double_bonus",
		"name": "Triple Double Bonus",
		"color": Color(0.08, 0.08, 0.08),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "Extreme kicker payouts!\n4 Aces + 2/3/4: 800 (=4000 at Max Bet)\n4 2s-4s + A/2/3/4: 400\nThree of a Kind pays only 2\nRTP: 99.58% | Very High variance",
		"locked": false,
	},
	{
		"id": "aces_and_faces",
		"name": "Aces and Faces",
		"color": Color(0.1, 0.5, 0.2),
		"accent": Color(0.75, 0.75, 0.8),
		"mini": "Bonus quads for Aces & Face cards\n4 Aces: 80 | 4 J/Q/K: 40 | 4 2s-10s: 25\nFull House: 8 | Flush: 5\nRTP: 99.26% | Low-Medium variance",
		"locked": false,
	},
	{
		"id": "joker_poker",
		"name": "Joker Poker",
		"color": Color(0.4, 0.1, 0.6),
		"accent": Color(1.0, 0.9, 0.1),
		"mini": "53-card deck with 1 Joker (wild)\nMin hand: Pair of Kings+\n5 of a Kind: 200 | Wild Royal: 100\nRTP: 100.65% | Low-Medium variance",
		"locked": false,
	},
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
	{"label": "SINGLE PLAY", "hands": 1},
	{"label": "TRIPLE PLAY", "hands": 3},
	{"label": "FIVE PLAY", "hands": 5},
	{"label": "TEN PLAY", "hands": 10},
	{"label": "12 PLAY", "hands": 12},
	{"label": "25 PLAY", "hands": 25},
]
var _active_mode: int = 0
var _sidebar_buttons: Array[Button] = []


func _ready() -> void:
	MachineCardScene = load("res://scenes/lobby/machine_card.tscn")
	_paytables = Paytable.load_all()
	_apply_theme()
	_cash_label.text = "CASH:"
	_cash_cd = SaveManager.create_currency_display(40, Color.WHITE)
	_cash_label.get_parent().add_child(_cash_cd["box"])
	_cash_label.get_parent().move_child(_cash_cd["box"], _cash_label.get_index() + 1)
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_credits_label.text = "CREDITS: %d" % SaveManager.credits
	_build_carousel()


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

	# Find active mode from SaveManager
	for j in PLAY_MODES.size():
		if PLAY_MODES[j]["hands"] == SaveManager.hand_count:
			_active_mode = j
			break

	_sidebar_buttons.clear()
	for i in PLAY_MODES.size():
		var btn := Button.new()
		btn.text = PLAY_MODES[i]["label"]
		btn.custom_minimum_size = Vector2(320, 80)
		_style_sidebar_btn(btn, i == _active_mode)
		btn.pressed.connect(_on_mode_selected.bind(i))
		_sidebar.add_child(btn)
		_sidebar_buttons.append(btn)


func _on_mode_selected(index: int) -> void:
	_active_mode = index
	SaveManager.hand_count = PLAY_MODES[index]["hands"]
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
		card_node.setup(
			config["id"],
			config["name"],
			config["color"],
			config["accent"],
			rtp,
			config["mini"],
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
	_credits_label.text = "CREDITS: %d" % SaveManager.credits
