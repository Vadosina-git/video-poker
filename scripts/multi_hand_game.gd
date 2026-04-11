extends Control
## Multi-hand video poker game screen.
## Shows N hands vertically — primary (bottom, large) + extra hands (above, smaller).
## All hands share the same hold pattern but draw from independent decks.

signal back_to_lobby

var CardScene: PackedScene
var MiniHandScene: PackedScene

# Node refs
@onready var _hands_area: VBoxContainer = %HandsArea
@onready var _game_title: Label = %GameTitle
@onready var _back_btn: Button = %BackButton
@onready var _win_label: Label = %WinLabel
@onready var _total_bet_label: Label = %TotalBetLabel
@onready var _balance_label: Label = %BalanceLabel
@onready var _topup_btn: Button = %TopUpButton
@onready var _speed_btn: Button = %SpeedButton
@onready var _hands_btn: Button = %HandsButton
@onready var _bet_amount_btn: Button = %BetAmountButton
@onready var _bet_btn: Button = %BetButton
@onready var _bet_max_btn: Button = %BetMaxButton
@onready var _deal_draw_btn: Button = %DealDrawButton
@onready var _bottom_bar: HBoxContainer = %BottomBar
@onready var _info_row: HBoxContainer = %InfoRow
@onready var _bottom_section: VBoxContainer = %BottomSection

var _manager: MultiHandManager
var _variant: BaseVariant
var _rush_round: bool = false
var _num_hands: int = 3
var _blink_tween: Tween = null
var _bet_flash_tween: Tween
var _balance_cd: Dictionary
var _bet_cd: Dictionary
var _win_cd: Dictionary

# Primary hand (bottom row, interactive)
var _primary_cards: Array = []  # Array of card_visual TextureRect
var _primary_container: HBoxContainer
var _animating: bool = false
var _primary_win_mask: Array = [false, false, false, false, false]

# Extra hands (above primary, non-interactive mini displays)
var _extra_displays: Array = []  # Array of MiniHandDisplay

# Colors
const COL_YELLOW := Color("FFEC00")
const COL_GREEN := Color("07E02F")
const COL_BTN_TEXT := Color("3F2A00")

# Speed
var _speed_level: int = 1
const SPEED_CONFIGS := [
	{"deal_ms": 150, "draw_ms": 200, "flip_s": 0.15},
	{"deal_ms": 100, "draw_ms": 140, "flip_s": 0.12},
	{"deal_ms": 60,  "draw_ms": 80,  "flip_s": 0.08},
	{"deal_ms": 30,  "draw_ms": 40,  "flip_s": 0.05},
]

# Bet picker
const BET_AMOUNTS := [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
var _current_denomination: int = 1
var _bet_picker_overlay: Control = null


func setup(variant: BaseVariant, num_hands: int) -> void:
	_variant = variant
	_num_hands = num_hands


func _ready() -> void:
	if _variant == null:
		return

	CardScene = load("res://scenes/card.tscn")
	MiniHandScene = load("res://scenes/mini_hand.tscn")

	_manager = MultiHandManager.new()
	add_child(_manager)
	_manager.setup(_variant, _num_hands)

	# Connect signals
	_manager.all_hands_dealt.connect(_on_hands_dealt)
	_manager.all_hands_drawn.connect(_on_hands_drawn)
	_manager.all_hands_evaluated.connect(_on_hands_evaluated)
	_manager.credits_changed.connect(_on_credits_changed)
	_manager.bet_changed.connect(_on_bet_changed)
	_manager.state_changed.connect(_on_state_changed)

	# Buttons
	_back_btn.pressed.connect(func() -> void: back_to_lobby.emit())
	_speed_btn.pressed.connect(_on_speed_pressed)
	_bet_btn.pressed.connect(_manager.bet_one)
	_bet_amount_btn.pressed.connect(_on_bet_amount_pressed)
	_bet_max_btn.pressed.connect(_manager.bet_max)
	_deal_draw_btn.pressed.connect(_on_deal_draw_pressed)
	_hands_btn.pressed.connect(func() -> void: pass)  # Future: cycle hand count
	_topup_btn.pressed.connect(_show_shop)
	# Rush detection — catch any click/tap during animations

	_speed_level = SaveManager.speed_level
	_apply_theme()
	_build_hands_area()
	_build_paytable_badges()
	_update_speed_display()

	_game_title.text = _variant.paytable.name.to_upper()
	_hands_btn.text = "%d HANDS" % _num_hands
	_current_denomination = _recommend_denomination()
	SaveManager.denomination = _current_denomination
	_update_bet_amount_btn()
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)
	_win_label.text = "WIN:"


