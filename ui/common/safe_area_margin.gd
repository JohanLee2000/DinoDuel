class_name SafeAreaMargin
extends MarginContainer
## Keeps content clear of camera notches and rounded corners on phones.

@export var base_margin := 20


func _ready() -> void:
	_apply()
	get_viewport().size_changed.connect(_apply)


func _apply() -> void:
	var insets := [0.0, 0.0, 0.0, 0.0] # left, top, right, bottom in canvas units
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		var canvas := get_viewport_rect().size
		if screen.x > 0 and screen.y > 0:
			var to_canvas := canvas / screen
			insets = [
				safe.position.x * to_canvas.x,
				safe.position.y * to_canvas.y,
				(screen.x - safe.end.x) * to_canvas.x,
				(screen.y - safe.end.y) * to_canvas.y,
			]
	add_theme_constant_override("margin_left", base_margin + int(insets[0]))
	add_theme_constant_override("margin_top", base_margin + int(insets[1]))
	add_theme_constant_override("margin_right", base_margin + int(insets[2]))
	add_theme_constant_override("margin_bottom", base_margin + int(insets[3]))
