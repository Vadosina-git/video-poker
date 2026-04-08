extends Control

signal back_to_lobby

var CardScene: PackedScene

@onready var _paytable_display: PanelContainer = %PaytableDisplay
@onready var _cards_container: HBoxContainer = %CardsContainer
@onready var _hud: HBoxContainer = %HUD
@onready var _bet_one_btn: Button = %BetOneButton
@onready var _bet_max_btn: Button = %BetMaxButton
@onready var _deal_draw_btn: Button = %DealDrawButton
@onready var _message_label: Label = %MessageLabel
@onready var _back_button: Button = %BackButton
@onready var _game_title: Label = %GameTitle

var _game_manager: GameManager
var _card_visuals: Array = []
var _deal_speed_ms: int = 100
var _draw_speed_ms: int = 150
var _variant: BaseVariant


func setup(variant: BaseVariant) -> void:
	_variant = variant


func _ready() -> void:
	if _variant == null:
		return
	CardScene = load("res://scenes/card.tscn")
	_load_config()

	_game_manager = GameManager.new()
	add_child(_game_manager)
	_game_manager.setup(_variant)

	_game_manager.state_changed.connect(_on_state_changed)
	_game_manager.cards_dealt.connect(_on_cards_dealt)
	_game_manager.card_replaced.connect(_on_card_replaced)
	_game_manager.hand_evaluated.connect(_on_hand_evaluated)
	_game_manager.credits_changed.connect(_on_credits_changed)
	_game_manager.bet_changed.connect(_on_bet_changed)

	_bet_one_btn.pressed.connect(_game_manager.bet_one)
	_bet_max_btn.pressed.connect(_game_manager.bet_max)
	_deal_draw_btn.pressed.connect(_on_deal_draw_pressed)
	_back_button.pressed.connect(func() -> void: back_to_lobby.emit())

	_paytable_display.setup(_variant.paytable)
	_game_title.text = _variant.paytable.name.to_upper()

	_create_card_slots()

	_hud.update_credits(SaveManager.credits, false)
	_hud.update_bet(_game_manager.bet)
	_hud.clear_win()
	_message_label.text = "PLACE YOUR BET"


func _load_config() -> void:
	var file := FileAccess.open("res://data/config.json", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var config: Dictionary = json.data
	_deal_speed_ms = int(config.get("deal_speed_ms", 100))
	_draw_speed_ms = int(config.get("draw_speed_ms", 150))


func _create_card_slots() -> void:
	for i in 5:
		var card_node: PanelContainer = CardScene.instantiate()
		card_node.card_index = i
		card_node.clicked.connect(_on_card_clicked)
		_cards_container.add_child(card_node)
		_card_visuals.append(card_node)


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.IDLE:
			_deal_draw_btn.text = "DEAL"
			_bet_one_btn.disabled = false
			_bet_max_btn.disabled = false
			_deal_draw_btn.disabled = false
			_message_label.text = "PLACE YOUR BET"
			_hud.clear_win()
			for card_vis in _card_visuals:
				card_vis.set_interactive(false)
				card_vis.show_back()
			_paytable_display.highlight_bet_column(_game_manager.bet)

		GameManager.State.DEALING:
			_deal_draw_btn.disabled = true
			_bet_one_btn.disabled = true
			_bet_max_btn.disabled = true
			_message_label.text = ""

		GameManager.State.HOLDING:
			_deal_draw_btn.text = "DRAW"
			_deal_draw_btn.disabled = false
			_message_label.text = "HOLD CARDS, THEN DRAW"
			for i in _card_visuals.size():
				_card_visuals[i].set_interactive(true)
				# Show held state for auto-hold (Royal Flush)
				if _game_manager.held[i]:
					_card_visuals[i].set_held(true)

		GameManager.State.DRAWING:
			_deal_draw_btn.disabled = true
			for card_vis in _card_visuals:
				card_vis.set_interactive(false)

		GameManager.State.WIN_DISPLAY:
			_deal_draw_btn.text = "DEAL"
			_deal_draw_btn.disabled = false
			_bet_one_btn.disabled = false
			_bet_max_btn.disabled = false


func _on_cards_dealt(dealt_hand: Array[CardData]) -> void:
	for i in 5:
		_card_visuals[i].set_card(dealt_hand[i], true)
		SoundManager.play("deal")
		if i < 4:
			await get_tree().create_timer(_deal_speed_ms / 1000.0).timeout
	_game_manager.on_deal_animation_complete()


func _on_deal_draw_pressed() -> void:
	if _game_manager.state == GameManager.State.HOLDING:
		# Handle draw with animation timing
		_game_manager.draw()
		# Wait for draw animations, then evaluate
		await get_tree().create_timer(_draw_speed_ms / 1000.0 * 2).timeout
		_game_manager.on_draw_animation_complete()
	else:
		_game_manager.deal_or_draw()


func _on_card_replaced(index: int, new_card: CardData) -> void:
	_card_visuals[index].replace_card(new_card)
	SoundManager.play("flip")


func _on_hand_evaluated(hand_rank: int, hand_name: String, payout: int) -> void:
	if payout > 0:
		_message_label.text = hand_name
		_hud.update_win(payout)

		var hand_keys := _variant.paytable.get_hand_order()
		var key: String = Paytable.STANDARD_HAND_KEYS.get(hand_rank, "")
		var row_idx := hand_keys.find(key)
		if row_idx >= 0:
			_paytable_display.highlight_winning_row(row_idx)
			_paytable_display.flash_winning_row()
	else:
		_message_label.text = "NO WIN"


func _on_credits_changed(new_credits: int) -> void:
	_hud.update_credits(new_credits)


func _on_bet_changed(new_bet: int) -> void:
	_hud.update_bet(new_bet)
	_paytable_display.highlight_bet_column(new_bet)


func _on_card_clicked(card_index: int) -> void:
	_game_manager.toggle_hold(card_index)
	_card_visuals[card_index].set_held(_game_manager.held[card_index])
