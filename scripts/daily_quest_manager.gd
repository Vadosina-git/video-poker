extends Node

## DailyQuestManager — autoload that owns the daily-quest lifecycle:
##   • At startup, compares saved date_iso to today's local date and rolls
##     a fresh set of quests if the day changed.
##   • Watches gameplay via attach_to_game(scene, variant_id, mode) — main.gd
##     calls this every time it loads a game scene. Internally connects to
##     the right manager signal and routes results into _on_round_complete.
##   • Tracks per-quest progress, persists to SaveManager.daily_quest_state
##     after every change, emits signals for live UI updates.
##
## Quest type matchers live in _match_and_advance — single switch on quest.type.
## Add a new type by extending the switch and adding `quest.desc.<type>` to
## translations.

signal quest_progress_updated(quest_id: String, progress: int, target: int)
signal quest_completed(quest_id: String)
signal quest_claimed(quest_id: String, reward: int)
signal quests_rolled()


## Map from JSON hand_rank string to HandEvaluator.HandRank enum value.
## Quest configs use string names so they're readable in the JSON file.
const _HAND_RANK_BY_NAME := {
	"NOTHING": 0,
	"JACKS_OR_BETTER": 1,
	"TWO_PAIR": 2,
	"THREE_OF_A_KIND": 3,
	"STRAIGHT": 4,
	"FLUSH": 5,
	"FULL_HOUSE": 6,
	"FOUR_OF_A_KIND": 7,
	"STRAIGHT_FLUSH": 8,
	"ROYAL_FLUSH": 9,
}

## Tracks the manager we're currently attached to so we can disconnect when
## the player leaves the game scene (avoids dangling connections / double-fire).
var _attached_manager: Node = null
var _attached_variant_id: String = ""
var _attached_mode: String = ""


func _ready() -> void:
	_ensure_today_rolled()


# ─── DAILY ROLL ───────────────────────────────────────────────────────

func _today_iso() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## Returns seconds until next local midnight. UI countdown reads this.
func time_to_reset_seconds() -> int:
	var d := Time.get_datetime_dict_from_system()
	var seconds_today: int = int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"])
	return max(0, 86400 - seconds_today)


## Rolls fresh quests if the saved day != today. Idempotent — safe to call any time.
func _ensure_today_rolled() -> void:
	var state: Dictionary = SaveManager.daily_quest_state if SaveManager.daily_quest_state is Dictionary else {}
	var saved_date: String = String(state.get("date_iso", ""))
	if saved_date == _today_iso() and state.has("active"):
		return
	_roll_new_quests()


func _roll_new_quests() -> void:
	var pool: Array = ConfigManager.get_daily_quest_pool()
	var picks: int = ConfigManager.get_daily_quest_picks_per_day()
	var enabled_pool: Array = []
	for q in pool:
		if q is Dictionary and bool(q.get("enabled", true)):
			enabled_pool.append(q)
	enabled_pool.shuffle()
	var chosen: Array = enabled_pool.slice(0, mini(picks, enabled_pool.size()))
	var active: Array = []
	for q in chosen:
		var entry := {
			"quest_id": String(q.get("id", "")),
			"progress": 0,
			"claimed": false,
		}
		# play_different_machines tracks distinct variant ids in a sidecar set.
		if String(q.get("type", "")) == "play_different_machines":
			entry["machines_seen"] = []
		active.append(entry)
	SaveManager.set_daily_quest_state({
		"date_iso": _today_iso(),
		"active": active,
	})
	quests_rolled.emit()
	NotificationManager.on_daily_quests_rolled()


# ─── PUBLIC API ───────────────────────────────────────────────────────

