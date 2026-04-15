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
var _idle_blink_tween: Tween = null
var _idle_timer: SceneTreeTimer = null
var _balance_cd: Dictionary
var _balance_show_depth: bool = false
var _depth_tooltip: Control = null
var _bet_cd: Dictionary
var _win_cd: Dictionary
var _hold_hint_label: Label = null

# Primary hand (bottom row, interactive)
var _primary_cards: Array = []  # Array of card_visual TextureRect
var _primary_container: HBoxContainer
var _animating: bool = false
var _primary_win_mask: Array = [false, false, false, false, false]
var _double_btn: Button
var _double_amount: int = 0
var _double_warned: bool = false
var _in_double: bool = false
var _double_cards: Array = []
var _double_dealer_card: CardData = null
var _info_card: PanelContainer
var _info_card_active_label: Label
var _info_btn: Button
var _info_overlay: Control
# Per-hand multiplier safe zones (index 0 = primary, 1+ = extras)
var _mult_zones: Array[Control] = []
var _next_displays: Array[Control] = []
var _active_displays: Array[Control] = []
# Rows that were temporarily detached from a NEXT VBox during animation and
# reparented to self — tracked here so we can always clean them up, even if
# a previous animation was interrupted.
var _anim_detached_rows: Array[Control] = []
# State persistence: key = "{hand_count}_{bet}" → {hand_multipliers, next_multipliers}
var _ux_states: Dictionary = {}

# Extra hands (above primary, non-interactive mini displays)
var _extra_displays: Array = []  # Array of MiniHandDisplay

# Colors
const COL_YELLOW := Color("FFEC00")
const COL_GREEN := Color("07E02F")
const COL_BTN_TEXT := Color("3F2A00")

# Ultra VP multiplier glyph sizes.
# NEXT is small (it's a hint for the upcoming round), ACTIVE is big (it's the
# current round's "star" — dominant visual). Animation pins the label's value
# row bottom to the hand's bottom both before and after the size jump.
const UX_ACTIVE_H_PRIMARY := 44.0
const UX_ACTIVE_H_EXTRA := 34.0
const UX_NEXT_VAL_H_PRIMARY := 26.0
const UX_NEXT_VAL_H_EXTRA := 22.0
const UX_NEXT_HDR_H_PRIMARY := 26.0
const UX_NEXT_HDR_H_EXTRA := 22.0
# Bottom margin of ACTIVE row inside its zone.
const UX_ACTIVE_BOTTOM_MARGIN := 6.0
# Horizontal gap between the multiplier label's right edge and the left edge
# of the first card of its hand. Keep it small — the label should sit snug.
const UX_LABEL_RIGHT_GAP := 2.0

# Speed
var _speed_level: int = 1
const SPEED_CONFIGS := [
	{"deal_ms": 150, "draw_ms": 200, "flip_s": 0.15},
	{"deal_ms": 100, "draw_ms": 140, "flip_s": 0.12},
	{"deal_ms": 60,  "draw_ms": 80,  "flip_s": 0.08},
	{"deal_ms": 30,  "draw_ms": 40,  "flip_s": 0.05},
]

# Bet picker — from config
var BET_AMOUNTS: Array = []
var _current_denomination: int = 1
var _bet_picker_overlay: Control = null


var _ultra_vp: bool = false

func setup(variant: BaseVariant, num_hands: int, p_ultra_vp: bool = false) -> void:
	_variant = variant
	_num_hands = num_hands
	_ultra_vp = p_ultra_vp


func _ready() -> void:
	if _variant == null:
		return
	# Determine mode for denomination config
	var mode_id := "five_play"
	match _num_hands:
		1: mode_id = "single_play"
		3: mode_id = "triple_play"
		5: mode_id = "ultra_vp" if _ultra_vp else "five_play"
		10: mode_id = "ten_play"
		_: mode_id = "five_play"
	BET_AMOUNTS = ConfigManager.get_denominations(mode_id)
	var shop_items := ConfigManager.get_shop_items()
	for si in shop_items:
		SHOP_AMOUNTS.append(int(si.get("chips", 0) + si.get("bonus_chips", 0)))
	if SHOP_AMOUNTS.size() == 0:
		SHOP_AMOUNTS = [100, 500, 2500, 10000, 50000, 100000]

	CardScene = load("res://scenes/card.tscn")
	MiniHandScene = load("res://scenes/mini_hand.tscn")

	_manager = MultiHandManager.new()
	add_child(_manager)
	_manager.setup(_variant, _num_hands, _ultra_vp)

	# Connect signals
	_manager.all_hands_dealt.connect(_on_hands_dealt)
	_manager.all_hands_drawn.connect(_on_hands_drawn)
	_manager.all_hands_evaluated.connect(_on_hands_evaluated)
	_manager.credits_changed.connect(_on_credits_changed)
	_manager.bet_changed.connect(_on_bet_changed)
	_manager.state_changed.connect(_on_state_changed)

	# Double button
	_double_btn = Button.new()
	_double_btn.text = Translations.tr_key("game.double")
	_double_btn.disabled = true
	_double_btn.pressed.connect(_on_double_pressed)

	# Info button
	_info_btn = Button.new()
	_info_btn.text = "i"
	_info_btn.pressed.connect(_show_info)

	# Buttons
	_back_btn.pressed.connect(_on_back_pressed)
	_speed_btn.pressed.connect(_on_speed_pressed)
	_bet_btn.pressed.connect(_on_bet_one_pressed)
	_bet_amount_btn.pressed.connect(_on_bet_amount_pressed)
	_bet_max_btn.pressed.connect(_on_bet_max_pressed)
	_deal_draw_btn.pressed.connect(_on_deal_draw_pressed)
	_hands_btn.pressed.connect(_on_hands_pressed)
	_topup_btn.pressed.connect(_show_shop)
	# Rush detection — catch any click/tap during animations

	_speed_level = SaveManager.speed_level
	_apply_theme()
	_build_hands_area()
	_build_paytable_badges()
	_update_speed_display()

	_update_title()
	_hands_btn.text = Translations.tr_key("game.hands_n_fmt", [_num_hands])
	_current_denomination = _recommend_denomination()
	SaveManager.denomination = _current_denomination
	_update_bet_amount_btn()
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)
	_bet_btn.text = Translations.tr_key("game.bet_one_fmt", [_manager.bet])
	_win_label.text = Translations.tr_key("game.win_label")


func _setup_background() -> void:
	var bg: Control = %Background

	# Layer 1: Linear gradient TOP to BOTTOM — dark emerald → deep forest
	var linear_grad := GradientTexture2D.new()
	var lg := Gradient.new()
	lg.offsets = PackedFloat32Array([0.0, 1.0])
	lg.colors = PackedColorArray([Color("0A3D2A"), Color("062015")])
	linear_grad.gradient = lg
	linear_grad.fill = GradientTexture2D.FILL_LINEAR
	linear_grad.fill_from = Vector2(0.5, 0.0)
	linear_grad.fill_to = Vector2(0.5, 1.0)
	linear_grad.width = 512
	linear_grad.height = 512

	var linear_rect := TextureRect.new()
	linear_rect.texture = linear_grad
	linear_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	linear_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	linear_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg.add_child(linear_rect)

	# Layer 2: Radial gradient for Ultra VP — light green glow → transparent edge
	# Other modes — dark green vignette
	var radial_grad := GradientTexture2D.new()
	var rg := Gradient.new()
	if _ultra_vp:
		rg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		rg.colors = PackedColorArray([
			Color("5FD88A"),      # light green center
			Color(0.37, 0.84, 0.54, 0.4),  # fade
			Color(0.37, 0.84, 0.54, 0),    # transparent edge
		])
	else:
		rg.offsets = PackedFloat32Array([0.0, 0.54, 0.71, 0.89, 1.0])
		rg.colors = PackedColorArray([
			Color(0, 0, 0, 0),
			Color(0, 0, 0, 0),
			Color(0, 0.05, 0.02, 0.67),
			Color("021C0E"),
			Color("021C0E"),
		])
	radial_grad.gradient = rg
	radial_grad.fill = GradientTexture2D.FILL_RADIAL
	radial_grad.fill_from = Vector2(0.5, 0.5)
	radial_grad.fill_to = Vector2(1.0, 1.0)
	radial_grad.width = 512
	radial_grad.height = 512

	var radial_rect := TextureRect.new()
	radial_rect.texture = radial_grad
	radial_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	radial_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	radial_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg.add_child(radial_rect)


