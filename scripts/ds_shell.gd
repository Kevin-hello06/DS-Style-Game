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
## Fold 7 opened sideways (same layout as the kart game): the inner camera sits
## halfway down the right edge of the lower half. The D-pad and A/B/X/Y sit a
## little below halfway down, mirrored (the D-pad is as far from the left edge
## as A is from the right edge), with A/B/X/Y just far enough in that A keeps
## about 7 mm clear of the camera.
const FOLD_BELOW_MIDDLE := 12.0 # game pixels below the middle of the lower half
const FOLD_HOLE_CLEAR := 0.047  # clear zone round the hole, as a share of the display width (~7 mm)
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
const LENS_EDGE := 12.0    # classic upright: dark lens panel around the screen...
const LENS_LABEL := 24.0   # ...with room under the screen for the name

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
## Fill: the console scales to the edges of the display (any scale, e.g. 4.6x),
## and the single-screen body stretches to use a tall or wide phone fully.
## Sharp: whole-number scales only (crisper pixels), with dark space around.
static var fill_screen := true
static var style := Style.DUAL      # the style currently in use
## For testing on a PC: pretend the screen has camera cutouts here (screen
## pixels). On a phone the real cutouts are read from Android instead.
static var test_cutouts: Array[Rect2] = []

## Laptop testing: F2 shows the game as it would look on a phone, inside the
## window, whatever size the window is. Sizes are the real screens in pixels;
## "hole" is a rough camera punch-hole position (drawn in, and avoided).
const PREVIEWS := [
	{"name": "Off"},
	{"name": "Phone upright", "size": Vector2(1080, 2400), "fold": false, "hole": Rect2(505, 35, 70, 70)},
	{"name": "Phone sideways", "size": Vector2(2400, 1080), "fold": false, "hole": Rect2(35, 505, 70, 70)},
	{"name": "Fold 7 cover", "size": Vector2(1080, 2520), "fold": true, "hole": Rect2(505, 35, 70, 70)},
	{"name": "Fold 7 open", "size": Vector2(1968, 2184), "fold": true, "hole": Rect2(1790, 1480, 80, 80)},
	{"name": "Fold 7 open sideways", "size": Vector2(2184, 1968), "fold": true, "hole": Rect2(2104, 1441, 50, 50)},
]
static var preview_index := 0

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
var _offset := Vector2.ZERO  # where the safe area (clear of camera holes) starts
var _area := Rect2()         # the part of the window in use (all of it, or the F2 preview shape)
var _preview_hole := Rect2()
var _preview_layer: Control  # draws the preview's camera hole and name on top
var _fold_hole := Rect2()    # where the Fold 7's inner camera is assumed to be (opened sideways)
var _skip_fold_hole := false
var _side_col := CLASSIC_SIDE_COL  # classic sideways: width of each control column


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

	_preview_layer = Control.new()
	_preview_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_preview_layer.set_anchors_preset(PRESET_FULL_RECT)
	_preview_layer.draw.connect(_draw_preview_layer)
	add_child(_preview_layer)

	resized.connect(_layout)
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	# F2 (laptop only): cycle through phone shapes to see how they'd look.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F2 and not OS.has_feature("mobile"):
		preview_index = (preview_index + 1) % PREVIEWS.size()
		_layout()
		get_viewport().set_input_as_handled()


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


static func screen_label() -> String:
	return "Fill" if fill_screen else "Sharp"


func toggle_fill() -> void:
	fill_screen = not fill_screen
	_save_settings()
	_layout()


