class_name AgeGate
extends RefCounted
## First-launch age confirmation modal (18+ required).
## Required by Google Play Age-Restricted Content policy (Jan 2026) and Apple
## App Review Guideline 5.3 for social casino apps.
##
## Call: AgeGate.show_if_needed(host_control) from lobby._ready().
## If user confirms, SaveManager.age_gate_confirmed = true; no further prompts.
## If user taps "No", the app quits immediately.

static func show_if_needed(host: Control) -> void:
	if SaveManager.age_gate_confirmed:
		return
	# Disable via configs/features.json -> feature_flags.age_gate_enabled.
	var cm: Node = Engine.get_main_loop().root.get_node_or_null("/root/ConfigManager")
	if cm and not cm.is_feature_enabled("age_gate_enabled", true):
		return
	_build(host)


static func _build(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 2000
	host.add_child(overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0A0F40")
	style.set_border_width_all(3)
	style.border_color = Color("FFEC00")
	style.set_corner_radius_all(16)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# PRESET_CENTER pins anchors to (0.5, 0.5) but the panel grows down-right
	# from that point by default. GROW_DIRECTION_BOTH makes it expand equally
	# in all directions from the anchor, genuinely centering the modal.
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(620, 0)
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = Translations.tr_key("age_gate.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	vb.add_child(title)

	var body := Label.new()
	body.text = Translations.tr_key("age_gate.body")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(body)

	var disclaimer := Label.new()
	disclaimer.text = Translations.tr_key("age_gate.disclaimer")
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disclaimer.add_theme_font_size_override("font_size", 15)
	disclaimer.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	vb.add_child(disclaimer)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vb.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vb.add_child(buttons)

	var no_btn := _make_btn(Translations.tr_key("age_gate.no"), Color("8A1A1A"))
	buttons.add_child(no_btn)
	no_btn.pressed.connect(func() -> void:
		host.get_tree().quit()
	)

	var yes_btn := _make_btn(Translations.tr_key("age_gate.yes"), Color("1A7A2A"))
	buttons.add_child(yes_btn)
	yes_btn.pressed.connect(func() -> void:
		SaveManager.age_gate_confirmed = true
		SaveManager.save_game()
		overlay.queue_free()
	)


static func _make_btn(label: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(160, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_color
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.3)
	st.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("focus", st)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn
