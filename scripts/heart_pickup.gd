extends Area2D
class_name HeartPickup
## Restores one full heart when the player touches it.

@export var heal_amount := 2

var _t := 0.0


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.heal(heal_amount)
		queue_free()


func _draw() -> void:
	HeartShape.draw(self, Vector2(0, sin(_t * 4.0) * 1.5), 2, 9.0)
