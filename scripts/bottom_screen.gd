extends Control
class_name BottomScreen
## The controls, and the pause menu. Works in both console styles:
##
##   DUAL     This covers the lower half of the clamshell. The bottom screen in
##            its middle shows hearts, the area name, a II pause button, the
##            map and how many enemies are left; the D-pad and A/B/X/Y diamond
##            sit on the body either side of it.
##   CLASSIC  This covers the whole console body. Only the D-pad, the diamond
##            and a MENU button are drawn, on the body itself; hearts and the
##            mini-map are on the game screen instead (see hud.gd).
##
## A = sword; B, X and Y are spare for items later.
## Touch: hold on the D-pad (8 directions) and tap the buttons; several
## fingers at once are fine. Laptop: the mouse works as a finger, the keyboard
## still works, and Esc or P pauses.
## The pause menu opens over the game screen in CLASSIC, and over the bottom
## screen in DUAL.

const SIZE := Vector2(256, 192)
const BAR_HEIGHT := 22.0

const DPAD_ARM := 26.0      # centre to tip of each arm
const DPAD_WIDTH := 18.0    # thickness of the cross
const DPAD_DEADZONE := 5.0  # a finger right on the centre doesn't move you
const DPAD_REACH := 58.0    # CLASSIC: how far from the D-pad a touch still counts

const DIAMOND_OFFSET := 21.0
const BUTTON_RADIUS := 12.0
const TOUCH_SLACK := 6.0  # buttons accept taps a little outside their circle
## Letter -> [offset direction, input action]. A right, B bottom, X top, Y left.
const BUTTONS := {
	"A": [Vector2.RIGHT, "attack"],
	"B": [Vector2.DOWN, "action_b"],
	"X": [Vector2.UP, "action_x"],
	"Y": [Vector2.LEFT, "action_y"],
}

# The map on the DUAL bottom screen (there's room for a big one now).
const MAP_CELL := Vector2(56, 32)
const MAP_GAP := Vector2(18, 14)
const MAP_TOP := 40.0

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
var classic := false
var dpad_center := Vector2(40, 120)
var diamond_center := Vector2(376, 120)
## The screen inside this panel: the bottom screen (DUAL) or the game screen
## (CLASSIC). Touches there don't work the controls.
var screen_rect := Rect2(Vector2.ZERO, SIZE)

var _dpad_index := -1
var _dpad_dir := Vector2i.ZERO
var _button_fingers := {}  # touch index -> action held by that finger
var _blink := 0.0

var _overlay: ColorRect
var _pause_button: Button
var _music: CheckButton
var _sfx: CheckButton
var _console_button: Button
var _shell_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu must work while paused
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE

	var t := Theme.new()
	t.default_font_size = 11
	theme = t

	# Pause button. No keyboard focus, so Space (attack) never presses it.
	_pause_button = Button.new()
	_pause_button.focus_mode = FOCUS_NONE
	_pause_button.pressed.connect(open_menu)
	add_child(_pause_button)

	_build_menu()


## DUAL: this covers the lower half of the clamshell (panel_size, in game
## pixels), with the bottom screen at screen_pos.
func setup_dual(panel_size: Vector2, screen_pos: Vector2, dpad: Vector2, diamond: Vector2) -> void:
	classic = false
	size = panel_size
	dpad_center = dpad
	diamond_center = diamond
	screen_rect = Rect2(screen_pos, SIZE)
	_overlay.position = screen_pos  # the pause menu covers the bottom screen
	_pause_button.text = "II"
	_pause_button.position = screen_pos + Vector2(SIZE.x - 28, 2)
	_pause_button.size = Vector2(26, 18)
	for s in ["normal", "hover", "pressed"]:
		_pause_button.remove_theme_stylebox_override(s)
	_pause_button.remove_theme_font_size_override("font_size")
	queue_redraw()


