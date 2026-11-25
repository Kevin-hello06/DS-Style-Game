extends Control
class_name Hud
## Drawn over the game on the top screen.
## Always: messages ("Area cleared!" and so on) along the bottom edge.
## CLASSIC console only: hearts top-left, and top-right a small map of the
## area you're in with a tiny world map under it, since there's no second
## screen to show them on.

const FONT_SIZE := 12
const MAP_CELL := Vector2(10, 6)
const MAP_GAP := Vector2(4, 3)
const AREA_MAP_MAX := Vector2(64, 40)  # biggest the area map gets, in game pixels

var world: World
var banner_title := ""     # big "LEVEL 1 CLEAR!" / "GAME CLEAR!" box
var banner_text := ""
var title_banner := false  # the level select's title: only shown when it has its own screen
var message := ""
var message_timer := 0.0
var _blink := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func show_banner(title: String, text: String) -> void:
	banner_title = title
	banner_text = text
	message = ""


func show_message(text: String, duration := 2.5) -> void:
	message = text
	message_timer = duration
	queue_redraw()


func _process(delta: float) -> void:
	_blink += delta
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message = ""
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var view := get_viewport_rect().size

	if DSShell.style == DSShell.Style.CLASSIC:
		var backing := Color(0, 0, 0, 0.35)
		if world and is_instance_valid(world.player):
			var hearts := ceili(world.player.max_health / 2.0)
			draw_rect(Rect2(2, 2, 8 + hearts * 12, 16), backing)
			BottomScreen.draw_hearts(self, world.player, Vector2(10, 10), 9.0, 12.0)
			# Level number under the hearts.
			var lv := "Level %d" % (World.level + 1)
			draw_rect(Rect2(2, 20, font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8, 12), backing)
			draw_string(font, Vector2(6, 29), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		# Top-right: the area map, with the tiny world map under it.
		var cols := 0
		var rows := 0
		for c: Vector2i in World.map_pos().values():
			cols = maxi(cols, c.x + 1)
			rows = maxi(rows, c.y + 1)
		var world_size := Vector2(cols, rows) * (MAP_CELL + MAP_GAP) - MAP_GAP
		if world:
			var px := clampi(mini(int(AREA_MAP_MAX.x / world.map_size.x), int(AREA_MAP_MAX.y / world.map_size.y)), 1, 3)
			var area_size := Vector2(world.map_size * px)
			var panel_w := maxf(area_size.x, world_size.x)
			var panel := Rect2(view.x - panel_w - 6, 5, panel_w, area_size.y + 5 + world_size.y)
			draw_rect(panel.grow(3), backing)
			BottomScreen.draw_area_map(self, world, Rect2(panel.position, Vector2(panel_w, area_size.y)), px, _blink)
			BottomScreen.draw_minimap(self, font, panel.get_center().x, panel.position.y + area_size.y + 5,
				MAP_CELL, MAP_GAP, 0, _blink)

	# On the single-screen console the level select covers the game screen and
	# has its own title, so the title banner is left off there.
	if banner_title != "" and not (title_banner and DSShell.style == DSShell.Style.CLASSIC):
		_draw_banner(font, view)
		return
	if message == "":
		return
	var text_w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# Near the bottom edge of the top screen, so it doesn't hide the player.
	var pos := Vector2(floorf((view.x - text_w) * 0.5), view.y - 10)
	draw_rect(Rect2(pos + Vector2(-4, -FONT_SIZE), Vector2(text_w + 8, FONT_SIZE + 6)), Color(0, 0, 0, 0.45))
	draw_string(font, pos + Vector2(1, 1), message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.BLACK)
	draw_string(font, pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


func _draw_banner(font: Font, view: Vector2) -> void:
	var tw := font.get_string_size(banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var sw := font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var box_w := maxf(tw, sw) + 24
	var box := Rect2(((view - Vector2(box_w, 56)) * 0.5).floor(), Vector2(box_w, 56))
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.35))
	draw_rect(box, Color(0.06, 0.05, 0.1, 0.92))
	draw_rect(box, Color("#f2c14e"), false, 2.0)
	var pulse := 0.85 + 0.15 * sin(_blink * 6.0)
	draw_string(font, Vector2(floorf(box.get_center().x - tw * 0.5), box.position.y + 28), banner_title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#f2c14e") * Color(pulse, pulse, pulse))
	draw_string(font, Vector2(floorf(box.get_center().x - sw * 0.5), box.position.y + 46), banner_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
