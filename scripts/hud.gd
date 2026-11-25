extends Control
class_name Hud
## Drawn over the game on the top screen.
## Always: messages ("Area cleared!" and so on) along the bottom edge.
## CLASSIC console only: hearts top-left and a small mini-map top-right, since
## there's no second screen to show them on.

const FONT_SIZE := 12
const MAP_CELL := Vector2(14, 8)
const MAP_GAP := Vector2(5, 4)

var world: World
var message := ""
var message_timer := 0.0
var _blink := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


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
		# Mini-map, top-right.
		var cols := 0
		var rows := 0
		for c: Vector2i in World.MAP_POS.values():
			cols = maxi(cols, c.x + 1)
			rows = maxi(rows, c.y + 1)
		var map_size := Vector2(cols, rows) * (MAP_CELL + MAP_GAP) - MAP_GAP
		var map_rect := Rect2(Vector2(view.x - map_size.x - 6, 6), map_size)
		draw_rect(map_rect.grow(3), backing)
		BottomScreen.draw_minimap(self, font, map_rect.get_center().x, map_rect.position.y,
			MAP_CELL, MAP_GAP, 0, _blink)

	if message == "":
		return
	var text_w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# Near the bottom edge of the top screen, so it doesn't hide the player.
	var pos := Vector2(floorf((view.x - text_w) * 0.5), view.y - 10)
	draw_rect(Rect2(pos + Vector2(-4, -FONT_SIZE), Vector2(text_w + 8, FONT_SIZE + 6)), Color(0, 0, 0, 0.45))
	draw_string(font, pos + Vector2(1, 1), message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.BLACK)
	draw_string(font, pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