func _apply_theme() -> void:
	$VBoxContainer.add_theme_constant_override("separation", 2)

	# Title
	_back_btn.add_theme_font_size_override("font_size", 18)
	_back_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0, 0, 0, 0)
	_back_btn.add_theme_stylebox_override("normal", back_style)
	_back_btn.add_theme_stylebox_override("hover", back_style)
	_back_btn.add_theme_stylebox_override("pressed", back_style)

	_game_title.add_theme_font_size_override("font_size", 20)
	_game_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))

	# Hands area
	_hands_area.add_theme_constant_override("separation", 4)
	_hands_area.alignment = BoxContainer.ALIGNMENT_END

	# --- Bottom section ---
	_bottom_section.add_theme_constant_override("separation", 2)

	# Info row: [WIN chip_val | TOTAL BET chip_val] ... [BALANCE chip_val | +]
	_info_row.add_theme_constant_override("separation", 10)
	_win_label.add_theme_font_size_override("font_size", 16)
	_win_label.add_theme_color_override("font_color", COL_YELLOW)
	_win_label.text = "WIN:"
	_win_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_info_row.add_child(_win_cd["box"])
	_info_row.move_child(_win_cd["box"], _win_label.get_index() + 1)
	SaveManager.set_currency_value(_win_cd, "0")
	_total_bet_label.add_theme_font_size_override("font_size", 16)
	_total_bet_label.add_theme_color_override("font_color", Color.WHITE)
	_total_bet_label.text = "TOTAL BET:"
	_bet_cd = SaveManager.create_currency_display(16, Color.WHITE)
	_info_row.add_child(_bet_cd["box"])
	_info_row.move_child(_bet_cd["box"], _total_bet_label.get_index() + 1)
	_balance_label.add_theme_font_size_override("font_size", 16)
	_balance_label.add_theme_color_override("font_color", COL_YELLOW)
	_balance_label.text = "BALANCE:"
	_balance_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_info_row.add_child(_balance_cd["box"])
	_info_row.move_child(_balance_cd["box"], _balance_label.get_index() + 1)

	# Top-up button — small yellow square
	_topup_btn.add_theme_font_size_override("font_size", 18)
	_topup_btn.add_theme_color_override("font_color", COL_YELLOW)
	var topup_style := StyleBoxFlat.new()
	topup_style.bg_color = Color(0.1, 0.1, 0.4, 0.8)
	topup_style.set_border_width_all(2)
	topup_style.border_color = COL_YELLOW
	topup_style.set_corner_radius_all(4)
	topup_style.content_margin_left = 6
	topup_style.content_margin_right = 6
	topup_style.content_margin_top = 0
	topup_style.content_margin_bottom = 0
	_topup_btn.add_theme_stylebox_override("normal", topup_style)
	_topup_btn.add_theme_stylebox_override("hover", topup_style)
	_topup_btn.add_theme_stylebox_override("pressed", topup_style)
	_topup_btn.custom_minimum_size = Vector2(28, 24)

	# Button bar — flat, grouped with spacers
	_bottom_bar.add_theme_constant_override("separation", 0)
	_build_button_groups.call_deferred()

	# Button textures
	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg")
	var tex_panel := load("res://assets/textures/btn_panel11.svg")
	var tex_panel_w := load("res://assets/textures/btn_panel11-1.svg")
	var tex_green := load("res://assets/textures/btn_rect_green.svg")
	var tex_blue := load("res://assets/textures/btn_blue.svg")
	var tex_gray := load("res://assets/textures/btn_panel11.svg")

	var btn_h := 36

	# Left group: SPEED
	_style_btn(_speed_btn, tex_panel_w, Color.WHITE, 13, 110, btn_h)

	# Center group: HANDS, $amount, BET, BET MAX
	_style_btn(_hands_btn, tex_panel, Color.WHITE, 14, 100, btn_h)
	_style_btn(_bet_amount_btn, tex_blue, Color.WHITE, 16, 120, btn_h)
	_style_btn(_bet_btn, tex_yellow, COL_BTN_TEXT, 14, 80, btn_h)
	_style_btn(_bet_max_btn, tex_yellow, COL_BTN_TEXT, 14, 100, btn_h)

	# Right group: DEAL
	_style_btn(_deal_draw_btn, tex_green, Color.WHITE, 18, 120, btn_h)


func _build_button_groups() -> void:
	# Insert spacers between button groups in BottomBar:
	# [SPEED] [spacer] [HANDS] [$amt] [BET] [BET MAX] [spacer] [DEAL]
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(spacer_l)
	_bottom_bar.move_child(spacer_l, _speed_btn.get_index() + 1)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(spacer_r)
	_bottom_bar.move_child(spacer_r, _bet_max_btn.get_index() + 1)


func _style_btn(btn: Button, tex: Texture2D, text_col: Color, font_sz: int, min_w: int, min_h: int) -> void:
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


# --- Build hands area ---

var _extra_grid: GridContainer

