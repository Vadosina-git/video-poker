extends Control

## Spin Poker UI: 3×5 card grid, 20 fixed lines, slot-style spin animation.

signal back_to_lobby

const COL_YELLOW := Color("FFEC00")
const COL_BTN_TEXT := Color("3F2A00")
const BG_COLOR := Color(0.15, 0.0, 0.35)
const GRID_BG := Color(0.25, 0.15, 0.45, 0.6)

const BET_AMOUNTS := [1, 5, 10, 20, 50, 100, 500, 1000, 2000, 5000, 10000, 50000]

var _variant: BaseVariant
var _manager: SpinPokerManager
var _current_denomination: int = 1
var _animating: bool = false
var _rush: bool = false

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

# Line indicators (left/right side labels)
var _left_line_labels: Array[Label] = []
var _right_line_labels: Array[Label] = []

# Win line drawing + badge
var _line_draw_node: Control
var _winning_lines: Array = []
var _current_win_cycle: int = -1
var _blink_tween: Tween
var _win_badge: PanelContainer = null

# Speed
var _speed_level: int = 1
const SPEED_LABELS := ["1x", "2x", "3x", "MAX"]
const SPEED_CONFIGS := [
	{"spin_ms": 60, "base_spin_ms": 700, "col_stop_ms": 180},
	{"spin_ms": 45, "base_spin_ms": 450, "col_stop_ms": 140},
	{"spin_ms": 30, "base_spin_ms": 250, "col_stop_ms": 90},
	{"spin_ms": 20, "base_spin_ms": 0,   "col_stop_ms": 0},
]

