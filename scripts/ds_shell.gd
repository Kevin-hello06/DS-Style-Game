extends Control
class_name DSShell
## The handheld console the game is shown in. Two styles:
##
##   DUAL     A clamshell with two equal halves. The game is on the wide top
##            screen; hearts, the maps and an enemy count are on the bottom
##            screen, with the D-pad and buttons on the body either side of it.
##   CLASSIC  A single-screen handheld. The game screen sits at the top of the
##            body with the D-pad and buttons below it (or either side of it
##            when the phone is held sideways). Hearts and the mini-map are
##            shown on the game screen itself.
##
## "Auto" (the default) picks DUAL on Samsung Galaxy Z Fold phones, folded or
## open, and on squarish screens such as tablets or a laptop window, and
## CLASSIC on ordinary phone screens. The pause menu can force either style.
##
## Everything is scaled by a whole number so pixels stay crisp, and the layout
## is rebuilt whenever the display changes size (rotating, folding, unfolding).
## The shell colour can also be changed in the pause menu. Both settings are
## remembered.

enum Style { DUAL, CLASSIC }

const SCREEN := Vector2(256, 192)   # every screen is 256x192 game pixels

# Dual (clamshell) measurements, in game pixels.
const DUAL_COL := 80.0   # body either side of the bottom screen (holds the controls)
const DUAL_TOP_W := 384.0  # the DUAL top screen is wider: 24 tiles across, filling its half
const TOP_IN := 12.0     # body edge to screen, at the top of each half
const LABEL_IN := 18.0   # below the top screen (room for the name)
const BOTTOM_IN := 18.0  # below the bottom screen (same as LABEL_IN: equal halves)
const HINGE := 10.0      # gap between the two halves
const OUTER := 8.0       # space around the whole console
const BEZEL := 4.0       # black frame around each screen

# Classic (single-screen) measurements, in game pixels.
const CLASSIC_PORTRAIT := Vector2(292, 372)   # whole body, held upright
const CLASSIC_LANDSCAPE := Vector2(452, 228)  # whole body, held sideways
const CLASSIC_SIDE_COL := 98.0                # control column width, sideways

const SETTINGS_PATH := "user://settings.cfg"
const COLOR_DESK := Color("#101016")
const COLOR_BEZEL := Color("#0b0b10")
const CONSOLE_MODES := ["auto", "classic", "dual"]

## Shell colours: body, edge (shading + hinge), text, power light.
const PALETTES := [
	{"name": "Midnight", "body": Color("#2e3047"), "edge": Color("#1d1e30"), "text": Color("#9da3c7"), "led": Color("#6cf2a0")},
	{"name": "Ice", "body": Color("#d9e2ec"), "edge": Color("#a9b8c9"), "text": Color("#5b6b80"), "led": Color("#2fcf6f")},
	{"name": "Coral", "body": Color("#e8806e"), "edge": Color("#bf5a4a"), "text": Color("#fff1ec"), "led": Color("#fff27a")},
	{"name": "Mint", "body": Color("#93d6bd"), "edge": Color("#5fae93"), "text": Color("#2f5e4f"), "led": Color("#ff6b6b")},
]

static var shell_index := 0
static var console_mode := "auto"   # "auto", "classic" or "dual"
static var style := Style.DUAL      # the style currently in use
## For testing on a PC: pretend the screen has camera cutouts here (screen
## pixels). On a phone the real cutouts are read from Android instead.
static var test_cutouts: Array[Rect2] = []

var top: SubViewportContainer
var viewport: SubViewport
var world: World
var bottom: BottomScreen
var side_by_side := false
var screen_scale := 1.0
var game_scale := 1.0   # the game view's scale (same as the console's)

# Where things ended up (in real pixels), for drawing.
var _upper_rect := Rect2()   # dual: top half of the console (or left half)
var _lower_rect := Rect2()   # dual: bottom half (or right half)
var _body_rect := Rect2()    # classic: the whole body
var _classic_portrait := true


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_load_settings()

	top = SubViewportContainer.new()
	top.name = "TopScreen"
	top.stretch = false
	top.size = SCREEN
	top.mouse_filter = MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	top.add_child(viewport)
	world = World.new()
	world.name = "World"
	viewport.add_child(world)
	add_child(top)

	bottom = BottomScreen.new()
	bottom.name = "BottomScreen"
	bottom.world = world
	add_child(bottom)

	resized.connect(_layout)
	_layout()


# --- Settings ----------------------------------------------------------------

static func shell_name() -> String:
	return PALETTES[shell_index]["name"]


## For the pause menu, e.g. "Auto (Dual)".
static func console_label() -> String:
	var current := "Dual" if style == Style.DUAL else "Classic"
	if console_mode == "auto":
		return "Auto (%s)" % current
	return current


