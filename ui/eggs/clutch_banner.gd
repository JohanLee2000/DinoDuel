class_name ClutchBanner
extends Control
## The picture at the top of the Eggs tab: Jo's clutch painting with how many clutches are waiting.
## With clutches it glows, embers drift up from the amber, and tapping it hatches one; without any
## it dims and says how to get more.

signal hatch_pressed

const ART := "res://assets/eggs/clutch_banner.webp"
const HEIGHT := 300.0
## Where the nest sits in the painting (fraction of width/height), for the glow and embers.
const NEST := Vector2(0.5, 0.62)

var clutches := 0
var rare_clutches := 0
var _image: TextureRect
var _glow: TextureRect
var _press_position := Vector2.INF


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	# PASS so a drag that starts here still scrolls the tab.
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Rounded corners: the panel's shape masks everything inside it.
	var frame := Panel.new()
	var shape := StyleBoxFlat.new()
	shape.bg_color = Palette.PANEL
	shape.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", shape)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_image = TextureRect.new()
	_image.texture = load(ART)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_image)
	_image.resized.connect(func() -> void: _image.pivot_offset = _image.size * NEST)
	var drift := _image.create_tween().set_loops()
	drift.tween_property(_image, "scale", Vector2(1.07, 1.07), 9.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(_image, "scale", Vector2.ONE, 9.0).set_trans(Tween.TRANS_SINE)

	_glow = TextureRect.new()
	var radial := GradientTexture2D.new()
	var warm := Gradient.new()
	warm.set_color(0, Color(1.0, 0.72, 0.3, 0.7))
	warm.set_color(1, Color(1.0, 0.72, 0.3, 0.0))
	radial.gradient = warm
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(0.5, 0.0)
	_glow.texture = radial
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	frame.add_child(_glow)

	frame.add_child(_embers())

	# Dark fade at the bottom for the words.
	var shade := TextureRect.new()
	var down := GradientTexture2D.new()
	var dark := Gradient.new()
	dark.set_color(0, Color(Palette.BACKGROUND, 0.0))
	dark.set_color(1, Color(Palette.BACKGROUND, 0.9))
	down.gradient = dark
	down.fill_from = Vector2(0, 0)
	down.fill_to = Vector2(0, 1)
	shade.texture = down
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -130
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)

	var words := UiKit.vbox(0)
	words.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	words.offset_left = 18
	words.offset_right = -18
	words.offset_top = -96
	words.offset_bottom = -12
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total := clutches + rare_clutches
	var has_clutches := total > 0
	var headline := UiKit.title("%d clutch%s ready!" % [total, "" if total == 1 else "es"] if has_clutches
			else "No clutches right now", 36, Palette.HIGHLIGHT if has_clutches else Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	headline.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	headline.add_theme_constant_override("shadow_offset_y", 3)
	words.add_child(headline)
	var hint := "Win a battle or check in daily for a free clutch."
	if has_clutches:
		hint = "Tap to hatch" if rare_clutches == 0 else "Tap to hatch  ·  %d Rare" % rare_clutches
	words.add_child(UiKit.label(hint, 24, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	frame.add_child(words)

	if has_clutches:
		var pulse := _glow.create_tween().set_loops()
		pulse.tween_property(_glow, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(_glow, "modulate:a", 0.45, 1.2).set_trans(Tween.TRANS_SINE)
	else:
		_image.modulate = Color(0.55, 0.55, 0.6)
		_glow.visible = false
	resized.connect(_place_glow)


func _place_glow() -> void:
	var glow_size := Vector2(size.x * 0.75, size.y * 1.1)
	_glow.size = glow_size
	_glow.position = size * NEST - glow_size / 2


## Embers floating up out of the amber.
func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.amount = 18 if clutches + rare_clutches > 0 else 6
	embers.lifetime = 3.0
	embers.preprocess = 3.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(170, 20)
	embers.direction = Vector2.UP
	embers.spread = 30.0
	embers.initial_velocity_min = 25.0
	embers.initial_velocity_max = 60.0
	embers.gravity = Vector2(0, -10)
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.3, 0.0))
	fade.add_point(0.25, Color(1.0, 0.75, 0.3, 0.9))
	fade.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
	embers.color_ramp = fade
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = add
	resized.connect(func() -> void: embers.position = size * NEST + Vector2(0, size.y * 0.12))
	return embers


## A tap (not a scroll) hatches a clutch.
func _gui_input(event: InputEvent) -> void:
	if clutches + rare_clutches <= 0:
		return
	if event is InputEventMouseMotion and _press_position != Vector2.INF:
		if _press_position.distance_to(event.global_position) > DinoCard.TAP_SLOP:
			_press_position = Vector2.INF
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_position = event.global_position
	elif _press_position != Vector2.INF:
		_press_position = Vector2.INF
		pivot_offset = size / 2
		var press := create_tween()
		press.tween_property(self, "scale", Vector2(0.97, 0.97), 0.06)
		press.tween_property(self, "scale", Vector2.ONE, 0.1)
		press.tween_callback(hatch_pressed.emit)
