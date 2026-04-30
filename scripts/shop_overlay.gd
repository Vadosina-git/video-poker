extends Node
## Autoload. Shows the IGT-style shop overlay on any host scene — lobby, single-
## hand game, multi-hand, Ultra VP, Spin Poker. All three game screens + lobby
## call `ShopOverlay.show(self)` to open the exact same UI.
##
## Shop stays open after purchase / gift claim; only the close (X) button
## dismisses it.


signal shop_closed

const GIFT_ICON_SIZE := 56
const GIFT_BTN_W := 180
const GIFT_BTN_H := 56
const GIFT_ICON_OVERLAP := 22

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

# --- State ------------------------------------------------------------------
var _overlay: Control = null
var _host: Node = null
var _cash_pill: PanelContainer = null
var _cash_cd: Dictionary = {}
var _gift_widget: Control = null
var _gift_icon: TextureRect = null
var _gift_label_area: VBoxContainer = null


func _process(_delta: float) -> void:
	# Keep the shop-side gift timer in sync while gift is recharging.
	if not is_instance_valid(_overlay):
		return
	if _gift_label_area and is_instance_valid(_gift_label_area) and not _is_gift_ready():
		var timer_label := _gift_label_area.get_node_or_null("Timer") as Label
		if timer_label:
			var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
			var remaining: int = interval_sec - (int(Time.get_unix_time_from_system()) - SaveManager.last_gift_time)
			var h: int = remaining / 3600
			var m: int = (remaining % 3600) / 60
			var s: int = remaining % 60
			timer_label.text = "%dH %dM %dS" % [h, m, s]


# --- Public API -------------------------------------------------------------

