extends Control

signal back_to_lobby

var CardScene: PackedScene

@onready var _paytable_display: PanelContainer = $TopSection/PaytableMargin/PaytableDisplay
@onready var _cards_container: HBoxContainer = %CardsContainer
@onready var _game_title: Label = %GameTitle
@onready var _back_btn: Button = %BackButton
@onready var _balance_label: Label = %BalanceLabel
@onready var _topup_btn: Button = %TopUpButton
@onready var _last_win_label: Label = %LastWinLabel
@onready var _total_bet_label: Label = %TotalBetLabel
@onready var _speed_btn: Button = %SpeedButton
@onready var _bet_one_btn: Button = %BetOneButton
@onready var _bet_amount_btn: Button = %BetAmountButton
@onready var _bet_max_btn: Button = %BetMaxButton
@onready var _deal_draw_btn: Button = %DealDrawButton
@onready var _bottom_bar: HBoxContainer = %BottomBar
@onready var _bottom_bar_margin: MarginContainer = $BottomSection/BottomBarMargin
@onready var _info_bar: HBoxContainer = %InfoBar
@onready var _info_bar_margin: MarginContainer = $TopSection/InfoBarMargin
@onready var _top_section: VBoxContainer = $TopSection
@onready var _bottom_section: VBoxContainer = $BottomSection
@onready var _middle_section: VBoxContainer = %MiddleSection

var _game_manager: GameManager
var _card_visuals: Array = []
var _bet_flash_tween: Tween
var _info_btn: Button
var _info_overlay: Control
var _double_btn: Button
var _double_amount: int = 0
var _double_warned: bool = false  # show warning only once per session
var _in_double: bool = false
var _balance_cd: Dictionary  # currency display for balance
var _balance_show_depth: bool = false
var _depth_tooltip: Control = null
var _bet_cd: Dictionary      # currency display for total bet
var _variant: BaseVariant
var _animating: bool = false

# Figma colors
const COL_YELLOW := Color("FFEC00")
const COL_BG := Color("000086")
const COL_GREEN := Color("07E02F")
const COL_BTN_TEXT := Color("3F2A00")

# Speed system — 4 levels
var _speed_level: int = 1
const SPEED_CONFIGS := [
	{"deal_ms": 150, "draw_ms": 200, "flip_s": 0.15},
	{"deal_ms": 100, "draw_ms": 140, "flip_s": 0.12},
	{"deal_ms": 60,  "draw_ms": 80,  "flip_s": 0.08},
	{"deal_ms": 30,  "draw_ms": 40,  "flip_s": 0.05},
]
const ARROW_ACTIVE := "▶"
const ARROW_INACTIVE := "▷"

# Bet amounts for the picker
const BET_AMOUNTS := [1, 5, 10, 20, 50, 100, 500, 1000, 2000, 5000, 10000, 50000]
var _current_denomination: int = 1
var _bet_picker_overlay: Control = null


func setup(variant: BaseVariant) -> void:
	_variant = variant


func _ready() -> void:
	if _variant == null:
		return
	CardScene = load("res://scenes/card.tscn")

	_game_manager = GameManager.new()
	add_child(_game_manager)
	_game_manager.setup(_variant)

	_game_manager.state_changed.connect(_on_state_changed)
	_game_manager.cards_dealt.connect(_on_cards_dealt)
	_game_manager.card_replaced.connect(_on_card_replaced)
	_game_manager.hand_evaluated.connect(_on_hand_evaluated)
	_game_manager.credits_changed.connect(_on_credits_changed)
	_game_manager.bet_changed.connect(_on_bet_changed)

	_back_btn.pressed.connect(_on_back_pressed)
	# Info button — created programmatically
	_info_btn = Button.new()
	_info_btn.text = "i"
	_info_btn.pressed.connect(_show_info)
	# Double button
	_double_btn = Button.new()
	_double_btn.text = Translations.tr_key("game.double")
	_double_btn.disabled = true
	_double_btn.pressed.connect(_on_double_pressed)
	_speed_btn.pressed.connect(_on_speed_pressed)
	_bet_one_btn.pressed.connect(_game_manager.bet_one)
	_bet_amount_btn.pressed.connect(_on_bet_amount_pressed)
	_bet_max_btn.pressed.connect(_on_bet_max_pressed)
	_deal_draw_btn.pressed.connect(_on_deal_draw_pressed)
	_topup_btn.pressed.connect(_show_shop)

	_speed_level = SaveManager.speed_level
	_apply_theme()
	_update_speed_display()
	_paytable_display.setup(_variant.paytable)
	_paytable_display.bet_column_clicked.connect(_on_paytable_bet_clicked)
	_game_title.text = Translations.tr_key("machine.%s.name" % _variant.variant_id).to_upper()

	_create_card_slots()

	_current_denomination = _recommend_denomination()
	SaveManager.denomination = _current_denomination
	_update_bet_amount_btn()
	_update_balance(SaveManager.credits)
	_update_bet_display(_game_manager.bet)
	_bet_one_btn.text = Translations.tr_key("game.bet_one_fmt", [_game_manager.bet])
	_bet_max_btn.text = Translations.tr_key("game.bet_max")
	_set_status(Translations.tr_key("game.place_your_bet"))



