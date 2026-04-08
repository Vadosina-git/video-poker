extends Control

signal machine_selected(variant_id: String)

var MachineCardScene: PackedScene = null

const MACHINE_CONFIG := [
	{
		"id": "jacks_or_better",
		"name": "Jacks or Better",
		"color": Color(0.2, 0.3, 0.8),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "Royal Flush: 4000\nFull House: 9\nFlush: 6",
		"locked": false,
	},
	{
		"id": "bonus_poker",
		"name": "Bonus Poker",
		"color": Color(0.75, 0.15, 0.15),
		"accent": Color(0.75, 0.75, 0.8),
		"mini": "4 Aces: 80\nFull House: 8\nFlush: 5",
		"locked": true,
	},
	{
		"id": "deuces_wild",
		"name": "Deuces Wild",
		"color": Color(0.1, 0.7, 0.2),
		"accent": Color(1.0, 0.9, 0.1),
		"mini": "4 Deuces: 200\nNatural Royal: 4000",
		"locked": true,
	},
	{
		"id": "bonus_poker_deluxe",
		"name": "Bonus Poker Deluxe",
		"color": Color(0.5, 0.1, 0.5),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "4 of a Kind: 80\nFull House: 9",
		"locked": true,
	},
	{
		"id": "double_bonus",
		"name": "Double Bonus",
		"color": Color(0.6, 0.1, 0.1),
		"accent": Color(0.75, 0.75, 0.8),
		"mini": "4 Aces: 160\nFull House: 10",
		"locked": true,
	},
	{
		"id": "double_double_bonus",
		"name": "Double Double Bonus",
		"color": Color(0.45, 0.05, 0.15),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "4 Aces + 2/3/4: 400\n4 Aces: 160",
		"locked": true,
	},
	{
		"id": "triple_double_bonus",
		"name": "Triple Double Bonus",
		"color": Color(0.08, 0.08, 0.08),
		"accent": Color(0.85, 0.7, 0.2),
		"mini": "4 Aces + 2/3/4: 800\n4 Aces: 160",
		"locked": true,
	},
	{
		"id": "aces_and_faces",
		"name": "Aces and Faces",
		"color": Color(0.1, 0.5, 0.2),
		"accent": Color(0.75, 0.75, 0.8),
		"mini": "4 Aces: 80\n4 J/Q/K: 40",
		"locked": true,
	},
	{
		"id": "joker_poker",
		"name": "Joker Poker",
		"color": Color(0.4, 0.1, 0.6),
		"accent": Color(1.0, 0.9, 0.1),
		"mini": "5 of a Kind: 200\nWild Royal: 100",
		"locked": true,
	},
	{
		"id": "deuces_and_joker",
		"name": "Deuces & Joker Wild",
		"color": Color(0.05, 0.5, 0.45),
		"accent": Color(0.8, 0.15, 0.15),
		"mini": "4 Deuces+Joker: 10000\nNatural Royal: 4000",
		"locked": true,
	},
]

@onready var _carousel: HBoxContainer = %MachineCarousel
@onready var _credits_label: Label = %LobbyCredits

var _paytables: Dictionary = {}


func _ready() -> void:
	MachineCardScene = load("res://scenes/lobby/machine_card.tscn")
	_paytables = Paytable.load_all()
	_apply_theme()
	_credits_label.text = "CREDITS: %d" % SaveManager.credits
	_build_carousel()


func _apply_theme() -> void:
	$VBoxContainer.add_theme_constant_override("separation", 20)
	var top_bar := $VBoxContainer/TopBar as MarginContainer
	top_bar.add_theme_constant_override("margin_left", 24)
	top_bar.add_theme_constant_override("margin_right", 24)
	var title := %LobbyTitle as Label
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	_credits_label.add_theme_font_size_override("font_size", 24)
	_credits_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	var select_label := $VBoxContainer/SelectLabel as Label
	select_label.add_theme_font_size_override("font_size", 22)
	select_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_carousel.add_theme_constant_override("separation", 24)


func _build_carousel() -> void:
	for config in MACHINE_CONFIG:
		var card_node: PanelContainer = MachineCardScene.instantiate()
		_carousel.add_child(card_node)
		var rtp: float = 0.0
		if config["id"] in _paytables:
			rtp = _paytables[config["id"]].rtp
		card_node.setup(
			config["id"],
			config["name"],
			config["color"],
			config["accent"],
			rtp,
			config["mini"],
			config["locked"],
		)
		card_node.play_pressed.connect(_on_play_pressed)


func _on_play_pressed(variant_id: String) -> void:
	SaveManager.last_variant = variant_id
	machine_selected.emit(variant_id)


func refresh_credits() -> void:
	_credits_label.text = "CREDITS: %d" % SaveManager.credits
