extends PanelContainer

signal play_pressed(variant_id: String)
## Fires whenever the effective visible_rect() may have changed: after
## initial texture assignment and after apply_tile_size() resizes the
## tile. Lobby listens to keep the shimmer overlay aligned to the PNG.
signal visual_ready

var variant_id: String = ""
var locked: bool = false
var _bg_color: Color = Color(0.75, 0.12, 0.12)
var _icon_path: String = ""
var _rtp: float = 0.0
var _mini_info: String = ""

@onready var _icon_tex: TextureRect = %MachineIcon
@onready var _lock_overlay: ColorRect = %LockOverlay


func setup(p_variant_id: String, p_icon_path: String, p_color: Color, _p_accent: Color, p_rtp: float, p_mini_info: String, p_locked: bool = false) -> void:
	variant_id = p_variant_id
	locked = p_locked
	_bg_color = p_color
	_icon_path = p_icon_path
	_rtp = p_rtp
	_mini_info = p_mini_info

	if is_node_ready():
		_apply_setup(p_locked)
	else:
		ready.connect(func() -> void: _apply_setup(p_locked), CONNECT_ONE_SHOT)


func _apply_setup(p_locked: bool) -> void:
	# Start at ZERO so tiles contribute nothing to the grid's combined
	# minimum size — this prevents the SafeArea from pushing the footer
	# off-screen on short viewports. apply_tile_size() runs deferred from
	# lobby_manager and sets the actual computed dimensions.
	custom_minimum_size = Vector2.ZERO
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# clip_contents=false so StyleBoxFlat's downward drop shadow isn't
	# trimmed by the card's own rect. Labels clip themselves via
	# clip_text + anchored positioning, so no overflow risk remains.
	clip_contents = false

	# Decide display mode per-tile by PNG availability:
	#   - PNG exists in the active theme's machines/ folder → icon layout
	#     (transparent plate, TextureRect fills the card).
	#   - PNG missing → constructed text layout (colored plate + title +
	#     suits + RTP). This lets a theme ship partial machine art or
	#     omit it entirely and get a code-built fallback for free.
	# Coming-soon placeholder slot — flat grey tile, no machine layout,
	# no tap response. Appended by lobby_manager at the end of every mode's
	# configs so players read the line-up as expanding rather than fixed.
	if variant_id == "_coming_soon":
		_build_coming_soon_tile()
		_icon_tex.visible = false
		_lock_overlay.visible = false
		visual_ready.emit()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	var has_png: bool = _icon_path != "" and ResourceLoader.exists(_icon_path)
	if has_png:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_icon_tex.visible = true
		_icon_tex.texture = load(_icon_path)
		# Shader-driven shimmer that samples the PNG alpha — glare stays
		# inside visible artwork and never crosses transparent padding.
		# Time uniform is driven from _process so the TextureRect always
		# redraws when the uniform changes (canvas_item TIME built-in
		# doesn't reliably trigger redraws on all platforms).
		_shimmer_mat = ShaderMaterial.new()
		_shimmer_mat.shader = load("res://shaders/tile_shimmer.gdshader")
		_icon_tex.material = _shimmer_mat
		_shimmer_t = 0.0
	else:
		_build_text_tile(p_locked)
		_icon_tex.visible = false
		_build_text_label()

	_lock_overlay.visible = p_locked
	# Texture may have just been assigned — let the lobby re-align the
	# shimmer rect to the PNG's actual visible area.
	visual_ready.emit()

	mouse_filter = Control.MOUSE_FILTER_PASS
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not p_locked else Control.CURSOR_ARROW