func _apply_theme() -> void:
	# All sizes fixed pixels for 2952x1360 viewport.
	# canvas_items + keep scales everything proportionally.

	_top_section.add_theme_constant_override("separation", 0)
	_bottom_section.add_theme_constant_override("separation", 4)
	_middle_section.add_theme_constant_override("separation", 2)
	_layout_middle.call_deferred()

	# Back button — subtle, small
	_back_btn.add_theme_font_size_override("font_size", 18)
	_back_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_back_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.6))
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0, 0, 0, 0)
	_back_btn.add_theme_stylebox_override("normal", back_style)
	_back_btn.add_theme_stylebox_override("hover", back_style)
	_back_btn.add_theme_stylebox_override("pressed", back_style)
	_back_btn.custom_minimum_size = Vector2(40, 30)

	# Title — compact to give paytable more room
	_game_title.add_theme_font_size_override("font_size", 20)
	_game_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))

	# Paytable & InfoBar margins
	var side_m := 100
	$TopSection/PaytableMargin.add_theme_constant_override("margin_left", side_m)
	$TopSection/PaytableMargin.add_theme_constant_override("margin_right", side_m)
	_info_bar_margin.add_theme_constant_override("margin_left", side_m)
	_info_bar_margin.add_theme_constant_override("margin_right", side_m)

	_balance_label.add_theme_font_size_override("font_size", 22)
	_balance_label.add_theme_color_override("font_color", Color.WHITE)
	_balance_label.text = Translations.tr_key("game.balance")
	_balance_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_balance_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_balance_label.gui_input.connect(_on_balance_clicked)
	_balance_cd = SaveManager.create_currency_display(18, Color.WHITE)
	_balance_cd["box"].mouse_filter = Control.MOUSE_FILTER_STOP
	_balance_cd["box"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_balance_cd["box"].gui_input.connect(_on_balance_clicked)
	_balance_label.get_parent().add_child(_balance_cd["box"])
	_balance_label.get_parent().move_child(_balance_cd["box"], _balance_label.get_index() + 1)
	# Top-up button
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
	# Reparent status label out of InfoBar to position freely over cards
	_last_win_label.get_parent().remove_child(_last_win_label)
	add_child(_last_win_label)
	_last_win_label.add_theme_font_size_override("font_size", 20)
	_last_win_label.add_theme_color_override("font_color", COL_YELLOW)
	_last_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_win_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Cards gap
	_cards_container.add_theme_constant_override("separation", 8)

	# Total bet — wrap label + chip_label in HBox
	_total_bet_label.add_theme_font_size_override("font_size", 22)
	_total_bet_label.add_theme_color_override("font_color", Color.WHITE)
	_total_bet_label.text = Translations.tr_key("game.total_bet")
	_bet_cd = SaveManager.create_currency_display(22, Color.WHITE)
	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 4)
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var bet_parent := _total_bet_label.get_parent()
	var bet_idx := _total_bet_label.get_index()
	bet_parent.remove_child(_total_bet_label)
	bet_row.add_child(_total_bet_label)
	bet_row.add_child(_bet_cd["box"])
	bet_parent.add_child(bet_row)
	bet_parent.move_child(bet_row, bet_idx)

	# Bottom bar
	# Same margins as paytable so buttons align with table edges
	_bottom_bar_margin.add_theme_constant_override("margin_left", side_m)
	_bottom_bar_margin.add_theme_constant_override("margin_right", side_m)
	_bottom_bar_margin.add_theme_constant_override("margin_bottom", 10)
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_theme_constant_override("separation", 0)
	_build_button_groups.call_deferred()

	# Button textures
	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg")
	var tex_pill := load("res://assets/textures/btn_pill_yellow.svg")
	var tex_green := load("res://assets/textures/btn_rect_green.svg")
	var tex_blue := load("res://assets/textures/btn_blue.svg")

	# Buttons
	var tex_info := load("res://assets/textures/info_button.svg")
	_style_button_texture(_info_btn, tex_info, Color.BLACK, 22, 52, 52)
	_style_button_texture(_speed_btn, tex_yellow, COL_BTN_TEXT, 18, 140, 52)
	_style_button_texture(_double_btn, tex_yellow, COL_BTN_TEXT, 18, 120, 52)
	_style_button_texture(_bet_one_btn, tex_yellow, COL_BTN_TEXT, 22, 140, 52)
	_style_button_texture(_bet_amount_btn, tex_blue, Color.WHITE, 22, 150, 52)
	_update_bet_amount_btn()
	_style_button_texture(_bet_max_btn, tex_yellow, COL_BTN_TEXT, 22, 150, 52)
	_style_button_texture(_deal_draw_btn, tex_green, Color.WHITE, 24, 150, 52)



