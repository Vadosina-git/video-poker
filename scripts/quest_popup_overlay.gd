extends CanvasLayer

## Daily Quests popup — extracted from lobby_manager.gd into a global
## autoload so the same window can be opened over the lobby (top-bar icon)
## OR over any game scene (banner tap during play). Single source of truth
## for layout, styling, and quest-card behavior.
##
## Routing:
##   • Card "GO" emits `go_requested(variant_id, mode)`. main.gd is the
##     sole handler — it sets SaveManager state and triggers the machine
##     load via the existing loader path, regardless of which scene is
##     currently active.
##   • Card "CLAIM" awards credits inline (DailyQuestManager.claim_reward),
##     then asks the active scene for a chip cascade if it supports one
##     (lobby does, game scenes don't — they fall back to silent credit).
##
## Autoload registration: project.godot, after DailyQuestManager (signals)
## and ThemeManager (theme tokens).

signal go_requested(variant_id: String, mode: String)

const _QUEST_TYPE_ACCENT := {
	"play_hands":              Color("4FC3F7"),
	"win_hands":               Color("66BB6A"),
	"collect_combo":           Color("BA68C8"),
	"accumulate_winnings":     Color("FFB300"),
	"score_specific_hand":     Color("EC407A"),
	"total_bet":               Color("FF7043"),
	"play_different_machines": Color("26C6DA"),
}

var _overlay: Control = null
var _list_box: VBoxContainer = null
var _countdown_label: Label = null
var _countdown_timer: Timer = null
var _show_all_pool: bool = false
var _cheat_btn: Button = null


func _ready() -> void:
	# Layer 120 — above the banner (150 reserved? — banner at 150, popup
	# below banner so a banner shown DURING popup view sits on top). Adjust
	# if the design changes.
	layer = 120


# ─── PUBLIC API ───────────────────────────────────────────────────────

func show_popup() -> void:
	if _overlay != null:
		return
	_build_popup()


func hide_popup() -> void:
	_disconnect_signals()
	if _countdown_timer:
		_countdown_timer.stop()
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_list_box = null
	_countdown_label = null
	_cheat_btn = null
	_show_all_pool = false


# ─── BUILD ────────────────────────────────────────────────────────────

func _build_popup() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			hide_popup()
	)
	_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(680, 820)
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = ThemeManager.color("panel_bg", Color(0.05, 0.05, 0.18, 0.98))
	pstyle.set_border_width_all(int(ThemeManager.size("border_width", 3)))
	pstyle.border_color = ThemeManager.color("panel_border", Color("FFEC00"))
	pstyle.set_corner_radius_all(int(ThemeManager.size("corner_radius", 12)))
	pstyle.content_margin_left = 28
	pstyle.content_margin_right = 28
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var theme_font: Font = ThemeManager.font()

	var title := Label.new()
	title.text = Translations.tr_key("quests.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ThemeManager.color("title_text", Color.WHITE))
	title.add_theme_color_override("font_outline_color", ThemeManager.color("title_outline", Color.BLACK))
	title.add_theme_constant_override("outline_size", 4)
	if theme_font != null:
		title.add_theme_font_override("font", theme_font)
	vb.add_child(title)

	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 16)
	_countdown_label.add_theme_color_override("font_color",
		ThemeManager.color("body_text", Color(0.85, 0.85, 0.85, 1)))
	if theme_font != null:
		_countdown_label.add_theme_font_override("font", theme_font)
	_countdown_label.modulate = Color(1, 1, 1, 0.85)
	vb.add_child(_countdown_label)
	_update_countdown_label()

	if _countdown_timer == null:
		_countdown_timer = Timer.new()
		_countdown_timer.wait_time = 1.0
		_countdown_timer.autostart = false
		_countdown_timer.timeout.connect(_update_countdown_label)
		add_child(_countdown_timer)
	_countdown_timer.start()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 14)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	_rebuild_list()

	_connect_signals()

	var close := Button.new()
	close.text = Translations.tr_key("settings.close")
	close.custom_minimum_size = Vector2(0, 48)
	var cs := StyleBoxFlat.new()
	cs.bg_color = ThemeManager.color("button_primary_bg", Color("FFEC00"))
	cs.set_corner_radius_all(int(ThemeManager.size("button_corner_radius", 10)))
	close.add_theme_stylebox_override("normal", cs)
	close.add_theme_stylebox_override("hover", cs)
	close.add_theme_stylebox_override("pressed", cs)
	close.add_theme_stylebox_override("focus", cs)
	close.add_theme_color_override("font_color",
		ThemeManager.color("button_primary_text", Color.BLACK))
	close.add_theme_font_size_override("font_size", 18)
	if theme_font != null:
		close.add_theme_font_override("font", theme_font)
	close.pressed.connect(hide_popup)
	vb.add_child(close)

	# Designer cheats — pool browser + progress reset.
	var cheat_row := HBoxContainer.new()
	cheat_row.add_theme_constant_override("separation", 8)
	vb.add_child(cheat_row)

	_cheat_btn = _make_cheat_button(
		Translations.tr_key("quest.cheat.show_all"),
		_toggle_cheat,
		theme_font)
	cheat_row.add_child(_cheat_btn)

	var reset_btn: Button = _make_cheat_button(
		Translations.tr_key("quest.cheat.reset"),
		_on_cheat_reset_pressed,
		theme_font)
	cheat_row.add_child(reset_btn)

	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)