## Returns merged quest data for UI: each entry has the config fields plus
## current progress / claimed flags. Skips active entries whose quest_id no
## longer exists in the pool (config edits, remote-config wipes).
func get_active_quests() -> Array:
	_ensure_today_rolled()
	var pool_by_id := _pool_index()
	var state: Dictionary = SaveManager.daily_quest_state
	var active: Array = state.get("active", [])
	var result: Array = []
	for entry in active:
		if not (entry is Dictionary):
			continue
		var qid: String = String(entry.get("quest_id", ""))
		if not pool_by_id.has(qid):
			continue
		var cfg: Dictionary = pool_by_id[qid]
		var merged := cfg.duplicate(true)
		merged["progress"] = int(entry.get("progress", 0))
		merged["claimed"] = bool(entry.get("claimed", false))
		merged["target"] = int(cfg.get("target", 1))
		result.append(merged)
	return result


## Returns "go" | "claim" | "claimed" — drives the button label/state.
func get_button_state(quest_id: String) -> String:
	for q in get_active_quests():
		if String(q.get("id", "")) != quest_id:
			continue
		if bool(q.get("claimed", false)):
			return "claimed"
		if int(q.get("progress", 0)) >= int(q.get("target", 1)):
			return "claim"
		return "go"
	return "claimed"


## For "Go to" button: which machine/mode the player should be sent to.
## Returns {"variant_id": String, "mode": String} — both can be empty.
##   • variant_id empty → no specific machine; popup just closes (or switches mode tab).
##   • mode empty → any mode. UI uses lobby's currently selected mode.
func get_navigation_target(quest_id: String) -> Dictionary:
	var cfg: Dictionary = _pool_index().get(quest_id, {})
	if cfg.is_empty():
		return {"variant_id": "", "mode": ""}
	var machines: Array = cfg.get("machines", [])
	var modes: Array = cfg.get("modes", [])
	return {
		"variant_id": String(machines[0]) if machines.size() > 0 else "",
		"mode": String(modes[0]) if modes.size() > 0 else "",
	}


## Claim reward. Idempotent — repeated calls after first success return 0.
## Returns reward amount actually awarded (0 if not claimable).
func claim_reward(quest_id: String) -> int:
	var state: Dictionary = SaveManager.daily_quest_state
	var active: Array = state.get("active", [])
	var pool_by_id := _pool_index()
	for i in active.size():
		var entry: Dictionary = active[i]
		if String(entry.get("quest_id", "")) != quest_id:
			continue
		if bool(entry.get("claimed", false)):
			return 0
		var cfg: Dictionary = pool_by_id.get(quest_id, {})
		if cfg.is_empty():
			return 0
		if int(entry.get("progress", 0)) < int(cfg.get("target", 1)):
			return 0
		# Mark claimed BEFORE awarding so a double-tap can't double-pay.
		entry["claimed"] = true
		active[i] = entry
		state["active"] = active
		SaveManager.set_daily_quest_state(state)
		var reward: int = int(cfg.get("reward", 0))
		if reward > 0:
			SaveManager.add_credits(reward)
		quest_claimed.emit(quest_id, reward)
		return reward
	return 0


# ─── GAME-MANAGER HOOK ────────────────────────────────────────────────

## Called by main.gd each time it loads a game scene. Finds the relevant
## manager and connects to its result signal. Disconnects any prior hook.
func attach_to_game(scene: Node, variant_id: String, mode: String) -> void:
	detach_from_game()
	if scene == null:
		return
	# Manager is named "GameManager" / "MultiHandManager" / "SpinPokerManager"
	# inside the scene root or — fallback — searched as a node child.
	var mgr: Node = _find_game_manager(scene)
	if mgr == null:
		return
	_attached_manager = mgr
	_attached_variant_id = variant_id
	_attached_mode = mode
	if mgr.has_signal("hand_evaluated"):
		mgr.hand_evaluated.connect(_on_single_hand_evaluated)
	elif mgr.has_signal("all_hands_evaluated"):
		mgr.all_hands_evaluated.connect(_on_multi_hands_evaluated)
	elif mgr.has_signal("lines_evaluated"):
		mgr.lines_evaluated.connect(_on_spin_lines_evaluated)


