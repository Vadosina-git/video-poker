extends Node
##
## SafeAreaManager — autoload. Reads the device safe area (notch /
## Dynamic Island / home indicator / Android cutout) and exposes it as
## viewport-space margins, plus a helper that applies those margins to
## any Control by inset offsets.
##
## Consumers:
##   - scripts/main.gd applies offsets to every game scene it spawns.
##
## Re-evaluates on viewport resize, orientation change, or app focus
## return (system UI may have changed while backgrounded).

signal safe_area_changed(margins: Dictionary)

var margins: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

# Controls registered for automatic offset updates: { control: WeakRef }.
var _tracked: Array[WeakRef] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Recompute when the viewport changes size (rotation, split-view,
	# window resize on desktop). The root viewport's signal fires on
	# every relevant change.
	get_tree().root.size_changed.connect(_recompute)
	# First pass after the tree is ready so DisplayServer has the real
	# screen size, not the editor stub.
	call_deferred("_recompute")


func _notification(what: int) -> void:
	# When the user returns from the home screen / app switcher, iOS
	# may have changed the orientation or system bar state without
	# emitting size_changed. Recompute defensively.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_recompute()


func apply_offsets(ctrl: Control) -> void:
	if ctrl == null:
		return
	_tracked.append(weakref(ctrl))
	_apply_to(ctrl)


func _recompute() -> void:
	var new_margins := _compute_margins()
	if _margins_equal(new_margins, margins):
		# Still re-apply to tracked controls — a freshly-spawned scene
		# registered with apply_offsets() wants the current values.
		_flush_tracked()
		return
	margins = new_margins
	_flush_tracked()
	safe_area_changed.emit(margins)


func _compute_margins() -> Dictionary:
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

	# Only mobile devices have meaningful safe areas. On desktop the
	# DisplayServer will return the full window which would produce
	# zeros anyway, but skip the math to keep editor runs clean.
	if not (OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")):
		return zero

	var safe_px: Rect2i = DisplayServer.get_display_safe_area()
	var win_px: Vector2i = DisplayServer.window_get_size()
	if win_px.x <= 0 or win_px.y <= 0 or safe_px.size.x <= 0 or safe_px.size.y <= 0:
		return zero

	var vp_size: Vector2 = get_tree().root.size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return zero

	# Convert pixel rect → viewport coords. With stretch_mode = canvas_items
	# the scaling is uniform per-axis: viewport / window pixels.
	var sx: float = float(vp_size.x) / float(win_px.x)
	var sy: float = float(vp_size.y) / float(win_px.y)

	var left_px: int = safe_px.position.x
	var top_px: int = safe_px.position.y
	var right_px: int = win_px.x - (safe_px.position.x + safe_px.size.x)
	var bottom_px: int = win_px.y - (safe_px.position.y + safe_px.size.y)

	return {
		"left": max(0.0, float(left_px) * sx),
		"top": max(0.0, float(top_px) * sy),
		"right": max(0.0, float(right_px) * sx),
		"bottom": max(0.0, float(bottom_px) * sy),
	}


func _flush_tracked() -> void:
	var live: Array[WeakRef] = []
	for ref in _tracked:
		var obj: Object = ref.get_ref()
		if obj != null and is_instance_valid(obj) and obj is Control:
			_apply_to(obj as Control)
			live.append(ref)
	_tracked = live


func _apply_to(ctrl: Control) -> void:
	# Apply inset *additively* to the control's existing offsets, respecting
	# its anchors. Only sides anchored to a viewport edge get pushed inward,
	# so a top-anchored bar shifts down by `top` but keeps its declared height,
	# a bottom-anchored bar shifts up by `bottom`, and a full-rect container
	# shrinks on all four sides. Previous delta is cached in meta so repeated
	# recomputes (rotation, focus return) don't accumulate.
	var prev: Dictionary = ctrl.get_meta("_safe_area_applied", {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0})
	var dl: float = float(margins["left"]) - float(prev["left"])
	var dt: float = float(margins["top"]) - float(prev["top"])
	var dr: float = float(margins["right"]) - float(prev["right"])
	var db: float = float(margins["bottom"]) - float(prev["bottom"])
	if ctrl.anchor_left == 0.0:
		ctrl.offset_left += dl
	if ctrl.anchor_top == 0.0:
		ctrl.offset_top += dt
	if ctrl.anchor_right == 1.0:
		ctrl.offset_right -= dr
	if ctrl.anchor_bottom == 1.0:
		ctrl.offset_bottom -= db
	ctrl.set_meta("_safe_area_applied", margins.duplicate())


func _margins_equal(a: Dictionary, b: Dictionary) -> bool:
	for k in ["left", "top", "right", "bottom"]:
		if abs(float(a[k]) - float(b[k])) > 0.5:
			return false
	return true
