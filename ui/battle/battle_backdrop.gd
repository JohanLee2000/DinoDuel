class_name BattleBackdrop
extends Control
## Battle background built from each side's active dino type (assets/battle/<type>.webp): the
## rival's scene on top, the player's below, blended in the middle and drifting slowly. When an
## active dino of another type comes in, the new pairing crossfades in over the old one.

const SHADER := preload("res://ui/battle/battle_backdrop.gdshader")
const TEXTURES := ["res://assets/battle/land.webp", "res://assets/battle/sky.webp", "res://assets/battle/sea.webp"]
const FADE_SECONDS := 0.6

var _player_type := -1
var _rival_type := -1
var _layer: ColorRect
var _rival_focus := Vector2(0.5, 0.2)
var _player_focus := Vector2(0.5, 0.75)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		for child in get_children():
			_update_layer(child))


## Shows the scenes for these dino types (DinoDef.DinoType), crossfading if they changed.
func set_types(player_type: int, rival_type: int) -> void:
	if player_type == _player_type and rival_type == _rival_type:
		return
	var first := _layer == null
	_player_type = player_type
	_rival_type = rival_type
	var layer := ColorRect.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("rival_tex", load(TEXTURES[rival_type]))
	material.set_shader_parameter("player_tex", load(TEXTURES[player_type]))
	layer.material = material
	add_child(layer)
	var old := _layer
	_layer = layer
	_update_layer(layer)
	if first:
		return
	layer.modulate.a = 0.0
	var fade := layer.create_tween()
	fade.tween_property(layer, "modulate:a", 1.0, FADE_SECONDS)
	fade.tween_callback(old.queue_free)


## Where the active cards sit (global rects), for the soft shadows behind them.
func set_focus(rival_card: Rect2, player_card: Rect2) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_rival_focus = (rival_card.get_center() - global_position) / size
	_player_focus = (player_card.get_center() - global_position) / size
	for child in get_children():
		_update_layer(child)


func _update_layer(layer: ColorRect) -> void:
	if layer == null or size.y <= 0:
		return
	var material := layer.material as ShaderMaterial
	material.set_shader_parameter("rect_aspect", size.x / size.y)
	material.set_shader_parameter("rival_focus", _rival_focus)
	material.set_shader_parameter("player_focus", _player_focus)