func _build_hands_area() -> void:
	var extra_rect: Control = %ExtraHandsRect
	var primary_row: HBoxContainer = %PrimaryRow

	# Grid inside ExtraHandsRect — columns based on hand count
	_extra_grid = GridContainer.new()
	_extra_grid.set_anchors_preset(Control.PRESET_CENTER)
	_extra_grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_extra_grid.grow_vertical = Control.GROW_DIRECTION_BOTH
	_extra_grid.columns = _get_grid_cols()
	_extra_grid.add_theme_constant_override("h_separation", 16)
	_extra_grid.add_theme_constant_override("v_separation", 10)
	extra_rect.add_child(_extra_grid)

	# Extra hands — GridContainer
	var num_extra: int = _num_hands - 1
	var cols: int = _get_grid_cols()
	_extra_grid.columns = cols
	var remainder: int = num_extra % cols

	# If last row is incomplete, insert a spacer at the start of last row
	# to shift hands right by half a hand width → centered
	var spacer_index: int = -1
	if remainder > 0 and remainder < cols:
		# Last row starts at this child index
		var full_rows: int = num_extra / cols
		spacer_index = full_rows * cols
		# Add +1 column to accommodate the spacer in the last row
		_extra_grid.columns = cols + 1  # temporarily wider for last row? No — GridContainer uses fixed cols.
		# Different approach: insert a half-width spacer as a grid child
		# GridContainer wraps at `columns` — spacer takes one cell position
		_extra_grid.columns = cols  # keep cols, we'll handle spacer sizing

	for i in num_extra:
		var mh: MiniHandDisplay = MiniHandScene.instantiate()
		mh._variant = _variant
		mh._overlay_parent = self
		_extra_grid.add_child(mh)
		_extra_displays.append(mh)
		mh.show_back()

	# No spacer in grid — we'll offset last row after sizing

	# Size extra cards after layout settles
	_size_extra_hands.call_deferred()

	# Primary hand — fixed row at bottom
	_primary_container = primary_row
	_primary_container.add_theme_constant_override("separation", 12)
	_primary_container.alignment = BoxContainer.ALIGNMENT_CENTER

	for i in 5:
		var card: TextureRect = CardScene.instantiate()
		card.card_index = i
		card.clicked.connect(_on_card_clicked)
		card.custom_minimum_size = _get_primary_card_size()
		_primary_container.add_child(card)
		_primary_cards.append(card)

	# Move HELD labels to bottom of cards for multi-hand
	for card in _primary_cards:
		card.set_held_bottom()


func _get_grid_cols() -> int:
	# Grid layout: columns based on number of extra hands
	var num_extra: int = _num_hands - 1
	match num_extra:
		2: return 1       # 3-hand: 2 extra → 1 column, 2 rows (stacked like original)
		4: return 2       # 5-hand: 4 extra → 2 columns, 2 rows
		9: return 3       # 10-hand: 9 extra → 3 columns, 3 rows
		11: return 3      # 12-hand: 11 extra → 3 columns, 4 rows
		24: return 5      # 25-hand: 24 extra → 5 columns, 5 rows
		_:
			if num_extra <= 4: return 2
			if num_extra <= 9: return 3
			if num_extra <= 16: return 4
			return 5


func _size_extra_hands() -> void:
	var extra_rect: Control = %ExtraHandsRect
	var rect_h: int = int(extra_rect.size.y)
	var rect_w: int = int(extra_rect.size.x)
	var num_extra: int = _num_hands - 1
	if num_extra <= 0 or rect_h <= 0:
		return

	var cols: int = _get_grid_cols()
	var rows: int = ceili(float(num_extra) / cols)

	# Calculate card size from available space
	var h_sep: int = 12
	var v_sep: int = 6
	var avail_h: int = rect_h - v_sep * (rows - 1)
	var avail_w: int = rect_w - h_sep * (cols - 1)

	# Each cell: one hand (5 overlapping cards)
	# Card height = cell height
	var cell_h: int = avail_h / rows
	var cell_w: int = avail_w / cols

	# Card dimensions — height from cell, width constrained by cell
	var card_h: int = cell_h - 4
	var card_w: int = int(card_h * 0.739)

	var use_overlap: bool = cols > 1  # No overlap for single-column (3-hand mode)

	if use_overlap:
		# Overlapping cards: total_w = card_w * 0.3 * 4 + card_w = card_w * 2.2
		var max_card_w: int = int(cell_w / 2.2)
		if card_w > max_card_w:
			card_w = max_card_w
			card_h = int(card_w / 0.739)
	else:
		# Full cards in a row: 5 cards + 4 gaps
		var gap: int = 4
		var max_card_w: int = (cell_w - gap * 4) / 5
		if card_w > max_card_w:
			card_w = max_card_w
			card_h = int(card_w / 0.739)

	card_w = maxi(card_w, 16)
	card_h = maxi(card_h, 22)

	var sep: int
	if use_overlap:
		sep = -int(card_w * 0.65)
	else:
		sep = 4  # Normal spacing for 3-hand mode

	# Calculate hand visual width for spacer sizing
	var hand_vis_w: int
	if use_overlap:
		hand_vis_w = int(card_w * 0.35 * 4 + card_w)
	else:
		hand_vis_w = card_w * 5 + sep * 4

	for mini in _extra_displays:
		mini.set_card_size(card_w, card_h)
		mini.add_theme_constant_override("separation", sep)

	_extra_grid.add_theme_constant_override("h_separation", h_sep)
	_extra_grid.add_theme_constant_override("v_separation", v_sep)

	# Offset last row hands for centering if incomplete
	var remainder: int = num_extra % cols
	if remainder > 0 and remainder < cols:
		var shift: float = (hand_vis_w + h_sep) / 2.0
		# Last `remainder` displays are in the last row
		var last_row_start: int = _extra_displays.size() - remainder
		_center_last_row.call_deferred(last_row_start, remainder, shift)


