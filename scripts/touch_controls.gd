extends Control
class_name TouchControls
## Floating virtual joystick on the left half of the screen and an attack
## button on the right half. Feeds the same input actions as the keyboard,
## so the player code doesn't care where input comes from.
## Positions are recalculated every frame, so it adapts when the Fold
## opens/closes or rotates.

const STICK_RADIUS := 28.0
const DEADZONE := 0.2

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _attack_index := -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	var view := get_viewport_rect().size

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < view.x * 0.5 and _stick_index == -1:
				_stick_index = touch.index
				_stick_origin = touch.position
				_stick_pos = touch.position
				_update_stick()
			elif touch.position.x >= view.x * 0.5 and _attack_index == -1:
				_attack_index = touch.index
				Input.action_press("attack")
		else:
			if touch.index == _stick_index:
				_stick_index = -1
				_set_axis("move_left", "move_right", 0.0)
				_set_axis("move_up", "move_down", 0.0)
			elif touch.index == _attack_index:
				_attack_index = -1
				Input.action_release("attack")
		queue_redraw()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_index:
			_stick_pos = drag.position
			_update_stick()
			queue_redraw()


func _stick_vector() -> Vector2:
	var v := (_stick_pos - _stick_origin) / STICK_RADIUS
	return v.normalized() if v.length() > 1.0 else v


func _update_stick() -> void:
	var v := _stick_vector()
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_up", "move_down", v.y)


func _set_axis(negative: StringName, positive: StringName, value: float) -> void:
	if value < -DEADZONE:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > DEADZONE:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _draw() -> void:
	var view := get_viewport_rect().size

	# Joystick: drawn where the thumb landed, or a faint hint when idle.
	if _stick_index != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.18))
		draw_circle(_stick_origin + _stick_vector() * STICK_RADIUS, 11.0, Color(1, 1, 1, 0.5))
	else:
		var hint := Vector2(44, view.y - 44)
		draw_arc(hint, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.2), 1.5)

	# Attack button hint in the bottom-right corner.
	var button := Vector2(view.x - 40, view.y - 40)
	var alpha := 0.55 if _attack_index != -1 else 0.25
	draw_circle(button, 18.0, Color(1, 1, 1, alpha))
	var font := ThemeDB.fallback_font
	draw_string(font, button + Vector2(-5, 5), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.6))
