extends CanvasLayer

## Quest progress banner — slides in from the top of the screen when a daily
## quest's progress increments during gameplay. Shows title + animated
## progress bar (interpolating from previous → new value) + a transient "+N"
## delta label.
##
## Behavior contract:
##   • Same quest fires twice while banner visible → keep banner, continue
##     animating bar from current value to new target. Hide-timer restarts.
##   • Different quest fires while banner visible → enqueue. After current
##     banner finishes its hide animation we pop the queue.
##   • Banner is tappable → emits `banner_tapped`. main.gd routes to the
##     quests popup (opens immediately when in lobby; switches scene first
##     when in a game).
##
## Autoload registration: project.godot, after DailyQuestManager (depends on
## its signals + active state) and after ThemeManager (uses theme tokens).

signal banner_tapped()

const BANNER_HEIGHT := 100
const VISIBLE_SEC := 5.25
const SLIDE_SEC := 0.28
const PROG_ANIM_SEC := 1.65

var _banner: Control = null
var _bar: ProgressBar = null
var _count_label: Label = null
var _delta_label: Label = null
var _shown_qid: String = ""
## Per-quest snapshot of progress at the moment the LAST banner was shown
## or extended. Used to compute the delta the next signal fires. Cleared on
## daily reroll so yesterday's leftovers can't poison today's first banner.
var _last_known: Dictionary = {}
## Queue of pending banners. Each entry: {qid, prev, curr, target}. When the
## same qid fires more progress events while it sits in the queue, we MERGE
## by updating `curr` / `target` in place so a single banner cycle shows the
## full delta — no flash per increment. New increments while a DIFFERENT
## qid is on screen still enqueue normally.
var _queue: Array = []
var _hide_timer: Timer = null
## True between the moment we kick off the hide tween and the moment the
## queued next banner pops. Prevents a second banner from being added while
## the first is fading out (would visually overlap).
var _hiding: bool = false


func _ready() -> void:
	layer = 150
	DailyQuestManager.quest_progress_updated.connect(_on_progress)
	DailyQuestManager.quests_rolled.connect(_on_quests_rolled)
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = VISIBLE_SEC
	_hide_timer.timeout.connect(_start_hide)
	add_child(_hide_timer)


func _on_quests_rolled() -> void:
	_last_known.clear()
	_queue.clear()


func _on_progress(qid: String, progress: int, target: int) -> void:
	var prev: int = int(_last_known.get(qid, 0))
	if progress <= prev:
		_last_known[qid] = progress
		return
	# Same quest as the one currently displayed → extend the live banner
	# bar instead of queuing a duplicate.
	if _banner != null and not _hiding and _shown_qid == qid:
		_bar.max_value = target
		_animate_bar_to(progress)
		_flash_delta(progress - prev)
		_hide_timer.start()
		_last_known[qid] = progress
		return
	# Already queued? Merge — update curr/target in place, keep the original
	# prev so the eventual banner shows the full prev → final sweep.
	for i in _queue.size():
		if String(_queue[i].get("qid", "")) == qid:
			_queue[i]["curr"] = progress
			_queue[i]["target"] = target
			return
	# Banner busy (visible or fading out) → enqueue.
	if _banner != null or _hiding:
		_queue.append({"qid": qid, "prev": prev, "curr": progress, "target": target})
		return
	_show(qid, prev, progress, target)


