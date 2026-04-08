extends Node

const SAVE_PATH := "user://save.json"
const DEFAULT_CREDITS := 1000

var credits: int = DEFAULT_CREDITS
var denomination: int = 1
var last_variant: String = "jacks_or_better"
var settings := {
	"sound_fx": true,
	"music": true,
	"casino_ambient": false,
	"game_speed": "normal",
	"auto_hold": false,
}


func _ready() -> void:
	load_game()


func save_game() -> void:
	var data := {
		"credits": credits,
		"denomination": denomination,
		"last_variant": last_variant,
		"settings": settings,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return
	var data: Dictionary = json.data
	credits = int(data.get("credits", DEFAULT_CREDITS))
	denomination = int(data.get("denomination", 1))
	last_variant = data.get("last_variant", "jacks_or_better")
	var saved_settings: Dictionary = data.get("settings", {})
	for key in saved_settings:
		if key in settings:
			settings[key] = saved_settings[key]


func add_credits(amount: int) -> void:
	credits += amount
	save_game()


func deduct_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	save_game()
	return true
