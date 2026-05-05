extends Control
## Single-hand game screen for the supercell skin. Fully independent of
## scripts/game.gd (classic) — builds its own layout matching the
## Figma reference: green felt, paytable panel on the left, 5 cards +
## HELD badges, large DRAW/MAX BET buttons bottom-right.
##
## Uses the shared GameManager FSM so core gameplay logic (deal/hold/
## draw/evaluate) is reused, only the UI chrome differs.

signal back_to_lobby

const FELT_BG_COL_TOP    := Color("2F7A3A")
const FELT_BG_COL_BOT    := Color("1F5C26")
const FRAME_COL          := Color("0A2915")
const PAYTABLE_BG_COL    := Color("5A3A22")
const PAYTABLE_HDR_COL   := Color("F2C64A")
const PAYTABLE_ROW_COL   := Color("F2C64A")
const COIN_PILL_BG       := Color("3A2312")
const COIN_PILL_BORDER   := Color("F2C64A")
const TITLE_COLOR        := Color.WHITE
const TITLE_OUTLINE      := Color("0A2915")
# Shared sizing for the supercell top-bar icons (back / info) so all three
# game modes (single, multi, spin) render them at identical dimensions
# with identical edge padding. Bumping these here updates every screen.
const SUPERCELL_TOP_ICON_SIZE := 58  # 44 × 1.3, rounded — "30% larger"
const SUPERCELL_TOP_EDGE_PAD := 32   # left/right margin from screen edge
const DRAW_BG            := Color("F2D62E")
const MAX_BET_BG         := Color("E9483C")
const BET_LVL_BG         := Color("4A2B15")

var _variant: BaseVariant
var _game_manager: GameManager
var _cards: Array = []                # Array[CardVisual]
var _winner_glows: Array = []         # Array[Control] — one gold-outline overlay per card slot

# Classic-parity animation pacing — copied verbatim from scripts/game.gd
# so supercell card deal/draw feels identical.
const SPEED_CONFIGS := [
	{"deal_ms": 150, "draw_ms": 200, "flip_s": 0.15},
	{"deal_ms": 100, "draw_ms": 140, "flip_s": 0.12},
	{"deal_ms": 60,  "draw_ms": 80,  "flip_s": 0.08},
	{"deal_ms": 30,  "draw_ms": 40,  "flip_s": 0.05},
]
var _speed_level: int = 1
var _animating: bool = false

# NB: no @onready — setup() runs BEFORE _ready, and @onready
# re-executes the initializer after setup, wiping our assignments
# back to null. Plain `var` keeps the refs we set in _build_ui().
var _paytable_list: VBoxContainer = null
var _title_label: Label = null
var _balance_label: Label = null
var _win_label: Label = null
var _last_label: Label = null
var _status_label: Label = null
var _last_win_amount: int = 0
var _win_increment_tween: Tween = null
var _draw_btn: Button = null
var _max_bet_btn: Button = null
var _bet_lvl_btn: Button = null
var _speed_btn: Button = null
var _tutor_btn: Button = null
var _double_btn: Button = null
var _win_name_label: Label = null
var _lose_name_label: RichTextLabel = null
var _win_pill_blink_tw: Tween = null
var _lose_pill_blink_tw: Tween = null
var _paytable_rows: Dictionary = {}   # hand_key → HBoxContainer row
var _idle_blink_tween: Tween = null
var _highlighted_paytable_key: String = ""  # sticky: stays lit until next DEAL
var _hint_bubble: Control = null      # active hint overlay (null when nothing shown)
var _hint_dismiss_id: int = 0         # gen counter so stale 7s timers can't kill a fresh bubble
var _gift_label: Label = null
var _gift_timer: Timer = null
var _gift_icon_tex: TextureRect = null
var _gift_ready_path: String = ""
var _gift_waiting_path: String = ""
var _denom_lab: Label = null    # label inside the COINS picker button — tracks denomination
var _denom_btn: Button = null   # the COINS picker button itself (for width measurement)
var _coins_prefix_lab: Label = null  # "COINS:" label preceding the chip+value cluster

# Section roots — captured by builders, animated on entrance.
var _top_bar_root: Control = null
var _paytable_panel_root: Control = null
var _cards_area_root: Control = null
var _bottom_bar_root: Control = null


func setup(variant: BaseVariant) -> void:
	_variant = variant
	_build_ui()
	_setup_manager()
	# Catch-all: ensures every Label / RichTextLabel / Button created by
	# the build path uses LilitaOne, even ones added through helpers that
	# might forget the font override.
	call_deferred("_apply_supercell_font_recursive", self)


## Recursively pushes ThemeManager.font() onto every text node in the
## subtree — runs after the whole UI is built so it cleans up any node
## a sub-builder forgot to font-override.
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play_entrance_animation()


func _play_entrance_animation() -> void:
	# Mirror classic single-hand entrance: top sections slide in from above,
	# bottom controls slide up from below. Same params as scripts/game.gd.
	var top_nodes: Array[Control] = []
	if is_instance_valid(_top_bar_root):
		top_nodes.append(_top_bar_root)
	if is_instance_valid(_paytable_panel_root):
		top_nodes.append(_paytable_panel_root)
	if is_instance_valid(_cards_area_root):
		top_nodes.append(_cards_area_root)
	var bottom_nodes: Array[Control] = []
	if is_instance_valid(_bottom_bar_root):
		bottom_nodes.append(_bottom_bar_root)
	for n in top_nodes + bottom_nodes:
		n.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var vp_h: float = get_viewport_rect().size.y
	var slide: float = vp_h * 0.6
	var dur: float = 0.6
	var overshoot_px: float = 9.0
	for n in top_nodes:
		if not is_instance_valid(n):
			continue
		var base_y: float = n.position.y
		n.position.y = base_y - slide
		n.modulate.a = 1.0
		_tween_section_bounce(n, base_y, overshoot_px, dur)
	for n in bottom_nodes:
		if not is_instance_valid(n):
			continue
		var base_y: float = n.position.y
		n.position.y = base_y + slide
		n.modulate.a = 1.0
		_tween_section_bounce(n, base_y, -overshoot_px, dur)


func _tween_section_bounce(section: Control, target_y: float, overshoot: float, dur: float) -> void:
	var tw := section.create_tween()
	tw.tween_property(section, "position:y", target_y + overshoot, dur * 0.82) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(section, "position:y", target_y, dur * 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


# ──────────────────────────────────────────────────────────────────────
# UI construction
# ──────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Root bg — vertical gradient pulled from the machine tile's colors,
	# clean (no overlay pattern) so the focus stays on the cards.
	_build_felt_bg()
	_build_top_bar()
	_build_paytable_panel()
	_build_cards_area()
	_build_bottom_bar()


func _build_felt_bg() -> void:
	# Background inherits the machine tile's gradient from the lobby
	# (same top→bottom colors). Falls back to felt green only if the
	# theme doesn't declare a gradient for this variant.
	var vid: String = _variant.paytable.variant_id if _variant and _variant.paytable else SaveManager.last_variant
	var grad: Array = ThemeManager.machine_gradient(vid)
	var top_c: Color = grad[0] if grad.size() == 2 else FELT_BG_COL_TOP
	var bot_c: Color = grad[1] if grad.size() == 2 else FELT_BG_COL_BOT

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.draw.connect(func() -> void:
		var ci := bg.get_canvas_item()
		var rect := Rect2(Vector2.ZERO, bg.size)
		_draw_vertical_gradient(ci, rect, top_c, bot_c)
	)


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


func _draw_rounded_rect_outline(ctrl: Control, rect: Rect2, radius: float, col: Color, width: float) -> void:
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.position.x + rect.size.x
	var b := rect.position.y + rect.size.y
	ctrl.draw_line(Vector2(l + radius, t), Vector2(r - radius, t), col, width)
	ctrl.draw_line(Vector2(l + radius, b), Vector2(r - radius, b), col, width)
	ctrl.draw_line(Vector2(l, t + radius), Vector2(l, b - radius), col, width)
	ctrl.draw_line(Vector2(r, t + radius), Vector2(r, b - radius), col, width)
	ctrl.draw_arc(Vector2(l + radius, t + radius), radius, PI, PI * 1.5, 12, col, width)
	ctrl.draw_arc(Vector2(r - radius, t + radius), radius, PI * 1.5, TAU, 12, col, width)
	ctrl.draw_arc(Vector2(r - radius, b - radius), radius, 0, PI * 0.5, 12, col, width)
	ctrl.draw_arc(Vector2(l + radius, b - radius), radius, PI * 0.5, PI, 12, col, width)


func _build_top_bar() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = SUPERCELL_TOP_EDGE_PAD
	top.offset_right = -SUPERCELL_TOP_EDGE_PAD
	top.offset_top = 28
	top.custom_minimum_size = Vector2(0, 88)
	top.add_theme_constant_override("separation", 16)
	add_child(top)
	_top_bar_root = top

	# Back button — red square with white left arrow.
	var back_btn := _make_sticker_btn(Color("E54C3A"), Color("7A1F13"))
	back_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	# Default Control size_flags include SIZE_FILL on both axes — in the
	# tall HBox that would stretch the square to a narrow tall pill.
	# Shrink-center keeps it a uniform square at the configured size.
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.tooltip_text = "Back"
	back_btn.pressed.connect(func() -> void: emit_signal("back_to_lobby"))
	back_btn.draw.connect(func() -> void: _draw_arrow_left(back_btn))
	top.add_child(back_btn)

	# Balance pill — brown rounded with $ icon + number.
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = COIN_PILL_BG
	pill_style.border_color = COIN_PILL_BORDER
	pill_style.set_border_width_all(3)
	pill_style.set_corner_radius_all(36)
	pill_style.content_margin_left = 22
	pill_style.content_margin_right = 22
	pill_style.content_margin_top = 8
	pill_style.content_margin_bottom = 8
	pill_style.anti_aliasing = true
	pill.add_theme_stylebox_override("panel", pill_style)
	top.add_child(pill)
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 10)
	pill.add_child(pill_row)
	var coin := _make_coin_glyph(36)
	pill_row.add_child(coin)
	_balance_label = Label.new()
	_balance_label.text = SaveManager.format_money(SaveManager.credits)
	_balance_label.add_theme_font_size_override("font_size", 28)
	_balance_label.add_theme_color_override("font_color", PAYTABLE_ROW_COL)
	_balance_label.add_theme_font_override("font", ThemeManager.font())
	pill_row.add_child(_balance_label)

	# "+" top-up button — uses the dedicated btn_plus PNG. Plain Button
	# (not a sticker) so there's no flat fill leaking around the PNG's
	# transparent edges; the artwork itself carries the yellow plate +
	# baked-in "+" glyph.
	var topup := Button.new()
	topup.custom_minimum_size = Vector2(72, 72)
	topup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topup.tooltip_text = "Store"
	# Empty styleboxes for every state so Godot's default theme can't
	# paint a fill behind the PNG.
	var empty_st := StyleBoxEmpty.new()
	topup.add_theme_stylebox_override("normal", empty_st)
	topup.add_theme_stylebox_override("hover", empty_st)
	topup.add_theme_stylebox_override("pressed", empty_st)
	topup.add_theme_stylebox_override("focus", empty_st)
	topup.add_theme_stylebox_override("disabled", empty_st)
	topup.icon = load("res://assets/themes/supercell/controls/btn_plus.png")
	topup.expand_icon = true
	topup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	topup.pressed.connect(func() -> void:
		if ShopOverlay:
			ShopOverlay.show(self)
	)
	_add_press_effect(topup)
	top.add_child(topup)

	# Spacer pushing title to center.
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	# Gift widget — same PNG assets + label logic as the lobby footer
	# gift button (themes/supercell/icons/gift_ready.png /
	# gift_waiting.png via ThemeManager.ui_icon_path). Tap opens the
	# shop; the actual claim must come from inside the shop, never from
	# the lobby/game widget.
	var gift_btn := Button.new()
	gift_btn.custom_minimum_size = Vector2(132, 62)
	gift_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gift_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	gift_btn.add_theme_stylebox_override("normal", empty)
	gift_btn.add_theme_stylebox_override("hover", empty)
	gift_btn.add_theme_stylebox_override("pressed", empty)
	gift_btn.add_theme_stylebox_override("focus", empty)
	# Background pill — matches the supercell purple/yellow chrome.
	var bg_panel := Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gift_style := StyleBoxFlat.new()
	gift_style.bg_color = Color("A341D9")
	gift_style.border_color = Color("FFCC2E")
	gift_style.set_border_width_all(3)
	gift_style.set_corner_radius_all(18)
	gift_style.anti_aliasing = true
	bg_panel.add_theme_stylebox_override("panel", gift_style)
	gift_btn.add_child(bg_panel)
	# Icon (left half) — TextureRect that swaps between ready/waiting.
	_gift_icon_tex = TextureRect.new()
	_gift_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gift_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gift_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gift_icon_tex.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_gift_icon_tex.offset_left = 6
	_gift_icon_tex.offset_right = 50
	_gift_icon_tex.offset_top = 6
	_gift_icon_tex.offset_bottom = -6
	gift_btn.add_child(_gift_icon_tex)
	_gift_ready_path = ThemeManager.ui_icon_path("gift_ready")
	_gift_waiting_path = ThemeManager.ui_icon_path("gift_waiting")
	_refresh_gift_icon_texture()
	# Label (right half) — countdown or READY.
	_gift_label = Label.new()
	_gift_label.text = "--:--"
	_gift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gift_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gift_label.add_theme_font_size_override("font_size", 20)
	_gift_label.add_theme_color_override("font_color", Color.WHITE)
	_gift_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_gift_label.add_theme_constant_override("outline_size", 3)
	_gift_label.add_theme_font_override("font", ThemeManager.font())
	_gift_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gift_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_gift_label.offset_left = -78
	_gift_label.offset_right = -8
	gift_btn.add_child(_gift_label)
	gift_btn.pressed.connect(func() -> void:
		if ShopOverlay:
			ShopOverlay.show(self)
	)
	_add_press_effect(gift_btn)
	top.add_child(gift_btn)
	_start_gift_ticker()

	# Title is anchored to the screen-wide top band (separate from the
	# top HBox flow) so it stays geometrically centered on the viewport
	# regardless of how wide the left/right control clusters are.
	_title_label = Label.new()
	_title_label.text = _variant_title()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 44)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_font_override("font", ThemeManager.font())
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use set_anchors_and_offsets_preset (not just set_anchors_preset) so
	# offset_left/right are explicitly reset to 0 — a freshly-built Label
	# with rect (0, 0, 0, 0) would otherwise leak that into the offsets
	# and pin the title to the top-left corner.
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_left = 0
	_title_label.offset_right = 0
	_title_label.offset_top = 28
	_title_label.offset_bottom = 116
	_title_label.size_flags_horizontal = Control.SIZE_FILL
	add_child(_title_label)
	# Push title behind the top HBox so back/info icons remain clickable
	# even when the title's full-width hit area would have eaten the tap.
	# (mouse_filter=IGNORE already passes input through, this is belt+braces.)
	move_child(_title_label, top.get_index())

	# Info button — blue square with white "i". Placed immediately after
	# the gift widget (no expand-spacer between them) so the right
	# cluster reads as a single "gift + info" group pushed to the screen
	# edge by the single `sp` spacer above. Without this collapse the
	# gift used to sit half-way across the bar and overlap the centered
	# machine title.
	var info_btn := _make_sticker_btn(Color("3C9DE8"), Color("16507C"))
	info_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_btn.draw.connect(func() -> void: _draw_info_glyph(info_btn))
	info_btn.pressed.connect(_on_info_pressed)
	top.add_child(info_btn)


