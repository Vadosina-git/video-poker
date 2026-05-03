extends "res://scripts/multi_hand_game.gd"
## Supercell reskin of the multi-hand / Ultra VP table. Extends the
## classic MultiHandGame so all FSM, multi-hand logic, card animations
## and multiplier handling stay identical (full functional parity).
## Override only the visual chrome:
##   • felt background inherits the machine's gradient (same as
##     single-hand supercell)
##   • slight mode-specific tint overlay so Triple / Five / Ten /
##     Ultra feel distinct
##   • control buttons pick up PNG assets from
##     themes/supercell/controls/ when present, else keep the
##     classic sticker styleboxes
##
## Layout is untouched — user requested "не меняя расположения
## элементов". Classic multi_hand_game.gd builds all nodes; we just
## recolor / repaint.

# Keep these in sync with the same constants in game_supercell.gd —
# the three supercell modes use identical icon size + screen-edge padding.
const SUPERCELL_TOP_ICON_SIZE := 58
const SUPERCELL_TOP_EDGE_PAD := 32

const MODE_TINTS := {
	1:  Color(1, 1, 1, 0),         # single (never here; fallback no-op)
	3:  Color(0.55, 0.75, 1.0, 0.15),    # Triple   — cool blue wash
	5:  Color(0.50, 0.95, 0.70, 0.14),   # Five     — aqua/green wash
	10: Color(0.80, 0.55, 1.0, 0.18),    # Ten      — violet wash
}
const ULTRA_TINT := Color(1.0, 0.85, 0.40, 0.20)  # Ultra VP amber


func _ready() -> void:
	# Bump info-row chip + digit glyphs to 2× before classic's _ready
	# runs `_apply_theme`, which is where every WIN / TOTAL BET / BALANCE
	# currency display is FIRST created via `create_currency_display`.
	# Setting this AFTER super._ready() would resize the digits but
	# leave the initial chip glyph small (or vice versa) until the next
	# FSM update.
	_info_glyph_h = 32
	super._ready()
	# Button texture swaps are safe at this point — layout is built.
	call_deferred("_swap_control_textures")
	# Currency displays were built by classic's _ready using the chip
	# glyph SaveManager held at that moment. ThemeManager swaps the chip
	# texture on theme change but already-rendered TextureRects keep
	# their old reference. Walk every cd Dictionary and rebuild them so
	# the supercell coin replaces the classic chip.
	call_deferred("_refresh_currency_displays")
	# Replace classic's white-arrow exit icon (with its 160px left content
	# margin) with the supercell-styled red 44×44 back square — same
	# look as the single-hand supercell screen. Without this, the classic
	# btn.icon renders ON TOP of the back_btn.png stylebox.
	call_deferred("_apply_supercell_back_btn")
	# Bump bottom-bar control sizes from classic's 36px-tall layout to
	# the chunkier supercell 80px scale so the multi/ultra screens match
	# the single-hand visual weight.
	call_deferred("_apply_supercell_button_sizes")
	# Pull main-hand cards 2px closer (12 → 10) for the same compact
	# spacing as single-hand supercell. Mini extra-hand grids are not
	# touched — those keep classic's wider gap.
	call_deferred("_apply_supercell_main_hand_spacing")
	# Bet level is locked at 1 across the supercell skin — the wager per
	# round is purely the denomination × num_hands. BET / MAX BET buttons
	# are hidden so they can't desync the locked value.
	call_deferred("_lock_supercell_bet_to_one")
	# With BET / MAX BET hidden, the middle group looks lopsided — pull
	# SPEED out of the left cluster into the middle so it sits next to
	# HANDS / DENOM.
	call_deferred("_relocate_speed_to_middle")
	# Move the INFO "i" button from bottom bar to the top header so the
	# top bar matches single-hand supercell.
	call_deferred("_relocate_info_to_top_bar")
	# Skin Ultra VP multiplier plaques with the supercell PNG stickers.
	# (No-op when not Ultra.)
	call_deferred("_skin_ultra_multiplier_plaques")
	# Bump WIN / TOTAL BET / BALANCE labels and their currency-display
	# glyphs to 2× the classic 16px scale so the readouts read at a
	# glance from across the room — the supercell screens have more
	# breathing room than classic, the bigger numbers fit naturally.
	call_deferred("_apply_supercell_info_row_sizes")
	# Re-skin the "+" topup button to the same 72×72 PNG plate as the
	# single-hand supercell, instead of the classic blue mini button.
	# Classic's text "+" looks tiny on the supercell layout (Bug 12).
	call_deferred("_apply_supercell_topup_btn")