func _apply_theme() -> void:
	_setup_background()
	$VBoxContainer.add_theme_constant_override("separation", 2)

	# Back button — exit icon, aligned with controlbar
	TopBarBuilder.style_exit_button(_back_btn)

	_game_title.add_theme_font_size_override("font_size", 20)
	_game_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))

	# Hands area
	_hands_area.add_theme_constant_override("separation", 4)
	_hands_area.alignment = BoxContainer.ALIGNMENT_END

	# --- Bottom section ---
	_bottom_section.add_theme_constant_override("separation", 2)

	# Info row: [WIN chip_val | TOTAL BET chip_val] ... [BALANCE chip_val | +]
	_info_row.add_theme_constant_override("separation", 10)
	# Wrap info row in margin container (same side margins as bottom bar)
	var ir_parent := _info_row.get_parent()
	var ir_idx := _info_row.get_index()
	var ir_margin := MarginContainer.new()
	ir_margin.add_theme_constant_override("margin_left", 100)
	ir_margin.add_theme_constant_override("margin_right", 100)
	ir_parent.remove_child(_info_row)
	ir_margin.add_child(_info_row)
	ir_parent.add_child(ir_margin)
	ir_parent.move_child(ir_margin, ir_idx)
	_win_label.add_theme_font_size_override("font_size", 16)
	_win_label.add_theme_color_override("font_color", Color.WHITE)
	_win_label.text = Translations.tr_key("game.win_label")
	_win_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_label.gui_input.connect(_on_credits_toggle)
	_win_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_win_cd["box"].mouse_filter = Control.MOUSE_FILTER_STOP
	_win_cd["box"].gui_input.connect(_on_credits_toggle)
	_info_row.add_child(_win_cd["box"])
	_info_row.move_child(_win_cd["box"], _win_label.get_index() + 1)
	SaveManager.set_currency_value(_win_cd, "0")
	_total_bet_label.add_theme_font_size_override("font_size", 16)
	_total_bet_label.add_theme_color_override("font_color", Color.WHITE)
	_total_bet_label.text = Translations.tr_key("game.total_bet")
	_total_bet_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_total_bet_label.gui_input.connect(_on_credits_toggle)
	_bet_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_info_row.add_child(_bet_cd["box"])
	_info_row.move_child(_bet_cd["box"], _total_bet_label.get_index() + 1)
	_balance_label.add_theme_font_size_override("font_size", 16)
	_balance_label.add_theme_color_override("font_color", Color.WHITE)
	_balance_label.text = Translations.tr_key("game.balance")
	_balance_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_balance_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_balance_label.gui_input.connect(_on_credits_toggle)
	_balance_cd = SaveManager.create_currency_display(16, COL_YELLOW)
	_balance_cd["box"].mouse_filter = Control.MOUSE_FILTER_STOP
	_balance_cd["box"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_balance_cd["box"].gui_input.connect(_on_credits_toggle)
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

	# Button bar — flat, grouped with spacers, with side margins like single-hand
	_bottom_bar.add_theme_constant_override("separation", 0)
	var bb_parent := _bottom_bar.get_parent()
	var bb_idx := _bottom_bar.get_index()
	var bb_margin := MarginContainer.new()
	bb_margin.add_theme_constant_override("margin_left", 100)
	bb_margin.add_theme_constant_override("margin_right", 100)
	bb_parent.remove_child(_bottom_bar)
	bb_margin.add_child(_bottom_bar)
	bb_parent.add_child(bb_margin)
	bb_parent.move_child(bb_margin, bb_idx)
	_build_button_groups.call_deferred()

	# Button textures
	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg")
	var tex_panel := load("res://assets/textures/btn_panel11.svg")
	var tex_panel_w := load("res://assets/textures/btn_panel11-1.svg")
	var tex_green := load("res://assets/textures/btn_rect_green.svg")
	var tex_blue := load("res://assets/textures/btn_blue.svg")
	var tex_gray := load("res://assets/textures/btn_panel11.svg")

	var btn_h := 36

	# Left group: INFO + SPEED
	var tex_info := load("res://assets/textures/info_button.svg")
	_style_btn(_info_btn, tex_info, Color.BLACK, 16, 40, btn_h)
	_style_btn(_speed_btn, tex_panel_w, Color.WHITE, 13, 110, btn_h)

	# Center group: HANDS, $amount, BET, BET MAX
	_style_btn(_hands_btn, tex_panel, Color.WHITE, 14, 100, btn_h)
	_style_btn(_bet_amount_btn, tex_blue, Color.WHITE, 16, 120, btn_h)
	_style_btn(_bet_btn, tex_yellow, COL_BTN_TEXT, 14, 80, btn_h)
	_style_btn(_bet_max_btn, tex_yellow, COL_BTN_TEXT, 14, 100, btn_h)
	_bet_max_btn.text = Translations.tr_key("game.bet_max")

	# Right group: DOUBLE + DEAL
	_style_btn(_double_btn, tex_yellow, COL_BTN_TEXT, 13, 90, btn_h)
	_style_btn(_deal_draw_btn, tex_green, Color.WHITE, 18, 120, btn_h)


func _build_button_groups() -> void:
	# [INFO] [SPEED] [spacer] [HANDS] [$amt] [BET] [BET MAX] [spacer] [DOUBLE] [DEAL]
	_bottom_bar.add_child(_info_btn)
	_bottom_bar.move_child(_info_btn, _speed_btn.get_index())
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_l.custom_minimum_size.x = 4
	_bottom_bar.add_child(spacer_l)
	_bottom_bar.move_child(spacer_l, _speed_btn.get_index() + 1)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_r.custom_minimum_size.x = 4
	_bottom_bar.add_child(spacer_r)
	_bottom_bar.move_child(spacer_r, _bet_max_btn.get_index() + 1)
	# DOUBLE button before DEAL
	_bottom_bar.add_child(_double_btn)
	_bottom_bar.move_child(_double_btn, _deal_draw_btn.get_index())


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
	# 1.2: Press effect
	btn.pivot_offset = btn.size / 2
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.05)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	)


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
	_extra_grid.add_theme_constant_override("h_separation", 20 if _ultra_vp else 16)
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

	# Ultra VP: clear mult zones arrays (will be populated in order: primary first, then extras)
	if _ultra_vp:
		_clear_mult_zones()

	# Build primary zone FIRST so it's at index 0
	if _ultra_vp:
		_build_mult_zone(80, true)  # zone added to primary_container below

	for i in num_extra:
		var mh: MiniHandDisplay = MiniHandScene.instantiate()
		mh._variant = _variant
		mh._overlay_parent = self
		if _ultra_vp:
			# Wrap in HBox with mult zone on the left
			var wrap := HBoxContainer.new()
			wrap.add_theme_constant_override("separation", 4)
			var zone := _build_mult_zone(60, false)
			wrap.add_child(zone)
			wrap.add_child(mh)
			_extra_grid.add_child(wrap)
		else:
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

	# Ultra VP: add the previously built primary mult zone to primary_container FIRST (left side)
	if _ultra_vp and _mult_zones.size() > 0:
		_primary_container.add_child(_mult_zones[0])
		_primary_container.move_child(_mult_zones[0], 0)

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

	# Info card (Ultra VP only) — right of primary hand
	if _ultra_vp:
		_build_info_card()
		_update_multiplier_labels.call_deferred()


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


# --- Hand count cycling ---

const HAND_COUNTS := [3, 5, 10, 12, 25]
const UX_HAND_COUNTS := [3, 5, 10]
var _switching_hands: bool = false

func _on_hands_pressed() -> void:
	if _manager.state != MultiHandManager.State.IDLE and _manager.state != MultiHandManager.State.WIN_DISPLAY:
		return
	if _switching_hands:
		return
	if _manager.state == MultiHandManager.State.WIN_DISPLAY:
		_manager._to_idle()
	# Cycle to next hand count
	var counts: Array = UX_HAND_COUNTS if _ultra_vp else HAND_COUNTS
	var current_idx := counts.find(_num_hands)
	var next_idx := (current_idx + 1) % counts.size() if current_idx >= 0 else 0
	var new_count: int = counts[next_idx]
	_switch_hand_count(new_count)