## Open the shop as a child of `host`. No-op if already open.
func show(host: Node) -> void:
	if is_instance_valid(_overlay):
		return
	if not is_instance_valid(host):
		return
	_host = host
	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 100
	_host.add_child(_overlay)

	# Backdrop fades in. Per-skin dim color via ThemeManager so the supercell
	# purple haze appears under the shop overlay just like under popups.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_target: Color = ThemeManager.popup_dim_color() if _is_supercell() else Color(0.05, 0.04, 0.22, 1.0)
	bg.color = Color(dim_target.r, dim_target.g, dim_target.b, 0.0)
	_overlay.add_child(bg)
	bg.create_tween().tween_property(bg, "color:a", dim_target.a, 0.2)

	# Slide-up + bounce open animation on the overlay as a whole.
	var vp_size: Vector2 = _host.get_viewport_rect().size
	_overlay.pivot_offset = Vector2(vp_size.x * 0.5, vp_size.y)
	_overlay.scale = Vector2(0.95, 0.95)
	_overlay.position.y = 40
	_overlay.modulate.a = 0.0
	var intro := _overlay.create_tween().set_parallel(true)
	intro.tween_property(_overlay, "modulate:a", 1.0, 0.22)
	intro.tween_property(_overlay, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	intro.tween_property(_overlay, "position:y", 0.0, 0.28) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Close X button. In supercell — red danger-sticker with drop shadow;
	# in classic — yellow round chip (legacy IGT look).
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 64)
	close_btn.add_theme_font_size_override("font_size", 40)
	var close_fill: Color
	var close_border: Color
	var close_text: Color
	if _is_supercell():
		close_fill = ThemeManager.color("button_danger_bg", Color("E63946"))
		close_border = ThemeManager.color("button_danger_border", Color("152033"))
		close_text = ThemeManager.color("button_danger_text", Color.WHITE)
	else:
		close_fill = Color("FFEC00")
		close_border = Color(0.35, 0.28, 0.0)
		close_text = Color.BLACK
	close_btn.add_theme_color_override("font_color", close_text)
	var cs := _make_skin_sticker(close_fill, close_border, 32)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_stylebox_override("hover", cs)
	close_btn.add_theme_stylebox_override("pressed", cs)
	close_btn.add_theme_stylebox_override("focus", cs)
	close_btn.pressed.connect(hide_shop)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_attach_press_effect(close_btn)
	_overlay.add_child(close_btn)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -88
	close_btn.offset_right = -24
	close_btn.offset_top = 24
	close_btn.offset_bottom = 88

	# Balance pill (top-left).
	var bal_pill := _build_balance_pill()
	_overlay.add_child(bal_pill)
	bal_pill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bal_pill.offset_left = 24
	bal_pill.offset_top = 24

	# Pack cards scroll.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 110
	scroll.offset_bottom = -140
	_overlay.add_child(scroll)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Stretch to scroll viewport width so ALIGNMENT_CENTER actually centers
	# the cards instead of hugging content to the left edge.
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 32)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(row)

	var items := ConfigManager.get_shop_items()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
	)
	for it in items:
		row.add_child(_build_pack_card(it))

	# Exchange-rate label (if enabled in config).
	var rate_cfg: Dictionary = ConfigManager.shop.get("exchange_rate", {})
	if rate_cfg.get("show_label", false):
		var rate_hb := _build_exchange_rate_row(int(rate_cfg.get("coins_per_dollar", 100)))
		_overlay.add_child(rate_hb)
		rate_hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		rate_hb.grow_horizontal = Control.GROW_DIRECTION_BOTH
		rate_hb.offset_top = -56
		rate_hb.offset_bottom = -20

	# "Restore Purchases" link, bottom-left (App Store review requires it).
	var restore_btn := Button.new()
	restore_btn.text = Translations.tr_key("shop.restore")
	restore_btn.flat = true
	restore_btn.add_theme_font_size_override("font_size", 14)
	restore_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	restore_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restore_btn.pressed.connect(func() -> void: IapManager.restore_purchases())
	_overlay.add_child(restore_btn)
	restore_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	restore_btn.offset_left = 24
	restore_btn.offset_top = -44
	restore_btn.offset_bottom = -20

	# Gift widget at bottom-right.
	var gift := _build_gift_widget()
	_gift_widget = gift
	_overlay.add_child(gift)
	gift.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var gw: float = gift.custom_minimum_size.x
	var gh: float = gift.custom_minimum_size.y
	gift.offset_left = -gw - 24
	gift.offset_top = -gh - 24
	gift.offset_right = -24
	gift.offset_bottom = -24

	# Final pass: apply theme font (LilitaOne in supercell) to every
	# Label/Button so all chrome reads in one design language without each
	# helper having to inject the font itself.
	_apply_theme_font_recursive(_overlay)