func detach_from_game() -> void:
	if _attached_manager == null or not is_instance_valid(_attached_manager):
		_attached_manager = null
		return
	if _attached_manager.has_signal("hand_evaluated") and _attached_manager.hand_evaluated.is_connected(_on_single_hand_evaluated):
		_attached_manager.hand_evaluated.disconnect(_on_single_hand_evaluated)
	if _attached_manager.has_signal("all_hands_evaluated") and _attached_manager.all_hands_evaluated.is_connected(_on_multi_hands_evaluated):
		_attached_manager.all_hands_evaluated.disconnect(_on_multi_hands_evaluated)
	if _attached_manager.has_signal("lines_evaluated") and _attached_manager.lines_evaluated.is_connected(_on_spin_lines_evaluated):
		_attached_manager.lines_evaluated.disconnect(_on_spin_lines_evaluated)
	_attached_manager = null
	_attached_variant_id = ""
	_attached_mode = ""


func _find_game_manager(scene: Node) -> Node:
	for child in scene.get_children():
		if child.has_signal("hand_evaluated") or child.has_signal("all_hands_evaluated") or child.has_signal("lines_evaluated"):
			return child
	# Some scenes attach the manager script to the root.
	if scene.has_signal("hand_evaluated") or scene.has_signal("all_hands_evaluated") or scene.has_signal("lines_evaluated"):
		return scene
	return null


# ─── SIGNAL ADAPTERS ──────────────────────────────────────────────────

## Single-hand: GameManager.hand_evaluated(rank, name, payout)
func _on_single_hand_evaluated(rank: int, _name: String, payout: int) -> void:
	var bet_coins: int = _current_total_bet_coins(1)
	_on_round_complete([{"hand_rank": rank, "payout": payout}], bet_coins)


## Multi-hand: MultiHandManager.all_hands_evaluated(results, total_payout)
func _on_multi_hands_evaluated(results: Array, _total_payout: int) -> void:
	var num_hands: int = results.size() if results.size() > 0 else 1
	var bet_coins: int = _current_total_bet_coins(num_hands)
	_on_round_complete(results, bet_coins)


## Spin Poker: SpinPokerManager.lines_evaluated(results, total_payout)
func _on_spin_lines_evaluated(results: Array, _total_payout: int) -> void:
	# Spin Poker total bet is bet * 20 lines * denom in spin_poker_manager —
	# but matcher only cares about coins wagered this round, which the manager
	# tracks. Read back via property if available, else fall back to single bet.
	var num_lines: int = 20
	var bet_coins: int = _current_total_bet_coins(num_lines)
	_on_round_complete(results, bet_coins)


## Best-effort bet readback. Multi/spin multiply the per-hand bet by
## hand_count / line_count. Falls back to (bet * denom * multiplier).
func _current_total_bet_coins(multiplier: int) -> int:
	if _attached_manager == null or not is_instance_valid(_attached_manager):
		return 0
	var bet: int = 0
	if "bet" in _attached_manager:
		bet = int(_attached_manager.get("bet"))
	var denom: int = SaveManager.denomination
	return bet * denom * max(multiplier, 1)


# ─── PROGRESS PIPELINE ────────────────────────────────────────────────

## results: Array of {hand_rank, payout, ...} — single-hand wraps one entry.
func _on_round_complete(results: Array, total_bet_coins: int) -> void:
	if _attached_variant_id == "":
		return
	_ensure_today_rolled()
	var state: Dictionary = SaveManager.daily_quest_state
	var active: Array = state.get("active", [])
	var pool_by_id := _pool_index()
	var changed := false
	for i in active.size():
		var entry: Dictionary = active[i]
		var qid: String = String(entry.get("quest_id", ""))
		var cfg: Dictionary = pool_by_id.get(qid, {})
		if cfg.is_empty() or bool(entry.get("claimed", false)):
			continue
		if not _passes_filters(cfg):
			continue
		var before: int = int(entry.get("progress", 0))
		var target: int = int(cfg.get("target", 1))
		if before >= target:
			continue
		_match_and_advance(cfg, entry, results, total_bet_coins)
		var after: int = int(entry.get("progress", 0))
		if after != before:
			active[i] = entry
			changed = true
			quest_progress_updated.emit(qid, after, target)
			if before < target and after >= target:
				quest_completed.emit(qid)
	if changed:
		state["active"] = active
		SaveManager.set_daily_quest_state(state)


