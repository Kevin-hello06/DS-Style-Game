extends Control
class_name DSShell
## The handheld: a clamshell console body with the two screens set into it.
##   Top screen:    the game (a SubViewport holding the World).
##   Bottom screen: hearts, mini-map, joystick, A/B buttons, pause menu (256x192).
## On tall or square displays (Fold cover screen, Fold opened, phones in
## portrait) the two halves are stacked with a hinge between them; on wide
## displays (landscape, laptop window) they open side by side.
## Both halves are exactly the same size, like a real clamshell, with two
## 256x192 screens. Everything is scaled by a whole number so pixels stay
## crisp. Re-arranges itself whenever the display size changes (folding /
## unfolding).
##
## The shell colour can be changed in the pause menu and is remembered.

const SCREEN := Vector2(256, 192)   # DS screen size: bottom screen, and the top screen's minimum
## Biggest the top screen may grow to fill spare room. Equal to SCREEN means
## it never grows, so both halves stay identical. Try Vector2(416, 384) to
## let the game view use extra space instead.
const MAX_TOP := SCREEN

# Console body measurements, in DS pixels.
const SIDE := 18.0       # body edge to screen, left and right
const TOP_IN := 12.0     # body edge to screen, at the top of each half
const LABEL_IN := 18.0   # below the top screen (room for the name)
const BOTTOM_IN := 18.0  # below the bottom screen (same as LABEL_IN: equal halves)
const HINGE := 10.0      # gap between the two halves
const OUTER := 8.0       # space around the whole console
const BEZEL := 4.0       # black frame around each screen

const SETTINGS_PATH := "user://settings.cfg"
const COLOR_DESK := Color("#101016")
const COLOR_BEZEL := Color("#0b0b10")

## Shell colours: body, edge (shading + hinge), text, power light.
const PALETTES := [
	{"name": "Midnight", "body": Color("#2e3047"), "edge": Color("#1d1e30"), "text": Color("#9da3c7"), "led": Color("#6cf2a0")},
	{"name": "Ice", "body": Color("#d9e2ec"), "edge": Color("#a9b8c9"), "text": Color("#5b6b80"), "led": Color("#2fcf6f")},
	{"name": "Coral", "body": Color("#e8806e"), "edge": Color("#bf5a4a"), "text": Color("#fff1ec"), "led": Color("#fff27a")},
	{"name": "Mint", "body": Color("#93d6bd"), "edge": Color("#5fae93"), "text": Color("#2f5e4f"), "led": Color("#ff6b6b")},
]

static var shell_index := 0

var top: SubViewportContainer
var viewport: SubViewport
var world: World
var bottom: BottomScreen
var side_by_side := false
var screen_scale := 1.0

# Where things ended up (in real pixels), for drawing.
var _upper_rect := Rect2()   # top half of the console (or left half)
var _lower_rect := Rect2()   # bottom half (or right half)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_load_shell()

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


# --- Shell colour ------------------------------------------------------------

static func shell_name() -> String:
	return PALETTES[shell_index]["name"]


func next_shell() -> void:
	shell_index = (shell_index + 1) % PALETTES.size()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the audio settings that are already in there
	cfg.set_value("display", "shell", shell_index)
	cfg.save(SETTINGS_PATH)
	queue_redraw()