func hide_shop() -> void:
	if not is_instance_valid(_overlay):
		return
	var ov := _overlay
	_overlay = null
	ov.pivot_offset = Vector2(ov.get_viewport_rect().size.x * 0.5, ov.get_viewport_rect().size.y)
	var outro := ov.create_tween().set_parallel(true)
	outro.tween_property(ov, "modulate:a", 0.0, 0.14)
	outro.tween_property(ov, "scale", Vector2(0.95, 0.95), 0.17) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	outro.tween_property(ov, "position:y", 40.0, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	outro.chain().tween_callback(ov.queue_free)
	_cash_cd = {}
	_cash_pill = null
	_gift_widget = null
	_gift_icon = null
	_gift_label_area = null
	shop_closed.emit()


# --- Balance pill -----------------------------------------------------------

func _build_balance_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	_cash_pill = pill
	var bg_col: Color = ThemeManager.color("cash_pill_bg", Color(0.05, 0.03, 0.03)) if _is_supercell() else Color(0.05, 0.03, 0.03)
	var border_col: Color = ThemeManager.color("cash_pill_border", Color("FFEC00")) if _is_supercell() else Color("FFEC00")
	var text_col: Color = ThemeManager.color("cash_pill_text", Color.WHITE) if _is_supercell() else Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_border_width_all(4)
	style.border_color = border_col
	style.set_corner_radius_all(28)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.anti_aliasing = true
	if _is_supercell():
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_offset = Vector2(0, 4)
	pill.add_theme_stylebox_override("panel", style)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(inner)

	var cash_label := Label.new()
	cash_label.text = Translations.tr_key("lobby.cash")
	cash_label.add_theme_font_size_override("font_size", 30)
	cash_label.add_theme_color_override("font_color", text_col)
	cash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cash_label.add_theme_constant_override("outline_size", 3)
	inner.add_child(cash_label)

	var cd := SaveManager.create_currency_display(32, text_col)
	inner.add_child(cd["box"])
	SaveManager.set_currency_value(cd, SaveManager.format_money(SaveManager.credits))
	_cash_cd = cd
	return pill


# --- Gift widget ------------------------------------------------------------

func _build_gift_widget() -> Control:
	var widget_w: int = GIFT_ICON_SIZE + GIFT_BTN_W - GIFT_ICON_OVERLAP
	var widget_h: int = GIFT_ICON_SIZE

	var root := Control.new()
	root.custom_minimum_size = Vector2(widget_w, widget_h)
	root.size = Vector2(widget_w, widget_h)
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.pivot_offset = Vector2(widget_w, widget_h) * 0.5

	var pill := TextureRect.new()
	pill.texture = load("res://assets/shop/gift_box_button.png")
	pill.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	pill.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	pill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pill.stretch_mode = TextureRect.STRETCH_SCALE
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)

	var la := VBoxContainer.new()
	la.position = Vector2(GIFT_ICON_SIZE - GIFT_ICON_OVERLAP, (widget_h - GIFT_BTN_H) * 0.5)
	la.size = Vector2(GIFT_BTN_W, GIFT_BTN_H)
	la.alignment = BoxContainer.ALIGNMENT_CENTER
	la.add_theme_constant_override("separation", 0)
	la.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(la)
	_gift_label_area = la

	var icon := TextureRect.new()
	icon.position = Vector2(0, 0)
	icon.size = Vector2(GIFT_ICON_SIZE, GIFT_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_gift_icon = icon

	_rebuild_gift_content(_is_gift_ready())
	_attach_hover_bounce(root)

	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var target: Vector2 = Vector2(0.93, 0.93) if event.pressed else Vector2.ONE
			var dur: float = 0.07 if event.pressed else 0.11
			var tw := root.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(root, "scale", target, dur)
			if not event.pressed and _is_gift_ready():
				var spawn_pos: Vector2 = root.global_position + root.size * 0.5
				_claim_gift(spawn_pos)
	)
	return root


func _rebuild_gift_content(ready: bool) -> void:
	if not _gift_label_area or not _gift_icon:
		return
	for child in _gift_label_area.get_children():
		_gift_label_area.remove_child(child)
		child.queue_free()

	if ready:
		_gift_icon.texture = _gift_box_texture(true)
		var collect := Label.new()
		collect.text = "COLLECT!"
		collect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		collect.add_theme_font_size_override("font_size", 22)
		collect.add_theme_color_override("font_color", Color.WHITE)
		collect.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		collect.add_theme_constant_override("outline_size", 3)
		_gift_label_area.add_child(collect)

		var amount_hb := HBoxContainer.new()
		amount_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		amount_hb.add_theme_constant_override("separation", 4)
		amount_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gift_label_area.add_child(amount_hb)

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
		_gift_icon.texture = _gift_box_texture(false)
		var timer_label := Label.new()
		timer_label.name = "Timer"
		timer_label.text = "--H --M --S"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 22)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		timer_label.add_theme_constant_override("outline_size", 3)
		_gift_label_area.add_child(timer_label)


## Resolves the gift-box texture for the current skin. Each theme can ship
## its own art at `assets/themes/<id>/icons/gift_box_icon.png` (idle) and
## `gift_box_ready_icon.png` (ready). Falls back to the shared
## `assets/shop/...` PNG when a theme doesn't override.
func _gift_box_texture(ready: bool) -> Texture2D:
	var icon_name: String = "gift_box_ready_icon" if ready else "gift_box_icon"
	var theme_path: String = ThemeManager.ui_icon_path(icon_name)
	if theme_path != "":
		return load(theme_path)
	var fallback: String = "res://assets/shop/%s.png" % icon_name
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null