func _center_last_row(start_idx: int, count: int, shift: float) -> void:
	await get_tree().process_frame
	for i in count:
		var idx: int = start_idx + i
		if idx < _extra_displays.size():
			_extra_displays[idx].position.x += shift


func _get_primary_card_size() -> Vector2:
	# Compact primary hand — same across all multihand modes
	return Vector2(144, 202)


# --- Speed ---

func _get_deal_ms() -> int:
	return SPEED_CONFIGS[_speed_level]["deal_ms"]

func _get_flip_s() -> float:
	return SPEED_CONFIGS[_speed_level]["flip_s"]

func _on_speed_pressed() -> void:
	_speed_level = (_speed_level + 1) % SPEED_CONFIGS.size()
	SaveManager.speed_level = _speed_level
	SaveManager.save_game()
	_update_speed_display()

func _update_speed_display() -> void:
	var arrows := ""
	for i in 4:
		arrows += "▶" if i <= _speed_level else "▷"
	_speed_btn.text = arrows + "\nSPEED"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == MultiHandManager.State.DRAWING or _manager.state == MultiHandManager.State.DEALING:
			_rush_round = true


func _is_rushing() -> bool:
	return _rush_round or _is_instant()


# --- Display helpers ---

func _update_balance(credits: int) -> void:
	SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(credits))

func _update_bet_display(bet: int) -> void:
	var total: int = bet * _num_hands * SaveManager.denomination
	SaveManager.set_currency_value(_bet_cd, SaveManager.format_short(total))
	_flash_bet_display()


func _flash_bet_display() -> void:
	if _bet_flash_tween:
		_bet_flash_tween.kill()
	SaveManager.set_currency_value(_bet_cd, "", 20, COL_YELLOW)
	_bet_flash_tween = create_tween()
	_bet_flash_tween.tween_interval(0.4)
	_bet_flash_tween.tween_callback(func() -> void:
		SaveManager.set_currency_value(_bet_cd, "", 16, Color.WHITE)
	)

const MIN_GAME_DEPTH := 30

func _recommend_denomination() -> int:
	var balance := SaveManager.credits
	var best: int = BET_AMOUNTS[0]
	for amount in BET_AMOUNTS:
		# worst case total_bet = denomination * max_bet * num_hands
		if balance / (amount * MultiHandManager.MAX_BET * _num_hands) >= MIN_GAME_DEPTH:
			best = amount
		else:
			break
	return best


var _bet_btn_cd: Dictionary

func _update_bet_amount_btn() -> void:
	_bet_amount_btn.text = ""
	_bet_amount_btn.icon = null
	if _bet_btn_cd.is_empty():
		_bet_btn_cd = SaveManager.create_currency_display(14, Color.WHITE)
		_bet_btn_cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bet_btn_cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		_bet_amount_btn.add_child(_bet_btn_cd["box"])
	SaveManager.set_currency_value(_bet_btn_cd, SaveManager.format_short(_current_denomination))





# --- State changes ---

func _on_state_changed(new_state: int) -> void:
	match new_state:
		MultiHandManager.State.IDLE:
			_deal_draw_btn.text = "DEAL"
			_bet_btn.disabled = false
			_bet_max_btn.disabled = false
			_deal_draw_btn.disabled = false
			_win_label.text = "PLACE YOUR BET"
			_win_cd["box"].visible = false
			_win_label.add_theme_color_override("font_color", COL_YELLOW)
			for card in _primary_cards:
				card.set_interactive(false)

		MultiHandManager.State.DEALING:
			_deal_draw_btn.disabled = true
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_win_label.text = ""

		MultiHandManager.State.HOLDING:
			_deal_draw_btn.text = "DRAW"
			_deal_draw_btn.disabled = false
			_win_label.text = "HOLD CARDS, THEN DRAW"
			for i in _primary_cards.size():
				_primary_cards[i].set_interactive(true)
				if _manager.held[i]:
					_primary_cards[i].set_held(true)
			# Show held cards in extra hands, backs for non-held
			for mini in _extra_displays:
				_show_mini_held(mini)

		MultiHandManager.State.DRAWING:
			_deal_draw_btn.disabled = true
			for card in _primary_cards:
				card.set_interactive(false)

		MultiHandManager.State.WIN_DISPLAY:
			_deal_draw_btn.text = "DEAL"
			_deal_draw_btn.disabled = true
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true