func _switch_hand_count(new_count: int) -> void:
	_switching_hands = true
	# Save current UX state before switching
	_save_ux_state()

	# 1. Animate out: bounce → shrink → fade
	if _extra_grid:
		_extra_grid.pivot_offset = _extra_grid.size / 2
		var tw_out := create_tween()
		tw_out.tween_property(_extra_grid, "scale", Vector2(1.05, 1.05), 0.05).set_ease(Tween.EASE_OUT)
		tw_out.tween_property(_extra_grid, "scale", Vector2(0.15, 0.15), 0.15).set_ease(Tween.EASE_IN)
		tw_out.parallel().tween_property(_extra_grid, "modulate:a", 0.0, 0.12).set_delay(0.06)
		await tw_out.finished

	# 2. Remove old
	_stop_result_blink()
	for mini in _extra_displays:
		mini.hide_result()
	_extra_displays.clear()
	if _extra_grid:
		_extra_grid.get_parent().remove_child(_extra_grid)
		_extra_grid.free()
		_extra_grid = null

	# 3. Update state
	_num_hands = new_count
	SaveManager.hand_count = new_count
	SaveManager.save_game()
	_hands_btn.text = Translations.tr_key("game.hands_n_fmt", [_num_hands])
	_manager.setup(_variant, _num_hands, _ultra_vp)
	# Load saved UX state for new hand count
	_load_ux_state()

	# 4. Build new grid (invisible)
	var extra_rect: Control = %ExtraHandsRect
	_extra_grid = GridContainer.new()
	_extra_grid.set_anchors_preset(Control.PRESET_CENTER)
	_extra_grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_extra_grid.grow_vertical = Control.GROW_DIRECTION_BOTH
	_extra_grid.columns = _get_grid_cols()
	_extra_grid.add_theme_constant_override("h_separation", 20 if _ultra_vp else 16)
	_extra_grid.add_theme_constant_override("v_separation", 10)
	_extra_grid.modulate.a = 0.0
	extra_rect.add_child(_extra_grid)

	# Ultra VP: keep primary zone/labels (index 0), remove old extra zones/labels.
	# NOTE: the zones in _mult_zones[1..] were children of the extra_grid and
	# are already freed by _extra_grid.free() above — so their references here
	# are dangling. We must NOT assign them to typed variables (that throws
	# "Trying to assign invalid previously freed instance" in Godot 4).
	if _ultra_vp:
		while _mult_zones.size() > 1:
			_mult_zones.pop_back()  # already freed with the grid
		while _next_displays.size() > 1:
			var d = _next_displays.pop_back()  # untyped — might be freed
			if is_instance_valid(d):
				(d as Node).queue_free()
		while _active_displays.size() > 1:
			var d = _active_displays.pop_back()  # untyped — might be freed
			if is_instance_valid(d):
				(d as Node).queue_free()

	for i in (_num_hands - 1):
		var mh: MiniHandDisplay = MiniHandScene.instantiate()
		mh._variant = _variant
		mh._overlay_parent = self
		if _ultra_vp:
			var wrap := HBoxContainer.new()
			wrap.add_theme_constant_override("separation", 4)
			var zone := _build_mult_zone(60, false)
			wrap.add_child(zone)
			wrap.add_child(mh)
			_extra_grid.add_child(wrap)
		else:
			_extra_grid.add_child(mh)
		_extra_displays.append(mh)
		mh.show_back()

	# 5. Wait for layout, then size
	await get_tree().process_frame
	await get_tree().process_frame
	_size_extra_hands()

	# 6. Update displays
	_update_paytable_badges()
	_current_denomination = _recommend_denomination()
	SaveManager.denomination = _current_denomination
	_update_bet_amount_btn()
	_update_bet_display(_manager.bet)
	_update_balance(SaveManager.credits)

	# 7. Animate in: fade + grow → bounce settle
	_extra_grid.pivot_offset = _extra_grid.size / 2
	_extra_grid.scale = Vector2(0.15, 0.15)
	_extra_grid.modulate.a = 0.0
	var tw_in := create_tween()
	# Fade in first
	tw_in.tween_property(_extra_grid, "modulate:a", 1.0, 0.084)
	# Grow from depth (parallel, slightly delayed)
	tw_in.parallel().tween_property(_extra_grid, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT).set_delay(0.03)
	# Bounce settle
	tw_in.tween_property(_extra_grid, "scale", Vector2(1.0, 1.0), 0.06).set_ease(Tween.EASE_IN_OUT)
	await tw_in.finished

	# Refresh multiplier labels for new layout
	if _ultra_vp:
		_update_multiplier_labels()

	_switching_hands = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == MultiHandManager.State.DRAWING or _manager.state == MultiHandManager.State.DEALING:
			_rush_round = true


func _is_rushing() -> bool:
	return _rush_round or _is_instant()


# --- Display helpers ---

func _update_balance(credits: int) -> void:
	if _balance_show_depth:
		var cr := _calculate_credits()
		_balance_label.text = Translations.tr_key("game.games")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(cr), 0, Color(-1, 0, 0), false)
	else:
		_balance_label.text = Translations.tr_key("game.balance")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(credits), 0, Color(-1, 0, 0), true)


func _calculate_credits() -> int:
	var denom: int = maxi(SaveManager.denomination, 1)
	return SaveManager.credits / denom


func _calculate_game_depth() -> int:
	var ux_active := _ultra_vp and _manager.bet == MultiHandManager.ULTRA_BET
	var bet_mult := 2 if ux_active else 1
	var per_round: int = _manager.bet * _num_hands * SaveManager.denomination * bet_mult
	if per_round <= 0:
		return 0
	return SaveManager.credits / per_round


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
	if _win_cd["box"].visible:
		var win_val: int = _double_amount if _double_amount > 0 else 0
		if _balance_show_depth:
			SaveManager.set_currency_value(_win_cd, str(win_val / maxi(SaveManager.denomination, 1)), 0, Color(-1, 0, 0), false)
		else:
			if win_val > 0:
				SaveManager.set_currency_value(_win_cd, SaveManager.format_short(win_val))
			else:
				SaveManager.set_currency_value(_win_cd, "0")


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
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
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
	var total: int = bet * _num_hands * SaveManager.denomination
	if _balance_show_depth:
		var credits_total: int = bet * _num_hands
		SaveManager.set_currency_value(_bet_cd, str(credits_total), 0, Color(-1, 0, 0), false)
	else:
		SaveManager.set_currency_value(_bet_cd, SaveManager.format_short(total))
		_flash_bet_display()
	# Refresh multiplier display when bet changes
	if _ultra_vp:
		_refresh_ux_visibility()


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
	var max_bet: int = MultiHandManager.ULTRA_BET if _ultra_vp else MultiHandManager.MAX_BET
	for amount in BET_AMOUNTS:
		# worst case total_bet = denomination * max_bet * num_hands
		if balance / (amount * max_bet * _num_hands) >= MIN_GAME_DEPTH:
			best = amount
		else:
			break
	return best


var _bet_btn_cd: Dictionary

func _update_bet_amount_btn() -> void:
	_bet_amount_btn.text = ""
	_bet_amount_btn.icon = null
	if _bet_btn_cd.is_empty():
		_bet_btn_cd = SaveManager.create_currency_display(18, Color.WHITE)
		_bet_btn_cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bet_btn_cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		_bet_amount_btn.add_child(_bet_btn_cd["box"])
	SaveManager.set_currency_value(_bet_btn_cd, SaveManager.format_auto(_current_denomination, 96, 18))





# --- State changes ---

func _on_state_changed(new_state: int) -> void:
	match new_state:
		MultiHandManager.State.IDLE:
			_deal_draw_btn.text = Translations.tr_key("game.deal")
			_bet_btn.disabled = false
			_bet_max_btn.disabled = false
			_deal_draw_btn.disabled = false
			_hands_btn.disabled = false
			_bet_amount_btn.disabled = false
			_double_btn.disabled = true
			_in_double = false
			_win_label.text = Translations.tr_key("game.win_label")
			_win_cd["box"].visible = true
			SaveManager.set_currency_value(_win_cd, "0")
			_win_label.add_theme_color_override("font_color", Color.WHITE)
			for card in _primary_cards:
				card.set_interactive(false)
			_start_idle_blink_timer()

		MultiHandManager.State.DEALING:
			_hide_hold_hint()
			_stop_idle_blink()
			_deal_draw_btn.disabled = true
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_bet_amount_btn.disabled = true
			_bet_amount_btn.modulate.a = 0.5
			_hands_btn.disabled = true
			_double_btn.disabled = true
			_win_label.text = Translations.tr_key("game.win_label")
			_win_cd["box"].visible = true
			SaveManager.set_currency_value(_win_cd, "0")

		MultiHandManager.State.HOLDING:
			_deal_draw_btn.text = Translations.tr_key("game.draw")
			_deal_draw_btn.disabled = false
			_win_label.text = ""
			for i in _primary_cards.size():
				_primary_cards[i].set_interactive(true)
				if _manager.held[i]:
					_primary_cards[i].set_held(true)
			# Show held cards in extra hands, backs for non-held
			for mini in _extra_displays:
				_show_mini_held(mini)

		MultiHandManager.State.DRAWING:
			_hide_hold_hint()
			_deal_draw_btn.disabled = true
			for card in _primary_cards:
				card.set_interactive(false)

		MultiHandManager.State.WIN_DISPLAY:
			_deal_draw_btn.text = Translations.tr_key("game.deal")
			_deal_draw_btn.disabled = true
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			_hands_btn.disabled = false


func _show_hold_hint() -> void:
	_hide_hold_hint()
	_hold_hint_label = Label.new()
	_hold_hint_label.text = Translations.tr_key("game.hold_cards_then_draw")
	_hold_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_hint_label.add_theme_font_size_override("font_size", 18)
	_hold_hint_label.add_theme_color_override("font_color", COL_YELLOW)
	var bold := SystemFont.new()
	bold.font_weight = 700
	_hold_hint_label.add_theme_font_override("font", bold)
	_hold_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_hint_label.z_index = 20
	add_child(_hold_hint_label)
	_position_hold_hint.call_deferred()


func _position_hold_hint() -> void:
	if not _hold_hint_label or not is_instance_valid(_hold_hint_label):
		return
	await get_tree().process_frame
	if not _primary_container or not is_instance_valid(_primary_container):
		return
	var rect := _primary_container.get_global_rect()
	var lbl_size := _hold_hint_label.get_combined_minimum_size()
	_hold_hint_label.global_position = Vector2(
		rect.get_center().x - lbl_size.x / 2,
		rect.position.y - lbl_size.y - 8
	)