func _style_button_texture(btn: Button, tex: Texture2D, text_col: Color, font_sz: int, min_w: int, min_h: int) -> void:
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.texture_margin_left = 12
	style.texture_margin_right = 12
	style.texture_margin_top = 12
	style.texture_margin_bottom = 12
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
	btn.add_theme_color_override("font_disabled_color", text_col.darkened(0.3))
	btn.custom_minimum_size = Vector2(min_w, min_h)
	# Press animation — scale down then back
	if not btn.is_connected("button_down", _on_btn_down):
		btn.button_down.connect(_on_btn_down.bind(btn))
		btn.button_up.connect(_on_btn_up.bind(btn))


static func _on_btn_down(btn: Button) -> void:
	var tween := btn.create_tween()
	btn.pivot_offset = btn.size / 2
	tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05)


static func _on_btn_up(btn: Button) -> void:
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_OUT)


func _build_button_groups() -> void:
	# Insert info button before SPEED, then spacers between groups:
	# [INFO] [SPEED] [spacer] [BET ONE] [$amt] [MAX BET] [spacer] [DEAL]
	_bottom_bar.add_child(_info_btn)
	_bottom_bar.move_child(_info_btn, _speed_btn.get_index())
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(spacer_l)
	_bottom_bar.move_child(spacer_l, _speed_btn.get_index() + 1)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(spacer_r)
	_bottom_bar.move_child(spacer_r, _bet_max_btn.get_index() + 1)
	# DOUBLE button before DEAL
	_bottom_bar.add_child(_double_btn)
	_bottom_bar.move_child(_double_btn, _deal_draw_btn.get_index())


# --- Speed ---

func _get_deal_ms() -> int:
	return SPEED_CONFIGS[_speed_level]["deal_ms"]

func _get_draw_ms() -> int:
	return SPEED_CONFIGS[_speed_level]["draw_ms"]

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
		arrows += ARROW_ACTIVE if i <= _speed_level else ARROW_INACTIVE
	_speed_btn.text = arrows + "\nSPEED"


# --- Cards ---

func _create_card_slots() -> void:
	for i in 5:
		var card_node: TextureRect = CardScene.instantiate()
		card_node.card_index = i
		card_node.clicked.connect(_on_card_clicked)
		_cards_container.add_child(card_node)
		_card_visuals.append(card_node)


func _layout_middle() -> void:
	# Wait one more frame so TopSection/BottomSection have final sizes
	await get_tree().process_frame
	var top_h: float = _top_section.size.y
	var bot_h: float = _bottom_section.size.y
	var total_h: float = size.y
	if total_h < 1:
		total_h = get_viewport_rect().size.y
	# Position MiddleSection between TopSection and BottomSection
	_middle_section.anchor_top = top_h / total_h
	_middle_section.anchor_bottom = 1.0 - (bot_h / total_h)
	_middle_section.anchor_left = 0.0
	_middle_section.anchor_right = 1.0
	_middle_section.offset_top = 0
	_middle_section.offset_bottom = 0
	_middle_section.offset_left = 0
	_middle_section.offset_right = 0
	# Wait another frame for MiddleSection to get its size
	await get_tree().process_frame
	_resize_cards()
	_position_status_label()


func _resize_cards() -> void:
	var mid_h: int = int(_middle_section.size.y)
	if mid_h < 10:
		mid_h = 400
	# Leave space for HELD labels above cards + TOTAL BET below
	var card_h: int = mid_h - 80
	# Card aspect ratio 136:184 = 0.739
	var card_w: int = int(card_h * 0.739)
	# Width constraint
	var gap := 18
	var max_w: int = int(size.x * 0.80)
	var total: int = card_w * 5 + gap * 4
	if total > max_w:
		card_w = (max_w - gap * 4) / 5
		card_h = int(card_w / 0.739)
	card_w = maxi(card_w, 60)
	card_h = maxi(card_h, 80)

	for card_vis in _card_visuals:
		card_vis.custom_minimum_size = Vector2(card_w, card_h)


func _position_status_label() -> void:
	await get_tree().process_frame
	var cards_rect := _cards_container.get_global_rect()
	var cards_center_x := cards_rect.get_center().x
	var info_bar_rect := _info_bar.get_global_rect()
	# Place label at InfoBar's Y, centered horizontally on cards
	_last_win_label.size = Vector2(400, 30)
	_last_win_label.global_position = Vector2(
		cards_center_x - 200,
		info_bar_rect.position.y
	)


# --- Display helpers ---

func _update_balance(credits: int) -> void:
	if _balance_show_depth:
		var depth := _calculate_game_depth()
		_balance_label.text = Translations.tr_key("game.games")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(depth), 0, Color(-1, 0, 0), false)
	else:
		_balance_label.text = Translations.tr_key("game.balance")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(credits), 0, Color(-1, 0, 0), true)


func _calculate_game_depth() -> int:
	var per_round: int = _game_manager.bet * SaveManager.denomination
	if per_round <= 0:
		return 0
	return SaveManager.credits / per_round


