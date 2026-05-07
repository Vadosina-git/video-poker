extends Node

## NotificationManager autoload — wraps godot-mobile-plugins/godot-notification-scheduler.
##
## Single switch UX: SaveManager.notifications_enabled toggles the whole feature.
## When the plugin or platform is unavailable (Desktop, Web, plugin not installed),
## every public method silently no-ops so the rest of the game runs unchanged.
##
## Schedules five event kinds:
##   • gift_ready          — triggered on gift claim, fires at cooldown end
##   • shop_pack_ready/<id>— triggered per pack on claim, fires at pack cooldown end
##   • daily_quests_reset  — fires at next local midnight, refreshed daily
##   • retention_day_2     — fires 48h after last app exit at fire_at_local_hour
##   • retention_day_7     — fires 168h after last app exit at fire_at_local_hour
##
## Quiet hours: if computed fire time falls inside [start, end) local, the time
## is shifted forward to `end_hour` of the next valid day. Player asleep ≠
## notification fired.
##
## iOS lets us schedule up to 64 notifications; we never approach that since
## retention pings are rescheduled on each foreground.

signal permission_resolved(granted: bool)

const PLUGIN_NODE_NAME := "_NotificationSchedulerInternal"

var _plugin: Node = null
var _channel_created: bool = false
var _initialized: bool = false


func _ready() -> void:
	if not _is_supported_platform():
		return
	if not ConfigManager.is_notifications_feature_enabled():
		return
	_init_plugin()
	# Wire app pause/resume so retention pings reschedule on each session edge.
	get_tree().root.size_changed.connect(_on_root_changed)
	# NOTIFICATION_APPLICATION_FOCUS_OUT/IN routed through _notification.


func _notification(what: int) -> void:
	if not _initialized:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_schedule_retention_pings()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_cancel_retention_pings()
		# Cooldown notifications: re-anchor on resume in case clock drifted.
		_resync_all_cooldowns()


# ─── PLATFORM / PLUGIN BOOTSTRAP ─────────────────────────────────────

func _is_supported_platform() -> bool:
	var os: String = OS.get_name()
	return os == "iOS" or os == "Android"


func _init_plugin() -> void:
	# The plugin ships a Node-based class `NotificationScheduler`. We instantiate
	# it as a child here; if the class isn't available (plugin not installed
	# yet, or Godot can't resolve the symbol on this build), we silently bail.
	if _plugin != null:
		return
	if not Engine.has_singleton("NotificationScheduler") and not ClassDB.class_exists("NotificationScheduler"):
		# Plugin uses a Node added to the scene tree, not a singleton. Try a
		# script-class lookup via load(); if that also fails, assume missing.
		var resource := load("res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd") if ResourceLoader.exists("res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd") else null
		if resource == null:
			# Last resort — try the scene the AssetLib version ships with.
			if not ResourceLoader.exists("res://addons/NotificationSchedulerPlugin/NotificationScheduler.tscn"):
				push_warning("[NotificationManager] plugin not installed — feature disabled at runtime")
				return
	var scheduler_node: Node = _instantiate_plugin_node()
	if scheduler_node == null:
		push_warning("[NotificationManager] failed to instantiate NotificationScheduler")
		return
	scheduler_node.name = PLUGIN_NODE_NAME
	add_child(scheduler_node)
	_plugin = scheduler_node
	_connect_plugin_signals()
	if _plugin.has_method("initialize"):
		_plugin.initialize()
	_initialized = true
	_create_channel_if_needed()


