@tool
extends SceneTree

## One-shot CLI tool that converts every .svg in
## res://assets/themes/supercell/glyphs_multipliers/ to a same-named .png at
## 4× the SVG's intrinsic size (retina) — preserves aspect ratio. Run with:
##
##   godot --headless --quit --script res://scripts/tools/convert_svg_to_png.gd
##
## Removes the original .svg + .svg.import after a successful PNG write so
## Godot picks up the PNGs cleanly on the next import pass.

const FOLDER := "res://assets/themes/supercell/glyphs_multipliers/"
const SCALE := 4.0  # 4× upsample for retina-friendly raster


func _init() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		print("Folder not found: ", FOLDER)
		quit(1)
		return

	var converted := 0
	var skipped := 0
	dir.list_dir_begin()
	while true:
		var fname := dir.get_next()
		if fname == "":
			break
		if dir.current_is_dir():
			continue
		if not fname.ends_with(".svg"):
			continue
		var src := FOLDER + fname
		var dst := FOLDER + fname.get_basename() + ".png"
		if _convert_one(src, dst):
			converted += 1
			# Remove the .svg + .import so Godot doesn't keep it in parallel.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(src))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(src + ".import"))
		else:
			skipped += 1
			print("  SKIP: ", fname)
	dir.list_dir_end()
	print("Converted %d, skipped %d" % [converted, skipped])
	quit()


func _convert_one(src_path: String, dst_path: String) -> bool:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(src_path))
	if err != OK:
		# Image.load doesn't natively support SVG — fall back to ResourceLoader
		# which goes through Godot's SVG importer to give us a Texture2D.
		var tex: Texture2D = load(src_path)
		if tex == null:
			return false
		img = tex.get_image()
		if img == null:
			return false
	# Upsample to SCALE× for crisper raster.
	if SCALE != 1.0:
		var w := int(img.get_width() * SCALE)
		var h := int(img.get_height() * SCALE)
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var save_err := img.save_png(ProjectSettings.globalize_path(dst_path))
	if save_err != OK:
		print("  save_png failed for ", dst_path, " err=", save_err)
		return false
	print("  -> ", dst_path)
	return true