func _on_balance_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not SaveManager.depth_hint_shown:
			_show_depth_tooltip()
			SaveManager.depth_hint_shown = true
			SaveManager.save_game()
		_balance_show_depth = not _balance_show_depth
		_update_balance(SaveManager.credits)


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
	ps.bg_color = COL_BG
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
	msg.text = Translations.tr_key("game_depth.description_single")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)

	var ok_btn := Button.new()
	ok_btn.text = Translations.tr_key("common.got_it")
	var tex_y := load("res://assets/textures/btn_rect_yellow.svg")
	_style_button_texture(ok_btn, tex_y, COL_BTN_TEXT, 18, 140, 44)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(func() -> void:
		if _depth_tooltip:
			_depth_tooltip.queue_free()
			_depth_tooltip = null
	)
	vbox.add_child(ok_btn)

func _update_bet_display(bet: int) -> void:
	var total: int = bet * SaveManager.denomination
	SaveManager.set_currency_value(_bet_cd, SaveManager.format_short(total))
	_flash_bet_display()


func _flash_bet_display() -> void:
	if _bet_flash_tween:
		_bet_flash_tween.kill()
	SaveManager.set_currency_value(_bet_cd, "", 26, COL_YELLOW)
	_bet_flash_tween = create_tween()
	_bet_flash_tween.tween_interval(0.4)
	_bet_flash_tween.tween_callback(func() -> void:
		SaveManager.set_currency_value(_bet_cd, "", 22, Color.WHITE)
	)

var _last_win_amount: int = 0

func _set_status(text: String) -> void:
	_last_win_label.text = text
	_last_win_label.add_theme_color_override("font_color", COL_YELLOW)
	_last_win_label.modulate.a = 1.0
	# Smaller font for long status messages
	if text.length() > 15:
		_last_win_label.add_theme_font_size_override("font_size", 16)
	else:
		_last_win_label.add_theme_font_size_override("font_size", 20)

func _set_win_active(amount: int) -> void:
	_last_win_amount = amount
	_set_status("%s %s" % [Translations.tr_key("game.win_label"), SaveManager.format_short(amount)])

func _set_win_dimmed() -> void:
	_last_win_label.text = Translations.tr_key("game.last_win_fmt", [SaveManager.format_short(_last_win_amount)])
	_last_win_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
	_last_win_label.modulate.a = 0.7



# --- State changes ---

func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.IDLE:
			_deal_draw_btn.text = Translations.tr_key("game.deal")
			_bet_one_btn.disabled = false
			_bet_max_btn.disabled = false
			_deal_draw_btn.disabled = false
			_bet_amount_btn.disabled = false
			_double_btn.disabled = true
			_in_double = false
			_set_status(Translations.tr_key("game.place_your_bet"))
			for card_vis in _card_visuals:
				card_vis.set_interactive(false)
			_paytable_display.highlight_bet_column(_game_manager.bet)

		GameManager.State.DEALING:
			_deal_draw_btn.disabled = true
			_bet_one_btn.disabled = true
			_bet_max_btn.disabled = true
			_bet_amount_btn.disabled = true
			_set_win_dimmed()
			_paytable_display.highlight_bet_column(_game_manager.bet)

		GameManager.State.HOLDING:
			_deal_draw_btn.text = Translations.tr_key("game.draw")
			_deal_draw_btn.disabled = false
			_set_status(Translations.tr_key("game.hold_cards_then_draw"))
			for i in _card_visuals.size():
				_card_visuals[i].set_interactive(true)
				if _game_manager.held[i]:
					_card_visuals[i].set_held(true)
			var deal_rank := _variant.evaluate(_game_manager.hand)
			if deal_rank != HandEvaluator.HandRank.NOTHING:
				_highlight_paytable_row(deal_rank)

		GameManager.State.DRAWING:
			_deal_draw_btn.disabled = true
			for card_vis in _card_visuals:
				card_vis.set_interactive(false)

		GameManager.State.WIN_DISPLAY:
			_deal_draw_btn.text = Translations.tr_key("game.deal")
			# Buttons stay disabled until credit animation finishes
			_deal_draw_btn.disabled = true
			_bet_one_btn.disabled = true
			_bet_max_btn.disabled = true


func _on_cards_dealt(dealt_hand: Array[CardData]) -> void:
	_animating = true
	_hide_win_overlay()
	var instant := _get_flip_s() < 0.03
	# Flip face-up cards to back
	var any_face_up := false
	for i in 5:
		_card_visuals[i].set_flip_duration(_get_flip_s())
		if _card_visuals[i].face_up:
			any_face_up = true
			_card_visuals[i].flip_to_back()
			if not instant:
				await get_tree().create_timer(_get_deal_ms() / 1000.0).timeout
	if any_face_up and not instant:
		await get_tree().create_timer(0.08).timeout
	for i in 5:
		_card_visuals[i].set_flip_duration(_get_flip_s())
		_card_visuals[i].set_card(dealt_hand[i], true, _variant.is_wild_card(dealt_hand[i]))
		SoundManager.play("deal")
		if not instant and i < 4:
			await get_tree().create_timer(_get_deal_ms() / 1000.0).timeout
	# Wait for the last card's flip animation to finish before showing HELD
	if not instant:
		await get_tree().create_timer(_get_flip_s() * 2).timeout
	_animating = false
	_game_manager.on_deal_animation_complete()