func _is_gift_ready() -> bool:
	var interval_sec: int = ConfigManager.get_gift_interval_hours() * 3600
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - SaveManager.last_gift_time
	return elapsed >= interval_sec or SaveManager.last_gift_time == 0


func _claim_gift(from_pos: Vector2) -> void:
	if not _is_gift_ready():
		return
	var chips: int = ConfigManager.get_gift_chips()
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(chips)
	SaveManager.last_gift_time = int(Time.get_unix_time_from_system())
	SaveManager.save_game()
	SoundManager.play("gift_claim")
	_rebuild_gift_content(false)
	_spawn_confetti_burst(from_pos)
	_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)


# --- Pack card (main shop item) --------------------------------------------

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
	card_style.anti_aliasing = true
	if _is_supercell():
		# Supercell pack tile — drop sticker shadow + dark outline so cards
		# pop off the tinted backdrop the same way machine tiles do in lobby.
		card_style.border_color = ThemeManager.color("panel_border", scheme["border"])
		card_style.shadow_color = Color(0, 0, 0, 0.55)
		card_style.shadow_offset = Vector2(0, 6)
		card_style.set_corner_radius_all(int(ThemeManager.size("tile_corner_radius", 18)))
	card.add_theme_stylebox_override("panel", card_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vb)

	if top_badge_key != null and str(top_badge_key) != "":
		vb.add_child(_build_top_ribbon(Translations.tr_key(str(top_badge_key))))

	if bonus_chips > 0 and chips > 0:
		var strike_hb := _build_chips_display(chips, 22, Color.WHITE)
		strike_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_add_strike_line(strike_hb)
		vb.add_child(strike_hb)
		var bonus_pct: int = int(round(float(bonus_chips) / float(chips) * 100.0))
		vb.add_child(_build_bonus_banner(bonus_pct))

	var total_hb := _build_chips_display(total, 32, Color("FFEC00"))
	total_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(total_hb)

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

	if bonus_chips > 0:
		var extra := _build_extra_ribbon(bonus_chips, scheme["bonus_ribbon"])
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(extra)

	var cooldown_sec: int = int(item.get("cooldown_seconds", 0))
	if cooldown_sec > 0:
		# Free-timed pack: claim for free once per cooldown_seconds.
		vb.add_child(_build_timed_pack_button(item))
	else:
		# Paid IAP pack: routed through IapManager (stub awards, RC charges).
		var buy_btn := _build_buy_button()
		var product_id: String = str(item.get("id", ""))
		buy_btn.pressed.connect(func() -> void:
			var spawn_pos: Vector2 = buy_btn.global_position + buy_btn.size * 0.5
			_initiate_purchase(product_id, total, spawn_pos)
		)
		vb.add_child(buy_btn)

	return card


## Cooldown-aware claim button for free-timed packs. Swaps between two states
## in place (enabled green FREE ↔ disabled grey FREE IN HH:MM:SS). A 1s Timer
## ticks the countdown label while the pack is locked; on reaching zero the
## button re-enables itself without rebuilding the card.
func _build_timed_pack_button(item: Dictionary) -> Control:
	var product_id: String = str(item.get("id", ""))
	var cooldown: int = int(item.get("cooldown_seconds", 0))
	var total: int = int(item.get("chips", 0)) + int(item.get("bonus_chips", 0))

	var container := Control.new()
	container.custom_minimum_size = Vector2(0, 44)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.05, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	container.add_child(btn)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = false
	container.add_child(timer)

	var apply_state := func() -> void:
		var remaining: int = SaveManager.get_pack_cooldown_remaining(product_id, cooldown)
		if remaining <= 0:
			btn.disabled = false
			btn.text = Translations.tr_key("common.free")
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_apply_timed_btn_style(btn, false)
			timer.stop()
		else:
			btn.disabled = true
			btn.text = Translations.tr_key("shop.free_in_fmt", [_fmt_countdown(remaining)])
			_apply_timed_btn_style(btn, true)
			if timer.is_stopped():
				timer.start()

	timer.timeout.connect(apply_state)
	btn.pressed.connect(func() -> void:
		if SaveManager.get_pack_cooldown_remaining(product_id, cooldown) > 0:
			return
		var old_credits: int = SaveManager.credits
		SaveManager.add_credits(total)
		SaveManager.mark_pack_claimed(product_id)
		var spawn_pos: Vector2 = btn.global_position + btn.size * 0.5
		_spawn_confetti_burst(spawn_pos)
		_spawn_chip_cascade(spawn_pos, old_credits, SaveManager.credits)
		SoundManager.play("gift_claim")
		apply_state.call()
	)
	_attach_press_effect(btn)
	apply_state.call()
	return container