# Card path helpers
const SUIT_CODES := {
	CardData.Suit.HEARTS: "h", CardData.Suit.DIAMONDS: "d",
	CardData.Suit.CLUBS: "c", CardData.Suit.SPADES: "s",
}
const RANK_CODES := {
	CardData.Rank.TWO: "2", CardData.Rank.THREE: "3", CardData.Rank.FOUR: "4",
	CardData.Rank.FIVE: "5", CardData.Rank.SIX: "6", CardData.Rank.SEVEN: "7",
	CardData.Rank.EIGHT: "8", CardData.Rank.NINE: "9", CardData.Rank.TEN: "10",
	CardData.Rank.JACK: "j", CardData.Rank.QUEEN: "q", CardData.Rank.KING: "k",
	CardData.Rank.ACE: "a",
}


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
	_speed_level = SaveManager.speed_level
	_current_denomination = SaveManager.denomination
	_build_ui()
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

	# ── Top: title
	_game_title = Label.new()
	_game_title.text = "SPIN POKER — %s" % _variant.paytable.name.to_upper()
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 18)
	_game_title.add_theme_color_override("font_color", COL_YELLOW)
	_game_title.add_theme_font_override("font", bold)
	root_vbox.add_child(_game_title)

	# ── Middle: grid area with line labels — centered, fixed proportions
	var grid_area := HBoxContainer.new()
	grid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_area.add_theme_constant_override("separation", 0)
	grid_area.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(grid_area)

	# Left line labels
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 0)
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.custom_minimum_size.x = 24
	grid_area.add_child(left_col)
	for i in 10:
		var lbl := _make_line_label(i)
		left_col.add_child(lbl)
		_left_line_labels.append(lbl)

	# Grid panel — silver border frame, no expand, centered
	_grid_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.75, 0.75, 0.8)  # Silver/light gray frame
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.85, 0.9)
	panel_style.set_corner_radius_all(2)
	panel_style.content_margin_left = 3
	panel_style.content_margin_right = 3
	panel_style.content_margin_top = 3
	panel_style.content_margin_bottom = 3
	_grid_panel.add_theme_stylebox_override("panel", panel_style)
	_grid_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_area.add_child(_grid_panel)

	_grid_container = GridContainer.new()
	_grid_container.columns = 5
	_grid_container.add_theme_constant_override("h_separation", 2)
	_grid_container.add_theme_constant_override("v_separation", 0)
	_grid_panel.add_child(_grid_container)

	# Build 15 card slots (3 rows × 5 cols)
	# Target: grid ~730×390 → each cell ~144×130, cards keep aspect inside
	var back_tex: Texture2D = null
	var card_back_path := "res://assets/cards/card_back.png"
	if ResourceLoader.exists(card_back_path):
		back_tex = load(card_back_path)

	for row in 3:
		_card_rects[row] = []
		for col in 5:
			var tex_rect := TextureRect.new()
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(140, 126)
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

	# Right line labels
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 0)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.custom_minimum_size.x = 24
	grid_area.add_child(right_col)
	for i in range(10, 20):
		var lbl := _make_line_label(i)
		right_col.add_child(lbl)
		_right_line_labels.append(lbl)

	# ── Status + game pays: inline labels (no separate bar, prevents layout jumps)
	_status_label = Label.new()
	_status_label.text = "PLACE YOUR BET"
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
	info_row.add_theme_constant_override("separation", 12)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(info_row)

	_win_label = Label.new()
	_win_label.text = "WIN"
	_win_label.add_theme_font_size_override("font_size", 14)
	_win_label.add_theme_color_override("font_color", Color.WHITE)
	info_row.add_child(_win_label)
	_win_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	info_row.add_child(_win_cd["box"])
	SaveManager.set_currency_value(_win_cd, "0")

	_bet_display_label = Label.new()
	_bet_display_label.text = "BET"
	_bet_display_label.add_theme_font_size_override("font_size", 14)
	_bet_display_label.add_theme_color_override("font_color", Color.WHITE)
	info_row.add_child(_bet_display_label)
	_bet_display_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	info_row.add_child(_bet_display_cd["box"])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(spacer)

	_balance_label = Label.new()
	_balance_label.text = "CREDIT"
	_balance_label.add_theme_font_size_override("font_size", 14)
	_balance_label.add_theme_color_override("font_color", Color.WHITE)
	info_row.add_child(_balance_label)
	_balance_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	info_row.add_child(_balance_cd["box"])

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(btn_row)

	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_yellow.svg") else null
	var tex_blue := load("res://assets/textures/btn_rect_blue.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_blue.svg") else null
	var tex_green := load("res://assets/textures/btn_rect_green.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_green.svg") else null

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_style_btn(_back_btn, tex_blue, Color.WHITE, 13, 70, 36)
	_back_btn.pressed.connect(func() -> void: back_to_lobby.emit())
	btn_row.add_child(_back_btn)

	_see_pays_btn = Button.new()
	_see_pays_btn.text = "SEE PAYS"
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

	_bet_btn = Button.new()
	_bet_btn.text = "BET"
	_style_btn(_bet_btn, tex_yellow, COL_BTN_TEXT, 13, 70, 36)
	_bet_btn.pressed.connect(_on_bet_one_pressed)
	btn_row.add_child(_bet_btn)

	_bet_max_btn = Button.new()
	_bet_max_btn.text = "BET MAX"
	_style_btn(_bet_max_btn, tex_yellow, COL_BTN_TEXT, 13, 90, 36)
	_bet_max_btn.pressed.connect(_on_bet_max_pressed)
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