func _on_deal_draw_pressed() -> void:
	if _animating:
		return
	if _game_manager.state == GameManager.State.HOLDING:
		_animating = true
		var instant := _get_flip_s() < 0.03
		# Flip non-held cards to back
		for i in 5:
			if not _game_manager.held[i]:
				_card_visuals[i].set_flip_duration(_get_flip_s())
				_card_visuals[i].flip_to_back()
				SoundManager.play("flip")
				if not instant:
					await get_tree().create_timer(_get_deal_ms() / 1000.0).timeout
		if not instant:
			await get_tree().create_timer(0.08).timeout
		_game_manager.draw()
		# Deal new cards
		for i in 5:
			if not _game_manager.held[i]:
				_card_visuals[i].set_flip_duration(_get_flip_s())
				_card_visuals[i].set_card(_game_manager.hand[i], true, _variant.is_wild_card(_game_manager.hand[i]))
				SoundManager.play("deal")
				if not instant:
					await get_tree().create_timer(_get_deal_ms() / 1000.0).timeout
		if not instant:
			await get_tree().create_timer(_get_flip_s() * 2).timeout
		_animating = false
		_game_manager.on_draw_animation_complete()
	else:
		_game_manager.deal_or_draw()


func _on_card_replaced(_index: int, _new_card: CardData) -> void:
	# Handled in _on_deal_draw_pressed now
	pass


func _on_hand_evaluated(hand_rank: int, hand_name: String, payout: int) -> void:
	if payout > 0:
		_set_win_active(payout)
		_show_win_overlay(hand_name)
		_highlight_paytable_row(hand_rank)
		_paytable_display.flash_winning_row()
	else:
		_paytable_display.clear_winning_row()
		_set_status(Translations.tr_key("game.no_win"))
		_show_lose_overlay()
		_delay_unlock_buttons()


var _credit_tween: Tween = null
var _displayed_credits: int = -1

func _on_credits_changed(new_credits: int) -> void:
	if _game_manager.state == GameManager.State.WIN_DISPLAY or _game_manager.state == GameManager.State.EVALUATING:
		# Animate credit roll-up over 2 seconds
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
	SaveManager.set_currency_value(_balance_cd, "", 22, COL_YELLOW)
	_credit_tween = create_tween()
	_credit_tween.tween_method(_update_credit_display, start, target, 1.0).set_ease(Tween.EASE_OUT)
	_credit_tween.tween_callback(_on_credit_animation_done)


func _update_credit_display(value: int) -> void:
	_displayed_credits = value
	if _balance_show_depth:
		var per_round: int = _game_manager.bet * SaveManager.denomination
		var depth := (value / per_round) if per_round > 0 else 0
		_balance_label.text = Translations.tr_key("game.games")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(depth), 0, Color(-1, 0, 0), false)
	else:
		_balance_label.text = Translations.tr_key("game.balance")
		SaveManager.set_currency_value(_balance_cd, SaveManager.format_money(value), 0, Color(-1, 0, 0), true)


func _on_credit_animation_done() -> void:
	SaveManager.set_currency_value(_balance_cd, "", 18, Color.WHITE)
	_unlock_buttons()
	if _game_manager.last_win > 0:
		_double_btn.disabled = false
		_double_amount = _game_manager.last_win


func _delay_unlock_buttons() -> void:
	await get_tree().create_timer(0.5).timeout
	_unlock_buttons()


func _unlock_buttons() -> void:
	_deal_draw_btn.disabled = false
	_bet_one_btn.disabled = false
	_bet_max_btn.disabled = false

func _on_bet_changed(new_bet: int) -> void:
	_update_bet_display(new_bet)
	_paytable_display.highlight_bet_column(new_bet)
	_bet_one_btn.text = Translations.tr_key("game.bet_one_fmt", [new_bet])
	if _balance_show_depth:
		_update_balance(SaveManager.credits)


func _on_bet_max_pressed() -> void:
	if _game_manager.state != GameManager.State.IDLE and _game_manager.state != GameManager.State.WIN_DISPLAY:
		return
	if _game_manager.state == GameManager.State.WIN_DISPLAY:
		_game_manager._to_idle()
	var old_bet := _game_manager.bet
	_game_manager.bet = GameManager.MAX_BET
	_game_manager.bet_changed.emit(_game_manager.bet)
	SoundManager.play("bet")
	# Sweep animation, then deal after it finishes
	_paytable_display.sweep_to_max(old_bet)
	await _paytable_display.sweep_finished
	_game_manager.deal()


func _on_paytable_bet_clicked(bet: int) -> void:
	if _game_manager.state != GameManager.State.IDLE and _game_manager.state != GameManager.State.WIN_DISPLAY:
		return
	if _game_manager.state == GameManager.State.WIN_DISPLAY:
		_game_manager._to_idle()
	_game_manager.bet = bet
	SaveManager.bet_level = bet
	SaveManager.save_game()
	_game_manager.bet_changed.emit(bet)




func _highlight_paytable_row(hand_rank: int) -> void:
	var hand_keys := _variant.paytable.get_hand_order()
	var key: String = _variant.get_paytable_key(hand_rank)
	var row_idx := hand_keys.find(key)
	if row_idx >= 0:
		_paytable_display.highlight_winning_row(row_idx)