func _fmt_countdown(seconds: int) -> String:
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	var s: int = seconds % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


func _apply_timed_btn_style(btn: Button, locked: bool) -> void:
	var st: StyleBoxFlat
	if _is_supercell():
		# Supercell: yellow primary sticker (claim) / muted purple sticker (locked).
		if locked:
			var muted_fill: Color = ThemeManager.color("popup_bg", Color(0.30, 0.30, 0.36)).lightened(0.05)
			var muted_border: Color = ThemeManager.color("button_primary_border", Color(0.14, 0.14, 0.18))
			st = _make_skin_sticker(muted_fill, muted_border, 14)
			btn.add_theme_color_override("font_color", ThemeManager.color("dim_text", Color(0.85, 0.85, 0.9)))
		else:
			var fill: Color = ThemeManager.color("button_primary_bg", Color("FFCC2E"))
			var border: Color = ThemeManager.color("button_primary_border", Color("152033"))
			st = _make_skin_sticker(fill, border, 14)
			btn.add_theme_color_override("font_color", ThemeManager.color("button_primary_text", Color("2A1F00")))
			btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0))
	else:
		st = StyleBoxFlat.new()
		st.set_corner_radius_all(22)
		st.set_border_width_all(2)
		if locked:
			st.bg_color = Color(0.30, 0.30, 0.36)
			st.border_color = Color(0.14, 0.14, 0.18)
		else:
			st.bg_color = Color(0.15, 0.80, 0.35)
			st.border_color = Color(0.04, 0.40, 0.12)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("disabled", st)
	btn.add_theme_stylebox_override("focus", st)
	var hover := st.duplicate()
	if not _is_supercell() and not locked:
		(hover as StyleBoxFlat).bg_color = Color(0.20, 0.88, 0.40)
	elif _is_supercell() and not locked:
		(hover as StyleBoxFlat).bg_color = ThemeManager.color("button_primary_bg", Color("FFCC2E")).lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)


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
	# Shrink-center the Label inside HBox so its rect matches the visible
	# text height (no descender padding stretching). Strike line at
	# ctrl.size.y * 0.5 then passes through the digit centre.
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
	# Compute strike y from the Label's actual font ascent — visible digit
	# centre sits at (label_top + ascent / 2) regardless of font / theme /
	# HBox padding. Chip glyph next to digits doesn't affect this position.
	ctrl.draw.connect(func() -> void:
		if ctrl.get_child_count() == 0:
			return
		var lab: Label = ctrl.get_child(0) as Label
		if lab == null:
			var fallback_y: float = ctrl.size.y * 0.5
			ctrl.draw_line(Vector2(-2, fallback_y), Vector2(ctrl.size.x + 2, fallback_y),
				Color(1.0, 0.25, 0.25, 0.95), 3.0)
			return
		var f: Font = lab.get_theme_font("font")
		var fs: int = lab.get_theme_font_size("font_size")
		if f == null:
			f = ThemeDB.fallback_font
		if fs <= 0:
			fs = ThemeDB.fallback_font_size
		var ascent: float = f.get_ascent(fs)
		# Digit visual centre ≈ ascent/2 below label top. position.y is the
		# Label's offset within the HBox after vertical shrink-centering.
		var y: float = lab.position.y + ascent * 0.5
		ctrl.draw_line(Vector2(-2, y), Vector2(ctrl.size.x + 2, y),
			Color(1.0, 0.25, 0.25, 0.95), 3.0)
	)


