extends HBoxContainer

@onready var _credits_label: Label = %CreditsValue
@onready var _bet_label: Label = %BetValue
@onready var _win_label: Label = %WinValue

var _displayed_credits: int = 0


func update_credits(amount: int, animate: bool = true) -> void:
	if animate and _displayed_credits != amount:
		_animate_counter(_credits_label, _displayed_credits, amount)
	else:
		_displayed_credits = amount
		_credits_label.text = str(amount)


func update_bet(amount: int) -> void:
	_bet_label.text = str(amount)


func update_win(amount: int) -> void:
	if amount > 0:
		_animate_counter(_win_label, 0, amount)
	else:
		_win_label.text = "0"


func clear_win() -> void:
	_win_label.text = "0"


func _animate_counter(label: Label, from: int, to: int) -> void:
	var tween := create_tween()
	var duration := clampf(absf(to - from) * 0.02, 0.3, 2.0)
	tween.tween_method(func(val: float) -> void:
		var current := int(val)
		label.text = str(current)
		if label == _credits_label:
			_displayed_credits = current
	, float(from), float(to), duration)
