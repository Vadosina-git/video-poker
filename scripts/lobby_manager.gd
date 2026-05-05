extends Control

signal machine_selected(variant_id: String)

var MachineCardScene: PackedScene = null

## Per-machine config: ID + colors + lock flag.
## Display name and mini-description come from translations.json (keys
## `machine.{id}.name` / `machine.{id}.mini`).
const MACHINE_CONFIG := [
	{"id": "deuces_and_joker",   "color": Color(0.05, 0.5, 0.45), "accent": Color(0.8, 0.15, 0.15), "locked": false},
	{"id": "jacks_or_better",    "color": Color(0.2, 0.3, 0.8),   "accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "bonus_poker",        "color": Color(0.75, 0.15, 0.15),"accent": Color(0.75, 0.75, 0.8), "locked": false},
	{"id": "deuces_wild",        "color": Color(0.1, 0.7, 0.2),   "accent": Color(1.0, 0.9, 0.1),   "locked": false},
	{"id": "double_bonus",       "color": Color(0.6, 0.1, 0.1),   "accent": Color(0.75, 0.75, 0.8), "locked": false},
	{"id": "bonus_poker_deluxe", "color": Color(0.5, 0.1, 0.5),   "accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "double_double_bonus","color": Color(0.45, 0.05, 0.15),"accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "triple_double_bonus","color": Color(0.08, 0.08, 0.08),"accent": Color(0.85, 0.7, 0.2),  "locked": false},
	{"id": "aces_and_faces",     "color": Color(0.1, 0.5, 0.2),   "accent": Color(0.75, 0.75, 0.8), "locked": false},
	{"id": "joker_poker",        "color": Color(0.4, 0.1, 0.6),   "accent": Color(1.0, 0.9, 0.1),   "locked": false},
]

@onready var _grid: GridContainer = %MachineGrid
@onready var _credits_label: Label = %LobbyCredits
@onready var _cash_label: Label = %CashLabel
@onready var _sidebar: VBoxContainer = %Sidebar

var _cash_cd: Dictionary

var _paytables: Dictionary = {}
var _machine_cards: Array = []

# Card background color by play mode id (all machines in a mode share one tint)
const MODE_CARD_COLORS := {
	"single_play": Color(0.72, 0.10, 0.10),   # red
	"triple_play": Color(0.22, 0.40, 0.78),   # light blue
	"five_play":   Color(0.10, 0.25, 0.65),   # medium blue
	"ten_play":    Color(0.04, 0.12, 0.45),   # dark blue
	"ultra_vp":    Color(0.06, 0.35, 0.15),   # dark green
	"spin_poker":  Color(0.38, 0.08, 0.55),   # purple
}

# Built from lobby_order.json via ConfigManager at _ready()
var PLAY_MODES: Array = []

const MODE_HANDS := {
	"single_play": 1, "triple_play": 3, "five_play": 5,
	"ten_play": 10, "ultra_vp": 5, "spin_poker": 1,
}

func _build_play_modes() -> void:
	PLAY_MODES.clear()
	var lobby_modes := ConfigManager.get_lobby_modes()
	# features.json gates entire mode families (multi-hand / ultra_vp / spin_poker).
	var multi_on: bool = ConfigManager.is_feature_enabled("multi_hand_enabled", true)
	var ultra_on: bool = ConfigManager.is_feature_enabled("ultra_vp_enabled", true)
	var spin_on: bool = ConfigManager.is_feature_enabled("spin_poker_enabled", true)
	for m in lobby_modes:
		if not m.get("enabled", true):
			continue
		var mode_id: String = m.get("id", "")
		if mode_id in ["triple_play", "five_play", "ten_play"] and not multi_on:
			continue
		if mode_id == "ultra_vp" and not ultra_on:
			continue
		if mode_id == "spin_poker" and not spin_on:
			continue
		PLAY_MODES.append({
			"id": mode_id,
			"label_key": m.get("label_key", "lobby.mode_" + mode_id),
			"hands": MODE_HANDS.get(mode_id, 1),
			"ultra_vp": mode_id == "ultra_vp",
			"spin_poker": mode_id == "spin_poker",
			"machines": m.get("machines", []),
		})
	if PLAY_MODES.size() == 0:
		# Fallback
		PLAY_MODES = [
			{"id": "single_play", "label_key": "lobby.mode_single_play", "hands": 1, "ultra_vp": false, "spin_poker": false, "machines": []},
		]
var _active_mode: int = 0
# Per-mode gradient pairs for the supercell skin (top → bottom).
const SUPERCELL_MODE_BG := {
	"single_play": [Color("22CBFD"), Color("A5E6FF")],   # cyan — default supercell
	# Multi-hand modes progressively darken with hand count so the
	# player feels the stakes deepen visually as Triple → Five → Ten.
	"triple_play": [Color("7986CB"), Color("3949AB")],   # light indigo
	"five_play":   [Color("5C6BC0"), Color("283593")],   # mid indigo
	"ten_play":    [Color("3F51B5"), Color("1A237E")],   # deep indigo / navy
	"ultra_vp":    [Color("4CAF50"), Color("1B5E20")],   # supercell green
	"spin_poker":  [Color("7E57C2"), Color("4527A0")],   # supercell purple
}

# Per-mode gradient pairs for the classic skin (top → bottom).
# Single keeps the original theme colors; each multi-hand step darkens the
# bottom accent progressively. Ultra → dark forest green. Spin → deep purple.
const CLASSIC_MODE_BG := {
	"single_play": [Color("07132A"), Color("4A8CC8")],   # classic navy → sky blue
	"triple_play": [Color("061122"), Color("3D79AD")],   # slightly darker blue
	"five_play":   [Color("050E1B"), Color("306090")],   # medium dark blue
	"ten_play":    [Color("040C16"), Color("214566")],   # deep dark blue
	"ultra_vp":    [Color("031A08"), Color("0D5C2A")],   # dark forest green
	"spin_poker":  [Color("0E0320"), Color("4A147A")],   # deep purple
}
var _active_bg_top: Color = Color(0.04, 0.04, 0.08, 1)
var _active_bg_bot: Color = Color(0.04, 0.04, 0.08, 1)
var _bg_node: ColorRect = null
var _sidebar_buttons: Array[Button] = []
var _bg_gradient_node: TextureRect = null  # ThemeGradient TextureRect; updated on mode change
var _gift_footer_label: Label = null
var _gift_footer_tex: TextureRect = null
var _gift_footer_ready_path: String = ""
var _gift_footer_waiting_path: String = ""
var _store_btn: Control = null
var _shop_badge_visible: bool = false


func _ready() -> void:
	add_to_group("lobby_manager")
	MachineCardScene = load("res://scenes/lobby/machine_card.tscn")
	_build_play_modes()
	_paytables = Paytable.load_all()
	_build_bg_layer()
	_apply_theme()
	# Currency glyphs — MUST run AFTER _apply_theme() so _cash_pill points
	# at the freshly built HBox row inside the new LEFT zone.
	_cash_label.text = Translations.tr_key("lobby.cash")
	# Stroked digits — gives the chip count the same legibility as the
	# CREDITS: label above (which uses font_outline_color). Without this
	# the white digits float against the bright top bar with no edge.
	_cash_cd = SaveManager.create_currency_display(28, Color.WHITE,
		ThemeManager.color("topbar_text_outline", Color.BLACK), 2.0)
	_cash_pill.add_child(_cash_cd["box"])
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	_build_carousel()


## Paint the existing full-rect Background node from the active theme and
## Renders the lobby background. Single universal rule:
##   If `themes/<id>/backgrounds/background.png` exists → show the PNG,
##   nothing else (no gradient, no overlay, no pattern). Delete the file
##   and the theme falls back to its code-constructed layers:
##     1. primary gradient texture (radial/linear) if declared
##     2. else vertical 2-stop gradient from grid_bg_top/bottom
##     3. else solid fill (bg_main)
##     4. optional overlay gradient on top
##     5. optional diagonal-stripe pattern on top
func _build_bg_layer() -> void:
	var bg := $Background as ColorRect
	if bg == null:
		return
	bg.color = Color(0, 0, 0, 0)

	# ── PNG takes absolute priority — no mixing with generated layers. ──
	var png_tex: Texture2D = ThemeManager.background_texture()
	if png_tex != null:
		var tr := TextureRect.new()
		tr.name = "ThemeBackdrop"
		tr.texture = png_tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		move_child(tr, bg.get_index() + 1)
		# Age gate — classic-skin only. Supercell is branded as a
		# trainer app and intentionally omits the 18+ gate.
		if ThemeManager.current_id == "classic":
			AgeGate.show_if_needed(self)
		return

	# ── Code fallback: generated gradient + pattern layers. ──
	var grad_tex: Texture2D = ThemeManager.background_gradient_texture()
	var has_gradient_2stops: bool = ThemeManager.has_color("grid_bg_top") and ThemeManager.has_color("grid_bg_bottom")
	var solid_col: Color = ThemeManager.color("bg_main", Color(0.04, 0.04, 0.08, 1))
	# Cache the bg node so `_apply_mode_bg()` can re-trigger draw when the
	# active mode changes (supercell skin only — see SUPERCELL_MODE_BG).
	_bg_node = bg
	_apply_mode_bg()
	bg.draw.connect(func() -> void:
		var ci := bg.get_canvas_item()
		var rect := Rect2(Vector2.ZERO, bg.size)
		if grad_tex == null:
			if has_gradient_2stops:
				_draw_vertical_gradient(ci, rect, _active_bg_top, _active_bg_bot)
			else:
				RenderingServer.canvas_item_add_rect(ci, rect, solid_col)
		ThemeManager.draw_pattern(ci, rect)
	)
	var insert_idx: int = bg.get_index() + 1
	if grad_tex != null:
		var gr := TextureRect.new()
		gr.name = "ThemeGradient"
		gr.texture = grad_tex
		gr.set_anchors_preset(Control.PRESET_FULL_RECT)
		gr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# KEEP_ASPECT_COVERED so a radial gradient on a square texture
		# stays circular on any viewport aspect (some edges may crop).
		# Linear gradients look the same either way since the banding
		# runs along one axis only.
		gr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gr)
		move_child(gr, insert_idx)
		insert_idx += 1
		_bg_gradient_node = gr
	var overlay_tex: Texture2D = ThemeManager.background_overlay_gradient_texture()
	if overlay_tex != null:
		var ov := TextureRect.new()
		ov.name = "ThemeGradientOverlay"
		ov.texture = overlay_tex
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Overlay gradients are vertical (top→bottom darkener) — let
		# them stretch to fill the viewport exactly.
		ov.stretch_mode = TextureRect.STRETCH_SCALE
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ov)
		move_child(ov, insert_idx)
	# Age gate — classic-skin only (same reason as above branch).
	if ThemeManager.current_id == "classic":
		AgeGate.show_if_needed(self)


## Was 20px before edge-to-edge carousel work. Now the machine carousel
## sweeps to the actual screen edge (under the Dynamic Island / rounded
## corners) — the lobby's outer VBoxContainer carries metadata
## `safe_area_axes = "vertical"` so iOS horizontal safe area is ignored
## here, and the TopBar/Footer handle their own notch clearance via
## TOP_BAR_SIDE_PAD. Keeping the constant at 0 instead of removing it so
## the few non-carousel call sites (line 660-661 stylebox content margins)
## still compile without conditional code.
const SAFE_AREA_H := 0
# Extra horizontal padding inside the top bar so the balance pill (left)
# and the settings/support icons (right) stay clear of the screen's
# rounded corners / notch instead of hugging the bezel.
const TOP_BAR_SIDE_PAD := 48

func _apply_theme() -> void:
	$VBoxContainer.add_theme_constant_override("separation", 0)
	$VBoxContainer/SafeArea/ContentHBox.add_theme_constant_override("separation", 0)
	# Safe zone around the center: SAFE_AREA_H pixels on left/right so
	# carousel content clears the device safe area (notch / rounded
	# corners). Top/bottom stay flush since header + footer handle
	# vertical spacing.
	var safe := $VBoxContainer/SafeArea as MarginContainer
	safe.add_theme_constant_override("margin_left", SAFE_AREA_H)
	safe.add_theme_constant_override("margin_right", SAFE_AREA_H)
	safe.add_theme_constant_override("margin_top", 0)
	safe.add_theme_constant_override("margin_bottom", 0)
	# Old left sidebar is obsolete — mode buttons now live in the bottom footer.
	var old_sidebar := %Sidebar as Control
	if old_sidebar:
		old_sidebar.visible = false
	_style_top_bar()
	_clear_grid_frame()
	_style_footer()
	_build_footer_modes()
	var scroll := %GridScroll as ScrollContainer
	# vertical_scroll_mode=DISABLED (the scene default) force-stretches the
	# grid to the full scroll height, which expands tiles beyond their
	# custom_minimum_size. SHOW_NEVER keeps scroll math alive (no bar drawn)
	# but lets the grid sit at its actual min_size — so our computed tile
	# heights are honored. Grid gets SHRINK_CENTER so it vertically centers
	# when the viewport is taller than the two rows need.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.get_h_scroll_bar().modulate.a = 0
	scroll.get_v_scroll_bar().modulate.a = 0
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_setup_drag_scroll(scroll)
	# Horizontal gap between columns; vertical gap is wider so the two
	# rows have visible breathing room (the supercell sticker shadow needs
	# vertical clearance to read as a separate plate, not as a connector).
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 24)
	# Recompute tile size whenever the center area height changes (device
	# rotation, safe-area insets, header/footer height adjustments).
	if not scroll.resized.is_connected(_update_tile_sizes):
		scroll.resized.connect(_update_tile_sizes)


