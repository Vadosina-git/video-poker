extends Node

## SoundManager — loads audio from sounds.json config, plays via AudioStreamPlayer.
## Supports multiple simultaneous sounds via a pool of players.

const POOL_SIZE := 4
const AMBIENT_PITCH := 0.93

var _sfx_enabled: bool = true
var _music_enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}  # event_name → AudioStream
var _pitches: Dictionary = {}  # event_name → pitch_scale
var _volumes_db: Dictionary = {}  # event_name → volume_db
var _ambient_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _music_fade_tween: Tween = null
var _sfx_loop_player: AudioStreamPlayer = null
var _sfx_loop_current: String = ""


func _ready() -> void:
	_sfx_enabled = SaveManager.settings.get("sound_fx", true)
	_music_enabled = SaveManager.settings.get("music", true)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_load_sounds()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button or node is TextureButton:
		node.pressed.connect(func() -> void: play_with_pitch("button_press", randf_range(0.67, 0.97)))
		node.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT \
					and (node as BaseButton).disabled \
					and not node.is_in_group("no_disabled_sound"):
				play("button_disabled")
		)


func _load_sounds() -> void:
	var events: Dictionary = ConfigManager.sounds.get("events", {})
	var base_path: String = ConfigManager.sounds.get("sounds_path", "res://assets/sounds/")
	for event_name in events:
		var file_name: String = events[event_name]
		var path: String = base_path + file_name
		if ResourceLoader.exists(path):
			_streams[event_name] = load(path)
	_pitches = ConfigManager.sounds.get("pitches", {})
	_volumes_db = ConfigManager.sounds.get("volumes_db", {})


func play(sound_name: String) -> void:
	if not _sfx_enabled:
		return
	var stream: AudioStream = _streams.get(sound_name)
	if not stream:
		return
	var pitch: float = _pitches.get(sound_name, 1.0)
	var vol_db: float = _volumes_db.get(sound_name, 0.0)
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.volume_db = vol_db
			player.play()
			return
	_players[0].stream = stream
	_players[0].pitch_scale = pitch
	_players[0].volume_db = vol_db
	_players[0].play()


func play_with_pitch(sound_name: String, pitch: float) -> void:
	if not _sfx_enabled:
		return
	var stream: AudioStream = _streams.get(sound_name)
	if not stream:
		return
	var vol_db: float = _volumes_db.get(sound_name, 0.0)
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.volume_db = vol_db
			player.play()
			return
	_players[0].stream = stream
	_players[0].pitch_scale = pitch
	_players[0].volume_db = vol_db
	_players[0].play()


func play_lobby_ambient() -> void:
	if not _music_enabled:
		return
	var stream: AudioStream = _streams.get("lobby_ambient")
	if not stream:
		return
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.bus = "Master"
		_ambient_player.pitch_scale = AMBIENT_PITCH
		_ambient_player.finished.connect(func() -> void:
			if _ambient_player and _ambient_player.stream:
				_ambient_player.play()
		)
		add_child(_ambient_player)
	_ambient_player.volume_db = -14.0  # 0.2 линейный
	_ambient_player.stream = stream
	_ambient_player.play()


func play_ambient() -> void:
	if not _music_enabled:
		return
	var tracks := ["game_ambient", "game_ambient_2", "game_ambient_3"]
	var event: String = tracks[randi() % tracks.size()]
	var stream: AudioStream = _streams.get(event)
	if not stream:
		return
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.bus = "Master"
		_ambient_player.pitch_scale = AMBIENT_PITCH
		_ambient_player.finished.connect(func() -> void:
			if _ambient_player and _ambient_player.stream:
				_ambient_player.play()
		)
		add_child(_ambient_player)
	_ambient_player.volume_db = -8.0
	_ambient_player.stream = stream
	_ambient_player.play()


func stop_ambient() -> void:
	if _ambient_player and _ambient_player.playing:
		_ambient_player.stop()


func play_sfx_loop(event_name: String, volume_db: float = 0.0) -> void:
	if not _sfx_enabled:
		return
	var stream: AudioStream = _streams.get(event_name)
	if not stream:
		return
	if _sfx_loop_player == null:
		_sfx_loop_player = AudioStreamPlayer.new()
		_sfx_loop_player.bus = "Master"
		_sfx_loop_player.finished.connect(func() -> void:
			if _sfx_loop_player and _sfx_loop_player.stream:
				_sfx_loop_player.play()
		)
		add_child(_sfx_loop_player)
	_sfx_loop_current = event_name
	_sfx_loop_player.volume_db = volume_db
	_sfx_loop_player.stream = stream
	_sfx_loop_player.play()


func stop_sfx_loop() -> void:
	# Idempotent: clear `_sfx_loop_current` and `stream` even if `.playing`
	# is false at the moment of the call. The looped player relies on a
	# manual `finished` → `play()` chain (set up in `play_sfx_loop`); if we
	# only stop while `.playing` is true, a stop call that races with the
	# natural end of a WAV cycle leaves `stream` non-null, the queued
	# `finished` handler then re-plays the loop and the SFX runs forever.
	# Clearing `stream` here makes the `finished` handler's guard fail.
	_sfx_loop_current = ""
	if _sfx_loop_player:
		if _sfx_loop_player.playing:
			_sfx_loop_player.stop()
		_sfx_loop_player.stream = null


func stop_sfx_loop_if(expected: String) -> void:
	if _sfx_loop_current != expected:
		return
	stop_sfx_loop()


func play_music(event_name: String) -> void:
	if not _music_enabled:
		return
	var stream: AudioStream = _streams.get(event_name)
	if not stream:
		return
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Master"
		add_child(_music_player)
	if _music_fade_tween:
		_music_fade_tween.kill()
		_music_fade_tween = null
	_music_player.volume_db = 0.0
	_music_player.stream = stream
	_music_player.play()


func stop_music(fade_duration: float = 1.5) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if _music_fade_tween:
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", -80.0, fade_duration) \
		.set_ease(Tween.EASE_IN)
	_music_fade_tween.tween_callback(func() -> void:
		_music_player.stop()
		_music_player.volume_db = 0.0
	)


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	SaveManager.settings["sound_fx"] = enabled
	SaveManager.save_game()
	if not enabled:
		for player in _players:
			player.stop()


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	SaveManager.settings["music"] = enabled
	SaveManager.save_game()
	if not enabled:
		stop_ambient()
	else:
		play_ambient()
