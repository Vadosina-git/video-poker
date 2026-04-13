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
var _held_indicators: Array = []  # 5 Labels for HELD on middle row

# Line indicators (left/right side labels)
var _left_line_labels: Array[Label] = []
var _right_line_labels: Array[Label] = []

# Win line drawing
var _line_draw_node: Control  # Custom draw node for colored lines
var _winning_lines: Array = []  # Array of {line_idx, hand_name, payout}
var _current_win_cycle: int = -1
var _blink_tween: Tween

# Spin animation
var _spin_timers: Array = []  # Per-column spin timers
var _spin_target_cards: Array = []  # Target cards per column
var _columns_stopped: int = 0

# Speed
var _speed_level: int = 1
const SPEED_CONFIGS := [
	{"spin_ms": 120, "stop_delay_ms": 200},
	{"spin_ms": 80,  "stop_delay_ms": 150},
	{"spin_ms": 50,  "stop_delay_ms": 100},
	{"spin_ms": 25,  "stop_delay_ms": 50},
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
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)
	_update_bet_amount_btn()


# ─── UI CONSTRUCTION ──────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	bg.z_index = -1

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	# ── Top: title
	_game_title = Label.new()
	_game_title.text = "SPIN POKER — %s" % _variant.paytable.name.to_upper()
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 22)
	_game_title.add_theme_color_override("font_color", COL_YELLOW)
	var bold := SystemFont.new()
	bold.font_weight = 700
	_game_title.add_theme_font_override("font", bold)
	root_vbox.add_child(_game_title)

	# ── Middle: grid area with line labels
	var grid_area := HBoxContainer.new()
	grid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_area.add_theme_constant_override("separation", 2)
	grid_area.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(grid_area)

	# Left line labels
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 0)
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.custom_minimum_size.x = 32
	grid_area.add_child(left_col)
	for i in 10:
		var lbl := _make_line_label(i)
		left_col.add_child(lbl)
		_left_line_labels.append(lbl)

	# Grid panel
	_grid_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = GRID_BG
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.6, 0.6, 0.7)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	_grid_panel.add_theme_stylebox_override("panel", panel_style)
	_grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_area.add_child(_grid_panel)

	_grid_container = GridContainer.new()
	_grid_container.columns = 5
	_grid_container.add_theme_constant_override("h_separation", 3)
	_grid_container.add_theme_constant_override("v_separation", 3)
	_grid_panel.add_child(_grid_container)

	# Build 15 card slots (3 rows × 5 cols, row by row)
	var card_back_path := "res://assets/cards/card_back.png"
	var back_tex: Texture2D = null
	if ResourceLoader.exists(card_back_path):
		back_tex = load(card_back_path)

	for row in 3:
		_card_rects[row] = []
		for col in 5:
			var tex_rect := TextureRect.new()
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(100, 140)
			tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tex_rect.texture = back_tex
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP if row == 1 else Control.MOUSE_FILTER_IGNORE
			if row == 1:
				var c := col  # capture
				tex_rect.gui_input.connect(_on_card_clicked.bind(c))
			_grid_container.add_child(tex_rect)
			_card_rects[row].append(tex_rect)

	# Line draw overlay (for drawing colored lines through grid)
	_line_draw_node = Control.new()
	_line_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_draw_node.draw.connect(_draw_lines)
	_grid_panel.add_child(_line_draw_node)

	# Right line labels
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 0)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.custom_minimum_size.x = 32
	grid_area.add_child(right_col)
	for i in range(10, 20):
		var lbl := _make_line_label(i)
		right_col.add_child(lbl)
		_right_line_labels.append(lbl)

	# ── Status bar
	_status_label = Label.new()
	_status_label.text = "PLACE YOUR BET"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.add_theme_font_override("font", bold)
	var status_bg := PanelContainer.new()
	var sstyle := StyleBoxFlat.new()
	sstyle.bg_color = Color(0, 0, 0, 0.8)
	sstyle.content_margin_left = 16
	sstyle.content_margin_right = 16
	sstyle.content_margin_top = 6
	sstyle.content_margin_bottom = 6
	status_bg.add_theme_stylebox_override("panel", sstyle)
	status_bg.add_child(_status_label)
	root_vbox.add_child(status_bg)

	# ── Game pays label
	_game_pays_label = Label.new()
	_game_pays_label.text = ""
	_game_pays_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_pays_label.add_theme_font_size_override("font_size", 18)
	_game_pays_label.add_theme_color_override("font_color", COL_YELLOW)
	_game_pays_label.add_theme_font_override("font", bold)
	_game_pays_label.visible = false
	root_vbox.add_child(_game_pays_label)

	# ── Bottom: info row + buttons
	_build_bottom_bar(root_vbox, bold)


