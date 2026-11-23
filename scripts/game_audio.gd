extends AudioStreamPlayer
class_name GameAudio
## This node is the background music player, and also owns the players for
## sound effects. Sounds come from res://sounds/.
## It lives on the scene tree's root (not inside the level), so the music keeps
## playing smoothly while areas reload. Settings are saved to user://settings.cfg
## so they're remembered next time the game starts.
##
## Use it from anywhere:  GameAudio.sfx("swing")

const SETTINGS_PATH := "user://settings.cfg"
const SOUNDS := ["swing", "hit", "defeat", "hurt", "pickup", "door", "locked", "unlock", "die"]
const MUSIC_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0
const VOICES := 8  # how many sound effects can overlap

static var music_on := true
static var sfx_on := true

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


## Called once by the world. Creates the audio node if it doesn't exist yet.
static func ensure(tree: SceneTree) -> void:
	if tree.root.has_node("GameAudio"):
		return
	load_settings()
	var node := GameAudio.new()
	node.name = "GameAudio"
	# Deferred: the root is busy adding the level when this is called.
	tree.root.add_child.call_deferred(node)


## The audio node, or null if it isn't in the tree yet.
static func instance() -> GameAudio:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameAudio") as GameAudio


static func sfx(sound: String) -> void:
	var node := instance()
	if sfx_on and node:
		node._play_sfx(sound)


static func set_music(on: bool) -> void:
	music_on = on
	save_settings()
	var node := instance()
	if node:
		node._update_music()


static func set_sfx(on: bool) -> void:
	sfx_on = on
	save_settings()


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = cfg.get_value("audio", "music", true)
		sfx_on = cfg.get_value("audio", "sfx", true)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other settings already saved (e.g. shell colour)
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.save(SETTINGS_PATH)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep music going in the pause menu
	volume_db = MUSIC_VOLUME_DB

	for sound in SOUNDS:
		_streams[sound] = load("res://sounds/%s.wav" % sound)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		_voices.append(p)


func _ready() -> void:
	var bgm: AudioStreamWAV = load("res://sounds/bgm.wav")
	bgm.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bgm.loop_begin = 0
	bgm.loop_end = int(bgm.get_length() * bgm.mix_rate)
	stream = bgm
	_update_music()
	# We handle closing ourselves, so the music can stop cleanly first.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Stopping shortly before quitting avoids Godot's
		# "leaked instances" warnings when the window is closed.
		stop()
		for v in _voices:
			v.stop()
		await get_tree().create_timer(0.1).timeout
		get_tree().quit()


func _update_music() -> void:
	if music_on and not playing:
		play()
	elif not music_on:
		stop()


func _play_sfx(sound: String) -> void:
	if not _streams.has(sound):
		push_warning("Unknown sound: " + sound)
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = _streams[sound]
	p.play()