## Tiles scale proportionally to the vertical space available in the center
## area. Header and footer "squeeze" the middle — the grid rows share the
## remaining height equally, and tile width is derived from the theme's
## declared aspect ratio. User scrolls horizontally to see off-screen columns.
func _update_tile_sizes() -> void:
	var scroll := %GridScroll as ScrollContainer
	if scroll == null or _machine_cards.is_empty():
		return
	var avail_h: float = scroll.size.y
	if avail_h < 1.0:
		return
	var cols: int = maxi(int(_grid.columns), 1)
	var rows: int = int(ceil(float(_machine_cards.size()) / float(cols)))
	rows = maxi(rows, 1)
	# Must match GridContainer's v_separation override below — keep in sync.
	var v_sep: float = 24.0
	# Reserve space under each row for the sticker drop shadow. Without
	# this padding the last row's shadow would be clipped by the scroll
	# rect (and the row would appear to "hang" over the footer).
	const SHADOW_PAD := 12.0
	var tile_h: float = (avail_h - v_sep * float(rows - 1) - SHADOW_PAD * float(rows)) / float(rows)
	# tile_h above is the exact height that fills the available area minus
	# row separators and shadow reserve — letting the bottom row sit flush
	# against (but not over) the footer. Upper clamp prevents absurdly tall
	# tiles on huge desktop windows.
	tile_h = clampf(tile_h, 40.0, 360.0)
	var base: Vector2 = ThemeManager.tile_min_size()
	var aspect: float = (base.x / base.y) if base.y > 0.0 else 1.0
	var tile_w: float = tile_h * aspect
	for card in _machine_cards:
		if is_instance_valid(card) and card.has_method("apply_tile_size"):
			card.apply_tile_size(tile_w, tile_h)


## Builds the full 3-zone top bar layout (Figma-aligned):
##   [CREDITS block + Store]        [VIDEO POKER TRAINER]        [Support | Settings]
## Everything floats — no pills, no fills. Clears existing TopBar children
## and reparents scene-declared Labels (%CashLabel, %LobbyTitle) into the
## new structure. %LobbyCredits is dropped entirely.
func _style_top_bar() -> void:
	var top_bar := $VBoxContainer/TopBar as HBoxContainer
	top_bar.custom_minimum_size = Vector2(0, 120)
	var bg := StyleBoxEmpty.new()
	top_bar.add_theme_stylebox_override("panel", bg)
	top_bar.add_theme_constant_override("separation", 12)

	var title := %LobbyTitle as Label
	# Detach the reusable scene labels; drop the unused credits label.
	if _cash_label.get_parent():
		_cash_label.get_parent().remove_child(_cash_label)
	if title.get_parent():
		title.get_parent().remove_child(title)
	if _credits_label.get_parent():
		_credits_label.get_parent().remove_child(_credits_label)
		_credits_label.queue_free()

	# Wipe any leftover children (scene spacers etc.) so we rebuild cleanly.
	for c in top_bar.get_children():
		top_bar.remove_child(c)
		c.queue_free()

	# ---------- LEFT safe zone ----------
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(TOP_BAR_SIDE_PAD, 0)
	top_bar.add_child(left_pad)

	# ---------- LEFT zone ----------
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(left)

	# "CREDITS:" label (row 1) + chip/value row (row 2).
	var theme_font: Font = ThemeManager.font()
	_cash_label.add_theme_font_size_override("font_size", 20)
	_cash_label.add_theme_color_override("font_color", ThemeManager.color("topbar_text", Color.WHITE))
	_cash_label.add_theme_color_override("font_outline_color", ThemeManager.color("topbar_text_outline", Color.BLACK))
	_cash_label.add_theme_constant_override("outline_size", 3)
	if theme_font != null:
		_cash_label.add_theme_font_override("font", theme_font)

	var cash_group := VBoxContainer.new()
	cash_group.add_theme_constant_override("separation", 2)
	cash_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(cash_group)
	cash_group.add_child(_cash_label)
	# Value row — currency glyphs appended here in _ready.
	var cash_value_row := HBoxContainer.new()
	cash_value_row.add_theme_constant_override("separation", 6)
	cash_value_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	cash_group.add_child(cash_value_row)
	_cash_pill = cash_value_row

	# Store button (primitive bag icon + label + conditional badge).
	# The badge is a plain red dot that appears only while at least one
	# free reward is available in the shop (daily gift OR any IAP pack
	# off its cooldown). State is maintained by _refresh_shop_badge.
	if ConfigManager.is_visible("show_lobby_store_button", true):
		_store_btn = _make_top_icon_btn("store",
			Translations.tr_key("lobby.store"),
			_show_shop)
		_store_btn.draw.connect(func() -> void:
			if _shop_badge_visible:
				_draw_badge(_store_btn)
		)
		left.add_child(_store_btn)

	# ---------- expanding spacer ----------
	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(sp1)

	# ---------- CENTER zone: title ----------
	title.text = Translations.tr_key("lobby.title")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ThemeManager.color("title_text", Color.WHITE))
	title.add_theme_color_override("font_outline_color", ThemeManager.color("title_outline", Color.BLACK))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if theme_font != null:
		title.add_theme_font_override("font", theme_font)
	top_bar.add_child(title)

	# ---------- expanding spacer ----------
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(sp2)

	# ---------- RIGHT zone: Support + Settings ----------
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(right)
	right.add_child(_make_top_icon_btn("support",
		Translations.tr_key("lobby.support"),
		_show_support))
	if ConfigManager.is_visible("show_lobby_settings_gear", true):
		right.add_child(_make_top_icon_btn("settings",
			Translations.tr_key("lobby.settings"),
			_show_settings))

	# ---------- RIGHT safe zone ----------
	var right_pad := Control.new()
	right_pad.custom_minimum_size = Vector2(TOP_BAR_SIDE_PAD, 0)
	top_bar.add_child(right_pad)


## Creates a top-bar icon button (primitive icon on top, label below).
## `kind` selects the drawn icon (store/support/settings). Notification
## badges are attached by the caller (see _store_btn + _refresh_shop_badge).
func _make_top_icon_btn(kind: String, label_text: String, on_press: Callable) -> Control:
	var root := Button.new()
	root.custom_minimum_size = Vector2(80, 96)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	root.add_theme_stylebox_override("normal", empty)
	root.add_theme_stylebox_override("hover", empty)
	root.add_theme_stylebox_override("pressed", empty)
	root.add_theme_stylebox_override("focus", empty)
	root.pressed.connect(on_press)
	_attach_press_effect(root)
	# PNG takes priority over primitive glyph. Same convention as
	# machine tiles — drop the PNG into themes/<id>/icons/<kind>.png
	# and it's picked up automatically.
	var png_path: String = ThemeManager.ui_icon_path(kind)
	if png_path != "":
		var tr := TextureRect.new()
		tr.texture = load(png_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# STRETCH_SCALE — every icon now renders at the exact rect size
		# regardless of its source PNG's aspect / internal padding. Source
		# PNGs are pre-cropped to ~1:1 so the cosmetic stretch is invisible
		# (<4%); this guarantees store/support/settings come out the same
		# pixel height instead of one icon shrinking due to extra alpha
		# margin in the asset.
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_TOP_WIDE)
		tr.offset_top = 2
		# Icon ends at y=78 — the label below (offset_top = -18 from
		# BOTTOM_WIDE → y=78..96) sits flush with the icon's bottom edge,
		# zero gap. Label slot is 18px so the 14pt + 3px-outline text
		# ("STORE" / "SUPPORT" / "SETTINGS") doesn't overflow upward into
		# the icon when bottom-aligned.
		tr.offset_bottom = 78
		root.add_child(tr)
	else:
		# Primitive-drawn icon fallback.
		root.draw.connect(func() -> void:
			_draw_top_icon(root, kind)
		)
	var lab := Label.new()
	lab.text = label_text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", ThemeManager.color("topbar_text", Color.WHITE))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 3)
	var theme_font: Font = ThemeManager.font()
	if theme_font != null:
		lab.add_theme_font_override("font", theme_font)
	lab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Label sits flush with the icon: icon ends at y=78, label spans
	# y=78..96 (18px tall) — zero gap. Bottom-aligned text fits inside
	# this slot at font 14 + outline 3 without overflowing into the icon.
	lab.offset_top = -18
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lab)
	return root


## Renders a primitive icon glyph into the top-half (~50x50) of a
## top-bar button. Meant as a placeholder — later swapped for PNG assets
## via the same config mechanism as machine tiles.
func _draw_top_icon(ctrl: Control, kind: String) -> void:
	var s: Vector2 = ctrl.size
	var cx: float = s.x * 0.5
	var cy: float = s.y * 0.36
	var r: float = 22.0
	var stroke := ThemeManager.color("grid_border", Color("FFEC00"))
	var w := 2.5
	match kind:
		"store":
			# Rounded bag outline + handle arc
			var rect := Rect2(cx - r, cy - r * 0.7, r * 2.0, r * 1.4)
			_draw_rounded_rect_outline(ctrl, rect, 4.0, stroke, w)
			# handle
			ctrl.draw_arc(Vector2(cx, cy - r * 0.7), r * 0.5, PI, TAU, 16, stroke, w)
		"support":
			ctrl.draw_arc(Vector2(cx, cy), r, 0, TAU, 32, stroke, w)
			# "?" centered
			var font: Font = ThemeManager.font()
			if font == null:
				font = ctrl.get_theme_default_font()
			if font != null:
				var qs: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
				ctrl.draw_string(font, Vector2(cx - qs.x * 0.5, cy + qs.y * 0.35), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 28, stroke)
		"settings":
			# Simple gear: outer circle + inner dot + 8 teeth as short lines.
			ctrl.draw_arc(Vector2(cx, cy), r * 0.7, 0, TAU, 32, stroke, w)
			ctrl.draw_arc(Vector2(cx, cy), r * 0.25, 0, TAU, 16, stroke, w)
			for i in 8:
				var a: float = float(i) * PI / 4.0
				var p1 := Vector2(cx + cos(a) * r * 0.8, cy + sin(a) * r * 0.8)
				var p2 := Vector2(cx + cos(a) * r, cy + sin(a) * r)
				ctrl.draw_line(p1, p2, stroke, w)


func _draw_rounded_rect_outline(ctrl: Control, rect: Rect2, radius: float, col: Color, width: float) -> void:
	# Approximates a rounded rect outline via 4 lines + 4 arcs. Good enough
	# for placeholder icons; won't be pixel-perfect on large radii.
	var l := rect.position.x; var t := rect.position.y
	var r := rect.position.x + rect.size.x; var b := rect.position.y + rect.size.y
	ctrl.draw_line(Vector2(l + radius, t), Vector2(r - radius, t), col, width)
	ctrl.draw_line(Vector2(l + radius, b), Vector2(r - radius, b), col, width)
	ctrl.draw_line(Vector2(l, t + radius), Vector2(l, b - radius), col, width)
	ctrl.draw_line(Vector2(r, t + radius), Vector2(r, b - radius), col, width)
	ctrl.draw_arc(Vector2(l + radius, t + radius), radius, PI, PI * 1.5, 8, col, width)
	ctrl.draw_arc(Vector2(r - radius, t + radius), radius, PI * 1.5, TAU, 8, col, width)
	ctrl.draw_arc(Vector2(r - radius, b - radius), radius, 0, PI * 0.5, 8, col, width)
	ctrl.draw_arc(Vector2(l + radius, b - radius), radius, PI * 0.5, PI, 8, col, width)


## Number-less notification dot hovering over the top-right of a
## top-bar button. Used on the Store icon to signal "a free reward is
## waiting". Callers gate the draw on their own state flag.
func _draw_badge(ctrl: Control) -> void:
	var s: Vector2 = ctrl.size
	# Hugs the icon's top-right corner. Icon spans y=2..80 horizontally
	# centered with KEEP_ASPECT_CENTERED, so a square texture lands at
	# ~(8, 2)..(72, 66). Putting the dot at cx+18, cy=12 plants it just
	# inside the visible icon's upper-right rather than floating in the
	# button's empty corner.
	var cx: float = s.x * 0.5 + 18.0
	var cy: float = 12.0
	var r := 7.0
	ctrl.draw_circle(Vector2(cx, cy), r, Color("#E53935"))
	ctrl.draw_arc(Vector2(cx, cy), r, 0, TAU, 24, Color.WHITE, 1.5)


## True while the shop has at least one claimable free reward: the
## daily gift (when its cooldown has elapsed) or any IAP pack currently
## off its own cooldown. Called every frame from _process — cheap:
## integer math + a dictionary lookup. Suppressed when configs/features.json
## -> feature_flags.lobby_store_indicator is false (no red dot shown).
func _has_free_shop_reward() -> bool:
	if not ConfigManager.is_feature_enabled("lobby_store_indicator", true):
		return false
	if _is_gift_ready():
		return true
	var items: Array = ConfigManager.get_shop_items()
	for it in items:
		if not (it is Dictionary):
			continue
		var id: String = str(it.get("id", ""))
		var cd: int = int(it.get("cooldown_seconds", 0))
		if id == "" or cd <= 0:
			continue
		if SaveManager.get_pack_cooldown_remaining(id, cd) <= 0:
			return true
	return false


## Toggles the Store button's notification dot to match the current
## shop state, triggering a redraw only on transitions.
func _refresh_shop_badge() -> void:
	if _store_btn == null or not is_instance_valid(_store_btn):
		return
	var visible_now: bool = _has_free_shop_reward()
	if visible_now != _shop_badge_visible:
		_shop_badge_visible = visible_now
		_store_btn.queue_redraw()


## The central zone inside the SafeArea has no inner padding — SafeArea
## alone provides the side inset. No frame, no background.
func _clear_grid_frame() -> void:
	var grid_margin := $VBoxContainer/SafeArea/ContentHBox/GridMargin as MarginContainer
	grid_margin.add_theme_constant_override("margin_left", 0)
	grid_margin.add_theme_constant_override("margin_right", 0)
	grid_margin.add_theme_constant_override("margin_top", 0)
	grid_margin.add_theme_constant_override("margin_bottom", 0)


