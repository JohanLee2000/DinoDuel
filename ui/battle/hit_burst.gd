class_name HitBurst
extends Control
## A quick impact flash for battles: a bright core, an expanding ring and a spray of sparks, drawn
## additively so it glows over the cards. Plays once and frees itself.

const DURATION := 0.38

var color := Color.WHITE
var radius := 90.0
var sparks := 10
var _t := 0.0:
	set(value):
		_t = value
		queue_redraw()
var _angles: Array[float] = []


## Adds a burst centered on `point` (global position) and plays it.
static func spawn(parent: Control, point: Vector2, burst_color: Color, burst_radius := 90.0,
		spark_count := 10) -> HitBurst:
	var burst := HitBurst.new()
	burst.color = burst_color
	burst.radius = burst_radius
	burst.sparks = spark_count
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	burst.material = add
	parent.add_child(burst)
	burst.global_position = point
	return burst


func _ready() -> void:
	for i in sparks:
		_angles.append(TAU * i / sparks + randf_range(-0.25, 0.25))
	var tween := create_tween()
	tween.tween_property(self, "_t", 1.0, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var fade := 1.0 - _t
	# Core flash: big and bright for the first moment, then gone.
	draw_circle(Vector2.ZERO, radius * (0.35 + 0.4 * _t), Color(color, 0.55 * fade * fade))
	draw_circle(Vector2.ZERO, radius * 0.22 * (1.0 - _t * 0.5), Color(1, 1, 1, 0.8 * fade * fade))
	# Shock ring.
	draw_arc(Vector2.ZERO, radius * (0.4 + 0.75 * _t), 0.0, TAU, 40, Color(color, 0.8 * fade),
			maxf(2.0, radius * 0.09 * fade), true)
	# Sparks flying outward.
	for angle in _angles:
		var dir := Vector2.from_angle(angle)
		var start := dir * radius * (0.3 + 0.9 * _t)
		var end := dir * radius * (0.5 + 1.25 * _t)
		draw_line(start, end, Color(color.lightened(0.4), fade), maxf(1.5, radius * 0.05 * fade), true)