func _show(qid: String, prev: int, curr: int, target: int) -> void:
	var quest: Dictionary = {}
	for q in DailyQuestManager.get_active_quests():
		if String(q.get("id", "")) == qid:
			quest = q
			break
	if quest.is_empty():
		return
	_shown_qid = qid
	_last_known[qid] = curr
	_banner = _build(quest, prev, target)
	add_child(_banner)
	_banner.offset_top = -BANNER_HEIGHT
	_banner.offset_bottom = 0
	var tw := _banner.create_tween().set_parallel(true)
	tw.tween_property(_banner, "offset_top", 0.0, SLIDE_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_banner, "offset_bottom", float(BANNER_HEIGHT), SLIDE_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_animate_bar_to(curr)
	_flash_delta(curr - prev)
	_hide_timer.start()


## Animate the bar from its current value to `value`, AND tick the
## "N / M" count label in lockstep so the right-side number rolls up
## together with the fill (not snapped at the start/end).
func _animate_bar_to(value: float) -> void:
	if _bar == null:
		return
	var from_v: float = _bar.value
	var target_max: int = int(_bar.max_value)
	var label: Label = _count_label
	var tw := _bar.create_tween().set_parallel(true)
	tw.tween_property(_bar, "value", value, PROG_ANIM_SEC) \
		.from(from_v).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(v: float) -> void:
			if is_instance_valid(label):
				label.text = "%d / %d" % [int(round(v)), target_max],
		from_v, value, PROG_ANIM_SEC
	).set_ease(Tween.EASE_OUT)


## Floating "+N" label that pops near the bar then fades. Re-triggered on
## every increment so successive bumps don't visually merge.
func _flash_delta(delta: int) -> void:
	if _delta_label == null or delta <= 0:
		return
	_delta_label.text = "+%d" % delta
	_delta_label.modulate = Color(1, 1, 1, 0.0)
	_delta_label.scale = Vector2(0.65, 0.65)
	# Pivot stays at the geometric center of the 120×44 offset rect so the
	# pop scales from the middle.
	_delta_label.pivot_offset = Vector2(60, 22)
	var tw := _delta_label.create_tween().set_parallel(true)
	tw.tween_property(_delta_label, "modulate:a", 1.0, 0.16)
	tw.tween_property(_delta_label, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Visible delta lingers proportionally to the bar animation so it stays
	# while the fill is still moving.
	var tw2 := _delta_label.create_tween()
	tw2.tween_interval(PROG_ANIM_SEC * 0.6)
	tw2.tween_property(_delta_label, "modulate:a", 0.0, 0.5)


func _start_hide() -> void:
	if _banner == null or _hiding:
		return
	_hiding = true
	var b: Control = _banner
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "offset_top", float(-BANNER_HEIGHT), SLIDE_SEC) \
		.set_ease(Tween.EASE_IN)
	tw.tween_property(b, "offset_bottom", 0.0, SLIDE_SEC) \
		.set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(b):
		b.queue_free()
	_banner = null
	_shown_qid = ""
	_bar = null
	_count_label = null
	_delta_label = null
	_hiding = false
	if not _queue.is_empty():
		await get_tree().create_timer(0.12).timeout
		var n: Dictionary = _queue.pop_front()
		_show(String(n.qid), int(n.prev), int(n.curr), int(n.target))