func _build_bonus_banner(percent: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bonus_bg: Color = ThemeManager.color("button_primary_bg", Color("FFCC2E")) if _is_supercell() else Color("FFEC00")
	var st := StyleBoxFlat.new()
	st.bg_color = bonus_bg
	st.set_corner_radius_all(4)
	if _is_supercell():
		st.set_border_width_all(2)
		st.border_color = ThemeManager.color("button_primary_border", Color("152033"))
		st.anti_aliasing = true
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var lab := Label.new()
	lab.text = Translations.tr_key("shop.bonus_percent_fmt", [percent])
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 20)
	var bonus_text: Color = ThemeManager.color("button_primary_text", Color.BLACK) if _is_supercell() else Color.BLACK
	lab.add_theme_color_override("font_color", bonus_text)
	pc.add_child(lab)
	return pc


func _build_top_ribbon(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.clip_contents = true
	var ribbon_bg: Color = ThemeManager.color("button_primary_bg", Color("FFCC2E")) if _is_supercell() else Color("FFEC00")
	var st := StyleBoxFlat.new()
	st.bg_color = ribbon_bg
	st.set_corner_radius_all(6)
	if _is_supercell():
		st.set_border_width_all(2)
		st.border_color = ThemeManager.color("button_primary_border", Color("152033"))
		st.anti_aliasing = true
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", st)
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	var ribbon_text: Color = ThemeManager.color("button_primary_text", Color.BLACK) if _is_supercell() else Color.BLACK
	lab.add_theme_color_override("font_color", ribbon_text)
	pc.add_child(lab)
	_attach_shimmer_sweep(pc, 3.0, Color(1, 1, 1, 0.7))
	return pc


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
	var st: StyleBoxFlat
	var hover: StyleBoxFlat
	if _is_supercell():
		var fill: Color = ThemeManager.color("button_primary_bg", Color("FFCC2E"))
		var border: Color = ThemeManager.color("button_primary_border", Color("152033"))
		st = _make_skin_sticker(fill, border, 14)
		hover = st.duplicate() as StyleBoxFlat
		hover.bg_color = fill.lightened(0.08)
		btn.add_theme_color_override("font_color", ThemeManager.color("button_primary_text", Color("2A1F00")))
	else:
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.05, 0.9))
		btn.add_theme_constant_override("outline_size", 3)
		st = StyleBoxFlat.new()
		st.bg_color = Color(0.15, 0.80, 0.35)
		st.set_border_width_all(2)
		st.border_color = Color(0.04, 0.40, 0.12)
		st.set_corner_radius_all(22)
		hover = st.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.20, 0.88, 0.40)
	btn.add_theme_stylebox_override("normal", st)
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


# --- Purchase / reward animations -------------------------------------------

## Route "buy" button through IapManager. IapManager handles the actual chip
## grant (stub or RevenueCat) and emits purchase_success — we listen for that
## once-per-call and run the visual reward animations.
func _initiate_purchase(product_id: String, expected_amount: int, from_pos: Vector2) -> void:
	var old_credits: int = SaveManager.credits

	# One-shot listener — disconnects itself after firing.
	var on_success := func(pid: String, _chips: int) -> void:
		if pid != product_id:
			return
		SoundManager.play("shop_purchase")
		_spawn_confetti_burst(from_pos)
		_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)
	var on_failure := func(pid: String, err: String) -> void:
		if pid != product_id:
			return
		push_warning("Shop: purchase %s failed: %s" % [pid, err])

	IapManager.purchase_success.connect(on_success, CONNECT_ONE_SHOT)
	IapManager.purchase_failed.connect(on_failure, CONNECT_ONE_SHOT)
	IapManager.purchase(product_id)


