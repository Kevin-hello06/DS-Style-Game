extends Node2D
class_name World
## The game world shown on the top screen. Builds the current area from its
## ASCII map, spawns everything, and handles doors between areas, clearing
## levels and the end of the game.
##
## Map legend:
##   #  wall          ~  water (blocks movement)
##   .  floor         P  player start (first area only)
##   E  enemy         H  heart pickup
##   1-9  door: leads to the area named in the level's "doors". The matching
##        digit in that area is where you come out.
## The outer border is always solid (except doors), so rows don't need perfect lengths.
## Doors stay locked until every enemy in the area is defeated.

const TILE := 16

## The levels. Each has its own areas, doors, mini-map layout, floor colours
## and enemy toughness. Clear every area in a level to move on to the next.
const LEVELS := [
	{
		"name": "Green Fields",
		"start": "field",
		"enemy_hp": 2,
		"enemy_speed": 38.0,
		"areas": {
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
		},
		"doors": {
			"field": {"1": "cave", "2": "lake"},
			"cave": {"1": "field"},
			"lake": {"2": "field"},
		},
		"map_pos": {"field": Vector2i(0, 0), "cave": Vector2i(1, 0), "lake": Vector2i(0, 1)},
		"floors": {
			"field": [Color("#6aa84f"), Color("#62a048")],
			"cave": [Color("#5d5a6b"), Color("#565363")],
			"lake": [Color("#c9b47a"), Color("#c2ad72")],
		},
	},
	{
		"name": "Desert Ruins",
		"start": "dunes",
		"enemy_hp": 3,
		"enemy_speed": 44.0,
		"areas": {
			"dunes": [
				"################################",
				"#..............................#",
				"#..P......~~~~.................#",
				"#.........~~~~.......E.........#",
				"#..............................#",
				"#....####.........#####........#",
				"#....#..#..E......#...#........#",
				"#....#............#.H.#........#",
				"#....#..#.........#...#........1",
				"#....####.........##.##...E....1",
				"#..............................#",
				"#..............................#",
				"#.##........##..........~~~~...#",
				"#.......E....#..........~~~~...#",
				"#..............................#",
				"#................E.............#",
				"#..............................#",
				"###############22###############",
			],
			"ruins": [
				"##############################",
				"#............................#",
				"#............................#",
				"#........E...........E.......#",
				"#.....##....##....##....##...#",
				"#.....##....##....##....##...#",
				"#............................#",
				"#............................#",
				"1............~~~~.........E..#",
				"1...E........~~~~............#",
				"#............................#",
				"#............................#",
				"#.....##....##....##....##...#",
				"#.....##....##.H..##....##...#",
				"#........E...........E.......#",
				"#............................#",
				"#............................#",
				"####################33########",
			],
			"oasis": [
				"###############22###############",
				"#..............................#",
				"#..............................#",
				"#..............................#",
				"#...E......................E...#",
				"#.........~~~~~~~~~~~~.........#",
				"#.........~~~~~~~~~~~~.........#",
				"#.........~~~~....~~~~.........#",
				"#.....H...~~~~....~~~~...H.....#",
				"#.........~~~~~~~~~~~~.........#",
				"#.........~~~~~~~~~~~~.........#",
				"#..............................#",
				"#...E......................E...#",
				"#..............E...............#",
				"#..............................#",
				"################################",
			],
			"tomb": [
				"####################33####",
				"#........................#",
				"#.H......................#",
				"#........................#",
				"#...##################...#",
				"#...#....................#",
				"#...#........E...........#",
				"#...#....##....##....#...#",
				"#...#..E.............#...#",
				"#...#.......##....E..#...#",
				"#...#.......H........#...#",
				"#...#................#...#",
				"#...######....########...#",
				"#........................#",
				"#........................#",
				"#..E........E.........E..#",
				"#........................#",
				"##########################",
			],
		},
		"doors": {
			"dunes": {"1": "ruins", "2": "oasis"},
			"ruins": {"1": "dunes", "3": "tomb"},
			"oasis": {"2": "dunes"},
			"tomb": {"3": "ruins"},
		},
		"map_pos": {"dunes": Vector2i(0, 0), "ruins": Vector2i(1, 0), "oasis": Vector2i(0, 1), "tomb": Vector2i(1, 1)},
		"floors": {
			"dunes": [Color("#d9c38a"), Color("#d2bb80")],
			"ruins": [Color("#a39c8d"), Color("#9b9486")],
			"oasis": [Color("#7cbf6a"), Color("#74b862")],
			"tomb": [Color("#4f4a5e"), Color("#49445a")],
		},
	},
	{
		"name": "Frozen Castle",
		"start": "snowfield",
		"enemy_hp": 3,
		"enemy_speed": 52.0,
		"areas": {
			"snowfield": [
				"##################################",
				"#................................#",
				"#..............##................#",
				"#..P....##..........E............#",
				"#.......#..E..........##.........#",
				"#......................#.........#",
				"#................................#",
				"#...........~~~~~~~~.........E...#",
				"#....E......~~~~~~~~.............#",
				"#...........~~~~~~~~..E..........1",
				"#................................1",
				"#.....##...................##....#",
				"#......#....................#....#",
				"#.............##.................#",
				"#..H......E........E....~~~~~~...#",
				"#.......................~~~~~~...#",
				"#................................#",
				"##################################",
			],
			"ice cave": [
				"##############################",
				"#............................#",
				"#............................#",
				"#....#....###############....#",
				"#..E.#..................#....#",
				"#....#........E......E..#....#",
				"#....#..~~..............#....#",
				"#....#..~~......#####...#....#",
				"#....#..~~..............#....#",
				"1....#..~~..E...........#....#",
				"1....#.............H.......E.#",
				"#....#.......................#",
				"#....########...##########...#",
				"#............................#",
				"#............................#",
				"#........############.....~~.#",
				"#.........................~~.#",
				"#.H..E................E...~~.#",
				"#............................#",
				"##############22##############",
			],
			"castle yard": [
				"##############22##################",
				"#................................#",
				"#................................#",
				"#..E.............................#",
				"#.....########...............E...#",
				"#.....#......#...E...............#",
				"#.....#..E.H.#...................#",
				"#.....#......#...................#",
				"#.....###..###...................3",
				"#...................########.....3",
				"#...................#......#.....#",
				"#.......................E..#.....#",
				"#........~~~~.......#....H.#.....#",
				"#........~~~~.......########.....#",
				"#...E.........................E..#",
				"#...............E................#",
				"#................................#",
				"##################################",
			],
			"keep": [
				"##########################",
				"#........................#",
				"#.H......................#",
				"#..E....E....E....E....E.#",
				"#....#....#....#....#....#",
				"#....#....#....#....#....#",
				"#........................#",
				"#..........~~~~..........#",
				"3..........~~~~..........#",
				"3........................#",
				"#....#....#....#....#....#",
				"#....#....#....#....#....#",
				"#..E..................E..#",
				"#.......E........E.....H.#",
				"#........................#",
				"##########################",
			],
		},
		"doors": {
			"snowfield": {"1": "ice cave"},
			"ice cave": {"1": "snowfield", "2": "castle yard"},
			"castle yard": {"2": "ice cave", "3": "keep"},
			"keep": {"3": "castle yard"},
		},
		"map_pos": {"snowfield": Vector2i(0, 0), "ice cave": Vector2i(1, 0), "castle yard": Vector2i(1, 1), "keep": Vector2i(2, 1)},
		"floors": {
			"snowfield": [Color("#e6eef5"), Color("#dde7f0")],
			"ice cave": [Color("#a9c4dc"), Color("#a0bcd6")],
			"castle yard": [Color("#8e8a80"), Color("#87837a")],
			"keep": [Color("#6a4a58"), Color("#634452")],
		},
	},
]