func _build_text_label() -> void:
	# Remove previously built text layout (e.g. after re-setup on theme switch).
	for child in get_children():
		if child.name == "TextLayout":
			child.queue_free()

	var theme_font: Font = ThemeManager.font()
	# Anchor-based container so suits + RTP stick to the bottom and
	# the title is pinned near the top regardless of card height.
	var layout := Control.new()
	layout.name = "TextLayout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	# ── Title block (top ~45%, below the outline's top edge) ──
	var title_wrap := VBoxContainer.new()
	title_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	title_wrap.add_theme_constant_override("separation", 2)
	title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Compact title band near the top third, leaving the rest for the
	# short label, suits pattern and the RTP pill.
	title_wrap.offset_top = 14
	title_wrap.offset_left = 14
	title_wrap.offset_right = -14
	title_wrap.anchor_bottom = 0.42
	title_wrap.offset_bottom = 0
	layout.add_child(title_wrap)

	var title := Label.new()
	# Theme-specific uppercase display title with explicit \n for 2-line
	# layout (e.g. "DBL DBL\nBONUS"). Falls back to translations name.
	var title_text: String = ThemeManager.machine_title(variant_id)
	if title_text == "":
		title_text = Translations.tr_key("machine.%s.name" % variant_id).to_upper()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Autowrap off — config provides the line breaks manually so font
	# sizing fits the widest line (see _fit_title_font_for_width).
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.max_lines_visible = 2
	title.clip_text = true
	title.add_theme_color_override("font_color", ThemeManager.color("title_text", Color.WHITE))
	title.add_theme_color_override("font_outline_color", ThemeManager.color("title_outline", Color(0, 0, 0, 1)))
	title.add_theme_constant_override("outline_size", 5)
	if theme_font != null:
		title.add_theme_font_override("font", theme_font)
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Emoji decoration on each side of the title, height = title row height.
	# Two Labels render emoji glyphs (system fallback fonts handle color
	# variants automatically); their font_size is recalculated on resize so
	# the glyph keeps tracking the title row height regardless of viewport.
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 6)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.add_child(title_row)
	var emoji_left: Control = _make_emoji_node(variant_id)
	var emoji_right: Control = _make_emoji_node(variant_id)
	title_row.add_child(emoji_left)
	title_row.add_child(title)
	title_row.add_child(emoji_right)
	_title_label = title
	_title_row = title_row
	_title_emojis = [emoji_left, emoji_right]
	var resize_emoji := func() -> void:
		var h: float = max(title_row.size.y, 16.0)
		var target: int = int(clamp(h * 0.55, 12.0, 36.0))
		_apply_emoji_size(emoji_left, target)
		_apply_emoji_size(emoji_right, target)
	title_row.resized.connect(resize_emoji)
	resize_emoji.call_deferred()
	_fit_title_font(title)

	# Short label directly under the title.
	var short_label: String = ThemeManager.machine_label(variant_id)
	if short_label != "":
		var sub := Label.new()
		sub.text = short_label
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub.clip_text = true
		sub.add_theme_font_size_override("font_size", 15)
		sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_wrap.add_child(sub)
		_sub_label = sub

	# ── Suits pattern (anchored above the RTP pill) ──
	# Theme-scoped SVG textures in assets/themes/<id>/icons/. If any
	# of the files are missing the row is skipped — caller falls back
	# to no suit decoration rather than showing a half-set.
	#
	# TODO (supercell thematic icons): swap this row for per-machine
	# icons once the assets land. Planned mapping (one icon per tile):
	#   jacks_or_better      → ♠ spade only
	#   bonus_poker_deluxe   → 4×4 grid icon
	#   double_double_bonus  → ⚡ lightning bolt
	#   aces_and_faces       → 👑 crown / "A"
	#   joker_poker          → joker hat / star
	#   bonus_poker          → 🎯 target
	#   double_bonus         → ×2 multiplier glyph
	#   triple_double_bonus  → 🔥 flame
	#   deuces_wild          → "2" inside a diamond
	#   deuces_and_joker     → 5 stars
	var suit_names := ["suit_spade", "suit_hearts", "suit_diamonds", "suit_clubs"]
	var suit_texs: Array = []
	var all_suits_present := true
	for sn in suit_names:
		var p := ThemeManager.ui_icon_path(sn)
		if p == "":
			all_suits_present = false
			break
		suit_texs.append(load(p))
	if all_suits_present:
		var suits := HBoxContainer.new()
		suits.alignment = BoxContainer.ALIGNMENT_CENTER
		# Tighter spacing so the 4 suit icons stay within the tile
		# interior, never crowding the outline.
		suits.add_theme_constant_override("separation", 10)
		suits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		suits.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		if ThemeManager.current_id == "supercell":
			# Supercell tiles host a stats panel above the suits row, so the
			# suits hug the bottom edge to free vertical space for the panel.
			suits.offset_top = -42
			suits.offset_bottom = -22
		else:
			suits.offset_top = -56
			suits.offset_bottom = -32
		layout.add_child(suits)
		# Suit icons take their tint from the per-machine bottom gradient
		# color so the row reads as a softer echo of the tile body — and
		# shrink to 75% size (20→15) to free room above the RTP pill.
		var grad: Array = ThemeManager.machine_gradient(variant_id)
		var suit_tint: Color = Color(0, 0, 0, 0.28)
		if grad.size() == 2:
			suit_tint = grad[1]
			suit_tint.a = 0.5
		for tex in suit_texs:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(15, 15)
			tr.modulate = suit_tint
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			suits.add_child(tr)

	# ── RTP pill (anchored to bottom edge) ──
	# Hidden under non-casino themes (trainer branding) — RTP is a gambling
	# concept and shouldn't show up anywhere the reviewer scans the lobby.
	var display_rtp: float = ThemeManager.machine_rtp(variant_id)
	if display_rtp <= 0.0:
		display_rtp = _rtp
	var _show_rtp_pill: bool = ThemeManager.current_id == "classic" \
		and ConfigManager.is_visible("show_rtp_in_machine_info", true)
	if _show_rtp_pill and display_rtp > 0.0:
		var rtp_row := HBoxContainer.new()
		rtp_row.alignment = BoxContainer.ALIGNMENT_CENTER
		rtp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtp_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		rtp_row.offset_top = -28
		rtp_row.offset_bottom = -6
		layout.add_child(rtp_row)
		var rtp_panel := PanelContainer.new()
		var rtp_style := StyleBoxFlat.new()
		rtp_style.bg_color = Color(0, 0, 0, 0.45)
		rtp_style.set_corner_radius_all(12)
		rtp_style.content_margin_left = 16
		rtp_style.content_margin_right = 16
		rtp_style.content_margin_top = 2
		rtp_style.content_margin_bottom = 2
		rtp_panel.add_theme_stylebox_override("panel", rtp_style)
		rtp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtp_row.add_child(rtp_panel)
		var rtp_lab := Label.new()
		rtp_lab.text = "%.2f%%" % display_rtp
		rtp_lab.add_theme_font_size_override("font_size", 16)
		rtp_lab.add_theme_color_override("font_color", Color("FFEC00"))
		rtp_lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		rtp_lab.add_theme_constant_override("outline_size", 2)
		if theme_font != null:
			rtp_lab.add_theme_font_override("font", theme_font)
		rtp_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtp_panel.add_child(rtp_lab)

	# Stats panel built unconditionally on supercell so the STATS toggle can
	# flip visibility without rebuilding the carousel. Visibility / subtitle
	# inversion is applied at the end via _apply_stats_visibility().
	if ThemeManager.current_id == "supercell":
		_build_stats_panel(layout, theme_font)
	_apply_stats_visibility(SaveManager.show_machine_stats)