func _on_buy(amount: int, from_pos: Vector2) -> void:
	# Legacy entry point — kept as a thin wrapper for non-shop callers
	# (e.g. gift claim). Normal shop flow goes through _initiate_purchase.
	var old_credits: int = SaveManager.credits
	SaveManager.add_credits(amount)
	SaveManager.save_game()
	_spawn_confetti_burst(from_pos)
	_spawn_chip_cascade(from_pos, old_credits, SaveManager.credits)


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
		_overlay.add_child(piece)

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


func _spawn_chip_cascade(from_pos: Vector2, old_credits: int, new_credits: int) -> void:
	var pill_inner: Control = _cash_cd.get("box", null) as Control
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
	var chip_size: Vector2 = Vector2(52, 52)
	var chip_color: Color = Color("FFEC00")

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
		_overlay.add_child(chip)

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

		_spawn_chip_trail(chip_tex, chip_size, chip_color, from_pos + jitter, target_pos, stagger, travel_time)

	var total_duration: float = travel_time + stagger_step * float(chip_count - 1)
	_animate_balance_increment(old_credits, new_credits, total_duration)
	_flash_balance_pill(total_duration)


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
		_overlay.add_child(ghost)
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


func _animate_balance_increment(from: int, to: int, duration: float) -> void:
	if _cash_cd.is_empty():
		return
	SoundManager.play_sfx_loop("balance_increment")
	var tw := create_tween()
	tw.tween_method(func(val: int) -> void:
		if not _cash_cd.is_empty():
			SaveManager.set_currency_value(_cash_cd, SaveManager.format_money(val))
	, from, to, duration).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: SoundManager.stop_sfx_loop_if("balance_increment"))


func _flash_balance_pill(duration: float) -> void:
	if not is_instance_valid(_cash_pill):
		return
	var flashes: int = 3
	var half: float = duration / float(flashes * 2)
	var tw := _cash_pill.create_tween()
	for i in flashes:
		tw.tween_property(_cash_pill, "modulate", Color(1.55, 1.55, 0.85), half)
		tw.tween_property(_cash_pill, "modulate", Color.WHITE, half)


# --- Generic UI helpers (duplicated from lobby_manager so shop is self-contained) ---

func _set_chip_amount_text(label: Label, amount: int, max_w: float) -> void:
	label.text = SaveManager.format_money(amount)
	var min_size: Vector2 = label.get_minimum_size()
	if min_size.x > max_w:
		label.text = SaveManager.format_short(amount)


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


func _attach_shimmer_sweep(ctrl: Control, period: float = 3.0, color: Color = Color(1, 1, 1, 0.4), pause: float = -1.0) -> void:
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


# --- Theme helpers ----------------------------------------------------------

func _is_supercell() -> bool:
	return ThemeManager.current_id == "supercell"


## Sticker-style StyleBoxFlat (supercell drop-shadow look).
## In classic skins falls back to a plain rounded panel without the shadow.
func _make_skin_sticker(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.border_color = border
	st.set_border_width_all(int(ThemeManager.size("border_width", 3)))
	st.set_corner_radius_all(radius)
	st.anti_aliasing = true
	if _is_supercell():
		st.shadow_color = Color(0, 0, 0, 0.5)
		st.shadow_offset = Vector2(0, int(ThemeManager.size("button_shadow_offset", 6)))
	return st


## Apply the active theme's font (e.g. LilitaOne for supercell) to every
## Label/Button in the subtree. Single pass so individual builders stay free
## of font wiring.
func _apply_theme_font_recursive(node: Node) -> void:
	var f: Font = ThemeManager.font()
	if f == null:
		return
	if node is Label:
		(node as Label).add_theme_font_override("font", f)
	elif node is Button:
		(node as Button).add_theme_font_override("font", f)
	for child in node.get_children():
		_apply_theme_font_recursive(child)
