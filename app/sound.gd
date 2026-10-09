class_name Sound
extends Node
## Sound effects and music. Session calls Sound.setup() at startup; after that, Sound.play(&"bite")
## works from anywhere and every Button plays a tap sound by itself. Effects are Kenney CC0 sounds
## (assets/audio/CREDITS.md). Music tracks are optional files in assets/audio/music/ (<track>.ogg)
## and stay silent until they exist. The volume sliders are saved per device in settings.cfg.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 8
const MUSIC_DB := -10.0
const FADE_SECONDS := 1.0
## Name -> volume in dB. Files are levelled to the same loudness by tools/prepare_sfx.py, so these
## set how loud each sound is relative to the others. Variants are found by file name:
## <name>.ogg, or <name>_1.ogg, <name>_2.ogg, ... (one is picked at random each time).
const SOUNDS := {
	&"tap": -9.0,
	&"error": -9.0,
	&"card_open": -6.0,
	&"card_pick": -6.0,
	&"card_flip": -6.0,
	&"swap": -6.0,
	&"clutch_open": -6.0,
	&"bite": 0.0,
	&"charge": 0.0,
	&"brace": -3.0,
	&"block": 0.0,
	&"interrupted": -5.0,
	&"ko": 0.0,
	&"meteor": 0.0,
	&"victory": -1.0,
	&"defeat": -1.0,
	&"egg_crack": -3.0,
	&"egg_burst": 0.0,
	&"glow": -5.0,
	&"reveal_rare": -1.0,
	&"reveal_epic": -1.0,
	&"new_dino": -3.0,
	&"shiny": -5.0,
	&"amber": -5.0,
}
const MAX_VARIANTS := 9

static var _node: Sound

## Volume sliders, 0 to 1 (0 mutes).
var _sfx_volume := 1.0
var _music_volume := 1.0
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
## Pauses (or resumes) everything playing, e.g. while the app is in the background.
static func pause_all(paused: bool) -> void:
	if _node:
		for player in _node._music_players + _node._voices:
			player.stream_paused = paused


static func music(track: StringName) -> void:
	if _node:
		_node._set_music(track)


static func sfx_volume() -> float:
	return _node._sfx_volume if _node else 1.0


static func music_volume() -> float:
	return _node._music_volume if _node else 1.0


static func set_sfx_volume(volume: float) -> void:
	if _node:
		_node._sfx_volume = clampf(volume, 0.0, 1.0)
		_node._apply_settings()


static func set_music_volume(volume: float) -> void:
	if _node:
		_node._music_volume = clampf(volume, 0.0, 1.0)
		_node._apply_settings()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Music plus a few overlapping hits can add up past full scale; a limiter on the master bus
	# catches those peaks instead of letting them crackle on phone speakers.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)
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
		_sfx_volume = float(config.get_value("audio", "sfx_volume", 1.0))
		_music_volume = float(config.get_value("audio", "music_volume", 1.0))
		# Settings saved before the sliders existed had on/off switches.
		if not config.get_value("audio", "sfx", true):
			_sfx_volume = 0.0
		if not config.get_value("audio", "music", true):
			_music_volume = 0.0
	_apply_settings(false)
	get_tree().node_added.connect(_on_node_added)
	if _pending_track != &"":
		_set_music(_pending_track)


func _apply_settings(save := true) -> void:
	for pair in [[&"SFX", _sfx_volume], [&"Music", _music_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		var volume: float = pair[1]
		AudioServer.set_bus_mute(bus, volume <= 0.0)
		# Squared, so the slider feels even: half way is about a quarter of the loudness.
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume * volume, 0.0001)))
	if save:
		var config := ConfigFile.new()
		config.set_value("audio", "sfx_volume", _sfx_volume)
		config.set_value("audio", "music_volume", _music_volume)
		config.save(SETTINGS_PATH)


func _play(sound: StringName, pitch: float) -> void:
	var variants := _variants(sound)
	if variants.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = variants.pick_random()
	voice.volume_db = SOUNDS[sound]
	# A little random pitch so repeated hits don't sound copy-pasted.
	voice.pitch_scale = pitch * randf_range(0.96, 1.04)
	voice.play()


func _variants(sound: StringName) -> Array:
	if not _streams.has(sound):
		var loaded := []
		if not SOUNDS.has(sound):
			push_warning("Unknown sound: %s" % sound)
		elif ResourceLoader.exists(SFX_DIR + String(sound) + ".ogg"):
			loaded.append(load(SFX_DIR + String(sound) + ".ogg"))
		else:
			for i in range(1, MAX_VARIANTS + 1):
				var path := SFX_DIR + "%s_%d.ogg" % [sound, i]
				if ResourceLoader.exists(path):
					loaded.append(load(path))
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