## Renders the per-machine stats card (Best Combo + Score) used by the
## supercell lobby tile. Anchored to the bottom-wide region above the
## suits row. Reads SaveManager.get_machine_stats(variant_id); shows "—"
## when no win has been recorded yet.
func _build_stats_panel(layout: Control, theme_font: Font) -> void:
	var stats: Dictionary = SaveManager.get_machine_stats(SaveManager.mode_id, variant_id)
	var best_key: String = String(stats.get("best_key", ""))
	var score: int = int(stats.get("score", 0))
	var best_rank: int = int(stats.get("best_rank", 0))
	# "Big combo" threshold mirrors the game.gd win_large vibration cutoff —
	# Four of a Kind or higher on standard variants; wild-variant ranks
	# beyond FOUR_OF_A_KIND (5oak, four deuces, etc.) inherit the gold tint
	# automatically since their enum values are larger.
	var is_big_combo: bool = best_rank >= HandEvaluator.HandRank.FOUR_OF_A_KIND

	var grad: Array = ThemeManager.machine_gradient(variant_id)
	var base_col: Color = grad[1] if grad.size() == 2 else _bg_color
	var bg_col: Color = base_col.darkened(0.30)
	if is_big_combo:
		# Warm gold tint blended over the darkened machine color so the panel
		# still reads as part of the tile but pops as a "trophy" state.
		bg_col = bg_col.lerp(Color("C8A23A"), 0.55)
	bg_col.a = 0.9 if is_big_combo else 0.85

	var panel := PanelContainer.new()
	_stats_panel = panel
	panel.name = "StatsPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Proportional anchors so the panel scales with the tile and never crosses
	# into the title band (title sits at 0–0.42). User explicitly accepted that
	# the panel covers the suits row underneath when STATS toggle is ON.
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.44
	panel.anchor_bottom = 0.96
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = 0
	panel.offset_bottom = 0

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if is_big_combo:
		sb.set_border_width_all(2)
		sb.border_color = Color("FFD24A")
		sb.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", sb)
	layout.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(rows)

	var combo_value: String = "—"
	if best_key != "":
		var localized: String = Translations.tr_key("hand." + best_key)
		if localized != "" and localized != "hand." + best_key:
			combo_value = localized

	rows.add_child(_build_stats_label(Translations.tr_key("lobby.stats.best_combo"), HORIZONTAL_ALIGNMENT_LEFT, theme_font))
	rows.add_child(_build_stats_label(combo_value, HORIZONTAL_ALIGNMENT_RIGHT, theme_font))
	rows.add_child(_build_stats_label(Translations.tr_key("lobby.stats.score"), HORIZONTAL_ALIGNMENT_LEFT, theme_font))
	if score > 0:
		rows.add_child(_build_stats_score_row(score))
	else:
		rows.add_child(_build_stats_label("—", HORIZONTAL_ALIGNMENT_RIGHT, theme_font))


