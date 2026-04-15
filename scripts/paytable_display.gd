extends PanelContainer

signal bet_column_clicked(bet: int)
signal sweep_finished

var _labels: Array[Label] = []
var _cell_panels: Array[PanelContainer] = []
var _columns := 6
var _row_count := 0
var _current_bet := 1
var _winning_row := -1
var _animate_tween: Tween = null

const COL_YELLOW := Color("FFEC00")
const COL_CELL_DARK := Color("08004D")
const COL_CELL_ALT := Color("140D56")
const COL_BET_ACTIVE := Color("B53737")
const COL_BET_ACTIVE_ALT := Color("B94141")
const COL_BORDER := Color("FFEC00")
const COL_WIN_ROW := Color("4242D3")
const COL_WIN_ROW_BET := Color("E89090")


func setup(paytable: Paytable) -> void:
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = COL_CELL_DARK
	outer_style.set_border_width_all(2)
	outer_style.border_color = COL_BORDER
	outer_style.set_corner_radius_all(2)
	outer_style.content_margin_left = 0
	outer_style.content_margin_right = 0
	outer_style.content_margin_top = 0
	outer_style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", outer_style)

	var margin := $MarginContainer as MarginContainer
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)

	var grid: GridContainer = %PaytableGrid
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	for child in grid.get_children():
		grid.remove_child(child)
		child.free()
	_labels.clear()
	_cell_panels.clear()

	var hand_keys := paytable.get_hand_order()
	_row_count = hand_keys.size()
	var font_sz: int = _get_font_size()

	for row_idx in hand_keys.size():
		var hand_key: String = hand_keys[row_idx]
		var is_even_row := (row_idx % 2 == 0)
		var row_bg_dark: Color = COL_CELL_DARK if is_even_row else COL_CELL_ALT

		var name_cell := _create_cell(row_bg_dark)
		var name_label := Label.new()
		name_label.text = paytable.get_hand_display_name(hand_key)
		name_label.add_theme_font_size_override("font_size", font_sz)
		name_label.add_theme_color_override("font_color", COL_YELLOW)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_cell.add_child(name_label)
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_cell.custom_minimum_size.x = 260
		grid.add_child(name_cell)
		_labels.append(name_label)
		_cell_panels.append(name_cell)

		var row := paytable.get_payout_row(hand_key)
		var bold_font := SystemFont.new()
		bold_font.font_weight = 700
		for col in 5:
			var cell := _create_cell(row_bg_dark)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var bet_col := col + 1
			cell.gui_input.connect(_on_cell_clicked.bind(bet_col))
			var payout_label := Label.new()
			payout_label.text = str(int(row[col])) if col < row.size() else "0"
			payout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			payout_label.add_theme_font_size_override("font_size", font_sz + 2)
			payout_label.add_theme_font_override("font", bold_font)
			payout_label.add_theme_color_override("font_color", COL_YELLOW)
			payout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			payout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(payout_label)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.custom_minimum_size.x = 48
			grid.add_child(cell)
			_labels.append(payout_label)
			_cell_panels.append(cell)

	highlight_bet_column(_current_bet)


