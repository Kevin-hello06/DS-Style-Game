extends Node2D
## Builds the world from the ASCII map below, spawns everything, and wires up
## the HUD and touch controls.
##
## Map legend:
##   #  wall          ~  water (blocks movement)
##   .  grass         P  player start
##   E  enemy         H  heart pickup
## The outer border is always solid, so rows don't need perfect lengths.

const TILE := 16

const MAP: Array[String] = [
	"########################################",
	"#......................................#",
	"#..P.........~~~~~~....................#",
	"#............~~~~~~.........E..........#",
	"#....####....~~~~~~....................#",
	"#....#..#..............#######.........#",
	"#....#..#....H.........#.....#.........#",
	"#....##.#..............#..E..#.........#",
	"#......................#.....#.........#",
	"#......................###.###.........#",
	"#........E.............................#",
	"#......................................#",
	"#..######..........................E...#",
	"#..#....#.............~~~~~............#",
	"#..#.H..#.............~~~~~............#",
	"#..#....#.......E.....~~~~~............#",
	"#..###.##..............................#",
	"#..........................####........#",
	"#.....E....................#..#....E...#",
	"#..........~~~~............#H.#........#",
	"#..........~~~~............##.#........#",
	"#......................................#",
	"#......................................#",
	"########################################",
]

const ENEMY_HEART_DROP_CHANCE := 0.35

const COLOR_GRASS_A := Color("#6aa84f")
const COLOR_GRASS_B := Color("#62a048")
const COLOR_WALL := Color("#5b4636")
const COLOR_WALL_TOP := Color("#7d6450")
const COLOR_WATER := Color("#3d85c6")
const COLOR_WATER_SHINE := Color("#6fa8dc")

var map_size := Vector2i.ZERO
var player: Player
var hud: Hud
var enemies_left := 0


func _ready() -> void:
	_setup_input()
	_build_world()
	_build_ui()


# --- Input -----------------------------------------------------------------

func _setup_input() -> void:
	# Defined in code so the project works without editing the Input Map.
	# You can move these into Project Settings > Input Map later if you prefer.
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("attack", [KEY_SPACE, KEY_J, KEY_Z])


func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return  # already set up (e.g. after a scene reload)
	InputMap.add_action(action, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


# --- World -----------------------------------------------------------------

func _tile_at(x: int, y: int) -> String:
	if x <= 0 or y <= 0 or x >= map_size.x - 1 or y >= map_size.y - 1:
		return "#"
	if y < MAP.size() and x < MAP[y].length():
		return MAP[y][x]
	return "."


func _build_world() -> void:
	var width := 0
	for row in MAP:
		width = maxi(width, row.length())
	map_size = Vector2i(width, MAP.size())

	# All solid tiles share one static body; each tile adds a box shape.
	var solids := StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = Layers.WORLD
	solids.collision_mask = 0
	add_child(solids)

	var player_pos := Vector2(TILE * 2, TILE * 2)
	var enemy_spots: Array[Vector2] = []
	var heart_spots: Array[Vector2] = []

	for y in map_size.y:
		for x in map_size.x:
			var center := Vector2(x, y) * TILE + Vector2(TILE, TILE) * 0.5
			match _tile_at(x, y):
				"#", "~":
					var shape := CollisionShape2D.new()
					var rect := RectangleShape2D.new()
					rect.size = Vector2(TILE, TILE)
					shape.shape = rect
					shape.position = center
					solids.add_child(shape)
				"P":
					player_pos = center
				"E":
					enemy_spots.append(center)
				"H":
					heart_spots.append(center)

	queue_redraw()

	player = Player.new()
	player.name = "Player"
	player.position = player_pos
	add_child(player)
	player.died.connect(_on_player_died)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_size.x * TILE
	camera.limit_bottom = map_size.y * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

	for spot in enemy_spots:
		_spawn_enemy(spot)
	for spot in heart_spots:
		_spawn_heart(spot)


func _spawn_enemy(at: Vector2) -> void:
	var enemy := Enemy.new()
	enemy.position = at
	enemy.target = player
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)
	enemies_left += 1


func _spawn_heart(at: Vector2) -> void:
	var heart := HeartPickup.new()
	heart.position = at
	add_child(heart)


func _draw() -> void:
	for y in map_size.y:
		for x in map_size.x:
			var r := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
			match _tile_at(x, y):
				"#":
					draw_rect(r, COLOR_WALL)
					draw_rect(Rect2(r.position, Vector2(TILE, 4)), COLOR_WALL_TOP)
				"~":
					draw_rect(r, COLOR_WATER)
					draw_line(r.position + Vector2(3, 6), r.position + Vector2(9, 6), COLOR_WATER_SHINE)
					draw_line(r.position + Vector2(7, 11), r.position + Vector2(13, 11), COLOR_WATER_SHINE)
				_:
					draw_rect(r, COLOR_GRASS_A if (x + y) % 2 == 0 else COLOR_GRASS_B)


# --- UI & game flow --------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	hud = Hud.new()
	layer.add_child(hud)
	hud.set_health(player.health, player.max_health)
	player.health_changed.connect(hud.set_health)

	# On the phone, show the virtual joystick + attack button.
	if DisplayServer.is_touchscreen_available():
		layer.add_child(TouchControls.new())


func _on_enemy_killed(at: Vector2) -> void:
	enemies_left -= 1
	if randf() < ENEMY_HEART_DROP_CHANCE:
		# Deferred: we may be inside a physics callback right now.
		_spawn_heart.call_deferred(at)
	if enemies_left <= 0:
		hud.show_message("Area cleared!")


func _on_player_died() -> void:
	hud.show_message("You fell...")
	player.set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