## Filter check: machines / modes restrictions on currently attached game.
func _passes_filters(cfg: Dictionary) -> bool:
	var machines: Array = cfg.get("machines", [])
	if machines.size() > 0 and not (_attached_variant_id in machines):
		return false
	var modes: Array = cfg.get("modes", [])
	if modes.size() > 0 and not (_attached_mode in modes):
		return false
	return true


## Per-type progress increment. Mutates `entry` in place.
func _match_and_advance(cfg: Dictionary, entry: Dictionary, results: Array, total_bet_coins: int) -> void:
	var qtype: String = String(cfg.get("type", ""))
	match qtype:
		"play_hands":
			# Multi/spin: results.size() hands per round; single: 1.
			entry["progress"] = int(entry.get("progress", 0)) + maxi(1, results.size())
		"win_hands":
			var wins: int = 0
			for r in results:
				if int(r.get("payout", 0)) > 0:
					wins += 1
			entry["progress"] = int(entry.get("progress", 0)) + wins
		"collect_combo":
			var target_rank: int = _resolve_rank(cfg)
			var hits: int = 0
			for r in results:
				if int(r.get("hand_rank", 0)) == target_rank:
					hits += 1
			entry["progress"] = int(entry.get("progress", 0)) + hits
		"accumulate_winnings":
			var sum: int = 0
			for r in results:
				sum += maxi(int(r.get("payout", 0)), 0)
			entry["progress"] = int(entry.get("progress", 0)) + sum
		"score_specific_hand":
			var rank: int = _resolve_rank(cfg)
			for r in results:
				if int(r.get("hand_rank", 0)) == rank:
					entry["progress"] = int(cfg.get("target", 1))
					break
		"total_bet":
			entry["progress"] = int(entry.get("progress", 0)) + max(total_bet_coins, 0)
		"play_different_machines":
			var seen: Array = entry.get("machines_seen", [])
			if not (_attached_variant_id in seen):
				seen.append(_attached_variant_id)
				entry["machines_seen"] = seen
				entry["progress"] = seen.size()
		_:
			pass  # Unknown type — silently ignore.


func _resolve_rank(cfg: Dictionary) -> int:
	return int(_HAND_RANK_BY_NAME.get(String(cfg.get("hand_rank", "")), -1))


## True when at least one active quest is completed but not yet claimed —
## used by the lobby top-bar badge ("red dot" indicator on the quests icon)
## to mirror the existing shop badge pattern.
func has_claimable() -> bool:
	for q in get_active_quests():
		if bool(q.get("claimed", false)):
			continue
		if int(q.get("progress", 0)) >= int(q.get("target", 1)):
			return true
	return false


## Re-fires the currently-attached game manager's `credits_changed` signal
## with the post-claim balance. Game scenes update their balance label by
## listening to this — without an explicit notify they stay stale because
## DailyQuestManager.claim_reward calls SaveManager.add_credits silently.
func notify_credits_changed() -> void:
	if _attached_manager == null or not is_instance_valid(_attached_manager):
		return
	if _attached_manager.has_signal("credits_changed"):
		_attached_manager.credits_changed.emit(SaveManager.credits)


func _pool_index() -> Dictionary:
	var idx: Dictionary = {}
	for q in ConfigManager.get_daily_quest_pool():
		if q is Dictionary:
			idx[String(q.get("id", ""))] = q
	return idx
