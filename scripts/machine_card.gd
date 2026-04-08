extends PanelContainer

signal play_pressed(variant_id: String)

var variant_id: String = ""
var locked: bool = false

@onready var _name_label: Label = %MachineName
@onready var _rtp_label: Label = %RTPLabel
@onready var _play_button: Button = %PlayButton
@onready var _color_bar: ColorRect = %ColorBar
@onready var _lock_overlay: ColorRect = %LockOverlay
@onready var _mini_paytable: Label = %MiniPaytable


func setup(p_variant_id: String, p_name: String, p_color: Color, _p_accent: Color, rtp: float, mini_info: String, p_locked: bool = false) -> void:
	variant_id = p_variant_id
	locked = p_locked

	if is_node_ready():
		_apply_setup(p_name, p_color, rtp, mini_info, p_locked)
	else:
		ready.connect(func() -> void: _apply_setup(p_name, p_color, rtp, mini_info, p_locked), CONNECT_ONE_SHOT)


func _apply_setup(p_name: String, p_color: Color, rtp: float, mini_info: String, p_locked: bool) -> void:
	# Apply theme overrides
	var margin := $VBoxContainer/MarginContainer as MarginContainer
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	var content := $VBoxContainer/MarginContainer/Content as VBoxContainer
	content.add_theme_constant_override("separation", 12)

	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_mini_paytable.add_theme_font_size_override("font_size", 14)
	_mini_paytable.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_rtp_label.add_theme_font_size_override("font_size", 16)
	_rtp_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_play_button.add_theme_font_size_override("font_size", 22)

	_name_label.text = p_name
	_rtp_label.text = "RTP: %.2f%%" % rtp
	_color_bar.color = p_color
	_mini_paytable.text = mini_info
	_lock_overlay.visible = p_locked
	_play_button.disabled = p_locked
	if p_locked:
		_play_button.text = "LOCKED"
	else:
		_play_button.text = "PLAY"
	_play_button.pressed.connect(func() -> void: play_pressed.emit(variant_id))