# --- Win overlay ---

var _win_overlay: PanelContainer = null
var _win_overlay_label: Label = null
var _win_overlay_winnings_row: HBoxContainer = null
var _win_overlay_tween: Tween = null
var _win_overlay_showing_name: bool = true

func _create_overlay(text: String) -> void:
	_hide_win_overlay()

	_win_overlay = PanelContainer.new()

	var msg_bar_path := "res://assets/textures/MessegBar.svg"
	if ResourceLoader.exists(msg_bar_path):
		var tex := load(msg_bar_path) as Texture2D
		var style := StyleBoxTexture.new()
		style.texture = tex
		style.texture_margin_left = 16
		style.texture_margin_right = 16
		style.texture_margin_top = 8
		style.texture_margin_bottom = 8
		style.content_margin_left = 60
		style.content_margin_right = 60
		style.content_margin_top = 16
		style.content_margin_bottom = 16
		_win_overlay.add_theme_stylebox_override("panel", style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.0, 0.3, 0.9)
		style.set_border_width_all(3)
		style.border_color = COL_YELLOW
		style.set_corner_radius_all(8)
		style.content_margin_left = 60
		style.content_margin_right = 60
		style.content_margin_top = 16
		style.content_margin_bottom = 16
		_win_overlay.add_theme_stylebox_override("panel", style)

	var content_box := VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 0)
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_win_overlay.add_child(content_box)

	_win_overlay_label = Label.new()
	_win_overlay_label.text = text
	_win_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_overlay_label.add_theme_font_size_override("font_size", 42)
	_win_overlay_label.add_theme_color_override("font_color", COL_YELLOW)
	content_box.add_child(_win_overlay_label)

	# Winnings row: "WINNINGS:" + currency glyphs (hidden initially)
	_win_overlay_winnings_row = HBoxContainer.new()
	_win_overlay_winnings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_win_overlay_winnings_row.add_theme_constant_override("separation", 8)
	_win_overlay_winnings_row.visible = false
	var w_label := Label.new()
	w_label.text = Translations.tr_key("game.winnings")
	w_label.add_theme_font_size_override("font_size", 42)
	w_label.add_theme_color_override("font_color", COL_YELLOW)
	_win_overlay_winnings_row.add_child(w_label)
	var w_cd := SaveManager.create_currency_display(38, COL_YELLOW)
	SaveManager.set_currency_value(w_cd, SaveManager.format_short(_last_win_amount))
	_win_overlay_winnings_row.add_child(w_cd["box"])
	content_box.add_child(_win_overlay_winnings_row)

	_win_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_overlay.modulate.a = 0.0
	add_child(_win_overlay)

	await get_tree().process_frame
	_position_overlay()
	_win_overlay.modulate.a = 1.0


func _position_overlay() -> void:
	if not _win_overlay:
		return
	var cards_rect := _cards_container.get_global_rect()
	var cards_center := cards_rect.get_center()
	var overlay_size := _win_overlay.get_combined_minimum_size()
	_win_overlay.position = Vector2(
		cards_center.x - overlay_size.x / 2,
		cards_center.y - overlay_size.y / 2
	)


func _show_win_overlay(hand_name: String) -> void:
	_win_overlay_showing_name = true
	_create_overlay(hand_name)

	await get_tree().process_frame
	_win_overlay_tween = create_tween().set_loops()
	# Alternate: hand name 2s → fade → winnings 2s → fade → repeat
	_win_overlay_tween.tween_interval(2.0)
	_win_overlay_tween.tween_property(_win_overlay, "modulate:a", 0.0, 0.15)
	_win_overlay_tween.tween_callback(_cycle_overlay_text)
	_win_overlay_tween.tween_property(_win_overlay, "modulate:a", 1.0, 0.15)
	_win_overlay_tween.tween_interval(2.0)
	_win_overlay_tween.tween_property(_win_overlay, "modulate:a", 0.0, 0.15)
	_win_overlay_tween.tween_callback(_cycle_overlay_text)
	_win_overlay_tween.tween_property(_win_overlay, "modulate:a", 1.0, 0.15)


func _show_lose_overlay() -> void:
	_create_overlay(Translations.tr_key("game.try_again"))
	# Blink: visible 2s, hidden 1s
	await get_tree().process_frame
	if _win_overlay:
		_win_overlay_tween = create_tween().set_loops()
		_win_overlay_tween.tween_interval(2.0)
		_win_overlay_tween.tween_property(_win_overlay, "modulate:a", 0.0, 0.15)
		_win_overlay_tween.tween_interval(0.7)
		_win_overlay_tween.tween_property(_win_overlay, "modulate:a", 1.0, 0.15)


func _cycle_overlay_text() -> void:
	_win_overlay_showing_name = not _win_overlay_showing_name
	if _win_overlay_label and _win_overlay_winnings_row:
		_win_overlay_label.visible = _win_overlay_showing_name
		_win_overlay_winnings_row.visible = not _win_overlay_showing_name
		_position_overlay()