func _on_cell_clicked(event: InputEvent, bet: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		bet_column_clicked.emit(bet)


func _create_cell(bg_color: Color) -> PanelContainer:
	var cell := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.content_margin_left = 8
	style.content_margin_right = 8
	var pad := _get_cell_padding()
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	cell.add_theme_stylebox_override("panel", style)
	return cell


func _get_cell_style(cell: PanelContainer) -> StyleBoxFlat:
	return cell.get_theme_stylebox("panel") as StyleBoxFlat


func _get_base_color(row: int, col: int) -> Color:
	var is_even := (row % 2 == 0)
	if col == _current_bet and col > 0:
		return COL_BET_ACTIVE if is_even else COL_BET_ACTIVE_ALT
	return COL_CELL_DARK if is_even else COL_CELL_ALT


func highlight_bet_column(bet: int) -> void:
	_current_bet = bet
	_winning_row = -1
	# Don't interrupt a running sweep animation
	if _animate_tween and _animate_tween.is_running():
		return
	_reset_all_cells()


## Animate columns sequentially from current bet up to max (5).
## Emits sweep_finished when done.
func sweep_to_max(from_bet: int) -> void:
	_winning_row = -1
	_kill_sweep()
	# Reset all cells with no column highlighted
	var saved := _current_bet
	_current_bet = 0  # no column active
	_reset_all_cells()
	_current_bet = 5
	if from_bet >= 5:
		_reset_all_cells()
		sweep_finished.emit()
		return
	_animate_tween = create_tween()
	var flash_color := Color(0.85, 0.25, 0.25)
	for col in range(from_bet + 1, 6):
		var sweep_col := col
		_animate_tween.tween_callback(_sweep_column_on.bind(sweep_col, flash_color))
		_animate_tween.tween_interval(0.2)
		if sweep_col < 5:
			_animate_tween.tween_callback(_sweep_column_off.bind(sweep_col))
	# Settle column 5 to final red
	_animate_tween.tween_callback(func() -> void:
		for row in _row_count:
			var idx: int = row * _columns + 5
			var s := _get_cell_style(_cell_panels[idx])
			if s:
				s.bg_color = COL_BET_ACTIVE if (row % 2 == 0) else COL_BET_ACTIVE_ALT
		sweep_finished.emit()
	)


func _kill_sweep() -> void:
	if _animate_tween:
		_animate_tween.kill()
		_animate_tween = null


func _reset_all_cells() -> void:
	var jackpot_idx: int = 5  # row 0, col 5 (max bet column)
	var bold_font := SystemFont.new()
	bold_font.font_weight = 700
	for i in _cell_panels.size():
		var row: int = i / _columns
		var col: int = i % _columns
		var style := _get_cell_style(_cell_panels[i])
		if style:
			style.bg_color = _get_base_color(row, col)
		# Jackpot cell: top row, max bet — light red bold, slightly larger (fixed size, not cumulative)
		if i == jackpot_idx:
			_labels[i].add_theme_color_override("font_color", Color("FF6666"))
			_labels[i].add_theme_font_override("font", bold_font)
			_labels[i].add_theme_font_size_override("font_size", _get_font_size() + 4)
		else:
			_labels[i].add_theme_color_override("font_color", COL_YELLOW)
			_labels[i].remove_theme_font_override("font")
		_labels[i].modulate.a = 1.0



func _sweep_column_on(col: int, color: Color) -> void:
	for row in _row_count:
		var idx: int = row * _columns + col
		var s := _get_cell_style(_cell_panels[idx])
		if s:
			s.bg_color = color


func _sweep_column_off(col: int) -> void:
	for row in _row_count:
		var idx: int = row * _columns + col
		var s := _get_cell_style(_cell_panels[idx])
		if s:
			s.bg_color = COL_CELL_DARK if (row % 2 == 0) else COL_CELL_ALT


var _row_tween: Tween = null


func clear_winning_row() -> void:
	if _row_tween:
		_row_tween.kill()
		_row_tween = null
	if _winning_row >= 0:
		var old_start: int = _winning_row * _columns
		for col in _columns:
			var idx: int = old_start + col
			var row: int = _winning_row
			var style := _get_cell_style(_cell_panels[idx])
			if style:
				style.bg_color = _get_base_color(row, col)
			_labels[idx].add_theme_color_override("font_color", COL_YELLOW)
			_labels[idx].remove_theme_font_override("font")
			_labels[idx].modulate.a = 1.0
		_winning_row = -1


func highlight_winning_row(row_index: int) -> void:
	var start_from := _winning_row if _winning_row >= 0 else _row_count - 1
	clear_winning_row()
	_winning_row = row_index
	if row_index < 0 or row_index >= _row_count:
		return
	# Sweep from previous winning row (or bottom) toward the new one
	var step := -1 if row_index <= start_from else 1
	_row_tween = create_tween()
	for row in range(start_from, row_index + step, step):
		var sweep_row := row
		_row_tween.tween_callback(_light_row.bind(sweep_row))
		_row_tween.tween_interval(0.03)
		if sweep_row != row_index:
			_row_tween.tween_callback(_unlight_row.bind(sweep_row))
	# Bold the hand name on final row
	_row_tween.tween_callback(func() -> void:
		var start: int = row_index * _columns
		var name_label := _labels[start]
		var bold_font := SystemFont.new()
		bold_font.font_weight = 700
		name_label.add_theme_font_override("font", bold_font)
	)


func _light_row(row: int) -> void:
	var start: int = row * _columns
	for col in _columns:
		var idx: int = start + col
		var style := _get_cell_style(_cell_panels[idx])
		if style:
			if col == _current_bet and col > 0:
				style.bg_color = COL_WIN_ROW_BET
			else:
				style.bg_color = COL_WIN_ROW
		_labels[idx].add_theme_color_override("font_color", Color.WHITE)


func _unlight_row(row: int) -> void:
	var start: int = row * _columns
	for col in _columns:
		var idx: int = start + col
		var style := _get_cell_style(_cell_panels[idx])
		if style:
			style.bg_color = _get_base_color(row, col)
		_labels[idx].add_theme_color_override("font_color", COL_YELLOW)


func flash_winning_row() -> void:
	if _winning_row < 0:
		return
	var start: int = _winning_row * _columns
	var tween := create_tween().set_loops(6)
	for col in _columns:
		var label := _labels[start + col]
		tween.parallel().tween_property(label, "modulate:a", 0.3, 0.25)
	tween.chain()
	for col in _columns:
		var label := _labels[start + col]
		tween.parallel().tween_property(label, "modulate:a", 1.0, 0.25)


func _get_font_size() -> int:
	# Base: 15 for 9 rows, shrink for more rows
	if _row_count <= 9:
		return 15
	elif _row_count <= 11:
		return 13
	else:
		return 11


func _get_cell_padding() -> int:
	if _row_count <= 9:
		return 1
	elif _row_count <= 11:
		return 0
	else:
		return 0