## Override classic's entrance animation. The supercell sub-script issues
## ~11 call_deferred decorations (button sizes, relocations, font swaps,
## hand spacing) that trigger BoxContainer reflow during the brief 4-frame
## await classic uses, which snaps children back to layout-default
## positions and visually kills the mid-slide tween. Extending the wait so
## the layout settles BEFORE we capture base positions and start the
## tween restores the slide-bounce identical to classic.
func _play_entrance_animation() -> void:
	var title_bar: Control = get_node_or_null("VBoxContainer/TitleBar") as Control
	var top_nodes: Array[Control] = []
	if is_instance_valid(title_bar):
		top_nodes.append(title_bar)
	if is_instance_valid(_hands_area):
		top_nodes.append(_hands_area)
	var bottom_nodes: Array[Control] = []
	if is_instance_valid(_bottom_section):
		bottom_nodes.append(_bottom_section)
	var badge_nodes: Array[Control] = []
	if is_instance_valid(_left_badges):
		badge_nodes.append(_left_badges)
	if is_instance_valid(_right_badges):
		badge_nodes.append(_right_badges)
	# Hide synchronously before the first frame renders.
	for n in top_nodes + bottom_nodes + badge_nodes:
		n.modulate.a = 0.0
	# Wait long enough for every supercell decoration call_deferred to
	# finish AND for the resulting BoxContainer reflow to settle. 12 frames
	# (~0.2s @ 60fps) covers the 11 deferred calls comfortably.
	for i in 12:
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
		_tween_mh_section_bounce(n, base_y, overshoot_px, dur, 0.0)
	for n in bottom_nodes:
		if not is_instance_valid(n):
			continue
		var base_y: float = n.position.y
		n.position.y = base_y + slide
		n.modulate.a = 1.0
		_tween_mh_section_bounce(n, base_y, -overshoot_px, dur, 0.0)
	var badge_delay: float = 0.18
	for n in badge_nodes:
		if not is_instance_valid(n):
			continue
		var base_y: float = n.position.y
		n.position.y = base_y - slide
		n.visible = true
		_tween_mh_section_bounce(n, base_y, overshoot_px, dur, badge_delay)


## Re-skin the classic "+" topup button (small text "+" on a blue plate)
## with the supercell PNG plate used in single-hand: 72×72 plate carrying
## the baked-in "+" glyph. Without this the button shrinks to ~24px on the
## InfoRow and feels untappable on touch devices.
func _apply_supercell_topup_btn() -> void:
	if _topup_btn == null or not is_instance_valid(_topup_btn):
		return
	_topup_btn.text = ""
	_topup_btn.custom_minimum_size = Vector2(56, 56)
	_topup_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty_st := StyleBoxEmpty.new()
	_topup_btn.add_theme_stylebox_override("normal", empty_st)
	_topup_btn.add_theme_stylebox_override("hover", empty_st)
	_topup_btn.add_theme_stylebox_override("pressed", empty_st)
	_topup_btn.add_theme_stylebox_override("focus", empty_st)
	_topup_btn.add_theme_stylebox_override("disabled", empty_st)
	var icon_path := "res://assets/themes/supercell/controls/btn_plus.png"
	if ResourceLoader.exists(icon_path):
		_topup_btn.icon = load(icon_path)
		_topup_btn.expand_icon = true
	_topup_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Multi-hand supercell bet lock.
## Non-Ultra modes: bet stays at 1 (denomination = full wager).
## Ultra mode: bet is 5 (feature OFF) or 10 (feature ON, multipliers active).
## Player toggles between 5/10 by tapping the Ultra info card (the
## "ULTRA Win → Next hand gets multiplier!" plate to the right of the
## primary hand). BET/MAX BET buttons stay hidden in this skin.
func _lock_supercell_bet_to_one() -> void:
	if _manager != null and is_instance_valid(_manager):
		var locked_bet: int = 1
		if _ultra_vp:
			# Restore feature state from saved bet (5 or 10). Default OFF.
			var saved: int = SaveManager.get_bet_level(_manager.mode_id)
			locked_bet = 10 if saved >= 10 else 5
		_manager.bet = locked_bet
		if _manager.has_method("get") and "mode_id" in _manager:
			SaveManager.set_bet_level(_manager.mode_id, locked_bet)
		_manager.bet_changed.emit(locked_bet)
		_update_bet_display(locked_bet)
	if _bet_btn != null and is_instance_valid(_bet_btn):
		_bet_btn.visible = false
		_bet_btn.disabled = true
	if _bet_max_btn != null and is_instance_valid(_bet_max_btn):
		_bet_max_btn.visible = false
		_bet_max_btn.disabled = true
	# Refresh the COINS button so the displayed denom × 5 × (1 or 2) +
	# yellow accent reflect the current feature state.
	if _ultra_vp:
		call_deferred("_update_bet_amount_btn")
		call_deferred("_install_ultra_x2_badge")
	# Force LilitaOne onto every label / button classic just built. The
	# subclass's own ctor doesn't touch them, so without this they keep
	# the engine default font even with the supercell theme active.
	call_deferred("_apply_supercell_font_recursive", self)


var _ultra_x2_badge: Panel = null

