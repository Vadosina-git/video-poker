extends Control

## Spin Poker UI: 3×5 card grid, 20 fixed lines, slot-style spin animation.

signal back_to_lobby

const COL_YELLOW := Color("FFEC00")
const COL_BTN_TEXT := Color("3F2A00")
const BG_COLOR := Color(0.15, 0.0, 0.35)
const GRID_BG := Color(0.25, 0.15, 0.45, 0.6)

var BET_AMOUNTS: Array = []

var _variant: BaseVariant
var _manager: SpinPokerManager
var _current_denomination: int = 1
var _animating: bool = false
var _last_total_payout: int = 0
var _rush: bool = false
var _win_increment_tween: Tween = null
var _balance_show_depth: bool = false
var _depth_tooltip: Control = null

# UI refs
var _game_title: Label
var _status_label: Label
var _game_pays_label: Label
var _deal_draw_btn: Button
var _bet_btn: Button
var _bet_max_btn: Button
var _bet_amount_btn: Button
var _speed_btn: Button
var _back_btn: Button
var _see_pays_btn: Button
var _win_label: Label
var _win_cd: Dictionary
var _balance_label: Label
var _balance_cd: Dictionary
var _bet_display_label: Label
var _bet_display_cd: Dictionary

# Grid: 3 rows × 5 cols of TextureRect
var _card_rects: Array = [[], [], []]  # _card_rects[row][col]
var _grid_container: Control
var _grid_panel: PanelContainer
var _held_indicators: Array = []  # 5 Control nodes (held_rect.svg + HELD label)

# Line indicators (ribbon icons on left/right of grid)

# Shutters (top/bottom row covers during spin)
var _shutters: Array = []

# Win line drawing + badge
var _line_draw_node: Control
var _winning_lines: Array = []
var _current_win_cycle: int = -1
var _blink_tween: Tween
var _win_badge: PanelContainer = null
var _idle_blink_tween: Tween = null
var _idle_timer: SceneTreeTimer = null

# Speed
var _speed_level: int = 1
const SPEED_LABELS := ["1x", "2x", "3x", "MAX"]
const SPEED_CONFIGS := [
	{"spin_ms": 50, "base_spin_ms": 3500, "col_stop_ms": 900, "inertia_ms": 700},
	{"spin_ms": 40, "base_spin_ms": 2200, "col_stop_ms": 600, "inertia_ms": 500},
	{"spin_ms": 30, "base_spin_ms": 1200, "col_stop_ms": 350, "inertia_ms": 300},
	{"spin_ms": 20, "base_spin_ms": 0,    "col_stop_ms": 0,   "inertia_ms": 0},
]

# Card path helpers — spin poker uses square SVG cards from cards_spin/
const SPIN_CARD_DIR := "res://assets/cards/cards_spin/"
const SUIT_CODES := {
	CardData.Suit.HEARTS: "h", CardData.Suit.DIAMONDS: "d",
	CardData.Suit.CLUBS: "c", CardData.Suit.SPADES: "s",
}
const SUIT_CODES_CLUBS_CYR := "\u0441"  # Cyrillic с (used for number cards in spin assets)
const RANK_CODES := {
	CardData.Rank.TWO: "2", CardData.Rank.THREE: "3", CardData.Rank.FOUR: "4",
	CardData.Rank.FIVE: "5", CardData.Rank.SIX: "6", CardData.Rank.SEVEN: "7",
	CardData.Rank.EIGHT: "8", CardData.Rank.NINE: "9", CardData.Rank.TEN: "10",
	CardData.Rank.JACK: "j", CardData.Rank.QUEEN: "q", CardData.Rank.KING: "k",
	CardData.Rank.ACE: "a",
}
const FACE_RANKS := [CardData.Rank.JACK, CardData.Rank.QUEEN, CardData.Rank.KING, CardData.Rank.ACE]


func setup(variant: BaseVariant) -> void:
	_variant = variant
	_manager = SpinPokerManager.new()
	_manager.setup(variant)
	_manager.state_changed.connect(_on_state_changed)
	_manager.deal_spin_complete.connect(_on_deal_spin_complete)
	_manager.draw_spin_complete.connect(_on_draw_spin_complete)
	_manager.lines_evaluated.connect(_on_lines_evaluated)
	_manager.credits_changed.connect(_on_credits_changed)
	_manager.bet_changed.connect(_on_bet_changed)


func _ready() -> void:
	BET_AMOUNTS = ConfigManager.get_denominations("spin_poker")
	_speed_level = SaveManager.speed_level
	_current_denomination = SaveManager.denomination
	_build_ui()
	_resize_grid.call_deferred()
	_current_denomination = _recommend_denomination()
	SaveManager.denomination = _current_denomination
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)
	_update_bet_amount_btn()
	_update_speed_label()


# ─── UI CONSTRUCTION ──────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	bg.z_index = -1

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 2)
	add_child(root_vbox)

	var bold := SystemFont.new()
	bold.font_weight = 700

	# ── Top: [exit icon] [title centered]
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(title_bar)

	_back_btn = TopBarBuilder.create_exit_button()
	_back_btn.pressed.connect(_on_back_pressed)
	title_bar.add_child(_back_btn)

	_game_title = Label.new()
	_game_title.text = "SPIN POKER — %s" % _variant.paytable.name.to_upper()
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 18)
	_game_title.add_theme_color_override("font_color", COL_YELLOW)
	_game_title.add_theme_font_override("font", bold)
	_game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_game_title)

	# ── Middle: grid area with line labels — centered, fixed proportions
	var grid_area := HBoxContainer.new()
	grid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_area.add_theme_constant_override("separation", 0)
	grid_area.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(grid_area)

	# Left line ribbons (pointing right → toward grid), distributed by start row
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 0)
	left_col.custom_minimum_size.x = 40
	grid_area.add_child(left_col)
	# Top row (row 0): lines 2,4,6,10 → indices 1,3,5,9
	var left_top := HBoxContainer.new()
	left_top.add_theme_constant_override("separation", 1)
	left_top.alignment = BoxContainer.ALIGNMENT_CENTER
	left_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(left_top)
	for i in [1, 3, 5, 9]:
		left_top.add_child(_make_line_ribbon(i, false))
	# Mid row (row 1): lines 1,8,9 → indices 0,7,8
	var left_mid := HBoxContainer.new()
	left_mid.add_theme_constant_override("separation", 1)
	left_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	left_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(left_mid)
	for i in [0, 7, 8]:
		left_mid.add_child(_make_line_ribbon(i, false))
	# Bot row (row 2): lines 3,5,7 → indices 2,4,6
	var left_bot := HBoxContainer.new()
	left_bot.add_theme_constant_override("separation", 1)
	left_bot.alignment = BoxContainer.ALIGNMENT_CENTER
	left_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(left_bot)
	for i in [2, 4, 6]:
		left_bot.add_child(_make_line_ribbon(i, false))

	# Grid panel — silver border frame, no expand, centered
	_grid_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.75, 0.75, 0.8)  # Silver/light gray frame
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.85, 0.9)
	panel_style.set_corner_radius_all(2)
	panel_style.content_margin_left = 2
	panel_style.content_margin_right = 2
	panel_style.content_margin_top = 3
	panel_style.content_margin_bottom = 3
	_grid_panel.add_theme_stylebox_override("panel", panel_style)
	_grid_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_area.add_child(_grid_panel)

	_grid_container = GridContainer.new()
	_grid_container.columns = 5
	_grid_container.add_theme_constant_override("h_separation", 0)
	_grid_container.add_theme_constant_override("v_separation", 0)
	_grid_panel.add_child(_grid_container)

	# Build 15 card slots (3 rows × 5 cols), square cards (184×184 SVGs)
	var back_tex: Texture2D = null
	var card_back_path := SPIN_CARD_DIR + "card_back_spin.svg"
	if ResourceLoader.exists(card_back_path):
		back_tex = load(card_back_path)

	for row in 3:
		_card_rects[row] = []
		for col in 5:
			var tex_rect := TextureRect.new()
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(80, 80)
			tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tex_rect.texture = back_tex
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP if row == 1 else Control.MOUSE_FILTER_IGNORE
			if row == 1:
				var c := col
				tex_rect.gui_input.connect(_on_card_clicked.bind(c))
			_grid_container.add_child(tex_rect)
			_card_rects[row].append(tex_rect)

	# Line draw overlay
	_line_draw_node = Control.new()
	_line_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_draw_node.draw.connect(_draw_lines)
	_grid_panel.add_child(_line_draw_node)

	# Right line ribbons (pointing left → toward grid, flipped), distributed by start row
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 0)
	right_col.custom_minimum_size.x = 40
	grid_area.add_child(right_col)
	# Top row (row 0): lines 14,16,20 → indices 13,15,19
	var right_top := HBoxContainer.new()
	right_top.add_theme_constant_override("separation", 1)
	right_top.alignment = BoxContainer.ALIGNMENT_CENTER
	right_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(right_top)
	for i in [13, 15, 19]:
		right_top.add_child(_make_line_ribbon(i, true))
	# Mid row (row 1): lines 12,13,18,19 → indices 11,12,17,18
	var right_mid := HBoxContainer.new()
	right_mid.add_theme_constant_override("separation", 1)
	right_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	right_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(right_mid)
	for i in [11, 12, 17, 18]:
		right_mid.add_child(_make_line_ribbon(i, true))
	# Bot row (row 2): lines 11,15,17 → indices 10,14,16
	var right_bot := HBoxContainer.new()
	right_bot.add_theme_constant_override("separation", 1)
	right_bot.alignment = BoxContainer.ALIGNMENT_CENTER
	right_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(right_bot)
	for i in [10, 14, 16]:
		right_bot.add_child(_make_line_ribbon(i, true))

	# ── Status + game pays: inline labels (no separate bar, prevents layout jumps)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.add_theme_font_override("font", bold)

	_game_pays_label = Label.new()
	_game_pays_label.text = ""
	_game_pays_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_pays_label.add_theme_font_size_override("font_size", 14)
	_game_pays_label.add_theme_color_override("font_color", COL_YELLOW)
	_game_pays_label.add_theme_font_override("font", bold)
	_game_pays_label.visible = false

	# ── Bottom bar
	_build_bottom_bar(root_vbox, bold)