func _show_mini_held(mini: MiniHandDisplay) -> void:
	# Show held cards face-up using mini's own _get_card_path (wild-aware)
	var back_tex: Texture2D = load("res://assets/cards/card_back.png")
	for i in 5:
		if _manager.held[i]:
			mini.show_card_at(i, _manager.primary_hand[i], false)
		else:
			mini._card_textures[i].texture = back_tex
			mini._face_up[i] = false
			mini._face_up[i] = false


# --- Deal / Draw ---

func _is_instant() -> bool:
	return _get_flip_s() < 0.03


func _on_hands_dealt(primary_hand: Array[CardData]) -> void:
	_animating = true
	_rush_round = false
	_stop_result_blink()
	_hide_primary_result()
	for mini in _extra_displays:
		mini.hide_result()
	var delay: float = _get_deal_ms() / 1000.0

	# Flip ALL hands to back — column by column
	for mini in _extra_displays:
		mini.reset_highlight()

	for i in 5:
		var did_flip := false
		_primary_cards[i].set_flip_duration(_get_flip_s())
		if _primary_cards[i].face_up:
			_primary_cards[i].flip_to_back()
			did_flip = true
		for mini in _extra_displays:
			if mini.is_face_up_at(i):
				mini.show_back_at(i, not _is_rushing())
				did_flip = true
		if did_flip:
			if not _is_rushing():
				SoundManager.play("flip")
				await get_tree().create_timer(delay).timeout

	if not _is_rushing():
		await get_tree().create_timer(0.08).timeout
	else:
		await get_tree().create_timer(0.02).timeout

	# Deal primary hand
	for i in 5:
		_primary_cards[i].set_flip_duration(0.0 if _is_rushing() else _get_flip_s())
		_primary_cards[i].set_card(primary_hand[i], true, _variant.is_wild_card(primary_hand[i]))
		if not _is_rushing():
			SoundManager.play("deal")
			if i < 4:
				await get_tree().create_timer(delay).timeout
	# Wait for the last card's flip animation to finish before showing HELD
	if not _is_rushing():
		await get_tree().create_timer(_get_flip_s() * 2).timeout
	_animating = false
	_manager.on_deal_animation_complete()


func _on_deal_draw_pressed() -> void:
	if _animating:
		return
	if _manager.state == MultiHandManager.State.HOLDING:
		_animating = true
		var delay: float = _get_deal_ms() / 1000.0
		# Flip non-held primary cards to back
		for i in 5:
			if not _manager.held[i]:
				_primary_cards[i].set_flip_duration(0.0 if _is_rushing() else _get_flip_s())
				_primary_cards[i].flip_to_back()
				if not _is_rushing():
					SoundManager.play("flip")
					await get_tree().create_timer(delay).timeout
		if not _is_rushing():
			await get_tree().create_timer(0.08).timeout
		_manager.draw()
	else:
		_manager.deal_or_draw()


func _on_hands_drawn(all_hands: Array) -> void:
	var delay: float = _get_deal_ms() / 1000.0

	# 1. Primary hand — card by card
	var primary: Array = all_hands[0]
	for i in 5:
		if not _manager.held[i]:
			_primary_cards[i].set_flip_duration(0.0 if _is_rushing() else _get_flip_s())
			_primary_cards[i].set_card(primary[i], true, _variant.is_wild_card(primary[i]))
			if not _is_rushing():
				SoundManager.play("deal")
				await get_tree().create_timer(delay).timeout

	# 2. Extra hands bottom-to-top, each hand card by card
	var cols: int = _get_grid_cols()
	var num_extra: int = _extra_displays.size()
	var rows_count: int = ceili(float(num_extra) / cols)
	var hand_keys := _variant.paytable.get_hand_order()
	for row in range(rows_count - 1, -1, -1):
		for col in cols:
			var idx: int = row * cols + col
			if idx >= num_extra:
				continue
			var h: int = idx + 1
			if h >= all_hands.size():
				continue
			var hand: Array = all_hands[h]
			var mini: MiniHandDisplay = _extra_displays[idx]
			for i in 5:
				if not _manager.held[i] and i < hand.size():
					mini.show_card_at(i, hand[i], not _is_rushing())
					if not _is_rushing():
						await get_tree().create_timer(delay * 0.5).timeout
			if _is_rushing():
				await get_tree().create_timer(0.03).timeout
			# Show result immediately after this hand's cards are revealed
			var hand_rank := _variant.evaluate(hand)
			var payout: int = _variant.get_payout(hand_rank, _manager.bet) * SaveManager.denomination
			var hand_name: String = _variant.get_hand_name(hand_rank)
			if payout > 0:
				var multiplier: int = int(payout / SaveManager.denomination) if SaveManager.denomination > 0 else payout
				var badge_color := _get_badge_color_for_hand(hand_name, hand_keys)
				mini.show_result(hand_name, multiplier, badge_color)
				mini.set_win_mask(_variant.get_hold_mask(hand, hand_rank))
			else:
				mini.show_result("", 0, Color.TRANSPARENT)
				mini.set_win_mask([false, false, false, false, false])
		if not _is_rushing():
			await get_tree().create_timer(0.05).timeout

	# Wait for last card flip animation to finish
	if not _is_rushing():
		await get_tree().create_timer(_get_flip_s() * 2).timeout
	# Dim all losing hands simultaneously
	for mini in _extra_displays:
		mini.apply_final_dim()
	_animating = false
	_manager.on_draw_animation_complete()


