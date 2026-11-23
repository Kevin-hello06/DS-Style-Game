extends Control
class_name BottomScreen
## The DS-style bottom screen: hearts and area name along the top, a mini-map
## of the areas, a D-pad on the left, an A/B/X/Y diamond on the right
## (A = sword; B, X, Y are spare for items later), and the pause menu.
##
## Everything is laid out on a 256x192 grid; DSShell scales it up.
## Touch: hold anywhere on the left half to use the D-pad (8 directions),
## tap the A/B/X/Y buttons. Several fingers at once are fine.
## Laptop: the mouse works as a finger, keyboard still works, Esc or P pauses.

const SIZE := Vector2(256, 192)
const BAR_HEIGHT := 22.0

# D-pad and buttons sit out towards the edges, where thumbs naturally rest.
const DPAD_CENTER := Vector2(42, 136)
const DPAD_ARM := 26.0     # centre to tip of each arm
const DPAD_WIDTH := 18.0   # thickness of the cross
const DPAD_DEADZONE := 5.0 # a finger right on the centre doesn't move you

const DIAMOND_CENTER := Vector2(216, 136)
const DIAMOND_OFFSET := 21.0
const BUTTON_RADIUS := 12.0
const TOUCH_SLACK := 6.0  # buttons accept taps a little outside their circle
## Letter -> [offset direction, input action]. Same arrangement as a DS:
## A right, B bottom, X top, Y left.
const BUTTONS := {
	"A": [Vector2.RIGHT, "attack"],
	"B": [Vector2.DOWN, "action_b"],
	"X": [Vector2.UP, "action_x"],
	"Y": [Vector2.LEFT, "action_y"],
}

const MAP_CELL := Vector2(34, 20)
const MAP_GAP := Vector2(10, 8)
const MAP_TOP := 30.0

const COLOR_BG := Color("#2b2838")
const COLOR_BAR := Color("#1d1b27")
const COLOR_TEXT := Color("#e8e4f0")
const COLOR_DIM := Color("#6d6880")
const COLOR_DPAD := Color("#47435a")
const COLOR_DPAD_LIT := Color("#8a85a0")
const COLOR_BUTTON := Color("#5d5873")
const COLOR_A := Color("#d9534f")  # the sword gets a colour of its own
const COLOR_MAP_CURRENT := Color("#f2c14e")
const COLOR_MAP_CLEARED := Color("#5fae5a")
const COLOR_MAP_VISITED := Color("#77728a")
const COLOR_MAP_LINE := Color("#4a4659")

var world: World

var _dpad_index := -1
var _dpad_dir := Vector2i.ZERO
var _button_fingers := {}  # touch index -> action held by that finger
var _blink := 0.0

var _overlay: ColorRect
var _pause_button: Button
var _music: CheckButton
var _sfx: CheckButton
var _shell_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu must work while paused
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE

	var t := Theme.new()
	t.default_font_size = 11
	theme = t

	# Pause button, top-right. No keyboard focus, so Space (attack) never presses it.
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.focus_mode = FOCUS_NONE
	_pause_button.position = Vector2(SIZE.x - 28, 2)
	_pause_button.size = Vector2(26, 18)
	_pause_button.pressed.connect(open_menu)
	add_child(_pause_button)

	_build_menu()


func _build_menu() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.04, 0.08, 0.92)
	_overlay.size = SIZE
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.size = SIZE
	_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	center.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_music = CheckButton.new()
	_music.text = "Music"
	_music.toggled.connect(GameAudio.set_music)
	box.add_child(_music)

	_sfx = CheckButton.new()
	_sfx.text = "Sound effects"
	_sfx.toggled.connect(GameAudio.set_sfx)
	box.add_child(_sfx)

	_shell_button = Button.new()
	_shell_button.pressed.connect(_on_shell_pressed)
	box.add_child(_shell_button)

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(close_menu)
	box.add_child(resume)


# --- Pause menu --------------------------------------------------------------

func open_menu() -> void:
	_release_all()
	_music.set_pressed_no_signal(GameAudio.music_on)
	_sfx.set_pressed_no_signal(GameAudio.sfx_on)
	_update_shell_text()
	_overlay.visible = true
	_pause_button.visible = false
	get_tree().paused = true


func close_menu() -> void:
	_overlay.visible = false
	_pause_button.visible = true
	get_tree().paused = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


