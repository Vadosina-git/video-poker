extends Control

var LobbyScene: PackedScene
var GameScene: PackedScene

var _current_scene: Control = null
var _paytables: Dictionary = {}
var _loader_active: bool = false

const LOADER_DURATION := 2.0
# Supercell skin shows the loader/splash a bit longer so the trainer
# branding has time to read. Classic stays on the historical 2.0s.
const LOADER_DURATION_SUPERCELL := 3.0


func _ready() -> void:
	# Keep classic's deep-blue clear color as the default; supercell paints
	# its own background, so it won't notice this value either way.
	RenderingServer.set_default_clear_color(Color(0, 0, 0.527, 1))
	LobbyScene = load("res://scenes/lobby/lobby.tscn")
	GameScene = load("res://scenes/game.tscn")
	_paytables = Paytable.load_all()
	QuestBannerOverlay.banner_tapped.connect(_on_quest_banner_tapped)
	QuestPopupOverlay.go_requested.connect(_on_quest_go_requested)
	_show_lobby()


## Banner-tap routes straight to the quests popup overlay, which renders on
## its own CanvasLayer above whatever scene is active — lobby or a game.
## No scene transition; player stays at the table.
func _on_quest_banner_tapped() -> void:
	QuestPopupOverlay.show_popup()


## Quest popup "GO" handler — sole subscriber. Translates the (variant, mode)
## intent into the existing machine-load pipeline, applying the mode change
## to SaveManager directly so it works whether the player is currently in
## lobby or in a game scene.
func _on_quest_go_requested(variant_id: String, mode: String) -> void:
	if mode != "":
		SaveManager.mode_id = mode
		match mode:
			"single_play":
				SaveManager.hand_count = 1
				SaveManager.ultra_vp = false
				SaveManager.spin_poker = false
			"triple_play":
				SaveManager.hand_count = 3
				SaveManager.ultra_vp = false
				SaveManager.spin_poker = false
			"five_play":
				SaveManager.hand_count = 5
				SaveManager.ultra_vp = false
				SaveManager.spin_poker = false
			"ten_play":
				SaveManager.hand_count = 10
				SaveManager.ultra_vp = false
				SaveManager.spin_poker = false
			"ultra_vp":
				SaveManager.hand_count = 5
				SaveManager.ultra_vp = true
				SaveManager.spin_poker = false
			"spin_poker":
				SaveManager.hand_count = 1
				SaveManager.ultra_vp = false
				SaveManager.spin_poker = true
	SaveManager.last_variant = variant_id
	SaveManager.save_game()
	_on_machine_selected(variant_id)


func _show_lobby() -> void:
	SoundManager.stop_ambient()
	SoundManager.play_lobby_ambient()
	DailyQuestManager.detach_from_game()
	_clear_current()
	var lobby: Control = LobbyScene.instantiate()
	add_child(lobby)
	_make_full_rect(lobby)
	_current_scene = lobby
	lobby.machine_selected.connect(_on_machine_selected)
	_fade_in_scene(lobby)
	_maybe_show_tutorial()


func _maybe_show_tutorial() -> void:
	if not TutorialOverlay.should_show():
		return
	TutorialOverlay.present(self)


## Fade a freshly-shown scene in from transparent → opaque.
func _fade_in_scene(scene: Control) -> void:
	scene.modulate.a = 0.0
	var tw := scene.create_tween()
	tw.tween_property(scene, "modulate:a", 1.0, 0.33).set_ease(Tween.EASE_OUT)