## Compact "×2" sticker glued to the COINS button's top-right corner.
## Attached to the scene root with manual positioning so it sits OUTSIDE
## every layout container — it cannot push or shift any sibling.
## Position is synced to the button's global rect via the button's
## `item_rect_changed` signal. Visibility tracks the feature state.
func _install_ultra_x2_badge() -> void:
	if not _ultra_vp:
		return
	if _bet_amount_btn == null or not is_instance_valid(_bet_amount_btn):
		call_deferred("_install_ultra_x2_badge")
		return
	if _ultra_x2_badge != null and is_instance_valid(_ultra_x2_badge):
		_refresh_ultra_x2_badge()
		return
	const BADGE_W := 40
	const BADGE_H := 26
	_ultra_x2_badge = Panel.new()
	_ultra_x2_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ultra_x2_badge.custom_minimum_size = Vector2(BADGE_W, BADGE_H)
	_ultra_x2_badge.size = Vector2(BADGE_W, BADGE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("FFCC2E")
	sb.border_color = Color("152033")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.anti_aliasing = true
	_ultra_x2_badge.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "×2"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("152033"))
	var f: Font = ThemeManager.font()
	if f != null:
		lbl.add_theme_font_override("font", f)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ultra_x2_badge.add_child(lbl)
	# Attach to scene root so the badge sits ABOVE the bottom bar and
	# isn't clipped by any container.
	add_child(_ultra_x2_badge)
	_ultra_x2_badge.z_index = 100
	if not _bet_amount_btn.item_rect_changed.is_connected(_position_ultra_x2_badge):
		_bet_amount_btn.item_rect_changed.connect(_position_ultra_x2_badge)
	_position_ultra_x2_badge()
	_refresh_ultra_x2_badge()


func _position_ultra_x2_badge() -> void:
	if _ultra_x2_badge == null or not is_instance_valid(_ultra_x2_badge):
		return
	if _bet_amount_btn == null or not is_instance_valid(_bet_amount_btn):
		return
	# Mostly tucked inside the COINS button's top-right corner — only a
	# small lip overhangs (≈10% top / 20% right) so it reads as a sticker
	# without floating away from the button.
	var btn_rect: Rect2 = _bet_amount_btn.get_global_rect()
	var bw: float = _ultra_x2_badge.size.x
	var bh: float = _ultra_x2_badge.size.y
	_ultra_x2_badge.global_position = Vector2(
		btn_rect.position.x + btn_rect.size.x - bw * 0.8,
		btn_rect.position.y - bh * 0.1
	)


func _refresh_ultra_x2_badge() -> void:
	if _ultra_x2_badge == null or not is_instance_valid(_ultra_x2_badge):
		return
	var feature_on: bool = _manager != null and is_instance_valid(_manager) and _manager.bet >= 10
	_ultra_x2_badge.visible = feature_on


## Whenever the bet flips (info-card toggle, save load, hand-count
## reset), repaint the COINS button so its value shows denom × 5 × 2
## and tints yellow when the feature is ON. Classic's `_on_bet_changed`
## doesn't touch this button, so we restamp it here.
func _on_bet_changed(new_bet: int) -> void:
	super._on_bet_changed(new_bet)
	if _ultra_vp:
		_update_bet_amount_btn()
		_refresh_ultra_x2_badge()


## Defensive override: classic's HOLDING / DRAWING branches don't
## explicitly disable the COINS (denomination) button — it relies on
## DEALING's prior disable persisting. In Ultra mode something between
## DEALING and HOLDING re-enables it, leaving the button visually
## active mid-round. Force-disable across every in-round state.
func _on_state_changed(new_state: int) -> void:
	super._on_state_changed(new_state)
	if _bet_amount_btn == null or not is_instance_valid(_bet_amount_btn):
		return
	match new_state:
		MultiHandManager.State.IDLE, MultiHandManager.State.WIN_DISPLAY:
			# parent enables / leaves enabled — bet can be changed here
			pass
		_:
			_bet_amount_btn.disabled = true
			_bet_amount_btn.modulate.a = 0.5


## Override classic's `_on_info_card_clicked`: in Supercell the Ultra
## info card acts purely as an ON/OFF toggle for the feature (bet 5↔10).
## It does NOT start a round — player must press DEAL afterwards.
## Classic's behavior (activate + immediate deal) is unchanged in its skin.
func _on_info_card_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _is_bet_locked():
		return
	if _manager == null or not is_instance_valid(_manager):
		return
	var new_bet: int = 5 if _manager.bet >= 10 else 10
	_manager.bet = new_bet
	SaveManager.set_bet_level(_manager.mode_id, new_bet)
	SaveManager.save_game()
	_manager.bet_changed.emit(new_bet)


