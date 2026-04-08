extends Node

var _enabled: bool = true


func play(sound_name: String) -> void:
	if not _enabled:
		return
	# Stub — will be implemented when audio assets are added
	# Supported: bet, deal, flip, hold, win_small, win_big, win_royal, lose, button


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