func _hide_hold_hint() -> void:
	if _hold_hint_label and is_instance_valid(_hold_hint_label):
		_hold_hint_label.queue_free()
	_hold_hint_label = null


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
			VibrationManager.vibrate("card_deal")
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
	VibrationManager.vibrate("button_press")
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
		if _manager.state == MultiHandManager.State.IDLE or _manager.state == MultiHandManager.State.WIN_DISPLAY:
			var cost: int = _manager.bet * _num_hands * SaveManager.denomination
			if cost > SaveManager.credits:
				_flash_balance_red()
				_show_shop()
				return
		# Starting new round — animate NEXT → ACTIVE first (Ultra VP)
		if _ultra_vp and _manager.bet == MultiHandManager.ULTRA_BET:
			_animating = true
			_deal_draw_btn.disabled = true
			_bet_btn.disabled = true
			_bet_max_btn.disabled = true
			await _animate_multipliers_next_to_active()
			_animating = false
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
				VibrationManager.vibrate("card_deal")
				await get_tree().create_timer(delay).timeout

	# 1b. Show primary hand result immediately (don't wait for extra hands)
	var hand_keys := _variant.paytable.get_hand_order()
	var ux_active := _ultra_vp and _manager.bet == MultiHandManager.ULTRA_BET
	var p_rank := _variant.evaluate(primary)
	var p_base: int = _variant.get_payout(p_rank, _manager.bet)
	_primary_win_mask = [false, false, false, false, false]
	if p_base > 0:
		var p_name: String = _variant.get_hand_name(p_rank)
		var p_badge_color := _get_badge_color_for_hand(p_name, hand_keys)
		var p_active_m: int = 1
		if _ultra_vp and _manager.hand_multipliers.size() > 0:
			p_active_m = _manager.hand_multipliers[0]
		_show_primary_result(p_name, p_base, p_badge_color, p_active_m)
		_primary_win_mask = _variant.get_hold_mask(primary, p_rank)
	# Primary-hand cards are NEVER dimmed (unlike extras). Always full brightness.
	for ci in 5:
		_primary_cards[ci].modulate = Color.WHITE
	# Ultra VP: show NEXT multiplier for primary hand immediately
	if ux_active:
		var p_earned := MultiHandManager.get_ultra_vp_multiplier(p_rank)
		_manager.next_multipliers[0] = p_earned
		_show_single_next_multiplier(0, p_earned)

	# 2. Extra hands bottom-to-top, each hand card by card
	var cols: int = _get_grid_cols()
	var num_extra: int = _extra_displays.size()
	var rows_count: int = ceili(float(num_extra) / cols)
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
				var base_mult: int = _variant.get_payout(hand_rank, _manager.bet)
				var badge_color := _get_badge_color_for_hand(hand_name, hand_keys)
				var active_m: int = 1
				if _ultra_vp and (idx + 1) < _manager.hand_multipliers.size():
					active_m = _manager.hand_multipliers[idx + 1]
				mini.show_result(hand_name, base_mult, badge_color, active_m)
				mini.set_win_mask(_variant.get_hold_mask(hand, hand_rank))
			else:
				mini.show_result("", 0, Color.TRANSPARENT)
				mini.set_win_mask([false, false, false, false, false])
			# Ultra VP: show NEXT multiplier for this hand immediately
			if ux_active:
				var earned := MultiHandManager.get_ultra_vp_multiplier(hand_rank)
				_manager.next_multipliers[h] = earned
				_show_single_next_multiplier(h, earned)
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
	# Extra hand results + NEXT multipliers already shown during draw animation
	_start_result_blink()

	# Primary hand result already shown during draw animation (in _on_hands_drawn)

	# Show total win + animate credits
	if total_payout > 0:
		VibrationManager.vibrate("win_small")
		_win_label.text = Translations.tr_key("game.win_label")
		if _balance_show_depth:
			var win_cr: int = total_payout / maxi(SaveManager.denomination, 1)
			SaveManager.set_currency_value(_win_cd, str(win_cr), 0, Color(-1, 0, 0), false)
		else:
			SaveManager.set_currency_value(_win_cd, SaveManager.format_short(total_payout))
		_win_cd["box"].visible = true
		_win_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		_win_label.text = Translations.tr_key("game.no_win")
		_win_cd["box"].visible = false
		_win_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
		_delay_unlock_buttons()


func _ux_state_key() -> String:
	return "%d_%d_%d" % [_num_hands, _manager.bet, SaveManager.denomination]


func _save_ux_state() -> void:
	if not _ultra_vp:
		return
	_ux_states[_ux_state_key()] = {
		"hand_multipliers": _manager.hand_multipliers.duplicate(),
		"next_multipliers": _manager.next_multipliers.duplicate(),
	}


func _load_ux_state() -> void:
	if not _ultra_vp:
		return
	var key := _ux_state_key()
	if key in _ux_states:
		var st: Dictionary = _ux_states[key]
		var saved_hand: Array = st["hand_multipliers"]
		var saved_next: Array = st["next_multipliers"]
		_manager.hand_multipliers.clear()
		_manager.next_multipliers.clear()
		for i in _num_hands:
			_manager.hand_multipliers.append(saved_hand[i] if i < saved_hand.size() else 1)
			_manager.next_multipliers.append(saved_next[i] if i < saved_next.size() else 1)
	else:
		# No saved state — reset
		_manager.hand_multipliers.clear()
		_manager.next_multipliers.clear()
		for i in _num_hands:
			_manager.hand_multipliers.append(1)
			_manager.next_multipliers.append(1)


var _info_pulse_tween: Tween = null

func _update_info_card_status() -> void:
	if not _info_card_active_label:
		return
	var ux_active := _manager.bet == MultiHandManager.ULTRA_BET
	if ux_active:
		_info_card_active_label.text = Translations.tr_key("info_card.active")
		_info_card_active_label.add_theme_color_override("font_color", Color("07E02F"))
		_start_info_pulse()
	else:
		_info_card_active_label.text = Translations.tr_key("info_card.press_to_activate")
		_info_card_active_label.add_theme_color_override("font_color", Color("FF4444"))
		_stop_info_pulse()


func _start_info_pulse() -> void:
	_stop_info_pulse()
	if not _info_card:
		return
	_info_pulse_tween = create_tween().set_loops()
	_info_pulse_tween.tween_property(_info_card, "modulate:a", 0.85, 1.0).set_ease(Tween.EASE_IN_OUT)
	_info_pulse_tween.tween_property(_info_card, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT)


func _stop_info_pulse() -> void:
	if _info_pulse_tween:
		_info_pulse_tween.kill()
		_info_pulse_tween = null
	if _info_card:
		_info_card.modulate.a = 1.0


func _refresh_ux_visibility() -> void:
	if not _ultra_vp:
		return
	_update_info_card_status()
	_ensure_mult_labels()
	var ux_active := _manager.bet == MultiHandManager.ULTRA_BET
	if not ux_active:
		for lbl in _next_displays:
			lbl.visible = false
		for lbl in _active_displays:
			lbl.visible = false
	else:
		_update_multiplier_labels()


func _hide_active_multipliers() -> void:
	_ensure_mult_labels()
	for lbl in _active_displays:
		lbl.visible = false


func _hide_next_multipliers() -> void:
	_ensure_mult_labels()
	for lbl in _next_displays:
		lbl.visible = false


func _update_next_multipliers() -> void:
	if not _ultra_vp:
		return
	if _next_displays.size() < _num_hands:
		return
	for i in _num_hands:
		var next_m: int = _manager.next_multipliers[i] if i < _manager.next_multipliers.size() else 1
		_show_single_next_multiplier(i, next_m)


## Show NEXT multiplier for a single hand with pop-in animation.
func _show_single_next_multiplier(idx: int, earned_mult: int) -> void:
	if idx >= _next_displays.size():
		return
	var next_disp := _next_displays[idx]
	if earned_mult > 1:
		var vh: float = UX_NEXT_VAL_H_PRIMARY if idx == 0 else UX_NEXT_VAL_H_EXTRA
		var hh: float = UX_NEXT_HDR_H_PRIMARY if idx == 0 else UX_NEXT_HDR_H_EXTRA
		MultiplierGlyphs.set_next_value_x(next_disp, earned_mult, vh, hh)
		_position_next_label(idx)
		# Soft pop-in: scale from 0.55 to 1 and fade from transparent.
		next_disp.pivot_offset = next_disp.size / 2.0
		next_disp.scale = Vector2(0.55, 0.55)
		next_disp.modulate.a = 0.0
		next_disp.visible = true
		var tw := create_tween().set_parallel(true)
		tw.tween_property(next_disp, "modulate:a", 1.0, 0.09)
		tw.tween_property(next_disp, "scale", Vector2.ONE, 0.14)
	else:
		next_disp.visible = false