func _resize_grid() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# Calculate available height between title and bottom bar
	var viewport_h: float = get_viewport_rect().size.y
	var title_bottom: float = _game_title.get_global_rect().end.y
	# Bottom bar area ~120px from bottom
	var available_h: float = viewport_h - title_bottom - 140
	# 3 rows of square cells → cell size = available_h / 3
	var cell_sz: float = floorf(available_h / 3.0)
	cell_sz = maxf(cell_sz, 80.0)  # minimum 80
	for row in 3:
		for col in 5:
			(_card_rects[row][col] as TextureRect).custom_minimum_size = Vector2(cell_sz, cell_sz)


func _build_bottom_bar(root_vbox: VBoxContainer, bold: SystemFont) -> void:
	# Status row: status left, game pays right (fixed height, no layout jumps)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 16)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(status_row)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status_label)
	_game_pays_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_game_pays_label)

	# Info row: WIN | BET | CREDIT
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_row.custom_minimum_size.x = 800
	root_vbox.add_child(info_row)

	_win_label = Label.new()
	_win_label.text = Translations.tr_key("game.win_label")
	_win_label.add_theme_font_size_override("font_size", 14)
	_win_label.add_theme_color_override("font_color", Color.WHITE)
	_win_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_label.gui_input.connect(_on_credits_toggle)
	info_row.add_child(_win_label)
	_win_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_win_cd["box"].mouse_filter = Control.MOUSE_FILTER_STOP
	_win_cd["box"].gui_input.connect(_on_credits_toggle)
	info_row.add_child(_win_cd["box"])

	_bet_display_label = Label.new()
	_bet_display_label.text = Translations.tr_key("game.total_bet")
	_bet_display_label.add_theme_font_size_override("font_size", 14)
	_bet_display_label.add_theme_color_override("font_color", Color.WHITE)
	_bet_display_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_bet_display_label.gui_input.connect(_on_credits_toggle)
	info_row.add_child(_bet_display_label)
	_bet_display_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_bet_display_cd["box"].mouse_filter = Control.MOUSE_FILTER_STOP
	_bet_display_cd["box"].gui_input.connect(_on_credits_toggle)
	info_row.add_child(_bet_display_cd["box"])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(spacer)

	_balance_label = Label.new()
	_balance_label.text = Translations.tr_key("game.balance")
	_balance_label.add_theme_font_size_override("font_size", 14)
	_balance_label.add_theme_color_override("font_color", Color.WHITE)
	_balance_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_balance_label.gui_input.connect(_on_credits_toggle)
	info_row.add_child(_balance_label)
	_balance_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_balance_cd["box"].mouse_filter = Control.MOUSE_FILTER_STOP
	_balance_cd["box"].gui_input.connect(_on_credits_toggle)
	info_row.add_child(_balance_cd["box"])

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_row.custom_minimum_size.x = 800
	root_vbox.add_child(btn_row)

	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_yellow.svg") else null
	var tex_blue := load("res://assets/textures/btn_rect_blue.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_blue.svg") else null
	var tex_green := load("res://assets/textures/btn_rect_green.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_green.svg") else null

	_see_pays_btn = Button.new()
	_see_pays_btn.text = Translations.tr_key("spin.see_pays")
	_style_btn(_see_pays_btn, tex_blue, Color.WHITE, 13, 90, 36)
	_see_pays_btn.pressed.connect(_show_paytable)
	btn_row.add_child(_see_pays_btn)

	_bet_amount_btn = Button.new()
	_bet_amount_btn.text = ""
	_style_btn(_bet_amount_btn, tex_blue, Color.WHITE, 13, 90, 36)
	_bet_amount_btn.pressed.connect(_on_bet_amount_pressed)
	btn_row.add_child(_bet_amount_btn)

	_deal_draw_btn = Button.new()
	_deal_draw_btn.text = "DEAL\nSPIN"
	_style_btn(_deal_draw_btn, tex_green, Color.WHITE, 14, 100, 44)
	_deal_draw_btn.pressed.connect(_on_deal_draw_pressed)
	btn_row.add_child(_deal_draw_btn)

	# BET and BET MAX removed from Spin Poker (5.7) — bet fixed at max
	_bet_btn = Button.new()
	_bet_btn.visible = false
	btn_row.add_child(_bet_btn)
	_bet_max_btn = Button.new()
	_bet_max_btn.visible = false
	btn_row.add_child(_bet_max_btn)

	_speed_btn = Button.new()
	_speed_btn.text = "SPEED 1x"
	_style_btn(_speed_btn, tex_blue, Color.WHITE, 12, 80, 36)
	_speed_btn.pressed.connect(_on_speed_pressed)
	btn_row.add_child(_speed_btn)


func _style_btn(btn: Button, tex: Texture2D, text_col: Color, font_sz: int, min_w: int, min_h: int) -> void:
	if tex:
		var style := StyleBoxTexture.new()
		style.texture = tex
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		style.texture_margin_left = 10
		style.texture_margin_right = 10
		style.texture_margin_top = 10
		style.texture_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.modulate_color = Color(1.1, 1.1, 1.1)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed := style.duplicate()
		pressed.modulate_color = Color(0.85, 0.85, 0.85)
		btn.add_theme_stylebox_override("pressed", pressed)
		var disabled := style.duplicate()
		disabled.modulate_color = Color(0.5, 0.5, 0.5)
		btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.custom_minimum_size = Vector2(min_w, min_h)
	_add_press_effect(btn)


