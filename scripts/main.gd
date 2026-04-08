extends Control

var LobbyScene: PackedScene
var GameScene: PackedScene

var _current_scene: Control = null
var _paytables: Dictionary = {}


func _ready() -> void:
	LobbyScene = load("res://scenes/lobby/lobby.tscn")
	GameScene = load("res://scenes/game.tscn")
	_paytables = Paytable.load_all()
	_show_lobby()


func _show_lobby() -> void:
	_clear_current()
	var lobby: Control = LobbyScene.instantiate()
	add_child(lobby)
	_current_scene = lobby
	lobby.machine_selected.connect(_on_machine_selected)


func _on_machine_selected(variant_id: String) -> void:
	_clear_current()
	var game: Control = GameScene.instantiate()

	var paytable: Paytable = _paytables[variant_id]
	var variant := JacksOrBetter.new(paytable)
	game.setup(variant)

	add_child(game)
	_current_scene = game
	game.back_to_lobby.connect(_show_lobby)


func _clear_current() -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null