func _build_stats_label(text_value: String, align: int, theme_font: Font) -> Label:
	var lab := Label.new()
	lab.text = text_value
	lab.horizontal_alignment = align
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lab.add_theme_constant_override("outline_size", 3)
	if theme_font != null:
		lab.add_theme_font_override("font", theme_font)
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _build_stats_score_row(score: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cd: Dictionary = SaveManager.create_currency_display(16, Color(1, 1, 1, 1), Color(0, 0, 0, 0.85), 2.0)
	var box: HBoxContainer = cd["box"]
	box.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	SaveManager.set_currency_value(cd, SaveManager.format_short(score))
	return row


const _MACHINE_EMOJI := {
	"jacks_or_better": "✅",
	"bonus_poker": "🎯",
	"bonus_poker_deluxe": "💠",
	"double_bonus": "🎲",
	"double_double_bonus": "⚡",
	"triple_double_bonus": "🔥",
	"aces_and_faces": "👑",
	"deuces_wild": "💎",
	"joker_poker": "🃏",
	"deuces_and_joker": "⭐",
}


func _emoji_for(p_variant_id: String) -> String:
	return _MACHINE_EMOJI.get(p_variant_id, "♦")


## Returns a Control rendering the per-machine title emoji. Prefers a
## pre-rendered SVG (Twemoji-style) shipped under the active theme's
## icons folder so web/desktop builds don't depend on a system color
## emoji font; falls back to a plain Label glyph when the SVG is absent.
func _make_emoji_node(p_variant_id: String) -> Control:
	var svg_path: String = ThemeManager.ui_icon_path("title_emoji_" + p_variant_id)
	if svg_path != "" and ResourceLoader.exists(svg_path):
		var tr := TextureRect.new()
		tr.texture = load(svg_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.custom_minimum_size = Vector2(24, 24)
		return tr
	var lab := Label.new()
	lab.text = _emoji_for(p_variant_id)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.clip_text = false
	lab.add_theme_font_size_override("font_size", 24)
	return lab


func _apply_emoji_size(node: Control, target_px: int) -> void:
	if node is TextureRect:
		node.custom_minimum_size = Vector2(target_px, target_px)
	elif node is Label:
		(node as Label).add_theme_font_size_override("font_size", target_px)


## Coming-soon placeholder tile — same outline/shadow chrome as a real
## machine card so it visually belongs to the lineup, but body is flat
## desaturated grey (gradient-shader path reused with grey colors) and
## the centered "COMING SOON…" label replaces all variant-specific
## decorations.
func _build_coming_soon_tile() -> void:
	# Same chrome as a real machine tile — outline + shader gradient body +
	# downward drop shadow — but everything dimmed via modulate so the slot
	# reads as "ghost" / placeholder rather than active.
	var outer_radius: int = int(ThemeManager.size("tile_corner_radius", 22))
	var outline_width: float = float(ThemeManager.size("tile_outline_width", float(TILE_OUTLINE_WIDTH)))
	var shadow_offset: int = int(ThemeManager.size("tile_shadow_offset", float(TILE_SHADOW_OFFSET)))
	var shadow_col: Color = ThemeManager.color("tile_shadow_color", Color("0A0F20"))
	shadow_col.a *= 0.5

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0, 0, 0, 0)
	card_style.anti_aliasing = true
	card_style.set_corner_radius_all(outer_radius)
	card_style.set_border_width_all(0)
	card_style.shadow_size = 0
	card_style.shadow_color = Color(0, 0, 0, 0)
	card_style.content_margin_left = 0
	card_style.content_margin_right = 0
	card_style.content_margin_top = 0
	card_style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", card_style)
	_shadow_paint_offset = int(shadow_offset)
	_shadow_paint_color = shadow_col
	_shadow_paint_radius = int(outer_radius)
	queue_redraw()

	var top_col := Color(0.55, 0.57, 0.60)
	var bot_col := Color(0.36, 0.38, 0.41)
	var outline_col := Color(0.20, 0.22, 0.25)

	_gradient_rect = ColorRect.new()
	_gradient_rect.name = "GradientBg"
	_gradient_rect.color = Color(1, 1, 1, 1)
	_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gradient_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Half-alpha so the lobby background bleeds through and the slot reads
	# as "placeholder" rather than another machine.
	_gradient_rect.modulate = Color(1, 1, 1, 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tile_gradient.gdshader")
	mat.set_shader_parameter("top_color", top_col)
	mat.set_shader_parameter("bot_color", bot_col)
	mat.set_shader_parameter("outline_color", outline_col)
	mat.set_shader_parameter("outline_width", outline_width)
	mat.set_shader_parameter("corner_radius", float(outer_radius))
	mat.set_shader_parameter("highlight_color", Color(1, 1, 1, 0.18))
	mat.set_shader_parameter("highlight_thickness", 0.0)
	_gradient_rect.material = mat
	add_child(_gradient_rect)
	move_child(_gradient_rect, 0)
	_update_gradient_rect_size()
	resized.connect(_update_gradient_rect_size)

	var lab := Label.new()
	lab.name = "ComingSoonLabel"
	lab.text = Translations.tr_key("lobby.more_coming")
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.offset_left = 16
	lab.offset_right = -16
	lab.add_theme_font_size_override("font_size", 24)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	lab.add_theme_constant_override("outline_size", 3)
	var theme_font: Font = ThemeManager.font()
	if theme_font != null:
		lab.add_theme_font_override("font", theme_font)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab)


## Builds the supercell-style "sticker" tile: thick outline + solid
## downward shadow (drawn by StyleBoxFlat) + gradient body (drawn by
## ColorRect + tile_gradient.gdshader). Falls back to a flat _bg_color
## when the active theme doesn't declare a per-machine gradient.
# Default outline thickness — themes can override via `tile_outline_width`.
const TILE_OUTLINE_WIDTH := 2
# Default downward shadow offset — themes override via `tile_shadow_offset`.
const TILE_SHADOW_OFFSET := 8
const TILE_INNER_RADIUS := 18
const TILE_SHADOW_PAD := 10

var _gradient_rect: ColorRect = null
var _shadow_rect: ColorRect = null
# Hand-rolled drop shadow: a solid slab painted via _draw() below the
# panel rect, rather than StyleBoxFlat.shadow_* (whose `shadow_size`
# expands the halo uniformly on all sides). _draw() lets us paint the
# slab strictly downward, giving the supercell sticker look.
var _shadow_paint_offset: int = 0
var _shadow_paint_color: Color = Color(0, 0, 0, 0)
var _shadow_paint_radius: int = 0


func _build_text_tile(p_locked: bool) -> void:
	var outer_radius: int = int(ThemeManager.size("tile_corner_radius", 22))
	var outline_width: float = float(ThemeManager.size("tile_outline_width", float(TILE_OUTLINE_WIDTH)))
	var shadow_offset: int = int(ThemeManager.size("tile_shadow_offset", float(TILE_SHADOW_OFFSET)))
	var top_highlight: float = float(ThemeManager.size("tile_top_highlight", 0.0))
	var outline_default: Color = ThemeManager.color("tile_outline_color", Color("1A1A2E"))
	var outline_col: Color = ThemeManager.machine_outline(variant_id, outline_default)
	var shadow_col: Color = ThemeManager.color("tile_shadow_color", Color("0A0F20"))
	var grad: Array = ThemeManager.machine_gradient(variant_id)

	# StyleBox bg/border are transparent — the gradient ColorRect (below)
	# paints the body, and the drop shadow is painted separately via
	# _draw(), so we keep StyleBoxFlat.shadow_* zeroed (its `shadow_size`
	# expands the halo equally on all sides, which fights the "drop shadow
	# below only" look the supercell sticker style needs).
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0, 0, 0, 0)
	card_style.anti_aliasing = true
	card_style.set_corner_radius_all(outer_radius)
	card_style.set_border_width_all(0)
	card_style.shadow_size = 0
	card_style.shadow_color = Color(0, 0, 0, 0)
	# Stash the shadow params for _draw() — drawn as a solid slab strictly
	# below the panel, sized to peek out by `shadow_offset` px. Locked
	# tiles disable the shadow for a flat dimmed appearance.
	if not p_locked:
		_shadow_paint_offset = int(shadow_offset)
		_shadow_paint_color = shadow_col
	else:
		_shadow_paint_offset = 0
		_shadow_paint_color = Color(0, 0, 0, 0)
	_shadow_paint_radius = int(outer_radius)
	queue_redraw()
	# Zero content margins so PanelContainer's fit_child_in_rect lays the
	# gradient/shadow children flush with the panel rect — otherwise the
	# shadow slab (drawn at full-panel coords) would peek out around the
	# inset gradient on every side, producing a halo instead of a clean
	# downward-only drop shadow.
	card_style.content_margin_left = 0
	card_style.content_margin_right = 0
	card_style.content_margin_top = 0
	card_style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", card_style)

	# Drop previous dynamic children if re-running (theme switch).
	if _gradient_rect != null and is_instance_valid(_gradient_rect):
		_gradient_rect.queue_free()
		_gradient_rect = null
	if _shadow_rect != null and is_instance_valid(_shadow_rect):
		_shadow_rect.queue_free()
		_shadow_rect = null

	if grad.size() == 2:
		var top_col: Color = grad[0] if not p_locked else Color(0.30, 0.05, 0.05)
		var bot_col: Color = grad[1] if not p_locked else Color(0.15, 0.02, 0.02)

		# ── BODY: gradient + thin outline ring, rounded corners. ──
		_gradient_rect = ColorRect.new()
		_gradient_rect.name = "GradientBg"
		_gradient_rect.color = Color(1, 1, 1, 1)
		_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gradient_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tile_gradient.gdshader")
		mat.set_shader_parameter("top_color", top_col)
		mat.set_shader_parameter("bot_color", bot_col)
		mat.set_shader_parameter("outline_color", outline_col if not p_locked else Color("3A0A0A"))
		mat.set_shader_parameter("outline_width", outline_width)
		mat.set_shader_parameter("corner_radius", float(outer_radius))
		mat.set_shader_parameter("highlight_color", Color(1, 1, 1, 0.4))
		mat.set_shader_parameter("highlight_thickness", top_highlight if not p_locked else 0.0)
		_gradient_rect.material = mat
		add_child(_gradient_rect)
		# Body sits at the bottom of the child stack so text layout (added
		# after this build) can render on top.
		move_child(_gradient_rect, 0)
		_update_gradient_rect_size()
		resized.connect(_update_gradient_rect_size)
	else:
		# Theme doesn't declare a per-machine gradient — fall back to
		# flat tint through the stylebox's bg_color.
		card_style.bg_color = _bg_color if not p_locked else Color(0.30, 0.05, 0.05)
		card_style.set_border_width_all(int(outline_width))
		card_style.border_color = outline_col if not p_locked else Color(0.25, 0.05, 0.05)


