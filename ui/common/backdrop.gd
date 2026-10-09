class_name Backdrop
extends ColorRect
## Full-screen background: deep navy with a soft texture and vignette, like the concept sheet.
##
## The texture is a noise shader (card_surface.gdshader) that never changes, so it's drawn once
## into an image and reused by every screen: running it live cost a full-screen noise pass every
## frame (2026-10-09 phone measurement). Until the image is ready the plain base color shows.

const BASE := Color("13254a")
const DARK := Color("050a16")

static var _baked: ImageTexture
static var _baking := false

var _image: TextureRect


func _ready() -> void:
	color = BASE.lerp(DARK, 0.45)
	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	if _baked:
		_image.texture = _baked
	else:
		_bake.call_deferred()


func _bake() -> void:
	if _baking:
		# Another screen is already baking it; pick it up when done.
		while _baked == null and is_inside_tree():
			await get_tree().process_frame
		if is_inside_tree():
			_image.texture = _baked
		return
	_baking = true
	var bake_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	var viewport := SubViewport.new()
	viewport.size = bake_size
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var surface := ColorRect.new()
	surface.size = Vector2(bake_size)
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/common/card_surface.gdshader")
	material.set_shader_parameter("base_color", BASE)
	material.set_shader_parameter("dark_color", DARK)
	material.set_shader_parameter("grain", 0.45)
	material.set_shader_parameter("noise_scale", 0.006)
	material.set_shader_parameter("vignette", 1.1)
	material.set_shader_parameter("radius", 0.0)
	material.set_shader_parameter("rect_size", Vector2(bake_size))
	surface.material = material
	viewport.add_child(surface)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	_baked = ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	_baking = false
	if is_inside_tree():
		_image.texture = _baked