## Render a vertical gradient by stacking N thin horizontal rects. Cheap and
## works without custom textures or shaders — 60 slices is visually smooth at
## typical grid heights (~800px → ~13px per slice).
func _draw_vertical_gradient(ci: RID, rect: Rect2, top: Color, bottom: Color, slices: int = 60) -> void:
	if slices <= 0:
		return
	var step: float = rect.size.y / float(slices)
	for i in slices:
		var t: float = float(i) / float(slices - 1)
		var col := top.lerp(bottom, t)
		var y: float = rect.position.y + step * float(i)
		# Extend one pixel to cover rounding gaps between slices.
		RenderingServer.canvas_item_add_rect(ci,
			Rect2(rect.position.x, y, rect.size.x, step + 1.0),
			col)


func _style_footer() -> void:
	var footer := %Footer as HBoxContainer
	# Tall enough for the 136-tall mode buttons (icon 92 + label 40 + top
	# breathing room). Shrunk after the 1.5× icon size reduction.
	footer.custom_minimum_size = Vector2(0, 160)
	# Minimum gap between buttons — they keep a tight spacing by default.
	# Buttons keep their own custom_minimum_size and group-center so the
	# strip grows when more modes are added but never spreads out to fill
	# the full footer width.
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	# No fill, no border — mode buttons float over the background pattern.
	var st := StyleBoxEmpty.new()
	st.content_margin_left = SAFE_AREA_H
	st.content_margin_right = SAFE_AREA_H
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	footer.add_theme_stylebox_override("panel", st)


func _build_footer_modes() -> void:
	# Find active mode from SaveManager — prefer mode_id match, fall back to hand_count.
	var found := false
	for j in PLAY_MODES.size():
		if PLAY_MODES[j].get("id", "") == SaveManager.mode_id:
			_active_mode = j
			found = true
			break
	if not found:
		for j in PLAY_MODES.size():
			var m: Dictionary = PLAY_MODES[j]
			if m["hands"] == SaveManager.hand_count and m["ultra_vp"] == SaveManager.ultra_vp and m.get("spin_poker", false) == SaveManager.spin_poker:
				_active_mode = j
				found = true
				break
	if not found and PLAY_MODES.size() > 0:
		# Saved mode was disabled in config — sync SaveManager to the first
		# enabled mode so machine routing doesn't leak stale flags (e.g. old
		# spin_poker=true would otherwise launch spin_poker_game.tscn).
		_active_mode = 0
		SaveManager.mode_id = PLAY_MODES[0].get("id", "single_play")
		SaveManager.hand_count = PLAY_MODES[0]["hands"]
		SaveManager.ultra_vp = PLAY_MODES[0]["ultra_vp"]
		SaveManager.spin_poker = PLAY_MODES[0].get("spin_poker", false)
		SaveManager.save_game()
	# Repaint the lobby backdrop using the now-resolved active mode.
	# Without this, returning from a non-default mode (e.g. spin_poker)
	# would briefly leave the bg on the single_play cyan because
	# `_build_bg_layer` runs before `_active_mode` is restored from save.
	_apply_mode_bg()

	var footer := %Footer as HBoxContainer
	for child in footer.get_children():
		child.queue_free()
	_sidebar_buttons.clear()

	# Leftmost: gift widget (replaces the Figma "Coming Soon" slot — per
	# direction "на место иконки coming soon влево вниз"). Same footprint
	# as a mode button so the row reads as one icon strip.
	footer.add_child(_build_footer_gift())

	for i in PLAY_MODES.size():
		var mode_id: String = PLAY_MODES[i].get("id", "")
		var btn := _make_footer_mode_btn(mode_id,
			Translations.tr_key(PLAY_MODES[i]["label_key"]),
			i == _active_mode)
		btn.pressed.connect(_on_mode_selected.bind(i))
		footer.add_child(btn)
		_sidebar_buttons.append(btn)


func _on_mode_selected(index: int) -> void:
	var was_ultra: bool = _active_mode == index and PLAY_MODES[index].get("ultra_vp", false)
	_active_mode = index
	var selected_mode_id: String = PLAY_MODES[index].get("id", "single_play")
	SaveManager.mode_id = selected_mode_id
	# Pre-release: force canonical hand count per mode (3/5/10) — ignore any
	# previously saved override so reviewer always sees Triple Play=3,
	# Five Play=5, Ten Play=10 on entry, regardless of last session.
	SaveManager.hand_count = MODE_HANDS.get(selected_mode_id, PLAY_MODES[index]["hands"])
	SaveManager.ultra_vp = PLAY_MODES[index]["ultra_vp"]
	SaveManager.spin_poker = PLAY_MODES[index].get("spin_poker", false)
	if PLAY_MODES[index].get("ultra_vp", false) and not was_ultra:
		SoundManager.play("multiplier_activate")
	SaveManager.save_game()
	# Repaint the lobby backdrop with the new mode's gradient (supercell
	# only — classic stays on its theme-default colors).
	_apply_mode_bg()
	# Rebuild footer so the newly active mode's icon+label switch to
	# accent color. Cheap — 6 buttons + a gift slot.
	_build_footer_modes()
	_build_carousel()
	if index < _sidebar_buttons.size():
		var btn: Control = _sidebar_buttons[index]
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "rotation", deg_to_rad(-1.225), 0.053).from(0.0)
		tw.tween_property(btn, "rotation", deg_to_rad(0.98), 0.06)
		tw.tween_property(btn, "rotation", 0.0, 0.067)


## Footer mode button: primitive icon above a label. Active state is
## signaled by accent color only (icon stroke + label) — no fills/borders.
## Metadata `mode_id` drives the primitive drawn (so PNG swaps can be
## slotted in later using the same keys as machine tiles).
## Resolve the lobby gradient pair for the currently selected mode.
## Supercell uses SUPERCELL_MODE_BG; classic uses CLASSIC_MODE_BG (mode-aware
## darkening). Unknown skins fall back to theme `grid_bg_top/bottom` colors.
func _apply_mode_bg() -> void:
	var mode_id: String = "single_play"
	if _active_mode >= 0 and _active_mode < PLAY_MODES.size():
		mode_id = PLAY_MODES[_active_mode].get("id", "single_play")
	if ThemeManager.current_id == "supercell":
		var pair: Variant = SUPERCELL_MODE_BG.get(mode_id, null)
		if pair == null:
			pair = SUPERCELL_MODE_BG["single_play"]
		_active_bg_top = pair[0]
		_active_bg_bot = pair[1]
	else:
		var pair: Variant = CLASSIC_MODE_BG.get(mode_id, null)
		if pair != null:
			_active_bg_top = pair[0]
			_active_bg_bot = pair[1]
		else:
			var solid: Color = ThemeManager.color("bg_main", Color(0.04, 0.04, 0.08))
			_active_bg_top = ThemeManager.color("grid_bg_top", solid)
			_active_bg_bot = ThemeManager.color("grid_bg_bottom", solid)
		# Classic uses a radial GradientTexture2D — rebuild it with mode colors
		# so switching modes visually tints the background.
		if _bg_gradient_node != null and is_instance_valid(_bg_gradient_node):
			_bg_gradient_node.texture = _build_classic_radial(_active_bg_top, _active_bg_bot)
	if _bg_node != null and is_instance_valid(_bg_node):
		_bg_node.queue_redraw()


## Builds a radial GradientTexture2D matching the classic.json structure
## but derived from the given edge (top/dark) and center (bot/accent) colors.
## Stop positions mirror the original: 0.0 → 0.18 → 0.54 → 1.0.
func _build_classic_radial(edge: Color, center: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.18, 0.54, 1.0])
	grad.colors = PackedColorArray([
		center.lightened(0.12),           # glowing center — slightly brighter
		center,                           # full accent
		center.lerp(edge, 0.6),           # transitioning toward dark
		edge,                             # darkest at the edges
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 1024
	tex.height = 1024
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	return tex


func _make_footer_mode_btn(mode_id: String, label_text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(176, 136)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	var active_col := ThemeManager.color("sidebar_active_text", Color("FFEC00"))
	var idle_col := ThemeManager.color("sidebar_text", Color(0.75, 0.65, 0.15))
	var col: Color = active_col if active else idle_col
	btn.set_meta("mode_id", mode_id)
	btn.set_meta("active", active)

	# Icon area: PNG if available, fallback to primitive glyph.
	var icon_tex: Texture2D = _mode_icon_texture(mode_id)
	if icon_tex != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Icon 92px tall (1.5× smaller than before), sits flush against
		# the label's top edge — no gap, no overlap.
		tex_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
		tex_rect.offset_top = 4
		tex_rect.offset_bottom = 96
		# Dim non-active icons via modulate; active stays at full alpha.
		tex_rect.modulate = Color(1, 1, 1, 1.0) if active else Color(1, 1, 1, 0.72)
		btn.add_child(tex_rect)
	else:
		btn.draw.connect(func() -> void:
			_draw_mode_icon(btn, mode_id, col)
		)

	var lab := Label.new()
	lab.text = label_text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 4)
	var theme_font: Font = ThemeManager.font()
	if theme_font != null:
		lab.add_theme_font_override("font", theme_font)
	lab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lab.offset_top = -40
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lab)
	_attach_press_effect(btn)
	return btn


## Resolves a mode button icon via the active theme's folder
## (assets/themes/<theme>/modes/<mode_id>.png). Returns null when the
## theme doesn't ship a PNG — the primitive glyph takes over.
func _mode_icon_texture(mode_id: String) -> Texture2D:
	var path := ThemeManager.mode_icon_path(mode_id)
	if path == "":
		return null
	return load(path)


## Primitive icon used for each footer mode. Stroke-only outlined
## rectangles/circles with a hint glyph — placeholder until PNG assets
## land. Width/pos mirrors the top-bar icon helper.
func _draw_mode_icon(ctrl: Control, mode_id: String, col: Color) -> void:
	var s: Vector2 = ctrl.size
	var cx: float = s.x * 0.5
	var cy: float = s.y * 0.38
	var r := 22.0
	var w := 2.5
	# Outlined square common base for all modes.
	var rect := Rect2(cx - r, cy - r, r * 2.0, r * 2.0)
	_draw_rounded_rect_outline(ctrl, rect, 6.0, col, w)
	# Glyph hint — short text inside (1-2 chars) so modes are distinguishable
	# even before PNG icons are provided.
	var font: Font = ThemeManager.font()
	if font == null:
		font = ctrl.get_theme_default_font()
	if font == null:
		return
	var glyph := ""
	match mode_id:
		"single_play": glyph = "1"
		"triple_play": glyph = "3"
		"five_play":   glyph = "5"
		"ten_play":    glyph = "10"
		"ultra_vp":    glyph = "X"
		"spin_poker":  glyph = "~"
		_:             glyph = "?"
	var fs := 20 if glyph.length() <= 1 else 16
	var gs: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	ctrl.draw_string(font, Vector2(cx - gs.x * 0.5, cy + gs.y * 0.35), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Footer gift slot — same icon+label footprint as a mode button. Label
## flips between "FREE" (ready) and "HH:MM:SS" (cooldown) in _process.
func _build_footer_gift() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(176, 136)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	var col := ThemeManager.color("sidebar_active_text", Color("FFEC00"))
	# PNG states: themes/<id>/icons/gift_ready.png + gift_waiting.png.
	# When either exists we render via TextureRect and swap textures as
	# the state changes (handled in _process via _refresh_gift_icon).
	var ready_path: String = ThemeManager.ui_icon_path("gift_ready")
	var waiting_path: String = ThemeManager.ui_icon_path("gift_waiting")
	if ready_path != "" or waiting_path != "":
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_TOP_WIDE)
		tr.offset_top = 4
		tr.offset_bottom = 96
		btn.add_child(tr)
		_gift_footer_tex = tr
		_gift_footer_ready_path = ready_path
		_gift_footer_waiting_path = waiting_path
		_refresh_gift_icon()
	else:
		_gift_footer_tex = null
		btn.draw.connect(func() -> void:
			_draw_gift_icon(btn, col)
		)
	var lab := Label.new()
	lab.text = _gift_footer_label_text()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 4)
	var theme_font: Font = ThemeManager.font()
	if theme_font != null:
		lab.add_theme_font_override("font", theme_font)
	lab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lab.offset_top = -40
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lab)
	_gift_footer_label = lab
	# Tap behavior: open the shop overlay regardless of state. The actual
	# claim must happen from the shop's own gift widget — the lobby button
	# is just a portal so the player always lands inside the store before
	# claiming (matches the trainer-skin "everything goes through the
	# shop" UX).
	btn.pressed.connect(func() -> void:
		if ShopOverlay:
			ShopOverlay.show(self)
	)
	_attach_press_effect(btn)
	return btn


func _draw_gift_icon(ctrl: Control, col: Color) -> void:
	var s: Vector2 = ctrl.size
	var cx: float = s.x * 0.5
	var cy: float = s.y * 0.38
	var r := 30.0
	var w := 3.0
	# Gift box: square outline + vertical ribbon line + top "bow" arc.
	var rect := Rect2(cx - r, cy - r * 0.75, r * 2.0, r * 1.5)
	_draw_rounded_rect_outline(ctrl, rect, 8.0, col, w)
	ctrl.draw_line(Vector2(cx, cy - r * 0.75), Vector2(cx, cy + r * 0.75), col, w)
	ctrl.draw_line(Vector2(cx - r, cy), Vector2(cx + r, cy), col, w)
	ctrl.draw_arc(Vector2(cx - r * 0.4, cy - r * 0.75), r * 0.3, 0, PI, 12, col, w)
	ctrl.draw_arc(Vector2(cx + r * 0.4, cy - r * 0.75), r * 0.3, 0, PI, 12, col, w)