func _add_press_effect(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.05)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	)


func _make_line_ribbon(line_idx: int, flip: bool) -> Control:
	var color: Color = SpinPokerManager.LINE_COLORS[line_idx]
	var container := Control.new()
	container.custom_minimum_size = Vector2(38, 18)
	# Ribbon background
	var ribbon_path := "res://assets/textures/spin_ribbon.svg"
	if ResourceLoader.exists(ribbon_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(ribbon_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.modulate = color
		if flip:
			tex_rect.flip_h = true
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(tex_rect)
	# Number text
	var lbl := Label.new()
	lbl.text = "%d" % (line_idx + 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	var bold := SystemFont.new()
	bold.font_weight = 700
	lbl.add_theme_font_override("font", bold)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)
	return container


# ─── CARD RENDERING ────────────────────────────────────────────────────

func _get_suit_code(card: CardData) -> String:
	if card.suit == CardData.Suit.CLUBS:
		# Number cards use Cyrillic "с", face cards use Latin "c" in spin assets
		if card.rank in FACE_RANKS:
			return "c"
		return SUIT_CODES_CLUBS_CYR
	return SUIT_CODES.get(card.suit, "")


func _get_card_path(card: CardData) -> String:
	if card == null:
		return SPIN_CARD_DIR + "card_back_spin.svg"
	if card.is_joker():
		return SPIN_CARD_DIR + "vp joker red.svg"
	if _variant.is_wild_card(card) and card.rank == CardData.Rank.TWO:
		var s := _get_suit_code(card)
		return SPIN_CARD_DIR + "card_vp_wild%s.svg" % s
	var r: String = RANK_CODES.get(card.rank, "")
	var s := _get_suit_code(card)
	return SPIN_CARD_DIR + "card_vp_%s%s.svg" % [r, s]


func _set_card_texture(row: int, col: int, card: CardData) -> void:
	var path := _get_card_path(card)
	if ResourceLoader.exists(path):
		_card_rects[row][col].texture = load(path)
	_card_rects[row][col].modulate = Color.WHITE


func _set_card_back(row: int, col: int) -> void:
	var path := SPIN_CARD_DIR + "card_back_spin.svg"
	if ResourceLoader.exists(path):
		_card_rects[row][col].texture = load(path)
	_card_rects[row][col].modulate = Color.WHITE


func _reset_all_modulate() -> void:
	for row in 3:
		for col in 5:
			_card_rects[row][col].modulate = Color.WHITE


# ─── HELD INDICATORS (multihand style: held_rect.svg + HELD text) ────

func _show_held(col: int, show: bool) -> void:
	if col >= _held_indicators.size():
		return
	_held_indicators[col].visible = show


func _build_held_indicators() -> void:
	for indicator in _held_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_held_indicators.clear()
	for col in 5:
		var container := Control.new()
		container.visible = false
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.z_index = 5

		# Background: held_rect.svg
		var held_tex_rect := TextureRect.new()
		var held_tex_path := "res://assets/textures/held_rect.svg"
		if ResourceLoader.exists(held_tex_path):
			held_tex_rect.texture = load(held_tex_path)
		held_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		held_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		held_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.add_child(held_tex_rect)

		# Text "HELD"
		var held_text := Label.new()
		held_text.text = "HELD"
		held_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		held_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		held_text.add_theme_font_size_override("font_size", 13)
		held_text.add_theme_color_override("font_color", Color("3F2A00"))
		var hbold := SystemFont.new()
		hbold.font_weight = 700
		held_text.add_theme_font_override("font", hbold)
		held_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.add_child(held_text)

		add_child(container)
		_held_indicators.append(container)
	_position_held_indicators.call_deferred()


func _position_held_indicators() -> void:
	await get_tree().process_frame
	for col in 5:
		if col >= _held_indicators.size():
			break
		var card_rect: TextureRect = _card_rects[1][col]
		var rect := card_rect.get_global_rect()
		var indicator: Control = _held_indicators[col]
		var h: float = 22.0
		indicator.size = Vector2(rect.size.x * 0.85, h)
		indicator.global_position = Vector2(
			rect.position.x + (rect.size.x - indicator.size.x) / 2,
			rect.position.y + rect.size.y - h - 2
		)


# ─── STATE HANDLING ───────────────────────────────────────────────────

func _on_state_changed(new_state: int) -> void:
	match new_state:
		SpinPokerManager.State.IDLE:
			_deal_draw_btn.text = "DEAL\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = false
			_bet_max_btn.disabled = false
			_bet_amount_btn.disabled = false
			_bet_amount_btn.modulate.a = 1.0
			_status_label.text = ""
			_game_pays_label.visible = false
			_start_idle_blink_timer()

		SpinPokerManager.State.SPINNING:
			_stop_idle_blink()
			_deal_draw_btn.text = "STOP\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_bet_amount_btn.disabled = true
			_bet_amount_btn.modulate.a = 0.5

		SpinPokerManager.State.HOLDING:
			_deal_draw_btn.text = "DRAW\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_status_label.text = ""

		SpinPokerManager.State.DRAW_SPINNING:
			_deal_draw_btn.text = "STOP\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true

		SpinPokerManager.State.WIN_DISPLAY:
			_deal_draw_btn.text = "DEAL\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true


# ─── ROW FOLD ANIMATION (J.7) ─────────────────────────────────────────

func _animate_rows_fold() -> void:
	_clear_shutters()
	if _rush or SPEED_CONFIGS[_speed_level]["base_spin_ms"] == 0:
		for col in 5:
			_set_card_back(0, col)
			_set_card_back(2, col)
		return

	var shutter_color := Color(0.2, 0.15, 0.35)  # match grid bg
	var close_ms := 400.0
	var cascade_ms := 150.0

	for col in 5:
		for row in [0, 2]:  # top and bottom
			var cell: TextureRect = _card_rects[row][col]
			var shutter := ColorRect.new()
			shutter.color = shutter_color
			shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shutter.z_index = 3
			shutter.global_position = cell.global_position
			if row == 0:
				# Top: grows downward
				shutter.size = Vector2(cell.size.x, 0)
			else:
				# Bottom: grows upward from bottom
				shutter.size = Vector2(cell.size.x, 0)
				shutter.global_position.y += cell.size.y
			add_child(shutter)
			_shutters.append(shutter)

			var tw := create_tween()
			var delay := col * cascade_ms / 1000.0
			if row == 0:
				tw.tween_property(shutter, "size:y", cell.size.y, close_ms / 1000.0).set_delay(delay)
			else:
				tw.tween_property(shutter, "size:y", cell.size.y, close_ms / 1000.0).set_delay(delay)
				tw.parallel().tween_property(shutter, "global_position:y", cell.global_position.y, close_ms / 1000.0).set_delay(delay)

	# Wait for last column
	await get_tree().create_timer((4 * cascade_ms + close_ms) / 1000.0 + 0.05).timeout

	# Set card backs under shutters
	for col in 5:
		_set_card_back(0, col)
		_set_card_back(2, col)


func _clear_shutters() -> void:
	for s in _shutters:
		if is_instance_valid(s):
			s.queue_free()
	_shutters.clear()


# ─── DEAL SPIN ────────────────────────────────────────────────────────

func _on_deal_spin_complete(mid_row: Array[CardData]) -> void:
	_animating = true
	_rush = false
	_stop_win_cycle()
	_clear_line_display()
	_hide_win_badge()
	_game_pays_label.visible = false
	_last_total_payout = 0
	_set_win_dimmed()
	_reset_all_modulate()

	# Clear held
	for col in 5:
		_show_held(col, false)

	# J.7: Animate top/bottom rows folding closed (collapse → card backs)
	await _animate_rows_fold()

	# Animate middle row
	await _animate_spin_deal(mid_row)
	_build_held_indicators()
	_animating = false
	_manager.on_deal_spin_complete()


func _animate_spin_deal(mid_row: Array[CardData]) -> void:
	var cfg: Dictionary = SPEED_CONFIGS[_speed_level]
	var base_ms: int = cfg["base_spin_ms"]
	var col_ms: int = cfg["col_stop_ms"]
	var inertia_ms: int = cfg["inertia_ms"]

	if _rush or base_ms == 0:
		for col in 5:
			_set_card_texture(1, col, mid_row[col])
		return

	# Drum reel: overlay a scrolling strip on each middle-row cell
	var filler_count: int = int(ConfigManager.get_animation("spin_filler_cards_count", 15))
	var bounce_px: float = ConfigManager.get_animation("spin_reel_bounce_px", 5.0)
	var decel_ms: float = ConfigManager.get_animation("spin_reel_deceleration_ms", 800.0)
	var col_delay_ms: float = ConfigManager.get_animation("spin_reel_column_delay_ms", 300.0)
	var random_paths := _build_random_card_paths(filler_count)
	var reel_overlays: Array[Control] = []

	# Create a reel strip overlay for each column
	for col in 5:
		var cell: TextureRect = _card_rects[1][col]
		var cell_size := cell.size
		# Clip container — sits on top of the cell, clips overflow
		var clip := Control.new()
		clip.clip_contents = true
		clip.size = cell_size
		clip.global_position = cell.global_position
		clip.z_index = 5
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		# Vertical strip: filler cards + target card at bottom
		var strip := VBoxContainer.new()
		strip.add_theme_constant_override("separation", 0)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in filler_count:
			var tex := TextureRect.new()
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = cell_size
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var path: String = random_paths[(col * 3 + i) % random_paths.size()]
			if ResourceLoader.exists(path):
				tex.texture = load(path)
			strip.add_child(tex)
		# Target card at the end
		var target_tex := TextureRect.new()
		target_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		target_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		target_tex.custom_minimum_size = cell_size
		target_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var target_path := _get_card_path(mid_row[col])
		if ResourceLoader.exists(target_path):
			target_tex.texture = load(target_path)
		strip.add_child(target_tex)
		clip.add_child(strip)
		# Position strip so first filler is visible
		strip.position.y = 0
		reel_overlays.append(clip)
		# Hide actual card during spin
		cell.modulate.a = 0.0

	# Animate: scroll strips, then stop column by column
	var total_strip_h: float = (_card_rects[1][0].size.y) * (filler_count + 1)
	var target_y: float = -(total_strip_h - _card_rects[1][0].size.y)

	# Base spin phase: all columns scrolling fast (loop scroll via texture cycling)
	var spin_timer := Timer.new()
	spin_timer.wait_time = SPEED_CONFIGS[_speed_level]["spin_ms"] / 1000.0
	spin_timer.autostart = true
	add_child(spin_timer)
	var frame_offsets := [0, 0, 0, 0, 0]
	var col_stopped := [false, false, false, false, false]
	spin_timer.timeout.connect(func() -> void:
		for col in 5:
			if col_stopped[col]:
				continue
			frame_offsets[col] += int(_card_rects[1][col].size.y * 0.6)
			var strip: VBoxContainer = reel_overlays[col].get_child(0)
			strip.position.y = -(frame_offsets[col] % int(total_strip_h))
	)

	await get_tree().create_timer(base_ms / 1000.0).timeout

	# Stop columns left to right with deceleration + bounce
	for col in 5:
		if _rush:
			col_stopped[col] = true
			reel_overlays[col].queue_free()
			_card_rects[1][col].modulate.a = 1.0
			_set_card_texture(1, col, mid_row[col])
			continue
		col_stopped[col] = true
		var strip: VBoxContainer = reel_overlays[col].get_child(0)
		# Decelerate to target position
		var tw := create_tween()
		tw.tween_property(strip, "position:y", target_y - bounce_px, decel_ms / 1000.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(strip, "position:y", target_y, 0.1).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		# Reveal real card, remove overlay
		_card_rects[1][col].modulate.a = 1.0
		_set_card_texture(1, col, mid_row[col])
		reel_overlays[col].queue_free()
		SoundManager.play("spin_stop")
		VibrationManager.vibrate("spin_stop")
		if col < 4:
			await get_tree().create_timer(col_delay_ms / 1000.0).timeout

	spin_timer.stop()
	spin_timer.queue_free()


# ─── DRAW SPIN ────────────────────────────────────────────────────────

func _on_draw_spin_complete(grid: Array) -> void:
	_animating = true

	# Held columns: duplicate mid card to top/bottom instantly
	for col in 5:
		if _manager.held[col]:
			_set_card_texture(0, col, grid[0][col])
			_set_card_texture(2, col, grid[2][col])

	# Animate unheld columns
	await _animate_spin_draw(grid)
	_clear_shutters()
	_animating = false
	_manager.on_draw_spin_complete()


func _animate_spin_draw(grid: Array) -> void:
	var cfg: Dictionary = SPEED_CONFIGS[_speed_level]
	var base_ms: int = cfg["base_spin_ms"]
	var col_ms: int = cfg["col_stop_ms"]

	if _rush or base_ms == 0:
		for row in 3:
			for col in 5:
				_set_card_texture(row, col, grid[row][col])
		return

	var filler_count: int = int(ConfigManager.get_animation("spin_filler_cards_count", 15))
	var bounce_px: float = ConfigManager.get_animation("spin_reel_bounce_px", 5.0)
	var decel_ms: float = ConfigManager.get_animation("spin_reel_deceleration_ms", 800.0)
	var col_delay_ms: float = ConfigManager.get_animation("spin_reel_column_delay_ms", 300.0)
	var random_paths := _build_random_card_paths(filler_count * 3)
	var reel_overlays: Array[Control] = []

	# For each unheld column, create a reel strip covering all 3 rows
	for col in 5:
		if _manager.held[col]:
			reel_overlays.append(null)
			continue
		var top_cell: TextureRect = _card_rects[0][col]
		var bot_cell: TextureRect = _card_rects[2][col]
		var cell_w := top_cell.size.x
		var cell_h := top_cell.size.y
		var full_h := cell_h * 3  # 3 rows

		var clip := Control.new()
		clip.clip_contents = true
		clip.size = Vector2(cell_w, full_h)
		clip.global_position = top_cell.global_position
		clip.z_index = 5
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)

		var strip := VBoxContainer.new()
		strip.add_theme_constant_override("separation", 0)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Filler cards (groups of 3 for each "row set")
		for i in filler_count:
			var tex := TextureRect.new()
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(cell_w, cell_h)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var path: String = random_paths[(col * 5 + i) % random_paths.size()]
			if ResourceLoader.exists(path):
				tex.texture = load(path)
			strip.add_child(tex)
		# Target 3 cards (top, mid, bot) at end of strip
		for row in 3:
			var target_tex := TextureRect.new()
			target_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			target_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			target_tex.custom_minimum_size = Vector2(cell_w, cell_h)
			target_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tp := _get_card_path(grid[row][col])
			if ResourceLoader.exists(tp):
				target_tex.texture = load(tp)
			strip.add_child(target_tex)
		clip.add_child(strip)
		reel_overlays.append(clip)
		# Hide real cards
		for row in 3:
			_card_rects[row][col].modulate.a = 0.0

	var cell_h: float = (_card_rects[0][0] as TextureRect).size.y
	var total_strip_h: float = cell_h * (filler_count + 3)
	var target_y: float = -(total_strip_h - cell_h * 3)

	# Spin phase
	var spin_timer := Timer.new()
	spin_timer.wait_time = SPEED_CONFIGS[_speed_level]["spin_ms"] / 1000.0
	spin_timer.autostart = true
	add_child(spin_timer)
	var frame_offsets := [0, 0, 0, 0, 0]
	var col_stopped := [false, false, false, false, false]
	for col in 5:
		if _manager.held[col]:
			col_stopped[col] = true
	spin_timer.timeout.connect(func() -> void:
		for col in 5:
			if col_stopped[col] or reel_overlays[col] == null:
				continue
			frame_offsets[col] += int(cell_h * 0.6)
			var strip: VBoxContainer = reel_overlays[col].get_child(0)
			strip.position.y = -(frame_offsets[col] % int(total_strip_h))
	)

	await get_tree().create_timer(base_ms / 1000.0).timeout

	# Stop columns left to right
	for col in 5:
		if _manager.held[col] or reel_overlays[col] == null:
			continue
		if _rush:
			col_stopped[col] = true
			reel_overlays[col].queue_free()
			for row in 3:
				_card_rects[row][col].modulate.a = 1.0
				_set_card_texture(row, col, grid[row][col])
			continue
		col_stopped[col] = true
		var strip: VBoxContainer = reel_overlays[col].get_child(0)
		var tw := create_tween()
		tw.tween_property(strip, "position:y", target_y - bounce_px, decel_ms / 1000.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(strip, "position:y", target_y, 0.1).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		for row in 3:
			_card_rects[row][col].modulate.a = 1.0
			_set_card_texture(row, col, grid[row][col])
		reel_overlays[col].queue_free()
		SoundManager.play("spin_stop")
		VibrationManager.vibrate("spin_stop")
		if col < 4:
			await get_tree().create_timer(col_delay_ms / 1000.0).timeout

	spin_timer.stop()
	spin_timer.queue_free()


func _build_random_card_paths(count: int) -> Array[String]:
	var paths: Array[String] = []
	var suits_std := ["h", "d", "s"]
	var num_ranks := ["2","3","4","5","6","7","8","9","10"]
	var face_ranks := ["j","q","k","a"]
	for _i in count:
		if randi() % 2 == 0:
			var r: String = num_ranks[randi() % num_ranks.size()]
			var all_s := suits_std + [SUIT_CODES_CLUBS_CYR]
			var s: String = all_s[randi() % all_s.size()]
			paths.append(SPIN_CARD_DIR + "card_vp_%s%s.svg" % [r, s])
		else:
			var r: String = face_ranks[randi() % face_ranks.size()]
			var all_s := suits_std + ["c"]
			var s: String = all_s[randi() % all_s.size()]
			paths.append(SPIN_CARD_DIR + "card_vp_%s%s.svg" % [r, s])
	return paths


# ─── WIN EVALUATION & DISPLAY ─────────────────────────────────────────

func _on_lines_evaluated(results: Array, total_payout: int) -> void:
	_last_total_payout = total_payout
	_winning_lines.clear()
	for r in results:
		if r["payout"] > 0:
			_winning_lines.append(r)

	if total_payout > 0:
		VibrationManager.vibrate("win_small")
		var display_total: int = total_payout / maxi(SaveManager.denomination, 1)
		_game_pays_label.text = Translations.tr_key("spin.game_pays_fmt", [str(display_total)])
		_game_pays_label.visible = true
		_set_win_active(total_payout)
		_status_label.text = Translations.tr_key("spin.game_over")
		_highlight_all_winning()
		if _winning_lines.size() > 0:
			_start_win_cycle()
	else:
		_last_total_payout = 0
		_set_win_dimmed()
		_status_label.text = Translations.tr_key("spin.game_over")
		_game_pays_label.visible = false


func _highlight_all_winning() -> void:
	for row in 3:
		for col in 5:
			_card_rects[row][col].modulate = Color(0.4, 0.4, 0.5)
	var bright_positions := {}
	for w in _winning_lines:
		var line_idx: int = w["line_idx"]
		for col in 5:
			var row: int = SpinPokerManager.LINES[line_idx][col]
			bright_positions[Vector2i(row, col)] = true
	for pos in bright_positions:
		_card_rects[pos.x][pos.y].modulate = Color.WHITE


func _start_win_cycle() -> void:
	_current_win_cycle = 0
	_show_winning_line(_current_win_cycle)
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_interval(2.0)
	_blink_tween.tween_callback(_next_win_line)


func _next_win_line() -> void:
	if _winning_lines.size() == 0:
		return
	_current_win_cycle = (_current_win_cycle + 1) % _winning_lines.size()
	_show_winning_line(_current_win_cycle)


func _show_winning_line(idx: int) -> void:
	if idx < 0 or idx >= _winning_lines.size():
		return
	var w: Dictionary = _winning_lines[idx]
	var payout_coins: int = w["payout"] / maxi(SaveManager.denomination, 1)
	_status_label.text = "%s PAYS %d" % [w["hand_name"], payout_coins]
	_line_draw_node.queue_redraw()
	# Show badge on center card (col 2) of this line
	_show_win_badge(w)


func _stop_win_cycle() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	_current_win_cycle = -1
	_winning_lines.clear()
	_hide_win_badge()
	_line_draw_node.queue_redraw()


func _clear_line_display() -> void:
	_winning_lines.clear()
	_current_win_cycle = -1
	_hide_win_badge()
	_line_draw_node.queue_redraw()


# ─── WIN BADGE (on center reel card of winning line) ──────────────────

func _show_win_badge(w: Dictionary) -> void:
	_hide_win_badge()
	var line_idx: int = w["line_idx"]
	var color: Color = SpinPokerManager.LINE_COLORS[line_idx]
	var payout_coins: int = w["payout"] / maxi(SaveManager.denomination, 1)

	_win_badge = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.12, 0.92)
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_win_badge.add_theme_stylebox_override("panel", style)
	_win_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_badge.z_index = 10

	var label := Label.new()
	label.text = "%s\n%d" % [w["hand_name"], payout_coins]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	_win_badge.add_child(label)

	add_child(_win_badge)
	# Position on center reel (col 2) at the row this line passes through
	var center_row: int = SpinPokerManager.LINES[line_idx][2]
	var card_rect: TextureRect = _card_rects[center_row][2]
	_position_badge_on_card.call_deferred(card_rect)


func _position_badge_on_card(card_rect: TextureRect) -> void:
	await get_tree().process_frame
	if not is_instance_valid(_win_badge):
		return
	var rect := card_rect.get_global_rect()
	var badge_size := _win_badge.get_combined_minimum_size()
	_win_badge.global_position = Vector2(
		rect.get_center().x - badge_size.x / 2,
		rect.get_center().y - badge_size.y / 2
	)


func _hide_win_badge() -> void:
	if _win_badge and is_instance_valid(_win_badge):
		_win_badge.queue_free()
	_win_badge = null


# ─── LINE DRAWING ─────────────────────────────────────────────────────

func _draw_lines() -> void:
	if _winning_lines.size() == 0 or _current_win_cycle < 0:
		return
	var w: Dictionary = _winning_lines[_current_win_cycle]
	var line_idx: int = w["line_idx"]
	var color: Color = SpinPokerManager.LINE_COLORS[line_idx]
	var points: PackedVector2Array = PackedVector2Array()
	for col in 5:
		var row: int = SpinPokerManager.LINES[line_idx][col]
		var card_rect: TextureRect = _card_rects[row][col]
		var global_center := card_rect.global_position + card_rect.size / 2
		var local_pos := _line_draw_node.get_global_transform().affine_inverse() * global_center
		points.append(local_pos)
	if points.size() >= 2:
		_line_draw_node.draw_polyline(points, color, 3.0, true)


# ─── IDLE BLINK & BALANCE FLASH ──────────────────────────────────────

func _start_idle_blink_timer() -> void:
	_stop_idle_blink()
	_idle_timer = get_tree().create_timer(5.0)
	_idle_timer.timeout.connect(_begin_deal_blink)

func _begin_deal_blink() -> void:
	_idle_timer = null
	if _idle_blink_tween:
		_idle_blink_tween.kill()
	_idle_blink_tween = create_tween().set_loops()
	_idle_blink_tween.tween_property(_deal_draw_btn, "modulate:a", 0.4, 0.3)
	_idle_blink_tween.tween_property(_deal_draw_btn, "modulate:a", 1.0, 0.3)

func _stop_idle_blink() -> void:
	_idle_timer = null
	if _idle_blink_tween:
		_idle_blink_tween.kill()
		_idle_blink_tween = null
	_deal_draw_btn.modulate.a = 1.0

func _flash_balance_red() -> void:
	var tw := create_tween()
	tw.tween_property(_balance_cd["box"], "modulate", Color(1, 0.3, 0.3), 0.15)
	tw.tween_property(_balance_cd["box"], "modulate", Color.WHITE, 0.15)
	tw.tween_property(_balance_cd["box"], "modulate", Color(1, 0.3, 0.3), 0.15)
	tw.tween_property(_balance_cd["box"], "modulate", Color.WHITE, 0.15)


# ─── BUTTON HANDLERS ─────────────────────────────────────────────────

func _on_deal_draw_pressed() -> void:
	VibrationManager.vibrate("button_press")
	if _animating:
		_rush = true
		return
	if _manager.state == SpinPokerManager.State.SPINNING or _manager.state == SpinPokerManager.State.DRAW_SPINNING:
		_rush = true
		return
	# Check credits before deal
	if _manager.state == SpinPokerManager.State.IDLE or _manager.state == SpinPokerManager.State.WIN_DISPLAY:
		if _manager.get_total_bet() > SaveManager.credits:
			_flash_balance_red()
			_show_bet_picker()
			return
	_manager.deal_or_draw()


func _on_card_clicked(event: InputEvent, col: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == SpinPokerManager.State.HOLDING:
			_manager.toggle_hold(col)
			_show_held(col, _manager.held[col])
			VibrationManager.vibrate("card_hold")
			if _manager.held[col]:
				_set_card_texture(0, col, _manager.middle_row[col])
				_set_card_texture(2, col, _manager.middle_row[col])
			else:
				_set_card_back(0, col)
				_set_card_back(2, col)


func _on_bet_one_pressed() -> void:
	_manager.bet_one()
	_update_bet_display(_manager.bet)


func _on_bet_max_pressed() -> void:
	_manager.bet_max()
	_update_bet_display(_manager.bet)
	_manager.deal()


func _on_bet_amount_pressed() -> void:
	if _manager.state != SpinPokerManager.State.IDLE and _manager.state != SpinPokerManager.State.WIN_DISPLAY:
		return
	_show_bet_picker()


func _on_speed_pressed() -> void:
	_speed_level = (_speed_level + 1) % SPEED_CONFIGS.size()
	SaveManager.speed_level = _speed_level
	SaveManager.save_game()
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_btn.text = "SPEED %s" % SPEED_LABELS[_speed_level]


func _on_bet_changed(new_bet: int) -> void:
	_update_bet_display(new_bet)
	if _balance_show_depth:
		_update_balance(SaveManager.credits)


func _on_credits_changed(new_credits: int) -> void:
	_update_balance(new_credits)


# ─── UI UPDATES ───────────────────────────────────────────────────────

func _recommend_denomination() -> int:
	var best: int = BET_AMOUNTS[0]
	for amount in BET_AMOUNTS:
		var worst_cost: int = SpinPokerManager.NUM_LINES * SpinPokerManager.MAX_BET * amount
		if worst_cost <= SaveManager.credits:
			best = amount
		else:
			break
	return best


func _calculate_credits() -> int:
	var denom: int = maxi(_current_denomination, 1)
	return SaveManager.credits / denom


func _update_balance(credits: int) -> void:
	if _balance_show_depth:
		var cr := _calculate_credits()
		_balance_label.text = Translations.tr_key("game.games")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(cr), 0, Color(-1, 0, 0), false)
	else:
		_balance_label.text = Translations.tr_key("game.balance")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(credits), 0, Color(-1, 0, 0), true)


func _format_win(amount: int) -> String:
	if _balance_show_depth:
		return str(amount / maxi(_current_denomination, 1))
	return SaveManager.format_money(amount)


func _set_win_active(amount: int) -> void:
	_last_total_payout = amount
	_win_label.text = Translations.tr_key("game.win_label")
	_win_label.add_theme_color_override("font_color", Color.WHITE)
	_win_cd["box"].visible = true
	_animate_win_increment(0, amount)


func _set_win_dimmed() -> void:
	_stop_win_increment()
	_win_label.text = Translations.tr_key("game.win_label")
	_win_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
	var show_chip: bool = not _balance_show_depth
	SaveManager.set_currency_value(_win_cd, _format_win(_last_total_payout), 16, Color(0.7, 0.7, 0.4), show_chip)
	_win_cd["box"].visible = true


func _animate_win_increment(from: int, to: int) -> void:
	_stop_win_increment()
	var show_chip: bool = not _balance_show_depth
	SaveManager.set_currency_value(_win_cd, _format_win(from), 16, COL_YELLOW, show_chip)
	if from == to:
		return
	_win_increment_tween = create_tween()
	_win_increment_tween.tween_method(func(val: int) -> void:
		SaveManager.set_currency_value(_win_cd, _format_win(val), 0, Color(-1, 0, 0), not _balance_show_depth)
	, from, to, 1.4).set_ease(Tween.EASE_OUT)


func _stop_win_increment() -> void:
	if _win_increment_tween:
		_win_increment_tween.kill()
		_win_increment_tween = null


func _on_credits_toggle(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_toggle_credits_mode()


func _toggle_credits_mode() -> void:
	if not SaveManager.depth_hint_shown:
		_show_depth_tooltip()
		SaveManager.depth_hint_shown = true
		SaveManager.save_game()
	_balance_show_depth = not _balance_show_depth
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)
	# Refresh WIN display (always)
	if _manager.state == SpinPokerManager.State.WIN_DISPLAY:
		_set_win_active(_last_total_payout)
	else:
		_set_win_dimmed()


func _show_depth_tooltip() -> void:
	if _depth_tooltip:
		_depth_tooltip.queue_free()
	_depth_tooltip = Control.new()
	_depth_tooltip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_depth_tooltip.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_depth_tooltip)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_depth_tooltip.queue_free()
			_depth_tooltip = null
	)
	_depth_tooltip.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("062015")
	ps.set_border_width_all(3)
	ps.border_color = COL_YELLOW
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 28
	ps.content_margin_right = 28
	ps.content_margin_top = 20
	ps.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_depth_tooltip.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var bold := SystemFont.new()
	bold.font_weight = 700
	var title := Label.new()
	title.text = Translations.tr_key("game_depth.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_YELLOW)
	title.add_theme_font_override("font", bold)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = Translations.tr_key("game_depth.description_multi")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)

	var ok_btn := Button.new()
	ok_btn.text = Translations.tr_key("common.got_it")
	var tex_y := load("res://assets/textures/btn_rect_yellow.svg")
	_style_btn(ok_btn, tex_y, COL_BTN_TEXT, 18, 140, 44)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(func() -> void:
		if _depth_tooltip:
			_depth_tooltip.queue_free()
			_depth_tooltip = null
	)
	vbox.add_child(ok_btn)