## CLASSIC: this covers the whole console body (body_size, in game pixels).
func setup_classic(body_size: Vector2, game_screen_pos: Vector2, dpad: Vector2,
		diamond: Vector2, menu_center: Vector2) -> void:
	classic = true
	size = body_size
	dpad_center = dpad
	diamond_center = diamond
	screen_rect = Rect2(game_screen_pos, SIZE)
	_overlay.position = game_screen_pos  # the pause menu covers the game screen
	_pause_button.text = "MENU"
	_pause_button.size = Vector2(44, 13)
	_pause_button.position = menu_center - _pause_button.size * 0.5
	_pause_button.add_theme_font_size_override("font_size", 8)
	_pause_button.add_theme_stylebox_override("normal", _pill(COLOR_DPAD))
	_pause_button.add_theme_stylebox_override("hover", _pill(COLOR_DPAD.lightened(0.1)))
	_pause_button.add_theme_stylebox_override("pressed", _pill(COLOR_DPAD.darkened(0.3)))
	queue_redraw()


func _pill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(7)
	return sb


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
	box.add_theme_constant_override("separation", 3)
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

	_console_button = Button.new()
	_console_button.pressed.connect(_on_console_pressed)
	box.add_child(_console_button)

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
	_update_menu_text()
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
	_update_menu_text()


func _on_console_pressed() -> void:
	var shell := get_parent() as DSShell
	if shell:
		shell.next_console_mode()
	_update_menu_text()


func _update_menu_text() -> void:
	_console_button.text = "Console: " + DSShell.console_label()
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


## Whether a new touch at p (local) may start using the controls.
func _touch_allowed(p: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(p):
		return false  # off this panel (e.g. on the DUAL top screen)
	if Rect2(_pause_button.position, _pause_button.size).grow(4).has_point(p):
		return false
	return not screen_rect.has_point(p)


func _in_dpad_zone(p: Vector2) -> bool:
	return p.x < size.x * 0.5 and p.distance_to(dpad_center) <= DPAD_REACH


func _input(event: InputEvent) -> void:
	if _overlay.visible:
		return  # the menu's own buttons handle taps while paused

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var p := _to_local(touch.position)
		if touch.pressed:
			if not _touch_allowed(p):
				return
			var action := _button_at(p)
			if action != "":
				_button_fingers[touch.index] = action
				Input.action_press(action)
			elif _dpad_index == -1 and _in_dpad_zone(p):
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


func button_position(letter: String) -> Vector2:
	return diamond_center + (BUTTONS[letter][0] as Vector2) * DIAMOND_OFFSET


## The action of the A/B/X/Y button under this point, or "" if none.
func _button_at(p: Vector2) -> String:
	for letter: String in BUTTONS:
		if p.distance_to(button_position(letter)) <= BUTTON_RADIUS + TOUCH_SLACK:
			return BUTTONS[letter][1]
	return ""


func _update_dpad(p: Vector2) -> void:
	var d := p - dpad_center
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
	if not classic:
		_draw_bottom_screen(font)
		_draw_label(font, "A: Sword", diamond_center + Vector2(0, DIAMOND_OFFSET + BUTTON_RADIUS + 14))
	elif size.y > size.x:
		# Upright: between the D-pad and the buttons.
		_draw_label(font, "A: Sword", Vector2(size.x * 0.5, dpad_center.y + 4))
	else:
		# Sideways: the middle is the game screen, so put it under the buttons.
		_draw_label(font, "A: Sword", diamond_center + Vector2(0, DIAMOND_OFFSET + BUTTON_RADIUS + 14))
	_draw_controls(font)


## DUAL: the bottom screen's contents, drawn at screen_rect.
func _draw_bottom_screen(font: Font) -> void:
	draw_set_transform(screen_rect.position)
	draw_rect(Rect2(Vector2.ZERO, SIZE), COLOR_BG)
	draw_rect(Rect2(0, 0, SIZE.x, BAR_HEIGHT), COLOR_BAR)
	if world and is_instance_valid(world.player):
		draw_hearts(self, world.player, Vector2(12, 11), 11.0, 14.0)
	var title := World.area.capitalize()
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(floorf((SIZE.x - tw) * 0.5), 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT)
	draw_minimap(self, font, SIZE.x * 0.5, MAP_TOP, MAP_CELL, MAP_GAP, 11, _blink)

	# What's left to do in this area.
	var status := "Area cleared - doors open"
	if world and world.doors_locked:
		status = "Enemies left: %d" % world.enemies_left
	var sw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(floorf((SIZE.x - sw) * 0.5), SIZE.y - 12), status,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT if world and world.doors_locked else COLOR_MAP_CLEARED)
	draw_set_transform(Vector2.ZERO)