const ENEMY_HEART_DROP_CHANCE := 0.35

const COLOR_WALL := Color("#5b4636")
const COLOR_WALL_TOP := Color("#7d6450")
const COLOR_WATER := Color("#3d85c6")
const COLOR_WATER_SHINE := Color("#6fa8dc")
const COLOR_DOOR := Color("#1b1410")
const COLOR_OUTSIDE := Color("#14121a")  # shown around an area smaller than the view

## Static vars survive the scene reload we use to switch areas.
static var level := 0             # index into LEVELS (0 = Level 1)
static var area := "field"
static var arrive_door := ""      # door digit we came through ("" = use P)
static var saved_health := -1     # -1 = full health
static var cleared := {}          # areas already cleared: their doors stay open
static var visited := {}          # areas seen so far (shown on the mini-map)
static var collected := {}        # area -> {heart position: true} for hearts already picked up
## True while the level select is showing: the chosen level's first area is
## shown as a still preview behind it.
static var title_mode := true
static var beaten := {}           # level index -> true once you've cleared it (saved)
static var _progress_loaded := false

const SETTINGS_PATH := "user://settings.cfg"


# --- The current level -------------------------------------------------------

static func level_data() -> Dictionary:
	return LEVELS[level]


static func areas() -> Dictionary:
	return level_data()["areas"]


static func doors() -> Dictionary:
	return level_data()["doors"]


static func map_pos() -> Dictionary:
	return level_data()["map_pos"]


## e.g. "Level 2: Desert Ruins"
static func level_title() -> String:
	return "Level %d: %s" % [level + 1, level_data()["name"]]


