extends Node

## SoundManager — loads audio from sounds.json config, plays via AudioStreamPlayer.
## Supports multiple simultaneous sounds via a pool of players.

const POOL_SIZE := 4

var _enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}  # event_name → AudioStream


func _ready() -> void:
	_enabled = SaveManager.settings.get("sound_fx", true)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_load_sounds()


func _load_sounds() -> void:
	var events: Dictionary = ConfigManager.sounds.get("events", {})
	var base_path: String = ConfigManager.sounds.get("sounds_path", "res://assets/sounds/")
	for event_name in events:
		var file_name: String = events[event_name]
		var path: String = base_path + file_name
		if ResourceLoader.exists(path):
			_streams[event_name] = load(path)


func play(sound_name: String) -> void:
	if not _enabled:
		return
	var stream: AudioStream = _streams.get(sound_name)
	if not stream:
		return
	# Find an available player
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All busy — use first (interrupt oldest)
	_players[0].stream = stream
	_players[0].play()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	SaveManager.settings["sound_fx"] = enabled
	SaveManager.save_game()
	if not enabled:
		for player in _players:
			player.stop()
