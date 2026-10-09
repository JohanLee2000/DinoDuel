class_name EggView
extends Control
## A fossil egg. Uses Jo's painted frames in assets/eggs/ (made by tools/prepare_eggs.py) and falls
## back to a drawn egg without them. Waiting, it wobbles now and then. First tap: it shakes, cracks
## and light glows out of the cracks in its rarity color. Second tap: it shakes harder and harder
## (longer for rarer eggs), cracks all over and bursts.

signal cracked
## Emitted at the moment the shell breaks; the hatch screen takes over from here.
signal burst

enum Stage { WHOLE, CRACKED, BURSTING, GONE }

const SHELL := Color("f3e7cc")
const SHELL_SHADE := Color("dccaa2")
const SPECKLE := Color("a88c62")
const CRACK := Color("3e2f1c")
const ART_DIR := "res://assets/eggs/"
## Painted frames: intact, first crack, about to burst. Crack frames come with a light layer.
const FRAMES: Array[String] = ["egg_whole", "egg_crack_1", "egg_crack_2"]

var rarity := DinoDef.Rarity.COMMON
var stage := Stage.WHOLE
var _glow := 0.0
var _cracks := 0
var _speckles: Array[Vector3] = []
var _pulse: Tween
var _idle: Tween
var _art := false
var _shell: TextureRect
var _light: TextureRect
var _core: TextureRect
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(300, 390)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	for i in 18:
		_speckles.append(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.7, 0.75), rng.randf_range(0.015, 0.03)))


func _ready() -> void:
	pivot_offset = size * Vector2(0.5, 0.85)
	_art = ResourceLoader.exists(ART_DIR + FRAMES[0] + ".webp")
	if _art:
		_shell = _layer(false)
		# The light is added on top of the shell: a soft glow in the rarity color, plus a whiter core.
		_light = _layer(true)
		_core = _layer(true)
		_show_frame(_cracks)
	if stage == Stage.WHOLE and not Session.autoplay:
		_start_idle()