func next_shell() -> void:
	shell_index = (shell_index + 1) % PALETTES.size()
	_save_settings()
	queue_redraw()


func next_console_mode() -> void:
	console_mode = CONSOLE_MODES[(CONSOLE_MODES.find(console_mode) + 1) % CONSOLE_MODES.size()]
	_save_settings()
	_layout()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the audio settings that are already in there
	cfg.set_value("display", "shell", shell_index)
	cfg.set_value("display", "console", console_mode)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		shell_index = clampi(cfg.get_value("display", "shell", 0), 0, PALETTES.size() - 1)
		console_mode = cfg.get_value("display", "console", "auto")
		if not console_mode in CONSOLE_MODES:
			console_mode = "auto"


## True on Samsung Galaxy Z Fold phones (model numbers SM-F9xx).
## The Z Flip (SM-F7xx) is a normal-shaped phone when open, so it isn't counted.
static func is_fold_device() -> bool:
	return OS.get_name() == "Android" and OS.get_model_name().to_upper().begins_with("SM-F9")


func _pick_style(s: Vector2) -> Style:
	match console_mode:
		"classic":
			return Style.CLASSIC
		"dual":
			return Style.DUAL
	if is_fold_device():
		return Style.DUAL
	# Ordinary phones are long and thin (about 2:1 or more, either way round).
	var ratio := maxf(s.x, s.y) / minf(s.x, s.y)
	return Style.CLASSIC if ratio >= 1.7 else Style.DUAL


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	style = _pick_style(s)
	viewport.size = Vector2i(SCREEN)
	top.size = SCREEN
	if style == Style.CLASSIC:
		_layout_classic(s)
	else:
		_layout_dual(s)
	top.scale = Vector2(game_scale, game_scale)
	bottom.scale = Vector2(screen_scale, screen_scale)
	queue_redraw()


func _whole(k: float) -> float:
	return floorf(k) if k >= 1.0 else k  # whole-number scale = sharp pixels


func _layout_dual(s: Vector2) -> void:
	var half_w := SCREEN.x + DUAL_COL * 2.0
	var upper_h := TOP_IN + SCREEN.y + LABEL_IN
	var lower_h := TOP_IN + SCREEN.y + BOTTOM_IN
	var stacked := Vector2(half_w, upper_h + HINGE + lower_h)
	var side := Vector2(half_w * 2.0 + HINGE, upper_h)
	var pad := Vector2(OUTER, OUTER) * 2.0

	var stacked_k := minf(s.x / (stacked + pad).x, s.y / (stacked + pad).y)
	var side_k := minf(s.x / (side + pad).x, s.y / (side + pad).y)
	side_by_side = side_k > stacked_k
	var k := _whole(side_k if side_by_side else stacked_k)
	screen_scale = k

	var total := side if side_by_side else stacked
	var origin := ((s - total * k) * 0.5).floor()
	_upper_rect = Rect2(origin, Vector2(half_w, upper_h) * k)
	if side_by_side:
		_lower_rect = Rect2(origin + Vector2(half_w + HINGE, 0) * k, Vector2(half_w, lower_h) * k)
	else:
		_lower_rect = Rect2(origin + Vector2(0, upper_h + HINGE) * k, Vector2(half_w, lower_h) * k)

	# The top screen fills its half, apart from a slim edge of body.
	game_scale = k
	var top_size := Vector2(DUAL_TOP_W, SCREEN.y)
	viewport.size = Vector2i(top_size)
	top.size = top_size
	top.position = (_upper_rect.position + Vector2((half_w - DUAL_TOP_W) * 0.5, TOP_IN) * k).floor()
	bottom.position = _lower_rect.position
	# Controls on the body either side of the bottom screen, a little below its
	# middle. To move them, change the + 10 (bigger = lower). If the phone's
	# camera hole would cover one, it's moved up or down out of the way.
	var controls_y := TOP_IN + SCREEN.y * 0.5 + 10
	var y_range := Vector2(TOP_IN + 34, lower_h - 34)
	var dpad := _avoid_cutouts(Vector2(DUAL_COL * 0.5, controls_y), 34.0, y_range)
	var diamond := _avoid_cutouts(Vector2(half_w - DUAL_COL * 0.5, controls_y), 36.0, y_range)
	bottom.setup_dual(Vector2(half_w, lower_h), Vector2(DUAL_COL, TOP_IN), dpad, diamond)