func _variant_title() -> String:
	var id: String = SaveManager.last_variant
	# Mirror the lobby tile's stylised title (e.g. "CLASSIC DRAW",
	# "QUAD HUNT") so the table feels like the same machine the player
	# tapped in the lobby. Fall back to the localised classic name when
	# the active theme doesn't ship a per-variant title override.
	var supercell_title: String = ThemeManager.machine_title(id)
	if supercell_title != "":
		return supercell_title.replace("\n", " ").to_upper()
	return Translations.tr_key("machine.%s.name" % id).to_upper()


func _build_paytable_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 40
	panel.offset_top = 150
	panel.offset_right = 40 + 380
	panel.offset_bottom = -190
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Prefer the PNG sticker (assets/themes/supercell/controls/paytable_panel.png)
	# when it's shipped with the theme — gives the supercell book-leather
	# look. Fall back to a flat brown stylebox if the PNG is missing so
	# the lobby/game still renders something usable.
	var panel_png_path: String = ThemeManager.theme_folder() + "controls/paytable_panel.png"
	if ResourceLoader.exists(panel_png_path):
		var tex: Texture2D = load(panel_png_path)
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sbt.content_margin_left = 22
		sbt.content_margin_right = 22
		sbt.content_margin_top = 18
		sbt.content_margin_bottom = 18
		panel.add_theme_stylebox_override("panel", sbt)
	else:
		var st := StyleBoxFlat.new()
		st.bg_color = PAYTABLE_BG_COL
		st.set_corner_radius_all(20)
		st.set_border_width_all(4)
		st.border_color = Color("2F1A0B")
		st.content_margin_left = 18
		st.content_margin_right = 18
		st.content_margin_top = 14
		st.content_margin_bottom = 14
		st.anti_aliasing = true
		panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	_paytable_panel_root = panel

	# Make the whole paytable a single tappable button — anywhere in
	# the panel triggers the same press-pop + intro hint bubble.
	# mouse_filter STOP eats the input on the panel itself; rows inside
	# stay IGNORE so they don't intercept first.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_paytable_panel_input.bind(panel))
	_add_press_effect_generic(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	# Forward clicks from the inner column up to the panel — without
	# this, clicking on the header label area gets stopped by the
	# VBoxContainer (which inherits STOP from theme defaults on some
	# platforms) and the press-pop on the panel never fires.
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	var hdr := Label.new()
	hdr.text = "PAYTABLE"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 28)
	hdr.add_theme_color_override("font_color", PAYTABLE_HDR_COL)
	hdr.add_theme_font_override("font", ThemeManager.font())
	vb.add_child(hdr)

	_paytable_list = VBoxContainer.new()
	_paytable_list.add_theme_constant_override("separation", 2)
	vb.add_child(_paytable_list)

	_rebuild_paytable_rows()


## Builds the paytable rows from the variant's paytable. Bet-scaled
## payout column uses current bet level. Row HBoxes are indexed by
## hand_key in `_paytable_rows` so _on_hand_evaluated can pulse the
## matching row on a win.
func _rebuild_paytable_rows() -> void:
	if _paytable_list == null or _variant == null or _variant.paytable == null:
		return
	for c in _paytable_list.get_children():
		c.queue_free()
	_paytable_rows.clear()
	var bet: int = _game_manager.bet if _game_manager else 5
	for key in _variant.paytable.get_hand_order():
		# PanelContainer wrapper so we can paint a bright background fill
		# when the row pulses on a win — a plain HBox can't host a stylebox.
		var row_panel := PanelContainer.new()
		# Span the full paytable width so the on-win yellow highlight reads
		# as a "bar" across the row, not a tight pill hugging the text.
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = Color(0, 0, 0, 0)  # transparent at rest
		base_style.set_corner_radius_all(6)
		base_style.content_margin_left = 6
		base_style.content_margin_right = 6
		base_style.content_margin_top = 1
		base_style.content_margin_bottom = 1
		row_panel.add_theme_stylebox_override("panel", base_style)
		_paytable_list.add_child(row_panel)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row_panel.add_child(hb)
		var lab := Label.new()
		lab.text = _variant.paytable.get_hand_display_name(key).to_upper()
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color", PAYTABLE_ROW_COL)
		lab.add_theme_font_override("font", ThemeManager.font())
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lab)
		# Show actual chip payout (multiplier × denom) prefixed with a
		# coin glyph so the value reads as currency, not a multiplier.
		# Right-aligned via a sub-HBox so the coin sticks to the number.
		var pay_wrap := HBoxContainer.new()
		pay_wrap.alignment = BoxContainer.ALIGNMENT_END
		pay_wrap.add_theme_constant_override("separation", 4)
		pay_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(pay_wrap)
		var pay_coin := _make_coin_glyph(18)
		pay_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pay_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pay_wrap.add_child(pay_coin)
		var pay := Label.new()
		var multiplier: int = int(_variant.paytable.get_payout_by_key(key, 1))
		pay.text = str(multiplier * SaveManager.denomination)
		pay.add_theme_font_size_override("font_size", 16)
		pay.add_theme_color_override("font_color", PAYTABLE_ROW_COL)
		pay.add_theme_font_override("font", ThemeManager.font())
		pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pay_wrap.add_child(pay)
		# Stash the stylebox + label refs on the panel so pulse doesn't
		# have to re-traverse children each frame. Also store the per-coin
		# multiplier so denom changes can update the number without
		# touching the paytable JSON again.
		row_panel.set_meta("bg_style", base_style)
		row_panel.set_meta("name_label", lab)
		row_panel.set_meta("pay_label", pay)
		row_panel.set_meta("pay_coin", pay_coin)
		row_panel.set_meta("multiplier", multiplier)
		# Rows themselves don't react to taps — the whole paytable panel
		# is one big button (see _build_paytable_panel). Letting clicks
		# pass through here keeps the press-pop on the parent panel
		# consistent regardless of where the finger lands.
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paytable_rows[key] = row_panel