func _layer(additive: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rect.material = material
		rect.modulate.a = 0.0
	add_child(rect)
	return rect


func _show_frame(index: int) -> void:
	if not _art:
		return
	_shell.texture = load(ART_DIR + FRAMES[index] + ".webp")
	var has_light := index > 0
	_light.visible = has_light
	_core.visible = has_light
	if has_light:
		var light: Texture2D = load(ART_DIR + FRAMES[index] + "_light.webp")
		_light.texture = light
		_core.texture = light
	_apply_light()


## The light layers follow the glow: colored glow in the rarity color, a paler core on top.
func _apply_light() -> void:
	if not _art:
		return
	var color := Palette.RARITY_COLORS[rarity]
	var strength := clampf(_glow, 0.0, 1.6)
	var flicker := 1.0 + 0.08 * sin(_time * 9.0) + 0.05 * sin(_time * 23.0) if stage == Stage.CRACKED else 1.0
	_light.modulate = Color(color.r, color.g, color.b, clampf(strength * 0.9 * flicker, 0.0, 1.0))
	_core.modulate = Color(1, 1, 1, clampf((strength - 0.4) * 0.35 * flicker, 0.0, 0.6))


func _process(delta: float) -> void:
	if stage == Stage.CRACKED:
		_time += delta
		_apply_light()


## While waiting to be tapped: a little wobble every couple of seconds, like something's moving inside.
func _start_idle() -> void:
	_idle = create_tween().set_loops()
	_idle.tween_interval(1.4)
	for angle in [0.06, -0.05, 0.03, 0.0]:
		_idle.tween_property(self, "rotation", angle, 0.09).set_trans(Tween.TRANS_SINE)


func _stop_idle() -> void:
	if _idle:
		_idle.kill()
		_idle = null
	rotation = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


## Moves to the next stage, the same as a tap.
func advance() -> void:
	match stage:
		Stage.WHOLE:
			_crack()
		Stage.CRACKED:
			_burst()


func _crack() -> void:
	_stop_idle()
	stage = Stage.CRACKED
	_cracks = 1
	_show_frame(1)
	Sound.play(&"egg_crack")
	Sound.play(&"glow", 0.85 + rarity * 0.12)
	var tween := create_tween()
	for angle in [0.22, -0.2, 0.16, -0.12, 0.07, 0.0]:
		tween.tween_property(self, "rotation", angle, 0.06)
	tween.parallel().tween_method(_set_glow, 0.0, 0.6 + rarity * 0.2, 0.4)
	queue_redraw()
	cracked.emit()
	# Rarer eggs pulse while they wait.
	if rarity >= DinoDef.Rarity.SUPER_RARE:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale", Vector2(1.05, 1.05), 0.45 - rarity * 0.05)
		_pulse.tween_property(self, "scale", Vector2.ONE, 0.45 - rarity * 0.05)


## Shakes harder and harder, longer for rarer eggs, then bursts.
func _burst() -> void:
	stage = Stage.BURSTING
	if _pulse:
		_pulse.kill()
	scale = Vector2.ONE
	var shakes := 8 + rarity * 4
	var tween := create_tween()
	for i in shakes:
		var strength := 0.08 + 0.3 * float(i) / shakes
		var hop := -size.y * 0.04 * float(i) / shakes
		tween.tween_property(self, "rotation", strength * (1 if i % 2 == 0 else -1), 0.045)
		tween.parallel().tween_property(self, "position:y", position.y + (hop if i % 2 == 0 else 0.0), 0.045)
		if i == shakes / 2:
			tween.tween_callback(func() -> void:
				_cracks = 2
				_show_frame(2)
				Sound.play(&"egg_crack", 0.85)
				queue_redraw())
	tween.parallel().tween_method(_set_glow, _glow, 1.4 + rarity * 0.25, 0.045 * shakes)
	tween.tween_property(self, "rotation", 0.0, 0.04)
	await tween.finished
	stage = Stage.GONE
	visible = false
	Sound.play(&"egg_burst")
	burst.emit()


## Shows the egg cracked and glowing without any tap animation (the story intro uses this).
func show_glowing(glow: float) -> void:
	_cracks = 1
	_show_frame(1)
	_set_glow(glow)


func _set_glow(value: float) -> void:
	_glow = value
	_apply_light()
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.55)
	var rx := size.x * 0.4
	var ry := size.y * 0.42
	if _glow > 0.0:
		var color := Palette.RARITY_COLORS[rarity]
		for i in range(8, 0, -1):
			draw_circle(center, ry * (0.75 + i * 0.1 * _glow), Color(color, 0.06 * _glow), true, -1.0, true)

	if _art:
		return
	var points := PackedVector2Array()
	for i in 64:
		var t := TAU * i / 64.0
		# Wider at the bottom than the top, like a real egg.
		var x := rx * cos(t) * (1.0 + 0.12 * sin(t))
		points.append(center + Vector2(x, ry * sin(t)))
	draw_colored_polygon(points, SHELL)
	# Shading on the right side.
	var shade := PackedVector2Array()
	for i in 33:
		var t := -PI / 2 + PI * i / 32.0
		shade.append(center + Vector2(rx * cos(t) * (1.0 + 0.12 * sin(t)), ry * sin(t)))
	# Inner edge of the crescent; skips the tips so the outline never crosses itself.
	for i in range(31, 0, -1):
		var t := -PI / 2 + PI * i / 32.0
		shade.append(center + Vector2(rx * 0.55 * cos(t) * (1.0 + 0.12 * sin(t)), ry * sin(t)))
	draw_colored_polygon(shade, Color(SHELL_SHADE, 0.6))
	for s in _speckles:
		draw_circle(center + Vector2(s.x * rx, s.y * ry), s.z * size.x, SPECKLE, true, -1.0, true)
	draw_circle(center + Vector2(-rx * 0.35, -ry * 0.45), rx * 0.22, Color(1, 1, 1, 0.22), true, -1.0, true)
	points.append(points[0])
	draw_polyline(points, Color("6e5c3e", 0.7), maxf(1.5, size.x * 0.008), true)

	if _cracks >= 1:
		_draw_crack(center, rx, -ry * 0.08, 6)
	if _cracks >= 2:
		_draw_crack(center, rx * 0.8, -ry * 0.42, 5)
		_draw_crack(center, rx * 0.85, ry * 0.3, 5)


func _draw_crack(center: Vector2, half_width: float, y: float, steps: int) -> void:
	var crack := PackedVector2Array()
	for i in steps + 1:
		var x := lerpf(-half_width, half_width, float(i) / steps)
		crack.append(center + Vector2(x, y + (size.y * 0.035 if i % 2 == 0 else -size.y * 0.035)))
	draw_polyline(crack, CRACK, maxf(2.0, size.x * 0.012), true)
