extends PanelContainer

var _labels: Array[Label] = []
var _columns := 6
var _row_count := 0
var _current_bet := 1
var _winning_row := -1


func setup(paytable: Paytable) -> void:
	# Apply margins and grid spacing
	var margin := $MarginContainer as MarginContainer
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)

	var grid: GridContainer = %PaytableGrid
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for child in grid.get_children():
		child.queue_free()
	_labels.clear()

	var hand_keys := paytable.get_hand_order()
	_row_count = hand_keys.size()

	for hand_key in hand_keys:
		var name_label := Label.new()
		name_label.text = paytable.get_hand_display_name(hand_key)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		grid.add_child(name_label)
		_labels.append(name_label)

		var row := paytable.get_payout_row(hand_key)
		for i in 5:
			var payout_label := Label.new()
			payout_label.text = str(int(row[i])) if i < row.size() else "0"
			payout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			payout_label.add_theme_font_size_override("font_size", 16)
			payout_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.35))
			grid.add_child(payout_label)
			_labels.append(payout_label)

	highlight_bet_column(_current_bet)


func highlight_bet_column(bet: int) -> void:
	_current_bet = bet
	_winning_row = -1
	for i in _labels.size():
		var col := i % _columns
		var label := _labels[i]
		if col == 0:
			label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		elif col == bet:
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.35))


func highlight_winning_row(row_index: int) -> void:
	_winning_row = row_index
	if row_index < 0 or row_index >= _row_count:
		return
	var start := row_index * _columns
	for col in _columns:
		var label := _labels[start + col]
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))


func flash_winning_row() -> void:
	if _winning_row < 0:
		return
	var start := _winning_row * _columns
	var tween := create_tween().set_loops(6)
	for col in _columns:
		var label := _labels[start + col]
		tween.parallel().tween_property(label, "modulate:a", 0.3, 0.25)
	tween.chain()
	for col in _columns:
		var label := _labels[start + col]
		tween.parallel().tween_property(label, "modulate:a", 1.0, 0.25)