## Swaps the gift TextureRect's texture between ready/waiting states.
## Called on init and from _process so state transitions follow the
## timer without rebuilding the button.
func _refresh_gift_icon() -> void:
	if _gift_footer_tex == null or not is_instance_valid(_gift_footer_tex):
		return
	var path: String = _gift_footer_ready_path if _is_gift_ready() else _gift_footer_waiting_path
	if path == "":
		# Only one of the two PNGs present — keep showing it regardless of state.
		path = _gift_footer_ready_path if _gift_footer_ready_path != "" else _gift_footer_waiting_path
	if path == "":
		return
	var current := _gift_footer_tex.texture
	if current == null or (current.resource_path if current is Resource else "") != path:
		_gift_footer_tex.texture = load(path)


func _gift_footer_label_text() -> String:
	if _is_gift_ready():
		return Translations.tr_key("common.free")
	var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
	var remaining: int = interval_sec - (int(Time.get_unix_time_from_system()) - SaveManager.last_gift_time)
	if remaining < 0:
		remaining = 0
	var h: int = remaining / 3600
	var m: int = (remaining % 3600) / 60
	var s: int = remaining % 60
	return "%02d:%02d:%02d" % [h, m, s]


## Hover overscale for any Control — slight zoom on mouse_entered, revert
## on mouse_exited. Scales around center via pivot_offset (kept in sync
## with the control's size so the bounce stays centered even if layout
## changes). Used for BaseButtons via _attach_press_effect, and directly
## for non-button controls like machine cards and the gift widget.
func _attach_hover_bounce(ctrl: Control, target_scale: float = 1.04) -> void:
	var update_pivot := func() -> void:
		if is_instance_valid(ctrl):
			ctrl.pivot_offset = ctrl.size / 2.0
	update_pivot.call()
	ctrl.resized.connect(update_pivot)
	ctrl.mouse_entered.connect(func() -> void:
		if not is_instance_valid(ctrl):
			return
		var tw := ctrl.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "scale", Vector2(target_scale, target_scale), 0.12)
	)
	ctrl.mouse_exited.connect(func() -> void:
		if not is_instance_valid(ctrl):
			return
		var tw := ctrl.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.14)
	)


## Attaches a quick scale-down/scale-up animation on press to a BaseButton,
## plus a tiny hover overscale. Scales around center via pivot_offset.
func _attach_press_effect(btn: BaseButton, target_scale: float = 0.93) -> void:
	var update_pivot := func() -> void:
		btn.pivot_offset = btn.size / 2.0
	update_pivot.call()
	btn.resized.connect(update_pivot)
	btn.button_down.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(target_scale, target_scale), 0.07)
	)
	btn.button_up.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.11)
	)
	# Ripple effect on press (anim 2.1)
	_attach_ripple(btn)
	# Hover overscale (skipped on touch-only platforms)
	btn.mouse_entered.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		if btn.button_pressed:
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		var tw := btn.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.14)
	)


## Material-style ripple: on press, a translucent circle expands from the
## click point and fades out. Uses a child overlay Control so the ripple
## draws on top of the button's texture/label regardless of draw order.
func _attach_ripple(btn: Control) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.clip_contents = true
	overlay.z_index = 10
	btn.add_child(overlay)
	var state := {"center": Vector2.ZERO, "radius": 0.0, "alpha": 0.0}
	overlay.draw.connect(func() -> void:
		if state["alpha"] > 0.001 and state["radius"] > 0.0:
			overlay.draw_circle(state["center"], state["radius"], Color(1, 1, 1, state["alpha"]))
	)
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			state["center"] = event.position
			var max_r: float = Vector2(maxf(event.position.x, btn.size.x - event.position.x), \
				maxf(event.position.y, btn.size.y - event.position.y)).length()
			state["radius"] = 0.0
			state["alpha"] = 0.55
			overlay.queue_redraw()
			var tw := overlay.create_tween().set_parallel(true)
			tw.tween_method(func(r: float) -> void:
				state["radius"] = r
				overlay.queue_redraw()
			, 0.0, max_r, 0.45).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(a: float) -> void:
				state["alpha"] = a
				overlay.queue_redraw()
			, 0.55, 0.0, 0.45).set_ease(Tween.EASE_OUT)
	)


## One-shot golden gleam diagonal sweep across a Control — used when a
## button transitions from disabled → enabled (anim 2.4).
func _gleam_once(ctrl: Control, color: Color = Color(1, 0.95, 0.3, 0.85)) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.clip_contents = true
	var state := {"t": -0.3}
	var tw := ctrl.create_tween()
	tw.tween_method(func(val: float) -> void:
		state["t"] = val
		ctrl.queue_redraw()
	, -0.3, 1.3, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	var draw_cb := func() -> void:
		var t: float = state["t"]
		if t < 0.0 or t > 1.0:
			return
		var w: float = ctrl.size.x
		var h: float = ctrl.size.y
		var cx: float = lerp(-w * 0.4, w * 1.1, t)
		var half: float = w * 0.1
		var skew: float = h * 0.6
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(cx - half, -2),
			Vector2(cx + half, -2),
			Vector2(cx + half - skew, h + 2),
			Vector2(cx - half - skew, h + 2),
		])
		ctrl.draw_colored_polygon(poly, color)
	ctrl.draw.connect(draw_cb)
	# Disconnect once the animation finishes so the gleam doesn't linger.
	tw.finished.connect(func() -> void:
		if ctrl.draw.is_connected(draw_cb):
			ctrl.draw.disconnect(draw_cb)
		ctrl.queue_redraw()
	)


## Crossfade + rotate swap between two textures on a TextureRect (anim 2.5).
## Fades current texture out with a 90° spin, swaps to `new_tex`, spins in.
func _morph_texture(tex_rect: TextureRect, new_tex: Texture2D, duration: float = 0.25) -> void:
	if not is_instance_valid(tex_rect):
		return
	tex_rect.pivot_offset = tex_rect.size * 0.5
	var half: float = duration * 0.5
	var tw := tex_rect.create_tween().set_parallel(true)
	tw.tween_property(tex_rect, "rotation", deg_to_rad(90), half).set_ease(Tween.EASE_IN)
	tw.tween_property(tex_rect, "modulate:a", 0.0, half).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		tex_rect.texture = new_tex
		tex_rect.rotation = deg_to_rad(-90)
	)
	tw.chain().tween_property(tex_rect, "rotation", 0.0, half).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex_rect, "modulate:a", 1.0, half).set_ease(Tween.EASE_OUT)