## Override classic's compact 36px-tall button sizing with the supercell
## 80px scale, mirroring the single-hand supercell screen. Each width is
## tuned to match its PNG asset's aspect (so the texture isn't squished)
## while leaving room for a full bottom-bar row at 1080p portrait width.
func _apply_supercell_button_sizes() -> void:
	const BTN_H := 80
	if _info_btn != null and is_instance_valid(_info_btn):
		_info_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	if _speed_btn != null and is_instance_valid(_speed_btn):
		_speed_btn.custom_minimum_size = Vector2(110, BTN_H)
	if _hands_btn != null and is_instance_valid(_hands_btn):
		_hands_btn.custom_minimum_size = Vector2(110, BTN_H)
		# Classic styled HANDS with `COL_BTN_TEXT` (dark brown) so the
		# label was unreadable on the supercell purple plate. Force white
		# across every state so the supercell skin reads correctly.
		_hands_btn.add_theme_color_override("font_color", Color.WHITE)
		_hands_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		_hands_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		_hands_btn.add_theme_color_override("font_focus_color", Color.WHITE)
	if _bet_amount_btn != null and is_instance_valid(_bet_amount_btn):
		_bet_amount_btn.custom_minimum_size = Vector2(180, BTN_H)
	if _bet_btn != null and is_instance_valid(_bet_btn):
		_bet_btn.custom_minimum_size = Vector2(130, BTN_H)
	if _bet_max_btn != null and is_instance_valid(_bet_max_btn):
		_bet_max_btn.custom_minimum_size = Vector2(150, BTN_H)
	if _double_btn != null and is_instance_valid(_double_btn):
		_double_btn.custom_minimum_size = Vector2(120, BTN_H)
	if _deal_draw_btn != null and is_instance_valid(_deal_draw_btn):
		_deal_draw_btn.custom_minimum_size = Vector2(180, BTN_H)
	# Bottom bar just grew from classic's 36px to supercell's 80px, which
	# shrinks %ExtraHandsRect — but classic's `_size_extra_hands` already
	# ran on the old (taller) extras rect, so the mini hands overlap the
	# main row on first entry. Wait for the next layout pass and recompute.
	await get_tree().process_frame
	_size_extra_hands()


## Recursively walks a Control subtree and pushes ThemeManager.font()
## onto every Label / RichTextLabel / Button it finds — used after
## super._ready() so labels built by the classic parent script also get
## the supercell font applied.
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


func _refresh_currency_displays() -> void:
	# In-place chip swap on classic-built currency displays so the
	# supercell coin replaces the classic chip without disturbing the
	# digit children. Includes _bet_btn_cd (the chip-glyph row that lives
	# inside the BET AMOUNT button) so it picks up the supercell coin
	# even when classic built it before the theme was applied.
	for cd in [_balance_cd, _bet_cd, _win_cd, _bet_btn_cd]:
		if cd is Dictionary:
			SaveManager.refresh_chip_in_box(cd)


## 2× scale-up for the bottom info row (WIN / TOTAL BET / BALANCE):
## bumps each label's font_size from classic's 16 to 32 and rebuilds
## the chip-glyph row at glyph_h=32 so the values stay vertically
## aligned with the labels.
func _apply_supercell_info_row_sizes() -> void:
	const LABEL_FS := 32
	const GLYPH_H := 32
	if _win_label != null and is_instance_valid(_win_label):
		_win_label.add_theme_font_size_override("font_size", LABEL_FS)
	if _total_bet_label != null and is_instance_valid(_total_bet_label):
		_total_bet_label.add_theme_font_size_override("font_size", LABEL_FS)
	if _balance_label != null and is_instance_valid(_balance_label):
		_balance_label.add_theme_font_size_override("font_size", LABEL_FS)
	# Currency display glyphs are stored in cd["glyph_h"] and read on
	# every set_currency_value rebuild. Empty-text branch resizes the
	# existing glyphs in-place without rebuilding (preserves whatever
	# value the FSM put there last).
	for cd in [_win_cd, _bet_cd, _balance_cd]:
		if cd is Dictionary:
			cd["glyph_h"] = GLYPH_H
			SaveManager.set_currency_value(cd, "", GLYPH_H)
	# Re-emit live values via the FSM so any short-format rule (e.g.
	# 12,500 → "12.5K") gets applied at the new glyph height.
	_update_balance(SaveManager.credits)
	_update_bet_display(_manager.bet)


