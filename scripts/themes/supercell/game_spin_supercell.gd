extends "res://scripts/spin_poker_game.gd"
## Supercell reskin of Spin Poker. Same rules as multi: extend the
## classic script for full functional parity (reel spin, shutters, line
## evaluation, payline highlights), only recolor the chrome. Spin
## Poker gets a warmer purple accent tint so it's visually distinct
## from single / multi.

const SPIN_TINT := Color(0.9, 0.5, 1.0, 0.18)
# Keep these in sync with game_supercell.gd / game_multi_supercell.gd —
# all three supercell modes use identical icon size + edge padding.
const SUPERCELL_TOP_ICON_SIZE := 58
const SUPERCELL_TOP_EDGE_PAD := 32


func _ready() -> void:
	# Bump the bottom-row glyph height before classic's `_build_ui`
	# (called from super._ready) creates each currency display via
	# `create_currency_display(_info_glyph_h, …)`. Setting this AFTER
	# super._ready would resize the digits but leave the chip glyph at
	# 16px until the next FSM update — exactly the bug shown in the
	# WIN: ©2K screenshot where text grew but chip stayed small.
	_info_glyph_h = 32
	super._ready()
	call_deferred("_apply_supercell_overrides")


func _apply_supercell_overrides() -> void:
	_install_supercell_background()
	_swap_control_textures()
	_refresh_currency_displays()
	_apply_supercell_title()
	_apply_supercell_back_btn()
	_apply_supercell_font_recursive(self)
	_lock_supercell_bet_to_one()
	_relocate_info_to_top_bar()
	_apply_supercell_info_row_sizes()


## Move the SEE PAYS button from the bottom bar to the top header (next
## to back), turn it into the supercell info-style 58×58 sticker so the
## spin top bar mirrors single-hand supercell.
func _relocate_info_to_top_bar() -> void:
	if _see_pays_btn == null or not is_instance_valid(_see_pays_btn):
		return
	if _back_btn == null or not is_instance_valid(_back_btn):
		return
	var top_bar: Node = _back_btn.get_parent()
	if top_bar == null:
		return
	var current_parent: Node = _see_pays_btn.get_parent()
	if current_parent != null:
		current_parent.remove_child(_see_pays_btn)
	# Push the info button to the far right of the top bar by inserting
	# an expanding spacer between existing siblings and the info button —
	# without it the HBox packs everything to the left.
	var prev_spacer: Node = top_bar.get_node_or_null("SupercellInfoSpacer")
	if prev_spacer != null:
		prev_spacer.queue_free()
	var info_spacer := Control.new()
	info_spacer.name = "SupercellInfoSpacer"
	info_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(info_spacer)
	top_bar.add_child(_see_pays_btn)
	# Same 32px right-edge padding as single-hand's top bar so the "i"
	# button isn't pinned to the screen edge.
	var prev_edge: Node = top_bar.get_node_or_null("SupercellRightEdgePad")
	if prev_edge != null:
		prev_edge.queue_free()
	var edge_pad := Control.new()
	edge_pad.name = "SupercellRightEdgePad"
	edge_pad.custom_minimum_size = Vector2(SUPERCELL_TOP_EDGE_PAD, 0)
	edge_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(edge_pad)
	_see_pays_btn.icon = null
	_see_pays_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	_see_pays_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_see_pays_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var clean := StyleBoxFlat.new()
	clean.bg_color = Color(0, 0, 0, 0)
	_see_pays_btn.add_theme_stylebox_override("normal", clean)
	_see_pays_btn.add_theme_stylebox_override("hover", clean)
	_see_pays_btn.add_theme_stylebox_override("pressed", clean)
	_see_pays_btn.add_theme_stylebox_override("focus", clean)
	# Apply supercell info_btn.png as the sticker background (same skin
	# as multi/ultra and single).
	var path: String = ThemeManager.theme_folder() + "controls/info_btn.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		_see_pays_btn.add_theme_stylebox_override("normal", st)
		_see_pays_btn.add_theme_stylebox_override("hover", st)
		_see_pays_btn.add_theme_stylebox_override("pressed", st)
		_see_pays_btn.add_theme_stylebox_override("focus", st)
	# info_btn.png has no glyph baked in — render the "i" via the button's
	# own text so it shows on every state.
	_see_pays_btn.text = "i"
	_see_pays_btn.add_theme_font_size_override("font_size", 38)
	_see_pays_btn.add_theme_color_override("font_color", Color.WHITE)
	_see_pays_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_see_pays_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_see_pays_btn.add_theme_color_override("font_focus_color", Color.WHITE)
	_see_pays_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_see_pays_btn.add_theme_constant_override("outline_size", 4)
	var fnt: Font = ThemeManager.font()
	if fnt != null:
		_see_pays_btn.add_theme_font_override("font", fnt)