func _build_bottom_bar(root_vbox: VBoxContainer, bold: SystemFont) -> void:
	# Info row: WIN | BET
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
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

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(btn_row)

	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_yellow.svg") else null
	var tex_blue := load("res://assets/textures/btn_rect_blue.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_blue.svg") else null
	var tex_green := load("res://assets/textures/btn_rect_green.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_green.svg") else null

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_style_btn(_back_btn, tex_blue, Color.WHITE, 14, 80, 40)
	_back_btn.pressed.connect(func() -> void: back_to_lobby.emit())
	btn_row.add_child(_back_btn)

	_see_pays_btn = Button.new()
	_see_pays_btn.text = "SEE PAYS"
	_style_btn(_see_pays_btn, tex_blue, Color.WHITE, 14, 100, 40)
	_see_pays_btn.pressed.connect(_show_paytable)
	btn_row.add_child(_see_pays_btn)

	_bet_amount_btn = Button.new()
	_bet_amount_btn.text = ""
	_style_btn(_bet_amount_btn, tex_blue, Color.WHITE, 14, 100, 40)
	_bet_amount_btn.pressed.connect(_on_bet_amount_pressed)
	btn_row.add_child(_bet_amount_btn)

	_deal_draw_btn = Button.new()
	_deal_draw_btn.text = "DEAL\nSPIN"
	_style_btn(_deal_draw_btn, tex_green, Color.WHITE, 16, 110, 48)
	_deal_draw_btn.pressed.connect(_on_deal_draw_pressed)
	btn_row.add_child(_deal_draw_btn)

	_bet_btn = Button.new()
	_bet_btn.text = "BET"
	_style_btn(_bet_btn, tex_yellow, COL_BTN_TEXT, 14, 80, 40)
	_bet_btn.pressed.connect(_on_bet_one_pressed)
	btn_row.add_child(_bet_btn)

	_bet_max_btn = Button.new()
	_bet_max_btn.text = "BET MAX"
	_style_btn(_bet_max_btn, tex_yellow, COL_BTN_TEXT, 14, 100, 40)
	_bet_max_btn.pressed.connect(_on_bet_max_pressed)
	btn_row.add_child(_bet_max_btn)

	_speed_btn = Button.new()
	_speed_btn.text = "SPEED"
	_style_btn(_speed_btn, tex_blue, Color.WHITE, 12, 80, 40)
	_speed_btn.pressed.connect(_on_speed_pressed)
	btn_row.add_child(_speed_btn)


func _style_btn(btn: Button, tex: Texture2D, text_col: Color, font_sz: int, min_w: int, min_h: int) -> void:
	if tex:
		var style := StyleBoxTexture.new()
		style.texture = tex
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
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
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", SpinPokerManager.LINE_COLORS[line_idx])
	lbl.custom_minimum_size = Vector2(28, 0)
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


func _set_card_back(row: int, col: int) -> void:
	var path := "res://assets/cards/card_back.png"
	if ResourceLoader.exists(path):
		_card_rects[row][col].texture = load(path)


func _set_placeholder(row: int, col: int) -> void:
	# Purple placeholder for top/bottom rows before draw
	_card_rects[row][col].texture = null
	_card_rects[row][col].modulate = Color(0.6, 0.4, 0.8, 0.3)


func _reset_card_modulate(row: int, col: int) -> void:
	_card_rects[row][col].modulate = Color.WHITE