func _update_bet_display(bet: int) -> void:
	var total: int = SpinPokerManager.NUM_LINES * bet * _current_denomination
	if _balance_show_depth:
		var credits_total: int = SpinPokerManager.NUM_LINES * bet
		SaveManager.set_currency_value(_bet_display_cd, str(credits_total), 0, Color(-1, 0, 0), false)
	else:
		SaveManager.set_currency_value(_bet_display_cd, SaveManager.format_auto(total, 80, 16))


var _bet_btn_cd: Dictionary

func _update_bet_amount_btn() -> void:
	_bet_amount_btn.text = ""
	_bet_amount_btn.icon = null
	if _bet_btn_cd.is_empty():
		_bet_btn_cd = SaveManager.create_currency_display(16, Color.WHITE)
		_bet_btn_cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bet_btn_cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		_bet_amount_btn.add_child(_bet_btn_cd["box"])
	SaveManager.set_currency_value(_bet_btn_cd, SaveManager.format_auto(_current_denomination, 66, 16))


# ─── INPUT ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == SpinPokerManager.State.SPINNING or _manager.state == SpinPokerManager.State.DRAW_SPINNING:
			_rush = true


# ─── BET PICKER ───────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	TopBarBuilder.show_exit_confirm(self, func() -> void: back_to_lobby.emit())