func _on_hands_evaluated(results: Array, total_payout: int) -> void:
	# Extra hand results already shown during draw animation
	_start_result_blink()

	# Primary hand result overlay + win mask
	_primary_win_mask = [false, false, false, false, false]
	if results.size() > 0:
		var pr: Dictionary = results[0]
		var p_payout: int = int(pr["payout"])
		if p_payout > 0:
			var p_mult: int = int(p_payout / SaveManager.denomination) if SaveManager.denomination > 0 else p_payout
			_show_primary_result(pr["hand_name"], p_mult)

	# Show total win + animate credits
	if total_payout > 0:
		_win_label.text = "WIN:"
		SaveManager.set_currency_value(_win_cd, SaveManager.format_short(total_payout))
		_win_cd["box"].visible = true
		_win_label.add_theme_color_override("font_color", COL_YELLOW)
	else:
		_win_label.text = "NO WIN"
		_win_cd["box"].visible = false
		_win_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
		_delay_unlock_buttons()


func _start_result_blink() -> void:
	_stop_result_blink()
	_blink_tween = create_tween().set_loops()
	# 7s cycle: visible 6s, badges off + dim non-winners 0.85s, badges on + undim
	_blink_tween.tween_interval(6.0)
	_blink_tween.tween_callback(_on_blink_off)
	_blink_tween.tween_interval(0.85)
	_blink_tween.tween_callback(_on_blink_on)
	_blink_tween.tween_interval(0.15)


func _on_blink_off() -> void:
	for mini in _extra_displays:
		if mini._result_overlay:
			mini.set_result_alpha(0.0)
			mini.dim_non_winning()


func _on_blink_on() -> void:
	for mini in _extra_displays:
		if mini._result_overlay:
			mini.set_result_alpha(1.0)
			mini.undim_all()


func _stop_result_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	for mini in _extra_displays:
		mini.set_result_alpha(1.0)
		mini.undim_all()


func _set_all_results_alpha(alpha: float) -> void:
	for mini in _extra_displays:
		mini.set_result_alpha(alpha)


var _credit_tween: Tween = null
var _displayed_credits: int = -1

func _on_credits_changed(new_credits: int) -> void:
	if _manager.state == MultiHandManager.State.WIN_DISPLAY or _manager.state == MultiHandManager.State.EVALUATING:
		_animate_credits(new_credits)
	else:
		_update_balance(new_credits)
		_displayed_credits = new_credits


func _animate_credits(target: int) -> void:
	if _credit_tween:
		_credit_tween.kill()
	var start := _displayed_credits if _displayed_credits >= 0 else target
	_displayed_credits = start
	# Highlight balance during roll-up
	SaveManager.set_currency_value(_balance_cd, "", 20, Color.WHITE)
	_credit_tween = create_tween()
	_credit_tween.tween_method(_update_credit_display, start, target, 1.0).set_ease(Tween.EASE_OUT)
	_credit_tween.tween_callback(_on_credit_animation_done)


func _update_credit_display(value: int) -> void:
	_displayed_credits = value
	SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(value))


func _on_credit_animation_done() -> void:
	SaveManager.set_currency_value(_balance_cd, "", 16, COL_YELLOW)
	_unlock_buttons()


func _delay_unlock_buttons() -> void:
	await get_tree().create_timer(0.5).timeout
	_unlock_buttons()


func _unlock_buttons() -> void:
	_deal_draw_btn.disabled = false
	_bet_btn.disabled = false
	_bet_max_btn.disabled = false

func _on_bet_changed(new_bet: int) -> void:
	_update_bet_display(new_bet)
	_update_paytable_badges()

func _on_card_clicked(card_index: int) -> void:
	_manager.toggle_hold(card_index)
	_primary_cards[card_index].set_held(_manager.held[card_index])
	# Update extra hands to show held status
	for mini in _extra_displays:
		_show_mini_held(mini)


# --- Card path helper ---

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

func _get_card_path(card: CardData) -> String:
	if card.is_joker():
		return "res://assets/cards/card_vp_joker_red.png"
	if _variant.is_wild_card(card) and card.rank == CardData.Rank.TWO:
		var s: String = SUIT_CODES.get(card.suit, "")
		return "res://assets/cards/card_vp_wild%s.png" % s
	var r: String = RANK_CODES.get(card.rank, "")
	var s: String = SUIT_CODES.get(card.suit, "")
	return "res://assets/cards/card_vp_%s%s.png" % [r, s]


# --- Bet picker ---

