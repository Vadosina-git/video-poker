extends Node
## Localization autoload.
##
## Loads `data/translations.json` and exposes `tr_key(key, args)` for code to
## fetch translated text. The active language is one of the codes defined in
## the JSON file (currently "en", "ru", "es") or "system" — meaning the
## platform/OS locale chooses the closest match.
##
## To switch language at runtime call `set_language(code)`. This persists the
## choice through SaveManager and emits `language_changed`. Callers (typically
## main.gd) should reload all open scenes to pick up new strings.

signal language_changed(new_code: String)

const TRANSLATIONS_PATH := "res://data/translations.json"
const SUPPORTED_CODES := ["en", "ru", "es"]
const DEFAULT_CODE := "en"

var current_code: String = DEFAULT_CODE
var _strings: Dictionary = {}  # nested: {code: {key: value}}


func _ready() -> void:
	_load_translations()
	_apply_initial_language()


func _load_translations() -> void:
	if not FileAccess.file_exists(TRANSLATIONS_PATH):
		push_warning("Translations file not found: " + TRANSLATIONS_PATH)
		return
	var file := FileAccess.open(TRANSLATIONS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Failed to parse translations JSON: " + json.get_error_message())
		return
	var data: Dictionary = json.data
	var langs: Dictionary = data.get("languages", {})
	for code in langs:
		_strings[code] = langs[code]


func _apply_initial_language() -> void:
	var saved: String = SaveManager.language
	if saved == "" or saved == "system":
		current_code = _detect_system_language()
	elif saved in SUPPORTED_CODES:
		current_code = saved
	else:
		current_code = DEFAULT_CODE


## Inspect OS locale and pick the closest supported language.
func _detect_system_language() -> String:
	var locale := OS.get_locale_language().to_lower()
	if locale.begins_with("ru"):
		return "ru"
	if locale.begins_with("es"):
		return "es"
	return "en"


## Persist a new language choice and reload localized text everywhere.
## Pass "system" to fall back to the OS-detected language.
func set_language(code: String) -> void:
	SaveManager.language = code
	SaveManager.save_game()
	if code == "" or code == "system":
		current_code = _detect_system_language()
	elif code in SUPPORTED_CODES:
		current_code = code
	else:
		current_code = DEFAULT_CODE
	language_changed.emit(current_code)


## Look up a translation key and optionally interpolate `%s` / `%d` arguments.
## Falls back to English if the key is missing in the active language, then to
## the key string itself if the key is also missing in English (helps debugging).
func tr_key(key: String, args: Array = []) -> String:
	var raw := _lookup(key)
	if args.is_empty():
		return raw
	return raw % args


func _lookup(key: String) -> String:
	var dict: Dictionary = _strings.get(current_code, {})
	if key in dict:
		return String(dict[key])
	var fallback: Dictionary = _strings.get(DEFAULT_CODE, {})
	if key in fallback:
		return String(fallback[key])
	return key  # surface the missing key so it's easy to spot in-game


## Returns the list of selectable language codes for the settings popup.
## "system" is included as a synthetic option that defers to OS locale.
func get_available_codes() -> Array[String]:
	var out: Array[String] = ["system"]
	for c in SUPPORTED_CODES:
		out.append(c)
	return out


## Display name for a language code (used in the settings popup).
func display_name_for_code(code: String) -> String:
	match code:
		"system":
			return tr_key("settings.language_system")
		"en":
			return "English"
		"ru":
			return "Русский"
		"es":
			return "Español"
		_:
			return code


## Convenience accessor used by the settings popup to know what to highlight.
func get_saved_language() -> String:
	return SaveManager.language if SaveManager.language != "" else "system"
