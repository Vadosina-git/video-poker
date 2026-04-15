class_name TopBarBuilder
extends RefCounted

## Shared top bar setup: exit icon + title + optional info button.
## Call from any game mode to get consistent styling.

const EXIT_ICON_PATH := "res://assets/textures/table_exit.svg"
const LEFT_MARGIN := 100  # align with controlbar side_m


## Style an existing back button (from .tscn) as exit icon.
static func style_exit_button(btn: Button) -> void:
	btn.text = ""
	if ResourceLoader.exists(EXIT_ICON_PATH):
		btn.icon = load(EXIT_ICON_PATH)
		btn.expand_icon = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.content_margin_left = LEFT_MARGIN
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.custom_minimum_size = Vector2(LEFT_MARGIN + 38, 38)


## Create a new exit button (for modes that build UI in code).
static func create_exit_button() -> Button:
	var btn := Button.new()
	style_exit_button(btn)
	return btn


## Show exit confirmation dialog. Returns the overlay Control (caller
## connects back_to_lobby on confirm).
static func show_exit_confirm(parent: Control, on_leave: Callable) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50
	parent.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("000086")
	ps.set_border_width_all(3)
	ps.border_color = Color.WHITE
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 32
	ps.content_margin_right = 32
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = Translations.tr_key("game.exit_confirm")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)

	var tex_y := load("res://assets/textures/btn_rect_yellow.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_yellow.svg") else null
	var tex_g := load("res://assets/textures/btn_rect_green.svg") if ResourceLoader.exists("res://assets/textures/btn_rect_green.svg") else null

	var stay_btn := Button.new()
	stay_btn.text = Translations.tr_key("game.exit_stay")
	stay_btn.custom_minimum_size = Vector2(120, 44)
	stay_btn.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(stay_btn)

	var leave_btn := Button.new()
	leave_btn.text = Translations.tr_key("game.exit_leave")
	leave_btn.custom_minimum_size = Vector2(120, 44)
	leave_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		on_leave.call()
	)
	btns.add_child(leave_btn)

	return overlay