# ─── SIGNALS WIRE-UP ──────────────────────────────────────────────────

func _connect_signals() -> void:
	if not DailyQuestManager.quest_progress_updated.is_connected(_on_state_changed):
		DailyQuestManager.quest_progress_updated.connect(_on_state_changed)
	if not DailyQuestManager.quest_completed.is_connected(_on_completed):
		DailyQuestManager.quest_completed.connect(_on_completed)
	if not DailyQuestManager.quest_claimed.is_connected(_on_claimed):
		DailyQuestManager.quest_claimed.connect(_on_claimed)


func _disconnect_signals() -> void:
	if DailyQuestManager.quest_progress_updated.is_connected(_on_state_changed):
		DailyQuestManager.quest_progress_updated.disconnect(_on_state_changed)
	if DailyQuestManager.quest_completed.is_connected(_on_completed):
		DailyQuestManager.quest_completed.disconnect(_on_completed)
	if DailyQuestManager.quest_claimed.is_connected(_on_claimed):
		DailyQuestManager.quest_claimed.disconnect(_on_claimed)


func _on_state_changed(_qid: String, _progress: int, _target: int) -> void:
	if _list_box:
		_rebuild_list()


func _on_completed(_qid: String) -> void:
	if _list_box:
		_rebuild_list()


func _on_claimed(_qid: String, _reward: int) -> void:
	if _list_box:
		_rebuild_list()


# ─── COUNTDOWN ────────────────────────────────────────────────────────

func _update_countdown_label() -> void:
	if _countdown_label == null:
		return
	var secs: int = DailyQuestManager.time_to_reset_seconds()
	_countdown_label.text = Translations.tr_key("quests.time_to_reset_fmt",
		[_format_countdown(secs)])


func _format_countdown(secs: int) -> String:
	@warning_ignore("integer_division")
	var h: int = secs / 3600
	@warning_ignore("integer_division")
	var m: int = (secs / 60) % 60
	var s: int = secs % 60
	return "%02d:%02d:%02d" % [h, m, s]


# ─── LIST + CARD BUILDERS ─────────────────────────────────────────────

func _rebuild_list() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var quests: Array
	if _show_all_pool:
		quests = []
		for cfg in ConfigManager.get_daily_quest_pool():
			if not (cfg is Dictionary):
				continue
			var merged: Dictionary = (cfg as Dictionary).duplicate(true)
			merged["progress"] = 0
			merged["claimed"] = false
			merged["target"] = int(cfg.get("target", 1))
			quests.append(merged)
	else:
		quests = DailyQuestManager.get_active_quests()
	if quests.is_empty():
		var empty := Label.new()
		empty.text = Translations.tr_key("quests.empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color",
			ThemeManager.color("body_text", Color.WHITE))
		_list_box.add_child(empty)
		return
	for q in quests:
		_list_box.add_child(_build_card(q))