func next_console_mode() -> void:
	console_mode = CONSOLE_MODES[(CONSOLE_MODES.find(console_mode) + 1) % CONSOLE_MODES.size()]
	_save_settings()
	_layout()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the audio settings that are already in there
	cfg.set_value("display", "shell", shell_index)
	cfg.set_value("display", "console", console_mode)
	cfg.set_value("display", "fill", fill_screen)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		shell_index = clampi(cfg.get_value("display", "shell", 0), 0, PALETTES.size() - 1)
		console_mode = cfg.get_value("display", "console", "auto")
		fill_screen = cfg.get_value("display", "fill", true)
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
	if is_fold_device() or PREVIEWS[preview_index].get("fold", false):
		return Style.DUAL
	# Ordinary phones are long and thin (about 2:1 or more, either way round).
	var ratio := maxf(s.x, s.y) / minf(s.x, s.y)
	return Style.CLASSIC if ratio >= 1.7 else Style.DUAL


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	var full := size
	if full.x <= 0.0 or full.y <= 0.0:
		return
	_area = Rect2(Vector2.ZERO, full)
	_preview_hole = Rect2()
	_fold_hole = Rect2()
	var preview: Dictionary = PREVIEWS[preview_index]
	if preview.has("size"):
		# Fit the phone's shape into the window, and put its camera hole in.
		var dev: Vector2 = preview["size"]
		var fit := minf(full.x / dev.x, full.y / dev.y)
		_area = Rect2(((full - dev * fit) * 0.5).floor(), (dev * fit).floor())
		var hole: Rect2 = preview["hole"]
		_preview_hole = Rect2(_area.position + hole.position * fit, hole.size * fit)
	style = _pick_style(_area.size)
	viewport.size = Vector2i(SCREEN)
	top.size = SCREEN

	# Lay everything out inside the safe area, clear of camera punch holes,
	# notches and the like; the console body still paints to the edges.
	var safe := _safe_area(_area.size)
	safe.position += _area.position
	_offset = safe.position
	if style == Style.CLASSIC:
		_layout_classic(safe.size)
	else:
		_layout_dual(safe.size)
	top.position += _offset
	bottom.position += _offset
	_body_rect.position += _offset
	_upper_rect.position += _offset
	_lower_rect.position += _offset
	if fill_screen:
		_stretch_body_to_edges(_area)
	_preview_layer.queue_redraw()
	top.scale = Vector2(game_scale, game_scale)
	bottom.scale = Vector2(screen_scale, screen_scale)
	queue_redraw()


func _whole(k: float) -> float:
	if fill_screen:
		return k  # fill the display exactly
	return floorf(k) if k >= 1.0 else k  # whole-number scale = sharp pixels


func _layout_dual(s: Vector2) -> void:
	var half_w := SCREEN.x + DUAL_COL * 2.0
	var upper_h := TOP_IN + SCREEN.y + LABEL_IN
	var lower_h := TOP_IN + SCREEN.y + BOTTOM_IN
	var stacked := Vector2(half_w, upper_h + HINGE + lower_h)
	var side := Vector2(half_w * 2.0 + HINGE, upper_h)
	var pad := Vector2.ZERO if fill_screen else Vector2(OUTER, OUTER) * 2.0

	var stacked_k := minf(s.x / (stacked + pad).x, s.y / (stacked + pad).y)
	var side_k := minf(s.x / (side + pad).x, s.y / (side + pad).y)
	side_by_side = side_k > stacked_k
	var k := _whole(side_k if side_by_side else stacked_k)
	screen_scale = k

	# Size of each half, in game pixels. With Fill, the halves stretch to share
	# the whole display (edge to edge, like the kart game), split by the hinge.
	var upper := Vector2(half_w, upper_h)
	var lower := Vector2(half_w, lower_h)
	if fill_screen:
		var room := (s / k).floor()
		if side_by_side:
			var w := floorf((room.x - HINGE) * 0.5)
			upper = Vector2(w, room.y)
			lower = Vector2(room.x - HINGE - w, room.y)
		else:
			var h := floorf((room.y - HINGE) * 0.5)
			upper = Vector2(room.x, h)
			lower = Vector2(room.x, room.y - HINGE - h)
		upper = upper.max(Vector2(half_w, upper_h))
		lower = lower.max(Vector2(half_w, lower_h))

	var total := Vector2(upper.x + HINGE + lower.x, maxf(upper.y, lower.y)) if side_by_side \
		else Vector2(maxf(upper.x, lower.x), upper.y + HINGE + lower.y)
	var origin := ((s - total * k) * 0.5).floor()
	_upper_rect = Rect2(origin, upper * k)
	if side_by_side:
		_lower_rect = Rect2(origin + Vector2(upper.x + HINGE, 0) * k, lower * k)
	else:
		_lower_rect = Rect2(origin + Vector2(0, upper.y + HINGE) * k, lower * k)

	# The top screen: 24 tiles wide, centred in its half with the name below.
	game_scale = k
	var top_size := Vector2(DUAL_TOP_W, SCREEN.y)
	viewport.size = Vector2i(top_size)
	top.size = top_size
	var top_pos := ((upper - top_size - Vector2(0, LABEL_IN - TOP_IN)) * 0.5).floor()
	top.position = (_upper_rect.position + top_pos * k).floor()
	bottom.position = _lower_rect.position

	# The bottom screen, centred in its half; the controls sit midway between
	# its sides and the edges of the body, a little below its middle. If the
	# phone's camera hole would cover one, it's moved up or down out of the way.
	var screen_pos := ((lower - SCREEN - Vector2(0, BOTTOM_IN - TOP_IN)) * 0.5).floor()
	var col := screen_pos.x  # body width beside the bottom screen
	var controls_y := screen_pos.y + SCREEN.y * 0.5 + 10
	var dpad := Vector2(col * 0.5, controls_y)
	var diamond := Vector2(lower.x - col * 0.5, controls_y)
	_fold_hole = Rect2()
	if _on_fold() and s.x > s.y and not side_by_side:
		# Fold 7 opened sideways: same placement as the kart game.
		var hole_px := _offset + _lower_rect.position + Vector2(lower.x * k - s.x * 0.02, lower.y * k * 0.5)
		var clear_px := s.x * FOLD_HOLE_CLEAR
		_fold_hole = Rect2(hole_px - Vector2(clear_px, clear_px), Vector2(clear_px, clear_px) * 2.0)
		var y := lower.y * 0.5 + FOLD_BELOW_MIDDLE
		# Furthest right A may go and still keep the clear zone (game pixels).
		var hole := (hole_px - _offset - _lower_rect.position) / k
		var keep := clear_px / k + BottomScreen.BUTTON_RADIUS
		var dy := y - hole.y
		var a_max := hole.x - sqrt(maxf(keep * keep - dy * dy, 0.0))
		var a_x := minf(lower.x - col * 0.5 + BottomScreen.DIAMOND_OFFSET, a_max)
		diamond = Vector2(a_x - BottomScreen.DIAMOND_OFFSET, y)
		# Mirror: D-pad's left edge as far from the left side as A's right edge is from the right side.
		var edge := lower.x - (a_x + BottomScreen.BUTTON_RADIUS)
		dpad = Vector2(edge + BottomScreen.DPAD_ARM, y)
	# Other holes the phone reports are still stepped around (the Fold camera
	# above is already allowed for exactly, so it's left out here).
	var y_range := Vector2(34, lower.y - 34)
	_skip_fold_hole = true
	dpad = _avoid_cutouts(dpad, 34.0, y_range)
	diamond = _avoid_cutouts(diamond, 36.0, y_range)
	_skip_fold_hole = false
	bottom.setup_dual(lower, screen_pos, dpad, diamond)


