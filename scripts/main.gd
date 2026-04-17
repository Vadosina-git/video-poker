extends Control

var LobbyScene: PackedScene
var GameScene: PackedScene

var _current_scene: Control = null
var _paytables: Dictionary = {}
var _loader_active: bool = false

const LOADER_DURATION := 3.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.527, 1.0))
	LobbyScene = load("res://scenes/lobby/lobby.tscn")
	GameScene = load("res://scenes/game.tscn")
	_paytables = Paytable.load_all()
	_show_lobby()


func _show_lobby() -> void:
	_clear_current()
	var lobby: Control = LobbyScene.instantiate()
	add_child(lobby)
	_make_full_rect(lobby)
	_current_scene = lobby
	lobby.machine_selected.connect(_on_machine_selected)


func _on_machine_selected(variant_id: String) -> void:
	if _loader_active:
		return
	_loader_active = true
	var loader := _create_loader()
	add_child(loader)
	await get_tree().create_timer(LOADER_DURATION).timeout
	_loader_active = false
	if is_instance_valid(loader):
		loader.queue_free()
	_load_game_scene(variant_id)


func _load_game_scene(variant_id: String) -> void:
	_clear_current()
	var paytable: Paytable = _paytables[variant_id]
	var variant := _create_variant(variant_id, paytable)
	var hand_count: int = SaveManager.hand_count
	var ultra_vp: bool = SaveManager.ultra_vp

	if SaveManager.spin_poker:
		# Spin Poker mode
		var spin_scene := load("res://scenes/spin_poker_game.tscn")
		if spin_scene:
			var spin_game: Control = spin_scene.instantiate()
			spin_game.setup(variant)
			add_child(spin_game)
			_make_full_rect(spin_game)
			_current_scene = spin_game
			spin_game.back_to_lobby.connect(_show_lobby)
			return

	if hand_count > 1 or ultra_vp:
		# Multi-hand mode
		var multi_scene := load("res://scenes/multi_hand_game.tscn")
		if multi_scene:
			var multi_game: Control = multi_scene.instantiate()
			multi_game.setup(variant, hand_count, ultra_vp)
			add_child(multi_game)
			_make_full_rect(multi_game)
			_current_scene = multi_game
			multi_game.back_to_lobby.connect(_show_lobby)
			return

	# Single hand mode (default)
	var game: Control = GameScene.instantiate()
	game.setup(variant)
	add_child(game)
	_make_full_rect(game)
	_current_scene = game
	game.back_to_lobby.connect(_show_lobby)


func _create_variant(variant_id: String, pt: Paytable) -> BaseVariant:
	match variant_id:
		"jacks_or_better":
			return JacksOrBetter.new(pt)
		"bonus_poker":
			return BonusPoker.new(pt)
		"bonus_poker_deluxe":
			return BonusPokerDeluxe.new(pt)
		"double_bonus":
			return DoubleBonus.new(pt)
		"double_double_bonus":
			return DoubleDoubleBonus.new(pt)
		"triple_double_bonus":
			return TripleDoubleBonus.new(pt)
		"aces_and_faces":
			return AcesAndFaces.new(pt)
		"deuces_wild":
			return DeucesWild.new(pt)
		"joker_poker":
			return JokerPoker.new(pt)
		"deuces_and_joker":
			return DeucesAndJoker.new(pt)
		_:
			return JacksOrBetter.new(pt)


func _make_full_rect(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.set_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_current() -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null


# --- Table-loading overlay (dim + spinner) ---

func _create_loader() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	overlay.add_child(dim)

	var center_ct := CenterContainer.new()
	center_ct.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_ct)

	var spinner := _create_spinner()
	center_ct.add_child(spinner)

	return overlay


func _create_spinner() -> Control:
	var size_px: float = 128.0
	var spinner := TextureRect.new()
	spinner.texture = load("res://assets/textures/loading_chip.png")
	spinner.custom_minimum_size = Vector2(size_px, size_px)
	spinner.size = Vector2(size_px, size_px)
	spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spinner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spinner.pivot_offset = Vector2(size_px * 0.5, size_px * 0.5)

	# Continuous rotation: one full turn per 2 seconds with wavelike pacing
	# (sine ease-in-out → accelerates from rest, peaks, decelerates back).
	# .from(0) resets each loop iteration so subsequent turns aren't a no-op.
	var tw := spinner.create_tween()
	tw.set_loops()
	tw.tween_property(spinner, "rotation", TAU, 2.0) \
		.from(0.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	return spinner