func _build(q: Dictionary, prev_progress: int, target: int) -> Control:
	var theme_font: Font = ThemeManager.font()

	# Banner spans the middle third of the screen, anchored to the top edge.
	# anchor_left/right at 1/3 and 2/3 → 33% width on any aspect ratio.
	# offset_top starts negative (off-screen) and animates to 0 in _show.
	var root := Control.new()
	root.anchor_left = 1.0 / 3.0
	root.anchor_right = 2.0 / 3.0
	root.anchor_top = 0.0
	root.anchor_bottom = 0.0
	root.offset_left = 0
	root.offset_right = 0
	root.offset_top = 0
	root.offset_bottom = BANNER_HEIGHT
	root.custom_minimum_size = Vector2(0, BANNER_HEIGHT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_tap()
	)
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeManager.color("panel_bg", Color(0.10, 0.13, 0.27, 0.97))
	s.border_color = ThemeManager.color("panel_border", Color("FFEC00"))
	s.set_border_width_all(2)
	s.border_width_bottom = 5
	# Banner sits flush against the screen top — square the top corners
	# and round only the bottom so it reads as a tab-like strip dropping
	# down. Also add a strong drop shadow for separation from gameplay.
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", s)
	root.add_child(panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)

	# Icon (clipboard, theme-resolved). Smaller than the popup-card icon
	# since the banner is only 1/3 of viewport width.
	var icon_path: String = ThemeManager.ui_icon_path("quests")
	if icon_path != "":
		var ico := TextureRect.new()
		ico.texture = load(icon_path)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.custom_minimum_size = Vector2(44, 44)
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ico)

	# Title + progress column.
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(vb)

	var tag := Label.new()
	tag.text = Translations.tr_key("quest.banner.label")
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color",
		ThemeManager.color("sidebar_active_text", Color("FFEC00")))
	if theme_font != null:
		tag.add_theme_font_override("font", theme_font)
	vb.add_child(tag)

	var title := Label.new()
	title.text = _format_quest_title(q)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color",
		ThemeManager.color("body_text", Color.WHITE))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if theme_font != null:
		title.add_theme_font_override("font", theme_font)
	vb.add_child(title)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	vb.add_child(prow)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = target
	_bar.value = prev_progress
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeManager.color("panel_border", Color("FFEC00"))
	fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", fill)
	var bgst := StyleBoxFlat.new()
	bgst.bg_color = Color(0, 0, 0, 0.6)
	bgst.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", bgst)
	prow.add_child(_bar)

	_count_label = Label.new()
	_count_label.text = "%d / %d" % [prev_progress, target]
	_count_label.custom_minimum_size = Vector2(80, 0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	if theme_font != null:
		_count_label.add_theme_font_override("font", theme_font)
	prow.add_child(_count_label)

	# Floating "+N" delta — overlaid on the CENTER of the progress bar so
	# the eye links the delta to the growing fill. Parented to the bar so
	# clipping isn't an issue (Control children aren't auto-clipped). The
	# offset rectangle (120×44) extends above/below the 14px bar — that's
	# fine, the label is non-blocking and renders unclipped.
	_delta_label = Label.new()
	_delta_label.add_theme_font_size_override("font_size", 24)
	_delta_label.add_theme_color_override("font_color", Color("3DD158"))
	_delta_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_delta_label.add_theme_constant_override("outline_size", 4)
	if theme_font != null:
		_delta_label.add_theme_font_override("font", theme_font)
	_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_delta_label.anchor_left = 0.5
	_delta_label.anchor_right = 0.5
	_delta_label.anchor_top = 0.5
	_delta_label.anchor_bottom = 0.5
	_delta_label.offset_left = -60
	_delta_label.offset_right = 60
	_delta_label.offset_top = -22
	_delta_label.offset_bottom = 22
	_delta_label.pivot_offset = Vector2(60, 22)
	_delta_label.modulate = Color(1, 1, 1, 0.0)
	_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_delta_label)

	return root


## Banner title — quest description without machine/mode suffix to keep the
## strip readable. The popup (opened on tap) shows the full filtered text.
func _format_quest_title(q: Dictionary) -> String:
	var qtype: String = String(q.get("type", ""))
	var target: int = int(q.get("target", 1))
	var rank_name: String = _localized_hand_name(String(q.get("hand_rank", "")))
	var args: Array = []
	match qtype:
		"play_hands", "win_hands", "play_different_machines":
			args = [target]
		"accumulate_winnings", "total_bet":
			args = [SaveManager.format_money(target)]
		"collect_combo":
			args = [rank_name, target]
		"score_specific_hand":
			args = [rank_name]
		_:
			args = [target]
	return Translations.tr_key("quest.desc." + qtype, args)


func _localized_hand_name(rank_name: String) -> String:
	var key_map := {
		"JACKS_OR_BETTER": "jacks_or_better",
		"TWO_PAIR": "two_pair",
		"THREE_OF_A_KIND": "three_of_a_kind",
		"STRAIGHT": "straight",
		"FLUSH": "flush",
		"FULL_HOUSE": "full_house",
		"FOUR_OF_A_KIND": "four_of_a_kind",
		"STRAIGHT_FLUSH": "straight_flush",
		"ROYAL_FLUSH": "royal_flush",
	}
	var pkey: String = key_map.get(rank_name, rank_name.to_lower())
	return Translations.tr_key("hand." + pkey)


func _on_tap() -> void:
	banner_tapped.emit()
	_hide_timer.stop()
	_start_hide()