## Force spin's bet level to 1 and hide the BET / MAX BET buttons —
## supercell skin treats the denomination as the only wager dial,
## matching single/multi-hand supercell.
func _lock_supercell_bet_to_one() -> void:
	if _manager != null and is_instance_valid(_manager):
		_manager.bet = 1
		SaveManager.set_bet_level("spin_poker", 1)
		_manager.bet_changed.emit(1)
	if _bet_btn != null and is_instance_valid(_bet_btn):
		_bet_btn.visible = false
		_bet_btn.disabled = true
	if _bet_max_btn != null and is_instance_valid(_bet_max_btn):
		_bet_max_btn.visible = false
		_bet_max_btn.disabled = true


## Recursively pushes ThemeManager.font() onto every Label / RichTextLabel
## / Button classic built — without this the classic-built UI keeps the
## engine's default font even with the supercell theme active.
func _apply_supercell_font_recursive(root: Node) -> void:
	var f: Font = ThemeManager.font()
	if f == null:
		return
	_apply_font_to_node(root, f)


func _apply_font_to_node(node: Node, f: Font) -> void:
	if node is Label or node is Button:
		(node as Control).add_theme_font_override("font", f)
	elif node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_override("normal_font", f)
		(node as RichTextLabel).add_theme_font_override("bold_font", f)
		(node as RichTextLabel).add_theme_font_override("italics_font", f)
		(node as RichTextLabel).add_theme_font_override("bold_italics_font", f)
	for child in node.get_children():
		_apply_font_to_node(child, f)


## Same fix as in multi_supercell — strip the white classic exit icon and
## the 160px LEFT_MARGIN content padding so the supercell red back square
## (back_btn.png) renders as a uniform 44×44 sticker matching single-hand.
func _apply_supercell_back_btn() -> void:
	if _back_btn == null or not is_instance_valid(_back_btn):
		return
	_back_btn.icon = null
	_back_btn.expand_icon = false
	_back_btn.text = ""
	_back_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var clean := StyleBoxFlat.new()
	clean.bg_color = Color(0, 0, 0, 0)
	_back_btn.add_theme_stylebox_override("normal", clean)
	_back_btn.add_theme_stylebox_override("hover", clean)
	_back_btn.add_theme_stylebox_override("pressed", clean)
	_back_btn.add_theme_stylebox_override("focus", clean)
	# Spin's _back_btn is built in code by TopBarBuilder, so its node name
	# is "Button" rather than "BackButton" — _swap_control_textures (which
	# matches by name) doesn't find it, apply the texture by hand.
	var path: String = ThemeManager.theme_folder() + "controls/back_btn.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		_back_btn.add_theme_stylebox_override("normal", st)
		_back_btn.add_theme_stylebox_override("hover", st)
		_back_btn.add_theme_stylebox_override("pressed", st)
		_back_btn.add_theme_stylebox_override("focus", st)
	# Leading spacer in the parent HBox so the button sits the same
	# distance from the screen edge as in single/multi.
	var parent: Node = _back_btn.get_parent()
	if parent is BoxContainer and parent.get_child(0) == _back_btn:
		var pad := Control.new()
		pad.name = "SupercellEdgePad"
		pad.custom_minimum_size = Vector2(SUPERCELL_TOP_EDGE_PAD, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(pad)
		parent.move_child(pad, _back_btn.get_index())


## Replace the "SPIN POKER — <paytable name>" title built by the classic
## script with the lobby-style supercell title so the spin screen feels
## like the same machine the player tapped on the carousel.
func _apply_supercell_title() -> void:
	if _game_title == null:
		return
	var id: String = SaveManager.last_variant
	var supercell_title: String = ThemeManager.machine_title(id)
	if supercell_title != "":
		_game_title.text = "SPIN POKER — %s" % supercell_title.replace("\n", " ").to_upper()
	# Re-parent + re-anchor so the title is geometrically centered on the
	# viewport rather than wherever classic's title_bar HBox placed it.
	var parent: Node = _game_title.get_parent()
	if parent != null and parent != self:
		parent.remove_child(_game_title)
		add_child(_game_title)
	# set_anchors_and_offsets_preset resets BOTH anchors and offsets to the
	# preset's defaults — set_anchors_preset alone keeps the previous
	# (narrow) offsets and pins the title to the top-left.
	# Vertical band aligns with the back-button row (y=8..72) so the
	# title sits inside the top bar instead of below it, matching multi.
	_game_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_game_title.offset_left = 0
	_game_title.offset_right = 0
	_game_title.offset_top = 8
	_game_title.offset_bottom = 72
	_game_title.size_flags_horizontal = Control.SIZE_FILL
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 32)
	_game_title.add_theme_color_override("font_color", Color.WHITE)
	_game_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_game_title.add_theme_constant_override("outline_size", 5)
	_game_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Font = ThemeManager.font()
	if f != null:
		_game_title.add_theme_font_override("font", f)