# ─── BET PICKER ───────────────────────────────────────────────────────

var _bet_picker_overlay: Control = null

func _show_bet_picker() -> void:
	if _bet_picker_overlay:
		_bet_picker_overlay.queue_free()
	_bet_picker_overlay = Control.new()
	_bet_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bet_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_bet_picker_overlay.z_index = 50
	add_child(_bet_picker_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
	)
	_bet_picker_overlay.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("000086")
	ps.set_border_width_all(3)
	ps.border_color = Color.WHITE
	ps.set_corner_radius_all(16)
	ps.content_margin_left = 32
	ps.content_margin_right = 32
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bet_picker_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("bet_select.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	var tex_y := load("res://assets/textures/btn_rect_yellow.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_yellow.svg") else null
	for amount in BET_AMOUNTS:
		var btn := Button.new()
		btn.text = ""
		_style_btn(btn, tex_y, COL_BTN_TEXT, 18, 120, 44)
		var cd := SaveManager.create_currency_display(16, COL_BTN_TEXT)
		cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		SaveManager.set_currency_value(cd, SaveManager.format_auto(amount, 96, 16))
		cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(cd["box"])
		btn.pressed.connect(func() -> void:
			_current_denomination = amount
			SaveManager.denomination = amount
			_update_bet_amount_btn()
			_update_bet_display(_manager.bet)
			if _balance_show_depth:
				_update_balance(SaveManager.credits)
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
		)
		grid.add_child(btn)


# ─── PAYTABLE POPUP ──────────────────────────────────────────────────

var _paytable_overlay: Control = null
var _paytable_grid_rects: Array = [[], [], []]
var _paytable_line_draw: Control = null
var _paytable_line_btns: Array[Button] = []
var _paytable_badge: PanelContainer = null
var _paytable_prev_btn_idx: int = -1
var _paytable_left_ribbons: Array = []  # [{idx, node}]
var _paytable_right_ribbons: Array = []
var _paytable_cycle_timer: Timer = null
var _paytable_cycle_idx: int = 0

func _show_paytable() -> void:
	if _paytable_overlay:
		_paytable_overlay.queue_free()
	_stop_paytable_cycle()
	_paytable_overlay = Control.new()
	_paytable_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paytable_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_paytable_overlay.z_index = 50
	add_child(_paytable_overlay)

	# Dim overlay
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_paytable_overlay()
	)
	_paytable_overlay.add_child(dim)

	var bold := SystemFont.new()
	bold.font_weight = 700

	# Title "20 LINES" top center
	var title := Label.new()
	title.text = "20 LINES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_YELLOW)
	title.add_theme_font_override("font", bold)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 12
	title.offset_bottom = 44
	title.offset_left = -100
	title.offset_right = 100
	_paytable_overlay.add_child(title)

	# Mini grid copy with card backs (centered)
	var mini_panel := PanelContainer.new()
	var mp_style := StyleBoxFlat.new()
	mp_style.bg_color = Color(0.75, 0.75, 0.8)
	mp_style.set_border_width_all(2)
	mp_style.border_color = Color(0.6, 0.6, 0.7)
	mp_style.set_corner_radius_all(4)
	mp_style.content_margin_left = 2
	mp_style.content_margin_right = 2
	mp_style.content_margin_top = 2
	mp_style.content_margin_bottom = 2
	mini_panel.add_theme_stylebox_override("panel", mp_style)
	mini_panel.set_anchors_preset(Control.PRESET_CENTER)
	mini_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mini_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_paytable_overlay.add_child(mini_panel)

	var mini_grid := GridContainer.new()
	mini_grid.columns = 5
	mini_grid.add_theme_constant_override("h_separation", 0)
	mini_grid.add_theme_constant_override("v_separation", 0)
	mini_panel.add_child(mini_grid)

	var back_path := SPIN_CARD_DIR + "card_back_spin.svg"
	var back_tex: Texture2D = load(back_path) if ResourceLoader.exists(back_path) else null
	var cell_sz := 120.0
	_paytable_grid_rects = [[], [], []]
	for row in 3:
		for col in 5:
			var tex := TextureRect.new()
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(cell_sz, cell_sz)
			tex.texture = back_tex
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mini_grid.add_child(tex)
			_paytable_grid_rects[row].append(tex)

	# Line draw node on top of mini grid
	_paytable_line_draw = Control.new()
	_paytable_line_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paytable_line_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paytable_line_draw.draw.connect(_draw_paytable_line)
	mini_panel.add_child(_paytable_line_draw)

	# Line ribbon indicators on left and right of mini grid
	# Distribute by start row (col 0 for left, col 4 for right)
	_paytable_left_ribbons = []
	_paytable_right_ribbons = []
	var left_rows := [[], [], []]  # T, M, B
	var right_rows := [[], [], []]
	for li in 20:
		var start_row_l: int = SpinPokerManager.LINES[li][0]
		var start_row_r: int = SpinPokerManager.LINES[li][4]
		if li < 10:
			left_rows[start_row_l].append(li)
		else:
			right_rows[start_row_r].append(li)
	# Build left column — all 10 stacked vertically, grouped by row with spacers
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 2)
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.custom_minimum_size.x = 40
	var grid_parent := mini_panel.get_parent()
	var grid_hbox := HBoxContainer.new()
	grid_hbox.add_theme_constant_override("separation", 4)
	grid_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_hbox.set_anchors_preset(Control.PRESET_CENTER)
	grid_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	grid_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	grid_parent.remove_child(mini_panel)
	grid_parent.add_child(grid_hbox)
	grid_hbox.add_child(left_vbox)
	grid_hbox.add_child(mini_panel)
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.custom_minimum_size.x = 40
	grid_hbox.add_child(right_vbox)
	# Left: 3 groups aligned to each reel row
	for row_idx in 3:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 1)
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		group.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left_vbox.add_child(group)
		for li in left_rows[row_idx]:
			var r := _make_line_ribbon(li, false)
			r.custom_minimum_size = Vector2(36, 16)
			group.add_child(r)
			_paytable_left_ribbons.append({"idx": li, "node": r})
	# Right: 3 groups aligned to each reel row
	for row_idx in 3:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 1)
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		group.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vbox.add_child(group)
		for li in right_rows[row_idx]:
			var r := _make_line_ribbon(li, true)
			r.custom_minimum_size = Vector2(36, 16)
			group.add_child(r)
			_paytable_right_ribbons.append({"idx": li, "node": r})

	# 20 line buttons horizontal at bottom
	var btn_container := HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 4)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	btn_container.offset_bottom = -12
	btn_container.offset_top = -48
	btn_container.offset_left = 8
	btn_container.offset_right = -8
	_paytable_line_btns.clear()
	_paytable_overlay.add_child(btn_container)

	for li in 20:
		var line_btn := Button.new()
		line_btn.text = str(li + 1)
		line_btn.custom_minimum_size = Vector2(44, 32)
		line_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ls := StyleBoxFlat.new()
		ls.bg_color = SpinPokerManager.LINE_COLORS[li].darkened(0.3)
		ls.set_border_width_all(2)
		ls.border_color = SpinPokerManager.LINE_COLORS[li]
		ls.set_corner_radius_all(4)
		ls.content_margin_left = 2
		ls.content_margin_right = 2
		ls.content_margin_top = 1
		ls.content_margin_bottom = 1
		line_btn.add_theme_stylebox_override("normal", ls)
		var lh := ls.duplicate()
		lh.bg_color = SpinPokerManager.LINE_COLORS[li].darkened(0.1)
		line_btn.add_theme_stylebox_override("hover", lh)
		var lp := ls.duplicate()
		lp.bg_color = SpinPokerManager.LINE_COLORS[li]
		line_btn.add_theme_stylebox_override("pressed", lp)
		line_btn.add_theme_font_size_override("font_size", 12)
		line_btn.add_theme_color_override("font_color", Color.WHITE)
		line_btn.pivot_offset = Vector2(22, 16)
		var idx := li
		line_btn.pressed.connect(func() -> void:
			_paytable_cycle_idx = idx
			_highlight_line_in_overlay(idx)
		)
		_paytable_line_btns.append(line_btn)
		btn_container.add_child(line_btn)

	# X close button (top-right)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.5, 0.1, 0.1)
	cs.set_corner_radius_all(20)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(func() -> void:
		_close_paytable_overlay()
	)
	_paytable_overlay.add_child(close_btn)
	close_btn.position = Vector2(size.x - 60, 10)

	# Auto-cycle: start cycling through lines
	_paytable_cycle_idx = 0
	_highlight_line_in_overlay(0)
	_start_paytable_cycle()