func _hide_win_overlay() -> void:
	if _win_overlay_tween:
		_win_overlay_tween.kill()
		_win_overlay_tween = null
	if _win_overlay:
		_win_overlay.queue_free()
		_win_overlay = null
	_win_overlay_label = null


# --- Bet Amount Picker ---

const MIN_GAME_DEPTH := 30

func _recommend_denomination() -> int:
	var balance := SaveManager.credits
	var best: int = BET_AMOUNTS[0]
	for amount in BET_AMOUNTS:
		# worst case total_bet = denomination * max_bet * hands
		if balance / (amount * GameManager.MAX_BET) >= MIN_GAME_DEPTH:
			best = amount
		else:
			break
	return best


var _bet_btn_cd: Dictionary

func _update_bet_amount_btn() -> void:
	_bet_amount_btn.text = ""
	_bet_amount_btn.icon = null
	if _bet_btn_cd.is_empty():
		_bet_btn_cd = SaveManager.create_currency_display(20, Color.WHITE)
		_bet_btn_cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bet_btn_cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		_bet_amount_btn.add_child(_bet_btn_cd["box"])
	SaveManager.set_currency_value(_bet_btn_cd, SaveManager.format_auto(_current_denomination, 118, 20))

func _on_bet_amount_pressed() -> void:
	if _game_manager.state != GameManager.State.IDLE and _game_manager.state != GameManager.State.WIN_DISPLAY:
		return
	_show_bet_picker()

func _on_back_pressed() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("000086")
	ps.set_border_width_all(3)
	ps.border_color = Color.WHITE
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
	msg.text = Translations.tr_key("game.exit_confirm")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)
	var tex_y := load("res://assets/textures/btn_rect_yellow.svg")
	var tex_g := load("res://assets/textures/btn_rect_green.svg")
	var stay_btn := Button.new()
	stay_btn.text = Translations.tr_key("game.exit_stay")
	_style_button_texture(stay_btn, tex_g, Color.WHITE, 20, 120, 44)
	stay_btn.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(stay_btn)
	var leave_btn := Button.new()
	leave_btn.text = Translations.tr_key("game.exit_leave")
	_style_button_texture(leave_btn, tex_y, COL_BTN_TEXT, 20, 120, 44)
	leave_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		back_to_lobby.emit()
	)
	btns.add_child(leave_btn)


func _show_bet_picker() -> void:
	_hide_bet_picker()

	_bet_picker_overlay = Control.new()
	_bet_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bet_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bet_picker_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_bet_picker()
	)
	_bet_picker_overlay.add_child(dim)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("000086")
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color.WHITE
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
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
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	var tex_yellow := load("res://assets/textures/btn_rect_yellow.svg")

	for amount in BET_AMOUNTS:
		var btn := Button.new()
		btn.text = ""
		_style_button_texture(btn, tex_yellow, COL_BTN_TEXT, 22, 140, 50)
		var cd := SaveManager.create_currency_display(20, COL_BTN_TEXT)
		cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		SaveManager.set_currency_value(cd, SaveManager.format_auto(amount, 108, 20))
		cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(cd["box"])
		btn.pressed.connect(func() -> void:
			_select_denomination(amount)
		)
		grid.add_child(btn)

func _select_denomination(amount: int) -> void:
	_current_denomination = amount
	SaveManager.denomination = amount
	_update_bet_amount_btn()
	_update_bet_display(_game_manager.bet)
	_bet_one_btn.text = Translations.tr_key("game.bet_one_fmt", [_game_manager.bet])
	_hide_bet_picker()

func _hide_bet_picker() -> void:
	if _bet_picker_overlay:
		_bet_picker_overlay.queue_free()
		_bet_picker_overlay = null


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
	panel_style.bg_color = COL_BG
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
		_style_button_texture(buy_btn, tex_green, Color.WHITE, 16, 120, 36)
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
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 20
	scroll.offset_bottom = -20
	_info_overlay.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
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
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(_hide_info)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	content.add_child(close_btn)

	# Title
	var title := Label.new()
	title.text = Translations.tr_key("info.title_single")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_YELLOW)
	content.add_child(title)

	# Rules — centered with left margin
	var rules_margin := MarginContainer.new()
	rules_margin.add_theme_constant_override("margin_left", 120)
	rules_margin.add_theme_constant_override("margin_right", 120)
	content.add_child(rules_margin)
	var rules := Label.new()
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD
	rules.add_theme_font_size_override("font_size", 18)
	rules.add_theme_color_override("font_color", Color.WHITE)
	rules.text = Translations.tr_key("info.rules_single")
	rules_margin.add_child(rules)

	# Machines title
	var machines_title := Label.new()
	machines_title.text = Translations.tr_key("info.machines_title")
	machines_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machines_title.add_theme_font_size_override("font_size", 24)
	machines_title.add_theme_color_override("font_color", COL_YELLOW)
	content.add_child(machines_title)

	# Machines table
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 20)
	table.add_theme_constant_override("v_separation", 6)
	content.add_child(table)

	var bold := SystemFont.new()
	bold.font_weight = 700
	for header_key in ["info.col_machine", "info.col_deck", "info.col_rtp", "info.col_feature"]:
		var lbl := Label.new()
		lbl.text = Translations.tr_key(header_key)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", COL_YELLOW)
		lbl.add_theme_font_override("font", bold)
		table.add_child(lbl)

	# Variant ID + deck/rtp/feature key triplets — names and feature texts
	# come from translations, deck/rtp are stable enough to inline.
	var rows := [
		["jacks_or_better",    "52",          "99.54%"],
		["bonus_poker",        "52",          "99.17%"],
		["bonus_poker_deluxe", "52",          "99.64%"],
		["double_bonus",       "52",          "100.17%"],
		["double_double_bonus","52",          "100.07%"],
		["triple_double_bonus","52",          "99.58%"],
		["aces_and_faces",     "52",          "99.26%"],
		["deuces_wild",        "52",          "99.73%"],
		["joker_poker",        "53 +Joker",   "100.65%"],
		["deuces_and_joker",   "53 +Joker",   "99.07%"],
	]
	for row in rows:
		var vid: String = row[0]
		var cells := [
			Translations.tr_key("machine.%s.name" % vid),
			row[1],
			row[2],
			Translations.tr_key("machine.%s.feature" % vid),
		]
		for i in cells.size():
			var lbl := Label.new()
			lbl.text = cells[i]
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			if i == 3:
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				lbl.custom_minimum_size.x = 250
			table.add_child(lbl)