func _on_bet_amount_pressed() -> void:
	if _manager.state != MultiHandManager.State.IDLE and _manager.state != MultiHandManager.State.WIN_DISPLAY:
		return
	_show_bet_picker()

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
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
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

	var tex_y := load("res://assets/textures/btn_rect_yellow.svg")
	for amount in BET_AMOUNTS:
		var btn := Button.new()
		btn.text = ""
		_style_btn(btn, tex_y, COL_BTN_TEXT, 18, 120, 44)
		var cd := SaveManager.create_currency_display(16, COL_BTN_TEXT)
		cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		SaveManager.set_currency_value(cd, SaveManager.format_short(amount))
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


# --- Shop popup ---

const SHOP_AMOUNTS := [100, 500, 2500, 10000, 50000, 100000]
var _shop_overlay: Control = null

func _show_shop() -> void:
	if _shop_overlay:
		_shop_overlay.queue_free()
		_shop_overlay = null

	_shop_overlay = Control.new()
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shop_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_shop()
	)
	_shop_overlay.add_child(dim)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("000086")
	panel_style.set_border_width_all(3)
	panel_style.border_color = COL_YELLOW
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_shop_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "GET CHIPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_YELLOW)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	var tex_green := load("res://assets/textures/btn_rect_green.svg")

	for amount in SHOP_AMOUNTS:
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 6)

		var cl := SaveManager.create_currency_display(22, Color.WHITE)
		SaveManager.set_currency_value(cl, SaveManager.format_short(amount))
		cl["box"].alignment = BoxContainer.ALIGNMENT_CENTER
		item.add_child(cl["box"])

		var buy_btn := Button.new()
		buy_btn.text = "FREE"
		_style_btn(buy_btn, tex_green, Color.WHITE, 16, 120, 36)
		buy_btn.pressed.connect(_on_shop_buy.bind(amount))
		item.add_child(buy_btn)

		grid.add_child(item)


func _on_shop_buy(amount: int) -> void:
	SaveManager.add_credits(amount)
	_update_balance(SaveManager.credits)
	_hide_shop()


func _hide_shop() -> void:
	if _shop_overlay:
		_shop_overlay.queue_free()
		_shop_overlay = null


# --- Primary hand result overlay ---

var _primary_result_overlay: PanelContainer = null

func _show_primary_result(hand_name: String, multiplier: int) -> void:
	_hide_primary_result()
	_primary_result_overlay = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.15, 0.85)
	style.set_border_width_all(2)
	style.border_color = COL_YELLOW
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_primary_result_overlay.add_theme_stylebox_override("panel", style)
	_primary_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = "%s\nX%d" % [hand_name, multiplier]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COL_YELLOW)
	_primary_result_overlay.add_child(label)

	add_child(_primary_result_overlay)
	await get_tree().process_frame
	var cards_rect := _primary_container.get_global_rect()
	var center := cards_rect.get_center()
	var sz := _primary_result_overlay.get_combined_minimum_size()
	_primary_result_overlay.position = Vector2(center.x - sz.x / 2, center.y - sz.y / 2)


func _get_badge_color_for_hand(hand_name: String, hand_keys: Array[String]) -> Color:
	# Match hand_name (uppercase) to paytable key's display name
	for idx in hand_keys.size():
		var display := hand_keys[idx].replace("_", " ").to_upper()
		if display == hand_name:
			return BADGE_COLORS[mini(idx, BADGE_COLORS.size() - 1)]
	return Color("FFEC00")


func _hide_primary_result() -> void:
	if _primary_result_overlay:
		_primary_result_overlay.queue_free()
		_primary_result_overlay = null


# --- Paytable side badges ---

const BADGE_COLORS := [
	Color("FFEC00"),  # 0  Royal Flush / top hand — gold
	Color("00BFFF"),  # 1  Straight Flush — cyan
	Color("FF44FF"),  # 2  4 Aces w/ kicker — magenta
	Color("4488FF"),  # 3  4 Aces — blue
	Color("BB44FF"),  # 4  4 2-4 w/ kicker — purple
	Color("FF8800"),  # 5  4 2-4 / Four of a Kind — orange
	Color("44DD44"),  # 6  4 5-K / Full House — green
	Color("FF4444"),  # 7  Flush — red
	Color("44BBAA"),  # 8  Straight — teal
	Color("88FF44"),  # 9  Three of a Kind — lime
	Color("5599FF"),  # 10 Two Pair — light blue
	Color("CC8844"),  # 11 Jacks or Better — copper
	Color("AA66CC"),  # 12 Kings or Better — lavender
]

var _left_badges: VBoxContainer = null
var _right_badges: VBoxContainer = null
var _badge_labels: Array[Label] = []
var _badge_hand_keys: Array[String] = []