func _close_paytable_overlay() -> void:
	_stop_paytable_cycle()
	if _paytable_overlay:
		_paytable_overlay.queue_free()
		_paytable_overlay = null
	_paytable_grid_rects = [[], [], []]
	_paytable_line_draw = null
	_paytable_line_btns.clear()
	_paytable_badge = null
	_paytable_prev_btn_idx = -1
	_paytable_left_ribbons.clear()
	_paytable_right_ribbons.clear()
	_clear_line_display()


func _start_paytable_cycle() -> void:
	_stop_paytable_cycle()
	_paytable_cycle_timer = Timer.new()
	_paytable_cycle_timer.wait_time = 2.0
	_paytable_cycle_timer.autostart = true
	_paytable_cycle_timer.timeout.connect(_advance_paytable_cycle)
	add_child(_paytable_cycle_timer)


func _advance_paytable_cycle() -> void:
	_paytable_cycle_idx = (_paytable_cycle_idx + 1) % 20
	_highlight_line_in_overlay(_paytable_cycle_idx)


func _stop_paytable_cycle() -> void:
	if _paytable_cycle_timer and is_instance_valid(_paytable_cycle_timer):
		_paytable_cycle_timer.stop()
		_paytable_cycle_timer.queue_free()
	_paytable_cycle_timer = null