## Short "success" pop on any Control — over-scale pulse + modulate flash.
func _success_pop(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween().set_parallel(true)
	tw.tween_property(ctrl, "scale", Vector2(1.18, 1.18), 0.1).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(ctrl, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "modulate", Color(1.5, 1.5, 1.0), 0.1).from(Color.WHITE)
	tw.chain().tween_property(ctrl, "modulate", Color.WHITE, 0.2)


var _drag_active := false
var _drag_start_x := 0.0
var _drag_scroll_start := 0
var _scroll_ref: ScrollContainer = null
var _inertia_tween: Tween = null
var _velocity_samples: Array = []  # [Vector2(x, time_sec)]
var _overscroll: float = 0.0        # rubber-band offset applied to grid
var _drag_moved: bool = false        # set true once drag crosses tap-cancel threshold

const DRAG_TAP_CANCEL_PX := 10.0    # movement beyond this in any drag cancels a tap

## Asymptote of the iOS-style rubber-band curve (in pixels). At small
## drag the response is close to 1:1; as drag grows it tapers toward
## this value without ever reaching it, so a full-screen drag still
## produces visible but heavily damped motion.
const OVERSCROLL_ASYMPTOTE := 480.0
const INERTIA_MULT := 0.28
const INERTIA_DURATION := 0.85
const SPRING_DURATION := 0.7
const MIN_INERTIA_VELOCITY := 120.0
const FLING_OVERSHOOT_MULT := 0.55  # inertia-past-edge peak = excess * this


## Rubber-band mapping: input = raw drag distance (≥ 0), output is the
## attenuated overscroll distance. Formula `drag * A / (drag + A)` — at
## drag=0 it's 0, at drag→∞ it approaches A. Progressive resistance.
func _rubber_band(drag: float) -> float:
	if drag <= 0.0:
		return 0.0
	return drag * OVERSCROLL_ASYMPTOTE / (drag + OVERSCROLL_ASYMPTOTE)

# On web the mouse/touch-drag direction feels reversed vs. native; flip the
# drag delta + velocity sign so swipe gestures behave naturally in-browser.
var _drag_sign: float = -1.0 if OS.has_feature("web") else 1.0

# Content node whose position.x gets offset for the rubber-band effect
# (defaults to the lobby grid; swapped to the shop row when the shop opens).
var _drag_content: Control = null
# Callable returning the global rect where drag input is accepted.
# Lobby → the grid scroll; shop → the full shop overlay.
var _drag_hit_rect_fn: Callable = Callable()


## Public: machine cards call this in their release handler to decide
## whether a short press should count as a tap (false) or was absorbed by a
## carousel swipe (true).
func carousel_drag_moved() -> bool:
	return _drag_moved


## Scrollbar is always invisible — the carousel handles its own drag/
## overscroll visuals, so fading the scrollbar in during drag was
## redundant. Kept as a no-op so existing call sites still work.
func _fade_scrollbar(_visible: bool) -> void:
	pass


func _setup_drag_scroll(scroll: ScrollContainer) -> void:
	_scroll_ref = scroll
	_drag_content = _grid
	_drag_hit_rect_fn = func() -> Rect2: return _scroll_ref.get_global_rect() if _scroll_ref else Rect2()


func _max_scroll() -> int:
	return maxi(int(_scroll_ref.get_h_scroll_bar().max_value) - int(_scroll_ref.size.x), 0)


func _set_overscroll(val: float) -> void:
	_overscroll = val
	if _drag_content and _scroll_ref:
		_drag_content.position.x = float(-_scroll_ref.scroll_horizontal) + val + _centering_offset()


## When the grid's natural width is smaller than the scroll viewport
## (all tiles fit on-screen → nothing to scroll), return the horizontal
## offset that centers the grid within the scroll. Otherwise 0.
## The value is added to position.x every frame in _process so
## ScrollContainer's layout pass can't strip it.
func _centering_offset() -> float:
	if _scroll_ref == null or _grid == null:
		return 0.0
	var cw: float = _grid.get_combined_minimum_size().x
	var sw: float = _scroll_ref.size.x
	if cw >= sw:
		return 0.0
	return (sw - cw) * 0.5


func _calc_velocity() -> float:
	# Use samples from the last ~150 ms for a smoothed throw-velocity
	if _velocity_samples.size() < 2:
		return 0.0
	var last: Vector2 = _velocity_samples[_velocity_samples.size() - 1]
	var start: Vector2 = _velocity_samples[0]
	for s in _velocity_samples:
		var v: Vector2 = s
		if last.y - v.y <= 0.15:
			start = v
			break
	var dt: float = last.y - start.y
	if dt < 0.001:
		return 0.0
	return (start.x - last.x) / dt * _drag_sign  # px/sec; positive = fling forward


func _input(event: InputEvent) -> void:
	if _scroll_ref == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var scroll_rect: Rect2 = _drag_hit_rect_fn.call() if _drag_hit_rect_fn.is_valid() else _scroll_ref.get_global_rect()
			if scroll_rect.has_point(event.global_position):
				_drag_active = true
				_drag_moved = false
				_drag_start_x = event.global_position.x
				_drag_scroll_start = _scroll_ref.scroll_horizontal
				_velocity_samples.clear()
				_velocity_samples.append(Vector2(event.global_position.x, Time.get_ticks_msec() / 1000.0))
				if _inertia_tween and _inertia_tween.is_running():
					_inertia_tween.kill()
				_fade_scrollbar(true)
		else:
			if _drag_active:
				_drag_active = false
				_release_drag(_calc_velocity())
				_fade_scrollbar(false)
	elif event is InputEventMouseMotion and _drag_active:
		var now: float = Time.get_ticks_msec() / 1000.0
		_velocity_samples.append(Vector2(event.global_position.x, now))
		while _velocity_samples.size() > 8:
			_velocity_samples.pop_front()
		var delta: float = (_drag_start_x - event.global_position.x) * _drag_sign
		if not _drag_moved and absf(_drag_start_x - event.global_position.x) > DRAG_TAP_CANCEL_PX:
			_drag_moved = true
		var target: int = _drag_scroll_start + int(delta)
		var m: int = _max_scroll()
		if target < 0:
			_scroll_ref.scroll_horizontal = 0
			_set_overscroll(_rubber_band(float(-target)))
		elif target > m:
			_scroll_ref.scroll_horizontal = m
			_set_overscroll(-_rubber_band(float(target - m)))
		else:
			_scroll_ref.scroll_horizontal = target
			_set_overscroll(0.0)


func _release_drag(velocity: float) -> void:
	if _inertia_tween and _inertia_tween.is_running():
		_inertia_tween.kill()

	# Already overscrolled: spring back.
	if absf(_overscroll) > 0.5:
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, _overscroll, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		return

	if absf(velocity) < MIN_INERTIA_VELOCITY:
		return

	var current: int = _scroll_ref.scroll_horizontal
	var m: int = _max_scroll()
	var target: int = current + int(velocity * INERTIA_MULT)

	if target < 0:
		# Inertia carries past the left edge → overshoot then spring back.
		# Phase 1 decelerates to peak (v→0). Phase 2 returns to 0 via SINE
		# EASE_IN_OUT so it also starts at v=0, avoiding the velocity
		# discontinuity at the peak that looked like an extra bounce.
		var excess: float = float(-target)
		var peak: float = -_rubber_band(excess * FLING_OVERSHOOT_MULT)
		_scroll_ref.scroll_horizontal = 0
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, 0.0, peak, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_inertia_tween.tween_method(_set_overscroll, peak, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	elif target > m:
		var excess2: float = float(target - m)
		var peak2: float = _rubber_band(excess2 * FLING_OVERSHOOT_MULT)
		_scroll_ref.scroll_horizontal = m
		_inertia_tween = create_tween()
		_inertia_tween.tween_method(_set_overscroll, 0.0, -peak2, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_inertia_tween.tween_method(_set_overscroll, -peak2, 0.0, SPRING_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		_inertia_tween = create_tween()
		_inertia_tween.tween_property(_scroll_ref, "scroll_horizontal", target, INERTIA_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


func _build_carousel() -> void:
	_machine_cards.clear()
	# Clear existing children
	for child in _grid.get_children():
		child.queue_free()
	# Get machine list for current mode
	var mode_machines: Array = []
	if _active_mode < PLAY_MODES.size():
		mode_machines = PLAY_MODES[_active_mode].get("machines", [])

	# Build a quick lookup: machine_id → MACHINE_CONFIG entry.
	var config_by_id: Dictionary = {}
	for c in MACHINE_CONFIG:
		config_by_id[c["id"]] = c

	# Collect configs in the order defined by the mode's `machines` list
	# (from lobby_order.json). If the mode has no list, fall back to
	# MACHINE_CONFIG source order.
	var configs: Array = []
	if mode_machines.size() > 0:
		for mm in mode_machines:
			if not mm.get("enabled", true):
				continue
			var mid: String = mm.get("id", "")
			if mid in config_by_id:
				configs.append(config_by_id[mid])
	else:
		for c in MACHINE_CONFIG:
			configs.append(c)

	# Center layout rule: ALWAYS 2 rows, columns grow with count so a
	# longer machine list just extends the strip horizontally (rubber
	# band + h-scroll do the rest) instead of wrapping into more rows.
	const FIXED_ROWS := 2
	_grid.columns = maxi(int(ceil(float(configs.size()) / float(FIXED_ROWS))), 1)

	# GridContainer fills row-major (left→right, top→bottom). We want the
	# visual order to be COLUMN-MAJOR (top→bottom within each column, columns
	# left→right), so remap the add order: visual (row, col) gets
	# configs[col * rows + row].
	var cols: int = maxi(int(_grid.columns), 1)
	var rows: int = int(ceil(float(configs.size()) / float(cols)))
	for row in range(rows):
		for col in range(cols):
			var src_idx: int = col * rows + row
			if src_idx >= configs.size():
				continue
			var config: Dictionary = configs[src_idx]
			var machine_id: String = config["id"]
			var card_node: PanelContainer = MachineCardScene.instantiate()
			_grid.add_child(card_node)
			var rtp: float = 0.0
			if machine_id in _paytables:
				rtp = _paytables[machine_id].rtp
			var mini_text := Translations.tr_key("machine.%s.mini" % machine_id)
			var icon_path := _icon_path_for(machine_id)
			card_node.setup(
				machine_id,
				icon_path,
				_mode_card_color(),
				config["accent"],
				rtp,
				mini_text,
				config["locked"],
			)
			card_node.play_pressed.connect(_on_play_pressed)
			# Hover bounce removed — tile stays static on mouse-over.
			# _attach_hover_bounce(card_node)
			# Decorative shimmer sweep (anim 1.2): fast highlight pass.
			# 1s sweep + 10.2s pause = 11.2s total cycle; alpha 0.35.
			# PanelContainer's content_margin (22/26px) would inset this child
			# to the logo area only — so we override position/size to span the
			# card's full rect after each container sort.
			var shim_host := Control.new()
			shim_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shim_host.clip_contents = true
			card_node.add_child(shim_host)
			# Bind shim_host to the tile's actual visible rect (PNG artwork
			# for icon mode, full card for text mode). This keeps the
			# sweep glow inside the visible art instead of sweeping over
			# the invisible letterbox margins on the container.
			var fix_shim_rect := func() -> void:
				if not (is_instance_valid(shim_host) and is_instance_valid(card_node)):
					return
				# PNG tiles run their own shader-based shimmer inside the
				# TextureRect (alpha-masked by the artwork). Disable the
				# external polygon overlay to avoid a visible double sweep.
				if card_node.has_method("has_png_art") and card_node.has_png_art():
					shim_host.visible = false
					return
				shim_host.visible = true
				var r: Rect2 = card_node.visible_rect() \
					if card_node.has_method("visible_rect") \
					else Rect2(Vector2.ZERO, card_node.size)
				shim_host.position = r.position
				shim_host.size = r.size
			card_node.sort_children.connect(fix_shim_rect)
			card_node.resized.connect(fix_shim_rect)
			# Also re-align when the tile's texture or size becomes known
			# (initial texture load + apply_tile_size both emit this).
			card_node.visual_ready.connect(fix_shim_rect)
			fix_shim_rect.call_deferred()
			_attach_shimmer_sweep(shim_host, 1.0, Color(1, 1, 1, 0.09), 10.2)
			_machine_cards.append(card_node)

	# Stagger fade-in: cards appear sequentially with a tiny scale pop.
	# NOTE: cards live inside a GridContainer, which overrides child position
	# every layout pass — so we animate modulate + scale only (pivot-based),
	# never position.
	call_deferred("_play_stagger_fade_in")
	call_deferred("_update_tile_sizes")


func _play_stagger_fade_in() -> void:
	# Visual order: column-major (top→bottom within each column, columns L→R).
	# Cards are added row-major, so remap add-index → visual order.
	var cols: int = maxi(int(_grid.columns), 1)
	var total: int = _machine_cards.size()
	var rows: int = int(ceil(float(total) / float(cols)))
	for i in total:
		var card: Control = _machine_cards[i]
		if not is_instance_valid(card):
			continue
		var row: int = i / cols
		var col: int = i % cols
		var visual_idx: int = col * rows + row
		card.modulate.a = 0.0
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.94, 0.94)
		var delay: float = 0.05 + float(visual_idx) * 0.033
		var tw := card.create_tween().set_parallel(true)
		tw.tween_interval(delay)
		tw.chain().tween_property(card, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.32) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _mode_card_color() -> Color:
	if _active_mode >= 0 and _active_mode < PLAY_MODES.size():
		var mode_id: String = PLAY_MODES[_active_mode].get("id", "single_play")
		return MODE_CARD_COLORS.get(mode_id, MODE_CARD_COLORS["single_play"])
	return MODE_CARD_COLORS["single_play"]


# Icon filename prefix per variant_id (assets/themes/<theme>/machines/{prefix}_{suffix}.png)
const ICON_VARIANT_PREFIX := {
	"jacks_or_better":     "jacks_or_better",
	"bonus_poker":         "bonus_poker",
	"bonus_poker_deluxe":  "bonus_deluxe",
	"double_bonus":        "double_bonus",
	"double_double_bonus": "double_double_bonus",
	"triple_double_bonus": "triple_double_bonus",
	"aces_and_faces":      "aces_faces",
	"deuces_wild":         "deuces_wild",
	"joker_poker":         "joker_poker",
	"deuces_and_joker":    "deuces_joker",
}

# Icon filename suffix per play-mode id
const ICON_MODE_SUFFIX := {
	"single_play": "classic",
	"triple_play": "multi",
	"five_play":   "multi",
	"ten_play":    "multi",
	"ultra_vp":    "ultra",
	"spin_poker":  "spin",
}


func _icon_path_for(variant_id: String) -> String:
	var prefix: String = ICON_VARIANT_PREFIX.get(variant_id, variant_id)
	var mode_id: String = "single_play"
	if _active_mode >= 0 and _active_mode < PLAY_MODES.size():
		mode_id = PLAY_MODES[_active_mode].get("id", "single_play")
	var suffix: String = ICON_MODE_SUFFIX.get(mode_id, "classic")
	# Theme-scoped path (assets/themes/<theme>/machines/<prefix>_<suffix>.png).
	# ThemeManager returns "" when the theme has no PNG — caller stays
	# safe because machine_card falls back to its text layout.
	return ThemeManager.machine_icon_path(prefix, suffix)


func _on_play_pressed(variant_id: String) -> void:
	SaveManager.last_variant = variant_id
	# Zoom-in on the tapped card (anim 6.2) before the transition
	for card in _machine_cards:
		if is_instance_valid(card) and card.variant_id == variant_id:
			if card.has_method("play_zoom_in"):
				card.play_zoom_in(0.3)
			break
	machine_selected.emit(variant_id)


func refresh_credits() -> void:
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))


# --- Settings popup ----------------------------------------------------------

var _settings_btn: BaseButton
var _settings_overlay: Control = null
var _settings_panel: Control = null
var _settings_dim: ColorRect = null
var _support_overlay: Control = null

func _show_settings() -> void:
	if _settings_overlay:
		return
	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.z_index = 100
	add_child(_settings_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_settings()
	)
	_settings_overlay.add_child(dim)
	_settings_dim = dim

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.18, 0.96)
	pstyle.set_border_width_all(3)
	pstyle.border_color = Color("FFEC00")
	pstyle.set_corner_radius_all(12)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_settings_overlay.add_child(panel)
	_settings_panel = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("settings.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	vbox.add_child(title)

	# LANGUAGE row — hidden while Translations.FORCE_ENGLISH is true.
	# To restore: flip the FORCE_ENGLISH constant in translations.gd and delete
	# this conditional (the block is preserved below for easy re-enable).
	if not Translations.FORCE_ENGLISH:
		var current := Translations.get_saved_language()
		var lang_btn := Button.new()
		lang_btn.text = "%s: %s" % [
			Translations.tr_key("settings.language"),
			Translations.display_name_for_code(current),
		]
		lang_btn.custom_minimum_size = Vector2(280, 56)
		_style_lang_btn(lang_btn, false)
		lang_btn.pressed.connect(_show_language_picker)
		vbox.add_child(lang_btn)

	# Music toggle
	var music_on: bool = SaveManager.settings.get("music", true)
	var music_btn := Button.new()
	music_btn.text = "%s: %s" % [
		Translations.tr_key("settings.music"),
		Translations.tr_key("common.on") if music_on else Translations.tr_key("common.off"),
	]
	music_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(music_btn, music_on)
	music_btn.pressed.connect(func() -> void:
		var new_val: bool = not SaveManager.settings.get("music", true)
		SoundManager.set_music_enabled(new_val)
		music_btn.text = "%s: %s" % [
			Translations.tr_key("settings.music"),
			Translations.tr_key("common.on") if new_val else Translations.tr_key("common.off"),
		]
		_style_lang_btn(music_btn, new_val)
	)
	vbox.add_child(music_btn)

	# Sound FX toggle
	var sfx_on: bool = SaveManager.settings.get("sound_fx", true)
	var sfx_btn := Button.new()
	sfx_btn.text = "%s: %s" % [
		Translations.tr_key("settings.sound_fx"),
		Translations.tr_key("common.on") if sfx_on else Translations.tr_key("common.off"),
	]
	sfx_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(sfx_btn, sfx_on)
	sfx_btn.pressed.connect(func() -> void:
		var new_val: bool = not SaveManager.settings.get("sound_fx", true)
		SoundManager.set_sfx_enabled(new_val)
		sfx_btn.text = "%s: %s" % [
			Translations.tr_key("settings.sound_fx"),
			Translations.tr_key("common.on") if new_val else Translations.tr_key("common.off"),
		]
		_style_lang_btn(sfx_btn, new_val)
	)
	vbox.add_child(sfx_btn)

	# Vibration toggle
	var vib_on: bool = SaveManager.settings.get("vibration", true)
	var vib_btn := Button.new()
	vib_btn.text = "%s: %s" % [
		Translations.tr_key("settings.vibration"),
		Translations.tr_key("common.on") if vib_on else Translations.tr_key("common.off"),
	]
	vib_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(vib_btn, vib_on)
	vib_btn.pressed.connect(func() -> void:
		var new_val: bool = not SaveManager.settings.get("vibration", true)
		SaveManager.settings["vibration"] = new_val
		SaveManager.save_game()
		vib_btn.text = "%s: %s" % [
			Translations.tr_key("settings.vibration"),
			Translations.tr_key("common.on") if new_val else Translations.tr_key("common.off"),
		]
		_style_lang_btn(vib_btn, new_val)
	)
	vbox.add_child(vib_btn)

	# Animation speed toggle — cycles 1..4 (internal 0..3). Preserves choice
	# in SaveManager.speed_level so game + multi_hand screens pick it up.
	var speed_btn := Button.new()
	var _speed_label := func(level: int) -> String:
		return "%s: %d/4" % [Translations.tr_key("settings.speed"), level + 1]
	speed_btn.text = _speed_label.call(SaveManager.speed_level)
	speed_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(speed_btn, false)
	speed_btn.pressed.connect(func() -> void:
		SaveManager.speed_level = (SaveManager.speed_level + 1) % 4
		SaveManager.save_game()
		speed_btn.text = _speed_label.call(SaveManager.speed_level)
	)
	vbox.add_child(speed_btn)

	# Privacy policy — opens GitHub Pages page in system browser.
	var privacy_btn := Button.new()
	privacy_btn.text = Translations.tr_key("settings.privacy_policy")
	privacy_btn.custom_minimum_size = Vector2(280, 56)
	_style_lang_btn(privacy_btn, false)
	privacy_btn.pressed.connect(func() -> void:
		OS.shell_open("https://vadosina-git.github.io/privacy-policy/video-poker-privacy.html")
	)
	vbox.add_child(privacy_btn)

	# Trainer disclaimer — supercell-only framing.
	if ThemeManager.current_id == "supercell":
		var disc_spacer := Control.new()
		disc_spacer.custom_minimum_size = Vector2(0, 6)
		vbox.add_child(disc_spacer)
		var disc := Label.new()
		disc.text = Translations.tr_key("trainer.disclaimer")
		disc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		disc.add_theme_font_size_override("font_size", 13)
		disc.add_theme_color_override("font_color", Color.WHITE)
		disc.custom_minimum_size = Vector2(360, 0)
		disc.modulate = Color(1, 1, 1, 0.78)
		vbox.add_child(disc)

	# Close button
	var close_btn := Button.new()
	close_btn.text = Translations.tr_key("settings.close")
	close_btn.custom_minimum_size = Vector2(280, 48)
	_style_lang_btn(close_btn, false)
	close_btn.pressed.connect(_hide_settings)
	vbox.add_child(close_btn)

	# Delete account button (red, at bottom)
	var del_btn := Button.new()
	del_btn.text = Translations.tr_key("settings.delete_account")
	del_btn.custom_minimum_size = Vector2(280, 48)
	var del_style := StyleBoxFlat.new()
	del_style.bg_color = Color(0.6, 0.1, 0.1)
	del_style.set_border_width_all(2)
	del_style.border_color = Color(0.8, 0.2, 0.2)
	del_style.set_corner_radius_all(8)
	del_btn.add_theme_stylebox_override("normal", del_style)
	var del_hover := del_style.duplicate()
	del_hover.bg_color = Color(0.7, 0.15, 0.15)
	del_btn.add_theme_stylebox_override("hover", del_hover)
	del_btn.add_theme_font_size_override("font_size", 18)
	del_btn.add_theme_color_override("font_color", Color.WHITE)
	del_btn.pressed.connect(_delete_account_step1)
	_attach_press_effect(del_btn)
	vbox.add_child(del_btn)


func _style_lang_btn(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.53) if active else Color(0.12, 0.12, 0.35)
	style.set_border_width_all(3)
	style.border_color = Color(0.85, 0.7, 0.2) if active else Color(0.3, 0.3, 0.5)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color("FFEC00") if active else Color.WHITE)
	_attach_press_effect(btn)


func _delete_account_step1() -> void:
	_hide_settings()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 110
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.8)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.3, 0.05, 0.05, 0.95)
	ps.set_border_width_all(3)
	ps.border_color = Color(0.8, 0.2, 0.2)
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
	msg.text = Translations.tr_key("settings.delete_confirm_1")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size.x = 400
	vbox.add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)
	var cancel := Button.new()
	cancel.text = Translations.tr_key("settings.delete_cancel")
	cancel.custom_minimum_size = Vector2(140, 44)
	_style_lang_btn(cancel, false)
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(cancel)
	var cont := Button.new()
	cont.text = Translations.tr_key("settings.delete_continue")
	cont.custom_minimum_size = Vector2(140, 44)
	_style_lang_btn(cont, true)
	cont.pressed.connect(func() -> void:
		overlay.queue_free()
		_delete_account_step2()
	)
	btns.add_child(cont)


