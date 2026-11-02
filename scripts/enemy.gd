extends CharacterBody2D
class_name Enemy
## Blob enemy: wanders until the player comes close, then chases.
## Takes knockback when hit and flashes white.

signal killed(at: Vector2)

@export var speed := 38.0
@export var max_hp := 2
@export var damage := 1
@export var sight_range := 110.0

const COLOR_BODY := Color("#8e44ad")
const COLOR_BODY_DARK := Color("#6c3483")

var hp := 2
var target: Node2D
var knockback := Vector2.ZERO
var flash_timer := 0.0
var wander_dir := Vector2.ZERO
var wander_timer := 0.0
var _bob := 0.0


func _ready() -> void:
	hp = max_hp
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.ENEMY

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	_bob = randf() * TAU


func _physics_process(delta: float) -> void:
	flash_timer = maxf(flash_timer - delta, 0.0)
	_bob += delta * 6.0

	var dir := Vector2.ZERO
	if is_instance_valid(target) and global_position.distance_to(target.global_position) < sight_range:
		dir = global_position.direction_to(target.global_position)
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(0.8, 2.0)
			wander_dir = Vector2.ZERO if randf() < 0.3 else Vector2.from_angle(randf() * TAU)
		dir = wander_dir * 0.5

	velocity = dir * speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	queue_redraw()


func hit(amount: int, from: Vector2) -> void:
	hp -= amount
	flash_timer = 0.12
	knockback = (global_position - from).normalized() * 220.0
	if hp <= 0:
		killed.emit(global_position)
		queue_free()


func _draw() -> void:
	var squash := sin(_bob) * 0.8
	var color := Color.WHITE if flash_timer > 0.0 else COLOR_BODY
	draw_circle(Vector2(0, 2), 7.0 + squash, COLOR_BODY_DARK if flash_timer <= 0.0 else Color.WHITE)
	draw_circle(Vector2(0, 0), 6.5 + squash, color)
	draw_rect(Rect2(-3, -2, 2, 2), Color.BLACK)
	draw_rect(Rect2(1, -2, 2, 2), Color.BLACK)