func _highlight_line_in_overlay(line_idx: int) -> void:
	# Unhighlight previous button
	if _paytable_prev_btn_idx >= 0 and _paytable_prev_btn_idx < _paytable_line_btns.size():
		var prev_btn := _paytable_line_btns[_paytable_prev_btn_idx]
		var prev_style := prev_btn.get_theme_stylebox("normal") as StyleBoxFlat
		if prev_style:
			prev_style.bg_color = SpinPokerManager.LINE_COLORS[_paytable_prev_btn_idx].darkened(0.3)
		prev_btn.scale = Vector2.ONE
	# Highlight current button
	if line_idx >= 0 and line_idx < _paytable_line_btns.size():
		var btn := _paytable_line_btns[line_idx]
		var btn_style := btn.get_theme_stylebox("normal") as StyleBoxFlat
		if btn_style:
			btn_style.bg_color = SpinPokerManager.LINE_COLORS[line_idx].lightened(0.3)
		btn.scale = Vector2(1.25, 1.25)
	_paytable_prev_btn_idx = line_idx
	_paytable_cycle_idx = line_idx
	# Highlight/dim ribbons
	for r in _paytable_left_ribbons:
		if r["idx"] == line_idx:
			(r["node"] as Control).modulate = Color(1.5, 1.5, 1.5)
		else:
			(r["node"] as Control).modulate = Color(0.5, 0.5, 0.5)
	for r in _paytable_right_ribbons:
		if r["idx"] == line_idx:
			(r["node"] as Control).modulate = Color(1.5, 1.5, 1.5)
		else:
			(r["node"] as Control).modulate = Color(0.5, 0.5, 0.5)
	# Remove old badge
	if _paytable_badge and is_instance_valid(_paytable_badge):
		_paytable_badge.queue_free()
		_paytable_badge = null
	# Add badge on center cell (col 2) of the line
	if _paytable_line_draw and _paytable_grid_rects[0].size() >= 5:
		var center_row: int = SpinPokerManager.LINES[line_idx][2]
		var cell: TextureRect = _paytable_grid_rects[center_row][2]
		var min_hand: String = _variant.paytable.get_hand_order().back()
		var display_name: String = _variant.paytable.get_hand_display_name(min_hand)
		_paytable_badge = PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.02, 0.02, 0.12, 0.9)
		bs.set_border_width_all(2)
		bs.border_color = SpinPokerManager.LINE_COLORS[line_idx]
		bs.set_corner_radius_all(4)
		bs.content_margin_left = 6
		bs.content_margin_right = 6
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		_paytable_badge.add_theme_stylebox_override("panel", bs)
		_paytable_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.text = display_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		_paytable_badge.add_child(lbl)
		_paytable_overlay.add_child(_paytable_badge)
		# Position on center of cell
		_position_paytable_badge.call_deferred(cell)
	if _paytable_line_draw:
		_paytable_line_draw.queue_redraw()


func _position_paytable_badge(cell: TextureRect) -> void:
	await get_tree().process_frame
	if not _paytable_badge or not is_instance_valid(_paytable_badge):
		return
	var rect := cell.get_global_rect()
	var badge_sz := _paytable_badge.get_combined_minimum_size()
	_paytable_badge.global_position = Vector2(
		rect.get_center().x - badge_sz.x / 2,
		rect.get_center().y - badge_sz.y / 2
	)


func _draw_paytable_line() -> void:
	if _paytable_cycle_idx < 0 or _paytable_cycle_idx >= 20:
		return
	if _paytable_grid_rects[0].size() < 5:
		return
	var line_idx: int = _paytable_cycle_idx
	var color: Color = SpinPokerManager.LINE_COLORS[line_idx]
	var points: PackedVector2Array = PackedVector2Array()
	for col in 5:
		var row: int = SpinPokerManager.LINES[line_idx][col]
		var cell: TextureRect = _paytable_grid_rects[row][col]
		var global_center := cell.global_position + cell.size / 2
		var local_pos := _paytable_line_draw.get_global_transform().affine_inverse() * global_center
		points.append(local_pos)
	if points.size() >= 2:
		_paytable_line_draw.draw_polyline(points, color, 4.0, true)
