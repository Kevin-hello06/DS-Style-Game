extends CharacterBody2D
class_name Player
## Top-down hero: 8-way movement, 4-way facing, sword swing,
## knockback and invincibility frames after taking damage.

signal health_changed(current: int, max_hp: int)
signal died

const SPEED := 90.0
const ATTACK_TIME := 0.18
const ATTACK_COOLDOWN := 0.32
const INVINCIBLE_TIME := 1.0
const KNOCKBACK_SPEED := 170.0
const KNOCKBACK_DECAY := 900.0

const COLOR_TUNIC := Color("#2a6f97")
const COLOR_SKIN := Color("#f1c27d")
const COLOR_HAIR := Color("#7b3f00")
const COLOR_BLADE := Color("#e0e0e0")

var max_health := 6  # in half-hearts: 6 = 3 hearts
var health := 6
var facing := Vector2.DOWN
var attack_timer := 0.0
var cooldown_timer := 0.0
var invincible_timer := 0.0
var knockback := Vector2.ZERO

var _hurtbox: Area2D
var _sword: Area2D


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 10)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)

	# Hurtbox: detects touching enemy bodies.
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = Layers.ENEMY
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(12, 14)
	hurt_shape.shape = hurt_rect
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)


func _physics_process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	invincible_timer = maxf(invincible_timer - delta, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_end_attack()
		input *= 0.25  # slow down while swinging
	elif input != Vector2.ZERO:
		# Snap facing to the dominant direction (4-way, Zelda-style).
		if absf(input.x) > absf(input.y):
			facing = Vector2(signf(input.x), 0)
		else:
			facing = Vector2(0, signf(input.y))

	if Input.is_action_just_pressed("attack") and attack_timer <= 0.0 and cooldown_timer <= 0.0:
		_start_attack()

	velocity = input * SPEED + knockback
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

	if invincible_timer <= 0.0:
		for body in _hurtbox.get_overlapping_bodies():
			if body is Enemy:
				take_damage(body.damage, body.global_position)
				break

	# Blink while invincible.
	modulate.a = 0.35 if invincible_timer > 0.0 and int(invincible_timer * 20.0) % 2 == 0 else 1.0
	queue_redraw()


func _start_attack() -> void:
	attack_timer = ATTACK_TIME
	cooldown_timer = ATTACK_COOLDOWN

	_sword = Area2D.new()
	_sword.collision_layer = 0
	_sword.collision_mask = Layers.ENEMY
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 10) if facing.x != 0.0 else Vector2(10, 16)
	shape.shape = rect
	_sword.add_child(shape)
	_sword.position = facing * 12.0
	_sword.body_entered.connect(_on_sword_hit)
	add_child(_sword)


func _end_attack() -> void:
	if is_instance_valid(_sword):
		_sword.queue_free()
	_sword = null


func _on_sword_hit(body: Node2D) -> void:
	if body.has_method("hit"):
		body.hit(1, global_position)


func take_damage(amount: int, from: Vector2) -> void:
	if invincible_timer > 0.0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	invincible_timer = INVINCIBLE_TIME
	knockback = (global_position - from).normalized() * KNOCKBACK_SPEED
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _draw() -> void:
	# Placeholder art: swap for an AnimatedSprite2D when you have sprites.
	draw_rect(Rect2(-5, -1, 10, 9), COLOR_TUNIC)          # body
	draw_rect(Rect2(-4, -8, 8, 7), COLOR_SKIN)            # head
	draw_rect(Rect2(-4, -8, 8, 2), COLOR_HAIR)            # hair
	if facing != Vector2.UP:                               # eyes
		var eye_shift := facing.x * 1.5
		draw_rect(Rect2(-3 + eye_shift, -5, 1, 2), Color.BLACK)
		draw_rect(Rect2(2 + eye_shift, -5, 1, 2), Color.BLACK)

	if attack_timer > 0.0:
		var size := Vector2(12, 3) if facing.x != 0.0 else Vector2(3, 12)
		var blade := Rect2(facing * 12.0 - size * 0.5, size)
		draw_rect(blade, COLOR_BLADE)