func _on_shell_pressed() -> void:
	var shell := get_parent() as DSShell
	if shell:
		shell.next_shell()
	_update_shell_text()


func _update_shell_text() -> void:
	_shell_button.text = "Shell colour: " + DSShell.shell_name()


func is_menu_open() -> bool:
	return _overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	var p_key: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).physical_keycode == KEY_P
	if event.is_action_pressed("ui_cancel") or p_key:
		if _overlay.visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


# --- Touch controls ----------------------------------------------------------

func _to_local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _input(event: InputEvent) -> void:
	if _overlay.visible:
		return  # the menu's own buttons handle taps while paused

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var p := _to_local(touch.position)
		if touch.pressed:
			if not Rect2(Vector2(0, BAR_HEIGHT), SIZE - Vector2(0, BAR_HEIGHT)).has_point(p):
				return  # on the top screen, or on the bar with the pause button
			var action := _button_at(p)
			if action != "":
				_button_fingers[touch.index] = action
				Input.action_press(action)
			elif _dpad_index == -1 and p.x < SIZE.x * 0.5:
				_dpad_index = touch.index
				_update_dpad(p)
		else:
			if touch.index == _dpad_index:
				_dpad_index = -1
				_set_dpad(Vector2i.ZERO)
			elif _button_fingers.has(touch.index):
				var action: String = _button_fingers[touch.index]
				_button_fingers.erase(touch.index)
				if not action in _button_fingers.values():
					Input.action_release(action)

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _dpad_index:
			_update_dpad(_to_local(drag.position))


## The action of the A/B/X/Y button under this point, or "" if none.
func _button_at(p: Vector2) -> String:
	for letter: String in BUTTONS:
		var c := DIAMOND_CENTER + (BUTTONS[letter][0] as Vector2) * DIAMOND_OFFSET
		if p.distance_to(c) <= BUTTON_RADIUS + TOUCH_SLACK:
			return BUTTONS[letter][1]
	return ""


func _update_dpad(p: Vector2) -> void:
	var d := p - DPAD_CENTER
	if d.length() < DPAD_DEADZONE:
		_set_dpad(Vector2i.ZERO)
		return
	# Snap to the nearest of 8 directions, so diagonals work too.
	var angle := snappedf(d.angle(), PI / 4.0)
	_set_dpad(Vector2i(roundi(cos(angle)), roundi(sin(angle))))


func _set_dpad(dir: Vector2i) -> void:
	_dpad_dir = dir
	_set_axis("move_left", "move_right", dir.x)
	_set_axis("move_up", "move_down", dir.y)


func _set_axis(negative: StringName, positive: StringName, value: int) -> void:
	if value < 0:
		Input.action_press(negative)
		Input.action_release(positive)
	elif value > 0:
		Input.action_press(positive)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release_all() -> void:
	_dpad_index = -1
	_dpad_dir = Vector2i.ZERO
	_button_fingers.clear()
	for action in ["move_left", "move_right", "move_up", "move_down",
			"attack", "action_b", "action_x", "action_y"]:
		Input.action_release(action)


# --- Drawing -----------------------------------------------------------------

func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, SIZE), COLOR_BG)
	draw_rect(Rect2(0, 0, SIZE.x, BAR_HEIGHT), COLOR_BAR)

	# Hearts.
	if world and is_instance_valid(world.player):
		var hp := world.player.health
		for i in ceili(world.player.max_health / 2.0):
			HeartShape.draw(self, Vector2(12 + i * 14, 11), clampi(hp - i * 2, 0, 2), 11.0)

	# Area name, centred in the bar.
	var title := World.area.capitalize()
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(floorf((SIZE.x - tw) * 0.5), 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT)

	_draw_minimap(font)
	_draw_controls(font)


func _map_cell_rect(cell: Vector2i, origin: Vector2) -> Rect2:
	return Rect2(origin + Vector2(cell) * (MAP_CELL + MAP_GAP), MAP_CELL)


