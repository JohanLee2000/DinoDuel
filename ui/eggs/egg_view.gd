class_name EggView
extends Control
## A fossil egg drawn in code (placeholder until there's real art).
## First tap: it shakes, cracks and glows in its rarity color. Second tap: it shakes harder and
## harder (longer for rarer eggs) and then bursts.

signal cracked
## Emitted at the moment the shell breaks; the hatch screen takes over from here.
signal burst

enum Stage { WHOLE, CRACKED, BURSTING, GONE }

const SHELL := Color("f3e7cc")
const SHELL_SHADE := Color("dccaa2")
const SPECKLE := Color("a88c62")
const CRACK := Color("3e2f1c")

var rarity := DinoDef.Rarity.COMMON
var stage := Stage.WHOLE
var _glow := 0.0
var _cracks := 0
var _speckles: Array[Vector3] = []
var _pulse: Tween


func _init() -> void:
	custom_minimum_size = Vector2(300, 390)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	for i in 18:
		_speckles.append(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.7, 0.75), rng.randf_range(0.015, 0.03)))


func _ready() -> void:
	pivot_offset = size * Vector2(0.5, 0.85)


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
	stage = Stage.CRACKED
	_cracks = 1
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
	_set_glow(glow)


func _set_glow(value: float) -> void:
	_glow = value
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.55)
	var rx := size.x * 0.4
	var ry := size.y * 0.42
	if _glow > 0.0:
		var color := Palette.RARITY_COLORS[rarity]
		for i in range(8, 0, -1):
			draw_circle(center, ry * (0.75 + i * 0.1 * _glow), Color(color, 0.06 * _glow), true, -1.0, true)

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
