extends Node
## Autoload: centralises all visual-style tokens (colors, borders, fonts, card
## pack path) behind a single API, so a single config flip re-skins the whole
## UI without touching any scene.
##
## Active theme lives in SaveManager.theme_name. Call set_theme("supercell") to
## switch. All scenes currently drawn reload themselves via `theme_changed`
## (lobby + any open popup call get_tree().reload_current_scene()).

signal theme_changed(new_id: String)

const THEMES_DIR := "res://configs/themes/"
const DEFAULT_THEME := "classic"

var current_id: String = DEFAULT_THEME
var _themes: Dictionary = {}          # id → full theme dict
var _cached_font: Font = null         # resolved Font resource for current theme


func _ready() -> void:
	_load_all()
	_apply_saved()


func _load_all() -> void:
	var dir := DirAccess.open(THEMES_DIR)
	if dir == null:
		push_error("ThemeManager: themes dir not found: " + THEMES_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".json"):
			var path := THEMES_DIR + file
			var t: Variant = _load_one(path)
			if t is Dictionary and t.has("id"):
				_themes[str(t["id"])] = t
		file = dir.get_next()
	dir.list_dir_end()


func _load_one(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("ThemeManager: failed to parse " + path)
		return null
	return json.data


func _apply_saved() -> void:
	var saved: String = SaveManager.theme_name
	if saved in _themes:
		current_id = saved
	else:
		current_id = DEFAULT_THEME
	_refresh_cached()
	_apply_window_bg()
	_apply_chip_glyph()


## Paints the engine's default_clear_color from the active theme so the area
## behind the safe-area margin (left/right vertical strips on landscape) matches
## the UI instead of showing the project.godot default dark blue.
func _apply_window_bg() -> void:
	var col := color("bg_main", Color.BLACK)
	RenderingServer.set_default_clear_color(col)


func _refresh_cached() -> void:
	_cached_font = null
	var path: String = _get_asset("font", "")
	if path != "" and ResourceLoader.exists(path):
		_cached_font = load(path)


## Push the active theme's chip / coin texture into SaveManager so every
## currency display (lobby pill, multi/spin balance + bet + win readouts)
## renders the right glyph automatically. The path comes from the theme
## JSON's `assets.currency_chip`. Themes that don't declare one fall
## back to whatever default SaveManager ships with.
func _apply_chip_glyph() -> void:
	# SaveManager is an autoload registered before ThemeManager, so it's
	# always available by the time `_apply_saved` / `set_theme` run. The
	# instance-valid guard is a belt-and-suspenders for hot-reload edge
	# cases where the SaveManager node was queue_freed during teardown.
	if not is_instance_valid(SaveManager):
		return
	var path: String = _get_asset("currency_chip", "")
	SaveManager.set_chip_texture(path)


## Switch active theme. Persists to SaveManager and fires `theme_changed` so
## scenes can reload. No-op if the id is unknown.
func set_theme(theme_id: String) -> void:
	if theme_id == current_id:
		return
	if not (theme_id in _themes):
		push_warning("ThemeManager: unknown theme %s" % theme_id)
		return
	current_id = theme_id
	SaveManager.theme_name = theme_id
	SaveManager.save_game()
	_refresh_cached()
	_apply_window_bg()
	_apply_chip_glyph()
	theme_changed.emit(theme_id)


## Cycle to the next available theme — useful for a dev cheat toggle.
func cycle_theme() -> void:
	var ids: Array = _themes.keys()
	ids.sort()
	if ids.is_empty():
		return
	var idx: int = ids.find(current_id)
	var next_id: String = str(ids[(idx + 1) % ids.size()])
	set_theme(next_id)


func list_theme_ids() -> Array:
	return _themes.keys()


func display_name(theme_id: String) -> String:
	var t: Variant = _themes.get(theme_id, null)
	if t is Dictionary:
		return str(t.get("display_name", theme_id))
	return theme_id


# --- Token lookup -----------------------------------------------------------

## Fetch a color token by name (e.g. "topbar_bg"). Accepts a fallback Color that's
## returned when the token is missing so callers don't crash mid-render.
func color(key: String, fallback: Color = Color.MAGENTA) -> Color:
	var hex: String = _get_color_hex(key)
	if hex == "":
		return fallback
	return Color(hex)


func has_color(key: String) -> bool:
	return _get_color_hex(key) != ""


func _get_color_hex(key: String) -> String:
	var t: Variant = _themes.get(current_id, null)
	if t is Dictionary:
		var colors: Dictionary = t.get("colors", {})
		return str(colors.get(key, ""))
	return ""


func size(key: String, fallback: float = 0.0) -> float:
	var t: Variant = _themes.get(current_id, null)
	if t is Dictionary:
		var sizes: Dictionary = t.get("sizes", {})
		return float(sizes.get(key, fallback))
	return fallback


func card_path() -> String:
	return _get_asset("card_path", "res://assets/themes/classic/cards/")


func spin_card_path() -> String:
	return _get_asset("spin_card_path", card_path() + "spin/")


## Folder for Ultra VP multiplier glyphs (digits 1..12, 'x', 'x_large',
## 'nexthand', 'nexthand_large'). Resolution order:
##   1. theme JSON `assets.multiplier_glyph_path` if defined
##   2. convention folder `themes/<id>/glyphs_multipliers/` if it exists
##   3. classic fallback `res://assets/textures/glyphs_multipliers/`
## Per-theme override lets each skin ship its own digit/X artwork while
## un-skinned themes keep the original shared glyph set.
func multiplier_glyph_path() -> String:
	var explicit: String = _get_asset("multiplier_glyph_path", "")
	if explicit != "":
		return explicit
	var conv: String = theme_folder() + "glyphs_multipliers/"
	# `glyph_multi_x.<png|svg>` is the cheapest sentinel for "this theme
	# ships a custom pack" — accept either format so PNG-based packs
	# (supercell) and SVG-based packs are both auto-detected without an
	# explicit JSON entry.
	if ResourceLoader.exists(conv + "glyph_multi_x.png") \
			or ResourceLoader.exists(conv + "glyph_multi_x.svg"):
		return conv
	return "res://assets/textures/glyphs_multipliers/"


## Returns a ready-to-assign StyleBoxFlat sized for a popup panel
## (settings, info, pickers, gift claim, shop). Uses the active theme's
## popup_bg / popup_border tokens so dialog chrome matches the skin.
func make_popup_stylebox() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = color("popup_bg", Color("05051280"))
	st.border_color = color("popup_border", Color("FFEC00"))
	st.set_border_width_all(int(size("popup_border_width", 3)))
	st.set_corner_radius_all(int(size("popup_corner_radius", 12)))
	st.anti_aliasing = true
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 20
	st.content_margin_bottom = 20
	return st


## Dim overlay color for backdrop behind popups.
func popup_dim_color() -> Color:
	return color("popup_dim", Color(0, 0, 0, 0.55))


## Applies theme font + popup title color (+ outline for legibility)
## to a Label in one call. Use on titles / section headers inside popups.
func style_popup_title(lab: Label, font_size: int = 28) -> void:
	var f := font()
	if f != null:
		lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", color("popup_title_text", Color("FFEC00")))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 3)


## Theme font + popup body color for paragraph / row labels inside
## popups — keeps panel text consistent per skin.
func style_popup_body(lab: Label, font_size: int = 16) -> void:
	var f := font()
	if f != null:
		lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", color("popup_body_text", Color.WHITE))


func font() -> Font:
	return _cached_font  # may be null for themes that keep the system font


## Per-theme background PNG discovered by convention at
## `themes/<id>/backgrounds/background.png`. No JSON declaration needed:
## drop the PNG in and the lobby will use it; delete it and the code
## fallback (gradient/pattern/fill) takes over automatically.
func background_texture() -> Texture2D:
	var path := theme_folder() + "backgrounds/background.png"
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## Root folder for the active theme's assets. All theme-specific PNGs
## (machine tiles, mode icons, backgrounds, fonts) live under this path
## so `ls assets/themes/<id>/` shows exactly what ships with each skin.
func theme_folder() -> String:
	return "res://assets/themes/%s/" % current_id


## Path to a mode button icon (e.g. "single_play", "ultra_vp"). Returns
## an empty string if the theme doesn't ship one — callers then fall
## back to the primitive drawn glyph.
func mode_icon_path(mode_id: String) -> String:
	var p := theme_folder() + "modes/%s.png" % mode_id
	return p if ResourceLoader.exists(p) else ""


## Path to a machine tile icon for the given variant + play mode.
## `mode_suffix` comes from ICON_MODE_SUFFIX in lobby_manager
## (classic/multi/ultra/spin). Returns an empty string when the PNG
## isn't present — typically for text-mode themes like supercell.
func machine_icon_path(variant_prefix: String, mode_suffix: String) -> String:
	var p := theme_folder() + "machines/%s_%s.png" % [variant_prefix, mode_suffix]
	return p if ResourceLoader.exists(p) else ""


## Path to a generic UI icon (store, support, settings, gift_ready,
## gift_waiting, suit_*, …) under themes/<id>/icons/<name>. Tries
## .svg first (vector) then .png. Returns an empty string if neither
## exists — callers fall back to primitive drawing.
func ui_icon_path(name: String) -> String:
	var base := theme_folder() + "icons/" + name
	var svg := base + ".svg"
	if ResourceLoader.exists(svg):
		return svg
	var png := base + ".png"
	if ResourceLoader.exists(png):
		return png
	return ""


## Returns [top_color, bot_color] for a per-machine gradient or an
## empty array when the theme doesn't declare one — caller falls back
## to the flat _bg_color rendering.
func machine_gradient(variant_id: String) -> Array:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return []
	var grads: Dictionary = t.get("machine_gradients", {})
	var pair: Variant = grads.get(variant_id, null)
	if not (pair is Array) or pair.size() < 2:
		return []
	return [Color(str(pair[0])), Color(str(pair[1]))]


## Per-machine outline (border) color override. When the theme declares a
## `machine_outlines` dict, this returns a darker shade of the bottom
## gradient color for each variant; otherwise callers fall back to the
## global `tile_outline_color`.
func machine_outline(variant_id: String, fallback: Color) -> Color:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return fallback
	var outlines: Dictionary = t.get("machine_outlines", {})
	var raw: Variant = outlines.get(variant_id, null)
	if raw == null:
		return fallback
	return Color(str(raw))


## Short 1–3-word label rendered under the title on text-mode tiles
## (e.g. "Classic · Low", "Quad Bonus"). Empty when the theme doesn't
## supply one.
func machine_label(variant_id: String) -> String:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return ""
	var labels: Dictionary = t.get("machine_labels", {})
	return str(labels.get(variant_id, ""))


## Theme-specific uppercase display title for a tile (e.g.
## "DBL DBL BONUS" for supercell vs the full "Double Double Bonus" in
## other contexts). Empty when the theme doesn't override, so callers
## fall back to the translations-provided name.
func machine_title(variant_id: String) -> String:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return ""
	var titles: Dictionary = t.get("machine_titles", {})
	return str(titles.get(variant_id, ""))


## Theoretical RTP percentage for a machine, read from
## machine_rtp dict in the theme config. Returns 0.0 when the theme
## doesn't declare a value — callers may fall back to a Paytable rtp.
func machine_rtp(variant_id: String) -> float:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return 0.0
	var rtps: Dictionary = t.get("machine_rtp", {})
	return float(rtps.get(variant_id, 0.0))


## Per-theme background gradient ("radial" or "linear"). Returns an
## already-built GradientTexture2D (1024×1024) ready to assign to a
## TextureRect, or null when the theme doesn't declare a gradient.
func background_gradient_texture() -> Texture2D:
	return _build_gradient_from_key("background_gradient")


## Optional second gradient rendered above the primary one (e.g. a
## top-transparent → bottom-opaque vertical darkener). Same config shape
## as background_gradient.
func background_overlay_gradient_texture() -> Texture2D:
	return _build_gradient_from_key("background_overlay_gradient")


## Builds a GradientTexture2D from a theme config dict keyed by `key`.
## Supports:
##   type         — "radial" or "linear" (default "linear")
##   stops        — [[offset, "#RRGGBB"], ...] or [[offset, hex, alpha], ...]
##   from, to     — optional Vector2 override (normalized 0..1) for
##                  the gradient's start/end points.
func _build_gradient_from_key(key: String) -> Texture2D:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return null
	var cfg: Variant = t.get(key, null)
	if not (cfg is Dictionary):
		return null
	var stops: Variant = cfg.get("stops", null)
	if not (stops is Array) or stops.size() < 2:
		return null
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		if s is Array and s.size() >= 2:
			offsets.append(float(s[0]))
			var c := Color(str(s[1]))
			if s.size() >= 3:
				c.a = float(s[2])
			colors.append(c)
	if offsets.size() < 2:
		return null
	var grad := Gradient.new()
	grad.offsets = offsets
	grad.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 1024
	tex.height = 1024
	var kind := str(cfg.get("type", "linear"))
	var is_radial := kind == "radial"
	tex.fill = GradientTexture2D.FILL_RADIAL if is_radial else GradientTexture2D.FILL_LINEAR
	var default_from: Vector2 = Vector2(0.5, 0.5) if is_radial else Vector2(0.0, 0.0)
	var default_to: Vector2 = Vector2(1.0, 1.0) if is_radial else Vector2(0.0, 1.0)
	var from_arr: Variant = cfg.get("from", null)
	tex.fill_from = _vec2_from_arr(from_arr, default_from)
	var to_arr: Variant = cfg.get("to", null)
	tex.fill_to = _vec2_from_arr(to_arr, default_to)
	return tex


func _vec2_from_arr(arr: Variant, fallback: Vector2) -> Vector2:
	if arr is Array and arr.size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback


func _get_asset(key: String, fallback: String) -> String:
	var t: Variant = _themes.get(current_id, null)
	if t is Dictionary:
		var assets: Dictionary = t.get("assets", {})
		return str(assets.get(key, fallback))
	return fallback


## Draw a diagonal-stripe overlay pattern on top of a rect (for the grid bg
## in supercell theme). Call from a Control's draw callback. No-op when the
## current theme disables the pattern.
func draw_pattern(ci: RID, rect: Rect2) -> void:
	var t: Variant = _themes.get(current_id, null)
	if not (t is Dictionary):
		return
	var p: Dictionary = t.get("pattern", {})
	if not bool(p.get("enabled", false)):
		return
	var col := Color(str(p.get("color", "#FFFFFF")))
	col.a = float(p.get("opacity", 0.08))
	var spacing: float = float(p.get("spacing", 22))
	var line_w: float = float(p.get("line_width", 2))
	# Diagonal 45° stripes across the rect. We iterate over x-intercepts on the
	# top edge from -height (stripes starting off-canvas top-right) to width+height
	# and draw each line to a bottom intercept shifted by rect.size.y.
	var y0: float = rect.position.y
	var y1: float = rect.position.y + rect.size.y
	var x_start: float = rect.position.x - rect.size.y
	var x_end: float = rect.position.x + rect.size.x
	var x: float = x_start
	while x <= x_end:
		RenderingServer.canvas_item_add_line(ci,
			Vector2(x, y0),
			Vector2(x + rect.size.y, y1),
			col,
			line_w,
			false)
		x += spacing


func tile_display() -> String:
	var t: Variant = _themes.get(current_id, null)
	if t is Dictionary:
		var tiles: Dictionary = t.get("tiles", {})
		return str(tiles.get("display", "icon"))
	return "icon"


func tile_min_size() -> Vector2:
	var t: Variant = _themes.get(current_id, null)
	if t is Dictionary:
		var tiles: Dictionary = t.get("tiles", {})
		var ms: Variant = tiles.get("min_size", null)
		if ms is Array and ms.size() >= 2:
			return Vector2(float(ms[0]), float(ms[1]))
	return Vector2(400, 240)
