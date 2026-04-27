class_name MultiplierGlyphs
extends RefCounted

## Utility for building multiplier displays using glyph textures (SVG images)
## instead of plain text labels.

## Classic / shared fallback used whenever the active theme doesn't ship
## its own multiplier glyph pack. ThemeManager.multiplier_glyph_path()
## handles the per-theme override; this constant only matters when the
## ThemeManager autoload is unavailable (script tests, tooling).
const GLYPH_DIR := "res://assets/textures/glyphs_multipliers/"


## Threshold at which the "large" X / NEXT HAND glyph variants are used.
## Multipliers >= this value look nicer with the larger glyph variants.
const LARGE_VARIANT_THRESHOLD := 7


static func _x_glyph_name(value: int) -> String:
	return "x_large" if value >= LARGE_VARIANT_THRESHOLD else "x"


static func _nexthand_glyph_name(value: int) -> String:
	return "nexthand_large" if value >= LARGE_VARIANT_THRESHOLD else "nexthand"


## Populate a container with "{value}X" glyphs. Clears existing children.
## Glyphs are wrapped in an inner HBoxContainer right-aligned to the parent so
## the content's right edge coincides with the parent's right edge.
static func set_value_x(container: Control, value: int, height: float = 24.0) -> void:
	_clear(container)
	container.set_meta("mult_value", value)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_horizontal = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(row)
	_add_glyph(row, str(value), height)
	_add_glyph(row, _x_glyph_name(value), height)


## Populate a VBoxContainer with "NEXT HAND" row on top, "{value}X" row below.
## Both rows are right-aligned so content's right edge = container's right edge.
static func set_next_value_x(container: Control, value: int, height_num: float = 20.0, height_next: float = 14.0) -> void:
	_clear(container)
	container.set_meta("mult_value", value)
	# NEXT HAND row
	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_END
	next_row.size_flags_horizontal = Control.SIZE_FILL
	next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_glyph(next_row, _nexthand_glyph_name(value), height_next)
	container.add_child(next_row)
	# Value + X row
	var val_row := HBoxContainer.new()
	val_row.alignment = BoxContainer.ALIGNMENT_END
	val_row.size_flags_horizontal = Control.SIZE_FILL
	val_row.add_theme_constant_override("separation", 0)
	val_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_glyph(val_row, str(value), height_num)
	_add_glyph(val_row, _x_glyph_name(value), height_num)
	container.add_child(val_row)


## Get stored multiplier value from container metadata.
static func get_value(container: Control) -> int:
	return container.get_meta("mult_value", 1) as int


## Create a fresh HBoxContainer for "{value}X" display.
static func make_value_x(value: int, height: float = 24.0) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_value_x(hbox, value, height)
	return hbox


## Create a fresh VBoxContainer for "NEXT HAND {value}X" display.
static func make_next_value_x(value: int, height_num: float = 20.0, height_next: float = 14.0) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_next_value_x(vbox, value, height_num, height_next)
	return vbox


static func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Look up `glyph_multi_<name>` in `dir`, preferring .png over .svg so a
## theme that ships rastered glyphs takes precedence over an SVG of the
## same name. Returns "" if neither exists.
static func _resolve_glyph(dir: String, glyph_name: String) -> String:
	var png := dir + "glyph_multi_%s.png" % glyph_name
	if ResourceLoader.exists(png):
		return png
	var svg := dir + "glyph_multi_%s.svg" % glyph_name
	if ResourceLoader.exists(svg):
		return svg
	return ""


static func _add_glyph(parent: Control, glyph_name: String, height: float) -> void:
	# Pull the active theme's glyph folder; PNG and SVG are both accepted
	# (supercell ships PNG raster glyphs, classic uses SVG). If a specific
	# glyph is missing in the theme pack, fall back to the classic shared
	# set so partial theme packs (e.g. only digits replaced) still render
	# the missing glyphs instead of disappearing.
	var theme_dir: String = ThemeManager.multiplier_glyph_path()
	var path: String = _resolve_glyph(theme_dir, glyph_name)
	if path == "":
		path = _resolve_glyph(GLYPH_DIR, glyph_name)
	if path == "":
		return
	var tex := TextureRect.new()
	tex.texture = load(path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Texture2D = tex.texture
	if t and t.get_height() > 0:
		var aspect := float(t.get_width()) / float(t.get_height())
		tex.custom_minimum_size = Vector2(ceilf(height * aspect), height)
	else:
		tex.custom_minimum_size = Vector2(height, height)
	parent.add_child(tex)