func _on_machine_selected(variant_id: String) -> void:
	if _loader_active:
		return
	_loader_active = true
	var loader := _create_loader()
	add_child(loader)
	# Fade loader in
	loader.modulate.a = 0.0
	loader.create_tween().tween_property(loader, "modulate:a", 1.0, 0.27)
	var dur: float = LOADER_DURATION_SUPERCELL if ThemeManager.current_id == "supercell" else LOADER_DURATION
	await get_tree().create_timer(dur).timeout
	_loader_active = false
	# Load the target scene BEFORE fading out the loader so we don't flash
	_load_game_scene(variant_id)
	if is_instance_valid(loader):
		var fade := loader.create_tween()
		fade.tween_property(loader, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
		fade.tween_callback(loader.queue_free)


func _load_game_scene(variant_id: String) -> void:
	SoundManager.stop_ambient()
	_clear_current()
	var paytable: Paytable = _paytables[variant_id]
	var variant := _create_variant(variant_id, paytable)
	var hand_count: int = SaveManager.hand_count
	var ultra_vp: bool = SaveManager.ultra_vp

	if SaveManager.spin_poker:
		# Spin Poker mode — route by theme first.
		var spin_theme_path := "res://scenes/themes/%s/spin_poker_game.tscn" % ThemeManager.current_id
		var spin_path := spin_theme_path if ResourceLoader.exists(spin_theme_path) else "res://scenes/spin_poker_game.tscn"
		var spin_scene := load(spin_path)
		if spin_scene:
			var spin_game: Control = spin_scene.instantiate()
			spin_game.setup(variant)
			add_child(spin_game)
			_make_full_rect(spin_game)
			_current_scene = spin_game
			spin_game.back_to_lobby.connect(_show_lobby)
			DailyQuestManager.attach_to_game(spin_game, variant_id, SaveManager.mode_id)
			SoundManager.play_ambient()
			return

	if hand_count > 1 or ultra_vp:
		# Multi-hand / Ultra VP — route by theme first.
		var multi_theme_path := "res://scenes/themes/%s/multi_hand_game.tscn" % ThemeManager.current_id
		var multi_path := multi_theme_path if ResourceLoader.exists(multi_theme_path) else "res://scenes/multi_hand_game.tscn"
		var multi_scene := load(multi_path)
		if multi_scene:
			var multi_game: Control = multi_scene.instantiate()
			multi_game.setup(variant, hand_count, ultra_vp)
			add_child(multi_game)
			_make_full_rect(multi_game)
			_current_scene = multi_game
			multi_game.back_to_lobby.connect(_show_lobby)
			DailyQuestManager.attach_to_game(multi_game, variant_id, SaveManager.mode_id)
			_fade_in_scene(multi_game)
			SoundManager.play_ambient()
			return

	# Single hand mode — route to per-theme scene if the active skin
	# ships its own layout under scenes/themes/<id>/game.tscn, else
	# fall back to the classic scene at scenes/game.tscn. This keeps
	# new skins fully isolated from the existing classic UI.
	var single_scene: PackedScene = _get_single_hand_scene()
	var game: Control = single_scene.instantiate()
	game.setup(variant)
	add_child(game)
	_make_full_rect(game)
	_current_scene = game
	game.back_to_lobby.connect(_show_lobby)
	DailyQuestManager.attach_to_game(game, variant_id, SaveManager.mode_id)
	_fade_in_scene(game)
	SoundManager.play_ambient()


func _get_single_hand_scene() -> PackedScene:
	var theme_path := "res://scenes/themes/%s/game.tscn" % ThemeManager.current_id
	if ResourceLoader.exists(theme_path):
		return load(theme_path)
	return GameScene


func _create_variant(variant_id: String, pt: Paytable) -> BaseVariant:
	match variant_id:
		"jacks_or_better":
			return JacksOrBetter.new(pt)
		"bonus_poker":
			return BonusPoker.new(pt)
		"bonus_poker_deluxe":
			return BonusPokerDeluxe.new(pt)
		"double_bonus":
			return DoubleBonus.new(pt)
		"double_double_bonus":
			return DoubleDoubleBonus.new(pt)
		"triple_double_bonus":
			return TripleDoubleBonus.new(pt)
		"aces_and_faces":
			return AcesAndFaces.new(pt)
		"deuces_wild":
			return DeucesWild.new(pt)
		"joker_poker":
			return JokerPoker.new(pt)
		"deuces_and_joker":
			return DeucesAndJoker.new(pt)
		_:
			return JacksOrBetter.new(pt)


func _make_full_rect(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.set_offsets_preset(Control.PRESET_FULL_RECT)
	# Safe-area inset (notch / Dynamic Island / home indicator / Android
	# cutout) is applied to UI children only — NOT to the scene root and
	# NOT to a child that's clearly a background (named "Background", OR
	# a ColorRect/TextureRect already at FULL_RECT — script-built backdrops
	# follow this pattern). Backgrounds stay full-bleed so the clear color
	# never shows in cutout pockets; every UI container is pushed inward.
	for child in ctrl.get_children():
		if not (child is Control):
			continue
		if child.name == "Background":
			continue
		if (child is ColorRect or child is TextureRect) \
				and child.anchor_left == 0.0 and child.anchor_top == 0.0 \
				and child.anchor_right == 1.0 and child.anchor_bottom == 1.0:
			continue
		# Per-child opt-in: a Control can carry `safe_area_axes` meta
		# ("all" / "vertical" / "horizontal") to restrict which sides are
		# inset. Lobby's VBoxContainer uses "vertical" so the machine
		# carousel can sweep horizontally under the notch.
		var axes: String = String(child.get_meta("safe_area_axes", "all"))
		SafeAreaManager.apply_offsets(child, axes)


func _clear_current() -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null


# --- Table-loading overlay (dim + spinner) ---

func _create_loader() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	overlay.add_child(dim)

	var center_ct := CenterContainer.new()
	center_ct.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_ct)

	var spinner := _create_spinner()
	center_ct.add_child(spinner)

	return overlay


func _create_spinner() -> Control:
	var size_px: float = 96.0
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(size_px, size_px)
	spinner.size = Vector2(size_px, size_px)
	spinner.pivot_offset = Vector2(size_px * 0.5, size_px * 0.5)
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner.draw.connect(func() -> void:
		var center := spinner.size * 0.5
		var radius: float = spinner.size.x * 0.42
		# Ring of 8 dots, leading dot fully opaque, trailing dots fade out.
		# Visually a neutral loader — no chip / no suit imagery.
		for i in 8:
			var ang: float = TAU * float(i) / 8.0 - PI * 0.5
			var p := center + Vector2(cos(ang), sin(ang)) * radius
			var alpha: float = 0.25 + 0.75 * (float(i) / 7.0)
			spinner.draw_circle(p, 7.0, Color(1, 1, 1, alpha))
	)

	# Continuous rotation: one full turn per 2 seconds with wavelike pacing.
	var tw := spinner.create_tween()
	tw.set_loops()
	tw.tween_property(spinner, "rotation", TAU, 2.0) \
		.from(0.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	return spinner
