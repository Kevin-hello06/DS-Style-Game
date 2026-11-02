class_name HeartShape
## Draws a heart (full, half or empty) on any CanvasItem.
## Shared by the HUD and the heart pickup.

const COLOR_FULL := Color("#e74c3c")
const COLOR_EMPTY := Color("#3b1f1f")
const COLOR_OUTLINE := Color("#1a0d0d")
const STEPS := 28


static func _point(t: float, size: float) -> Vector2:
	# Classic parametric heart curve, scaled so the heart is ~`size` px wide.
	var x := 16.0 * pow(sin(t), 3)
	var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
	return Vector2(x, y) * (size / 34.0)


## fill: 0 = empty, 1 = half, 2 = full
static func draw(canvas: CanvasItem, center: Vector2, fill: int, size := 10.0) -> void:
	var full := PackedVector2Array()
	for i in STEPS:
		full.append(center + _point(TAU * i / STEPS, size))
	canvas.draw_colored_polygon(full, COLOR_FULL if fill >= 2 else COLOR_EMPTY)

	if fill == 1:
		# Left half: t from PI (bottom tip) round to TAU (top cusp).
		var half := PackedVector2Array()
		for i in STEPS / 2 + 1:
			half.append(center + _point(PI + PI * i / (STEPS / 2), size))
		canvas.draw_colored_polygon(half, COLOR_FULL)

	var outline := full.duplicate()
	outline.append(full[0])
	canvas.draw_polyline(outline, COLOR_OUTLINE, 1.0)