func _update_title() -> void:
	var title := _variant.paytable.name.to_upper()
	if _ultra_vp:
		title = "ULTRA VP — " + title
	_game_title.text = title


## Build a safe zone Control (just reserves space in layout).
## Multiplier glyph displays are direct children of game root for easy absolute positioning.
func _build_mult_zone(width: int, is_primary: bool) -> Control:
	var zone := Control.new()
	zone.custom_minimum_size = Vector2(width, 0)
	zone.size_flags_vertical = Control.SIZE_FILL
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.clip_contents = false

	# Glyph containers live at the game root level (absolute positioning).
	# NO custom_minimum_size — their size must shrink to content so
	# combined_minimum_size reflects the actual glyph row height, not a padded
	# constant. (Padding would push the value row up from the card's bottom.)
	var next_display := VBoxContainer.new()
	next_display.alignment = BoxContainer.ALIGNMENT_CENTER
	next_display.add_theme_constant_override("separation", 0)
	next_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_display.visible = false
	next_display.z_index = 10
	# I.3: Dark backdrop for contrast (lighter, rounded)
	next_display.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0.08, 0.35)
		sb.set_corner_radius_all(6)
		next_display.draw_style_box(sb, Rect2(Vector2.ZERO, next_display.size))
	)
	add_child(next_display)
	_next_displays.append(next_display)

	var active_display := HBoxContainer.new()
	active_display.alignment = BoxContainer.ALIGNMENT_CENTER
	active_display.add_theme_constant_override("separation", 0)
	active_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_display.visible = false
	active_display.z_index = 10
	# I.3: Dark backdrop for contrast (lighter, rounded)
	active_display.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0.08, 0.35)
		sb.set_corner_radius_all(6)
		active_display.draw_style_box(sb, Rect2(Vector2.ZERO, active_display.size))
	)
	add_child(active_display)
	_active_displays.append(active_display)

	_mult_zones.append(zone)
	return zone


func _clear_mult_zones() -> void:
	_cleanup_detached_rows()
	for lbl in _next_displays:
		if is_instance_valid(lbl):
			lbl.queue_free()
	for lbl in _active_displays:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_mult_zones.clear()
	_next_displays.clear()
	_active_displays.clear()


## Free any leftover rows that were detached from a NEXT VBox for animation.
## Safe to call repeatedly — clears the tracking list too.
func _cleanup_detached_rows() -> void:
	for c in _anim_detached_rows:
		if is_instance_valid(c):
			c.queue_free()
	_anim_detached_rows.clear()


func _get_zone_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= _mult_zones.size():
		return Rect2()
	var zone := _mult_zones[idx]
	if not is_instance_valid(zone) or not zone.is_inside_tree():
		return Rect2()
	return zone.get_global_rect()


## Global rect of the FIRST (left-most) card in a hand. Used to anchor
## multiplier labels directly against the visible card, not the surrounding
## container (which may be taller/wider than the card itself).
## Idx 0 = primary, 1..N = extras.
func _get_hand_rect(idx: int) -> Rect2:
	if idx == 0:
		if _primary_cards.size() > 0 and is_instance_valid(_primary_cards[0]) \
				and (_primary_cards[0] as Control).is_inside_tree():
			return (_primary_cards[0] as Control).get_global_rect()
	else:
		var mi: int = idx - 1
		if mi < _extra_displays.size():
			var mini := _extra_displays[mi] as MiniHandDisplay
			if is_instance_valid(mini) and mini.is_inside_tree():
				# Use the first mini card's rect — the HBox container may be
				# slightly taller than the cards due to layout padding.
				if mini._card_textures.size() > 0:
					var first_card: TextureRect = mini._card_textures[0]
					if is_instance_valid(first_card) and first_card.is_inside_tree():
						return first_card.get_global_rect()
				return mini.get_global_rect()
	return Rect2()


## Compute a Control's size directly from its descendants' custom_minimum_size.
## Godot's get_combined_minimum_size() can return stale / zero values right
## after children are added (the Container hasn't sorted yet), so we walk the
## tree manually and add up glyph sizes ourselves.
func _compute_glyph_min_size(c: Control) -> Vector2:
	if c == null:
		return Vector2.ZERO
	var child_count := c.get_child_count()
	if child_count == 0:
		return c.custom_minimum_size
	var total := Vector2.ZERO
	if c is VBoxContainer:
		for ch in c.get_children():
			if ch is Control:
				var cs := _compute_glyph_min_size(ch)
				total.x = maxf(total.x, cs.x)
				total.y += cs.y
	elif c is HBoxContainer:
		for ch in c.get_children():
			if ch is Control:
				var cs := _compute_glyph_min_size(ch)
				total.x += cs.x
				total.y = maxf(total.y, cs.y)
	else:
		# Leaf Control (e.g. TextureRect) — its custom_minimum_size was set
		# explicitly by _add_glyph.
		total = c.custom_minimum_size
	return total


## Force the label to shrink to its current content's minimum size.
## Needed because a VBoxContainer whose parent is NOT a Container does not
## auto-update its .size when content changes — stale size values cause the
## label to visually extend beyond its content bounds.
func _shrink_to_content(lbl: Control) -> Vector2:
	# Manual computation is more reliable than get_combined_minimum_size()
	# immediately after children were added (before the Container sorts).
	var m: Vector2 = _compute_glyph_min_size(lbl)
	if m == Vector2.ZERO:
		m = lbl.get_combined_minimum_size()
	lbl.size = m
	return m


## Left-X so the label's right edge sits just left of the hand's first card.
func _label_right_anchored_x(lbl: Control, hand_rect: Rect2) -> float:
	var content_w: float = lbl.size.x
	return hand_rect.position.x - content_w - UX_LABEL_RIGHT_GAP


func _position_next_label(idx: int) -> void:
	if idx >= _next_displays.size():
		return
	var lbl := _next_displays[idx]
	var hand_rect := _get_hand_rect(idx)
	if hand_rect.size == Vector2.ZERO or hand_rect.size.x < 10.0:
		return
	_shrink_to_content(lbl)
	lbl.global_position = Vector2(_label_right_anchored_x(lbl, hand_rect), hand_rect.position.y)


## Continuously sync visible NEXT/ACTIVE labels to the current hand positions.
## Card layouts can shift across multiple frames (resize animations, grid
## transitions, font/texture load), and the labels otherwise get stranded at
## their original positions. This keeps them glued to the hand each frame.
func _process(_delta: float) -> void:
	if not _ultra_vp:
		return
	for i in _num_hands:
		if i >= _next_displays.size():
			break
		# NEXT label — only sync when visible and not currently being animated
		# (during the slide-down its children are detached and live on `self`).
		var next_lbl := _next_displays[i]
		if is_instance_valid(next_lbl) and next_lbl.visible \
				and next_lbl.get_child_count() > 0:
			var hand_rect := _get_hand_rect(i)
			if hand_rect.size.x >= 10.0:
				var lw: float = next_lbl.size.x
				next_lbl.global_position = Vector2(
					hand_rect.position.x - lw - UX_LABEL_RIGHT_GAP,
					hand_rect.position.y)
		# ACTIVE label
		if i >= _active_displays.size():
			continue
		var active_lbl := _active_displays[i]
		if is_instance_valid(active_lbl) and active_lbl.visible \
				and active_lbl.get_child_count() > 0:
			var hrect := _get_hand_rect(i)
			if hrect.size.x >= 10.0:
				var lw2: float = active_lbl.size.x
				var lh2: float = active_lbl.size.y
				active_lbl.global_position = Vector2(
					hrect.position.x - lw2 - UX_LABEL_RIGHT_GAP,
					hrect.position.y + hrect.size.y - lh2)


## Y for ACTIVE row top so the row's bottom edge touches the hand's bottom edge.
func _active_row_y(hand_rect: Rect2, active_h: float) -> float:
	return hand_rect.position.y + hand_rect.size.y - active_h


## Position the given multiplier label at the ACTIVE spot (bottom-left of the hand).
func _position_active_label_ctrl(lbl: Control, idx: int) -> void:
	if not is_instance_valid(lbl):
		return
	var hand_rect := _get_hand_rect(idx)
	if hand_rect.size == Vector2.ZERO:
		return
	var sz: Vector2 = _shrink_to_content(lbl)
	lbl.global_position = Vector2(_label_right_anchored_x(lbl, hand_rect), _active_row_y(hand_rect, sz.y))


## Convenience: position _next_displays[idx] at ACTIVE spot (for the old
## single-label animation path).
func _position_active_label(idx: int) -> void:
	if idx >= _next_displays.size():
		return
	_position_active_label_ctrl(_next_displays[idx], idx)


func _ensure_mult_labels() -> void:
	pass  # No-op; zones are built during layout