func _reset_all_modulate() -> void:
	for row in 3:
		for col in 5:
			_card_rects[row][col].modulate = Color.WHITE


# ─── HELD INDICATORS ──────────────────────────────────────────────────

func _show_held(col: int, show: bool) -> void:
	if col >= _held_indicators.size():
		return
	_held_indicators[col].visible = show


func _build_held_indicators() -> void:
	# Built after layout is ready (deferred)
	for indicator in _held_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_held_indicators.clear()
	for col in 5:
		var lbl := Label.new()
		lbl.text = "HELD"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", COL_YELLOW)
		var bold := SystemFont.new()
		bold.font_weight = 700
		lbl.add_theme_font_override("font", bold)
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 5
		add_child(lbl)
		_held_indicators.append(lbl)
	_position_held_indicators.call_deferred()


func _position_held_indicators() -> void:
	await get_tree().process_frame
	for col in 5:
		if col >= _held_indicators.size():
			break
		var card_rect: TextureRect = _card_rects[1][col]
		var rect := card_rect.get_global_rect()
		var lbl: Label = _held_indicators[col]
		lbl.size = Vector2(rect.size.x, 20)
		lbl.global_position = Vector2(rect.position.x, rect.position.y + rect.size.y - 20)


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
	_game_pays_label.visible = false
	SaveManager.set_currency_value(_win_cd, "0")
	_reset_all_modulate()

	# Clear held
	for col in 5:
		_show_held(col, false)

	# Set top/bottom to placeholder
	for col in 5:
		_set_placeholder(0, col)
		_set_placeholder(2, col)

	# Animate middle row: spin each column left to right
	await _animate_spin_deal(mid_row)
	_build_held_indicators()
	_animating = false
	_manager.on_deal_spin_complete()


func _animate_spin_deal(mid_row: Array[CardData]) -> void:
	var delay_ms: int = SPEED_CONFIGS[_speed_level]["stop_delay_ms"]

	if _rush or _speed_level >= 3:
		# Instant: just show cards
		for col in 5:
			_reset_card_modulate(1, col)
			_set_card_texture(1, col, mid_row[col])
		return

	# Start all columns spinning (rapid texture cycling)
	var spin_active := [true, true, true, true, true]
	var random_cards := _build_random_card_paths(25)

	# Spin timer: cycle textures rapidly
	var spin_timer := Timer.new()
	spin_timer.wait_time = SPEED_CONFIGS[_speed_level]["spin_ms"] / 1000.0
	spin_timer.autostart = true
	add_child(spin_timer)
	var frame_idx := [0]
	spin_timer.timeout.connect(func() -> void:
		for col in 5:
			if spin_active[col]:
				_reset_card_modulate(1, col)
				var idx: int = (frame_idx[0] + col * 3) % random_cards.size()
				var path: String = random_cards[idx]
				if ResourceLoader.exists(path):
					_card_rects[1][col].texture = load(path)
		frame_idx[0] += 1
	)

	# Stop columns left to right
	for col in 5:
		await get_tree().create_timer(delay_ms / 1000.0).timeout
		spin_active[col] = false
		_reset_card_modulate(1, col)
		_set_card_texture(1, col, mid_row[col])
		SoundManager.play("deal")

	spin_timer.stop()
	spin_timer.queue_free()


# ─── DRAW SPIN ────────────────────────────────────────────────────────

func _on_draw_spin_complete(grid: Array) -> void:
	_animating = true

	# First: duplicate held cards to top/bottom instantly
	for col in 5:
		if _manager.held[col]:
			_reset_card_modulate(0, col)
			_reset_card_modulate(2, col)
			_set_card_texture(0, col, grid[0][col])
			_set_card_texture(2, col, grid[2][col])

	# Animate unheld columns
	await _animate_spin_draw(grid)
	_animating = false
	_manager.on_draw_spin_complete()


