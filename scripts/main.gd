extends Node2D
## Builds the current area from its ASCII map, spawns everything, and wires up
## the HUD and touch controls.
##
## Map legend:
##   #  wall          ~  water (blocks movement)
##   .  floor         P  player start (first area only)
##   E  enemy         H  heart pickup
##   1-9  door: walks you to the area named in DOORS. The matching digit in
##        that area is where you come out.
## The outer border is always solid (except doors), so rows don't need perfect lengths.

const TILE := 16

const AREAS := {
	"field": [
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
		"#......................................1",
		"#..######..........................E...1",
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
		"##################22####################",
	],
	"cave": [
		"##############################",
		"#............................#",
		"#..####........E.......####..#",
		"#..#..#................#..#..#",
		"#..#..#.....######.....#..#..#",
		"#...........#....#...........#",
		"#.....E.....#..H.#.......E...#",
		"#...........#....#...........#",
		"#...........##.###...........#",
		"1............................#",
		"1.........E..........E.......#",
		"#............................#",
		"#..~~~~..............~~~~....#",
		"#..~~~~.......H......~~~~....#",
		"#............................#",
		"##############################",
	],
	"lake": [
		"##################22####################",
		"#......................................#",
		"#......................................#",
		"#.....~~~~~~~~~~~~~~~~~~~~~~~~~~.......#",
		"#.....~~~~~~~~~~~~~~~~~~~~~~~~~~.......#",
		"#.....~~~~~~~~~~~~~~~~~~~~~~~~~~...E...#",
		"#.....~~~~~~~~~~~~~~~~~~~~~~~~~~.......#",
		"#..E...................................#",
		"#.................................H....#",
		"#..........E..............E............#",
		"#......................................#",
		"########################################",
	],
}

## Where each door digit leads, per area.
const DOORS := {
	"field": {"1": "cave", "2": "lake"},
	"cave": {"1": "field"},
	"lake": {"2": "field"},
}

## Floor colours per area (checkerboard pair), so each area feels different.
const FLOOR_COLORS := {
	"field": [Color("#6aa84f"), Color("#62a048")],
	"cave": [Color("#5d5a6b"), Color("#565363")],
	"lake": [Color("#c9b47a"), Color("#c2ad72")],
}

## Static vars survive the scene reload we use to switch areas.
static var area := "field"
static var arrive_door := ""      # door digit we came through ("" = use P)
static var saved_health := -1     # -1 = full health
static var cleared := {}          # areas already cleared: their doors stay open

const ENEMY_HEART_DROP_CHANCE := 0.35

const COLOR_WALL := Color("#5b4636")
const COLOR_WALL_TOP := Color("#7d6450")
const COLOR_WATER := Color("#3d85c6")
const COLOR_WATER_SHINE := Color("#6fa8dc")
const COLOR_DOOR := Color("#1b1410")

var map: Array = []
var map_size := Vector2i.ZERO
var player: Player
var hud: Hud
var enemies_left := 0
var _leaving := false
var doors_locked := false
var _doors := {}                  # door Area2D -> digit
var _door_blockers: StaticBody2D  # solid boxes over the doors while locked


func _ready() -> void:
	_setup_input()
	_build_world()
	_build_ui()
	hud.show_message(area.capitalize() + ("" if not doors_locked else " - defeat all enemies!"), 2.0)


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

func _is_door(t: String) -> bool:
	return t.length() == 1 and t >= "1" and t <= "9"


func _raw_tile(x: int, y: int) -> String:
	if y >= 0 and y < map.size() and x >= 0 and x < map[y].length():
		return map[y][x]
	return "."


func _tile_at(x: int, y: int) -> String:
	var t := _raw_tile(x, y)
	if _is_door(t):
		return t
	if x <= 0 or y <= 0 or x >= map_size.x - 1 or y >= map_size.y - 1:
		return "#"
	return t


func _tile_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


## The first walkable tile next to a door, so we don't spawn on top of it.
func _spawn_next_to(cell: Vector2i) -> Vector2:
	for dir in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
		var c: Vector2i = cell + dir
		if _tile_at(c.x, c.y) in [".", "P", "H"]:
			return _tile_center(c)
	return _tile_center(cell)


