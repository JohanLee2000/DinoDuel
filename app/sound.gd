class_name Sound
extends Node
## Sound effects and music. Session calls Sound.setup() at startup; after that, Sound.play(&"bite")
## works from anywhere and every Button plays a tap sound by itself. Effects are Kenney CC0 sounds
## (assets/audio/CREDITS.md). Music tracks are optional files in assets/audio/music/ (<track>.ogg)
## and stay silent until they exist. The on/off switches are saved per device in settings.cfg.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 8
const MUSIC_DB := -10.0
const FADE_SECONDS := 1.0
## Name -> [variants, volume in dB]. Files are <name>.ogg, or <name>_1.ogg, <name>_2.ogg, ...
## Volumes even out the source files' loudness (measured, not by ear: adjust after listening).
const SOUNDS := {
	&"tap": [2, -3.0],
	&"back": [1, -4.0],
	&"error": [1, -7.0],
	&"toggle": [1, -10.0],
	&"card_open": [1, -2.0],
	&"card_pick": [1, -2.0],
	&"card_flip": [1, -1.5],
	&"swap": [2, 5.0],
	&"clutch_open": [1, -2.0],
	&"bite": [3, -2.5],
	&"charge": [3, -1.0],
	&"block": [2, 0.0],
	&"interrupted": [1, -1.0],
	&"ko": [1, -4.5],
	&"meteor": [2, -2.0],
	&"victory": [1, 0.0],
	&"defeat": [1, 0.0],
	&"egg_crack": [3, 0.0],
	&"egg_burst": [1, -2.0],
	&"glow": [1, 0.0],
	&"reveal_rare": [1, 0.0],
	&"reveal_epic": [1, 0.0],
	&"new_dino": [1, -5.0],
	&"shiny": [1, 2.0],
	&"amber": [1, 1.0],
}

static var _node: Sound

var _sfx_on := true
var _music_on := true
var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_track := &""
## A track asked for before the players existed (the node joins the tree a frame after setup).
var _pending_track := &""


## Creates the sound player once. Safe to call again.
static func setup(tree: SceneTree) -> void:
	if _node:
		return
	_node = Sound.new()
	_node.name = "Sound"
	tree.root.add_child.call_deferred(_node)


## Plays a sound effect by name. `pitch` shifts it (e.g. higher for rarer eggs).
static func play(sound: StringName, pitch := 1.0) -> void:
	if _node and _node.is_inside_tree():
		_node._play(sound, pitch)


## Crossfades to a looping music track, or to silence if that track's file doesn't exist yet.
static func music(track: StringName) -> void:
	if _node:
		_node._set_music(track)


static func sfx_on() -> bool:
	return _node == null or _node._sfx_on


static func music_on() -> bool:
	return _node == null or _node._music_on


static func set_sfx_on(on: bool) -> void:
	if _node:
		_node._sfx_on = on
		_node._apply_settings()


static func set_music_on(on: bool) -> void:
	if _node:
		_node._music_on = on
		_node._apply_settings()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_sfx_on = bool(config.get_value("audio", "sfx", true))
		_music_on = bool(config.get_value("audio", "music", true))
	_apply_settings(false)
	get_tree().node_added.connect(_on_node_added)
	if _pending_track != &"":
		_set_music(_pending_track)


func _apply_settings(save := true) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), not _sfx_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), not _music_on)
	if save:
		var config := ConfigFile.new()
		config.set_value("audio", "sfx", _sfx_on)
		config.set_value("audio", "music", _music_on)
		config.save(SETTINGS_PATH)


func _play(sound: StringName, pitch: float) -> void:
	var variants := _variants(sound)
	if variants.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = variants.pick_random()
	voice.volume_db = SOUNDS[sound][1]
	# A little random pitch so repeated hits don't sound copy-pasted.
	voice.pitch_scale = pitch * randf_range(0.96, 1.04)
	voice.play()


func _variants(sound: StringName) -> Array:
	if not _streams.has(sound):
		var loaded := []
		if SOUNDS.has(sound):
			var count: int = SOUNDS[sound][0]
			for i in count:
				var path := SFX_DIR + (String(sound) if count == 1 else "%s_%d" % [sound, i + 1]) + ".ogg"
				if ResourceLoader.exists(path):
					loaded.append(load(path))
		else:
			push_warning("Unknown sound: %s" % sound)
		_streams[sound] = loaded
	return _streams[sound]


func _set_music(track: StringName) -> void:
	if _music_players.is_empty():
		_pending_track = track
		return
	if track == _music_track:
		return
	_music_track = track
	var outgoing := _music_players[0]
	var incoming := _music_players[1]
	_music_players.reverse()
	var path := MUSIC_DIR + String(track) + ".ogg"
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", MUSIC_DB, FADE_SECONDS)
	if outgoing.playing:
		var fade := create_tween()
		fade.tween_property(outgoing, "volume_db", -60.0, FADE_SECONDS)
		fade.tween_callback(outgoing.stop)


## Every button taps when pressed, so screens don't each need to remember to.
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	_play(&"tap", 1.0)
