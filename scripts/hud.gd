extends Control
class_name Hud
## Hearts in the top-left corner and a centred message line.

var current := 6
var max_hp := 6
var message := ""
var message_timer := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func set_health(value: int, maximum: int) -> void:
	current = value
	max_hp = maximum
	queue_redraw()


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
	var heart_count := ceili(max_hp / 2.0)
	for i in heart_count:
		var fill := clampi(current - i * 2, 0, 2)
		HeartShape.draw(self, Vector2(12 + i * 13, 12), fill, 11.0)

	if message != "":
		var font := ThemeDB.fallback_font
		var font_size := 16
		var view := get_viewport_rect().size
		var text_w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2((view.x - text_w) * 0.5, view.y * 0.35)
		draw_string(font, pos + Vector2(1, 1), message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
		draw_string(font, pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