static func load_progress() -> void:
	if _progress_loaded:
		return
	_progress_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for i in cfg.get_value("progress", "beaten", []):
			beaten[int(i)] = true


static func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the other settings already saved
	cfg.set_value("progress", "beaten", beaten.keys())
	cfg.save(SETTINGS_PATH)


## Shows the level select (with level n previewed behind it).
static func go_to_level_select(n: int) -> void:
	start_level(n)
	title_mode = true


## Starts a level from scratch: full hearts, nothing cleared yet.
static func start_level(n: int) -> void:
	level = n
	area = level_data()["start"]
	arrive_door = ""
	saved_health = -1
	cleared = {}
	visited = {}
	collected = {}

var map: Array = []
var map_size := Vector2i.ZERO
var player: Player
var camera: Camera2D
var hud: Hud
var enemies_left := 0
var doors_locked := false
var _leaving := false
var _door_blockers: StaticBody2D  # solid boxes over the doors while locked
var _doors := {}                  # door Area2D -> digit
## Doors ignore the player until they've stepped away from every door once.
## Otherwise you'd arrive next to a door and get bounced straight back through it.
var _doors_armed := false
var _level_done := false
var _waiting_restart := false  # game clear: press A to play again
var _restart_ready := false
var _clear_frames := 0


func _ready() -> void:
	GameAudio.ensure(get_tree())
	load_progress()
	_setup_input()
	visited[area] = true
	_build_world()
	_build_hud()
	if title_mode:
		_freeze_for_title()
	elif arrive_door == "" and visited.size() == 1:
		hud.show_message("%s - defeat all enemies!" % level_title(), 3.0)
	elif doors_locked:
		hud.show_message("%s - defeat all enemies!" % area.capitalize(), 2.0)
	else:
		hud.show_message(area.capitalize(), 1.5)


# --- Input -----------------------------------------------------------------

func _setup_input() -> void:
	# Defined in code so the project works without editing the Input Map.
	# You can move these into Project Settings > Input Map later if you prefer.
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("attack", [KEY_SPACE, KEY_J, KEY_Z])  # A button
	_add_action("action_b", [KEY_K, KEY_X])            # B button (spare for later)
	_add_action("action_x", [KEY_I, KEY_C])            # X button (spare for later)
	_add_action("action_y", [KEY_U, KEY_V])            # Y button (spare for later)


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
	for dir: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
		var c := cell + dir
		if _tile_at(c.x, c.y) in [".", "P", "H"]:
			return _tile_center(c)
	return _tile_center(cell)


func _build_world() -> void:
	map = areas()[area]
	var width := 0
	for row: String in map:
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
	var arrived := false
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
					if not arrived and arrive_door == "":
						player_pos = center
				"E":
					enemy_spots.append(center)
				"H":
					heart_spots.append(center)
				_:
					if _is_door(t):
						_add_door(center, t)
						if t == arrive_door and not arrived:
							player_pos = _spawn_next_to(Vector2i(x, y))
							arrived = true

	queue_redraw()

	player = Player.new()
	player.name = "Player"
	player.position = player_pos
	if saved_health > 0:
		player.health = saved_health
	add_child(player)
	player.died.connect(_on_player_died)

	camera = Camera2D.new()
	_update_camera_limits()
	get_viewport().size_changed.connect(_update_camera_limits)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

	# A cleared area stays empty: its enemies don't come back.
	if not cleared.has(area):
		for spot in enemy_spots:
			_spawn_enemy(spot)
	# Hearts placed on the map come back only if you haven't picked them up yet.
	for spot in heart_spots:
		if not collected.get(area, {}).has(spot):
			_spawn_heart(spot, true)

	# Lock the doors until every enemy is beaten (unless cleared before).
	doors_locked = enemies_left > 0 and not cleared.has(area)
	if not doors_locked:
		cleared[area] = true
		_door_blockers.queue_free()
		_door_blockers = null


## Keeps the camera inside the area. If the area is smaller than the view
## (e.g. the lake on the tall Fold cover screen), it's centred instead.
func _update_camera_limits() -> void:
	var view := get_viewport_rect().size
	var area_px := Vector2(map_size * TILE)
	var margin := ((view - area_px) * 0.5).max(Vector2.ZERO).ceil()
	camera.limit_left = int(-margin.x)
	camera.limit_top = int(-margin.y)
	camera.limit_right = int(area_px.x + margin.x)
	camera.limit_bottom = int(area_px.y + margin.y)


