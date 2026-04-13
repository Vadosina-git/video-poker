extends Control

var LobbyScene: PackedScene
var GameScene: PackedScene

var _current_scene: Control = null
var _paytables: Dictionary = {}


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