## Paints the drop shadow as a solid slab BELOW the panel rect.
## The slab is the panel's full size shifted down by `_shadow_paint_offset`
## px, so only the bottom `_shadow_paint_offset` strip is visible (the rest
## sits behind the gradient ColorRect, fully covered). Drawing happens in
## the panel's own canvas item, BELOW its child gradient — exactly what we
## want for an opaque shadow that doesn't bleed onto the sides or top.
func _draw() -> void:
	if _shadow_paint_offset <= 0 or _shadow_paint_color.a <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = _shadow_paint_color
	sb.set_corner_radius_all(_shadow_paint_radius)
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), Rect2(0.0, float(_shadow_paint_offset), size.x, size.y))


func _update_gradient_rect_size() -> void:
	var sx: float = max(size.x, 1.0)
	var sy: float = max(size.y, 1.0)
	if _gradient_rect != null and _gradient_rect.material != null:
		(_gradient_rect.material as ShaderMaterial).set_shader_parameter("rect_size", Vector2(sx, sy))
	if _shadow_rect != null and _shadow_rect.material != null:
		(_shadow_rect.material as ShaderMaterial).set_shader_parameter("rect_size", Vector2(sx, sy))
	# Repaint the drop shadow slab whenever the panel resizes.
	queue_redraw()