func _instantiate_plugin_node() -> Node:
	# The plugin can be installed via AssetLib (places under addons/) or as a
	# custom path. Try the canonical locations.
	var candidates := [
		"res://addons/NotificationSchedulerPlugin/NotificationScheduler.tscn",
		"res://addons/NotificationSchedulerPlugin/notification_scheduler.tscn",
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var packed: PackedScene = load(path)
			if packed != null:
				return packed.instantiate()
	# Try GDScript class instantiation.
	if ClassDB.class_exists("NotificationScheduler"):
		return ClassDB.instantiate("NotificationScheduler")
	return null


func _connect_plugin_signals() -> void:
	if _plugin == null:
		return
	if _plugin.has_signal("post_notifications_permission_granted"):
		_plugin.post_notifications_permission_granted.connect(_on_permission_granted)
	if _plugin.has_signal("post_notifications_permission_denied"):
		_plugin.post_notifications_permission_denied.connect(_on_permission_denied)


func _create_channel_if_needed() -> void:
	if _channel_created or _plugin == null:
		return
	if OS.get_name() != "Android":
		_channel_created = true
		return
	var ch: Dictionary = ConfigManager.get_notifications_channel()
	var channel_class := load("res://addons/NotificationSchedulerPlugin/NotificationChannel.gd")
	if channel_class == null:
		# Plugin exposes the class as a script; fallback to ClassDB.
		if not ClassDB.class_exists("NotificationChannel"):
			return
	var channel = _build_channel_object(ch)
	if channel == null:
		return
	if _plugin.has_method("create_notification_channel"):
		_plugin.create_notification_channel(channel)
	_channel_created = true


func _build_channel_object(ch: Dictionary) -> Object:
	# Try ClassDB first (native), then GDScript class.
	var obj: Object = null
	if ClassDB.class_exists("NotificationChannel"):
		obj = ClassDB.instantiate("NotificationChannel")
	else:
		var script := load("res://addons/NotificationSchedulerPlugin/NotificationChannel.gd")
		if script != null:
			obj = script.new()
	if obj == null:
		return null
	# Plugin uses a fluent builder. All setters return the object.
	if obj.has_method("set_id"):
		obj.set_id(String(ch.get("id", "game_reminders")))
	if obj.has_method("set_name"):
		obj.set_name(_tr(String(ch.get("name_key", ""))))
	if obj.has_method("set_description"):
		obj.set_description(_tr(String(ch.get("description_key", ""))))
	if obj.has_method("set_importance"):
		obj.set_importance(_importance_value(String(ch.get("importance", "default"))))
	return obj


func _importance_value(name: String) -> int:
	# Mirrors NotificationChannel.Importance enum: NONE=0, MIN=1, LOW=2,
	# DEFAULT=3, HIGH=4, MAX=5. Fall back to DEFAULT.
	match name.to_lower():
		"none": return 0
		"min":  return 1
		"low":  return 2
		"high": return 4
		"max":  return 5
		_:      return 3


# ─── PUBLIC: PERMISSION + ENABLEMENT ─────────────────────────────────

## Returns true if the feature is reachable at all (config flag on AND platform
## supported AND plugin loaded). Used by the settings UI to hide the switch on
## desktop / web.
func is_available() -> bool:
	return _initialized and ConfigManager.is_notifications_feature_enabled()


## Player-facing master switch. Persisted by SaveManager. Toggling off cancels
## every scheduled notification immediately.
func set_player_enabled(enabled: bool) -> void:
	SaveManager.notifications_enabled = enabled
	SaveManager.save_game()
	if not enabled:
		cancel_all()
		return
	# Player turned the switch ON. If we never asked for OS permission, ask
	# now. Otherwise rebuild the schedule from current cooldown state.
	if not SaveManager.notifications_permission_asked:
		request_permission()
	else:
		_resync_all_cooldowns()


func is_player_enabled() -> bool:
	return SaveManager.notifications_enabled


func has_os_permission() -> bool:
	if not _initialized or _plugin == null:
		return false
	if not _plugin.has_method("has_post_notifications_permission"):
		return false
	return bool(_plugin.has_post_notifications_permission())


func request_permission() -> void:
	if not _initialized or _plugin == null:
		permission_resolved.emit(false)
		return
	SaveManager.notifications_permission_asked = true
	SaveManager.save_game()
	if has_os_permission():
		permission_resolved.emit(true)
		return
	if _plugin.has_method("request_post_notifications_permission"):
		_plugin.request_post_notifications_permission()


func _on_permission_granted(_perm: String) -> void:
	permission_resolved.emit(true)
	_resync_all_cooldowns()


func _on_permission_denied(_perm: String) -> void:
	permission_resolved.emit(false)


# ─── PUBLIC: SCHEDULING API ──────────────────────────────────────────

## Schedule the gift_ready reminder. Caller passes the Unix timestamp at which
## the gift becomes claimable; we compute delay from now. If timestamp is in
## the past or feature is off, this is a no-op.
func schedule_gift_ready(claim_at_unix: int) -> void:
	_schedule_event_at("gift_ready", "", claim_at_unix)


func cancel_gift_ready() -> void:
	_cancel_event("gift_ready", "")


## Per-pack shop reminder. pack_index = sort order from configs/shop.json (or
## any stable integer per pack). claim_at_unix = absolute time of cooldown end.
func schedule_shop_pack_ready(pack_index: int, claim_at_unix: int) -> void:
	_schedule_event_at("shop_pack_ready", str(pack_index), claim_at_unix)


func cancel_shop_pack_ready(pack_index: int) -> void:
	_cancel_event("shop_pack_ready", str(pack_index))


## Daily quest reset notification. fires at next local midnight.
func schedule_daily_quests_reset() -> void:
	if not _can_schedule():
		return
	var delay: int = DailyQuestManager.time_to_reset_seconds()
	if delay <= 0:
		return
	_schedule_event_with_delay("daily_quests_reset", "", delay)


func cancel_daily_quests_reset() -> void:
	_cancel_event("daily_quests_reset", "")


## Cancel everything we ever scheduled. Called when player turns master switch
## off, when feature_enabled flips to false via Remote Config.
func cancel_all() -> void:
	if not _initialized or _plugin == null:
		return
	cancel_gift_ready()
	cancel_daily_quests_reset()
	# Cancel all known shop pack ids based on current shop config.
	var packs: Array = ConfigManager.shop.get("iap_items", [])
	for i in packs.size():
		cancel_shop_pack_ready(i)
	_cancel_retention_pings()


# ─── INTERNAL: SCHEDULING ────────────────────────────────────────────

## Returns true iff every gate is open: feature flag, master switch, OS
## permission, plugin loaded.
func _can_schedule() -> bool:
	if not _initialized or _plugin == null:
		return false
	if not ConfigManager.is_notifications_feature_enabled():
		return false
	if not SaveManager.notifications_enabled:
		return false
	if not has_os_permission():
		return false
	return true


func _schedule_event_at(event_id: String, suffix: String, fire_at_unix: int) -> void:
	if not _can_schedule():
		return
	var now: int = int(Time.get_unix_time_from_system())
	var delay: int = max(0, fire_at_unix - now)
	if delay <= 0:
		# Past — no point scheduling. (Player is currently in-app; they'll see
		# the gift ready in the UI.) Still cancel any stale entry.
		_cancel_event(event_id, suffix)
		return
	_schedule_event_with_delay(event_id, suffix, delay)


func _schedule_event_with_delay(event_id: String, suffix: String, delay_seconds: int) -> void:
	if not _can_schedule():
		return
	var event_cfg: Dictionary = ConfigManager.get_notification_event(event_id)
	if event_cfg.is_empty():
		return
	if not bool(event_cfg.get("enabled", true)):
		return
	var notif_id: int = _resolve_id(event_cfg, suffix)
	var adjusted: int = _apply_quiet_hours(delay_seconds)
	# Cancel previous instance with same id before scheduling fresh.
	if _plugin.has_method("cancel"):
		_plugin.cancel(notif_id)
	var data := _build_notification_data(notif_id, event_cfg, adjusted)
	if data == null:
		return
	if _plugin.has_method("schedule"):
		_plugin.schedule(data)


func _build_notification_data(notif_id: int, event_cfg: Dictionary, delay_seconds: int) -> Object:
	var obj: Object = null
	if ClassDB.class_exists("NotificationData"):
		obj = ClassDB.instantiate("NotificationData")
	else:
		var script := load("res://addons/NotificationSchedulerPlugin/NotificationData.gd")
		if script != null:
			obj = script.new()
	if obj == null:
		return null
	var ch_id: String = String(ConfigManager.get_notifications_channel().get("id", "game_reminders"))
	if obj.has_method("set_id"):
		obj.set_id(notif_id)
	if obj.has_method("set_channel_id"):
		obj.set_channel_id(ch_id)
	if obj.has_method("set_title"):
		obj.set_title(_tr(String(event_cfg.get("title_key", ""))))
	if obj.has_method("set_content"):
		obj.set_content(_tr(String(event_cfg.get("body_key", ""))))
	if obj.has_method("set_small_icon_name"):
		obj.set_small_icon_name(ConfigManager.get_notifications_small_icon())
	if obj.has_method("set_delay"):
		obj.set_delay(delay_seconds)
	return obj


func _resolve_id(event_cfg: Dictionary, suffix: String) -> int:
	if event_cfg.has("id"):
		return int(event_cfg["id"])
	if event_cfg.has("id_offset"):
		var idx: int = 0
		if suffix != "" and suffix.is_valid_int():
			idx = int(suffix)
		return int(event_cfg["id_offset"]) + idx
	return 0


func _cancel_event(event_id: String, suffix: String) -> void:
	if not _initialized or _plugin == null:
		return
	var event_cfg: Dictionary = ConfigManager.get_notification_event(event_id)
	if event_cfg.is_empty():
		return
	var notif_id: int = _resolve_id(event_cfg, suffix)
	if _plugin.has_method("cancel"):
		_plugin.cancel(notif_id)


# ─── QUIET HOURS ─────────────────────────────────────────────────────

func _apply_quiet_hours(delay_seconds: int) -> int:
	var qh: Dictionary = ConfigManager.get_notifications_quiet_hours()
	var start_h: int = int(qh.get("start_hour", 0))
	var end_h: int = int(qh.get("end_hour", 0))
	if start_h == end_h:
		return delay_seconds
	var fire_unix: int = int(Time.get_unix_time_from_system()) + delay_seconds
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(fire_unix)
	var hour: int = int(dt.get("hour", 0))
	var in_quiet: bool = false
	if start_h < end_h:
		in_quiet = hour >= start_h and hour < end_h
	else:
		# Wraps midnight, e.g. 22..9.
		in_quiet = hour >= start_h or hour < end_h
	if not in_quiet:
		return delay_seconds
	# Shift to today's/tomorrow's end_hour:00 local time.
	var shift_seconds: int = ((end_h - hour) * 3600) - int(dt.get("minute", 0)) * 60 - int(dt.get("second", 0))
	if shift_seconds <= 0:
		shift_seconds += 86400
	return delay_seconds + shift_seconds


# ─── RETENTION PINGS ─────────────────────────────────────────────────

func _schedule_retention_pings() -> void:
	if not _can_schedule():
		return
	for ev in ["retention_day_2", "retention_day_7"]:
		var cfg: Dictionary = ConfigManager.get_notification_event(ev)
		if cfg.is_empty() or not bool(cfg.get("enabled", true)):
			continue
		var delay: int = int(cfg.get("delay_hours", 48)) * 3600
		# Anchor to fire_at_local_hour: shift so wall-clock time equals the
		# requested hour on the target day.
		var target_hour: int = int(cfg.get("fire_at_local_hour", 19))
		delay = _align_to_local_hour(delay, target_hour)
		_schedule_event_with_delay(ev, "", delay)


func _cancel_retention_pings() -> void:
	_cancel_event("retention_day_2", "")
	_cancel_event("retention_day_7", "")


func _align_to_local_hour(delay_seconds: int, target_hour: int) -> int:
	var fire_unix: int = int(Time.get_unix_time_from_system()) + delay_seconds
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(fire_unix)
	var hour: int = int(dt.get("hour", 0))
	var minute: int = int(dt.get("minute", 0))
	var second: int = int(dt.get("second", 0))
	var shift: int = (target_hour - hour) * 3600 - minute * 60 - second
	if shift < 0:
		# target hour already passed today — push to next day.
		shift += 86400
	return delay_seconds + shift


# ─── COOLDOWN RESYNC ─────────────────────────────────────────────────

## On foreground (or when player flips switch on) — recompute cooldown end
## times from SaveManager state and re-schedule. Defends against:
##   • clock drift / timezone change while app was backgrounded
##   • notifications cancelled by OS (low memory, force-stop)
##   • feature flipped via Remote Config since last session
func _resync_all_cooldowns() -> void:
	if not _can_schedule():
		return
	# Gift.
	var interval_h: int = ConfigManager.get_gift_interval_hours()
	if interval_h > 0 and SaveManager.last_gift_time > 0:
		var gift_at: int = SaveManager.last_gift_time + interval_h * 3600
		schedule_gift_ready(gift_at)
	# Shop packs.
	var packs: Array = ConfigManager.shop.get("iap_items", [])
	for i in packs.size():
		var pack: Dictionary = packs[i]
		var cooldown_s: int = int(pack.get("cooldown_seconds", 0))
		if cooldown_s <= 0:
			continue
		var product_id: String = String(pack.get("id", ""))
		var last_claim: int = int(SaveManager.pack_claim_times.get(product_id, 0))
		if last_claim <= 0:
			# Never claimed — pack is currently free; no notification needed.
			continue
		var ready_at: int = last_claim + cooldown_s
		schedule_shop_pack_ready(i, ready_at)
	# Daily quests.
	schedule_daily_quests_reset()


# ─── HOOKS (called from gameplay code on user actions) ───────────────

## Call from lobby_manager._claim_gift_reward after SaveManager.last_gift_time
## is updated. Schedules the next "gift ready" at last_gift_time + interval.
func on_gift_claimed() -> void:
	if not _can_schedule():
		return
	var interval_h: int = ConfigManager.get_gift_interval_hours()
	if interval_h <= 0:
		return
	var fire_at: int = SaveManager.last_gift_time + interval_h * 3600
	schedule_gift_ready(fire_at)


## Call from shop_overlay after SaveManager.mark_pack_claimed. Pass the pack
## index (sort order in iap_items) and cooldown seconds.
func on_shop_pack_claimed(pack_index: int, cooldown_seconds: int) -> void:
	if not _can_schedule():
		return
	if cooldown_seconds <= 0:
		return
	var fire_at: int = int(Time.get_unix_time_from_system()) + cooldown_seconds
	schedule_shop_pack_ready(pack_index, fire_at)


## Call from DailyQuestManager when a fresh roll happens. We schedule the next
## reset notification.
func on_daily_quests_rolled() -> void:
	if not _can_schedule():
		return
	schedule_daily_quests_reset()


# ─── HELPERS ─────────────────────────────────────────────────────────

func _tr(key: String) -> String:
	if key == "":
		return ""
	return Translations.tr_key(key)


func _on_root_changed() -> void:
	# Stub — kept connected so we can react if needed in future. Today, all
	# state changes go through _notification().
	pass