func _build_card(q: Dictionary) -> Control:
	var qtype: String = String(q.get("type", ""))
	var qid: String = String(q.get("id", ""))
	var state := DailyQuestManager.get_button_state(qid)
	var is_claimed: bool = state == "claimed"
	var accent: Color = _QUEST_TYPE_ACCENT.get(qtype, Color("4FC3F7"))
	if is_claimed:
		accent = accent.darkened(0.5)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	var base_bg: Color = ThemeManager.color("paytable_bg", Color(0.13, 0.16, 0.30, 1.0))
	card_style.bg_color = base_bg.lightened(0.05) if not is_claimed else base_bg.darkened(0.20)
	card_style.set_border_width_all(2)
	card_style.border_color = accent * Color(1, 1, 1, 0.55)
	card_style.border_width_bottom = 5
	card_style.set_corner_radius_all(16)
	card_style.shadow_color = Color(0, 0, 0, 0.45)
	card_style.shadow_size = 4
	card_style.shadow_offset = Vector2(0, 3)
	card_style.content_margin_left = 0
	card_style.content_margin_right = 16
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var stripe := PanelContainer.new()
	stripe.custom_minimum_size = Vector2(8, 0)
	stripe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stripe_style := StyleBoxFlat.new()
	stripe_style.bg_color = accent
	stripe_style.corner_radius_top_right = 4
	stripe_style.corner_radius_bottom_right = 4
	stripe.add_theme_stylebox_override("panel", stripe_style)
	row.add_child(stripe)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(64, 64)
	icon_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var disc_color: Color = accent
	icon_holder.draw.connect(func() -> void:
		var sz: Vector2 = icon_holder.size
		var ctr: Vector2 = sz * 0.5
		var r: float = minf(sz.x, sz.y) * 0.5 - 2.0
		icon_holder.draw_circle(ctr + Vector2(0, 2), r, Color(0, 0, 0, 0.35))
		icon_holder.draw_circle(ctr, r, disc_color)
		icon_holder.draw_arc(ctr, r - 1.0, 0, TAU, 64,
			disc_color.darkened(0.30), 2.0, true)
	)
	row.add_child(icon_holder)

	var icon_path: String = ThemeManager.ui_icon_path("quests")
	if icon_path != "":
		var ico := TextureRect.new()
		ico.texture = load(icon_path)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.set_anchors_preset(Control.PRESET_FULL_RECT)
		ico.offset_left = 14
		ico.offset_top = 14
		ico.offset_right = -14
		ico.offset_bottom = -14
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(ico)

	var theme_font: Font = ThemeManager.font()

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	body.add_child(title_row)

	var title := Label.new()
	title.text = _format_desc(q)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color",
		ThemeManager.color("body_text", Color.WHITE))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	if theme_font != null:
		title.add_theme_font_override("font", theme_font)
	title_row.add_child(title)

	var reward_pill: Control = _make_reward_pill(int(q.get("reward", 0)), is_claimed)
	reward_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(reward_pill)

	var progress_target: int = int(q.get("target", 1))
	var progress_now: int = mini(int(q.get("progress", 0)), progress_target)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 10)
	body.add_child(progress_row)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = progress_target
	bar.value = progress_now
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = accent
	fill_style.border_color = accent.lightened(0.30)
	fill_style.border_width_top = 2
	fill_style.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.55)
	bg_style.border_color = Color(0, 0, 0, 0.7)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("background", bg_style)
	progress_row.add_child(bar)

	var prog_label := Label.new()
	prog_label.text = "%d / %d" % [progress_now, progress_target]
	prog_label.custom_minimum_size = Vector2(78, 0)
	prog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_label.add_theme_font_size_override("font_size", 15)
	prog_label.add_theme_color_override("font_color",
		ThemeManager.color("body_text", Color.WHITE))
	if theme_font != null:
		prog_label.add_theme_font_override("font", theme_font)
	progress_row.add_child(prog_label)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 64)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if theme_font != null:
		btn.add_theme_font_override("font", theme_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_constant_override("outline_size", 3)
	row.add_child(btn)

	_style_button(btn, state)
	match state:
		"go":
			btn.text = Translations.tr_key("quest.btn.go")
			btn.pressed.connect(func() -> void: _on_go_pressed(qid))
		"claim":
			btn.text = Translations.tr_key("quest.btn.claim")
			btn.pressed.connect(func() -> void: _on_claim_pressed(qid, card))
		"claimed":
			btn.text = Translations.tr_key("quest.btn.claimed")
			btn.disabled = true
		_:
			btn.text = ""
			btn.disabled = true

	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.18) \
		.set_ease(Tween.EASE_OUT)
	if is_claimed:
		card.modulate = Color(1, 1, 1, 0.55)
	return card


func _make_reward_pill(amount: int, dimmed: bool) -> Control:
	var pill := PanelContainer.new()
	var s := StyleBoxFlat.new()
	var fill: Color = ThemeManager.color("button_primary_bg", Color("FFEC00"))
	if dimmed:
		fill = fill.darkened(0.45)
	s.bg_color = fill
	s.border_color = fill.darkened(0.30)
	s.border_width_bottom = 3
	s.set_corner_radius_all(20)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", s)
	var text_color: Color = ThemeManager.color("button_primary_text",
		Color(0.05, 0.05, 0.10))
	var cd: Dictionary = SaveManager.create_currency_display(20, text_color)
	SaveManager.set_currency_value(cd, SaveManager.format_money(amount), 20, text_color)
	var box: HBoxContainer = cd["box"]
	pill.add_child(box)
	return pill


func _style_button(btn: Button, state: String) -> void:
	var bg: Color
	var fg: Color
	var fg_hover: Color = Color(0, 0, 0, 0)
	match state:
		"claim":
			bg = ThemeManager.color("button_primary_bg", Color("FFEC00"))
			fg = ThemeManager.color("button_primary_text", Color.BLACK)
		"go":
			bg = Color("3DD158")
			fg = Color.WHITE
			fg_hover = ThemeManager.color("button_primary_bg", Color("FFEC00"))
		_:
			bg = Color(0.32, 0.32, 0.36, 1)
			fg = Color(0.78, 0.78, 0.78, 1)

	var corner: int = 16
	var lip: Color = bg.darkened(0.40)

	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(corner)
	s.border_color = lip
	s.border_width_bottom = 6
	s.content_margin_top = 8
	s.content_margin_bottom = 4
	s.content_margin_left = 16
	s.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.add_theme_stylebox_override("disabled", s)

	var sh := s.duplicate()
	sh.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", sh)

	var sp := StyleBoxFlat.new()
	sp.bg_color = bg.darkened(0.05)
	sp.set_corner_radius_all(corner)
	sp.border_color = lip
	sp.border_width_bottom = 0
	sp.content_margin_top = 14
	sp.content_margin_bottom = 4
	sp.content_margin_left = 16
	sp.content_margin_right = 16
	btn.add_theme_stylebox_override("pressed", sp)

	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_color_disabled", fg)
	if fg_hover.a > 0.0:
		btn.add_theme_color_override("font_color_hover", fg_hover)
		btn.add_theme_color_override("font_color_pressed", fg_hover)


# ─── DESCRIPTION FORMATTING ───────────────────────────────────────────

func _format_desc(q: Dictionary) -> String:
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
	var base := Translations.tr_key("quest.desc." + qtype, args)
	var machines: Array = q.get("machines", [])
	var modes: Array = q.get("modes", [])
	var parts: Array = []
	if machines.size() == 1:
		parts.append(_machine_display_name(String(machines[0])))
	if modes.size() == 1:
		parts.append(Translations.tr_key("lobby.mode_" + String(modes[0])))
	if not parts.is_empty():
		var joiner := " — "
		base += " " + Translations.tr_key("quest.suffix_fmt", [joiner.join(parts)])
	return base


func _machine_display_name(variant_id: String) -> String:
	var theme_title := ThemeManager.machine_title(variant_id)
	if theme_title != "":
		return theme_title.replace("\n", " ").strip_edges()
	return Translations.tr_key("machine.%s.name" % variant_id)


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


# ─── CARD ACTIONS ─────────────────────────────────────────────────────

func _on_go_pressed(quest_id: String) -> void:
	var target: Dictionary = DailyQuestManager.get_navigation_target(quest_id)
	var target_mode: String = String(target.get("mode", ""))
	var target_variant: String = String(target.get("variant_id", ""))
	# No explicit machine → fall back to last_variant; brand-new player
	# (no save / empty) → jacks_or_better single_play.
	if target_variant == "":
		target_variant = SaveManager.last_variant
		if target_variant == "":
			target_variant = "jacks_or_better"
			if target_mode == "":
				target_mode = "single_play"
	hide_popup()
	# main.gd is the sole subscriber — handles mode + last_variant + scene
	# transition + machine load uniformly regardless of caller.
	go_requested.emit(target_variant, target_mode)


func _on_claim_pressed(quest_id: String, source: Control) -> void:
	var old_credits: int = SaveManager.credits
	var reward: int = DailyQuestManager.claim_reward(quest_id)
	if reward <= 0:
		return
	SoundManager.play("gift_claim")
	# Visual chip cascade — only meaningful when the lobby balance pill is
	# visible (i.e. popup opened over lobby). In game scenes the cascade
	# helpers don't exist, so we silently bump credits instead.
	var current_scene: Node = _active_scene()
	if current_scene and current_scene.has_method("_spawn_chip_cascade") \
			and is_instance_valid(source):
		var from_pos: Vector2 = source.global_position + source.size * 0.5
		if current_scene.has_method("_spawn_confetti_burst"):
			current_scene._spawn_confetti_burst(from_pos)
		current_scene._spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)


func _active_scene() -> Node:
	var main: Node = get_node_or_null("/root/Main")
	if main and "_current_scene" in main:
		return main.get("_current_scene")
	return null


# ─── CHEATS ───────────────────────────────────────────────────────────

func _toggle_cheat() -> void:
	_show_all_pool = not _show_all_pool
	if _cheat_btn:
		var key := "quest.cheat.show_active" if _show_all_pool else "quest.cheat.show_all"
		_cheat_btn.text = Translations.tr_key(key)
	_rebuild_list()


func _on_cheat_reset_pressed() -> void:
	DailyQuestManager.cheat_reset_progress()
	_rebuild_list()


func _make_cheat_button(text: String, on_press: Callable, theme_font: Font) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.22, 0.30, 0.85)
	s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	btn.add_theme_font_size_override("font_size", 12)
	if theme_font != null:
		btn.add_theme_font_override("font", theme_font)
	btn.pressed.connect(on_press)
	return btn