func _layout_classic(s: Vector2) -> void:
	_classic_portrait = s.y >= s.x
	var body := CLASSIC_PORTRAIT if _classic_portrait else CLASSIC_LANDSCAPE
	var pad := Vector2.ZERO if fill_screen else Vector2(OUTER, OUTER) * 2.0
	var k := _whole(minf(s.x / (body + pad).x, s.y / (body + pad).y))
	screen_scale = k
	game_scale = k
	if fill_screen:
		# Stretch the body along the phone's long side to use all of it.
		body = (s / k - pad).max(body).floor()
	_side_col = (body.x - SCREEN.x) * 0.5 if not _classic_portrait else CLASSIC_SIDE_COL
	var origin := ((s - body * k) * 0.5).floor()
	_body_rect = Rect2(origin, body * k)

	# Positions inside the body, in game pixels.
	var screen_pos: Vector2
	var dpad: Vector2
	var diamond: Vector2
	var menu: Vector2
	var cs := 1.0  # size of the controls
	if _classic_portrait:
		screen_pos = Vector2((body.x - SCREEN.x) * 0.5, LENS_EDGE + 6)
		# The controls get bigger when there's room below the screen (tall
		# phones), and sit a little above the middle of that space.
		var region := Vector2(screen_pos.y + SCREEN.y + LENS_LABEL + 12, body.y - 36)
		cs = clampf((region.y - region.x) / 118.0, 1.0, 1.7)
		var controls_mid := region.x + (region.y - region.x) * 0.44
		dpad = Vector2(18 + (BottomScreen.DPAD_ARM + 8) * cs, controls_mid)
		diamond = Vector2(body.x - 18 - (BottomScreen.DIAMOND_OFFSET + BottomScreen.BUTTON_RADIUS + 4) * cs, controls_mid)
		var y_range := Vector2(region.x + 34 * cs, region.y - 34 * cs)
		bottom.position = origin  # needed by _avoid_cutouts
		dpad = _avoid_cutouts(dpad, 34.0 * cs, y_range)
		diamond = _avoid_cutouts(diamond, 36.0 * cs, y_range)
		menu = Vector2(body.x * 0.5, body.y - 22)
	else:
		screen_pos = Vector2(_side_col, (body.y - SCREEN.y - LABEL_IN) * 0.5 + 4)
		var mid := screen_pos.y + SCREEN.y * 0.5
		dpad = Vector2(_side_col * 0.5, mid)
		diamond = Vector2(body.x - _side_col * 0.5, mid)
		var y_range := Vector2(40, body.y - 50)
		bottom.position = origin  # needed by _avoid_cutouts
		dpad = _avoid_cutouts(dpad, 34.0, y_range)
		diamond = _avoid_cutouts(diamond, 36.0, y_range)
		menu = Vector2(body.x - _side_col * 0.5, body.y - 22)

	top.position = (origin + screen_pos * k).floor()
	bottom.position = origin
	bottom.setup_classic(body, screen_pos, dpad, diamond, menu, cs)