static func draw_hearts(ci: CanvasItem, player: Player, first: Vector2, heart_size: float, spacing: float) -> void:
	for i in ceili(player.max_health / 2.0):
		HeartShape.draw(ci, first + Vector2(i * spacing, 0), clampi(player.health - i * 2, 0, 2), heart_size)


## Draws the area map centred on center_x. With font_size 0 the boxes have no names.
static func draw_minimap(ci: CanvasItem, font: Font, center_x: float, top_y: float, cell: Vector2,
		gap: Vector2, font_size: int, blink: float) -> void:
	var cols := 0
	for c: Vector2i in World.MAP_POS.values():
		cols = maxi(cols, c.x + 1)
	var width := cols * cell.x + (cols - 1) * gap.x
	var origin := Vector2(floorf(center_x - width * 0.5), top_y)
	var rect_of := func(c: Vector2i) -> Rect2: return Rect2(origin + Vector2(c) * (cell + gap), cell)

	# Connections between areas, drawn first so the boxes sit on top.
	for from_area: String in World.DOORS:
		for to_area: String in World.DOORS[from_area].values():
			if World.visited.has(from_area) or World.visited.has(to_area):
				ci.draw_line(rect_of.call(World.MAP_POS[from_area]).get_center(),
					rect_of.call(World.MAP_POS[to_area]).get_center(), COLOR_MAP_LINE, 2.0)

	for name: String in World.MAP_POS:
		var r: Rect2 = rect_of.call(World.MAP_POS[name])
		if name == World.area:
			var pulse := 0.75 + 0.25 * sin(blink * 5.0)
			ci.draw_rect(r, COLOR_MAP_CURRENT * Color(pulse, pulse, pulse))
		elif World.cleared.has(name):
			ci.draw_rect(r, COLOR_MAP_CLEARED)
		elif World.visited.has(name):
			ci.draw_rect(r, COLOR_MAP_VISITED)
		else:
			ci.draw_rect(r, COLOR_BG)
			ci.draw_rect(r, COLOR_DIM, false, 1.0)  # unexplored: outline only
		if font_size > 0:
			var label := name.capitalize() if World.visited.has(name) else "?"
			var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var text_color := Color.BLACK if World.visited.has(name) else COLOR_DIM
			ci.draw_string(font, Vector2(floorf(r.get_center().x - lw * 0.5), floorf(r.get_center().y + font_size * 0.35)), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_controls(font: Font) -> void:
	# D-pad: lights up the pressed direction (from touch, or the keyboard).
	var dir := Vector2(_dpad_dir) if _dpad_index != -1 \
		else Input.get_vector("move_left", "move_right", "move_up", "move_down").sign()
	var c := dpad_center
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
		var color := COLOR_A if letter == "A" else COLOR_BUTTON
		_draw_button(font, button_position(letter), BUTTON_RADIUS, color, letter,
			Input.is_action_pressed(BUTTONS[letter][1]))


func _draw_button(font: Font, c: Vector2, r: float, color: Color, letter: String, pressed: bool) -> void:
	draw_circle(c + Vector2(0, 2), r, color.darkened(0.5))  # shadow
	var offset := Vector2(0, 2) if pressed else Vector2.ZERO
	draw_circle(c + offset, r, color.darkened(0.2) if pressed else color)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, c + offset + Vector2(-w * 0.5, 4), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_label(font: Font, text: String, at: Vector2) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, Vector2(floorf(at.x - w * 0.5), at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_DIM)