func _layout_classic(s: Vector2) -> void:
	_classic_portrait = s.y >= s.x
	var body := CLASSIC_PORTRAIT if _classic_portrait else CLASSIC_LANDSCAPE
	var pad := Vector2(OUTER, OUTER) * 2.0
	var k := _whole(minf(s.x / (body + pad).x, s.y / (body + pad).y))
	screen_scale = k
	game_scale = k
	var origin := ((s - body * k) * 0.5).floor()
	_body_rect = Rect2(origin, body * k)

	# Positions inside the body, in game pixels.
	var screen_pos: Vector2
	var dpad: Vector2
	var diamond: Vector2
	var menu: Vector2
	if _classic_portrait:
		screen_pos = Vector2((body.x - SCREEN.x) * 0.5, 16)
		var controls_mid := screen_pos.y + SCREEN.y + LABEL_IN + 58
		dpad = Vector2(60, controls_mid)
		diamond = Vector2(body.x - 60, controls_mid)
		var y_range := Vector2(controls_mid - 30, body.y - 50)
		bottom.position = origin  # needed by _avoid_cutouts
		dpad = _avoid_cutouts(dpad, 34.0, y_range)
		diamond = _avoid_cutouts(diamond, 36.0, y_range)
		menu = Vector2(body.x * 0.5, body.y - 26)
	else:
		screen_pos = Vector2(CLASSIC_SIDE_COL, 14)
		var mid := screen_pos.y + SCREEN.y * 0.5
		dpad = Vector2(CLASSIC_SIDE_COL * 0.5, mid)
		diamond = Vector2(body.x - CLASSIC_SIDE_COL * 0.5, mid)
		var y_range := Vector2(40, body.y - 50)
		bottom.position = origin  # needed by _avoid_cutouts
		dpad = _avoid_cutouts(dpad, 34.0, y_range)
		diamond = _avoid_cutouts(diamond, 36.0, y_range)
		menu = Vector2(body.x - CLASSIC_SIDE_COL * 0.5, body.y - 22)

	top.position = (origin + screen_pos * k).floor()
	bottom.position = origin
	bottom.setup_classic(body, screen_pos, dpad, diamond, menu)


# --- Camera punch holes ------------------------------------------------------

## The screen's camera cutouts, in screen pixels (empty on most PCs).
func _cutouts() -> Array[Rect2]:
	if not test_cutouts.is_empty():
		return test_cutouts
	var out: Array[Rect2] = []
	for r in DisplayServer.get_display_cutouts():
		out.append(r)
	return out


## Moves a control (given in game pixels inside `bottom`, with its touch radius)
## up or down, within y_range, until no camera cutout overlaps it. Stays put if
## it's already clear, or if there's nowhere clear to go.
func _avoid_cutouts(center: Vector2, radius: float, y_range: Vector2) -> Vector2:
	var cutouts := _cutouts()
	if cutouts.is_empty():
		return center
	var k := screen_scale
	var hits := func(c: Vector2) -> bool:
		var on_screen := Rect2(bottom.position + (c - Vector2(radius, radius)) * k, Vector2(radius, radius) * 2.0 * k)
		for cut: Rect2 in cutouts:
			if on_screen.intersects(cut.grow(4.0 * k)):
				return true
		return false
	if not hits.call(center):
		return center
	# Try the nearest positions first, alternating down and up.
	for step in range(4, int(y_range.y - y_range.x) + 4, 4):
		for dir in [1, -1]:
			var y: float = center.y + dir * step
			if y >= y_range.x and y <= y_range.y and not hits.call(Vector2(center.x, y)):
				return Vector2(center.x, y)
	return center


# --- Drawing the console -----------------------------------------------------

func _style(color: Color, radius: float, edge := Color.TRANSPARENT, edge_width := 0.0,
		shadow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if edge_width > 0.0:
		sb.border_color = edge
		sb.border_width_bottom = int(edge_width)
		sb.border_width_right = int(edge_width * 0.5)
	if shadow > 0.0:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = int(shadow)
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	return sb


func _draw() -> void:
	var k := screen_scale
	var p: Dictionary = PALETTES[shell_index]
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DESK)
	if style == Style.CLASSIC:
		_draw_classic(k, p)
	else:
		_draw_dual(k, p)


func _draw_body(k: float, rect: Rect2, p: Dictionary, radius: float) -> void:
	var body: Color = p["body"]
	draw_style_box(_style(body, radius * k, p["edge"], 3.0 * k, 8.0 * k), rect)
	# A soft highlight along the top edge.
	draw_line(rect.position + Vector2(radius * k, 2 * k), Vector2(rect.end.x - radius * k, rect.position.y + 2 * k),
		body.lightened(0.18), maxf(1.0, k))


func _draw_screen_bezel(k: float, rect: Rect2) -> void:
	draw_style_box(_style(COLOR_BEZEL, 5.0 * k), rect.grow(BEZEL * k))