func _load_shell() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		shell_index = clampi(cfg.get_value("display", "shell", 0), 0, PALETTES.size() - 1)


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return

	# Smallest possible console (top screen at DS size) in each arrangement.
	var half_w := SCREEN.x + SIDE * 2.0
	var upper_h := TOP_IN + SCREEN.y + LABEL_IN
	var lower_h := TOP_IN + SCREEN.y + BOTTOM_IN
	var stacked_min := Vector2(half_w, upper_h + HINGE + lower_h) + Vector2(OUTER, OUTER) * 2.0
	var side_min := Vector2(half_w * 2.0 + HINGE, upper_h) + Vector2(OUTER, OUTER) * 2.0

	var stacked_k := minf(s.x / stacked_min.x, s.y / stacked_min.y)
	var side_k := minf(s.x / side_min.x, s.y / side_min.y)
	side_by_side = side_k > stacked_k
	var k := side_k if side_by_side else stacked_k
	if k >= 1.0:
		k = floorf(k)  # whole-number scale = sharp pixels
	screen_scale = k

	# Let the top screen grow into whatever room is left.
	var avail := (s / k).floor()
	var top_size: Vector2
	if side_by_side:
		top_size = Vector2(avail.x - OUTER * 2.0 - SIDE * 2.0 - HINGE - half_w,
			avail.y - OUTER * 2.0 - TOP_IN - LABEL_IN)
	else:
		top_size = Vector2(avail.x - OUTER * 2.0 - SIDE * 2.0,
			avail.y - OUTER * 2.0 - TOP_IN - LABEL_IN - HINGE - lower_h)
	top_size = top_size.clamp(SCREEN, MAX_TOP).floor()

	viewport.size = Vector2i(top_size)
	top.size = top_size
	top.scale = Vector2(k, k)
	bottom.scale = Vector2(k, k)

	# Size of each console half and of the whole console, in DS pixels.
	var upper: Vector2
	var lower: Vector2
	var total: Vector2
	if side_by_side:
		var h := maxf(top_size.y, SCREEN.y) + TOP_IN + LABEL_IN
		upper = Vector2(top_size.x + SIDE * 2.0, h)
		lower = Vector2(half_w, h)
		total = Vector2(upper.x + HINGE + lower.x, h)
	else:
		var w := maxf(top_size.x, SCREEN.x) + SIDE * 2.0
		upper = Vector2(w, TOP_IN + top_size.y + LABEL_IN)
		lower = Vector2(w, lower_h)
		total = Vector2(w, upper.y + HINGE + lower.y)

	var origin := ((s - total * k) * 0.5).floor()
	_upper_rect = Rect2(origin, upper * k)
	if side_by_side:
		_lower_rect = Rect2(origin + Vector2(upper.x + HINGE, 0) * k, lower * k)
	else:
		_lower_rect = Rect2(origin + Vector2(0, upper.y + HINGE) * k, lower * k)

	# Screens sit centred in their halves, with the label space below the top one.
	top.position = (_upper_rect.position + Vector2((upper.x - top_size.x) * 0.5,
		TOP_IN + (upper.y - TOP_IN - LABEL_IN - top_size.y) * 0.5) * k).floor()
	bottom.position = (_lower_rect.position + Vector2((lower.x - SCREEN.x) * 0.5,
		TOP_IN + (lower.y - TOP_IN - BOTTOM_IN - SCREEN.y) * 0.5) * k).floor()
	queue_redraw()


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
	var body: Color = p["body"]
	var edge: Color = p["edge"]
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DESK)

	_draw_hinge(k, body, edge)

	# The two halves of the body.
	var body_style := _style(body, 12.0 * k, edge, 3.0 * k, 8.0 * k)
	draw_style_box(body_style, _upper_rect)
	draw_style_box(body_style, _lower_rect)
	# A soft highlight along the top edge of each half.
	for r: Rect2 in [_upper_rect, _lower_rect]:
		draw_line(r.position + Vector2(12 * k, 2 * k), Vector2(r.end.x - 12 * k, r.position.y + 2 * k),
			body.lightened(0.18), maxf(1.0, k))

	# Screen bezels.
	var bezel_style := _style(COLOR_BEZEL, 5.0 * k)
	draw_style_box(bezel_style, Rect2(top.position, top.size * k).grow(BEZEL * k))
	draw_style_box(bezel_style, Rect2(bottom.position, SCREEN * k).grow(BEZEL * k))

	_draw_speakers(k, edge)
	_draw_details(k, p)


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


func _draw_speakers(k: float, edge: Color) -> void:
	# Two grilles of little holes, either side of the top screen.
	var screen_r := Rect2(top.position, top.size * k)
	var cy := screen_r.get_center().y
	var dot := maxf(1.0, k * 0.9)
	var step := 3.5 * k
	for side_x: float in [_upper_rect.position.x + SIDE * k * 0.5, _upper_rect.end.x - SIDE * k * 0.5]:
		for row in 7:
			for col in 2:
				var pos := Vector2(side_x + (col - 0.5) * step, cy + (row - 3) * step)
				draw_circle(pos, dot, edge.darkened(0.35))


func _draw_details(k: float, p: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var text_color: Color = p["text"]

	# Name under the top screen.
	var label := "FOLD  ADVENTURE"
	var fs := int(maxf(8.0, 7.0 * k))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var label_y := top.position.y + top.size.y * k + BEZEL * k + (LABEL_IN - BEZEL) * k * 0.5 + fs * 0.35
	draw_string(font, Vector2(floorf(_upper_rect.get_center().x - w * 0.5), floorf(label_y)), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# Power light, top-left of the lower half, with a soft glow.
	var led: Color = p["led"]
	var led_pos := _lower_rect.position + Vector2(SIDE * 0.5, TOP_IN * 0.5 + 2) * k
	draw_circle(led_pos, 4.0 * k, Color(led, 0.18))
	draw_circle(led_pos, 1.6 * k, led)

	# Microphone hole, bottom-centre of the lower half.
	var mic := Vector2(_lower_rect.get_center().x, _lower_rect.end.y - BOTTOM_IN * k * 0.45)
	draw_circle(mic, maxf(1.0, 1.2 * k), COLOR_BEZEL)