func _delete_account_step2() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 110
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.8)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.4, 0.05, 0.05, 0.95)
	ps.set_border_width_all(3)
	ps.border_color = Color(1, 0.2, 0.2)
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
	msg.text = Translations.tr_key("settings.delete_confirm_2")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size.x = 400
	vbox.add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)
	var cancel := Button.new()
	cancel.text = Translations.tr_key("settings.delete_cancel")
	cancel.custom_minimum_size = Vector2(140, 44)
	_style_lang_btn(cancel, false)
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	btns.add_child(cancel)
	var del := Button.new()
	del.text = Translations.tr_key("settings.delete_confirm")
	del.custom_minimum_size = Vector2(140, 44)
	var del_style := StyleBoxFlat.new()
	del_style.bg_color = Color(0.7, 0.1, 0.1)
	del_style.set_border_width_all(2)
	del_style.border_color = Color(1, 0.3, 0.3)
	del_style.set_corner_radius_all(8)
	del.add_theme_stylebox_override("normal", del_style)
	del.add_theme_font_size_override("font_size", 22)
	del.add_theme_color_override("font_color", Color.WHITE)
	del.pressed.connect(func() -> void:
		overlay.queue_free()
		_perform_account_delete()
	)
	_attach_press_effect(del)
	btns.add_child(del)


func _perform_account_delete() -> void:
	# Clear save file
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	# Reset to defaults
	SaveManager.credits = ConfigManager.get_starting_balance()
	SaveManager.denomination = 1
	SaveManager.hand_count = 1
	SaveManager.ultra_vp = false
	SaveManager.spin_poker = false
	SaveManager.speed_level = 1
	SaveManager.bet_level = 1
	SaveManager.depth_hint_shown = false
	# Reset all cooldown timers so gifts + free-timed packs are claimable right away.
	SaveManager.last_gift_time = 0
	SaveManager.pack_claim_times.clear()
	SaveManager.save_game()
	# Refresh lobby
	SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(SaveManager.credits))
	# Force gift widget to re-evaluate readiness (shows COLLECT state immediately).
	_gift_ready = false
	_update_gift_state()


func _hide_settings() -> void:
	_hide_language_picker()
	if _settings_overlay:
		_settings_overlay.queue_free()
		_settings_overlay = null
		_settings_panel = null
		_settings_dim = null


## Support popup — a scrollable list of per-mode rules. Hidden modes
## (disabled in lobby_order.json) don't show their rules, matching the
## "if a mode is hidden on the client, its rules stay hidden" rule.
func _show_support() -> void:
	if _support_overlay:
		return
	_support_overlay = Control.new()
	_support_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_support_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_support_overlay.z_index = 100
	add_child(_support_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_hide_support()
	)
	_support_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(640, 720)
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = ThemeManager.color("panel_bg", Color(0.05, 0.05, 0.18, 0.98))
	pstyle.set_border_width_all(int(ThemeManager.size("border_width", 3)))
	pstyle.border_color = ThemeManager.color("panel_border", Color("FFEC00"))
	pstyle.set_corner_radius_all(int(ThemeManager.size("corner_radius", 12)))
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_support_overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = Translations.tr_key("support.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ThemeManager.color("title_text", Color.WHITE))
	title.add_theme_color_override("font_outline_color", ThemeManager.color("title_outline", Color.BLACK))
	title.add_theme_constant_override("outline_size", 4)
	var theme_font: Font = ThemeManager.font()
	if theme_font != null:
		title.add_theme_font_override("font", theme_font)
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	for mode in PLAY_MODES:
		var mode_id: String = mode.get("id", "")
		var title_key := "support.%s_title" % mode_id
		var rules_key := "support.%s_rules" % mode_id
		var section_title := Label.new()
		section_title.text = Translations.tr_key(title_key)
		section_title.add_theme_font_size_override("font_size", 22)
		section_title.add_theme_color_override("font_color",
			ThemeManager.color("sidebar_active_text", Color("FFEC00")))
		if theme_font != null:
			section_title.add_theme_font_override("font", theme_font)
		body.add_child(section_title)

		var rules := Label.new()
		rules.text = Translations.tr_key(rules_key)
		rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rules.add_theme_font_size_override("font_size", 17)
		rules.add_theme_color_override("font_color", ThemeManager.color("body_text", Color.WHITE))
		body.add_child(rules)

	# Trainer disclaimer — supercell only. Classic keeps its original
	# casino-app framing (per app store metadata for that build).
	if ThemeManager.current_id == "supercell":
		var disc_spacer := Control.new()
		disc_spacer.custom_minimum_size = Vector2(0, 8)
		body.add_child(disc_spacer)
		var disc := Label.new()
		disc.text = Translations.tr_key("trainer.disclaimer")
		disc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		disc.add_theme_font_size_override("font_size", 14)
		disc.add_theme_color_override("font_color", ThemeManager.color("body_text", Color.WHITE))
		if theme_font != null:
			disc.add_theme_font_override("font", theme_font)
		disc.modulate = Color(1, 1, 1, 0.78)
		body.add_child(disc)

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
	close.pressed.connect(_hide_support)
	vb.add_child(close)

	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _hide_support() -> void:
	if _support_overlay:
		_support_overlay.queue_free()
		_support_overlay = null


# --- Language picker (sub-popup of settings) ---

var _lang_picker_overlay: Control = null

func _show_language_picker() -> void:
	if _lang_picker_overlay:
		return
	_lang_picker_overlay = Control.new()
	_lang_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lang_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_lang_picker_overlay.z_index = 110  # above the settings popup
	add_child(_lang_picker_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_language_picker()
	)
	_lang_picker_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.18, 0.98)
	pstyle.set_border_width_all(3)
	pstyle.border_color = Color("FFEC00")
	pstyle.set_corner_radius_all(12)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_lang_picker_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Translations.tr_key("settings.language")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("FFEC00"))
	vbox.add_child(title)

	var current := Translations.get_saved_language()
	for code in Translations.get_available_codes():
		var btn := Button.new()
		btn.text = Translations.display_name_for_code(code)
		btn.custom_minimum_size = Vector2(280, 56)
		_style_lang_btn(btn, code == current)
		btn.pressed.connect(_on_language_chosen.bind(code))
		vbox.add_child(btn)


func _hide_language_picker() -> void:
	if _lang_picker_overlay:
		_lang_picker_overlay.queue_free()
		_lang_picker_overlay = null


func _on_language_chosen(code: String) -> void:
	_hide_language_picker()
	if code == Translations.get_saved_language():
		_hide_settings()
		return
	Translations.set_language(code)
	# Force a full game reload so every cached label / built scene updates.
	get_tree().call_deferred("reload_current_scene")


# --- Gift widget ---

const GIFT_ICON_SIZE := 56  # matches pill height so the icon never exceeds button bounds
const GIFT_BTN_W := 180
const GIFT_BTN_H := 56
const GIFT_ICON_OVERLAP := 22  # icon overlaps pill button by this much on left

var _gift_btn: Control = null
var _gift_icon_rect: TextureRect = null
var _gift_label_area: VBoxContainer = null
var _gift_ready: bool = false


func _build_gift_widget() -> void:
	var top_bar := $VBoxContainer/TopBar as HBoxContainer

	var widget_w: int = GIFT_ICON_SIZE + GIFT_BTN_W - GIFT_ICON_OVERLAP
	var widget_h: int = GIFT_ICON_SIZE

	var root := Control.new()
	root.custom_minimum_size = Vector2(widget_w, widget_h)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.pivot_offset = Vector2(widget_w, widget_h) * 0.5

	# Transparent pill — only the gift icon + countdown text are visible;
	# no fill, no border, consistent with the rest of the "floating" lobby.
	var pill := Panel.new()
	pill.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	pill.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	pill.custom_minimum_size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	pill.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)

	# Label area centered on the pill (text is rebuilt by _update_gift_state)
	_gift_label_area = VBoxContainer.new()
	_gift_label_area.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	_gift_label_area.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	_gift_label_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_gift_label_area.add_theme_constant_override("separation", 0)
	_gift_label_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gift_label_area)

	# Icon (overlaps pill on the left)
	_gift_icon_rect = TextureRect.new()
	_gift_icon_rect.position = Vector2(0, 0)
	_gift_icon_rect.size = Vector2(GIFT_ICON_SIZE, GIFT_ICON_SIZE)
	_gift_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gift_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gift_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gift_icon_rect)

	root.gui_input.connect(_on_gift_gui_input)
	# Hover bounce (anim 2.2) — applies in both ready + countdown states
	_attach_hover_bounce(root)
	_gift_btn = root

	if not ConfigManager.is_visible("show_lobby_gift_button", true):
		_gift_btn.queue_free()
		_gift_btn = null
		return
	top_bar.add_child(_gift_btn)
	if is_instance_valid(_settings_btn):
		top_bar.move_child(_gift_btn, _settings_btn.get_index())
	# Force initial rebuild of labels + icon
	_gift_ready = not _is_gift_ready()
	_update_gift_state()


func _process(_delta: float) -> void:
	# Clamp vertical scroll to 0 every frame — SHOW_NEVER hides the bar
	# but still allows wheel/touch scrolling on a few residual pixels.
	# Since the grid is sized to match the scroll height exactly, there's
	# nothing to scroll vertically — we just null it out.
	if _scroll_ref and _scroll_ref.scroll_vertical != 0:
		_scroll_ref.scroll_vertical = 0
	# Gift footer label + ready-state repaint. Cheap: only rebuilds text,
	# not the whole footer. Icon swap happens inside _refresh_gift_icon.
	if is_instance_valid(_gift_footer_label):
		_gift_footer_label.text = _gift_footer_label_text()
	_refresh_gift_icon()
	# Store notification dot reflects availability of any free reward.
	_refresh_shop_badge()
	# Keep shop-side timer in sync while gift is recharging
	if _shop_gift_label_area and is_instance_valid(_shop_gift_label_area) and not _gift_ready:
		var shop_timer := _shop_gift_label_area.get_node_or_null("Timer") as Label
		if shop_timer:
			var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
			var remaining: int = interval_sec - (int(Time.get_unix_time_from_system()) - SaveManager.last_gift_time)
			var h: int = remaining / 3600
			var m: int = (remaining % 3600) / 60
			var s: int = remaining % 60
			shop_timer.text = "%dH %dM %dS" % [h, m, s]
	# Re-apply rubber-band offset + centering offset after ScrollContainer's
	# sort resets content.position. Centering only triggers when the grid
	# is narrower than the viewport (few-machine case).
	if _drag_content and _scroll_ref:
		var centering: float = _centering_offset()
		if _overscroll != 0.0 or centering != 0.0:
			_drag_content.position.x = float(-_scroll_ref.scroll_horizontal) + _overscroll + centering


func _is_gift_ready() -> bool:
	var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - SaveManager.last_gift_time
	return elapsed >= interval_sec or SaveManager.last_gift_time == 0


func _update_gift_state() -> void:
	if not _gift_icon_rect or not _gift_label_area:
		return
	var ready: bool = _is_gift_ready()
	if ready != _gift_ready:
		_gift_ready = ready
		_rebuild_gift_content(ready)
	if not ready:
		var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
		var remaining: int = interval_sec - (int(Time.get_unix_time_from_system()) - SaveManager.last_gift_time)
		var h: int = remaining / 3600
		var m: int = (remaining % 3600) / 60
		var s: int = remaining % 60
		var timer_label := _gift_label_area.get_node_or_null("Timer") as Label
		if timer_label:
			timer_label.text = "%dH %dM %dS" % [h, m, s]


