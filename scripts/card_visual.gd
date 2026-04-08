extends PanelContainer

signal clicked(card_index: int)

var card_data: CardData = null
var card_index: int = 0
var held: bool = false
var face_up: bool = false

@onready var _rank_top: Label = %RankTop
@onready var _suit_center: Label = %SuitCenter
@onready var _rank_bottom: Label = %RankBottom
@onready var _held_label: Label = %HeldLabel
@onready var _card_back: ColorRect = %CardBack

var _style_normal: StyleBoxFlat
var _style_held: StyleBoxFlat
var _interactive: bool = false
var _base_position_y: float = 0.0


func _ready() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color.WHITE
	_style_normal.set_corner_radius_all(8)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.4, 0.4, 0.4)

	_style_held = _style_normal.duplicate()
	_style_held.border_color = Color(1.0, 0.85, 0.0)
	_style_held.set_border_width_all(4)

	add_theme_stylebox_override("panel", _style_normal)
	custom_minimum_size = Vector2(180, 252)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	gui_input.connect(_on_gui_input)
	show_back()


func set_card(p_card: CardData, animate: bool = false) -> void:
	card_data = p_card
	face_up = true
	held = false
	_update_display()
	if animate:
		_play_flip_in()


func show_back() -> void:
	card_data = null
	face_up = false
	held = false
	_update_display()


func set_held(value: bool) -> void:
	held = value
	_update_display()


func set_interactive(value: bool) -> void:
	_interactive = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func replace_card(new_card: CardData) -> void:
	card_data = new_card
	face_up = true
	_update_display()
	_play_flip_in()


func _update_display() -> void:
	if not is_node_ready():
		return

	_held_label.visible = held
	_card_back.visible = not face_up

	if card_data and face_up:
		var color := Color.RED if card_data.is_red() else Color.BLACK
		_rank_top.text = card_data.get_rank_symbol()
		_rank_top.add_theme_color_override("font_color", color)
		_suit_center.text = card_data.get_suit_symbol()
		_suit_center.add_theme_color_override("font_color", color)
		_rank_bottom.text = card_data.get_rank_symbol()
		_rank_bottom.add_theme_color_override("font_color", color)
		_rank_top.visible = true
		_suit_center.visible = true
		_rank_bottom.visible = true
	else:
		_rank_top.visible = false
		_suit_center.visible = false
		_rank_bottom.visible = false

	add_theme_stylebox_override("panel", _style_held if held else _style_normal)


func _play_flip_in() -> void:
	var tween := create_tween()
	pivot_offset = size / 2
	scale.x = 0.0
	tween.tween_property(self, "scale:x", 1.0, 0.15).set_ease(Tween.EASE_OUT)


func _on_gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if face_up:
			clicked.emit(card_index)