## Picks the largest font_size at which the title's longest word fits the
## tile width. Called on initial build (using the theme's declared width) and
## again whenever the lobby recomputes tile dimensions via apply_tile_size().
func _fit_title_font(title: Label) -> void:
	_fit_title_font_for_width(title, ThemeManager.tile_min_size().x)


func _fit_title_font_for_width(title: Label, tile_w: float) -> void:
	var font: Font = title.get_theme_font("font")
	if font == null:
		return
	var start_size := 22
	var min_size := 12
	# Effective tile content width: tile size minus stylebox content margins.
	var content_w: float = maxf(tile_w - 32.0, 40.0)
	# Fit the widest explicit line — titles are pre-wrapped with \n so
	# each line is rendered as given. We need every line to fit.
	var lines: PackedStringArray = title.text.split("\n")
	var picked: int = min_size
	for sz in range(start_size, min_size - 1, -1):
		var fits_all := true
		for line in lines:
			var size_px: Vector2 = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
			if size_px.x > content_w:
				fits_all = false
				break
		if fits_all:
			picked = sz
			break
	title.add_theme_font_size_override("font_size", picked)


## Lobby calls this after measuring available center-area height so the
## grid can shrink all tiles proportionally to fit between the header and
## footer. Also re-fits the title font to the new width.
func apply_tile_size(w: float, h: float) -> void:
	custom_minimum_size = Vector2(w, h)
	if _title_label != null and is_instance_valid(_title_label):
		# Font sizing must account for the two emoji slots flanking the title —
		# their width eats into the row, so the title can't use the full tile.
		var emoji_w: float = 0.0
		for em in _title_emojis:
			if em != null and is_instance_valid(em):
				emoji_w += em.custom_minimum_size.x
		# 6px separation × 2 gaps + emoji nodes
		var reserved: float = emoji_w + 12.0
		_fit_title_font_for_width(_title_label, maxf(w - reserved, 40.0))
	if _title_row != null and is_instance_valid(_title_row):
		var rh: float = max(_title_row.size.y, 16.0)
		var target: int = int(clamp(rh * 0.55, 12.0, 36.0))
		for em in _title_emojis:
			if em != null and is_instance_valid(em):
				_apply_emoji_size(em, target)
	# PNG's visible rect scales with card size — tell the lobby to
	# refresh the shimmer overlay's bounds.
	visual_ready.emit()