func _physics_process(_delta: float) -> void:
	if _doors_armed or not is_instance_valid(player):
		return
	for door: Area2D in _doors:
		if door.overlaps_body(player):
			_clear_frames = 0
			return
	# Overlaps are only known after the physics engine has run a step or two,
	# so wait a few frames of "not touching any door" before arming.
	_clear_frames += 1
	if _clear_frames >= 3:
		_doors_armed = true


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
	door.body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			_go_through(digit))
	add_child(door)
	_doors[door] = digit

	var block := CollisionShape2D.new()
	var block_rect := RectangleShape2D.new()
	block_rect.size = Vector2(TILE, TILE)
	block.shape = block_rect
	block.position = at
	_door_blockers.add_child(block)


func _go_through(digit: String) -> void:
	if _leaving or not _doors_armed or not doors().get(area, {}).has(digit):
		return
	if doors_locked:
		hud.show_message("Defeat all enemies first!", 1.5)
		GameAudio.sfx("locked")
		return
	GameAudio.sfx("door")
	_leaving = true
	saved_health = player.health
	arrive_door = digit
	area = doors()[area][digit]
	# Deferred: we're inside a physics callback right now.
	get_tree().reload_current_scene.call_deferred()


func _spawn_enemy(at: Vector2) -> void:
	var enemy := Enemy.new()
	enemy.position = at
	enemy.max_hp = level_data()["enemy_hp"]       # tougher and faster in later levels
	enemy.speed = level_data()["enemy_speed"]
	enemy.target = player
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)
	enemies_left += 1


## map_heart: a heart from the map (remembered once picked up), not one an enemy dropped.
func _spawn_heart(at: Vector2, map_heart := false) -> void:
	var heart := HeartPickup.new()
	heart.position = at
	if map_heart:
		var where := area
		heart.picked_up.connect(func() -> void:
			if not collected.has(where):
				collected[where] = {}
			collected[where][at] = true)
	add_child(heart)


# --- For the maps on screen --------------------------------------------------

## The map character at a tile: "#" wall, "~" water, "1"-"9" door, anything else floor.
func tile_at(cell: Vector2i) -> String:
	return _tile_at(cell.x, cell.y)


func is_door(t: String) -> bool:
	return _is_door(t)


func enemies() -> Array[Node]:
	return get_children().filter(func(n: Node) -> bool: return n is Enemy and not n.is_queued_for_deletion())


func hearts() -> Array[Node]:
	return get_children().filter(func(n: Node) -> bool: return n is HeartPickup and not n.is_queued_for_deletion())


func _draw() -> void:
	var floor_a: Color = level_data()["floors"][area][0]
	var floor_b: Color = level_data()["floors"][area][1]
	draw_rect(Rect2(Vector2(-1000, -1000), Vector2(map_size * TILE) + Vector2(2000, 2000)), COLOR_OUTSIDE)
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


# --- HUD & game flow -------------------------------------------------------

func _build_hud() -> void:
	# This CanvasLayer draws on the top screen, over the game.
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Hud.new()
	hud.world = self
	layer.add_child(hud)


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
	GameAudio.sfx("unlock")
	if cleared.size() >= areas().size():
		_finish_level()
		return
	hud.show_message("Area cleared! The doors are open.")
	# If the player is already pushing against a door, let them through now.
	if not _doors_armed:
		return
	for door: Area2D in _doors:
		if door.overlaps_body(player):
			_go_through(_doors[door])
			break


## Level select: show the area as a still picture, centred, with the title.
func _freeze_for_title() -> void:
	player.set_physics_process(false)
	for e: Node in enemies():
		e.process_mode = Node.PROCESS_MODE_DISABLED
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(map_size * TILE) * 0.5
	var note := "  (cleared)" if beaten.has(level) else ""
	hud.show_banner("CLASSIC ADVENTURE", level_title() + note)
	hud.title_banner = true


## Every area in this level is cleared: on to the next level, or the end.
func _finish_level() -> void:
	_level_done = true
	beaten[level] = true
	save_progress()
	if level < LEVELS.size() - 1:
		hud.show_banner("LEVEL %d CLEAR!" % (level + 1),
			"Next: Level %d - %s" % [level + 2, LEVELS[level + 1]["name"]])
		await get_tree().create_timer(3.5).timeout
		start_level(level + 1)
		get_tree().reload_current_scene()
	else:
		hud.show_banner("GAME CLEAR!", "You beat all %d levels!  Press A for level select" % LEVELS.size())
		_waiting_restart = true


func _process(_delta: float) -> void:
	if not _waiting_restart:
		return
	# A fresh press of A plays again. A has to be let go first, so a button
	# still held from the last fight doesn't restart the game straight away.
	if not Input.is_action_pressed("attack"):
		_restart_ready = true
	elif _restart_ready:
		_waiting_restart = false
		go_to_level_select(0)
		get_tree().reload_current_scene()


func _on_player_died() -> void:
	if _level_done:
		return  # too late to lose now
	hud.show_message("You fell...")
	player.set_physics_process(false)
	saved_health = -1  # come back with full hearts, at the door you came in by
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