## Light up a paytable row on a win — bright yellow fill on the brown
## paytable plate, text inverts to dark for contrast, small scale pop.
## Light stays on (sticky) until _reset_paytable_highlight() is called
## on the next DEAL — player has time to see which combo paid out.
##
## When `_highlighted_paytable_key` already matches `key` (i.e. the DEAL
## had this combo and DRAW kept it), skip the bg/text fade-in — the row
## is already lit; only the scale-pop runs. When the key differs (DRAW
## improved the hand to a different row), the previous row fades out via
## `_reset_paytable_highlight()` while the new row fades in, producing a
## visual transition rather than a hard re-light.
func _pulse_paytable_row(key: String) -> void:
	var same_row: bool = _highlighted_paytable_key == key
	if not same_row:
		_reset_paytable_highlight()
	var row: PanelContainer = _paytable_rows.get(key, null)
	if not (row is PanelContainer):
		return
	var bg_style: StyleBoxFlat = row.get_meta("bg_style", null)
	var name_lab: Label = row.get_meta("name_label", null)
	var pay_lab: Label = row.get_meta("pay_label", null)
	if bg_style == null:
		return

	var lit_fill := Color("FFCC2E")
	var lit_text := Color("2B1C48")

	var tw := row.create_tween().set_parallel(true)
	if not same_row:
		tw.tween_property(bg_style, "bg_color", lit_fill, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Hand-name AND payout value go dark on a lit row — yellow text on
	# yellow fill is unreadable.
	if not same_row and name_lab != null:
		tw.tween_property(name_lab, "theme_override_colors/font_color", lit_text, 0.12)
	if not same_row and pay_lab != null:
		tw.tween_property(pay_lab, "theme_override_colors/font_color", lit_text, 0.12)
	_highlighted_paytable_key = key


## Soft highlight used at DEAL time when the just-dealt hand already
## forms a winning combo. Same lit-yellow look as `_pulse_paytable_row`
## but without the scale-pop, payout emphasis or chip cascade — those
## are reserved for the eval at DRAW. If DRAW lands on the same key,
## the pulse skips re-fading and just adds the scale pop on top.
func _set_paytable_row_lit(key: String) -> void:
	if _highlighted_paytable_key == key:
		return
	_reset_paytable_highlight()
	var row: PanelContainer = _paytable_rows.get(key, null)
	if not (row is PanelContainer):
		return
	var bg_style: StyleBoxFlat = row.get_meta("bg_style", null)
	var name_lab: Label = row.get_meta("name_label", null)
	var pay_lab: Label = row.get_meta("pay_label", null)
	if bg_style == null:
		return
	var lit_fill := Color("FFCC2E")
	var lit_text := Color("2B1C48")
	var tw := row.create_tween().set_parallel(true)
	tw.tween_property(bg_style, "bg_color", lit_fill, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if name_lab != null:
		tw.tween_property(name_lab, "theme_override_colors/font_color", lit_text, 0.20)
	if pay_lab != null:
		tw.tween_property(pay_lab, "theme_override_colors/font_color", lit_text, 0.20)
	_highlighted_paytable_key = key


## Pre-evaluate the just-dealt hand against the variant's paytable. If
## it already forms a paying combo, soft-highlight the matching row so
## the player sees the goal even before picking holds. Called at the end
## of `_on_cards_dealt`. Returns silently if the hand has no payout key
## or the key is missing from the rendered paytable rows.
func _highlight_dealt_hand_paytable_row(dealt_hand: Array) -> void:
	if _variant == null:
		return
	var typed_hand: Array[CardData] = []
	for c in dealt_hand:
		if c is CardData:
			typed_hand.append(c)
	if typed_hand.size() < 5:
		return
	var rank = _variant.evaluate(typed_hand)
	var key: String = ""
	if _variant.has_method("get_paytable_key"):
		key = _variant.get_paytable_key(rank)
	if key == "":
		return
	if not _paytable_rows.has(key):
		return
	_set_paytable_row_lit(key)


## Highlight emphasis on the payout coin + amount of a winning row.
## During the lit phase the coin and the number swell to ~1.4× and tint
## red so the eye lands on the payout. `enable=false` returns them to
## the original 1.0× scale + paytable-row color.
func _animate_payout_emphasis(row: Control, enable: bool) -> void:
	if not is_instance_valid(row):
		return
	var pay_lab: Label = row.get_meta("pay_label", null)
	# Emphasis is applied to the payout VALUE (the number), not the coin
	# glyph: the digits scale up to ~1.4× and switch to bright red so
	# the win number is the loud focal point on a lit row. The coin
	# stays its normal yellow size — the cascade animation that follows
	# is when chips erupt from it.
	if not is_instance_valid(pay_lab):
		return
	var emphasis_color := Color("E63946")
	var target_color := emphasis_color if enable else PAYTABLE_ROW_COL
	var prev_tw: Tween = pay_lab.get_meta("emphasis_tween", null)
	if prev_tw != null and prev_tw.is_running():
		prev_tw.kill()
	var tw: Tween = pay_lab.create_tween()
	tw.tween_property(pay_lab, "theme_override_colors/font_color", target_color, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pay_lab.set_meta("emphasis_tween", tw)


## Spawn a stream of yellow chip glyphs flying from the given paytable
## row to the balance pill — same visual language as the shop's gift
## claim. Number of chips scales with the win size so a Royal Flush
## throws a thicker shower than a Two Pair. Trail ghosts add a smear.
func _spawn_chip_cascade_to_balance(key: String) -> void:
	var row: Control = _paytable_rows.get(key, null)
	if not is_instance_valid(row) or _balance_label == null:
		return

	# 1) Highlight pre-roll — let the player savour the lit row first.
	#    The pay coin + amount swell to ~1.5× and tint red so the win
	#    feels celebrated; we hold this for `pre_delay` before launching
	#    the chip cascade, then the row settles back as chips fly out.
	var pre_delay: float = 0.85
	_animate_payout_emphasis(row, true)

	var travel_time: float = 0.9  # was 0.6 — slower so the eye can track

	# Hold the balance roll-up until the first chip is on top of the
	# pill. Timeline of one chip after _on_hand_evaluated:
	#   t = 0          → cascade scheduled
	#   t = pre_delay  → chip spawns + fade-in begins, position tween starts
	#   t = pre_delay + travel_time → chip lands on the pill
	# fade-in (0.08s) runs in parallel with the position tween, so it
	# does NOT add to arrival time. We add a tiny 0.05s settle so the
	# number doesn't tick on the same frame the chip touches.
	_balance_hold_until_ms = Time.get_ticks_msec() + int((pre_delay + travel_time + 0.05) * 1000.0)

	await get_tree().create_timer(pre_delay).timeout
	if not is_instance_valid(row) or _balance_label == null:
		return
	# NB: emphasis is intentionally NOT cleared here — the red, enlarged
	# payout value should stay lit through the cascade and remain so
	# until the next DEAL (handled by _reset_paytable_highlight).

	# Spawn point: the payout coin glyph on the right side of the row,
	# so chips visually erupt from where the player just saw the number
	# light up. Falls back to the pay label if the coin glyph is missing.
	var from_anchor: Control = row.get_meta("pay_coin", null) as Control
	if from_anchor == null or not is_instance_valid(from_anchor):
		from_anchor = row.get_meta("pay_label", null) as Control
	if from_anchor == null or not is_instance_valid(from_anchor):
		from_anchor = row
	var from_pos: Vector2 = from_anchor.global_position + from_anchor.size * 0.5
	var target_pos: Vector2 = _balance_label.global_position + _balance_label.size * 0.5

	# Heavier wins → more chips, capped so the screen doesn't get spammed.
	var multiplier: int = int(row.get_meta("multiplier", 1))
	var chip_count: int = clampi(8 + multiplier / 50, 8, 22)
	var stagger_step: float = 0.04
	var chip_size: Vector2 = Vector2(40, 40)

	for i in chip_count:
		# Use the supercell native coin glyph (procedural draw) instead
		# of the classic skin's `glyph_chip.svg` chip — same shape and
		# color story as the BET / WIN / paytable coins on screen.
		var chip: Control = _make_coin_glyph(int(chip_size.x))
		chip.custom_minimum_size = chip_size
		chip.size = chip_size
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.pivot_offset = chip_size * 0.5
		chip.z_index = 500
		# Tighter jitter — chips erupt from the coin glyph, not the
		# whole row, so a small bursting cluster reads better.
		var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		chip.global_position = from_pos + jitter - chip_size * 0.5
		chip.modulate.a = 0.0
		add_child(chip)

		var stagger: float = float(i) * stagger_step
		var tw := chip.create_tween()
		tw.tween_interval(stagger)
		tw.tween_property(chip, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(chip, "global_position",
			target_pos - chip_size * 0.5, travel_time
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(chip, "scale", Vector2(0.55, 0.55), travel_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(chip, "modulate:a", 0.0, 0.1)
		tw.tween_callback(chip.queue_free)

		_spawn_supercell_chip_trail(chip_size, from_pos + jitter, target_pos, stagger, travel_time)


## Trail ghosts that smear behind the main chip — pure visual decoration.
## Each ghost travels the FULL path to the balance pill (same as the main
## chip), just with a small launch delay and reduced opacity, so the
## viewer never sees a coin-shaped object peter out mid-flight.
func _spawn_supercell_chip_trail(size: Vector2, start: Vector2, end: Vector2, base_stagger: float, travel: float) -> void:
	var trail_count: int = 4
	for k in trail_count:
		var ghost: Control = _make_coin_glyph(int(size.x))
		ghost.custom_minimum_size = size
		ghost.size = size
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.pivot_offset = size * 0.5
		ghost.z_index = 490
		ghost.modulate.a = 0.0
		ghost.global_position = start - size * 0.5
		add_child(ghost)
		# Lag behind the main chip by a small fraction of travel_time so the
		# trail reads as a smear, not a separate cluster. Opacity decreases
		# with k so later ghosts are fainter — gives a subtle motion blur.
		var lag: float = float(k + 1) * 0.04
		var peak_alpha: float = 0.40 * (1.0 - float(k) / float(trail_count + 1))
		var tw := ghost.create_tween()
		tw.tween_interval(base_stagger + lag)
		tw.tween_property(ghost, "modulate:a", peak_alpha, 0.08)
		tw.parallel().tween_property(ghost, "global_position",
			end - size * 0.5, travel
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(ghost, "scale", Vector2(0.55, 0.55), travel) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.10)
		tw.tween_callback(ghost.queue_free)


## Update payout amounts on existing paytable rows (no rebuild) when
## the denomination changes. Increases roll up via tween for that
## "money rising" feel; decreases snap instantly so the player doesn't
## wait to see a smaller number. Stops any prior tween per row so
## rapid denom changes don't stack conflicting tweens.
func _refresh_paytable_payouts(prev_denom: int, new_denom: int) -> void:
	if _paytable_rows.is_empty():
		return
	var increasing: bool = new_denom > prev_denom
	for key in _paytable_rows:
		var row: Control = _paytable_rows[key]
		if not is_instance_valid(row):
			continue
		var pay_lab: Label = row.get_meta("pay_label", null)
		var multiplier: int = int(row.get_meta("multiplier", 0))
		if pay_lab == null:
			continue
		var from_val: int = multiplier * prev_denom
		var to_val: int = multiplier * new_denom
		var prev_tw: Tween = pay_lab.get_meta("payout_tween", null)
		if prev_tw != null and prev_tw.is_running():
			prev_tw.kill()
		if not increasing or from_val == to_val:
			pay_lab.text = str(to_val)
			continue
		# Increment animation: 0.6s ease-out roll-up, scaled by delta so
		# big jumps feel weighty without lagging.
		var delta: float = float(to_val - from_val)
		var ref: float = maxf(1.0, float(to_val))
		var ratio: float = clampf(delta / ref, 0.0, 1.0)
		var dur: float = lerpf(0.25, 0.8, ratio)
		var tw := create_tween()
		tw.tween_method(func(v: int) -> void:
			if is_instance_valid(pay_lab):
				pay_lab.text = str(v)
		, from_val, to_val, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		pay_lab.set_meta("payout_tween", tw)


## Paytable panel tap handler. Anywhere on the panel pops the same
## intro bubble — goal of the game + how-to-play. Same dismissal rules
## as any hint bubble (7s auto + tap anywhere).
func _on_paytable_panel_input(event: InputEvent, panel: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Anchor the bubble at the tap point so it follows the finger.
	var hint_text: String = Translations.tr_key("hint.paytable_intro")
	_show_hint_bubble(hint_text, event.global_position)


## Spawn a yellow tooltip bubble above the tap point. The bubble itself
## doesn't block input — the full-screen catcher behind it does, so any
## subsequent tap (anywhere) dismisses the bubble. A 7-second timer also
## auto-dismisses; whichever fires first wins via `_hint_dismiss_id`.
func _show_hint_bubble(text: String, tap_global_pos: Vector2) -> void:
	_hide_hint_bubble()
	_hint_dismiss_id += 1
	var my_id: int = _hint_dismiss_id

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	# Any tap on the catcher dismisses the bubble.
	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_hide_hint_bubble()
	)
	add_child(overlay)
	_hint_bubble = overlay

	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFCC2E")
	style.border_color = Color("0A2915")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.anti_aliasing = true
	bubble.add_theme_stylebox_override("panel", style)
	overlay.add_child(bubble)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("2B1C48"))
	label.add_theme_font_override("font", ThemeManager.font())
	bubble.add_child(label)

	# Need one frame for the bubble to compute its real size before we
	# can centre it horizontally on the tap and place it above the
	# finger. Without this `bubble.size` is (0,0) and clamping breaks.
	await get_tree().process_frame
	if not is_instance_valid(bubble) or _hint_dismiss_id != my_id:
		return
	var b_size: Vector2 = bubble.size
	var local_tap: Vector2 = tap_global_pos - global_position
	var x: float = local_tap.x - b_size.x * 0.5
	var y: float = local_tap.y - b_size.y - 14
	var screen_size: Vector2 = get_viewport_rect().size
	x = clampf(x, 8.0, screen_size.x - b_size.x - 8.0)
	y = maxf(y, 8.0)
	bubble.position = Vector2(x, y)
	bubble.pivot_offset = b_size * 0.5
	bubble.scale = Vector2(0.7, 0.7)
	bubble.modulate.a = 0.0
	var tw := bubble.create_tween().set_parallel(true)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "modulate:a", 1.0, 0.16)

	# Auto-dismiss after 7 seconds — but only if THIS particular bubble
	# is still the active one (a newer tap replaces it).
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		if _hint_dismiss_id == my_id:
			_hide_hint_bubble()
	)


func _hide_hint_bubble() -> void:
	if _hint_bubble and is_instance_valid(_hint_bubble):
		_hint_bubble.queue_free()
	_hint_bubble = null


## Clear sticky paytable highlight left over from the previous round.
## Called on every DEAL via _on_cards_dealt.
func _reset_paytable_highlight() -> void:
	# Drop emphasis (red tint + scale-up) on EVERY row regardless of
	# which one was lit — guards against any prior round leaving a row
	# in the emphasised state (e.g. if a tween was killed mid-flight).
	for k in _paytable_rows:
		var any_row: Control = _paytable_rows[k]
		if is_instance_valid(any_row):
			_animate_payout_emphasis(any_row, false)
	if _highlighted_paytable_key == "":
		return
	var row: PanelContainer = _paytable_rows.get(_highlighted_paytable_key, null)
	_highlighted_paytable_key = ""
	if not (row is PanelContainer):
		return
	var bg_style: StyleBoxFlat = row.get_meta("bg_style", null)
	var name_lab: Label = row.get_meta("name_label", null)
	var pay_lab: Label = row.get_meta("pay_label", null)
	if bg_style != null:
		var tw := row.create_tween().set_parallel(true)
		tw.tween_property(bg_style, "bg_color", Color(0, 0, 0, 0), 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if name_lab != null:
			tw.tween_property(name_lab, "theme_override_colors/font_color", PAYTABLE_ROW_COL, 0.25)
		if pay_lab != null:
			tw.tween_property(pay_lab, "theme_override_colors/font_color", PAYTABLE_ROW_COL, 0.25)


func _build_cards_area() -> void:
	# Absolute-anchored layout so bands never swap order under any
	# container alignment quirks. Each section is a child of `center`
	# with an explicit y-range anchored inside center's rect.
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 460
	center.offset_top = 150
	center.offset_right = -40
	center.offset_bottom = -150
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_cards_area_root = center

	# ── Status banner — single fixed-width pill above the cards. Drives
	# every state prompt (PLACE BET → HOLD → NO WIN / WIN NAME) so the
	# player's eye has one anchor. Width is locked via SHRINK_CENTER +
	# custom_minimum_size so the pill doesn't resize per-message. ──
	var banner_wrap := HBoxContainer.new()
	banner_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_wrap.offset_top = 0
	banner_wrap.offset_bottom = 52
	banner_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(banner_wrap)

	var banner := PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.custom_minimum_size = Vector2(480, 52)
	# Prefer the supercell sticker PNG when shipped with the theme,
	# fall back to a flat amber-with-orange-border stylebox so the banner
	# still renders if the asset's missing.
	var banner_png_path: String = ThemeManager.theme_folder() + "controls/hit_banner.png"
	if ResourceLoader.exists(banner_png_path):
		var banner_tex: Texture2D = load(banner_png_path)
		var banner_sbt := StyleBoxTexture.new()
		banner_sbt.texture = banner_tex
		banner_sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		banner_sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		banner_sbt.content_margin_left = 28
		banner_sbt.content_margin_right = 28
		banner_sbt.content_margin_top = 4
		banner_sbt.content_margin_bottom = 4
		banner.add_theme_stylebox_override("panel", banner_sbt)
	else:
		var banner_style := StyleBoxFlat.new()
		banner_style.bg_color = Color("F2C64A")
		banner_style.set_corner_radius_all(10)
		banner_style.set_border_width_all(3)
		banner_style.border_color = Color("D8621E")
		banner_style.anti_aliasing = true
		banner_style.content_margin_left = 24
		banner_style.content_margin_right = 24
		banner_style.content_margin_top = 4
		banner_style.content_margin_bottom = 4
		banner.add_theme_stylebox_override("panel", banner_style)
	banner_wrap.add_child(banner)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.clip_text = true
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", Color("5A3A22"))
	_status_label.add_theme_font_override("font", ThemeManager.font())
	_status_label.text = ""
	banner.add_child(_status_label)
	# Keep banner ref so we can animate on wins without rebuilding it.
	_status_label.set_meta("banner_panel", banner)

	# ── Winning-hand name pill — overlaid ON the cards (classic-parity
	# MessegBar placement). One Label that paints its own background via
	# the "normal" stylebox + content_margins; no PanelContainer wrapper
	# so the Label can never lose its size to a parent's layout pass. ──
	_win_name_label = Label.new()
	_win_name_label.anchor_left = 0.5
	_win_name_label.anchor_right = 0.5
	_win_name_label.anchor_top = 0.0
	_win_name_label.anchor_bottom = 0.0
	_win_name_label.offset_left = -220
	_win_name_label.offset_right = 220
	_win_name_label.offset_top = 195
	_win_name_label.offset_bottom = 245
	_win_name_label.z_index = 10  # stack above cards + their golden borders
	_win_name_label.visible = false
	_win_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_win_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_win_name_label.clip_text = false
	_win_name_label.add_theme_font_size_override("font_size", 28)
	_win_name_label.add_theme_color_override("font_color", Color("FFCC2E"))
	_win_name_label.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	_win_name_label.add_theme_constant_override("outline_size", 4)
	_win_name_label.add_theme_font_override("font", ThemeManager.font())
	# Background plate — Label supports a "normal" stylebox in 4.x.
	var wn_style := StyleBoxFlat.new()
	wn_style.bg_color = Color("2B1C48")
	wn_style.set_corner_radius_all(12)
	wn_style.set_border_width_all(4)
	wn_style.border_color = Color("FFCC2E")
	wn_style.anti_aliasing = true
	wn_style.shadow_color = Color(0, 0, 0, 0.55)
	wn_style.shadow_size = 8
	wn_style.shadow_offset = Vector2(0, 4)
	wn_style.content_margin_left = 16
	wn_style.content_margin_right = 16
	wn_style.content_margin_top = 4
	wn_style.content_margin_bottom = 4
	_win_name_label.add_theme_stylebox_override("normal", wn_style)
	_win_name_label.text = ""
	center.add_child(_win_name_label)

	# ── Lose pill — same plate as the win pill but a RichTextLabel so
	# we can colour individual words via BBCode ("PRESS [color=#E63946]DEAL[/color]"). ──
	_lose_name_label = RichTextLabel.new()
	_lose_name_label.anchor_left = 0.5
	_lose_name_label.anchor_right = 0.5
	_lose_name_label.anchor_top = 0.0
	_lose_name_label.anchor_bottom = 0.0
	_lose_name_label.offset_left = -220
	_lose_name_label.offset_right = 220
	_lose_name_label.offset_top = 195
	_lose_name_label.offset_bottom = 245
	_lose_name_label.z_index = 10
	_lose_name_label.visible = false
	_lose_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lose_name_label.bbcode_enabled = true
	_lose_name_label.scroll_active = false
	_lose_name_label.fit_content = true
	_lose_name_label.add_theme_font_size_override("normal_font_size", 28)
	_lose_name_label.add_theme_color_override("default_color", Color("FFCC2E"))
	_lose_name_label.add_theme_font_override("normal_font", ThemeManager.font())
	# Re-use the same purple plate background.
	var lose_style := StyleBoxFlat.new()
	lose_style.bg_color = Color("2B1C48")
	lose_style.set_corner_radius_all(12)
	lose_style.set_border_width_all(4)
	lose_style.border_color = Color("FFCC2E")
	lose_style.anti_aliasing = true
	lose_style.shadow_color = Color(0, 0, 0, 0.55)
	lose_style.shadow_size = 8
	lose_style.shadow_offset = Vector2(0, 4)
	lose_style.content_margin_left = 16
	lose_style.content_margin_right = 16
	lose_style.content_margin_top = 8
	lose_style.content_margin_bottom = 8
	_lose_name_label.add_theme_stylebox_override("normal", lose_style)
	_refresh_lose_name_label_text()
	center.add_child(_lose_name_label)

	# ── Cards row — classic parity (aspect 0.739, 14px gap).
	# HELD indicator is rendered INSIDE the card by CardVisual.set_held()
	# (same golden border + HELD label as classic), so cards stand alone
	# without an external badge strip. ──
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Tighter card spacing — cards sit almost shoulder-to-shoulder.
	# Same 4px gap as multi/ultra's primary row.
	cards_row.add_theme_constant_override("separation", 4)
	cards_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cards_row.offset_top = 72
	cards_row.offset_bottom = 290
	center.add_child(cards_row)

	var card_scene: PackedScene = load("res://scenes/card.tscn")
	# Card aspect 136:184 = 0.739 — keeps classic proportions.
	var card_w: int = 148
	var card_h: int = 200
	for i in 5:
		var card_wrap := Control.new()
		card_wrap.custom_minimum_size = Vector2(card_w, card_h + 16)
		cards_row.add_child(card_wrap)
		var card: Control = card_scene.instantiate() as Control
		card.set_anchors_preset(Control.PRESET_CENTER)
		card.grow_horizontal = Control.GROW_DIRECTION_BOTH
		card.grow_vertical = Control.GROW_DIRECTION_BOTH
		card.custom_minimum_size = Vector2(card_w, card_h)
		card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
		# Force every card sprite to fill the rect uniformly. Some PNGs in
		# the deck have non-uniform aspect (e.g. card_vp_jd is 162×184 vs
		# the standard 136×184), and KEEP_ASPECT_CENTERED would shrink the
		# odd ones — TextureRect.STRETCH_SCALE makes every card render at
		# exactly the same on-screen dimensions.
		if card is TextureRect:
			(card as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
		card.gui_input.connect(_on_card_clicked.bind(i))
		card_wrap.add_child(card)
		_cards.append(card)
		# Winner glow — gold outline drawn over the card on a winning
		# hand for cards that contributed to the combo (whether they
		# were held during DRAW or freshly drawn). Hidden by default;
		# `_set_winner_glow` toggles it on when _on_hand_evaluated runs.
		# Lives as a child of the card so it inherits tilt + scale
		# transforms but renders ABOVE the texture (z_index = 1).
		var glow := Control.new()
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.modulate.a = 0.0
		glow.z_index = 1
		glow.draw.connect(_draw_winner_glow.bind(glow))
		card.add_child(glow)
		_winner_glows.append(glow)
		# CardVisual computes HELD position from the texture's aspect ratio.
		# In supercell with our card_w/card_h ratio that math drifts the pill
		# to the left edge — re-anchor it to TOP_WIDE so it's always
		# horizontally centered above the card after the node is ready.
		card.ready.connect(_recenter_held_for_card.bind(card), CONNECT_ONE_SHOT)

	# ── WIN / Last row — below the status hint. Active state shows
	# "WIN" + counter-animated amount (gold); dimmed state shows
	# "LAST WIN" + last amount (muted). Mirrors classic game.gd. ──
	var win_row := HBoxContainer.new()
	win_row.alignment = BoxContainer.ALIGNMENT_CENTER
	win_row.add_theme_constant_override("separation", 14)
	win_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	win_row.offset_top = 305
	win_row.offset_bottom = 348
	center.add_child(win_row)
	_last_label = Label.new()
	_last_label.text = Translations.tr_key("game.last_win_label")
	_last_label.add_theme_font_size_override("font_size", 22)
	_last_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
	_last_label.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	_last_label.add_theme_constant_override("outline_size", 3)
	_last_label.add_theme_font_override("font", ThemeManager.font())
	_last_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	win_row.add_child(_last_label)
	var coin_small := _make_coin_glyph(28)
	coin_small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	win_row.add_child(coin_small)
	_win_label = Label.new()
	_win_label.text = "0"
	_win_label.add_theme_font_size_override("font_size", 30)
	_win_label.add_theme_color_override("font_color", Color("F2D62E"))
	_win_label.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	_win_label.add_theme_constant_override("outline_size", 4)
	_win_label.add_theme_font_override("font", ThemeManager.font())
	_win_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	win_row.add_child(_win_label)

	# BET pill removed — bet is locked at MAX in supercell, and the wager
	# per round equals the denomination, which is now displayed inline on
	# the COINS picker button (see `_build_bottom_bar`).


func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 40
	bar.offset_right = -40
	# Bar height grows to accommodate 2× larger buttons (90px tall) plus
	# 12px breathing room at the bottom of the screen.
	bar.offset_top = -110
	bar.offset_bottom = -20
	# 3× the original separation so the right-cluster controls (SPEED,
	# COINS, DEAL) breathe — much closer to the supercell mock.
	bar.add_theme_constant_override("separation", 36)
	add_child(bar)
	_bottom_bar_root = bar

	# Left-side spacer pushes everything to the right edge next to DEAL.
	# Supercell intentionally drops BET LEVEL (bet locked at MAX) and
	# MAX BET (redundant with the lock) — classic keeps both.
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)

	# Hidden BET-LEVEL + MAX BET refs kept as node placeholders so existing
	# callbacks (paytable bet-column refresh) that touch these vars don't
	# NPE. They never enter the visual tree.
	_bet_lvl_btn = Button.new()
	_bet_lvl_btn.visible = false
	_bet_lvl_btn.disabled = true
	add_child(_bet_lvl_btn)

	_max_bet_btn = Button.new()
	_max_bet_btn.visible = false
	_max_bet_btn.disabled = true
	add_child(_max_bet_btn)

	# DOUBLE is created here as an unparented Button so callbacks can
	# safely read `_double_btn` from `_ready` onward; it gets parented to
	# the bar later (just before DEAL) so the visual order ends up
	# spacer · SPEED · COINS · DOUBLE · DEAL.
	_double_btn = _make_flat_btn(BET_LVL_BG, Color("2A1708"), "DOUBLE", Color.WHITE, 29)
	_double_btn.custom_minimum_size = Vector2(160, 90)
	_double_btn.disabled = true
	_double_btn.pressed.connect(_on_double_pressed)

	# SPEED — right cluster, leftmost. 2× the original 80×45 footprint
	# (160×90) so finger-targets feel right on phone screens; matching
	# font bump from 14 → 22 keeps the label proportional.
	var speed_btn := _make_flat_btn(BET_LVL_BG, Color("2A1708"), "SPEED", Color.WHITE, 22)
	speed_btn.custom_minimum_size = Vector2(160, 90)
	speed_btn.pressed.connect(_on_speed_pressed)
	speed_btn.visible = bool(ConfigManager.init_config.get("show_speed_button", false))
	bar.add_child(speed_btn)
	_speed_btn = speed_btn
	_speed_level = SaveManager.speed_level
	_refresh_speed_label()
	_apply_btn_png(speed_btn, "btn_speed.png")

	# TUTOR button — sits immediately to the left of SPEED. Replays the
	# tutorial overlay starting from slide 2 (the cheat path inside
	# `TutorialOverlay.attach_tutor_button`). Pass `null` for the
	# manager — `_game_manager` doesn't exist yet at _build_bottom_bar
	# time. The disable flag is driven from `_on_state_changed` instead,
	# which runs once `_game_manager` is wired and emits the initial
	# state.
	_tutor_btn = TutorialOverlay.attach_tutor_button(speed_btn, null)
	if _tutor_btn != null:
		_tutor_btn.disabled = false

	# Coins/denomination picker — right cluster. Uses the blank speed
	# plate for the background; `btn_denom.png` has baked-in "DENOM"
	# text that would collide with our dynamic coin + amount row.
	var denom := _make_flat_btn(BET_LVL_BG, Color("2A1708"), "", Color.WHITE, 22)
	denom.custom_minimum_size = Vector2(180, 90)
	denom.pressed.connect(_on_denom_pressed)
	bar.add_child(denom)
	_apply_btn_png(denom, "btn_speed.png")
	# Inline "COINS: <chip><amount>" on the picker button. Tight gap (4)
	# between the prefix and the chip+value cluster so the trio reads as
	# one phrase; chip and value are even tighter (2) so the glyph reads
	# visually paired with its number.
	_denom_btn = denom
	# Re-pick full vs short format every time the button gets a real size
	# (initial layout pass, orientation change, etc) — without this, the
	# very first render uses the pre-layout heuristic and a 2,500 label
	# can overflow the slot until the player changes denom.
	denom.resized.connect(_refresh_denom_label_text)
	var denom_hb := HBoxContainer.new()
	denom_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	denom_hb.add_theme_constant_override("separation", 4)
	denom_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	denom_hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	denom.add_child(denom_hb)
	_coins_prefix_lab = Label.new()
	_coins_prefix_lab.text = "COINS:"
	_coins_prefix_lab.add_theme_font_size_override("font_size", 22)
	_coins_prefix_lab.add_theme_color_override("font_color", Color.WHITE)
	_coins_prefix_lab.add_theme_font_override("font", ThemeManager.font())
	_coins_prefix_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	denom_hb.add_child(_coins_prefix_lab)
	var coin_amount_hb := HBoxContainer.new()
	coin_amount_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_amount_hb.add_theme_constant_override("separation", 2)
	coin_amount_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	denom_hb.add_child(coin_amount_hb)
	var denom_coin := _make_coin_glyph(40)
	denom_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_amount_hb.add_child(denom_coin)
	_denom_lab = Label.new()
	_denom_lab.add_theme_font_size_override("font_size", 22)
	_denom_lab.add_theme_color_override("font_color", Color.WHITE)
	_denom_lab.add_theme_font_override("font", ThemeManager.font())
	_denom_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set the text AFTER the font override so _format_denom_for_button can
	# measure with the real font; otherwise get_theme_font() returns null
	# and the formatter falls back to the full string regardless of width.
	_denom_lab.text = _format_denom_for_button(SaveManager.denomination)
	coin_amount_hb.add_child(_denom_lab)

	# DOUBLE — added to the bar AFTER COINS so it sits between COINS and
	# DEAL in the visual flow. Same yellow plate as the rest of the right
	# cluster. Visibility is config-driven (`show_double_button` in
	# init_config / Remote Config) so single + multi stay in sync — when
	# the App Store stealth flag flips DOUBLE off in multi, it must also
	# be hidden here.
	_double_btn.visible = bool(ConfigManager.init_config.get("show_double_button", true))
	bar.add_child(_double_btn)
	# Keep the "DOUBLE" label rendered ON TOP of the PNG plate (same
	# pattern as SPEED / DEAL — the artwork carries the chrome, Godot
	# draws the text). `clear_text=true` would leave the button blank
	# since `btn_double.png` doesn't bake the word in.
	_apply_btn_png(_double_btn, "btn_double.png")

	# DEAL/DRAW — right cluster, rightmost. With MAX BET gone the
	# player taps DEAL directly; bet is forced to MAX on deal so the
	# round still uses the full-pay paytable.
	_draw_btn = _make_flat_btn(DRAW_BG, Color("8C6A0E"), "DEAL", Color("2A2008"), 35)
	_draw_btn.custom_minimum_size = Vector2(240, 90)
	_draw_btn.pressed.connect(_on_deal_draw_pressed)
	bar.add_child(_draw_btn)
	# NB: _draw_btn text flips DEAL / DRAW ! at runtime — text isn't
	# baked into the PNGs. Initial sticker is btn_deal (idle state);
	# _apply_deal_or_draw_skin swaps to btn_draw when the FSM enters
	# HOLDING. If the deal asset is missing the helper falls back to
	# btn_draw on both states so the button is never blank.
	_apply_deal_or_draw_skin(false)


# ──────────────────────────────────────────────────────────────────────
# Sticker-style button helpers (primitive placeholders — user swaps
# with PNGs later via themes/supercell/controls/*.png).
# ──────────────────────────────────────────────────────────────────────

func _make_sticker_btn(fill: Color, outline: Color) -> Button:
	var btn := Button.new()
	# NB: do NOT set `flat = true` — that hides the stylebox background
	# and the button renders as text only over the felt (bug seen on
	# first render). Custom styleboxes take effect only on non-flat btns.
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.set_corner_radius_all(16)
	st.set_border_width_all(4)
	st.border_color = outline
	st.anti_aliasing = true
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 2
	st.shadow_offset = Vector2(0, 6)
	var hover := st.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", st)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_add_press_effect(btn)
	return btn


## Scale-pop press feedback — identical timing to classic game.gd so
## every button in supercell feels the same under finger.
func _add_press_effect(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size / 2)
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.05)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	)


## Generic press-pop on any Control (Panel, PanelContainer, …) — Button
## has button_down/up signals, plain Controls don't, so we listen for
## InputEventMouseButton on gui_input and replicate the same scale tween.
func _add_press_effect_generic(ctrl: Control) -> void:
	ctrl.pivot_offset = ctrl.size / 2
	ctrl.resized.connect(func() -> void: ctrl.pivot_offset = ctrl.size / 2)
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			var tw_down := ctrl.create_tween()
			tw_down.tween_property(ctrl, "scale", Vector2(0.97, 0.97), 0.05)
		else:
			var tw_up := ctrl.create_tween()
			tw_up.tween_property(ctrl, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	)


func _make_flat_btn(fill: Color, outline: Color, txt: String, text_col: Color, fs: int = 20) -> Button:
	var btn := _make_sticker_btn(fill, outline)
	btn.text = txt
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_font_size_override("font_size", fs)
	btn.add_theme_font_override("font", ThemeManager.font())
	return btn


## Swap the DEAL/DRAW button background between `btn_deal.png` (idle)
## and `btn_draw.png` (HOLDING). Falls back to whichever asset exists
## so the button never renders blank if one PNG is missing — useful
## while the deal sticker is still being authored.
func _apply_deal_or_draw_skin(is_holding: bool) -> void:
	if _draw_btn == null or not is_instance_valid(_draw_btn):
		return
	var primary: String = "btn_draw.png" if is_holding else "btn_deal.png"
	var fallback: String = "btn_deal.png" if is_holding else "btn_draw.png"
	var primary_path: String = ThemeManager.theme_folder() + "controls/" + primary
	var chosen: String = primary if ResourceLoader.exists(primary_path) else fallback
	_apply_btn_png(_draw_btn, chosen)


## If assets/themes/<active_theme>/controls/<filename> exists, replace
## the button's StyleBoxFlat with a StyleBoxTexture drawn from the PNG.
## `clear_text` is for buttons whose PNG has text baked in (DRAW,
## MAX BET, etc.) — skip it on buttons whose label is dynamic (BET LVL,
## SPEED, DENOM) so Godot's text can update over the static PNG.
func _apply_btn_png(btn: Button, filename: String, clear_text: bool = false) -> void:
	var path := ThemeManager.theme_folder() + "controls/" + filename
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var st := StyleBoxTexture.new()
	st.texture = tex
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	var hover := st.duplicate() as StyleBoxTexture
	# Subtle press/hover feedback via modulate on the button itself —
	# the stylebox itself stays identical so the image doesn't recolor.
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", st)
	# Disabled stylebox = same texture darkened via modulate_color so
	# Godot's default flat-grey disabled box doesn't replace the
	# supercell PNG plate. Without this, a disabled button (e.g. DOUBLE
	# until a winning hand evaluates) renders as a featureless grey rect.
	var disabled := st.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled)
	# Match the disabled font color too so the "DOUBLE" / "DEAL" text
	# follows the dimmed plate instead of staying bright on a dark sticker.
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	if clear_text:
		btn.text = ""


## All "coin" glyphs in the supercell skin pull from a single PNG asset
## (themes/supercell/controls/coin_chip.png) so the whole UI reads as
## one design language. Uses a TextureRect with KEEP_ASPECT_CENTERED so
## any pixel size renders crisply. Procedural circle draw is kept only
## as a defensive fallback when the asset is missing on disk.
const _SUPERCELL_COIN_TEX_PATH := "res://assets/themes/supercell/controls/coin_chip.png"

func _make_coin_glyph(px: int) -> Control:
	if ResourceLoader.exists(_SUPERCELL_COIN_TEX_PATH):
		var tr := TextureRect.new()
		tr.texture = load(_SUPERCELL_COIN_TEX_PATH)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(px, px)
		tr.size = Vector2(px, px)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	# Fallback: procedural circle if the PNG was excluded from the build.
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var center := c.size * 0.5
		var r := c.size.x * 0.45
		c.draw_circle(center, r, Color("F2D62E"))
		c.draw_arc(center, r, 0, TAU, 32, Color("8C6A0E"), 2.5)
		c.draw_circle(center, r * 0.55, Color("F2E88A"))
	)
	return c


func _draw_arrow_left(ctrl: Control) -> void:
	# Arrow geometry scales with the button so the same shape works on
	# 88x88 (classic supercell sizing) AND on the new 44x44 back button.
	var w := ctrl.size.x
	var h := ctrl.size.y
	var cx := w * 0.5
	var cy := h * 0.5
	var u: float = minf(w, h) / 88.0  # 1.0 at 88px, 0.5 at 44px
	var pts := PackedVector2Array([
		Vector2(cx + 14 * u, cy - 18 * u),
		Vector2(cx - 18 * u, cy),
		Vector2(cx + 14 * u, cy + 18 * u),
		Vector2(cx + 14 * u, cy + 8 * u),
		Vector2(cx - 2 * u, cy),
		Vector2(cx + 14 * u, cy - 8 * u),
	])
	ctrl.draw_colored_polygon(pts, Color.WHITE)


## Plus sign drawn centered on the top-up button. Procedural so we
## don't need a PNG for a one-off glyph.
func _draw_plus_glyph(ctrl: Control) -> void:
	var cx := ctrl.size.x * 0.5
	var cy := ctrl.size.y * 0.5
	var arm: float = minf(ctrl.size.x, ctrl.size.y) * 0.3
	var thickness: float = 6.0
	ctrl.draw_rect(Rect2(cx - arm, cy - thickness * 0.5, arm * 2, thickness), Color("2A1F00"))
	ctrl.draw_rect(Rect2(cx - thickness * 0.5, cy - arm, thickness, arm * 2), Color("2A1F00"))


## 1s ticker updating the gift countdown label. When the gift is ready
## the label reads "READY" and the widget pulses softly.
func _start_gift_ticker() -> void:
	if _gift_timer != null:
		return
	_gift_timer = Timer.new()
	_gift_timer.wait_time = 1.0
	_gift_timer.autostart = true
	_gift_timer.one_shot = false
	_gift_timer.timeout.connect(_refresh_gift_label)
	add_child(_gift_timer)
	_refresh_gift_label()


func _refresh_gift_label() -> void:
	if _gift_label == null:
		return
	var interval_hours: int = ConfigManager.get_gift_interval_hours()
	var interval_sec: int = interval_hours * 3600
	var now: int = int(Time.get_unix_time_from_system())
	var last: int = SaveManager.last_gift_time
	var ready: bool = last == 0 or now - last >= interval_sec
	if ready:
		_gift_label.text = "READY"
	else:
		var remaining: int = interval_sec - (now - last)
		var hh: int = remaining / 3600
		var mm: int = (remaining % 3600) / 60
		var ss: int = remaining % 60
		if hh > 0:
			_gift_label.text = "%d:%02d:%02d" % [hh, mm, ss]
		else:
			_gift_label.text = "%02d:%02d" % [mm, ss]
	_refresh_gift_icon_texture()


## Swap the icon TextureRect between ready / waiting PNG states. Same
## logic as lobby._refresh_gift_icon — falls back to whichever path is
## available so a partial asset set still renders something.
func _refresh_gift_icon_texture() -> void:
	if _gift_icon_tex == null or not is_instance_valid(_gift_icon_tex):
		return
	var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
	var now: int = int(Time.get_unix_time_from_system())
	var last: int = SaveManager.last_gift_time
	var ready: bool = last == 0 or now - last >= interval_sec
	var path: String = _gift_ready_path if ready else _gift_waiting_path
	if path == "":
		path = _gift_ready_path if _gift_ready_path != "" else _gift_waiting_path
	if path == "":
		return
	if _gift_icon_tex.texture == null or _gift_icon_tex.texture.resource_path != path:
		_gift_icon_tex.texture = load(path)


func _draw_info_glyph(ctrl: Control) -> void:
	var font: Font = ThemeManager.font()
	if font == null:
		font = ctrl.get_theme_default_font()
	if font == null:
		return
	# Font size scales with the button — 52pt at the original 88px size,
	# 26pt at the new compact 44px sizing.
	var glyph_size: int = int(round(minf(ctrl.size.x, ctrl.size.y) * 52.0 / 88.0))
	var txt := "i"
	var size_px: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, glyph_size)
	var cx := ctrl.size.x * 0.5
	var cy := ctrl.size.y * 0.5
	ctrl.draw_string(font,
		Vector2(cx - size_px.x * 0.5, cy + size_px.y * 0.33),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, Color.WHITE)


