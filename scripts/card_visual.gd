extends TextureRect

signal clicked(card_index: int)

var card_data: CardData = null
var card_index: int = 0
var held: bool = false
var wild: bool = false
var face_up: bool = false
var _interactive: bool = false

var _card_back_texture: Texture2D
var _held_label: Control

const SUIT_CODES := {
	CardData.Suit.HEARTS: "h",
	CardData.Suit.DIAMONDS: "d",
	CardData.Suit.CLUBS: "c",
	CardData.Suit.SPADES: "s",
}

const RANK_CODES := {
	CardData.Rank.TWO: "2", CardData.Rank.THREE: "3", CardData.Rank.FOUR: "4",
	CardData.Rank.FIVE: "5", CardData.Rank.SIX: "6", CardData.Rank.SEVEN: "7",
	CardData.Rank.EIGHT: "8", CardData.Rank.NINE: "9", CardData.Rank.TEN: "10",
	CardData.Rank.JACK: "j", CardData.Rank.QUEEN: "q", CardData.Rank.KING: "k",
	CardData.Rank.ACE: "a",
}


func _ready() -> void:
	# Don't override custom_minimum_size — let it be set externally
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(180, 252)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	gui_input.connect(_on_gui_input)

	# Load card back
	_card_back_texture = load("res://assets/cards/card_back.png")

	# Create HELD indicator
	var held_container := Control.new()
	held_container.visible = false
	held_container.custom_minimum_size = Vector2(73, 24)
	add_child(held_container)
	_held_label = held_container
	_held_position = "top"
	resized.connect(_reposition_held)

	# Background: held_rect.svg
	var held_tex_rect := TextureRect.new()
	var held_tex_path := "res://assets/textures/held_rect.svg"
	if ResourceLoader.exists(held_tex_path):
		held_tex_rect.texture = load(held_tex_path)
	held_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	held_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	held_tex_rect.set_anchors_preset(Control.PRESET_CENTER)
	held_tex_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	held_tex_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	held_tex_rect.custom_minimum_size = Vector2(73, 24)
	held_container.add_child(held_tex_rect)

	# Text "HELD" on top
	var held_text := Label.new()
	held_text.text = Translations.tr_key("game.held")
	held_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	held_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	held_text.add_theme_font_size_override("font_size", 16)
	held_text.add_theme_color_override("font_color", Color("3F2A00"))
	held_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	held_container.add_child(held_text)

	show_back()


func _get_card_texture_path() -> String:
	if card_data == null:
		return ""
	if card_data.is_joker():
		var joker_path := "res://assets/cards/card_vp_joker_red.png"
		if ResourceLoader.exists(joker_path):
			return joker_path
		return "res://assets/cards/card_vp_joker_black.png"
	# Wild deuces use special wild sprites
	if wild and card_data.rank == CardData.Rank.TWO:
		var suit_code: String = SUIT_CODES.get(card_data.suit, "")
		return "res://assets/cards/card_vp_wild%s.png" % suit_code
	var rank_code: String = RANK_CODES.get(card_data.rank, "")
	var suit_code: String = SUIT_CODES.get(card_data.suit, "")
	return "res://assets/cards/card_vp_%s%s.png" % [rank_code, suit_code]


func set_card(p_card: CardData, animate: bool = false, p_wild: bool = false) -> void:
	card_data = p_card
	face_up = true
	held = false
	wild = p_wild
	_update_display()
	if animate:
		_play_flip_in()


func show_back() -> void:
	card_data = null
	face_up = false
	held = false
	wild = false
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

	var was_visible: bool = _held_label.visible
	_held_label.visible = held
	# Hold badge pop (anim 5.4) — quick bounce when transitioning to visible
	if held and not was_visible:
		_held_label.pivot_offset = _held_label.size * 0.5
		var tw := _held_label.create_tween()
		tw.tween_property(_held_label, "scale", Vector2(1.25, 1.25), 0.09) \
			.from(Vector2(0.6, 0.6)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_held_label, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)

	if card_data and face_up:
		var path := _get_card_texture_path()
		if ResourceLoader.exists(path):
			texture = load(path)
		else:
			texture = _card_back_texture
	else:
		texture = _card_back_texture


var _flip_duration: float = 0.15

func set_flip_duration(duration: float) -> void:
	_flip_duration = duration

func _play_flip_in() -> void:
	if _flip_duration < 0.03:
		scale.x = 1.0
		return
	# Save the face texture, show back first, then animate flip
	var face_tex: Texture2D = texture
	texture = _card_back_texture
	var tween := create_tween()
	pivot_offset = size / 2
	scale.x = 1.0
	# Phase 1: shrink back side
	tween.tween_property(self, "scale:x", 0.0, _flip_duration).set_ease(Tween.EASE_IN)
	# Phase 2: swap to face texture at scale 0
	tween.tween_callback(func() -> void:
		texture = face_tex
	)
	# Phase 3: expand face side
	tween.tween_property(self, "scale:x", 1.0, _flip_duration).set_ease(Tween.EASE_OUT)


func flip_to_back() -> void:
	if not face_up:
		return
	if _flip_duration < 0.03:
		# Instant
		face_up = false
		held = false
		wild = false
		card_data = null
		_update_display()
		return
	var tween := create_tween()
	pivot_offset = size / 2
	tween.tween_property(self, "scale:x", 0.0, _flip_duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		face_up = false
		held = false
		wild = false
		card_data = null
		_update_display()
	)
	tween.tween_property(self, "scale:x", 1.0, _flip_duration).set_ease(Tween.EASE_OUT)


func _play_press() -> void:
	var tween := create_tween()
	pivot_offset = size / 2
	tween.tween_property(self, "scale", Vector2(0.93, 0.93), 0.06)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)


var _held_position: String = "top"

func set_held_top() -> void:
	_held_position = "top"
	_reposition_held()

func set_held_bottom() -> void:
	_held_position = "bottom"
	_reposition_held()

func _reposition_held() -> void:
	if not _held_label:
		return
	var s := size
	if s.y < 1:
		return

	# TextureRect with KEEP_ASPECT_CENTERED: find actual visible card rect
	var tex := texture
	var vis_w := s.x
	var vis_h := s.y
	if tex:
		var tex_size := tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var scale_x := s.x / tex_size.x
			var scale_y := s.y / tex_size.y
			var sc := minf(scale_x, scale_y)
			vis_w = tex_size.x * sc
			vis_h = tex_size.y * sc

	var offset_x := (s.x - vis_w) / 2.0
	var offset_y := (s.y - vis_h) / 2.0

	var held_w := minf(73.0, vis_w * 0.6)
	var held_h := 24.0
	var x := offset_x + (vis_w - held_w) / 2.0

	if _held_position == "top":
		_held_label.position = Vector2(x, offset_y - 2)
	else:
		_held_label.position = Vector2(x, offset_y + vis_h - held_h + 2)
	_held_label.size = Vector2(held_w, held_h)


func _on_gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_play_press()
			clicked.emit(card_index)