func _draw_name(k: float, p: Dictionary, center_x: float, top_y: float) -> void:
	var font := ThemeDB.fallback_font
	var label := "CLASSIC  ADVENTURE"
	var fs := int(maxf(8.0, 7.0 * k))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(floorf(center_x - w * 0.5), floorf(top_y + fs * 0.85)), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p["text"])


func _draw_led(k: float, p: Dictionary, pos: Vector2) -> void:
	var led: Color = p["led"]
	draw_circle(pos, 4.0 * k, Color(led, 0.18))
	draw_circle(pos, 1.6 * k, led)


func _draw_grille(k: float, p: Dictionary, center: Vector2, cols: int, rows: int) -> void:
	var dot := maxf(1.0, k * 0.9)
	var step := 3.5 * k
	var color: Color = (p["edge"] as Color).darkened(0.35)
	for row in rows:
		for col in cols:
			var offset := Vector2(col - (cols - 1) * 0.5, row - (rows - 1) * 0.5) * step
			draw_circle(center + offset, dot, color)


func _draw_dual(k: float, p: Dictionary) -> void:
	_draw_hinge(k, p["body"], p["edge"])
	_draw_body(k, _upper_rect, p, 12.0)
	_draw_body(k, _lower_rect, p, 12.0)
	# The top screen has no bezel (the game sits straight in the body);
	# the bottom screen keeps its frame.
	var top_rect := Rect2(top.position, top.size * k)
	_draw_screen_bezel(k, Rect2(bottom.position + Vector2(DUAL_COL, TOP_IN) * k, SCREEN * k))

	_draw_name(k, p, _upper_rect.get_center().x, top_rect.end.y + BEZEL * k + 2 * k)
	_draw_led(k, p, _lower_rect.position + Vector2(14, 14) * k)
	# Microphone hole, bottom-centre of the lower half.
	draw_circle(Vector2(_lower_rect.get_center().x, _lower_rect.end.y - BOTTOM_IN * k * 0.45),
		maxf(1.0, 1.2 * k), COLOR_BEZEL)


func _draw_hinge(k: float, body: Color, edge: Color) -> void:
	var hinge: Rect2
	if side_by_side:
		var x := _upper_rect.end.x - 4 * k
		var h := _upper_rect.size.y * 0.7
		hinge = Rect2(x, _upper_rect.get_center().y - h * 0.5, _lower_rect.position.x - x + 4 * k, h)
	else:
		var y := _upper_rect.end.y - 4 * k
		var w := _upper_rect.size.x * 0.7
		hinge = Rect2(_upper_rect.get_center().x - w * 0.5, y, w, _lower_rect.position.y - y + 4 * k)
	draw_style_box(_style(edge.darkened(0.15), HINGE * k * 0.5), hinge)
	# A shine line down the middle makes it read as a round barrel.
	var c := hinge.get_center()
	if side_by_side:
		draw_line(Vector2(c.x, hinge.position.y + 4 * k), Vector2(c.x, hinge.end.y - 4 * k), body.lightened(0.1), maxf(1.0, k))
	else:
		draw_line(Vector2(hinge.position.x + 4 * k, c.y), Vector2(hinge.end.x - 4 * k, c.y), body.lightened(0.1), maxf(1.0, k))


func _draw_classic(k: float, p: Dictionary) -> void:
	_draw_body(k, _body_rect, p, 16.0)
	var screen_rect := Rect2(top.position, SCREEN * k)

	# A recessed panel around the screen, then the screen's own bezel.
	var panel_color: Color = (p["edge"] as Color).darkened(0.25)
	draw_style_box(_style(panel_color, 9.0 * k), screen_rect.grow(BEZEL * k + 6 * k))
	_draw_screen_bezel(k, screen_rect)

	if _classic_portrait:
		_draw_name(k, p, screen_rect.get_center().x, screen_rect.end.y + BEZEL * k + 6 * k)
		_draw_led(k, p, screen_rect.position + Vector2(-BEZEL - 3, 14) * k)
		# Speaker grille, bottom-right corner of the body.
		_draw_grille(k, p, _body_rect.end - Vector2(30, 24) * k, 5, 4)
	else:
		_draw_name(k, p, screen_rect.get_center().x, screen_rect.end.y + BEZEL * k + 2 * k)
		_draw_led(k, p, _body_rect.position + Vector2(CLASSIC_SIDE_COL * 0.5, 16) * k)
		# Speaker grille, bottom of the left column.
		_draw_grille(k, p, _body_rect.position + Vector2(CLASSIC_SIDE_COL * 0.5, CLASSIC_LANDSCAPE.y - 22) * k, 6, 3)
