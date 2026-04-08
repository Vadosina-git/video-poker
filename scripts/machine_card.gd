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