# --- Camera punch holes, notches, Dynamic Island -----------------------------

## The part of the display clear of camera cutouts at the top and bottom
## edges, as reported by the phone (Android's cutout list, plus the system's
## safe area on phones and iOS). On a PC this is the whole window.
## Cutouts at the left or right edge don't move the layout: the screens are
## well away from the sides there, and the D-pad or buttons step around a
## hole instead (e.g. the Fold 7's camera on the buttons' side in DUAL).
func _safe_area(full: Vector2) -> Rect2:
	var safe := Rect2(Vector2.ZERO, full)
	if test_cutouts.is_empty() and OS.has_feature("mobile"):
		var sys := Rect2(DisplayServer.get_display_safe_area())
		if sys.has_area():
			safe = safe.intersection(Rect2(0, sys.position.y, full.x, sys.size.y))
	# Any cutout touching an edge pushes that edge of the safe area inwards.
	var margin := 6.0
	for window_cut: Rect2 in _cutouts():
		var cut := Rect2(window_cut.position - _area.position, window_cut.size)
		var to_edge := {
			"top": cut.position.y, "bottom": full.y - cut.end.y,
			"left": cut.position.x, "right": full.x - cut.end.x,
		}
		var edge: String = to_edge.keys()[0]
		for e: String in to_edge:
			if to_edge[e] < to_edge[edge]:
				edge = e
		if to_edge[edge] > minf(full.x, full.y) * 0.12:
			continue  # well away from every edge: the controls step around it instead
		match edge:
			"top":
				safe = safe.intersection(Rect2(0, cut.end.y + margin, full.x, full.y))
			"bottom":
				safe = safe.intersection(Rect2(0, 0, full.x, cut.position.y - margin))
	return Rect2(safe.position.floor(), safe.size.floor())


## Fill: the body behind the safe area reaches the display's edges.
func _stretch_body_to_edges(area: Rect2) -> void:
	var a := area.position
	var e := area.end
	if style == Style.CLASSIC:
		_body_rect = area
	elif side_by_side:
		_upper_rect = Rect2(a.x, a.y, _upper_rect.end.x - a.x, area.size.y)
		_lower_rect = Rect2(_lower_rect.position.x, a.y, e.x - _lower_rect.position.x, area.size.y)
	else:
		_upper_rect = Rect2(a.x, a.y, area.size.x, _upper_rect.end.y - a.y)
		_lower_rect = Rect2(a.x, _lower_rect.position.y, area.size.x, e.y - _lower_rect.position.y)


## The screen's camera cutouts, in screen pixels (empty on most PCs).
## True on a Galaxy Z Fold, or when previewing one with F2.
func _on_fold() -> bool:
	return is_fold_device() or PREVIEWS[preview_index].get("fold", false)


func _cutouts() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _fold_hole.has_area() and not _skip_fold_hole:
		out.append(_fold_hole)  # assumed, so it's avoided even if Android doesn't report it
	if not test_cutouts.is_empty():
		out.append_array(test_cutouts)
		return out
	if _preview_hole.has_area():
		out.append(_preview_hole)
		return out
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
		var on_screen := Rect2(_offset + bottom.position + (c - Vector2(radius, radius)) * k, Vector2(radius, radius) * 2.0 * k)
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


# --- F2 preview overlay ------------------------------------------------------

