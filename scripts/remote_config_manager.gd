extends Node

## RemoteConfigManager autoload — Firebase Remote Config via REST.
## Fetches once at startup (10s timeout). On any failure silently falls
## back to local ConfigManager. Registered AFTER ConfigManager.

const _PROJECT_ID := "video-poker-trainer-59777"
const _FETCH_URL := "https://firebaseremoteconfig.googleapis.com/v1/projects/%s/namespaces/firebase:fetch?key=%s"
const _TIMEOUT_SEC := 10.0
# Set to false once you've verified Remote Config works in Output panel.
const _DEBUG := false
# Kill-switch parameter name — must equal "true" in Firebase to enable
# remote overrides. Anything else (absent, "false", malformed) → use locals.
const _KILL_SWITCH_KEY := "remote_config_enabled"

const _IOS_API_KEY := "AIzaSyAOfIIhl_aIXxYBHMqjv6qb2oirIR4yaj0"
const _IOS_APP_ID := "1:1041149483254:ios:4532bdffe8dcfb706534d7"
const _ANDROID_API_KEY := "AIzaSyDZogjM4fZ7MtStCi03fVe-dVK39nll--8"
const _ANDROID_APP_ID := "1:1041149483254:android:302cbd535ff8437e6534d7"
const _WEB_API_KEY := "AIzaSyD9umhgNUtp5XwYL1JiWXrmk8XLr1MMXGM"
const _WEB_APP_ID := "1:1041149483254:web:900b40e013d339a86534d7"

signal fetch_completed(success: bool)

var _remote: Dictionary = {}
var _fetched := false
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = _TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_fetch()


# ─── PUBLIC ───────────────────────────────────────────────────────────

## Returns remote-overridden config dict if present, otherwise the local
## one from ConfigManager (matched by property name: "balance",
## "machines", "shop", "gift", "sounds", "animations", "features",
## "vibration", "economy", "init_config", "lobby_order").
func get_config(config_name: String) -> Dictionary:
	if _remote.has(config_name):
		return _remote[config_name]
	var local: Variant = ConfigManager.get(config_name)
	if local is Dictionary:
		return local
	return {}


## Returns ONLY the remote override (no fallback). Empty dict if absent.
## Used by ConfigManager to detect which configs to overwrite on fetch.
func get_remote(config_name: String) -> Dictionary:
	return _remote.get(config_name, {})


func is_fetched() -> bool:
	return _fetched


# ─── INTERNAL ─────────────────────────────────────────────────────────

func _fetch() -> void:
	var keys := _platform_keys()
	var url := _FETCH_URL % [_PROJECT_ID, keys["api_key"]]
	var instance_id := _get_or_create_instance_id()
	var body := {
		"app_id": keys["app_id"],
		"app_instance_id": instance_id,
	}
	if _DEBUG:
		print("[RemoteConfig] platform=%s app_id=%s instance_id=%s" % [
			OS.get_name(), keys["app_id"], instance_id,
		])
		print("[RemoteConfig] POST -> ", url)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_warning("RemoteConfig: failed to start request, err=%s" % err)
		_finish(false)


func _platform_keys() -> Dictionary:
	match OS.get_name():
		"iOS":
			return {"api_key": _IOS_API_KEY, "app_id": _IOS_APP_ID}
		"Android":
			return {"api_key": _ANDROID_API_KEY, "app_id": _ANDROID_APP_ID}
		"Web":
			return {"api_key": _WEB_API_KEY, "app_id": _WEB_APP_ID}
		_:
			return {"api_key": _IOS_API_KEY, "app_id": _IOS_APP_ID}


## Returns the persisted Firebase client id, generating + saving one on first call.
func _get_or_create_instance_id() -> String:
	if SaveManager.app_instance_id != "":
		return SaveManager.app_instance_id
	var generated := "%08x-%04x-%04x-%04x-%012x" % [
		randi(),
		randi() & 0xffff,
		randi() & 0xffff,
		randi() & 0xffff,
		randi(),
	]
	SaveManager.app_instance_id = generated
	SaveManager.save_game()
	return generated


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw_text := body.get_string_from_utf8()
	if _DEBUG:
		print("[RemoteConfig] response result=%s http=%s bytes=%s" % [result, code, body.size()])
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("RemoteConfig: fetch failed (result=%s, http=%s)" % [result, code])
		if _DEBUG and raw_text != "":
			print("[RemoteConfig] error body: ", raw_text.substr(0, 500))
		_finish(false)
		return
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_warning("RemoteConfig: response is not a JSON object")
		_finish(false)
		return
	if _DEBUG:
		print("[RemoteConfig] state=", parsed.get("state", "<none>"))
	var entries: Variant = parsed.get("entries", {})
	if not (entries is Dictionary):
		# state may be NO_TEMPLATE / NO_CHANGE — treat as success with empty overrides
		if _DEBUG:
			print("[RemoteConfig] no entries — finishing without overrides")
		_finish(true)
		return
	# Kill-switch: ignore EVERYTHING from remote unless the flag is explicitly "true".
	if String(entries.get(_KILL_SWITCH_KEY, "")) != "true":
		print("[RemoteConfig] kill-switch active, using local configs")
		_finish(true)
		return
	for key in entries.keys():
		if key == _KILL_SWITCH_KEY:
			continue
		var raw: Variant = entries[key]
		if typeof(raw) != TYPE_STRING:
			push_warning("RemoteConfig: entry '%s' is not a string, skipped" % key)
			continue
		var value: Variant = JSON.parse_string(raw)
		if value is Dictionary:
			_remote[key] = value
		else:
			push_warning("RemoteConfig: entry '%s' is not a JSON object, skipped" % key)
	if _DEBUG:
		print("[RemoteConfig] applied overrides: ", _remote.keys())
	_finish(true)


func _finish(success: bool) -> void:
	_fetched = true
	fetch_completed.emit(success)