func _build_paytable_badges() -> void:
	_clear_paytable_badges()

	var hand_keys := _variant.paytable.get_hand_order()
	var total: int = hand_keys.size()
	# Split evenly: left gets ceil, right gets floor
	var left_count: int = ceili(total / 2.0)
	var right_count: int = total - left_count

	# Create left column
	_left_badges = VBoxContainer.new()
	_left_badges.add_theme_constant_override("separation", 4)
	_left_badges.alignment = BoxContainer.ALIGNMENT_BEGIN
	_left_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_badges)

	# Create right column
	_right_badges = VBoxContainer.new()
	_right_badges.add_theme_constant_override("separation", 4)
	_right_badges.alignment = BoxContainer.ALIGNMENT_BEGIN
	_right_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_badges)

	_badge_labels.clear()
	_badge_hand_keys.clear()

	var bet_idx: int = clampi(_manager.bet - 1, 0, 4)

	# Left: top entries (most expensive first)
	for i in left_count:
		var key: String = hand_keys[i]
		var row := _variant.paytable.get_payout_row(key)
		var mult: int = int(row[bet_idx]) if bet_idx < row.size() else 0
		var color_idx: int = mini(i, BADGE_COLORS.size() - 1)
		var badge := _make_badge(
			_variant.paytable.get_hand_display_name(key),
			mult, BADGE_COLORS[color_idx]
		)
		_left_badges.add_child(badge)
		_badge_labels.append(badge.get_child(0) as Label)
		_badge_hand_keys.append(key)

	# Right: remaining entries
	for i in right_count:
		var idx: int = left_count + i
		var key: String = hand_keys[idx]
		var row := _variant.paytable.get_payout_row(key)
		var mult: int = int(row[bet_idx]) if bet_idx < row.size() else 0
		var color_idx: int = mini(idx, BADGE_COLORS.size() - 1)
		var badge := _make_badge(
			_variant.paytable.get_hand_display_name(key),
			mult, BADGE_COLORS[color_idx]
		)
		_right_badges.add_child(badge)
		_badge_labels.append(badge.get_child(0) as Label)
		_badge_hand_keys.append(key)

	_position_badges.call_deferred()


func _position_badges() -> void:
	await get_tree().process_frame
	if not _extra_grid or not _left_badges or not _right_badges:
		return
	var grid_rect := _extra_grid.get_global_rect()
	var primary_rect := _primary_container.get_global_rect()
	var top_y: float = grid_rect.position.y
	var available_h: float = primary_rect.position.y - top_y

	var badge_w: float = 180.0

	# Left: right edge aligned to grid left, fixed width
	_left_badges.position = Vector2(grid_rect.position.x - badge_w - 8, top_y)
	_left_badges.size = Vector2(badge_w, available_h)

	# Right: left edge aligned to grid right, fixed width
	_right_badges.position = Vector2(grid_rect.end.x + 8, top_y)
	_right_badges.size = Vector2(badge_w, available_h)

	# Check if badges fit — shrink only if they overflow available height
	await get_tree().process_frame
	var left_min_h: float = _left_badges.get_combined_minimum_size().y
	var right_min_h: float = _right_badges.get_combined_minimum_size().y
	var max_min_h: float = maxf(left_min_h, right_min_h)
	if max_min_h > available_h:
		_shrink_badge_fonts()


func _shrink_badge_fonts() -> void:
	for label in _badge_labels:
		label.add_theme_font_size_override("font_size", 10)
	# Also reduce badge padding
	var all_badges: Array = []
	if _left_badges:
		all_badges.append_array(_left_badges.get_children())
	if _right_badges:
		all_badges.append_array(_right_badges.get_children())
	for badge in all_badges:
		if badge is PanelContainer:
			var style := badge.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.content_margin_top = 1
				style.content_margin_bottom = 1
	if _left_badges:
		_left_badges.add_theme_constant_override("separation", 2)
	if _right_badges:
		_right_badges.add_theme_constant_override("separation", 2)


func _make_badge(hand_name: String, multiplier: int, border_color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.2, 0.9)
	style.set_border_width_all(2)
	style.border_color = border_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", style)

	badge.custom_minimum_size.x = 170
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = "%s\nX%d" % [hand_name, multiplier]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	badge.add_child(label)
	return badge


func _update_paytable_badges() -> void:
	var bet_idx: int = clampi(_manager.bet - 1, 0, 4)
	for i in _badge_labels.size():
		var key: String = _badge_hand_keys[i]
		var row := _variant.paytable.get_payout_row(key)
		var mult: int = int(row[bet_idx]) if bet_idx < row.size() else 0
		var display_name: String = _variant.paytable.get_hand_display_name(key)
		_badge_labels[i].text = "%s\nX%d" % [display_name, mult]
		# Jackpot highlight: top hand at max bet
		if i == 0 and _manager.bet == 5:
			_badge_labels[i].add_theme_color_override("font_color", Color("FF4444"))
			var bold := SystemFont.new()
			bold.font_weight = 700
			_badge_labels[i].add_theme_font_override("font", bold)
		else:
			_badge_labels[i].add_theme_color_override("font_color", Color.WHITE)
			_badge_labels[i].remove_theme_font_override("font")


func _clear_paytable_badges() -> void:
	if _left_badges:
		_left_badges.queue_free()
		_left_badges = null
	if _right_badges:
		_right_badges.queue_free()
		_right_badges = null