# ──────────────────────────────────────────────────────────────────────
# Game FSM wiring
# ──────────────────────────────────────────────────────────────────────

func _setup_manager() -> void:
	_game_manager = GameManager.new()
	add_child(_game_manager)
	_game_manager.setup(_variant)
	# Supercell single-hand always plays at bet level 1; the player only
	# changes the COINS denomination, never the bet level. Force the FSM
	# to bet=1 right after setup() (which would otherwise restore the
	# previously-saved bet level from SaveManager).
	if _game_manager.bet != 1:
		_game_manager.bet = 1
		SaveManager.set_bet_level("single_play", 1)
	_game_manager.state_changed.connect(_on_state_changed)
	_game_manager.cards_dealt.connect(_on_cards_dealt)
	_game_manager.card_replaced.connect(_on_card_replaced)
	_game_manager.hand_evaluated.connect(_on_hand_evaluated)
	_game_manager.credits_changed.connect(_on_credits_changed)
	_game_manager.bet_changed.connect(_on_bet_changed)
	_refresh_bet_display()
	_rebuild_paytable_rows()
	# GameManager starts in IDLE but doesn't emit state_changed on boot,
	# so the banner would stay blank until the first state transition.
	# Kick the visual handler once manually so the "START A ROUND" hint
	# appears before the player touches DEAL.
	_on_state_changed(GameManager.State.IDLE)