func _update_multiplier_labels() -> void:
	if not _ultra_vp:
		return
	if _next_displays.size() < _num_hands or _active_displays.size() < _num_hands:
		return
	await get_tree().process_frame

	for i in _num_hands:
		var active: int = _manager.hand_multipliers[i] if i < _manager.hand_multipliers.size() else 1
		var next_m: int = _manager.next_multipliers[i] if i < _manager.next_multipliers.size() else 1
		var next_lbl := _next_displays[i]
		var active_lbl := _active_displays[i]
		next_lbl.scale = Vector2.ONE
		next_lbl.modulate.a = 1.0
		active_lbl.scale = Vector2.ONE
		active_lbl.modulate.a = 1.0

		# NEXT label (top of card) — only when user earned a multiplier for next round.
		if next_m > 1:
			var vh: float = UX_NEXT_VAL_H_PRIMARY if i == 0 else UX_NEXT_VAL_H_EXTRA
			var hh: float = UX_NEXT_HDR_H_PRIMARY if i == 0 else UX_NEXT_HDR_H_EXTRA
			MultiplierGlyphs.set_next_value_x(next_lbl, next_m, vh, hh)
			_position_next_label(i)
			next_lbl.visible = true
		else:
			next_lbl.visible = false

		# ACTIVE label (bottom of card) — persists for entire round until next deal.
		if active > 1:
			var ah: float = UX_ACTIVE_H_PRIMARY if i == 0 else UX_ACTIVE_H_EXTRA
			MultiplierGlyphs.set_value_x(active_lbl, active, ah)
			_position_active_label_ctrl(active_lbl, i)
			active_lbl.visible = true
		else:
			active_lbl.visible = false


## Animate NEXT → ACTIVE for all hands in parallel.
## Single-label Ultra VP animation. One label per hand is reused for both
## NEXT ("NEXT HAND / value", top of zone) and ACTIVE ("value x", bottom of zone).
## The animation tweens the label's position from top to bottom, then rebuilds
## its content from two-row to one-row in place — NO separate label, NO handoff.
func _animate_multipliers_next_to_active() -> void:
	if not _ultra_vp or _manager.bet != MultiHandManager.ULTRA_BET:
		return
	if _next_displays.size() < _num_hands:
		return

	await get_tree().process_frame

	# Read NEXT multipliers from manager (source of truth).
	var next_mults: Array[int] = []
	for i in _num_hands:
		var m: int = _manager.next_multipliers[i] if i < _manager.next_multipliers.size() else 1
		next_mults.append(m)

	# Ensure NEXT labels are built + positioned at top (in case the animation
	# is triggered before _update_multiplier_labels had a chance to run).
	for i in _num_hands:
		var next_lbl := _next_displays[i]
		if not is_instance_valid(next_lbl):
			continue
		next_lbl.scale = Vector2.ONE
		next_lbl.modulate.a = 1.0
		next_lbl.pivot_offset = Vector2.ZERO
		if next_mults[i] > 1:
			var nv_h: float = UX_NEXT_VAL_H_PRIMARY if i == 0 else UX_NEXT_VAL_H_EXTRA
			var nh_h: float = UX_NEXT_HDR_H_PRIMARY if i == 0 else UX_NEXT_HDR_H_EXTRA
			MultiplierGlyphs.set_next_value_x(next_lbl, next_mults[i], nv_h, nh_h)
			_position_next_label(i)
			next_lbl.visible = true
		else:
			next_lbl.visible = false

	# Let layout settle for rebuilt labels.
	await get_tree().process_frame

	# Clean up any leftover detached rows from a prior (possibly interrupted)
	# animation so they don't visually duplicate with the ones we're about
	# to detach now.
	_cleanup_detached_rows()

	# Detach NEXT VBox children (header row + value row) from each VBox so we
	# can animate them independently: header stays in place and fades out,
	# while value row slides down to the hand's bottom.
	var detached_hdrs: Array[Control] = []
	var detached_vals: Array[Control] = []
	detached_hdrs.resize(_num_hands)
	detached_vals.resize(_num_hands)

	for i in _num_hands:
		var vbox := _next_displays[i]
		if not is_instance_valid(vbox) or next_mults[i] <= 1:
			continue
		if vbox.get_child_count() < 2:
			continue
		var hdr := vbox.get_child(0) as Control
		var val := vbox.get_child(1) as Control
		if not hdr or not val:
			continue
		var hdr_gpos := hdr.get_global_rect().position
		var val_gpos := val.get_global_rect().position
		vbox.remove_child(hdr)
		vbox.remove_child(val)
		add_child(hdr)
		add_child(val)
		hdr.global_position = hdr_gpos
		val.global_position = val_gpos
		hdr.z_index = 10
		val.z_index = 10
		detached_hdrs[i] = hdr
		detached_vals[i] = val
		_anim_detached_rows.append(hdr)
		_anim_detached_rows.append(val)
		vbox.visible = false

	var tween := create_tween().set_parallel(true)
	var has_any := false

	for i in _num_hands:
		var active_lbl := _active_displays[i]
		if not is_instance_valid(active_lbl):
			continue

		# Fade out the existing ACTIVE label with a small shrink.
		if active_lbl.visible:
			has_any = true
			active_lbl.pivot_offset = active_lbl.size / 2.0
			tween.tween_property(active_lbl, "modulate:a", 0.0, 0.07)
			tween.tween_property(active_lbl, "scale", Vector2(0.7, 0.7), 0.07)

		if next_mults[i] <= 1:
			continue
		var hand_rect := _get_hand_rect(i)
		if hand_rect.size == Vector2.ZERO:
			continue
		var hdr := detached_hdrs[i]
		var val := detached_vals[i]
		if not is_instance_valid(hdr) or not is_instance_valid(val):
			continue
		has_any = true

		# Value row slides down; header stays in place and fades out.
		var val_end_pos := Vector2(val.global_position.x,
				hand_rect.position.y + hand_rect.size.y - val.size.y)
		tween.tween_property(val, "global_position", val_end_pos, 0.38)
		# Header fade — starts LATE, vanishes almost instantly near end of slide.
		tween.tween_property(hdr, "modulate:a", 0.0, 0.025).set_delay(0.32)

	if not has_any:
		_cleanup_detached_rows()
		return
	await tween.finished
	VibrationManager.vibrate("multiplier_activate")

	# Free the detached rows — their job is done.
	_cleanup_detached_rows()

	# Reset VBox containers (now empty; will be rebuilt next time).
	for i in _num_hands:
		var nl := _next_displays[i]
		if is_instance_valid(nl):
			nl.visible = false
			nl.scale = Vector2.ONE
			nl.modulate.a = 1.0

	# Pop in the new ACTIVE labels — FAST fade + grow.
	var pop_tween := create_tween().set_parallel(true)
	var pop_has_any := false
	for i in _num_hands:
		var active_lbl := _active_displays[i]
		if not is_instance_valid(active_lbl):
			continue
		if next_mults[i] > 1:
			var ah: float = UX_ACTIVE_H_PRIMARY if i == 0 else UX_ACTIVE_H_EXTRA
			MultiplierGlyphs.set_value_x(active_lbl, next_mults[i], ah)
			_position_active_label_ctrl(active_lbl, i)
			# Appear in place with pure fade-in — no scale, no position movement.
			active_lbl.scale = Vector2.ONE
			active_lbl.pivot_offset = Vector2.ZERO
			active_lbl.modulate.a = 0.0
			active_lbl.visible = true
			pop_has_any = true
			pop_tween.tween_property(active_lbl, "modulate:a", 1.0, 0.07)
		else:
			active_lbl.visible = false
	if pop_has_any:
		await pop_tween.finished


func _build_info_card() -> void:
	if _info_card:
		_info_card.queue_free()
	_info_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07107A")
	style.set_border_width_all(3)
	style.border_color = Color("FFEC00")
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_info_card.add_theme_stylebox_override("panel", style)
	_info_card.custom_minimum_size = _get_primary_card_size()
	_info_card.custom_minimum_size.y = 120
	_info_card.clip_contents = true
	_info_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_info_card.gui_input.connect(_on_info_card_clicked)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_vertical = Control.SIZE_FILL
	_info_card.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("info_card.ultra_vp_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	var bold := SystemFont.new()
	bold.font_weight = 700
	title.add_theme_font_override("font", bold)
	vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color("FFEC00")
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	var desc := Label.new()
	desc.text = Translations.tr_key("info_card.description")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(desc)

	_info_card_active_label = Label.new()
	_info_card_active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_card_active_label.add_theme_font_size_override("font_size", 16)
	_info_card_active_label.add_theme_font_override("font", bold)
	vbox.add_child(_info_card_active_label)
	_update_info_card_status()

	_primary_container.add_child(_info_card)


func _on_info_card_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _manager.state == MultiHandManager.State.IDLE or _manager.state == MultiHandManager.State.WIN_DISPLAY:
			if _manager.state == MultiHandManager.State.WIN_DISPLAY:
				_manager._to_idle()
			_save_ux_state()
			_manager.bet = MultiHandManager.ULTRA_BET if _ultra_vp else MultiHandManager.MAX_BET
			SaveManager.bet_level = _manager.bet
			SaveManager.save_game()
			_load_ux_state()
			_update_multiplier_labels()
			_manager.bet_changed.emit(_manager.bet)
			# Run animation before deal
			await _animate_multipliers_next_to_active()
			_manager.deal()


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
	if _balance_show_depth:
		SaveManager.set_currency_value(_balance_cd, "", 20, Color.WHITE, false)
	else:
		SaveManager.set_currency_value(_balance_cd, "", 20, Color.WHITE)
	_credit_tween = create_tween()
	var dur := 2.1 if _ultra_vp else 1.4
	_credit_tween.tween_method(_update_credit_display, start, target, dur).set_ease(Tween.EASE_OUT)
	_credit_tween.tween_callback(_on_credit_animation_done)


func _update_credit_display(value: int) -> void:
	_displayed_credits = value
	if _balance_show_depth:
		var denom: int = maxi(SaveManager.denomination, 1)
		var cr: int = value / denom
		_balance_label.text = Translations.tr_key("game.games")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(cr), 0, Color(-1, 0, 0), false)
	else:
		_balance_label.text = Translations.tr_key("game.balance")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(value), 0, Color(-1, 0, 0), true)