## In-place chip swap on classic-built currency displays. SaveManager
## already holds the supercell coin texture (pushed by ThemeManager
## when the active theme switched). The displays themselves were built
## by classic's _ready before that swap, so their TextureRects still
## point at the old chip — re-point them now without rebuilding text.
func _refresh_currency_displays() -> void:
	# Refresh every chip TextureRect in spin's currency dictionaries so
	# the supercell coin replaces classic's glyph_chip in-place — covers
	# the big info-row displays plus the chip embedded in the BET AMOUNT
	# button.
	for cd in [_balance_cd, _win_cd, _bet_display_cd, _bet_btn_cd]:
		if cd is Dictionary:
			SaveManager.refresh_chip_in_box(cd)


func _install_supercell_background() -> void:
	# Spin Poker scene doesn't guarantee a Background child — if the
	# classic script creates it later, we spawn our own behind all
	# siblings so the paint is still drawn.
	var bg_node: Control = get_node_or_null("Background") as Control
	if bg_node == null:
		bg_node = ColorRect.new()
		bg_node.name = "SupercellBg"
		bg_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		(bg_node as ColorRect).color = Color(0, 0, 0, 0)
		bg_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_node)
		move_child(bg_node, 0)
	var vid: String = ""
	if _variant != null and _variant.paytable != null:
		vid = _variant.paytable.variant_id
	var grad: Array = ThemeManager.machine_gradient(vid)
	var top_c: Color = grad[0] if grad.size() == 2 else Color("2F2A7A")
	var bot_c: Color = grad[1] if grad.size() == 2 else Color("1B1648")
	if bg_node is ColorRect:
		(bg_node as ColorRect).color = Color(0, 0, 0, 0)
	bg_node.draw.connect(func() -> void:
		var ci := bg_node.get_canvas_item()
		var rect := Rect2(Vector2.ZERO, bg_node.size)
		_draw_vertical_gradient(ci, rect, top_c, bot_c)
		RenderingServer.canvas_item_add_rect(ci, rect, SPIN_TINT)
	)


## Override classic's blue "SELECT BET" popup with the supercell-styled
## chrome (purple panel + yellow border) — same look as the single-hand
## denomination picker.
func _show_bet_picker() -> void:
	if _bet_picker_overlay:
		_bet_picker_overlay.queue_free()
	_bet_picker_overlay = Control.new()
	_bet_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bet_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_bet_picker_overlay.z_index = 50
	add_child(_bet_picker_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = ThemeManager.popup_dim_color()
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
	)
	_bet_picker_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeManager.make_popup_stylebox())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	_bet_picker_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("game.select_coins_amount")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.style_popup_title(title, 28)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	for amount in BET_AMOUNTS:
		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size = Vector2(220, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeManager.color("button_primary_bg", Color("FFCC2E"))
		sb.border_color = ThemeManager.color("button_primary_border", Color("152033"))
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)
		var cd := SaveManager.create_currency_display(20, ThemeManager.color("button_primary_text", Color("2A1F00")))
		cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd["box"].set_anchors_preset(Control.PRESET_FULL_RECT)
		SaveManager.set_currency_value(cd, SaveManager.format_auto(amount, 140, 20))
		btn.add_child(cd["box"])
		btn.pressed.connect(func() -> void:
			_current_denomination = amount
			SaveManager.denomination = amount
			_update_bet_amount_btn()
			_update_bet_display(_manager.bet)
			if _balance_show_depth:
				_update_balance(SaveManager.credits)
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
		)
		grid.add_child(btn)