func _draw_minimap(font: Font) -> void:
	# Centre the map horizontally based on how many columns it uses.
	var cols := 0
	for cell: Vector2i in World.MAP_POS.values():
		cols = maxi(cols, cell.x + 1)
	var width := cols * MAP_CELL.x + (cols - 1) * MAP_GAP.x
	var origin := Vector2(floorf((SIZE.x - width) * 0.5), MAP_TOP)

	# Connections between areas, drawn first so the boxes sit on top.
	for from_area: String in World.DOORS:
		for to_area: String in World.DOORS[from_area].values():
			if World.visited.has(from_area) or World.visited.has(to_area):
				draw_line(_map_cell_rect(World.MAP_POS[from_area], origin).get_center(),
					_map_cell_rect(World.MAP_POS[to_area], origin).get_center(), COLOR_MAP_LINE, 2.0)

	for name: String in World.MAP_POS:
		var r := _map_cell_rect(World.MAP_POS[name], origin)
		var is_current := name == World.area
		if is_current:
			var pulse := 0.75 + 0.25 * sin(_blink * 5.0)
			draw_rect(r, COLOR_MAP_CURRENT * Color(pulse, pulse, pulse))
		elif World.cleared.has(name):
			draw_rect(r, COLOR_MAP_CLEARED)
		elif World.visited.has(name):
			draw_rect(r, COLOR_MAP_VISITED)
		else:
			draw_rect(r, COLOR_BG)
			draw_rect(r, COLOR_DIM, false, 1.0)  # unexplored: outline only
		var label := name.capitalize() if World.visited.has(name) else "?"
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var text_color := Color.BLACK if World.visited.has(name) else COLOR_DIM
		draw_string(font, Vector2(floorf(r.get_center().x - lw * 0.5), r.position.y + 14), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, text_color)


func _draw_controls(font: Font) -> void:
	# D-pad: lights up the pressed direction (from touch, or the keyboard).
	var dir := Vector2(_dpad_dir) if _dpad_index != -1 \
		else Input.get_vector("move_left", "move_right", "move_up", "move_down").sign()
	var c := DPAD_CENTER
	var arm := DPAD_ARM
	var half := DPAD_WIDTH * 0.5
	draw_rect(Rect2(c.x - arm, c.y - half + 2, arm * 2, DPAD_WIDTH), COLOR_DPAD.darkened(0.5))  # shadow
	draw_rect(Rect2(c.x - half, c.y - arm + 2, DPAD_WIDTH, arm * 2), COLOR_DPAD.darkened(0.5))
	draw_rect(Rect2(c.x - arm, c.y - half, arm * 2, DPAD_WIDTH), COLOR_DPAD)
	draw_rect(Rect2(c.x - half, c.y - arm, DPAD_WIDTH, arm * 2), COLOR_DPAD)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var lit := (d.x != 0 and signf(dir.x) == d.x) or (d.y != 0 and signf(dir.y) == d.y)
		var tip := c + d * (arm - 4)
		var side := Vector2(-d.y, d.x) * 4.0
		if lit:
			# Light up this arm: from the edge of the centre square out to its tip.
			var across := Vector2(absf(d.y), absf(d.x)) * half
			draw_rect(Rect2(c + d * half - across, Vector2.ZERO).expand(c + d * arm + across), COLOR_DPAD_LIT)
		draw_colored_polygon(PackedVector2Array([tip, tip - d * 6 + side, tip - d * 6 - side]),
			COLOR_TEXT if lit else COLOR_DIM)
	draw_circle(c, 4, COLOR_DPAD.darkened(0.25))

	# A/B/X/Y diamond.
	for letter: String in BUTTONS:
		var pos := DIAMOND_CENTER + (BUTTONS[letter][0] as Vector2) * DIAMOND_OFFSET
		var color := COLOR_A if letter == "A" else COLOR_BUTTON
		_draw_button(font, pos, BUTTON_RADIUS, color, letter, Input.is_action_pressed(BUTTONS[letter][1]))

	_draw_label(font, "A: Sword", Vector2(SIZE.x * 0.5, SIZE.y - 10))


func _draw_button(font: Font, c: Vector2, r: float, color: Color, letter: String, pressed: bool) -> void:
	draw_circle(c + Vector2(0, 2), r, color.darkened(0.5))  # shadow
	var offset := Vector2(0, 2) if pressed else Vector2.ZERO
	draw_circle(c + offset, r, color.darkened(0.2) if pressed else color)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, c + offset + Vector2(-w * 0.5, 4), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_label(font: Font, text: String, at: Vector2) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, Vector2(floorf(at.x - w * 0.5), at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_DIM)
