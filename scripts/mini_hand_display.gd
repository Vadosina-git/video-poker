class_name MiniHandDisplay
extends HBoxContainer

## Displays 5 small card textures in a row for multi-hand view.

var _card_textures: Array[TextureRect] = []
var _face_up: Array[bool] = [false, false, false, false, false]
var _variant: BaseVariant = null

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


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 5:
		var tex := TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(28, 40)
		_card_textures.append(tex)
		add_child(tex)


func set_card_size(w: int, h: int) -> void:
	for tex in _card_textures:
		tex.custom_minimum_size = Vector2(w, h)


func show_hand(hand: Array[CardData]) -> void:
	for i in 5:
		if i < hand.size():
			var path := _get_card_path(hand[i])
			if ResourceLoader.exists(path):
				_card_textures[i].texture = load(path)


func show_back() -> void:
	_face_up = [false, false, false, false, false]
	var back_path := "res://assets/cards/card_back.png"
	if ResourceLoader.exists(back_path):
		var back_tex := load(back_path)
		for tex in _card_textures:
			tex.texture = back_tex


func is_face_up_at(index: int) -> bool:
	return _face_up[index] if index < _face_up.size() else false

func show_card_at(index: int, card: CardData, animate: bool = true) -> void:
	if index >= _card_textures.size():
		return
	_face_up[index] = true
	var tex := _card_textures[index]
	var path := _get_card_path(card)
	if animate:
		# Phase 1: shrink rубашка to 0 (visible flip of back side)
		# Phase 2: swap texture to face
		# Phase 3: expand face from 0 to 1
		var tween := tex.create_tween()
		tex.pivot_offset = tex.size / 2
		tex.scale.x = 1.0
		tween.tween_property(tex, "scale:x", 0.0, 0.1).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if ResourceLoader.exists(path):
				tex.texture = load(path)
		)
		tween.tween_property(tex, "scale:x", 1.0, 0.1).set_ease(Tween.EASE_OUT)
	else:
		if ResourceLoader.exists(path):
			tex.texture = load(path)


func show_back_at(index: int, animate: bool = true) -> void:
	if index >= _card_textures.size():
		return
	_face_up[index] = false
	var tex := _card_textures[index]
	var back_path := "res://assets/cards/card_back.png"
	if animate:
		var tween := tex.create_tween()
		tex.pivot_offset = tex.size / 2
		tex.scale.x = 1.0
		tween.tween_property(tex, "scale:x", 0.0, 0.1).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if ResourceLoader.exists(back_path):
				tex.texture = load(back_path)
		)
		tween.tween_property(tex, "scale:x", 1.0, 0.1).set_ease(Tween.EASE_OUT)
	else:
		if ResourceLoader.exists(back_path):
			tex.texture = load(back_path)


var _result_overlay: PanelContainer = null
var _overlay_parent: Control = null  # Set externally by multi_hand_game.gd

var _is_losing: bool = false

func show_result(hand_name: String, multiplier: int, badge_color: Color = Color("FFEC00")) -> void:
	hide_result()
	if hand_name == "":
		_is_losing = true
		return
	_is_losing = false
	modulate = Color.WHITE
	_result_overlay = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.15, 0.85)
	style.set_border_width_all(2)
	style.border_color = badge_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_result_overlay.add_theme_stylebox_override("panel", style)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = "%s\nX%d" % [hand_name, multiplier]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	_result_overlay.add_child(label)

	# Add to game scene (not tree root!) so it's cleaned up on scene exit
	var parent: Control = _overlay_parent if _overlay_parent else self
	parent.add_child(_result_overlay)
	_position_result_overlay.call_deferred()


func _position_result_overlay() -> void:
	if not _result_overlay or not is_inside_tree():
		return
	var my_rect := get_global_rect()
	var center := my_rect.get_center()
	var ov_size := _result_overlay.get_combined_minimum_size()
	_result_overlay.position = Vector2(
		center.x - ov_size.x / 2,
		center.y - ov_size.y / 2 + my_rect.size.y * 0.1
	)


func _exit_tree() -> void:
	hide_result()


func set_result_alpha(alpha: float) -> void:
	if _result_overlay:
		_result_overlay.modulate.a = alpha


var _win_mask: Array[bool] = [false, false, false, false, false]

func set_win_mask(mask: Array[bool]) -> void:
	_win_mask = mask


func dim_non_winning() -> void:
	for i in _card_textures.size():
		_card_textures[i].modulate = Color.WHITE if _win_mask[i] else Color(0.35, 0.35, 0.45)


func undim_all() -> void:
	for i in _card_textures.size():
		_card_textures[i].modulate = Color.WHITE


func apply_final_dim() -> void:
	if _is_losing:
		modulate = Color(0.35, 0.35, 0.45)


func hide_result() -> void:
	if _result_overlay and _result_overlay.is_inside_tree():
		_result_overlay.queue_free()
	_result_overlay = null
	_is_losing = false
	modulate = Color.WHITE


func highlight_win(payout: int) -> void:
	if payout > 0:
		modulate = Color(1.0, 1.0, 1.0)
	else:
		modulate = Color(0.35, 0.35, 0.45)


func reset_highlight() -> void:
	hide_result()
	modulate = Color.WHITE


func _get_card_path(card: CardData) -> String:
	if card.is_joker():
		return "res://assets/cards/card_vp_joker_red.png"
	if _variant and _variant.is_wild_card(card) and card.rank == CardData.Rank.TWO:
		var s: String = SUIT_CODES.get(card.suit, "")
		return "res://assets/cards/card_vp_wild%s.png" % s
	var r: String = RANK_CODES.get(card.rank, "")
	var s: String = SUIT_CODES.get(card.suit, "")
	return "res://assets/cards/card_vp_%s%s.png" % [r, s]