func _rebuild_gift_content(ready: bool) -> void:
	for child in _gift_label_area.get_children():
		_gift_label_area.remove_child(child)
		child.queue_free()

	if ready:
		_gift_icon_rect.texture = load("res://assets/shop/gift_box_ready_icon.png")

		var collect_label := Label.new()
		collect_label.text = Translations.tr_key("gift.daily_bonus")
		collect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		collect_label.add_theme_font_size_override("font_size", 18)
		collect_label.add_theme_color_override("font_color", Color.WHITE)
		_gift_label_area.add_child(collect_label)

		var amount_hb := HBoxContainer.new()
		amount_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		amount_hb.add_theme_constant_override("separation", 4)
		amount_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Chip glyph — texture will be swapped by user later.
		var chip_tex: Texture2D = SaveManager.get_chip_texture()
		if chip_tex:
			var chip := TextureRect.new()
			chip.texture = chip_tex
			chip.custom_minimum_size = Vector2(20, 20)
			chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.modulate = Color("FFEC00")
			amount_hb.add_child(chip)

		var amount_lab := Label.new()
		amount_lab.add_theme_font_size_override("font_size", 18)
		amount_lab.add_theme_color_override("font_color", Color("FFEC00"))
		amount_lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		amount_lab.add_theme_constant_override("outline_size", 2)
		_set_chip_amount_text(amount_lab, ConfigManager.get_gift_chips(), GIFT_BTN_W - 40)
		amount_hb.add_child(amount_lab)
		_gift_label_area.add_child(amount_hb)
	else:
		_gift_icon_rect.texture = load("res://assets/shop/gift_box_icon.png")

		var timer_label := Label.new()
		timer_label.name = "Timer"
		timer_label.text = "--H --M --S"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 22)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		timer_label.add_theme_constant_override("outline_size", 3)
		_gift_label_area.add_child(timer_label)


## Pulses a "COLLECT!" label (or any label) with a gentle scale loop.
## Tween is bound to the label, so it auto-dies when the label is freed.
func _pulse_collect_label(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	label.resized.connect(func() -> void: label.pivot_offset = label.size * 0.5)
	var tw := label.create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "scale", Vector2(1.08, 1.08), 0.45).from(Vector2.ONE)
	tw.tween_property(label, "scale", Vector2.ONE, 0.45)


## Sets chip-count text on a label, switching to the short format ("1.2M")
## if the full comma-separated form wouldn't fit within `max_w` pixels.
func _set_chip_amount_text(label: Label, amount: int, max_w: float) -> void:
	label.text = SaveManager.format_money(amount)
	var min_size: Vector2 = label.get_minimum_size()
	if min_size.x > max_w:
		label.text = SaveManager.format_short(amount)


func _on_gift_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_gift_press_tween(true)
		else:
			_gift_press_tween(false)
			_on_gift_pressed()


func _gift_press_tween(down: bool) -> void:
	if not is_instance_valid(_gift_btn):
		return
	var target: Vector2 = Vector2(0.93, 0.93) if down else Vector2.ONE
	var dur: float = 0.07 if down else 0.11
	var tw := _gift_btn.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gift_btn, "scale", target, dur)


func _on_gift_pressed() -> void:
	if not _gift_ready:
		return
	# When the gift is ready, the top-bar gift widget opens the shop; the
	# shop itself shows a duplicate gift widget that actually claims the reward.
	_show_shop()


func _claim_gift_reward(from_pos: Vector2 = Vector2.ZERO) -> void:
	if not _is_gift_ready():
		return
	var chips: int = ConfigManager.get_gift_chips()
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(chips)
	SaveManager.last_gift_time = int(Time.get_unix_time_from_system())
	SaveManager.save_game()
	_gift_ready = false
	_update_gift_state()
	SoundManager.play("gift_claim")
	# Shop-side widget stays visible; just swap to the timer state.
	if _shop_gift_widget and is_instance_valid(_shop_gift_widget):
		_rebuild_shop_gift_content(false)
	if from_pos != Vector2.ZERO:
		_spawn_confetti_burst(from_pos)
		_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)
	else:
		_animate_balance_increment(old_credits, SaveManager.credits, 0.9)


## Returns the currency_display dict of the currently visible balance pill.
## Shop pill while shop is open, lobby pill otherwise.
func _active_cash_cd() -> Dictionary:
	if _shop_overlay and not _shop_cash_cd.is_empty():
		return _shop_cash_cd
	return _cash_cd


## Returns the PanelContainer of the currently visible balance pill.
func _active_cash_pill() -> Control:
	if _shop_overlay and is_instance_valid(_shop_cash_pill):
		return _shop_cash_pill
	return _cash_pill


func _animate_balance_increment(from: int, to: int, duration: float) -> void:
	var target_cd: Dictionary = _active_cash_cd()
	# Also keep the background (hidden) lobby pill in sync so the final value
	# is up-to-date the instant the shop closes.
	if target_cd != _cash_cd and not _cash_cd.is_empty():
		SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(to))
	SoundManager.play_sfx_loop("balance_increment")
	var tw := create_tween()
	tw.tween_method(func(val: int) -> void:
		SaveManager.set_currency_value(target_cd, SaveManager.format_money(val))
	, from, to, duration).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: SoundManager.stop_sfx_loop_if("balance_increment"))


## Spawns a visual cascade of chip icons that fly from `from_pos` (global)
## toward the currently-visible balance pill, while the balance counter +
## pill flash run in parallel. Falls back to a plain number tween if
## the pill isn't available.
func _spawn_chip_cascade(from_pos: Vector2, old_credits: int, new_credits: int) -> void:
	var target_cd: Dictionary = _active_cash_cd()
	var pill_inner: Control = target_cd.get("box", null) as Control
	if not is_instance_valid(pill_inner):
		_animate_balance_increment(old_credits, new_credits, 0.9)
		return
	var target_pos: Vector2 = pill_inner.global_position + pill_inner.size * 0.5

	var chip_tex: Texture2D = SaveManager.get_chip_texture()
	if chip_tex == null:
		_animate_balance_increment(old_credits, new_credits, 0.9)
		return

	var anim: Dictionary = ConfigManager.get_claim_animation()
	var chip_count: int = anim["chip_count"]
	var stagger_step: float = anim["stagger_step_sec"]
	var travel_time: float = anim["travel_time_sec"]
	var chip_size: Vector2 = Vector2(52, 52)  # bigger, per spec
	var chip_color: Color = Color("FFEC00")    # yellow, per spec

	for i in chip_count:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.custom_minimum_size = chip_size
		chip.size = chip_size
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.pivot_offset = chip_size * 0.5
		chip.z_index = 500
		var jitter := Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
		chip.global_position = from_pos + jitter - chip_size * 0.5
		chip.modulate = Color(chip_color.r, chip_color.g, chip_color.b, 0.0)
		add_child(chip)

		var stagger: float = float(i) * stagger_step
		var tw := chip.create_tween()
		tw.tween_interval(stagger)
		tw.tween_property(chip, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(chip, "global_position",
			target_pos - chip_size * 0.5, travel_time
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(chip, "scale", Vector2(0.6, 0.6), travel_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(chip, "modulate:a", 0.0, 0.1)
		tw.tween_callback(chip.queue_free)

		# Particle trail (anim 3.4): spawn small fading ghost copies along the
		# chip's path to create a motion smear.
		_spawn_chip_trail(chip_tex, chip_size, chip_color, from_pos + jitter, target_pos, stagger, travel_time)

	var total_duration: float = travel_time + stagger_step * float(chip_count - 1)
	_animate_balance_increment(old_credits, new_credits, total_duration)
	_flash_balance_pill(total_duration)
	# Big-win screen-wide golden tint (anim 3.3)
	if new_credits - old_credits >= 10000:
		_screen_gold_flash()


## Spawns ~5 shrinking ghost chips along the trajectory of a cascade chip.
## They stagger in time along the path and quickly fade, producing a trail.
func _spawn_chip_trail(tex: Texture2D, size: Vector2, color: Color, start: Vector2, end: Vector2, base_stagger: float, travel: float) -> void:
	var trail_count: int = 5
	for k in trail_count:
		var ghost := TextureRect.new()
		ghost.texture = tex
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.custom_minimum_size = size
		ghost.size = size
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.pivot_offset = size * 0.5
		ghost.z_index = 490
		ghost.modulate = Color(color.r, color.g, color.b, 0.0)
		ghost.global_position = start - size * 0.5
		add_child(ghost)
		var progress: float = float(k + 1) / float(trail_count + 1)
		var ghost_pos: Vector2 = start.lerp(end, progress)
		var ghost_delay: float = base_stagger + travel * progress * 0.7
		var tw := ghost.create_tween()
		tw.tween_interval(ghost_delay)
		tw.tween_property(ghost, "global_position", ghost_pos - size * 0.5, 0.01)
		tw.parallel().tween_property(ghost, "modulate:a", 0.45 * (1.0 - progress), 0.01)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ghost, "scale", Vector2(0.4, 0.4), 0.28).set_ease(Tween.EASE_OUT)
		tw.tween_callback(ghost.queue_free)


func _flash_balance_pill(duration: float) -> void:
	var pill: Control = _active_cash_pill()
	if not is_instance_valid(pill):
		return
	var flashes: int = 3
	var half: float = duration / float(flashes * 2)
	var tw := pill.create_tween()
	for i in flashes:
		tw.tween_property(pill, "modulate", Color(1.55, 1.55, 0.85), half)
		tw.tween_property(pill, "modulate", Color.WHITE, half)
	# Coin flip on the chip glyph inside the pill (anim 3.2)
	_coin_flip_chip()


## Finds the first chip glyph in the active pill's currency box and flips
## it around its Y axis (fake 3D via scale.x) once.
func _coin_flip_chip() -> void:
	var cd: Dictionary = _active_cash_cd()
	var box: Node = cd.get("box", null)
	if not is_instance_valid(box):
		return
	for child in box.get_children():
		if child is TextureRect:
			var tex_rect: TextureRect = child
			tex_rect.pivot_offset = tex_rect.size * 0.5
			var tw := tex_rect.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(tex_rect, "scale:x", 0.0, 0.18)
			tw.tween_property(tex_rect, "scale:x", 1.0, 0.18)
			break  # only the chip glyph (first TextureRect in the HBox)


## Full-screen golden tint flash for large incoming chip gains (anim 3.3).
## Only triggers when delta exceeds a threshold (10,000+).
func _screen_gold_flash() -> void:
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.85, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 999
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.22, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(flash.queue_free)


# --- Shop popup (IGT Game King style — horizontal scroll of pack cards) ---

const SHOP_COLOR_SCHEMES := {
	"blue": {
		"bg": Color("131BC7"),
		"border": Color("6AD6FC"),
		"image_frame": Color("0A0FB0"),
		"bonus_ribbon": Color("49C8FF"),
	},
	"purple": {
		"bg": Color("8C1FA6"),
		"border": Color("F24EB9"),
		"image_frame": Color("5D1177"),
		"bonus_ribbon": Color("49C8FF"),
	},
}

var _shop_overlay: Control = null
var _shop_cash_cd: Dictionary = {}
var _shop_cash_pill: Control = null
var _shop_gift_widget: Control = null
var _shop_gift_icon: TextureRect = null
var _shop_gift_label_area: VBoxContainer = null
var _cash_pill: Control = null  # lobby top-bar cash pill, captured in _style_top_bar
var _lobby_scroll_backup: ScrollContainer = null
var _lobby_drag_content_backup: Control = null
var _lobby_hit_rect_backup: Callable = Callable()


func _show_shop() -> void:
	ShopOverlay.show(self)
	if not ShopOverlay.shop_closed.is_connected(_on_shop_closed_refresh):
		ShopOverlay.shop_closed.connect(_on_shop_closed_refresh, CONNECT_ONE_SHOT)
	return


func _on_shop_closed_refresh() -> void:
	refresh_credits()
	# Force gift widget redraw too — user may have claimed while shop was open.
	if _gift_btn and is_instance_valid(_gift_btn):
		_gift_ready = not _is_gift_ready()
		_update_gift_state()



func _build_shop_balance_pill() -> PanelContainer:
	# Yellow-bordered pill with "CASH" label + current chip count (mirrors the
	# top-bar cash pill in the lobby).
	var pill := PanelContainer.new()
	_shop_cash_pill = pill
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.03)
	style.set_border_width_all(4)
	style.border_color = Color("FFEC00")
	style.set_corner_radius_all(28)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", style)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(inner)

	var cash_label := Label.new()
	cash_label.text = Translations.tr_key("lobby.cash")
	cash_label.add_theme_font_size_override("font_size", 30)
	cash_label.add_theme_color_override("font_color", Color.WHITE)
	cash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cash_label.add_theme_constant_override("outline_size", 3)
	inner.add_child(cash_label)

	var cd := SaveManager.create_currency_display(32, Color.WHITE,
		ThemeManager.color("topbar_text_outline", Color.BLACK), 2.0)
	inner.add_child(cd["box"])
	SaveManager.set_currency_value(cd, SaveManager.format_money(SaveManager.credits))
	_shop_cash_cd = cd
	return pill


func _build_shop_gift_widget() -> Control:
	var widget_w: int = GIFT_ICON_SIZE + GIFT_BTN_W - GIFT_ICON_OVERLAP
	var widget_h: int = GIFT_ICON_SIZE

	var root := Control.new()
	root.custom_minimum_size = Vector2(widget_w, widget_h)
	root.size = Vector2(widget_w, widget_h)
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.pivot_offset = Vector2(widget_w, widget_h) * 0.5

	# Pill bg — dark blue flat panel (trainer style).
	var pill := Panel.new()
	pill.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	pill.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	pill.custom_minimum_size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color("1E3A5F")
	pill_style.set_corner_radius_all(int(GIFT_BTN_H * 0.5))
	pill_style.set_border_width_all(2)
	pill_style.border_color = Color("3A5F8C")
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)

	# Label area (COLLECT!+amount for ready state, timer for waiting state)
	var la := VBoxContainer.new()
	la.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	la.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	la.alignment = BoxContainer.ALIGNMENT_CENTER
	la.add_theme_constant_override("separation", 0)
	la.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(la)
	_shop_gift_label_area = la

	# Icon (overlaps pill on the left)
	var icon := TextureRect.new()
	icon.position = Vector2(0, 0)
	icon.size = Vector2(GIFT_ICON_SIZE, GIFT_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_shop_gift_icon = icon

	_rebuild_shop_gift_content(_is_gift_ready())

	# Hover bounce (anim 2.2) — applies in both ready + countdown states
	_attach_hover_bounce(root)

	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var target: Vector2 = Vector2(0.93, 0.93) if event.pressed else Vector2.ONE
			var dur: float = 0.07 if event.pressed else 0.11
			var tw := root.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(root, "scale", target, dur)
			if not event.pressed and _gift_ready:
				var spawn_pos: Vector2 = root.global_position + root.size * 0.5
				_claim_gift_reward(spawn_pos)
	)
	return root