func _on_credit_animation_done() -> void:
	SaveManager.set_currency_value(_balance_cd, "", 16, COL_YELLOW)
	_unlock_buttons()
	# Enable double if there was a total win
	var total_payout := 0
	for r in _manager.all_results:
		total_payout += int(r["payout"])
	if total_payout > 0:
		_double_btn.disabled = false
		_double_amount = total_payout
		# G.4: Pulse balance for 3 seconds after win
		_pulse_balance(3.0)


func _pulse_balance(duration: float) -> void:
	var tw := create_tween().set_loops(int(duration / 0.6))
	tw.tween_property(_balance_cd["box"], "modulate", Color(1.3, 1.3, 0.8), 0.3)
	tw.tween_property(_balance_cd["box"], "modulate", Color.WHITE, 0.3)


func _delay_unlock_buttons() -> void:
	await get_tree().create_timer(0.5).timeout
	_unlock_buttons()


func _unlock_buttons() -> void:
	_deal_draw_btn.disabled = false
	_bet_btn.disabled = false
	_bet_max_btn.disabled = false
	_bet_amount_btn.disabled = false
	_bet_amount_btn.modulate.a = 1.0

func _on_bet_one_pressed() -> void:
	if _ultra_vp:
		_save_ux_state()
	_manager.bet_one()
	if _ultra_vp:
		# bet_one only changes bet (no deal) — safe to refresh labels
		_load_ux_state()
		_update_multiplier_labels()


func _on_bet_max_pressed() -> void:
	if _ultra_vp:
		_save_ux_state()
		# Restore state for MAX bet key (where NEXT mults are stored)
		var max_key := "%d_%d_%d" % [_num_hands, MultiHandManager.ULTRA_BET, SaveManager.denomination]
		if max_key in _ux_states:
			var st: Dictionary = _ux_states[max_key]
			var saved_hand: Array = st["hand_multipliers"]
			var saved_next: Array = st["next_multipliers"]
			_manager.hand_multipliers.clear()
			_manager.next_multipliers.clear()
			for i in _num_hands:
				_manager.hand_multipliers.append(saved_hand[i] if i < saved_hand.size() else 1)
				_manager.next_multipliers.append(saved_next[i] if i < saved_next.size() else 1)
		_update_multiplier_labels()
		# Run animation BEFORE bet_max() which calls deal()
		await _animate_multipliers_next_to_active()
	_manager.bet_max()


func _on_bet_changed(new_bet: int) -> void:
	_update_bet_display(new_bet)
	_update_paytable_badges()
	_bet_btn.text = Translations.tr_key("game.bet_one_fmt", [new_bet])
	if _balance_show_depth:
		_update_balance(SaveManager.credits)

func _on_card_clicked(card_index: int) -> void:
	if _in_double:
		_on_double_card_picked(card_index)
		return
	_manager.toggle_hold(card_index)
	_primary_cards[card_index].set_held(_manager.held[card_index])
	VibrationManager.vibrate("card_hold")
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


func _on_back_pressed() -> void:
	TopBarBuilder.show_exit_confirm(self, func() -> void: back_to_lobby.emit())


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

	var tex_y := load("res://assets/textures/btn_rect_yellow.svg")
	for amount in BET_AMOUNTS:
		var btn := Button.new()
		btn.text = ""
		_style_btn(btn, tex_y, COL_BTN_TEXT, 18, 120, 44)
		var cd := SaveManager.create_currency_display(16, COL_BTN_TEXT)
		cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		SaveManager.set_currency_value(cd, SaveManager.format_auto(amount, 96, 16))
		btn.add_child(cd["box"])
		btn.pressed.connect(func() -> void:
			if _ultra_vp:
				_save_ux_state()
			_current_denomination = amount
			SaveManager.denomination = amount
			if _ultra_vp:
				_load_ux_state()
				_update_multiplier_labels()
			_update_bet_amount_btn()
			_update_bet_display(_manager.bet)
			if _balance_show_depth:
				_update_balance(SaveManager.credits)
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
		)
		grid.add_child(btn)


# --- Shop popup ---

var SHOP_AMOUNTS: Array = []
var _shop_overlay: Control = null

func _show_shop() -> void:
	if _shop_overlay:
		_shop_overlay.queue_free()
		_shop_overlay = null

	_shop_overlay = Control.new()
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.z_index = 50
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
	title.text = Translations.tr_key("shop.title")
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
		buy_btn.text = Translations.tr_key("common.free")
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


# --- Info screen ---

func _show_info() -> void:
	if _info_overlay:
		_info_overlay.queue_free()
		_info_overlay = null

	_info_overlay = Control.new()
	_info_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Multiplier displays use z_index = 10; put the info modal above them so
	# it fully covers the game UI (otherwise NEXT/ACTIVE glyphs bleed through).
	_info_overlay.z_index = 100
	add_child(_info_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_info()
	)
	_info_overlay.add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.offset_top = 20
	scroll.offset_bottom = -20
	_info_overlay.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.5, 0.1, 0.1, 0.8)
	close_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_hide_info)
	content.add_child(close_btn)

	var bold := SystemFont.new()
	bold.font_weight = 700

	# Title
	var title := Label.new()
	title.text = Translations.tr_key("info.title_ultra_vp") if _ultra_vp else Translations.tr_key("info.title_multi")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	title.add_theme_font_override("font", bold)
	content.add_child(title)

	# Rules text — RichTextLabel with dark backdrop
	var rules_panel := PanelContainer.new()
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.1, 0.1, 0.4, 0.7)
	rp_style.set_corner_radius_all(8)
	rp_style.content_margin_left = 20
	rp_style.content_margin_right = 20
	rp_style.content_margin_top = 12
	rp_style.content_margin_bottom = 12
	rules_panel.add_theme_stylebox_override("panel", rp_style)
	content.add_child(rules_panel)
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 16)
	rules.add_theme_color_override("default_color", Color.WHITE)
	var rules_key := "info.rules_ultra_vp" if _ultra_vp else "info.rules_multi"
	var rules_text: String = Translations.tr_key(rules_key)
	if "[color" not in rules_text:
		for kw in ["DEAL", "DRAW", "HOLD", "MAX BET", "Ultra VP", "РУКИ"]:
			rules_text = rules_text.replace(kw, "[color=#00FF88]%s[/color]" % kw)
	rules.text = "[center]%s[/center]" % rules_text
	rules_panel.add_child(rules)

	if _ultra_vp:
		# Multiplier table title
		var mt := Label.new()
		mt.text = Translations.tr_key("info.multiplier_table")
		mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mt.add_theme_font_size_override("font_size", 22)
		mt.add_theme_color_override("font_color", Color("FFEC00"))
		mt.add_theme_font_override("font", bold)
		content.add_child(mt)

		var table := GridContainer.new()
		table.columns = 2
		table.add_theme_constant_override("h_separation", 40)
		table.add_theme_constant_override("v_separation", 6)
		content.add_child(table)

		for header_key in ["info.col_winning_hand", "info.col_next_multiplier"]:
			var lbl := Label.new()
			lbl.text = Translations.tr_key(header_key)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", Color("FFEC00"))
			lbl.add_theme_font_override("font", bold)
			table.add_child(lbl)

		var mult_table := [
			[Translations.tr_key("hand.jacks_or_better"), "2x"],
			[Translations.tr_key("hand.two_pair"), "3x"],
			[Translations.tr_key("hand.three_of_a_kind"), "4x"],
			[Translations.tr_key("hand.straight"), "5x"],
			[Translations.tr_key("hand.flush"), "6x"],
			[Translations.tr_key("hand.full_house"), "8x"],
			[Translations.tr_key("hand.four_of_a_kind"), "10x"],
			[Translations.tr_key("hand.straight_flush"), "12x"],
			[Translations.tr_key("hand.royal_flush"), "12x"],
		]
		var row_colors := [
			Color(0.4, 0.4, 0.6),   # Jacks or Better
			Color(0.4, 0.5, 0.6),   # Two Pair
			Color(0.3, 0.6, 0.4),   # Three of a Kind
			Color(0.3, 0.5, 0.7),   # Straight
			Color(0.5, 0.3, 0.6),   # Flush
			Color(0.6, 0.4, 0.3),   # Full House
			Color(0.7, 0.5, 0.2),   # Four of a Kind
			Color(0.3, 0.7, 0.7),   # Straight Flush
			Color(0.8, 0.6, 0.2),   # Royal Flush
		]
		for ri in mult_table.size():
			var row_data: Array = mult_table[ri]
			var row_col: Color = row_colors[ri] if ri < row_colors.size() else Color.WHITE
			for cell in row_data:
				var cell_panel := PanelContainer.new()
				var cs := StyleBoxFlat.new()
				cs.bg_color = Color(0.08, 0.08, 0.2, 0.5)
				cs.set_border_width_all(1)
				cs.border_color = Color(0.3, 0.3, 0.5)
				cs.content_margin_left = 8
				cs.content_margin_right = 8
				cs.content_margin_top = 3
				cs.content_margin_bottom = 3
				cell_panel.add_theme_stylebox_override("panel", cs)
				var lbl := Label.new()
				lbl.text = cell
				lbl.add_theme_font_size_override("font_size", 14)
				lbl.add_theme_color_override("font_color", row_col)
				cell_panel.add_child(lbl)
				table.add_child(cell_panel)
		table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _hide_info() -> void:
	if _info_overlay:
		_info_overlay.queue_free()
		_info_overlay = null