## Strips the classic exit-icon + 160px left padding off the back button
## so the supercell `back_btn.png` stylebox renders cleanly as a square
## red sticker — matching the single-hand supercell back button. Adds a
## leading spacer to give the same screen-edge padding as single uses.
func _apply_supercell_back_btn() -> void:
	if _back_btn == null or not is_instance_valid(_back_btn):
		return
	_back_btn.icon = null
	_back_btn.expand_icon = false
	_back_btn.text = ""
	_back_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Wipe the LEFT_MARGIN-content stylebox classic installed (which
	# stretched the supercell PNG into a wide pill) before the texture
	# swap below paints over it.
	var clean := StyleBoxFlat.new()
	clean.bg_color = Color(0, 0, 0, 0)
	_back_btn.add_theme_stylebox_override("normal", clean)
	_back_btn.add_theme_stylebox_override("hover", clean)
	_back_btn.add_theme_stylebox_override("pressed", clean)
	_back_btn.add_theme_stylebox_override("focus", clean)
	_apply_btn_png(_back_btn, "back_btn.png")
	# Leading spacer in the parent HBox so the button sits the configured
	# distance from the screen edge — matches single's `top.offset_left`.
	var parent: Node = _back_btn.get_parent()
	if parent is BoxContainer and parent.get_child(0) != _back_btn:
		# Already not the first child — assume someone else added padding.
		return
	if parent is BoxContainer:
		var pad := Control.new()
		pad.name = "SupercellEdgePad"
		pad.custom_minimum_size = Vector2(SUPERCELL_TOP_EDGE_PAD, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(pad)
		parent.move_child(pad, _back_btn.get_index())


func _apply_supercell_main_hand_spacing() -> void:
	# Tighter than the previous 10px gap — primary-row cards now sit
	# almost shoulder-to-shoulder. Extra-hand grids are NOT touched, so
	# the 5×N matrix above keeps its wider gap and the row hierarchy
	# (big primary cards close, small extras spaced) reads cleanly.
	if _primary_container != null and is_instance_valid(_primary_container):
		_primary_container.add_theme_constant_override("separation", 4)


## Override classic's badge builders so the LilitaOne font is reapplied
## every time the badges are (re)built. Classic's `_update_paytable_badges`
## explicitly calls `remove_theme_font_override("font")` on non-jackpot
## badges (line 3119), which strips the font set during _make_badge or
## by the recursive walker.
func _build_paytable_badges() -> void:
	super._build_paytable_badges()
	_apply_font_to_badges()


func _update_paytable_badges() -> void:
	super._update_paytable_badges()
	_apply_font_to_badges()


func _apply_font_to_badges() -> void:
	var f: Font = ThemeManager.font()
	if f == null:
		return
	for lab in _badge_labels:
		if lab != null and is_instance_valid(lab):
			lab.add_theme_font_override("font", f)


## Hand switching rebuilds the extra-hand grid (new MiniHandDisplay
## instances → fresh Label children with the engine default font) and
## also re-runs `_update_paytable_badges` (already covered above). After
## the switch animation settles we re-walk the whole tree so any newly
## created label adopts LilitaOne too.
func _switch_hand_count(new_count: int) -> void:
	await super._switch_hand_count(new_count)
	_apply_supercell_font_recursive(self)
	_apply_font_to_badges()
	_skin_ultra_multiplier_plaques()
	if _ultra_vp:
		# Hand-count switch may rebuild buttons — restamp COINS.
		call_deferred("_update_bet_amount_btn")


## Replace the dark-blue procedural plaque drawn behind every Ultra VP
## next/active multiplier display with the supercell PNG sticker
## (mult_next.png / mult_active.png). Disconnects the classic draw
## callback so it doesn't paint the old plate underneath.
func _skin_ultra_multiplier_plaques() -> void:
	if not _ultra_vp:
		return
	var next_path: String = ThemeManager.theme_folder() + "controls/mult_next.png"
	var active_path: String = ThemeManager.theme_folder() + "controls/mult_active.png"
	var next_tex: Texture2D = load(next_path) if ResourceLoader.exists(next_path) else null
	var active_tex: Texture2D = load(active_path) if ResourceLoader.exists(active_path) else null
	for disp in _next_displays:
		_attach_supercell_plaque(disp, next_tex)
	for disp in _active_displays:
		_attach_supercell_plaque(disp, active_tex)


func _attach_supercell_plaque(disp: Control, tex: Texture2D) -> void:
	if disp == null or not is_instance_valid(disp) or tex == null:
		return
	if disp.get_node_or_null("SupercellMultBg") != null:
		return  # already skinned
	# Drop classic's procedural draw callback (the dark-blue rounded rect).
	for conn in disp.draw.get_connections():
		disp.draw.disconnect(conn.callable)
	var bg := TextureRect.new()
	bg.name = "SupercellMultBg"
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Slight outward bleed so the sticker shape extends past the glyph
	# row's tight bbox (matches classic's 6px×4px padding offset).
	bg.offset_left = -10
	bg.offset_right = 10
	bg.offset_top = -6
	bg.offset_bottom = 6
	bg.z_index = -1
	disp.add_child(bg)
	disp.move_child(bg, 0)


## Move SPEED out of the left cluster into the middle cluster so the
## supercell bottom bar reads as INFO | SPEED HANDS DENOM | DEAL —
## matches the visual rhythm the user wants (BET / BET MAX are hidden,
## DOUBLE is hidden under supercell branding, leaving SPEED + HANDS +
## DENOM together as the middle group).
## Wrap classic's `_bet_btn_cd` chip+amount row with a leading "COINS:"
## label so the multi-hand DENOM button reads `COINS: <chip> 100` —
## visually identical to the single-hand supercell COINS picker. First
## call builds the wrapper; subsequent calls just refresh the value.
var _coins_prefix_in_bet_btn: Label = null
var _coins_btn_wrap: HBoxContainer = null

func _update_bet_amount_btn() -> void:
	if _bet_amount_btn == null:
		return
	_bet_amount_btn.text = ""
	_bet_amount_btn.icon = null
	if _bet_btn_cd.is_empty():
		_coins_btn_wrap = HBoxContainer.new()
		_coins_btn_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		_coins_btn_wrap.add_theme_constant_override("separation", 4)
		_coins_btn_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_coins_btn_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bet_amount_btn.add_child(_coins_btn_wrap)

		_coins_prefix_in_bet_btn = Label.new()
		_coins_prefix_in_bet_btn.text = "COINS:"
		_coins_prefix_in_bet_btn.add_theme_font_size_override("font_size", 18)
		_coins_prefix_in_bet_btn.add_theme_color_override("font_color", Color.WHITE)
		var f: Font = ThemeManager.font()
		if f != null:
			_coins_prefix_in_bet_btn.add_theme_font_override("font", f)
		_coins_prefix_in_bet_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_coins_btn_wrap.add_child(_coins_prefix_in_bet_btn)

		_bet_btn_cd = SaveManager.create_currency_display(18, Color.WHITE)
		_bet_btn_cd["box"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bet_btn_cd["box"].add_theme_constant_override("separation", 2)
		_coins_btn_wrap.add_child(_bet_btn_cd["box"])
	# Force the compact "5K" / "1.2M" form instead of `format_auto` —
	# the COINS button only has ~60px left after the "COINS:" prefix and
	# chip glyph, so a 4-digit "5,000" overflows the rounded plate.
	# Ultra: display the denomination × 5 (matches picker rows). When the
	# ×2 multiplier feature is ON (bet == 10), the displayed amount is
	# doubled AND the prefix + digits switch from white to yellow so the
	# player sees at a glance they're paying the boosted price.
	var shown_amount: int = _current_denomination
	var feature_on: bool = false
	if _ultra_vp:
		shown_amount = _current_denomination * 5
		feature_on = _manager != null and is_instance_valid(_manager) and _manager.bet >= 10
		if feature_on:
			shown_amount *= 2
	var col: Color = COL_YELLOW if feature_on else Color.WHITE
	if _coins_prefix_in_bet_btn != null and is_instance_valid(_coins_prefix_in_bet_btn):
		_coins_prefix_in_bet_btn.add_theme_color_override("font_color", col)
	SaveManager.set_currency_value(_bet_btn_cd, SaveManager.format_short(shown_amount), 0, col)


func _relocate_speed_to_middle() -> void:
	if _speed_btn == null or not is_instance_valid(_speed_btn):
		return
	if _hands_btn == null or not is_instance_valid(_hands_btn):
		return
	var bar: Node = _speed_btn.get_parent()
	if bar == null or not bar.has_method("move_child"):
		return
	# Position SPEED immediately before HANDS so it sits at the start of
	# the middle group, after the left-side spacer/info.
	bar.move_child(_speed_btn, _hands_btn.get_index())


## Move classic's INFO "i" button from the bottom bar into the top
## header (next to the back button) — mirrors the single-hand supercell
## layout. Size and skin match single's 58×58 sticker so all three modes
## look the same.
func _relocate_info_to_top_bar() -> void:
	if _info_btn == null or not is_instance_valid(_info_btn):
		return
	if _back_btn == null or not is_instance_valid(_back_btn):
		return
	var top_bar: Node = _back_btn.get_parent()
	if top_bar == null:
		return
	var current_parent: Node = _info_btn.get_parent()
	if current_parent != null:
		current_parent.remove_child(_info_btn)
	# TitleBar HBox doesn't have any EXPAND_FILL siblings (back + title
	# spacer pack to the left), so a freshly-added child would pile up on
	# the left edge. Insert an expanding spacer first to push the info
	# button to the far right of the top bar.
	var prev_spacer: Node = top_bar.get_node_or_null("SupercellInfoSpacer")
	if prev_spacer != null:
		prev_spacer.queue_free()
	var info_spacer := Control.new()
	info_spacer.name = "SupercellInfoSpacer"
	info_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(info_spacer)
	top_bar.add_child(_info_btn)
	# Right-edge padding mirrors single-hand's `top.offset_right =
	# -SUPERCELL_TOP_EDGE_PAD` so the "i" button sits 32px from the
	# screen edge instead of glued to it.
	var prev_edge: Node = top_bar.get_node_or_null("SupercellRightEdgePad")
	if prev_edge != null:
		prev_edge.queue_free()
	var edge_pad := Control.new()
	edge_pad.name = "SupercellRightEdgePad"
	edge_pad.custom_minimum_size = Vector2(SUPERCELL_TOP_EDGE_PAD, 0)
	edge_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(edge_pad)
	_info_btn.icon = null
	_info_btn.custom_minimum_size = Vector2(SUPERCELL_TOP_ICON_SIZE, SUPERCELL_TOP_ICON_SIZE)
	_info_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Wipe whatever stylebox classic painted (left-margin pill etc.) so
	# info_btn.png stretches as a clean 58×58 square sticker.
	var clean := StyleBoxFlat.new()
	clean.bg_color = Color(0, 0, 0, 0)
	_info_btn.add_theme_stylebox_override("normal", clean)
	_info_btn.add_theme_stylebox_override("hover", clean)
	_info_btn.add_theme_stylebox_override("pressed", clean)
	_info_btn.add_theme_stylebox_override("focus", clean)
	_apply_btn_png(_info_btn, "info_btn.png")
	# info_btn.png is a plain blue square — render the "i" letter on top
	# via the button's own text so it never disappears no matter what
	# classic re-applies later.
	_info_btn.text = "i"
	_info_btn.add_theme_font_size_override("font_size", 38)
	_info_btn.add_theme_color_override("font_color", Color.WHITE)
	_info_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_info_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_info_btn.add_theme_color_override("font_focus_color", Color.WHITE)
	_info_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info_btn.add_theme_constant_override("outline_size", 4)
	var f: Font = ThemeManager.font()
	if f != null:
		_info_btn.add_theme_font_override("font", f)


## Override classic's blue "SELECT BET" popup with the supercell-styled
## purple/yellow popup (same chrome as single's denom picker). The title
## and option formatting mirror single's `_show_picker` so all three
## modes look identical when picking a denomination.
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
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
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

	var pick_path: String = ThemeManager.theme_folder() + "controls/btn_denom_pick.png"
	var has_pick_tex: bool = ResourceLoader.exists(pick_path)
	var pick_tex: Texture2D = load(pick_path) if has_pick_tex else null
	for amount in BET_AMOUNTS:
		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size = Vector2(220, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if has_pick_tex:
			var st := StyleBoxTexture.new()
			st.texture = pick_tex
			st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			btn.add_theme_stylebox_override("normal", st)
			btn.add_theme_stylebox_override("hover", st)
			btn.add_theme_stylebox_override("pressed", st)
			btn.add_theme_stylebox_override("focus", st)
		else:
			# Fallback: flat yellow sticker like single's plus-button.
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
		# Ultra: each row reads denom × 5 (static, never recomputed).
		# Other modes: raw denom.
		var displayed_amount: int = amount * 5 if _ultra_vp else amount
		SaveManager.set_currency_value(cd, SaveManager.format_auto(displayed_amount, 140, 20))
		btn.add_child(cd["box"])
		btn.pressed.connect(func() -> void:
			# Defense in depth: refuse to apply if state changed under us.
			# `_is_bet_locked()` is inherited from `multi_hand_game.gd`.
			if _is_bet_locked():
				if _bet_picker_overlay:
					_bet_picker_overlay.queue_free()
					_bet_picker_overlay = null
				return
			if _ultra_vp:
				_save_ux_state()
			_current_denomination = amount
			SaveManager.denomination = amount
			if _ultra_vp:
				_load_ux_state()
				_update_multiplier_labels()
			_update_bet_amount_btn()
			_update_bet_display(_manager.bet)
			if _balance_show_depth:
				_update_balance(SaveManager.credits)
			_bet_picker_overlay.queue_free()
			_bet_picker_overlay = null
		)
		grid.add_child(btn)


## Override classic's title builder so the multi-hand table shows the
## same lobby-style title as the supercell tile (e.g. "QUAD HUNT" or
## "ULTRA VP — CLASSIC DRAW") instead of the literal paytable name.
func _update_title() -> void:
	if _game_title == null:
		return
	var id: String = SaveManager.last_variant
	var supercell_title: String = ThemeManager.machine_title(id)
	var title: String
	if supercell_title != "":
		title = supercell_title.replace("\n", " ").to_upper()
	else:
		title = _variant.paytable.name.to_upper()
	if _ultra_vp:
		title = "ULTRA VP — " + title
	_game_title.text = title
	# Re-anchor the title to the viewport's top band so it sits at screen
	# center regardless of where classic placed it in its top container.
	# Done here (rather than once in _ready) because classic's _apply_theme
	# may stomp our anchors after layout settles.
	_center_title_on_screen()


func _center_title_on_screen() -> void:
	if _game_title == null or not is_instance_valid(_game_title):
		return
	# Detach from any parent container that's positioning it via flow
	# layout (HBox/VBox), then re-parent to the scene root with full-width
	# top-anchored bounds + horizontal-center alignment.
	var parent: Node = _game_title.get_parent()
	if parent != null and parent != self:
		parent.remove_child(_game_title)
		add_child(_game_title)
	# Use set_anchors_and_offsets_preset (not just set_anchors_preset) so
	# the previous narrow visual rect doesn't leak into offset_left /
	# offset_right — that's what was pinning the title to the top-left
	# corner instead of letting it span the full screen width.
	# Vertical band aligns with the back-button row (y=8..72) so the
	# title sits IN the top bar (between back/info), not below it where
	# it would crowd the cards.
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


## Override classic's `_setup_background` so the emerald gradient
## TextureRect children it normally adds are never created in the
## supercell reskin. Called every time classic re-applies the theme
## (bet change, etc.) so our paint stays dominant.
func _setup_background() -> void:
	_install_supercell_background()


## Replaces the classic table-felt gradients with a supercell machine
## gradient + mode tint. Classic populates `%Background` with TextureRect
## children that paint emerald gradients on top of any draw callback we
## add — so we FIRST strip those children, THEN install our own draw.
func _install_supercell_background() -> void:
	# %Background exists as a unique-name node in the classic multi
	# scene; grab it via find_child to match classic's own lookup path.
	var bg_node: Control = find_child("Background", true, false) as Control
	if bg_node == null:
		return
	# Remove classic's TextureRect gradient children so our draw wins.
	for child in bg_node.get_children():
		child.queue_free()
	# Disconnect any previous supercell draw we may have attached on
	# a prior _apply_theme pass so we don't stack up callbacks.
	for conn in bg_node.draw.get_connections():
		bg_node.draw.disconnect(conn.callable)
	var vid: String = ""
	if _variant != null and _variant.paytable != null:
		vid = _variant.paytable.variant_id
	var grad: Array = ThemeManager.machine_gradient(vid)
	var top_c: Color = grad[0] if grad.size() == 2 else Color("2F7A3A")
	var bot_c: Color = grad[1] if grad.size() == 2 else Color("1F5C26")
	var tint: Color = ULTRA_TINT if _ultra_vp else MODE_TINTS.get(_num_hands, Color(1, 1, 1, 0))
	if bg_node is ColorRect:
		(bg_node as ColorRect).color = Color(0, 0, 0, 0)
	bg_node.draw.connect(func() -> void:
		var ci := bg_node.get_canvas_item()
		var rect := Rect2(Vector2.ZERO, bg_node.size)
		_draw_vertical_gradient(ci, rect, top_c, bot_c)
		if tint.a > 0.0:
			RenderingServer.canvas_item_add_rect(ci, rect, tint)
	)


## Tries to load PNG replacements for the main control buttons from
## the active theme folder. Any missing file leaves the classic
## stylebox intact — scene remains fully functional even with zero
## supercell assets on disk.
func _swap_control_textures() -> void:
	var pairs := [
		["DealDrawButton",   "btn_draw.png"],
		["BetMaxButton",     "btn_max_bet.png"],
		["BetButton",        "btn_bet_lvl.png"],
		["BetAmountButton",  "btn_denom.png"],
		["SpeedButton",      "btn_speed.png"],
		["HandsButton",      "btn_hands.png"],
		["BackButton",       "back_btn.png"],
	]
	for pair in pairs:
		var node_name: String = pair[0]
		var filename: String = pair[1]
		var btn: Button = _find_button_by_name(node_name)
		if btn == null:
			continue
		_apply_btn_png(btn, filename)
	# DOUBLE and INFO are code-created (no scene name) — apply by field ref.
	if _double_btn != null and is_instance_valid(_double_btn):
		_apply_btn_png(_double_btn, "btn_double.png")
		# Classic's `_style_btn` painted DOUBLE text in `COL_BTN_TEXT`
		# (dark brown) on the yellow plate; supercell's purple/yellow
		# chrome wants white text instead. Override every state's color
		# so hover / pressed don't fall back to the dark default.
		_double_btn.add_theme_color_override("font_color", Color.WHITE)
		_double_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		_double_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		_double_btn.add_theme_color_override("font_focus_color", Color.WHITE)
		# Bump DOUBLE label to 1.33× classic's 13px so it's legible on
		# the bigger supercell yellow plate.
		_double_btn.add_theme_font_size_override("font_size", 17)
	if _info_btn != null and is_instance_valid(_info_btn):
		_apply_btn_png(_info_btn, "info_btn.png")
	# Same scale-up for DEAL / DRAW so it matches DOUBLE's new size.
	if _deal_draw_btn != null and is_instance_valid(_deal_draw_btn):
		_deal_draw_btn.add_theme_font_size_override("font_size", 24)


func _find_button_by_name(node_name: String) -> Button:
	var candidate: Node = find_child(node_name, true, false)
	return candidate as Button if candidate is Button else null


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
	# Dim the same texture for the disabled state so e.g. DOUBLE before a
	# winning hand reads as "locked" instead of falling back to Godot's
	# default flat-grey disabled box.
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