func _rebuild_shop_gift_content(ready: bool) -> void:
	if not _shop_gift_label_area or not _shop_gift_icon:
		return
	for child in _shop_gift_label_area.get_children():
		_shop_gift_label_area.remove_child(child)
		child.queue_free()

	if ready:
		_shop_gift_icon.texture = load("res://assets/shop/gift_box_ready_icon.png")

		var collect := Label.new()
		collect.text = Translations.tr_key("gift.daily_bonus")
		collect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		collect.add_theme_font_size_override("font_size", 18)
		collect.add_theme_color_override("font_color", Color.WHITE)
		_shop_gift_label_area.add_child(collect)

		var amount_hb := HBoxContainer.new()
		amount_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		amount_hb.add_theme_constant_override("separation", 4)
		amount_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_gift_label_area.add_child(amount_hb)

		var chip_tex: Texture2D = SaveManager.get_chip_texture()
		if chip_tex:
			var chip := TextureRect.new()
			chip.texture = chip_tex
			chip.custom_minimum_size = Vector2(20, 20)
			chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.modulate = Color("FFEC00")
			amount_hb.add_child(chip)

		var amt := Label.new()
		amt.add_theme_font_size_override("font_size", 18)
		amt.add_theme_color_override("font_color", Color("FFEC00"))
		amt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		amt.add_theme_constant_override("outline_size", 2)
		_set_chip_amount_text(amt, ConfigManager.get_gift_chips(), GIFT_BTN_W - 40)
		amount_hb.add_child(amt)
	else:
		_shop_gift_icon.texture = load("res://assets/shop/gift_box_icon.png")

		var timer_label := Label.new()
		timer_label.name = "Timer"
		timer_label.text = "--H --M --S"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 22)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		timer_label.add_theme_constant_override("outline_size", 3)
		_shop_gift_label_area.add_child(timer_label)


func _build_pack_card(item: Dictionary) -> PanelContainer:
	var scheme_name: String = item.get("color_scheme", "blue")
	var scheme: Dictionary = SHOP_COLOR_SCHEMES.get(scheme_name, SHOP_COLOR_SCHEMES["blue"])
	var chips: int = int(item.get("chips", 0))
	var bonus_chips: int = int(item.get("bonus_chips", 0))
	var total: int = chips + bonus_chips
	var top_badge_key: Variant = item.get("top_badge_key", null)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 460)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = scheme["bg"]
	card_style.set_border_width_all(4)
	card_style.border_color = scheme["border"]
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vb)

	# Top ribbon (SPECIAL PACK / MOST POPULAR)
	if top_badge_key != null and str(top_badge_key) != "":
		vb.add_child(_build_top_ribbon(Translations.tr_key(str(top_badge_key))))

	# Strikethrough base price
	if bonus_chips > 0 and chips > 0:
		var strike_hb := _build_chips_display(chips, 22, Color.WHITE)
		strike_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_add_strike_line(strike_hb)
		vb.add_child(strike_hb)

		var bonus_pct: int = int(round(float(bonus_chips) / float(chips) * 100.0))
		vb.add_child(_build_bonus_banner(bonus_pct))

	# Total chips (big yellow)
	var total_hb := _build_chips_display(total, 32, Color("FFEC00"))
	total_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(total_hb)

	# Pack image
	var img_panel := PanelContainer.new()
	img_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var img_style := StyleBoxFlat.new()
	img_style.bg_color = scheme["image_frame"]
	img_style.set_border_width_all(2)
	img_style.border_color = scheme["border"]
	img_style.set_corner_radius_all(12)
	img_style.content_margin_left = 6
	img_style.content_margin_right = 6
	img_style.content_margin_top = 6
	img_style.content_margin_bottom = 6
	img_panel.add_theme_stylebox_override("panel", img_style)
	vb.add_child(img_panel)

	var img := TextureRect.new()
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.custom_minimum_size = Vector2(160, 160)
	var img_path: String = str(ConfigManager.shop.get("images_path", "res://assets/shop/")) + str(item.get("image", ""))
	if ResourceLoader.exists(img_path):
		img.texture = load(img_path)
	img_panel.add_child(img)

	# Bonus chips ribbon (bottom)
	if bonus_chips > 0:
		var extra := _build_extra_ribbon(bonus_chips, scheme["bonus_ribbon"])
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(extra)

	# FREE buy button
	var buy_btn := _build_buy_button()
	buy_btn.pressed.connect(func() -> void:
		var spawn_pos: Vector2 = buy_btn.global_position + buy_btn.size * 0.5
		_on_shop_buy(total, spawn_pos)
	)
	vb.add_child(buy_btn)

	return card


func _build_chips_display(amount: int, font_size: int, color: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	var num := Label.new()
	num.text = SaveManager.format_money(amount)
	num.add_theme_font_size_override("font_size", font_size)
	num.add_theme_color_override("font_color", color)
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	num.add_theme_constant_override("outline_size", 3)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(num)
	var chip_tex: Texture2D = SaveManager.get_chip_texture()
	if chip_tex:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		var h: int = int(font_size * 0.95)
		chip.custom_minimum_size = Vector2(h, h)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(chip)
	return hb


func _add_strike_line(ctrl: Control) -> void:
	# Compute strike y from font ascent (digit visual centre ≈ label_top +
	# ascent/2). Robust across themes, fonts and HBox row padding.
	ctrl.draw.connect(func() -> void:
		if ctrl.get_child_count() == 0:
			return
		var lab: Label = ctrl.get_child(0) as Label
		if lab == null:
			var fy: float = ctrl.size.y * 0.5
			ctrl.draw_line(Vector2(-2, fy), Vector2(ctrl.size.x + 2, fy),
				Color(1.0, 0.25, 0.25, 0.95), 3.0)
			return
		var f: Font = lab.get_theme_font("font")
		var fs: int = lab.get_theme_font_size("font_size")
		if f == null:
			f = ThemeDB.fallback_font
		if fs <= 0:
			fs = ThemeDB.fallback_font_size
		var y: float = lab.position.y + f.get_ascent(fs) * 0.5
		ctrl.draw_line(Vector2(-2, y), Vector2(ctrl.size.x + 2, y),
			Color(1.0, 0.25, 0.25, 0.95), 3.0)
	)


func _build_bonus_banner(percent: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color("FFEC00")
	st.set_corner_radius_all(4)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var lab := Label.new()
	lab.text = Translations.tr_key("shop.bonus_percent_fmt", [percent])
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color.BLACK)
	pc.add_child(lab)
	return pc


func _build_top_ribbon(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.clip_contents = true
	var st := StyleBoxFlat.new()
	st.bg_color = Color("FFEC00")
	st.set_corner_radius_all(6)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color.BLACK)
	pc.add_child(lab)
	# Diagonal shine sweep every ~3 sec
	_attach_shimmer_sweep(pc, 3.0, Color(1, 1, 1, 0.7))
	return pc


## Overlays a diagonal white shimmer stripe that sweeps across the control
## from left to right once every `period` seconds. Works on any Control via
## `draw.connect`. Only shows inside clip_contents.
func _attach_shimmer_sweep(ctrl: Control, period: float = 3.0, color: Color = Color(1, 1, 1, 0.4), pause: float = -1.0) -> void:
	# We animate a float "shimmer_t" 0..1, then use it in _draw to paint a
	# slanted polygon moving across the control's rect.
	var state := {"t": -0.2}
	var pause_time: float = pause if pause >= 0.0 else period * 0.4
	var tick := func() -> void:
		var tw := ctrl.create_tween()
		tw.set_loops()
		tw.tween_method(func(val: float) -> void:
			state["t"] = val
			ctrl.queue_redraw()
		, -0.3, 1.3, period).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(pause_time)
	tick.call()
	ctrl.draw.connect(func() -> void:
		var t: float = state["t"]
		if t < 0.0 or t > 1.0:
			return
		var w: float = ctrl.size.x
		var h: float = ctrl.size.y
		var cx: float = lerp(-w * 0.4, w * 1.1, t)
		var half: float = w * 0.08
		var skew: float = h * 0.6
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(cx - half, -2),
			Vector2(cx + half, -2),
			Vector2(cx + half - skew, h + 2),
			Vector2(cx - half - skew, h + 2),
		])
		ctrl.draw_colored_polygon(poly, color)
	)


func _build_extra_ribbon(bonus_chips: int, bg: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(6)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	pc.add_child(hb)
	var lab := Label.new()
	lab.text = "+" + SaveManager.format_money(bonus_chips)
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 3)
	hb.add_child(lab)
	var chip_tex: Texture2D = SaveManager.get_chip_texture()
	if chip_tex:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		chip.custom_minimum_size = Vector2(18, 18)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(chip)
	return pc


func _build_buy_button() -> Button:
	var btn := Button.new()
	btn.text = Translations.tr_key("common.free")
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.05, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.15, 0.80, 0.35)
	st.set_border_width_all(2)
	st.border_color = Color(0.04, 0.40, 0.12)
	st.set_corner_radius_all(22)
	btn.add_theme_stylebox_override("normal", st)
	var hover := st.duplicate()
	hover.bg_color = Color(0.20, 0.88, 0.40)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", st)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_attach_press_effect(btn)
	return btn


func _build_exchange_rate_row(coins_per_dollar: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	var n_label := Label.new()
	n_label.text = str(coins_per_dollar)
	n_label.add_theme_font_size_override("font_size", 22)
	n_label.add_theme_color_override("font_color", Color("FFEC00"))
	hb.add_child(n_label)
	var chip_tex: Texture2D = SaveManager.get_chip_texture()
	if chip_tex:
		var chip := TextureRect.new()
		chip.texture = chip_tex
		chip.custom_minimum_size = Vector2(22, 22)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(chip)
	var eq_label := Label.new()
	eq_label.text = Translations.tr_key("shop.exchange_rate_fmt", [1.0])
	eq_label.add_theme_font_size_override("font_size", 22)
	eq_label.add_theme_color_override("font_color", Color.WHITE)
	hb.add_child(eq_label)
	return hb


func _on_shop_buy(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(amount)
	SaveManager.save_game()
	# Shop stays open — cascade flies to the shop-side cash pill.
	if from_pos != Vector2.ZERO:
		_spawn_confetti_burst(from_pos)
		_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)
	else:
		_animate_balance_increment(old_credits, SaveManager.credits, 0.9)


## Local confetti burst — 14 coloured squares that fly out radially from
## `from_pos`, rotate, fade, and free themselves. Pure Control-based (no
## GPUParticles2D so it works fine on the web renderer).
func _spawn_confetti_burst(from_pos: Vector2) -> void:
	var colors: Array = [
		Color("FFEC00"), Color("FF5577"), Color("49C8FF"),
		Color("7FE7A0"), Color("FF9A2E"), Color("D67AFF"),
	]
	for i in 14:
		var piece := ColorRect.new()
		var sz := randf_range(6.0, 10.0)
		piece.custom_minimum_size = Vector2(sz, sz)
		piece.size = Vector2(sz, sz)
		piece.color = colors[i % colors.size()]
		piece.pivot_offset = piece.size * 0.5
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 600
		piece.global_position = from_pos - piece.size * 0.5
		add_child(piece)

		var angle: float = randf_range(-PI, PI)
		var dist: float = randf_range(80.0, 180.0)
		var target: Vector2 = piece.global_position + Vector2(cos(angle), sin(angle)) * dist
		var duration: float = randf_range(0.45, 0.75)
		var tw := piece.create_tween().set_parallel(true)
		tw.tween_property(piece, "global_position", target, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(piece, "rotation", randf_range(-TAU, TAU), duration)
		tw.tween_property(piece, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(piece.queue_free)


func _hide_shop() -> void:
	if _shop_overlay:
		# Kill any active shop drag/inertia before tearing down
		if _inertia_tween and _inertia_tween.is_running():
			_inertia_tween.kill()
		_drag_active = false
		_overscroll = 0.0
		# Mirror of the open animation: fade + scale-down + slide-down.
		var ov := _shop_overlay
		_shop_overlay = null
		ov.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y)
		var outro := ov.create_tween().set_parallel(true)
		outro.tween_property(ov, "modulate:a", 0.0, 0.14)
		outro.tween_property(ov, "scale", Vector2(0.95, 0.95), 0.17) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		outro.tween_property(ov, "position:y", 40.0, 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		outro.chain().tween_callback(ov.queue_free)
	_shop_cash_cd = {}
	_shop_cash_pill = null
	_shop_gift_widget = null
	_shop_gift_icon = null
	_shop_gift_label_area = null
	# Restore lobby drag-scroll target
	if _lobby_scroll_backup:
		_scroll_ref = _lobby_scroll_backup
		_drag_content = _lobby_drag_content_backup
		_drag_hit_rect_fn = _lobby_hit_rect_backup
		_lobby_scroll_backup = null
		_lobby_drag_content_backup = null
		_lobby_hit_rect_backup = Callable()