func _swap_control_textures() -> void:
	# Spin's controls are code-created (no scene names) — apply by field
	# ref. Back button is handled separately in `_apply_supercell_back_btn`.
	if _deal_draw_btn != null and is_instance_valid(_deal_draw_btn):
		_apply_btn_png(_deal_draw_btn, "btn_draw.png")
	if _bet_max_btn != null and is_instance_valid(_bet_max_btn):
		_apply_btn_png(_bet_max_btn, "btn_max_bet.png")
	if _bet_btn != null and is_instance_valid(_bet_btn):
		_apply_btn_png(_bet_btn, "btn_bet_lvl.png")
	if _bet_amount_btn != null and is_instance_valid(_bet_amount_btn):
		_apply_btn_png(_bet_amount_btn, "btn_denom.png")
	if _speed_btn != null and is_instance_valid(_speed_btn):
		_apply_btn_png(_speed_btn, "btn_speed.png")
	if _see_pays_btn != null and is_instance_valid(_see_pays_btn):
		_apply_btn_png(_see_pays_btn, "btn_bet_lvl.png")
	if _double_btn != null and is_instance_valid(_double_btn):
		_apply_btn_png(_double_btn, "btn_double.png")
		# 1.33× classic's 13px label so DOUBLE reads on the bigger
		# supercell plate.
		_double_btn.add_theme_font_size_override("font_size", 17)
	if _deal_draw_btn != null and is_instance_valid(_deal_draw_btn):
		# Same proportional bump for DEAL / SPIN — classic 14 → 19.
		_deal_draw_btn.add_theme_font_size_override("font_size", 19)
	# Bump from classic 36px-tall scale to supercell 80px scale.
	const BTN_H := 80
	if _speed_btn != null and is_instance_valid(_speed_btn):
		_speed_btn.custom_minimum_size = Vector2(110, BTN_H)
	if _see_pays_btn != null and is_instance_valid(_see_pays_btn):
		_see_pays_btn.custom_minimum_size = Vector2(130, BTN_H)
	if _bet_amount_btn != null and is_instance_valid(_bet_amount_btn):
		_bet_amount_btn.custom_minimum_size = Vector2(130, BTN_H)
	if _bet_btn != null and is_instance_valid(_bet_btn):
		_bet_btn.custom_minimum_size = Vector2(130, BTN_H)
	if _bet_max_btn != null and is_instance_valid(_bet_max_btn):
		_bet_max_btn.custom_minimum_size = Vector2(150, BTN_H)
	if _deal_draw_btn != null and is_instance_valid(_deal_draw_btn):
		_deal_draw_btn.custom_minimum_size = Vector2(180, BTN_H)
	if _double_btn != null and is_instance_valid(_double_btn):
		_double_btn.custom_minimum_size = Vector2(120, BTN_H)


func _apply_btn_png(btn: Button, filename: String) -> void:
	var path: String = ThemeManager.theme_folder() + "controls/" + filename
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var st := StyleBoxTexture.new()
	st.texture = tex
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("focus", st)
	# Dim the same texture for the disabled state so DOUBLE / DEAL while
	# locked reads "unavailable" instead of dropping to Godot's default
	# flat-grey disabled box.
	var disabled := st.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))


func _draw_vertical_gradient(ci: RID, rect: Rect2, top: Color, bot: Color, slices: int = 48) -> void:
	var step: float = rect.size.y / float(slices)
	for i in slices:
		var t: float = float(i) / float(slices - 1)
		var col := top.lerp(bot, t)
		RenderingServer.canvas_item_add_rect(ci,
			Rect2(rect.position.x, rect.position.y + step * float(i),
				rect.size.x, step + 1.0),
			col)


func _draw_diagonal_stripes(ci: RID, rect: Rect2, col: Color, spacing: float, width: float) -> void:
	var x: float = rect.position.x - rect.size.y
	while x <= rect.position.x + rect.size.x:
		RenderingServer.canvas_item_add_line(ci,
			Vector2(x, rect.position.y),
			Vector2(x + rect.size.y, rect.position.y + rect.size.y),
			col, width, false)
		x += spacing


## 2× scale-up for the bottom info row (WIN / TOTAL BET / BALANCE):
## bumps each label's font_size from classic's 14 to 28 and the chip
## glyphs from 16 to 32 so the readouts read at a glance — same scale
## as multi-hand supercell.
func _apply_supercell_info_row_sizes() -> void:
	const LABEL_FS := 28
	const GLYPH_H := 32
	if _win_label != null and is_instance_valid(_win_label):
		_win_label.add_theme_font_size_override("font_size", LABEL_FS)
	if _bet_display_label != null and is_instance_valid(_bet_display_label):
		_bet_display_label.add_theme_font_size_override("font_size", LABEL_FS)
	if _balance_label != null and is_instance_valid(_balance_label):
		_balance_label.add_theme_font_size_override("font_size", LABEL_FS)
	# Currency display glyphs are stored in cd["glyph_h"] and read on
	# every set_currency_value rebuild. Empty-text branch resizes the
	# existing glyphs in-place without rebuilding (preserves whatever
	# value the FSM put there last).
	for cd in [_win_cd, _bet_display_cd, _balance_cd]:
		if cd is Dictionary:
			cd["glyph_h"] = GLYPH_H
			SaveManager.set_currency_value(cd, "", GLYPH_H)
	# Re-emit live values so any short-format rule (e.g. 12,500 → "12.5K")
	# gets applied at the new glyph height.
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)