func _get_deal_ms() -> int:
	return int(SPEED_CONFIGS[_speed_level]["deal_ms"])


func _get_draw_ms() -> int:
	return int(SPEED_CONFIGS[_speed_level]["draw_ms"])


func _get_flip_s() -> float:
	return float(SPEED_CONFIGS[_speed_level]["flip_s"])


func _on_state_changed(state: int) -> void:
	var is_holding := state == GameManager.State.HOLDING
	_draw_btn.text = Translations.tr_key("game.draw") if is_holding else Translations.tr_key("game.deal")
	# Swap the sticker artwork to match the action — `btn_deal.png` for
	# idle/post-round, `btn_draw.png` while the player is choosing holds.
	_apply_deal_or_draw_skin(is_holding)
	# DOUBLE is only eligible right after a winning hand.
	if _double_btn != null:
		_double_btn.disabled = not (state == GameManager.State.WIN_DISPLAY and _game_manager.last_win > 0)
	# TUTOR is only available between rounds (idle / post-result).
	if _tutor_btn != null and is_instance_valid(_tutor_btn):
		_tutor_btn.disabled = not (state == GameManager.State.IDLE \
				or state == GameManager.State.WIN_DISPLAY)
	# Status hint per state — classic-parity strings.
	match state:
		GameManager.State.IDLE:
			_set_status(Translations.tr_key("game.start_a_round"))
			_set_win_dimmed()
		GameManager.State.DEALING:
			_set_status("")
		GameManager.State.HOLDING:
			_set_status(Translations.tr_key("game.hold_cards_then_draw"))
			# Autohold already applied by GameManager.on_deal_animation_complete
			# — mirror the held state onto the visuals (tilt + golden border)
			# so the player sees which cards are auto-held.
			for i in 5:
				if i < _cards.size() and _game_manager.held[i]:
					_apply_hold_visual(i)
		GameManager.State.DRAWING:
			_set_status("")
		GameManager.State.WIN_DISPLAY:
			# Status text is driven from _on_hand_evaluated (winning name
			# overlay or NO WIN consolation), so don't overwrite it here.
			pass
	# Classic-parity idle blink — DEAL button pulses while the player
	# hasn't kicked off a round yet (IDLE / WIN_DISPLAY).
	if state == GameManager.State.IDLE or state == GameManager.State.WIN_DISPLAY:
		_start_idle_blink()
	else:
		_stop_idle_blink()


func _start_idle_blink() -> void:
	_stop_idle_blink()
	if not ConfigManager.is_feature_enabled("deal_button_idle_blink", true):
		return
	if _draw_btn == null:
		return
	_idle_blink_tween = _draw_btn.create_tween().set_loops()
	var half_blink: float = ConfigManager.get_animation("deal_button_blink_interval_ms", 600.0) / 2000.0
	for i in 2:
		_idle_blink_tween.tween_property(_draw_btn, "modulate:a", 0.45, half_blink)
		_idle_blink_tween.tween_property(_draw_btn, "modulate:a", 1.0, half_blink)
	_idle_blink_tween.tween_interval(ConfigManager.get_animation("deal_button_idle_blink_sec", 5.0))


func _stop_idle_blink() -> void:
	if _idle_blink_tween and _idle_blink_tween.is_running():
		_idle_blink_tween.kill()
	_idle_blink_tween = null
	if _draw_btn != null:
		_draw_btn.modulate.a = 1.0


## Classic-parity deal animation: flip any face-up cards back, then
## stagger face-up set_card() calls 100ms apart, then advance FSM.
func _on_cards_dealt(dealt_hand: Array) -> void:
	_animating = true
	# Fresh round — drop any sticky paytable highlight from the last win
	# AND hide the winning-hand / try-again pill (both tied to the
	# previous round's evaluation). Also dismiss any active hint bubble
	# so the cards aren't covered, and clear winner-card glows.
	_reset_paytable_highlight()
	_show_win_name_pill(false)
	_show_lose_name_pill(false)
	_hide_hint_bubble()
	_clear_winner_glows()
	var instant := _get_flip_s() < 0.03
	var any_face_up := false
	for i in 5:
		if i >= _cards.size():
			continue
		_cards[i].set_flip_duration(_get_flip_s())
		if _cards[i].face_up:
			any_face_up = true
			_cards[i].flip_to_back()
			if not instant:
				await get_tree().create_timer(_get_deal_ms() / 1000.0).timeout
	if any_face_up and not instant:
		await get_tree().create_timer(ConfigManager.get_animation("card_deal_delay_ms", 80.0) / 1000.0).timeout
	for i in 5:
		if i >= _cards.size():
			continue
		_cards[i].set_flip_duration(_get_flip_s())
		_cards[i].set_card(dealt_hand[i], true, _variant.is_wild_card(dealt_hand[i]))  # SFX inside CardVisual
		VibrationManager.vibrate("card_deal")
		# Clear hold state from previous round — classic HELD overlay off
		# + balatro tilt + wobble reset. Without explicit wobble stop the
		# looping tween would keep jittering the fresh card.
		if _cards[i].has_method("set_held"):
			_cards[i].set_held(false)
		_stop_card_wobble(_cards[i])
		_tween_card_rotation(_cards[i], 0.0, 0.18)
		if not instant and i < 4:
			await get_tree().create_timer(_get_deal_ms() / 1000.0).timeout
	if not instant:
		await get_tree().create_timer(_get_flip_s() * 2).timeout
	# Fresh round — WIN label goes active (starts at 0, counts up on eval);
	# winning-hand overlay and status hint clear.
	_set_win_active(0)
	if _win_name_label != null:
		_win_name_label.visible = false
	_animating = false
	# Pre-eval: if the dealt 5 already form a paying combo, light up the
	# matching paytable row immediately so the player sees the goal.
	# Survives into DRAW — `_pulse_paytable_row` detects same-key reuse
	# and only adds the scale pop instead of re-flashing the highlight.
	_highlight_dealt_hand_paytable_row(dealt_hand)
	if is_instance_valid(_game_manager):
		_game_manager.on_deal_animation_complete()


## Handled inline in _on_deal_draw_pressed (like classic); signal is
## still connected for parity but no per-card action here.
func _on_card_replaced(_index: int, _new_card: CardData) -> void:
	pass


func _on_hand_evaluated(hand_rank: int, hand_name: String, payout: int) -> void:
	_last_win_amount = payout
	# Result is announced — the COINS picker becomes interactive again
	# (unless we're in the middle of a Double sub-game, which keeps it
	# locked via `_in_double`). The visual state is restored here so
	# the player can change denomination before the next DEAL.
	if not _in_double:
		_set_denom_btn_locked(false)
	if _double_btn != null:
		_double_btn.disabled = not (payout > 0)
	# Seed the double-or-nothing wager pool with the FRESH draw payout so
	# the first DOUBLE press risks the original win. Skip during a double
	# round so the accumulated value (e.g. 2× / 4× after consecutive wins)
	# isn't reset to the original draw amount — matches classic game.gd.
	if payout > 0 and not _in_double:
		_double_amount = payout
	if payout > 0:
		# Status banner cheers; hand-name pill above the cards shows the
		# combo, like the classic MessegBar overlay.
		_set_status(Translations.tr_key("game.you_win"))
		if _win_name_label != null and hand_name != "":
			_win_name_label.text = hand_name.to_upper()
			_show_win_name_pill(true)
		# Outline every card that contributed to the winning combo —
		# even cards drawn at DRAW time get the gold border, not just
		# the ones the player explicitly HELD.
		_highlight_winning_cards(hand_rank)
		var key: String = _variant.get_paytable_key(hand_rank) if _variant.has_method("get_paytable_key") else ""
		if key != "":
			_pulse_paytable_row(key)
			# Chip cascade — coins fly from the winning paytable row to
			# the balance pill, mirroring the shop-claim animation.
			_spawn_chip_cascade_to_balance(key)
		_animate_win_increment(0, payout)
		_flash_balance_win()
		var total_bet: int = _game_manager.bet * SaveManager.denomination
		if BigWinOverlay:
			BigWinOverlay.show_if_qualifies(self, payout, total_bet)
		SoundManager.play("win")
	else:
		# No-win: hide the win pill, pop the "TRY AGAIN! PRESS DEAL" pill
		# above the cards, dim the WIN counter, and keep the consolation
		# banner ("NO WIN") in the status strip so the player has both:
		# the call-to-action above the hand and the result label below.
		_show_win_name_pill(false)
		_refresh_lose_name_label_text()
		_show_lose_name_pill(true)
		_set_status(Translations.tr_key("game.no_win"))
		_set_win_dimmed()
		# Clear the sticky DEAL-time highlight (e.g. the player started
		# with JJ but un-held both jacks — DRAW evaluates as no-win, so
		# the previous "JACKS OR BETTER" row should fade out instead of
		# bleeding into the no-win view).
		_reset_paytable_highlight()