## Lobby STATS toggle entry point — show/hide stats panel without rebuilding
## the tile. Subtitle gets inverse visibility (hidden when stats shown) so
## the two never compete for the title band's vertical space.
func set_stats_visible(state: bool) -> void:
	_apply_stats_visibility(state)


func _apply_stats_visibility(state: bool) -> void:
	if _stats_panel != null and is_instance_valid(_stats_panel):
		_stats_panel.visible = state
	# Subtitle is hidden via alpha — NOT visible=false — so the title_wrap
	# container keeps reserving the same vertical slot in both modes. Without
	# this, hiding the subtitle would expand title_row height, which the emoji
	# resize callback reads → emojis grow + title font potentially re-fits.
	# Goal: title block looks identical regardless of stats state.
	if _sub_label != null and is_instance_valid(_sub_label):
		_sub_label.modulate.a = 0.0 if state else 1.0


## True when the tile is rendering a PNG (icon layout) vs the
## code-constructed text plate. Lobby uses this to skip its external
## shimmer overlay — PNG tiles carry their own shader-based shimmer
## that respects the texture's alpha mask.
func has_png_art() -> bool:
	return _icon_tex != null and _icon_tex.visible and _icon_tex.texture != null


## Prevents the text layout's combined min size from propagating up
## and inflating the grid beyond the central zone. The lobby drives
## tile dimensions via apply_tile_size() → custom_minimum_size, and we
## want the card to honor that value strictly (content is clipped
## visually via clip_contents when it doesn't fit).
func _get_minimum_size() -> Vector2:
	return custom_minimum_size


