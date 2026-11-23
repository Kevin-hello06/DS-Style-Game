extends Control
class_name Hud
## Messages over the game on the top screen ("Area cleared!" and so on).
## Hearts now live on the bottom screen.

const FONT_SIZE := 12

var message := ""
var message_timer := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func show_message(text: String, duration := 2.5) -> void:
	message = text
	message_timer = duration
	queue_redraw()


func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message = ""
			queue_redraw()


func _draw() -> void:
	if message == "":
		return
	var font := ThemeDB.fallback_font
	var view := get_viewport_rect().size
	var text_w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# Near the bottom edge of the top screen, so it doesn't hide the player.
	var pos := Vector2(floorf((view.x - text_w) * 0.5), view.y - 10)
	draw_rect(Rect2(pos + Vector2(-4, -FONT_SIZE), Vector2(text_w + 8, FONT_SIZE + 6)), Color(0, 0, 0, 0.45))
	draw_string(font, pos + Vector2(1, 1), message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.BLACK)
	draw_string(font, pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