func _hide_info() -> void:
	if _info_overlay:
		_info_overlay.queue_free()
		_info_overlay = null


# --- Double or Nothing ---

var _double_overlay: Control = null
var _double_cards: Array = []  # 5 cards for double round
var _double_dealer_card: CardData = null

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
	add_child(_double_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_double_overlay.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = COL_BG
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
	_style_button_texture(no_btn, tex_yellow, COL_BTN_TEXT, 22, 120, 50)
	no_btn.pressed.connect(func() -> void:
		_hide_double_overlay()
	)
	btns.add_child(no_btn)

	var yes_btn := Button.new()
	yes_btn.text = Translations.tr_key("common.yes")
	_style_button_texture(yes_btn, tex_green, Color.WHITE, 22, 120, 50)
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
	_bet_one_btn.disabled = true
	_bet_max_btn.disabled = true

	# Deduct winnings from balance (player risks them)
	SaveManager.deduct_credits(_double_amount)
	_update_balance(SaveManager.credits)

	# Build a fresh 52-card deck (no jokers, no wilds)
	var deck := Deck.new(52)
	_double_cards = deck.deal_hand()  # 5 cards
	_double_dealer_card = _double_cards[0]

	_hide_win_overlay()
	_set_status(Translations.tr_key("double.pick_card"))

	# Show: dealer card face-up, 4 player cards face-down
	for i in 5:
		_card_visuals[i].set_flip_duration(0.15)
		_card_visuals[i].set_held(false)
		if i == 0:
			_card_visuals[i].set_card(_double_cards[i], true)
		else:
			_card_visuals[i].show_back()
			_card_visuals[i].set_interactive(true)


func _on_card_clicked(card_index: int) -> void:
	if _in_double:
		_on_double_card_picked(card_index)
		return
	_game_manager.toggle_hold(card_index)
	_card_visuals[card_index].set_held(_game_manager.held[card_index])


func _on_double_card_picked(index: int) -> void:
	if index == 0:
		return  # Can't pick dealer card
	# Disable all cards
	for i in 5:
		_card_visuals[i].set_interactive(false)

	# Reveal picked card
	var card: CardData = _double_cards[index]
	_card_visuals[index].set_card(card, true)
	await get_tree().create_timer(0.5).timeout

	var player_rank: int = card.rank as int
	var dealer_rank: int = _double_dealer_card.rank as int

	if player_rank > dealer_rank:
		# Win — double the amount
		_double_amount *= 2
		SaveManager.add_credits(_double_amount)
		_displayed_credits = SaveManager.credits - _double_amount
		_animate_credits(SaveManager.credits)
		_set_status(Translations.tr_key("double.win_doubled_fmt", [SaveManager.format_money(_double_amount)]))
		await _credit_tween.finished
		_double_btn.disabled = false
		_deal_draw_btn.disabled = false
		_bet_one_btn.disabled = false
		_bet_max_btn.disabled = false
	elif player_rank == dealer_rank:
		# Tie — return original amount
		SaveManager.add_credits(_double_amount)
		_displayed_credits = SaveManager.credits - _double_amount
		_animate_credits(SaveManager.credits)
		_set_status(Translations.tr_key("double.tie"))
		_double_amount = 0
		await _credit_tween.finished
		_end_double()
	else:
		# Lose
		_set_status(Translations.tr_key("double.lose"))
		_double_amount = 0
		_end_double()


func _end_double() -> void:
	await get_tree().create_timer(1.0).timeout
	_double_btn.disabled = true
	_deal_draw_btn.disabled = false
	_bet_one_btn.disabled = false
	_bet_max_btn.disabled = false
	_in_double = false


func _hide_double_overlay() -> void:
	if _double_overlay:
		_double_overlay.queue_free()
		_double_overlay = null