func _draw_preview_layer() -> void:
	var preview: Dictionary = PREVIEWS[preview_index]
	if not preview.has("size"):
		return
	if _preview_hole.has_area():
		_preview_layer.draw_circle(_preview_hole.get_center(), _preview_hole.size.x * 0.5, Color.BLACK)
	if _fold_hole.has_area():  # the ~7 mm zone kept clear round the Fold's camera
		_preview_layer.draw_arc(_fold_hole.get_center(), _fold_hole.size.x * 0.5, 0, TAU, 48, Color(1, 0, 1, 0.8), 2.0)
	var font := ThemeDB.fallback_font
	var text := "Preview: %s  (%d x %d)  -  F2 for next" % [preview["name"], preview["size"].x, preview["size"].y]
	_preview_layer.draw_rect(Rect2(4, 4, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12, 22), Color(0, 0, 0, 0.7))
	_preview_layer.draw_string(font, Vector2(10, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


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
	if fill_screen:
		# Edge to edge: square corners, no shadow, no shading line.
		draw_rect(rect, body)
		return
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
	_draw_screen_bezel(k, Rect2(bottom.position + bottom.screen_rect.position * k, SCREEN * k))

	_draw_name(k, p, _upper_rect.get_center().x, top_rect.end.y + BEZEL * k + 2 * k)
	_draw_led(k, p, _lower_rect.position + Vector2(14, 14) * k)
	# Microphone hole, bottom-centre of the lower half.
	draw_circle(Vector2(_lower_rect.get_center().x, _lower_rect.end.y - BOTTOM_IN * k * 0.45),
		maxf(1.0, 1.2 * k), COLOR_BEZEL)


## Classic upright: a dark glass panel holding the screen, with the power
## light and the name inside it, and a thin accent line across the body.
func _draw_lens(k: float, p: Dictionary, screen_rect: Rect2) -> void:
	var lens := Rect2(screen_rect.position - Vector2(LENS_EDGE - 2, LENS_EDGE - 2) * k,
		screen_rect.size + Vector2(LENS_EDGE * 2 - 4, LENS_EDGE + LENS_LABEL - 4) * k)
	var glass := (p["edge"] as Color).darkened(0.55)
	var sb := _style(glass, 10.0 * k)
	sb.corner_radius_bottom_right = int(26 * k)  # one big rounded corner for a bit of character
	draw_style_box(sb, lens)
	# Accent line across the body, just above the lens.
	draw_rect(Rect2(_body_rect.position.x, lens.position.y - 6 * k, _body_rect.size.x, maxf(1.0, 1.5 * k)),
		(p["edge"] as Color).darkened(0.1))
	_draw_screen_bezel(k, screen_rect)
	# Inside the lens, under the screen: power light on the left, name in the middle.
	var label_y := screen_rect.end.y + BEZEL * k + (LENS_LABEL - BEZEL - 6) * k * 0.5
	_draw_led(k, p, Vector2(screen_rect.position.x + 6 * k, label_y + 1 * k))
	var font := ThemeDB.fallback_font
	var fs := int(maxf(8.0, 7.0 * k))
	var label := "CLASSIC  ADVENTURE"
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(floorf(screen_rect.get_center().x - w * 0.5), floorf(label_y + fs * 0.35)), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
	_draw_grille(k, p, _body_rect.end - Vector2(34, 30) * k, 6, 5)


func _draw_hinge(k: float, body: Color, edge: Color) -> void:
	if fill_screen:
		# Edge to edge: a plain dark band across the whole display where the
		# two halves meet.
		var band := Rect2(_upper_rect.end.x, _area.position.y, _lower_rect.position.x - _upper_rect.end.x, _area.size.y) if side_by_side \
			else Rect2(_area.position.x, _upper_rect.end.y, _area.size.x, _lower_rect.position.y - _upper_rect.end.y)
		draw_rect(band, edge.darkened(0.35))
		return
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
	if _classic_portrait:
		_draw_lens(k, p, screen_rect)
		return

	# A recessed panel around the screen, then the screen's own bezel.
	var panel_color: Color = (p["edge"] as Color).darkened(0.25)
	draw_style_box(_style(panel_color, 9.0 * k), screen_rect.grow(BEZEL * k + 6 * k))
	_draw_screen_bezel(k, screen_rect)

	if _classic_portrait:
		_draw_grille(k, p, _body_rect.end - Vector2(34, 30) * k, 6, 5)
	else:
		_draw_name(k, p, screen_rect.get_center().x, screen_rect.end.y + BEZEL * k + 2 * k)
		_draw_led(k, p, _body_rect.position + Vector2(_side_col * 0.5, 16) * k)
		# Speaker grille, bottom of the left column.
		_draw_grille(k, p, Vector2(_body_rect.position.x + _side_col * 0.5 * k, _body_rect.end.y - 22 * k), 6, 3)
