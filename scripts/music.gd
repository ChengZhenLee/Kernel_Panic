extends Node
## Autoload: background music. A looping title theme on the menu screens, a shuffled playlist of the four
## gameplay tracks during a run, and a victory / defeat sting on the result screen. Files that are missing
## are skipped, so the game still runs without them. Volume comes from Global.music_volume (the MUSIC slider).

const DIR := "res://assets/audio/music/"
const TITLE := "music_title"
const BOSSES := ["music_boss_v2_glitch", "music_boss_v2_hellgate", "music_boss_v2_overdrive", "music_boss_v2_phrygian"]
const GAMEPLAY := ["music_gameplay", "music_gameplay_b", "music_gameplay_c", "music_gameplay_d"]

var bus := -1
var player: AudioStreamPlayer
var sting_player: AudioStreamPlayer
var streams := {}
var mode := ""                  # "", "title", "gameplay", "sting"
var run_track := ""
var boss_track := ""
var current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.add_bus()
	bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "Music")
	AudioServer.set_bus_send(bus, "Master")
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.finished.connect(_on_finished)
	add_child(player)
	sting_player = AudioStreamPlayer.new()
	sting_player.bus = "Music"
	add_child(sting_player)
	apply_volume()


func apply_volume() -> void:
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(Global.music_volume * Global.music_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, Global.music_volume <= 0.001)


func _stream(track: String) -> AudioStream:
	if not streams.has(track):
		streams[track] = null
		for dir in [DIR, "res://assets/audio/"]:   # new tracks may sit in assets/audio or in its music folder
			if ResourceLoader.exists(dir + track + ".wav"):
				streams[track] = load(dir + track + ".wav")
				break
	return streams[track]


func _start(track: String) -> void:
	var s := _stream(track)
	current = track
	if s == null:
		player.stop()
		return
	player.stream = s
	player.play()


func play_title() -> void:
	if mode == "title" and player.playing:
		return
	mode = "title"
	sting_player.stop()
	_start(TITLE)


## One gameplay track per run, picked at random (never the same one twice in a row) and looped until the run ends.
func play_gameplay() -> void:
	mode = "gameplay"
	sting_player.stop()
	var pool: Array = GAMEPLAY.filter(func(t): return t != run_track)
	if pool.is_empty():
		pool = GAMEPLAY
	run_track = pool.pick_random()
	_start(run_track)


## The final boss fight's own track (one of the boss_v2 variants, looped); the run track keeps playing if none exist.
func play_boss() -> void:
	var have: Array = BOSSES.filter(func(t): return _stream(t) != null)
	if have.is_empty():
		return
	mode = "boss"
	sting_player.stop()
	boss_track = have.pick_random()
	_start(boss_track)


## Victory or defeat sting on the result screen; the run music stops for it.
func play_sting(won: bool) -> bool:
	mode = "sting"
	player.stop()
	var s := _stream("sting_victory" if won else "sting_defeat")
	if s == null:
		return false
	sting_player.stream = s
	sting_player.play()
	return true


func stop() -> void:
	mode = ""
	player.stop()
	sting_player.stop()


func _on_finished() -> void:
	match mode:
		"title": _start(TITLE)
		"gameplay": _start(run_track)
		"boss": _start(boss_track)
