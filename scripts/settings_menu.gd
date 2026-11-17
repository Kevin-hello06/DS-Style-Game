extends Control
class_name SettingsMenu
## Pause button in the top-right corner, plus a small pause menu with
## Music and Sound effects on/off switches.
## Keyboard: Esc or P opens/closes it.

const BUTTON_SIZE := Vector2(24, 20)

var _overlay: Control
var _pause_button: Button
var _music: CheckButton
var _sfx: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must still work while the game is paused
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	var t := Theme.new()
	t.default_font_size = 12
	theme = t

	# Pause button, top-right. No keyboard focus, so Space (attack) never presses it.
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.focus_mode = FOCUS_NONE
	_pause_button.set_anchors_preset(PRESET_TOP_RIGHT)
	_pause_button.offset_left = -BUTTON_SIZE.x - 4
	_pause_button.offset_right = -4
	_pause_button.offset_top = 4
	_pause_button.offset_bottom = 4 + BUTTON_SIZE.y
	_pause_button.pressed.connect(open)
	add_child(_pause_button)

	# Dim background + centred panel.
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_music = CheckButton.new()
	_music.text = "Music"
	_music.button_pressed = GameAudio.music_on
	_music.toggled.connect(GameAudio.set_music)
	box.add_child(_music)

	_sfx = CheckButton.new()
	_sfx.text = "Sound effects"
	_sfx.button_pressed = GameAudio.sfx_on
	_sfx.toggled.connect(GameAudio.set_sfx)
	box.add_child(_sfx)

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(close)
	box.add_child(resume)


func _unhandled_input(event: InputEvent) -> void:
	var toggle_key: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).physical_keycode == KEY_P
	if event.is_action_pressed("ui_cancel") or toggle_key:
		if _overlay.visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_music.set_pressed_no_signal(GameAudio.music_on)
	_sfx.set_pressed_no_signal(GameAudio.sfx_on)
	_overlay.visible = true
	_pause_button.visible = false
	get_tree().paused = true
	_music.grab_focus()


func close() -> void:
	_overlay.visible = false
	_pause_button.visible = true
	get_tree().paused = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


## Screen rectangle of the pause button, so touch controls can ignore taps on it.
func pause_button_rect() -> Rect2:
	return _pause_button.get_global_rect().grow(6)
