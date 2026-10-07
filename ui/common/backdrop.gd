class_name Backdrop
extends ColorRect
## Full-screen background: deep navy with a soft texture and vignette, like the concept sheet.


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/common/card_surface.gdshader")
	material.set_shader_parameter("base_color", Color("13254a"))
	material.set_shader_parameter("dark_color", Color("050a16"))
	material.set_shader_parameter("grain", 0.45)
	material.set_shader_parameter("noise_scale", 0.006)
	material.set_shader_parameter("vignette", 1.1)
	material.set_shader_parameter("radius", 0.0)
	material.set_shader_parameter("rect_size", size)
	self.material = material
	resized.connect(func() -> void: material.set_shader_parameter("rect_size", size))