func _animate_spin_draw(grid: Array) -> void:
	var delay_ms: int = SPEED_CONFIGS[_speed_level]["stop_delay_ms"]

	if _rush or _speed_level >= 3:
		for row in 3:
			for col in 5:
				_reset_card_modulate(row, col)
				_set_card_texture(row, col, grid[row][col])
		return

	var spin_active := [false, false, false, false, false]
	for col in 5:
		if not _manager.held[col]:
			spin_active[col] = true

	var random_cards := _build_random_card_paths(25)
	var spin_timer := Timer.new()
	spin_timer.wait_time = SPEED_CONFIGS[_speed_level]["spin_ms"] / 1000.0
	spin_timer.autostart = true
	add_child(spin_timer)
	var frame_idx := [0]
	spin_timer.timeout.connect(func() -> void:
		for col in 5:
			if spin_active[col]:
				for row in 3:
					_reset_card_modulate(row, col)
					var idx: int = (frame_idx[0] + col * 3 + row * 7) % random_cards.size()
					var path: String = random_cards[idx]
					if ResourceLoader.exists(path):
						_card_rects[row][col].texture = load(path)
		frame_idx[0] += 1
	)

	for col in 5:
		if not spin_active[col]:
			continue
		await get_tree().create_timer(delay_ms / 1000.0).timeout
		spin_active[col] = false
		for row in 3:
			_reset_card_modulate(row, col)
			_set_card_texture(row, col, grid[row][col])
		SoundManager.play("deal")

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
		# Highlight all winning cards
		_highlight_all_winning()
		# Start cycling through individual winning lines
		if _winning_lines.size() > 0:
			_start_win_cycle()
	else:
		_status_label.text = "GAME OVER"
		_game_pays_label.visible = false


func _highlight_all_winning() -> void:
	# Dim all cards first
	for row in 3:
		for col in 5:
			_card_rects[row][col].modulate = Color(0.4, 0.4, 0.5)
	# Brighten cards that appear in any winning line
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
	var line_idx: int = w["line_idx"]
	var payout_coins: int = w["payout"] / maxi(SaveManager.denomination, 1)
	_status_label.text = "%s PAYS %d" % [w["hand_name"], payout_coins]
	_line_draw_node.queue_redraw()


func _stop_win_cycle() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	_current_win_cycle = -1
	_winning_lines.clear()
	_line_draw_node.queue_redraw()


func _clear_line_display() -> void:
	_winning_lines.clear()
	_current_win_cycle = -1
	_line_draw_node.queue_redraw()


# ─── LINE DRAWING ─────────────────────────────────────────────────────

func _draw_lines() -> void:
	if _winning_lines.size() == 0 or _current_win_cycle < 0:
		return
	# Draw current winning line
	var w: Dictionary = _winning_lines[_current_win_cycle]
	var line_idx: int = w["line_idx"]
	var color: Color = SpinPokerManager.LINE_COLORS[line_idx]
	var points: PackedVector2Array = PackedVector2Array()
	for col in 5:
		var row: int = SpinPokerManager.LINES[line_idx][col]
		var card_rect: TextureRect = _card_rects[row][col]
		var center := card_rect.get_rect().get_center()
		# Convert from card_rect local → grid_container local → line_draw_node local
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
	_manager.deal_or_draw()


func _on_card_clicked(event: InputEvent, col: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == SpinPokerManager.State.HOLDING:
			_manager.toggle_hold(col)
			_show_held(col, _manager.held[col])
			# Duplicate held card to top/bottom visually
			if _manager.held[col]:
				_reset_card_modulate(0, col)
				_reset_card_modulate(2, col)
				_set_card_texture(0, col, _manager.middle_row[col])
				_set_card_texture(2, col, _manager.middle_row[col])
			else:
				_set_placeholder(0, col)
				_set_placeholder(2, col)


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


func _on_bet_changed(new_bet: int) -> void:
	_update_bet_display(new_bet)


func _on_credits_changed(new_credits: int) -> void:
	_update_balance(new_credits)


# ─── UI UPDATES ───────────────────────────────────────────────────────

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
	SaveManager.set_currency_value(_bet_btn_cd, SaveManager.format_auto(_current_denomination, 76, 16))


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