func _build_world() -> void:
	map = AREAS[area]
	var width := 0
	for row in map:
		width = maxi(width, row.length())
	map_size = Vector2i(width, map.size())

	# All solid tiles share one static body; each tile adds a box shape.
	var solids := StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = Layers.WORLD
	solids.collision_mask = 0
	add_child(solids)

	_door_blockers = StaticBody2D.new()
	_door_blockers.name = "DoorBlockers"
	_door_blockers.collision_layer = Layers.WORLD
	_door_blockers.collision_mask = 0
	add_child(_door_blockers)

	var player_pos := Vector2(TILE * 2, TILE * 2)
	var arrive_pos := Vector2.INF
	var enemy_spots: Array[Vector2] = []
	var heart_spots: Array[Vector2] = []

	for y in map_size.y:
		for x in map_size.x:
			var center := _tile_center(Vector2i(x, y))
			var t := _tile_at(x, y)
			match t:
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
				_:
					if _is_door(t):
						_add_door(center, t)
						if t == arrive_door and arrive_pos == Vector2.INF:
							arrive_pos = _spawn_next_to(Vector2i(x, y))

	if arrive_pos != Vector2.INF:
		player_pos = arrive_pos

	queue_redraw()

	player = Player.new()
	player.name = "Player"
	player.position = player_pos
	if saved_health > 0:
		player.health = saved_health
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

	# Lock the doors until every enemy is beaten (unless cleared before).
	doors_locked = enemies_left > 0 and not cleared.has(area)
	if not doors_locked:
		_door_blockers.queue_free()
		_door_blockers = null


func _add_door(at: Vector2, digit: String) -> void:
	var door := Area2D.new()
	door.position = at
	door.collision_layer = 0
	door.collision_mask = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Slightly bigger than a tile, so bumping a locked door still registers.
	rect.size = Vector2(TILE + 4, TILE + 4)
	shape.shape = rect
	door.add_child(shape)

	var block := CollisionShape2D.new()
	var block_rect := RectangleShape2D.new()
	block_rect.size = Vector2(TILE, TILE)
	block.shape = block_rect
	block.position = at
	_door_blockers.add_child(block)
	door.body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			_go_through(digit))
	add_child(door)
	_doors[door] = digit


func _go_through(digit: String) -> void:
	if _leaving or not DOORS.get(area, {}).has(digit):
		return
	if doors_locked:
		hud.show_message("Defeat all enemies first!", 1.5)
		return
	_leaving = true
	saved_health = player.health
	arrive_door = digit
	area = DOORS[area][digit]
	# Deferred: we're inside a physics callback right now.
	get_tree().reload_current_scene.call_deferred()


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
	var floor_a: Color = FLOOR_COLORS[area][0]
	var floor_b: Color = FLOOR_COLORS[area][1]
	for y in map_size.y:
		for x in map_size.x:
			var r := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
			var t := _tile_at(x, y)
			match t:
				"#":
					draw_rect(r, COLOR_WALL)
					draw_rect(Rect2(r.position, Vector2(TILE, 4)), COLOR_WALL_TOP)
				"~":
					draw_rect(r, COLOR_WATER)
					draw_line(r.position + Vector2(3, 6), r.position + Vector2(9, 6), COLOR_WATER_SHINE)
					draw_line(r.position + Vector2(7, 11), r.position + Vector2(13, 11), COLOR_WATER_SHINE)
				_:
					draw_rect(r, floor_a if (x + y) % 2 == 0 else floor_b)
					if _is_door(t):
						draw_rect(r.grow(-2), COLOR_DOOR)
						if doors_locked:  # bars
							for i in 3:
								var bx := r.position.x + 4 + i * 4
								draw_line(Vector2(bx, r.position.y + 2), Vector2(bx, r.end.y - 2), COLOR_WALL_TOP, 2.0)


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
	if enemies_left <= 0 and doors_locked:
		_unlock_doors()


func _unlock_doors() -> void:
	doors_locked = false
	cleared[area] = true
	if is_instance_valid(_door_blockers):
		_door_blockers.queue_free()
	_door_blockers = null
	queue_redraw()
	hud.show_message("Area cleared! The doors are open.")
	# If the player is already standing against a door, let them through now.
	for door in _doors:
		if door.overlaps_body(player):
			_go_through(_doors[door])
			break


func _on_player_died() -> void:
	hud.show_message("You fell...")
	player.set_physics_process(false)
	saved_health = -1      # come back with full hearts, at the door you came in by
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