# --- Double or Nothing ---

var _double_overlay: Control = null

func _on_double_pressed() -> void:
	if _double_amount <= 0:
		return
	if not _double_warned:
		_show_double_warning()
	else:
		_start_double()


func _show_double_warning() -> void:
	_double_overlay = Control.new()
	_double_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_double_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_double_overlay.z_index = 50
	add_child(_double_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_double_overlay.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("07107A")
	ps.set_border_width_all(3)
	ps.border_color = COL_YELLOW
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 20
	ps.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_double_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("double.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_YELLOW)
	vbox.add_child(title)

	var doubled := _double_amount * 2
	var msg := Label.new()
	msg.text = Translations.tr_key("double.msg_fmt",
			[SaveManager.format_money(_double_amount), SaveManager.format_money(doubled)])
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 20)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)

	var tex_green := load("res://assets/textures/btn_rect_green.svg")
	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg")

	var no_btn := Button.new()
	no_btn.text = Translations.tr_key("common.no")
	_style_btn(no_btn, tex_yellow, COL_BTN_TEXT, 22, 120, 44)
	no_btn.pressed.connect(func() -> void:
		_hide_double_overlay()
	)
	btns.add_child(no_btn)

	var yes_btn := Button.new()
	yes_btn.text = Translations.tr_key("common.yes")
	_style_btn(yes_btn, tex_green, Color.WHITE, 22, 120, 44)
	yes_btn.pressed.connect(func() -> void:
		_double_warned = true
		_hide_double_overlay()
		_start_double()
	)
	btns.add_child(yes_btn)


func _start_double() -> void:
	_in_double = true
	_double_btn.disabled = true
	_deal_draw_btn.disabled = true
	_bet_btn.disabled = true
	_bet_max_btn.disabled = true
	_hands_btn.disabled = true

	# Deduct winnings from balance
	SaveManager.deduct_credits(_double_amount)
	_update_balance(SaveManager.credits)

	# Build a fresh 52-card deck
	var deck := Deck.new(52)
	_double_cards = deck.deal_hand()
	_double_dealer_card = _double_cards[0]

	_hide_primary_result()
	_stop_result_blink()
	# Hide extra hands results
	for mini in _extra_displays:
		mini.hide_result()
		mini.modulate = Color(0.35, 0.35, 0.45)

	_win_label.text = Translations.tr_key("double.pick_card")
	_win_cd["box"].visible = false

	# Show: dealer card face-up, 4 player cards face-down
	for i in 5:
		_primary_cards[i].set_flip_duration(0.15)
		_primary_cards[i].set_held(false)
		if i == 0:
			_primary_cards[i].set_card(_double_cards[i], true)
		else:
			_primary_cards[i].show_back()
			_primary_cards[i].set_interactive(true)


func _on_double_card_picked(index: int) -> void:
	if index == 0:
		return
	for i in 5:
		_primary_cards[i].set_interactive(false)

	var card: CardData = _double_cards[index]
	_primary_cards[index].set_card(card, true)
	await get_tree().create_timer(0.5).timeout

	var player_rank: int = card.rank as int
	var dealer_rank: int = _double_dealer_card.rank as int

	if player_rank > dealer_rank:
		_double_amount *= 2
		VibrationManager.vibrate("double_win")
		SaveManager.add_credits(_double_amount)
		_displayed_credits = SaveManager.credits - _double_amount
		_animate_credits(SaveManager.credits)
		_win_label.text = Translations.tr_key("double.win")
		_win_cd["box"].visible = true
		if _balance_show_depth:
			SaveManager.set_currency_value(_win_cd, str(_double_amount / maxi(SaveManager.denomination, 1)), 0, Color(-1, 0, 0), false)
		else:
			SaveManager.set_currency_value(_win_cd, SaveManager.format_short(_double_amount))
		await _credit_tween.finished
		_double_btn.disabled = false
		_deal_draw_btn.disabled = false
		_bet_btn.disabled = false
		_bet_max_btn.disabled = false
	elif player_rank == dealer_rank:
		SaveManager.add_credits(_double_amount)
		_displayed_credits = SaveManager.credits - _double_amount
		_animate_credits(SaveManager.credits)
		_win_label.text = Translations.tr_key("double.tie")
		_win_cd["box"].visible = false
		_double_amount = 0
		await _credit_tween.finished
		_end_double()
	else:
		VibrationManager.vibrate("double_lose")
		_win_label.text = Translations.tr_key("double.lose")
		_win_cd["box"].visible = false
		_double_amount = 0
		_end_double()


func _end_double() -> void:
	await get_tree().create_timer(1.0).timeout
	_double_btn.disabled = true
	_deal_draw_btn.disabled = false
	_bet_btn.disabled = false
	_bet_max_btn.disabled = false
	_hands_btn.disabled = false
	_in_double = false
	# Restore extra hands
	for mini in _extra_displays:
		mini.modulate = Color.WHITE


func _hide_double_overlay() -> void:
	if _double_overlay:
		_double_overlay.queue_free()
		_double_overlay = null


# --- Primary hand result overlay ---

var _primary_result_overlay: PanelContainer = null

func _show_primary_result(hand_name: String, multiplier: int, badge_color: Color = COL_YELLOW, active_mult: int = 1) -> void:
	_hide_primary_result()
	_primary_result_overlay = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.2, 0.9)
	style.set_border_width_all(2)
	style.border_color = badge_color
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_primary_result_overlay.add_theme_stylebox_override("panel", style)
	_primary_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primary_result_overlay.custom_minimum_size.x = _primary_container.size.x * 0.33

	var label := Label.new()
	if active_mult > 1:
		var total := active_mult * multiplier
		label.text = "%s\n%d x %d = %d" % [hand_name, active_mult, multiplier, total]
	else:
		label.text = "%s\nX%d" % [hand_name, multiplier]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	_primary_result_overlay.add_child(label)

	# Start hidden so the overlay never shows at (0,0) before it's positioned.
	_primary_result_overlay.visible = false
	add_child(_primary_result_overlay)
	await get_tree().process_frame
	if not is_instance_valid(_primary_result_overlay):
		return
	var cards_rect := _primary_container.get_global_rect()
	var center := cards_rect.get_center()
	var sz := _primary_result_overlay.get_combined_minimum_size()
	_primary_result_overlay.position = Vector2(center.x - sz.x / 2, center.y - sz.y / 2)
	_primary_result_overlay.visible = true


func _get_badge_color_for_hand(hand_name: String, hand_keys: Array[String]) -> Color:
	# Match hand_name to paytable key's *localized* display name.
	for idx in hand_keys.size():
		if _variant.paytable.get_hand_display_name(hand_keys[idx]) == hand_name:
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
	# Ultra VP — no badges
	if _ultra_vp:
		return

	var hand_keys := _variant.paytable.get_hand_order()
	var total: int = hand_keys.size()
	# Split evenly: left gets ceil, right gets floor
	var left_count: int = ceili(total / 2.0)
	var right_count: int = total - left_count

	# Create left column
	_left_badges = VBoxContainer.new()
	_left_badges.add_theme_constant_override("separation", 2)
	_left_badges.alignment = BoxContainer.ALIGNMENT_BEGIN
	_left_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_badges.visible = false
	add_child(_left_badges)

	# Create right column
	_right_badges = VBoxContainer.new()
	_right_badges.add_theme_constant_override("separation", 2)
	_right_badges.alignment = BoxContainer.ALIGNMENT_BEGIN
	_right_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_badges.visible = false
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

	_left_badges.visible = true
	_right_badges.visible = true


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
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	badge.add_theme_stylebox_override("panel", style)

	badge.custom_minimum_size.x = 180
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = "%s\nX%d" % [hand_name, multiplier]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
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