## Visible rect of the tile in local coordinates.
##   - Text layout (colored plate): the full card rect.
##   - Icon layout (PNG loaded): the actual PNG area after
##     KEEP_ASPECT_CENTERED letterboxing, so shimmer + taps only hit the
##     visible artwork.
func visible_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, size)
	if _icon_tex == null or not _icon_tex.visible or _icon_tex.texture == null:
		return full
	var tex_size: Vector2 = _icon_tex.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0 or size.x <= 0 or size.y <= 0:
		return full
	var scale_factor: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var display: Vector2 = tex_size * scale_factor
	var offset: Vector2 = (size - display) * 0.5
	return Rect2(offset, display)


## Restricts click/tap hit-testing to the visible rect (PNG artwork for
## icon-mode tiles). Points in the letterboxed margins fall through to
## whatever's underneath (usually the lobby background — a no-op).
func _has_point(point: Vector2) -> bool:
	return visible_rect().has_point(point)


var _press_pos := Vector2.ZERO
var _is_pressed := false
var _title_label: Label = null
var _title_row: HBoxContainer = null
var _title_emojis: Array[Control] = []
var _stats_panel: PanelContainer = null
var _sub_label: Label = null
var _shimmer_mat: ShaderMaterial = null
var _shimmer_t: float = 0.0


## Called by lobby_manager before transitioning to a game — plays a quick
## zoom-in on this card so the tap visually "becomes" the game screen.
func play_zoom_in(_duration: float = 0.35) -> void:
	# No-op: the press/release tilt already provides tap feedback, and the
	# previous scale pop fought the release tween on `scale`, producing a
	# visible bounce on return.
	pass

const TAP_MAX_DISTANCE := 12.0  # screen-space px; beyond this release is a drag, not a tap

func _on_gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.global_position
			_animate_press(true)
		else:
			_animate_press(false)
			# Cancel the tap if the lobby carousel absorbed a swipe gesture —
			# otherwise short-distance drags (pressed on a card, scrolled a bit,
			# released) would accidentally load the table.
			if _carousel_absorbed_swipe():
				return
			if event.global_position.distance_to(_press_pos) < TAP_MAX_DISTANCE:
				SoundManager.play("button_press")
				play_pressed.emit(variant_id)


func _carousel_absorbed_swipe() -> bool:
	for node in get_tree().get_nodes_in_group("lobby_manager"):
		if node.has_method("carousel_drag_moved") and node.carousel_drag_moved():
			return true
	return false


func _animate_press(down: bool) -> void:
	if down == _is_pressed:
		return
	_is_pressed = down
	pivot_offset = size / 2.0
	var target: Vector2 = Vector2(0.95, 0.95) if down else Vector2.ONE
	var duration: float = 0.047 if down else 0.073
	var tilt: float = deg_to_rad(randf_range(-3.0, 3.0)) if down else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", tilt, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	# Restore scale if mouse leaves the card mid-press (e.g. during a drag).
	if what == NOTIFICATION_MOUSE_EXIT and _is_pressed:
		_animate_press(false)


func _process(delta: float) -> void:
	# Drive the shimmer shader's time uniform. The setter also triggers
	# a redraw (Godot invalidates canvas items when uniforms change).
	if _shimmer_mat != null:
		_shimmer_t += delta
		_shimmer_mat.set_shader_parameter("shimmer_time", _shimmer_t)