## Show / hide the "TRY AGAIN! PRESS DEAL" pill on a losing round.
## Same pop-in animation as the win pill so visual rhythm matches.
## Auto-hides the win pill if both somehow ended up shown together.
func _show_lose_name_pill(show: bool) -> void:
	if _lose_name_label == null:
		return
	if show:
		# Win pill first — never both visible at once.
		if _win_name_label != null and _win_name_label.visible:
			_win_name_label.visible = false
			_stop_pill_blink(_win_pill_blink_tw)
			_win_pill_blink_tw = null
	if not show:
		_lose_name_label.visible = false
		_lose_name_label.scale = Vector2.ONE
		_lose_name_label.modulate.a = 1.0
		_stop_pill_blink(_lose_pill_blink_tw)
		_lose_pill_blink_tw = null
		return
	_lose_name_label.visible = true
	_lose_name_label.scale = Vector2.ONE
	_lose_name_label.modulate.a = 1.0
	await get_tree().process_frame
	if not is_instance_valid(_lose_name_label):
		return
	_lose_name_label.pivot_offset = _lose_name_label.size * 0.5
	var tw := _lose_name_label.create_tween().set_parallel(true)
	tw.tween_property(_lose_name_label, "scale", Vector2(1.12, 1.12), 0.18) \
		.from(Vector2(0.7, 0.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_lose_name_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_lose_pill_blink_tw = _start_pill_blink(_lose_name_label, _lose_pill_blink_tw)


## Build the BBCode string for the lose pill from a localised template.
## Splits the translated phrase on "DEAL" so the word is highlighted in
## the same supercell red as the danger button — works in any language
## where the translator keeps "DEAL" verbatim (the in-game button is
## always called DEAL regardless of locale).
func _refresh_lose_name_label_text() -> void:
	if _lose_name_label == null:
		return
	var raw: String = Translations.tr_key("game.try_again_press_deal_plain")
	var parts: PackedStringArray = raw.split("DEAL")
	var bb := ""
	if parts.size() >= 2:
		bb = "[center]%s[color=#E63946]DEAL[/color]%s[/center]" % [parts[0], "DEAL".join(parts.slice(1))]
	else:
		bb = "[center]%s[/center]" % raw
	_lose_name_label.text = bb


## Toggle the winning-hand pill. The Label itself is the pill (it paints
## its own background + border via the "normal" stylebox), so we just
## flip its visibility and run a pop-in scale tween. Showing the win
## pill always hides the lose pill (and vice versa via _show_lose_name_pill).
func _show_win_name_pill(show: bool) -> void:
	if _win_name_label == null:
		return
	if show:
		_show_lose_name_pill(false)  # never both visible at once
	if not show:
		_win_name_label.visible = false
		_win_name_label.scale = Vector2.ONE
		_win_name_label.modulate.a = 1.0
		_stop_pill_blink(_win_pill_blink_tw)
		_win_pill_blink_tw = null
		return
	_win_name_label.visible = true
	_win_name_label.scale = Vector2.ONE
	_win_name_label.modulate.a = 1.0
	_win_pill_blink_tw = _start_pill_blink(_win_name_label, _win_pill_blink_tw)


## Looping blink: 2.7s idle → 0.15s fade modulate.a 1.0 → 0.2 → 0.15s
## back to 1.0, repeat. Returns the new tween so the caller can store
## it and cancel later via _stop_pill_blink.
func _start_pill_blink(node: CanvasItem, prev: Tween) -> Tween:
	_stop_pill_blink(prev)
	if not is_instance_valid(node):
		return null
	var tw := node.create_tween().set_loops()
	tw.tween_interval(2.7)
	tw.tween_property(node, "modulate:a", 0.2, 0.15)
	tw.tween_property(node, "modulate:a", 1.0, 0.15)
	return tw


func _stop_pill_blink(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


## Sets the WIN label into active mode: gold amount with "WIN" prefix.
## Called from _on_cards_dealt (amount=0) and _on_hand_evaluated via
## _animate_win_increment.
func _set_win_active(amount: int) -> void:
	if _last_label == null or _win_label == null:
		return
	_last_label.text = Translations.tr_key("game.win_label")
	_last_label.add_theme_color_override("font_color", Color.WHITE)
	_last_label.modulate.a = 1.0
	_win_label.text = str(amount)
	_win_label.add_theme_color_override("font_color", Color("F2D62E"))
	_win_label.modulate.a = 1.0


## Sets the WIN label into dim/last-round mode: muted amount with
## "LAST WIN" prefix. Used after a losing hand and on IDLE.
func _set_win_dimmed() -> void:
	_stop_win_increment()
	if _last_label == null or _win_label == null:
		return
	_last_label.text = Translations.tr_key("game.last_win_label")
	_last_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
	_last_label.modulate.a = 0.7
	_win_label.text = str(_last_win_amount)
	_win_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
	_win_label.modulate.a = 0.7


## Animate a rolling integer from `from` → `to` on _win_label over 2s.
## Classic-parity timing + ease-out. Cancels any prior counter tween so
## rapid consecutive wins don't jitter.
func _animate_win_increment(from: int, to: int) -> void:
	_stop_win_increment()
	_set_win_active(from)
	if from == to:
		return
	_win_increment_tween = create_tween()
	var dur: float = ConfigManager.get_animation("win_counter_single_ms", 2000.0) / 1000.0
	_win_increment_tween.tween_method(func(val: int) -> void:
		if _win_label != null:
			_win_label.text = str(val)
	, from, to, dur).set_ease(Tween.EASE_OUT)


func _stop_win_increment() -> void:
	if _win_increment_tween:
		_win_increment_tween.kill()
		_win_increment_tween = null


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


var _balance_display_value: int = -1
var _balance_tween: Tween = null
## Unix-ms timestamp at which the chip cascade's first chip is expected
## to land on the balance pill. Until then `_on_credits_changed` defers
## the balance roll-up so the number doesn't tick before the chips
## visually arrive. Set by `_spawn_chip_cascade_to_balance`, consumed
## (zeroed) once the increment runs.
var _balance_hold_until_ms: int = 0

func _on_credits_changed(new_credits: int) -> void:
	if _balance_label == null:
		return
	# First paint — don't animate, just snap to the initial value.
	if _balance_display_value < 0:
		_balance_display_value = new_credits
		_balance_label.text = SaveManager.format_money(new_credits)
		return
	if new_credits == _balance_display_value:
		return
	# Spending (e.g. paying for the next round) is instantaneous — no
	# animation, no hold; the player should never wait to see they've
	# been charged. Increments still roll up + can be deferred behind
	# the chip cascade.
	if new_credits < _balance_display_value:
		if _balance_tween and _balance_tween.is_running():
			_balance_tween.kill()
			# `.kill()` cancels the tween_callback that would have stopped
			# the looped balance SFX — stop it explicitly here, otherwise
			# the coin-count loop plays forever (e.g. after entering the
			# Double sub-game, which deducts the wager via this path).
			SoundManager.stop_sfx_loop_if("balance_increment")
		_balance_display_value = new_credits
		_balance_label.text = SaveManager.format_money(new_credits)
		_balance_hold_until_ms = 0
		return
	# GameManager emits `credits_changed` BEFORE `hand_evaluated`, so on
	# a winning round we get here before _spawn_chip_cascade_to_balance
	# has had a chance to set _balance_hold_until_ms. Yield one frame so
	# hand_evaluated → cascade can run, then read the hold deadline.
	await get_tree().process_frame
	if _balance_label == null or not is_instance_valid(_balance_label):
		return
	var hold_ms: int = _balance_hold_until_ms - Time.get_ticks_msec()
	if hold_ms > 0:
		_balance_hold_until_ms = 0  # consume — only one defer per cascade
		await get_tree().create_timer(hold_ms / 1000.0).timeout
		# After the wait the player may have already moved on; bail if
		# the balance label was disposed mid-animation.
		if _balance_label == null or not is_instance_valid(_balance_label):
			return
	_run_balance_roll_up(new_credits)


## Roll-up/down the balance label. Pulled out of `_on_credits_changed`
## so the deferred (post-cascade) path can call the same code.
## Duration scales with delta and is 1.5× longer than the original
## increment so the count-up reads as a deliberate reward.
func _run_balance_roll_up(new_credits: int) -> void:
	var from_val: int = _balance_display_value
	var to_val: int = new_credits
	var delta: int = absi(to_val - from_val)
	var ref: float = maxf(1.0, float(maxi(absi(from_val), absi(to_val))))
	var ratio: float = clampf(float(delta) / ref, 0.0, 1.0)
	var dur: float = lerpf(0.375, 1.8, ratio)  # 1.5× the previous 0.25..1.2
	if _balance_tween and _balance_tween.is_running():
		_balance_tween.kill()
		# Killing the tween skips its tween_callback — stop the existing
		# loop before starting a fresh one so we don't leave the SFX
		# playing if the new tween is also killed before it finishes.
		SoundManager.stop_sfx_loop_if("balance_increment")
	SoundManager.play_sfx_loop("balance_increment")
	_balance_tween = create_tween()
	_balance_tween.tween_method(func(v: int) -> void:
		_balance_display_value = v
		if _balance_label != null:
			_balance_label.text = SaveManager.format_money(v)
	, from_val, to_val, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_balance_tween.tween_callback(func() -> void: SoundManager.stop_sfx_loop_if("balance_increment"))


func _on_bet_changed(_new_bet: int) -> void:
	_refresh_bet_display()
	_rebuild_paytable_rows()


func _refresh_bet_display() -> void:
	if _game_manager == null:
		return
	# Supercell: bet level is locked at 1; the wager per round is the
	# denomination, which is shown inline on the COINS picker button.
	_refresh_denom_label_text()


## Re-applies the auto-shortened denom string on the COINS button. Hooked
## both to `_refresh_bet_display` (denom changes) and the button's
## `resized` signal (initial layout / orientation change), so the label
## always picks the right format for the current button width.
func _refresh_denom_label_text() -> void:
	if _denom_lab == null:
		return
	_denom_lab.text = _format_denom_for_button(SaveManager.denomination)


## Picks the display string for the COINS picker button. Defaults to the
## comma-grouped full format (e.g. "1,000"), but switches to the short
## "K/M" notation when the rendered full string wouldn't fit inside the
## available space on the button — keeps "20,000" from clipping under
## the chip glyph at high denominations.
func _format_denom_for_button(value: int) -> String:
	var full: String = SaveManager.format_money(value)
	if _denom_btn == null or _denom_lab == null:
		return full
	var font: Font = _denom_lab.get_theme_font("font")
	if font == null:
		return full
	var font_size: int = _denom_lab.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 22
	var btn_w: float = _denom_btn.size.x
	if btn_w <= 0.0:
		# Layout hasn't run yet — fall back to a numeric heuristic so the
		# initial render isn't stuck on the full string when it can't fit.
		# Threshold matched to what visibly fits inside the 180px slot at
		# the supercell font/size; the resize hook re-measures shortly
		# after with the real font and corrects if needed.
		return full if value < 1000 else SaveManager.format_short(value)
	var prefix_w: float = 0.0
	if _coins_prefix_lab != null:
		var pf: Font = _coins_prefix_lab.get_theme_font("font")
		var ps: int = _coins_prefix_lab.get_theme_font_size("font_size")
		if ps <= 0:
			ps = 22
		if pf != null:
			prefix_w = pf.get_string_size(_coins_prefix_lab.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x
	# Subtract: prefix label, chip glyph (40), 4+2 separations, ~16px button
	# padding margin so we don't ride the very edge.
	var available: float = btn_w - prefix_w - 40.0 - 6.0 - 16.0
	var full_w: float = font.get_string_size(full,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if full_w <= available:
		return full
	return SaveManager.format_short(value)
	# Hidden BET LEVEL placeholder still gets a sensible string in case
	# debug toggles its visibility.
	if _bet_lvl_btn != null:
		_bet_lvl_btn.text = "BET LVL %d" % _game_manager.bet


func _refresh_speed_label() -> void:
	if _speed_btn != null:
		_speed_btn.text = "SPEED %d" % (_speed_level + 1)


func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if _animating:
		return
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# In double-or-nothing the player picks one of cards 1..4 to compare
	# against the dealer card on slot 0 — handle that branch first.
	if _in_double:
		_on_double_card_picked(idx)
		return
	if _game_manager.state != GameManager.State.HOLDING:
		return
	_game_manager.toggle_hold(idx)
	_apply_hold_visual(idx)
	_play_card_press(idx)


## Balatro-style random tilt + classic HELD visuals. Held card tilts
## ±4..8 degrees, lifts 8px (done by CardVisual.set_held), and shows
## the golden border + HELD label from classic. Unhold returns to 0°.
func _apply_hold_visual(idx: int) -> void:
	if idx >= _cards.size():
		return
	var c: Control = _cards[idx]
	if not is_instance_valid(c):
		return
	var held: bool = _game_manager.held[idx]
	# Classic HELD label + golden border + lift live inside CardVisual.
	if c.has_method("set_held"):
		c.set_held(held)
	# Balatro tilt — random base angle per hold, reset on unhold.
	# Subtle 0.75–2° each way.
	var target_rot: float = 0.0
	if held:
		var sign: float = 1.0 if randf() > 0.5 else -1.0
		var deg: float = randf_range(0.75, 2.0) * sign
		target_rot = deg_to_rad(deg)
	_tween_card_rotation(c, target_rot, 0.22)
	# Balatro-style wobble: while held, the card breathes a tiny amount
	# around its base rotation forever. Released → kill the wobble and
	# the rotation tween above settles the card flat.
	if held:
		_start_card_wobble(c, target_rot)
	else:
		_stop_card_wobble(c)


## Helper: smooth rotation tween on a CardVisual, cancelling any prior
## tilt tween so rapid tap spam doesn't stack conflicting animations.
func _tween_card_rotation(c: Control, target: float, duration: float) -> void:
	if not is_instance_valid(c):
		return
	var prev: Tween = c.get_meta("tilt_tween", null)
	if prev != null and prev.is_running():
		prev.kill()
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "rotation", target, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta("tilt_tween", tw)


## Looping wobble — card jitters around its base tilt while held.
## Small amplitude (~1.2°) + short swing (~0.12s) gives a nervous,
## balatro-style micro-shake rather than a slow sway.
func _start_card_wobble(c: Control, base_rot: float) -> void:
	_stop_card_wobble(c)
	if not is_instance_valid(c):
		return
	var amp: float = deg_to_rad(1.2)
	var tw := c.create_tween().set_loops()
	# Random lead-in phase so a hand of held cards jitters out of sync.
	var phase: float = randf_range(0.05, 0.14)
	tw.tween_property(c, "rotation", base_rot + amp, phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", base_rot - amp, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", base_rot + amp, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	c.set_meta("wobble_tween", tw)


## Draw a thick rounded gold outline that hugs the card. Painted from
## a Control overlay parented to the card so tilt/scale transforms
## carry the glow with the card. Same color as the HELD border but
## without the HELD pill — used to mark cards inside the winning combo
## (whether they were held during DRAW or freshly drawn).
func _draw_winner_glow(g: Control) -> void:
	var rect := Rect2(Vector2.ZERO, g.size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.border_color = Color("FFCC2E")
	st.set_border_width_all(6)
	st.set_corner_radius_all(12)
	st.anti_aliasing = true
	st.draw(g.get_canvas_item(), rect)


## Toggle the winner-glow overlay on a single card slot. Fade in/out
## via modulate.a so the transition isn't a hard pop.
func _set_winner_glow(idx: int, on: bool) -> void:
	if idx < 0 or idx >= _winner_glows.size():
		return
	var g: Control = _winner_glows[idx]
	if not is_instance_valid(g):
		return
	# Make sure draw is current (size may have changed since init).
	g.queue_redraw()
	var prev: Tween = g.get_meta("glow_tween", null)
	if prev != null and prev.is_running():
		prev.kill()
	var target: float = 1.0 if on else 0.0
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", target, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	g.set_meta("glow_tween", tw)


## Highlight cards that form the winning combination. Combines the
## evaluator's hold mask (winning-hand cards) with the player's HELD
## state — held cards already have CardVisual's HELD overlay (gold
## border + HELD pill); cards that are part of the combo but weren't
## explicitly held get the same border via _winner_glow without the
## HELD pill.
func _highlight_winning_cards(rank: int) -> void:
	if _game_manager == null or _cards.is_empty():
		return
	if rank == HandEvaluator.HandRank.NOTHING:
		return
	var typed_hand: Array[CardData] = []
	for c in _game_manager.hand:
		typed_hand.append(c as CardData)
	var mask: Array[bool] = HandEvaluator.get_hold_mask(typed_hand, rank)
	for i in 5:
		if i >= mask.size():
			continue
		# Only show the standalone glow on cards that weren't explicitly
		# held — held cards already display CardVisual's gold border via
		# set_held(true) plus the HELD pill, so adding our overlay would
		# stack two outlines.
		var is_held: bool = i < _game_manager.held.size() and _game_manager.held[i]
		_set_winner_glow(i, mask[i] and not is_held)


## Drop every winner glow on a fresh deal so previous-round outlines
## don't bleed into the new hand.
func _clear_winner_glows() -> void:
	for i in _winner_glows.size():
		_set_winner_glow(i, false)


## Override CardVisual's HELD positioning for the supercell skin: pin the
## badge to TOP_WIDE so it's always centered horizontally regardless of
## texture aspect ratio. CardVisual's `resized` handler keeps re-running
## its own math; we disconnect it once and re-anchor the badge ourselves.
func _recenter_held_for_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var held: Control = card.get("_held_label")
	if held == null:
		return
	# Drop the texture-aware reposition listener so it can't override us.
	if card.resized.is_connected(card._reposition_held):
		card.resized.disconnect(card._reposition_held)
	held.set_anchors_preset(Control.PRESET_TOP_WIDE)
	held.offset_left = 0
	held.offset_right = 0
	held.offset_top = -2
	held.offset_bottom = 22
	held.size_flags_horizontal = Control.SIZE_FILL
	# Inner texture+label children of held already use PRESET_CENTER +
	# grow_both, so they auto-center in whatever rect we give them.


func _stop_card_wobble(c: Control) -> void:
	if not is_instance_valid(c):
		return
	var prev: Tween = c.get_meta("wobble_tween", null)
	if prev != null and prev.is_running():
		prev.kill()
	c.remove_meta("wobble_tween")


## Classic-parity card tap feedback — small scale pop + slight tilt on
## the tapped card. Resets after 150ms.
func _play_card_press(idx: int) -> void:
	if idx >= _cards.size():
		return
	var c: Control = _cards[idx]
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2(1.08, 1.08), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(c, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Classic-parity draw animation: flip non-held cards back, call
## game_manager.draw() for new cards, set them face-up with the same
## stagger, then advance FSM.
func _on_deal_draw_pressed() -> void:
	if _animating:
		return
	# If a double round is still active when the player taps DEAL, ignore
	# the press — they need to pick a card first or wait for the round to
	# wrap up.
	if _in_double:
		return
	VibrationManager.vibrate("button_press")
	if _game_manager.state == GameManager.State.HOLDING:
		# Lock the COINS picker visually the moment a real DRAW starts —
		# disabled + dim so the player sees they can't change denomination
		# until the result is announced. Re-enabled in `_on_hand_evaluated`.
		_set_denom_btn_locked(true)
		_animating = true
		var instant := _get_flip_s() < 0.03
		for i in 5:
			if not _game_manager.held[i]:
				_cards[i].set_flip_duration(_get_flip_s())
				_cards[i].flip_to_back()  # SFX inside CardVisual
				VibrationManager.vibrate("card_flip")
				if not instant:
					await get_tree().create_timer(_get_draw_ms() / 1000.0).timeout
		if not instant:
			await get_tree().create_timer(ConfigManager.get_animation("card_draw_delay_ms", 80.0) / 1000.0).timeout
		_game_manager.draw()
		for i in 5:
			if not _game_manager.held[i]:
				_cards[i].set_flip_duration(_get_flip_s())
				_cards[i].set_card(_game_manager.hand[i], true, _variant.is_wild_card(_game_manager.hand[i]))  # SFX inside CardVisual
				VibrationManager.vibrate("card_deal")
				if not instant:
					await get_tree().create_timer(_get_draw_ms() / 1000.0).timeout
		if not instant:
			await get_tree().create_timer(_get_flip_s() * 2).timeout
		_animating = false
		if is_instance_valid(_game_manager):
			_game_manager.on_draw_animation_complete()
	else:
		# IDLE or WIN_DISPLAY — check affordability before dealing,
		# so the player never gets stuck with negative credits (classic-parity).
		var state2: int = _game_manager.state
		if state2 == GameManager.State.IDLE or state2 == GameManager.State.WIN_DISPLAY:
			var cost: int = _game_manager.bet * SaveManager.denomination
			if cost > SaveManager.credits:
				# Insufficient — bail BEFORE locking the COINS picker.
				# Otherwise the player closes the shop and finds the
				# denom button stuck disabled (no hand was ever started,
				# so `_on_hand_evaluated` won't fire to re-enable it).
				_flash_balance_red()
				if ShopOverlay and ConfigManager.is_feature_enabled("auto_shop_on_low_balance", true):
					ShopOverlay.show(self)
				return
		# Deal will start — lock the COINS picker now.
		_set_denom_btn_locked(true)
		_game_manager.deal_or_draw()


## Briefly modulate the balance label red when the player tries to
## DEAL without enough credits. Same feedback as classic.
func _flash_balance_red() -> void:
	if _balance_label == null:
		return
	var tw := _balance_label.create_tween()
	tw.tween_property(_balance_label, "modulate", Color(1, 0.3, 0.3), 0.15)
	tw.tween_property(_balance_label, "modulate", Color.WHITE, 0.15)
	tw.tween_property(_balance_label, "modulate", Color(1, 0.3, 0.3), 0.15)
	tw.tween_property(_balance_label, "modulate", Color.WHITE, 0.15)


## Flash the balance label yellow + bumped brightness for 4 pulses.
## Used on a payout >0 to draw the eye to the new credits.
func _flash_balance_win() -> void:
	if _balance_label == null:
		return
	var tw := _balance_label.create_tween()
	for i in 3:
		tw.tween_property(_balance_label, "modulate", Color(1.6, 1.5, 0.7), 0.13)
		tw.tween_property(_balance_label, "modulate", Color.WHITE, 0.13)


func _on_max_bet_pressed() -> void:
	# No-op in supercell — bet level is locked at 1; the MAX BET button
	# is hidden but the callback stays connected to the (invisible)
	# placeholder, so we explicitly do nothing here.
	pass


func _on_speed_pressed() -> void:
	_speed_level = (_speed_level + 1) % SPEED_CONFIGS.size()
	SaveManager.speed_level = _speed_level
	SaveManager.save_game()
	_refresh_speed_label()


## Double-or-nothing flow — supercell-skinned port of classic game.gd's
## logic. Player risks the most recent payout to either double it (pick a
## card higher than the dealer) or lose it. Triggered from the DOUBLE
## button which is enabled only in WIN_DISPLAY with payout > 0.
var _double_overlay: Control = null
var _double_cards: Array = []  # 5 CardData
var _double_dealer_card: CardData = null
var _in_double: bool = false
var _double_warned: bool = false
var _double_amount: int = 0
# True between the first card pick and the result reveal — guards
# `_on_double_card_picked` from running twice when the player taps a
# second face-down card before the 0.5s reveal timer elapses.
var _double_picking: bool = false


func _on_double_pressed() -> void:
	# Wager pool is preserved as state — `_on_hand_evaluated` seeds it on
	# a fresh draw, and the WIN branch of `_on_double_card_picked` doubles
	# it on every successful round. Reading from it here means consecutive
	# DOUBLE presses correctly risk the accumulated amount (X → 2X → 4X…).
	if _double_amount <= 0:
		return
	if not _double_warned:
		_show_double_warning()
	else:
		_start_double()


func _show_double_warning() -> void:
	_double_overlay = Control.new()
	_double_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_double_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_double_overlay.z_index = 50
	add_child(_double_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = ThemeManager.popup_dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_double_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeManager.make_popup_stylebox())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	_double_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("double.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.style_popup_title(title, 28)
	vbox.add_child(title)

	var doubled := _double_amount * 2
	var msg_parts: Array = Translations.tr_key("double.msg_fmt",
			["<<WIN>>", "<<DBL>>"]).split("\n")
	var msg_box := VBoxContainer.new()
	msg_box.add_theme_constant_override("separation", 4)
	for line_text in msg_parts:
		var line_hbox := HBoxContainer.new()
		line_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		line_hbox.add_theme_constant_override("separation", 4)
		var token: String = ""
		var amount: int = 0
		if "<<WIN>>" in line_text:
			token = "<<WIN>>"
			amount = _double_amount
		elif "<<DBL>>" in line_text:
			token = "<<DBL>>"
			amount = doubled
		if token != "":
			var parts: PackedStringArray = line_text.split(token)
			if parts[0] != "":
				var lbl := Label.new()
				lbl.text = parts[0]
				ThemeManager.style_popup_body(lbl, 20)
				line_hbox.add_child(lbl)
			var cd := SaveManager.create_currency_display(20, Color.WHITE)
			SaveManager.set_currency_value(cd, SaveManager.format_money(amount))
			line_hbox.add_child(cd["box"])
			if parts.size() > 1 and parts[1] != "":
				var lbl := Label.new()
				lbl.text = parts[1]
				ThemeManager.style_popup_body(lbl, 20)
				line_hbox.add_child(lbl)
		else:
			var lbl := Label.new()
			lbl.text = line_text
			ThemeManager.style_popup_body(lbl, 20)
			line_hbox.add_child(lbl)
		msg_box.add_child(line_hbox)
	vbox.add_child(msg_box)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 20)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)

	var no_btn := _make_flat_btn(
		ThemeManager.color("button_secondary_bg", Color("452C82")),
		ThemeManager.color("button_secondary_border", Color("0A2915")),
		Translations.tr_key("common.no"),
		Color.WHITE, 22)
	no_btn.custom_minimum_size = Vector2(140, 60)
	no_btn.pressed.connect(func() -> void: _hide_double_overlay())
	btns.add_child(no_btn)

	var yes_btn := _make_flat_btn(
		ThemeManager.color("button_primary_bg", Color("FFCC2E")),
		ThemeManager.color("button_primary_border", Color("152033")),
		Translations.tr_key("common.yes"),
		ThemeManager.color("button_primary_text", Color("2A1F00")), 22)
	yes_btn.custom_minimum_size = Vector2(140, 60)
	yes_btn.pressed.connect(func() -> void:
		_double_warned = true
		_hide_double_overlay()
		_start_double()
	)
	btns.add_child(yes_btn)


func _start_double() -> void:
	_in_double = true
	_double_picking = false
	_double_btn.disabled = true
	_draw_btn.disabled = true
	# Player is now risking the win — keep the COINS picker locked + dim
	# until Double resolves (lose/tie/take-win → `_end_double`, or WIN
	# branch which clears `_in_double` and re-enables via `_set_...(false)`).
	_set_denom_btn_locked(true)

	# Risk the win: deduct the amount from balance. Mirrors classic
	# `game.gd:_start_double` — balance rolls back to its pre-draw level.
	# `SaveManager.deduct_credits` doesn't emit `credits_changed` (only
	# `GameManager` wraps it with the signal), so trigger the balance
	# label update by hand. Without this the displayed balance stays at
	# the post-draw level even though the actual `SaveManager.credits`
	# already dropped — exactly the bug shown in the bug report.
	SaveManager.deduct_credits(_double_amount)
	_on_credits_changed(SaveManager.credits)

	# Reset every leftover UI marker from the just-finished hand: the
	# winning-combo pill (e.g. "TWO PAIR"), the gold-outlined winner card
	# glows, the sticky paytable highlight, and any hint bubble. Without
	# these the screenshot showed the previous round's "TWO PAIR" badge
	# bleeding into the double-pick view.
	_show_win_name_pill(false)
	_show_lose_name_pill(false)
	_clear_winner_glows()
	_reset_paytable_highlight()
	_hide_hint_bubble()
	# WIN label rolls down to 0 — the wager is now at risk, not banked.
	_set_win_active(0)

	# Fresh 52-card deck, no jokers / wilds.
	var deck := Deck.new(52)
	_double_cards = deck.deal_hand()
	_double_dealer_card = _double_cards[0]

	_set_status(Translations.tr_key("double.pick_card"))

	# Dealer card face-up, 4 player cards animated face-down then
	# interactive. `flip_to_back()` plays a flip animation when the card
	# was face-up (covers winning hand cards), `show_back()` snaps the
	# rest to back instantly. set_interactive only changes the cursor —
	# the click guard is `_double_picking` (see `_on_double_card_picked`).
	for i in 5:
		if i >= _cards.size():
			continue
		var cv: Control = _cards[i]
		cv.set_flip_duration(ConfigManager.get_animation("double_card_flip_ms", 150.0) / 1000.0)
		cv.set_held(false)
		_stop_card_wobble(cv)
		_tween_card_rotation(cv, 0.0, 0.18)
		if i == 0:
			# Dealer slot — overwrite whatever was there with the
			# revealed dealer card (the flip-in animation handles the
			# transition from previous content).
			cv.set_card(_double_cards[i], true)
			cv.set_interactive(false)
		else:
			# Player picks: animate flip to back if the card is showing
			# its face, else just snap to back.
			if cv.face_up:
				cv.flip_to_back()
			else:
				cv.show_back()
			cv.set_interactive(true)


## Patched card click — when in double round, treat the click as a card
## pick rather than a HOLD toggle. Outside of double, normal HOLD logic.
func _on_double_card_picked(index: int) -> void:
	# Guard against rapid double-tap or a second face-down card being
	# clicked during the 0.5s reveal window — without this, two cards
	# could get flipped and the resolution would run twice (the bug shown
	# in the screenshot where two 7s ended up face-up).
	if _double_picking:
		return
	if index == 0:
		return  # dealer card
	if index >= _double_cards.size():
		return
	_double_picking = true
	for i in 5:
		if i < _cards.size():
			_cards[i].set_interactive(false)

	var card: CardData = _double_cards[index]
	_cards[index].set_card(card, true)
	await get_tree().create_timer(ConfigManager.get_animation("post_win_pause_sec", 0.5)).timeout

	var player_rank: int = card.rank as int
	var dealer_rank: int = _double_dealer_card.rank as int

	if player_rank > dealer_rank:
		_double_amount *= 2
		SoundManager.play("double_win")
		VibrationManager.vibrate("double_win")
		SaveManager.add_credits(_double_amount)
		_on_credits_changed(SaveManager.credits)
		# Sync the displayed WIN value to the new accumulated amount so
		# the player can read what's at stake before pressing DOUBLE
		# again or DEAL.
		_last_win_amount = _double_amount
		_set_win_active(_double_amount)
		_set_status(Translations.tr_key("double.win_doubled_fmt",
				[SaveManager.format_money(_double_amount)]))
		await get_tree().create_timer(0.4).timeout
		_double_btn.disabled = false
		_draw_btn.disabled = false
		# Keep `_double_picking = true` so the 3 remaining face-down cards
		# stay locked until the next `_start_double()` (which resets the
		# gate). Otherwise a tap on another face-down card would re-enter
		# resolution and double-pay the round.
		# Exit the double-routing mode so DEAL works again — without this
		# `_on_deal_draw_pressed` early-returns on `if _in_double` and the
		# player is stuck choosing between DOUBLE-again and a dead DEAL.
		# `_start_double()` re-asserts the flag if the player risks again.
		_in_double = false
		# Win banked → COINS picker can be tweaked before next DEAL.
		_set_denom_btn_locked(false)
	elif player_rank == dealer_rank:
		# Tie = PUSH (IGT Game King). Refund the wager to balance and
		# restore the WIN label to the at-risk amount so the player sees
		# what's available to risk again. Re-enable DOUBLE + DEAL so the
		# player chooses: another Double round or collect. `_in_double`
		# is cleared so DEAL routes correctly through the normal path.
		# `_double_picking` stays true so leftover face-down cards on
		# screen don't react to taps until the next `_start_double()`.
		SaveManager.add_credits(_double_amount)
		_on_credits_changed(SaveManager.credits)
		_set_status(Translations.tr_key("double.tie"))
		_last_win_amount = _double_amount
		_set_win_active(_double_amount)
		await get_tree().create_timer(0.4).timeout
		_double_btn.disabled = false
		_draw_btn.disabled = false
		_in_double = false
		_set_denom_btn_locked(false)
	else:
		SoundManager.play("double_lose")
		VibrationManager.vibrate("double_lose")
		_set_status(Translations.tr_key("double.lose"))
		_double_amount = 0
		# Do NOT reset `_double_picking = false` here — `_end_double`
		# awaits 1.0s before clearing `_in_double`, and during that
		# window the 3 untouched face-down cards would still route
		# clicks through `_on_double_card_picked` (the `_in_double` gate
		# is still on). Leaving the pick-lock on prevents the bug where
		# a tap on another face-down card after LOSE flipped a second
		# card and re-ran resolution. Flag is reset by the next
		# `_start_double()` if the player risks again.
		_end_double()


func _end_double() -> void:
	await get_tree().create_timer(1.0).timeout
	_double_btn.disabled = true
	_draw_btn.disabled = false
	_in_double = false
	# Round fully resolved (lose / tie-then-fold / forfeit) — restore
	# the COINS picker so the next round can use a different denom.
	_set_denom_btn_locked(false)


# Re-deal the 4 player face-down cards on a TIE so the round becomes a
# push. Dealer card (slot 0) stays — only the picks reshuffle.
func _reshuffle_double_player_cards() -> void:
	var deck := Deck.new(52)
	var fresh: Array = deck.deal_hand()
	for i in range(1, 5):
		if i >= _cards.size():
			continue
		_double_cards[i] = fresh[i]
		var cv: Control = _cards[i]
		cv.set_flip_duration(ConfigManager.get_animation("double_card_flip_ms", 150.0) / 1000.0)
		if cv.face_up:
			cv.flip_to_back()
		else:
			cv.show_back()
		cv.set_interactive(true)
	_set_status(Translations.tr_key("double.pick_card"))


func _hide_double_overlay() -> void:
	if _double_overlay:
		_double_overlay.queue_free()
		_double_overlay = null


## Opens a simple BET LVL picker popup (1..5). Selecting a level sets
## game_manager.bet and refreshes the paytable highlight column.
func _on_bet_lvl_pressed() -> void:
	if _animating:
		return
	if _is_bet_locked():
		return
	_show_picker("BET LEVEL", [1, 2, 3, 4, 5], _game_manager.bet, func(v: int) -> void:
		# Defense in depth: refuse if state changed while picker was open.
		if _is_bet_locked():
			return
		while _game_manager.bet != v:
			_game_manager.bet_one()
			if _game_manager.bet >= 5 and v == 5:
				break
	)


# Visually lock/unlock the COINS picker. `disabled` blocks the press,
# `modulate.a` dims the button so the player sees the change. Called
# from DEAL/DRAW press, hand-evaluated callback, Double start/end.
func _set_denom_btn_locked(locked: bool) -> void:
	if _denom_btn == null or not is_instance_valid(_denom_btn):
		return
	_denom_btn.disabled = locked
	_denom_btn.modulate.a = 0.5 if locked else 1.0


# Single source of truth: bet/denomination cannot change during an active
# hand or while the Double sub-game is running. Mirrors the helper in
# classic single-hand `game.gd`.
func _is_bet_locked() -> bool:
	if _in_double:
		return true
	return _game_manager.state != GameManager.State.IDLE \
		and _game_manager.state != GameManager.State.WIN_DISPLAY


## Denomination picker — sets SaveManager.denomination to the chosen
## value, then rebuilds paytable + bet pill. Denom list is pulled from
## balance.json so it's consistent with classic / multi-hand modes.
func _on_denom_pressed() -> void:
	if _animating:
		return
	if _is_bet_locked():
		return
	var denoms: Array = ConfigManager.get_denominations("single_play")
	if denoms.is_empty():
		denoms = [1, 5, 25, 100, 500]
	_show_picker(Translations.tr_key("game.select_coins_amount"), denoms, SaveManager.denomination, func(v: int) -> void:
		# Defense in depth: refuse if state changed while picker was open.
		if _is_bet_locked():
			return
		var prev: int = SaveManager.denomination
		SaveManager.denomination = v
		SaveManager.save_game()
		_refresh_bet_display()
		# Animate payouts up (or snap down) instead of rebuilding rows so
		# the player sees the chip values rolling to the new amount.
		_refresh_paytable_payouts(prev, v)
	)


## Info popup — lists the current variant's paytable rules. Uses the
## shared theme popup styling so visual chrome follows the active skin.
func _on_info_pressed() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = ThemeManager.popup_dim_color()
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	# Width = 80% of viewport (Bug 16). Centered via FULL_RECT + offsets
	# so it scales with portrait/landscape and tablet layouts. Min height
	# preserved from the previous fixed-520 design so short content still
	# reads as a deliberate dialog, not a thin strip.
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vp_size: Vector2 = get_viewport_rect().size
	var panel_w: float = vp_size.x * 0.8
	var panel_h: float = maxf(520.0, vp_size.y * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", ThemeManager.make_popup_stylebox())
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = _variant_title()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Title bumped 28→34 (Bug 8: info text too small to read on iPhone).
	ThemeManager.style_popup_title(title, 34)
	vb.add_child(title)
	var mini: String = Translations.tr_key("machine.%s.mini" % SaveManager.last_variant)
	if not mini.begins_with("machine.") and mini != "":
		var desc := Label.new()
		desc.text = mini
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Body bumped 15→19 per Phase 7 spec (~3-4px increase).
		ThemeManager.style_popup_body(desc, 19)
		vb.add_child(desc)
	_append_trainer_disclaimer(vb)


## Append the "this is a trainer, not a casino" disclaimer to a popup's
## VBoxContainer. Each information panel in the supercell skin must show
## it so the App Store reviewer (and the player) sees the framing
## consistently. Adds a thin spacer + an italic-styled body block.
func _append_trainer_disclaimer(parent: VBoxContainer) -> void:
	if parent == null:
		return
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)
	var lab := Label.new()
	lab.text = Translations.tr_key("trainer.disclaimer")
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Disclaimer bumped 13→16 alongside body bump (Bug 8).
	ThemeManager.style_popup_body(lab, 16)
	# Slightly dim so the disclaimer reads as supplementary info, not body.
	lab.modulate = Color(1, 1, 1, 0.78)
	parent.add_child(lab)


## Generic two-column picker (title + N option buttons) used by BET
## LVL and DENOMINATION. Uses the theme popup stylebox so visual
## chrome follows the skin automatically.
func _show_picker(title_text: String, options: Array, current: int, on_pick: Callable) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = ThemeManager.popup_dim_color()
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", ThemeManager.make_popup_stylebox())
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.style_popup_title(title, 24)
	vb.add_child(title)

	# 2-column grid (4 rows for 8 denoms). Stretches both children equal.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)

	for opt in options:
		var val: int = int(opt)
		var is_selected: bool = val == current
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Strip default Button paint — the PNG (or fallback flat plate)
		# carries the entire visual.
		var empty_st := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_st)
		btn.add_theme_stylebox_override("hover", empty_st)
		btn.add_theme_stylebox_override("pressed", empty_st)
		btn.add_theme_stylebox_override("focus", empty_st)
		_apply_coin_picker_skin(btn, val, is_selected)
		btn.pressed.connect(func() -> void:
			on_pick.call(val)
			overlay.queue_free()
		)
		var row_hb := HBoxContainer.new()
		row_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		row_hb.add_theme_constant_override("separation", 8)
		row_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(row_hb)
		var coin := _make_coin_glyph(28)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hb.add_child(coin)
		var num := Label.new()
		num.text = str(val)
		num.add_theme_font_size_override("font_size", 22)
		# Selected option contrasts with the highlighted plate — flip
		# text to the dark popup-bg color so it reads on yellow.
		num.add_theme_color_override("font_color",
			Color("2B1C48") if is_selected else Color.WHITE)
		num.add_theme_font_override("font", ThemeManager.font())
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hb.add_child(num)
		_add_press_effect(btn)
		grid.add_child(btn)


## Resolve the artwork for a single picker button.
##
## File-naming convention (drop PNGs in `assets/themes/supercell/controls/`):
##   btn_coin_<value>.png             — per-denom plate, e.g. btn_coin_5.png
##   btn_coin_<value>_selected.png    — per-denom highlighted plate
##   btn_coin.png                     — generic plate (fallback for any value)
##   btn_coin_selected.png            — generic highlighted plate
## When neither selected nor generic-selected is found, the plain plate
## is reused with a brightening modulate so the player still sees which
## bet is active. When even the regular plate is missing, the function
## falls back to a procedural sticker matching the rest of the bottom-bar.
func _apply_coin_picker_skin(btn: Button, value: int, selected: bool) -> void:
	var folder := ThemeManager.theme_folder() + "controls/"
	var per_value := folder + "btn_coin_%d.png" % value
	var per_value_sel := folder + "btn_coin_%d_selected.png" % value
	var generic := folder + "btn_coin.png"
	var generic_sel := folder + "btn_coin_selected.png"

	var chosen := ""
	if selected:
		# Try most-specific selected → generic selected → most-specific
		# normal → generic normal. Player can drop in only the bits they
		# have authored and the rest still renders.
		for path in [per_value_sel, generic_sel, per_value, generic]:
			if ResourceLoader.exists(path):
				chosen = path
				break
	else:
		for path in [per_value, generic]:
			if ResourceLoader.exists(path):
				chosen = path
				break

	if chosen != "":
		var tex_st := StyleBoxTexture.new()
		tex_st.texture = load(chosen)
		tex_st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		tex_st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		btn.add_theme_stylebox_override("normal", tex_st)
		btn.add_theme_stylebox_override("hover", tex_st)
		btn.add_theme_stylebox_override("pressed", tex_st)
		btn.add_theme_stylebox_override("focus", tex_st)
		# If we had to reuse the regular plate for a selected button,
		# brighten it so the active state is still visually distinct.
		if selected and chosen in [per_value, generic]:
			btn.modulate = Color(1.25, 1.20, 0.75)
		return

	# No assets at all — fall back to the procedural BET_LVL plate so
	# the picker still works visually before custom art ships.
	var fill: Color = Color("FFCC2E") if selected else BET_LVL_BG
	var outline := Color("2A1708")
	var flat_st := StyleBoxFlat.new()
	flat_st.bg_color = fill
	flat_st.set_corner_radius_all(16)
	flat_st.set_border_width_all(4)
	flat_st.border_color = outline
	flat_st.anti_aliasing = true
	flat_st.shadow_color = Color(0, 0, 0, 0.5)
	flat_st.shadow_size = 2
	flat_st.shadow_offset = Vector2(0, 6)
	btn.add_theme_stylebox_override("normal", flat_st)
	btn.add_theme_stylebox_override("hover", flat_st)
	btn.add_theme_stylebox_override("pressed", flat_st)
	btn.add_theme_stylebox_override("focus", flat_st)