func _make_line_label(line_idx: int) -> Label:
	var lbl := Label.new()
	lbl.text = "%d" % (line_idx + 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", SpinPokerManager.LINE_COLORS[line_idx])
	lbl.custom_minimum_size = Vector2(24, 0)
	return lbl


# ─── CARD RENDERING ────────────────────────────────────────────────────

func _get_card_path(card: CardData) -> String:
	if card == null:
		return "res://assets/cards/card_back.png"
	if card.is_joker():
		return "res://assets/cards/card_vp_joker_red.png"
	if _variant.is_wild_card(card) and card.rank == CardData.Rank.TWO:
		var s: String = SUIT_CODES.get(card.suit, "")
		return "res://assets/cards/card_vp_wild%s.png" % s
	var r: String = RANK_CODES.get(card.rank, "")
	var s: String = SUIT_CODES.get(card.suit, "")
	return "res://assets/cards/card_vp_%s%s.png" % [r, s]


func _set_card_texture(row: int, col: int, card: CardData) -> void:
	var path := _get_card_path(card)
	if ResourceLoader.exists(path):
		_card_rects[row][col].texture = load(path)
	_card_rects[row][col].modulate = Color.WHITE


func _set_card_back(row: int, col: int) -> void:
	var path := "res://assets/cards/card_back.png"
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
			_status_label.text = "PLACE YOUR BET"
			_game_pays_label.visible = false

		SpinPokerManager.State.SPINNING:
			_deal_draw_btn.text = "STOP\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_bet_amount_btn.disabled = true

		SpinPokerManager.State.HOLDING:
			_deal_draw_btn.text = "DRAW\nSPIN"
			_deal_draw_btn.disabled = false
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_status_label.text = "SELECT REELS TO HOLD THEN PRESS DRAW SPIN"

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


# ─── DEAL SPIN ────────────────────────────────────────────────────────

func _on_deal_spin_complete(mid_row: Array[CardData]) -> void:
	_animating = true
	_rush = false
	_stop_win_cycle()
	_clear_line_display()
	_hide_win_badge()
	_game_pays_label.visible = false
	SaveManager.set_currency_value(_win_cd, "0")
	_reset_all_modulate()

	# Clear held
	for col in 5:
		_show_held(col, false)

	# Top/bottom rows: show card backs
	for col in 5:
		_set_card_back(0, col)
		_set_card_back(2, col)

	# Animate middle row
	await _animate_spin_deal(mid_row)
	_build_held_indicators()
	_animating = false
	_manager.on_deal_spin_complete()


func _animate_spin_deal(mid_row: Array[CardData]) -> void:
	var cfg: Dictionary = SPEED_CONFIGS[_speed_level]
	var base_ms: int = cfg["base_spin_ms"]
	var col_ms: int = cfg["col_stop_ms"]

	if _rush or base_ms == 0:
		for col in 5:
			_set_card_texture(1, col, mid_row[col])
		return

	var spin_active := [true, true, true, true, true]
	var random_cards := _build_random_card_paths(40)

	# Start rapid texture cycling on all 5 columns
	var spin_timer := Timer.new()
	spin_timer.wait_time = cfg["spin_ms"] / 1000.0
	spin_timer.autostart = true
	add_child(spin_timer)
	var frame_idx := [0]
	spin_timer.timeout.connect(func() -> void:
		for col in 5:
			if spin_active[col]:
				var idx: int = (frame_idx[0] + col * 5) % random_cards.size()
				var path: String = random_cards[idx]
				if ResourceLoader.exists(path):
					_card_rects[1][col].texture = load(path)
		frame_idx[0] += 1
	)

	# Base spin: all columns spin together
	await get_tree().create_timer(base_ms / 1000.0).timeout

	# Sequential column stops, left to right
	for col in 5:
		if _rush:
			spin_active[col] = false
			_set_card_texture(1, col, mid_row[col])
			continue
		spin_active[col] = false
		_set_card_texture(1, col, mid_row[col])
		SoundManager.play("deal")
		if col < 4:
			await get_tree().create_timer(col_ms / 1000.0).timeout

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

	var spin_active := [false, false, false, false, false]
	for col in 5:
		if not _manager.held[col]:
			spin_active[col] = true

	var random_cards := _build_random_card_paths(40)
	var spin_timer := Timer.new()
	spin_timer.wait_time = cfg["spin_ms"] / 1000.0
	spin_timer.autostart = true
	add_child(spin_timer)
	var frame_idx := [0]
	spin_timer.timeout.connect(func() -> void:
		for col in 5:
			if spin_active[col]:
				for row in 3:
					var idx: int = (frame_idx[0] + col * 5 + row * 11) % random_cards.size()
					var path: String = random_cards[idx]
					if ResourceLoader.exists(path):
						_card_rects[row][col].texture = load(path)
		frame_idx[0] += 1
	)

	# Base spin: all unheld columns spin together
	await get_tree().create_timer(base_ms / 1000.0).timeout

	# Sequential column stops, left to right
	for col in 5:
		if not spin_active[col]:
			continue
		if _rush:
			spin_active[col] = false
			for row in 3:
				_set_card_texture(row, col, grid[row][col])
			continue
		spin_active[col] = false
		for row in 3:
			_set_card_texture(row, col, grid[row][col])
		SoundManager.play("deal")
		if col < 4:
			await get_tree().create_timer(col_ms / 1000.0).timeout

	spin_timer.stop()
	spin_timer.queue_free()


func _build_random_card_paths(count: int) -> Array[String]:
	var paths: Array[String] = []
	var suits := ["h", "d", "c", "s"]
	var ranks := ["2","3","4","5","6","7","8","9","10","j","q","k","a"]
	for _i in count:
		var r: String = ranks[randi() % ranks.size()]
		var s: String = suits[randi() % suits.size()]
		paths.append("res://assets/cards/card_vp_%s%s.png" % [r, s])
	return paths


# ─── WIN EVALUATION & DISPLAY ─────────────────────────────────────────

func _on_lines_evaluated(results: Array, total_payout: int) -> void:
	_winning_lines.clear()
	for r in results:
		if r["payout"] > 0:
			_winning_lines.append(r)

	if total_payout > 0:
		var display_total: int = total_payout / maxi(SaveManager.denomination, 1)
		_game_pays_label.text = "GAME PAYS %d" % display_total
		_game_pays_label.visible = true
		SaveManager.set_currency_value(_win_cd, SaveManager.format_short(total_payout))
		_status_label.text = "GAME OVER"
		_highlight_all_winning()
		if _winning_lines.size() > 0:
			_start_win_cycle()
	else:
		_status_label.text = "GAME OVER"
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


# ─── BUTTON HANDLERS ─────────────────────────────────────────────────

func _on_deal_draw_pressed() -> void:
	if _animating:
		_rush = true
		return
	if _manager.state == SpinPokerManager.State.SPINNING or _manager.state == SpinPokerManager.State.DRAW_SPINNING:
		_rush = true
		return
	# Check credits before deal
	if _manager.state == SpinPokerManager.State.IDLE or _manager.state == SpinPokerManager.State.WIN_DISPLAY:
		if _manager.get_total_bet() > SaveManager.credits:
			_status_label.text = "NOT ENOUGH CREDITS"
			return
	_manager.deal_or_draw()


func _on_card_clicked(event: InputEvent, col: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == SpinPokerManager.State.HOLDING:
			_manager.toggle_hold(col)
			_show_held(col, _manager.held[col])
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


func _update_balance(credits: int) -> void:
	SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(credits))


func _update_bet_display(bet: int) -> void:
	var total: int = SpinPokerManager.NUM_LINES * bet * _current_denomination
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

var _bet_picker_overlay: Control = null

func _show_bet_picker() -> void:
	if _bet_picker_overlay:
		_bet_picker_overlay.queue_free()
	_bet_picker_overlay = Control.new()
	_bet_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bet_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
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
	title.text = "SELECT BET"
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
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
		)
		grid.add_child(btn)


# ─── PAYTABLE POPUP ──────────────────────────────────────────────────

func _show_paytable() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 40
	scroll.offset_bottom = -40
	overlay.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = _variant.paytable.name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_YELLOW)
	vbox.add_child(title)

	var hand_order := _variant.paytable.get_hand_order()
	for key in hand_order:
		var row := _variant.paytable.get_payout_row(key)
		if row == null:
			continue
		var display_name: String = key.replace("_", " ").to_upper()
		var pay5: int = row[4] if row.size() > 4 else row[0]
		var lbl := Label.new()
		lbl.text = "%s — %d" % [display_name, pay5]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(lbl)
