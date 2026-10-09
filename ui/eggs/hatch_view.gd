class_name HatchView
extends Control
## Full-screen clutch opening, one egg at a time: tap to crack, tap again to hatch. The egg
## shakes (longer for rarer eggs), bursts into shell pieces, and the card pops up big over
## rotating light rays in the rarity color. Epic and Legendary hatches also shake the screen
## and flash. After the last egg, a summary shows the whole clutch.
##
## Results were already decided and saved before this opens, so closing the app halfway can't
## reroll anything.

signal finished

const CARD_WIDTH := 440.0
const BACKDROP := "res://assets/eggs/hatch_background.webp"
## Where the stone slab's top is in the backdrop painting (fraction of its height); the egg sits there.
const SLAB_Y := 0.74
const SHARD_COUNT := 8

var _results: Array[HatchResult] = []
var _title_text := "Your clutch is hatching!"
var _index := 0
var _waiting_for_tap := false
var _content: Control
var _title: Label
var _hint: Label
var _skip: Button
var _stage_nodes: Array[Node] = []
var _backdrop: TextureRect


static func create(results: Array[HatchResult], title := "") -> HatchView:
	var view := HatchView.new()
	view._results = results
	if title != "":
		view._title_text = title
	return view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := UiKit.modal_layer()
	layer.color = Palette.BACKGROUND
	layer.gui_input.connect(_on_background_input)
	add_child(layer)
	if ResourceLoader.exists(BACKDROP):
		_backdrop = TextureRect.new()
		_backdrop.texture = load(BACKDROP)
		_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backdrop.modulate = Color(0.85, 0.85, 0.85)
		add_child(_backdrop)
		# Slow drift in, and warm dust floating in the lantern light.
		_backdrop.resized.connect(func() -> void: _backdrop.pivot_offset = _backdrop.size / 2)
		var drift := _backdrop.create_tween().set_loops()
		drift.tween_property(_backdrop, "scale", Vector2(1.06, 1.06), 12.0).set_trans(Tween.TRANS_SINE)
		drift.tween_property(_backdrop, "scale", Vector2.ONE, 12.0).set_trans(Tween.TRANS_SINE)
		add_child(_dust())
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_title = UiKit.title("", 40, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 70
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_title)
	_hint = UiKit.label("", 28, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -200
	_hint.offset_bottom = -150
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_hint)
	# Outlined so they read over the painted backdrop.
	for label in [_title, _hint]:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_color", Palette.TEXT)
	_skip = UiKit.button("Skip to results", UiKit.BUTTON_GRAY, 76, 24)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_skip.offset_left = -170
	_skip.offset_right = 170
	_skip.offset_top = -120
	_skip.offset_bottom = -44
	_skip.pressed.connect(_show_summary)
	_content.add_child(_skip)
	if _results.size() == 1:
		_skip.visible = false
	_show_egg()


func _screen() -> Vector2:
	return get_viewport_rect().size


func _clear_stage() -> void:
	for node in _stage_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_stage_nodes.clear()


func _show_egg() -> void:
	_clear_stage()
	var result := _results[_index]
	_title.text = _title_text if _results.size() == 1 else "Egg %d of %d" % [_index + 1, _results.size()]
	_hint.text = "Tap the egg to crack it!"
	_dim_backdrop(0.85)
	var egg := EggView.new()
	egg.rarity = result.dino.rarity
	var screen := _screen()
	var egg_height := clampf(screen.y * 0.3, 360.0, 500.0)
	egg.size = Vector2(egg_height * 0.785, egg_height)
	egg.position = Vector2((screen.x - egg.size.x) / 2, _slab_top() - egg.size.y * 0.97)
	_content.add_child(egg)
	_stage_nodes.append(egg)
	egg.scale = Vector2(0.2, 0.2)
	egg.create_tween().tween_property(egg, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	egg.cracked.connect(func() -> void: _hint.text = "Its glow shows how rare it is. Tap again!")
	egg.burst.connect(_reveal.bind(result, egg.position + egg.size * Vector2(0.5, 0.55)))
	if Session.autoplay:
		await get_tree().create_timer(0.6).timeout
		egg.advance()
		await get_tree().create_timer(0.9).timeout
		egg.advance()


func _reveal(result: HatchResult, egg_center: Vector2) -> void:
	var rarity := result.dino.rarity
	var color := Palette.RARITY_COLORS[rarity]
	var card_center := _screen() / 2 + Vector2(0, 10)

	var rays := LightBurst.new()
	rays.color = color
	rays.size = Vector2.ONE * 900
	rays.position = card_center - rays.size / 2
	rays.pivot_offset = rays.size / 2
	_content.add_child(rays)
	_content.move_child(rays, 0)
	_stage_nodes.append(rays)
	rays.scale = Vector2(0.1, 0.1)
	rays.create_tween().tween_property(rays, "scale", Vector2.ONE * (0.8 + rarity * 0.1), 0.4).set_trans(Tween.TRANS_BACK)

	_spawn_shells(egg_center, 10 + rarity * 3)
	_spawn_sparks(egg_center, color, 24 + rarity * 12)
	_dim_backdrop(0.5)
	if rarity >= DinoDef.Rarity.EPIC:
		_flash_and_shake(rarity)

	# The card pops up face down, then flips over.
	var card := DinoCard.create(result.dino, DinoCard.Mode.LARGE, null, result.shiny, CARD_WIDTH)
	card.inspect_on_hold = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flipper := Control.new()
	flipper.size = Vector2(card.width, card.card_height())
	flipper.pivot_offset = flipper.size / 2
	flipper.position = card_center - flipper.size / 2
	flipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := DinoCard.create_back(card.width)
	flipper.add_child(back)
	card.visible = false
	flipper.add_child(card)
	_content.add_child(flipper)
	_stage_nodes.append(flipper)
	flipper.scale = Vector2(0.05, 0.05)
	flipper.rotation = -0.3
	var pop := flipper.create_tween()
	pop.tween_property(flipper, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(flipper, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(flipper, "scale:x", 0.0, 0.14).set_delay(0.15)
	pop.tween_callback(func() -> void:
		back.visible = false
		card.visible = true
		Sound.play(&"card_flip"))
	pop.tween_property(flipper, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var rarity_label := UiKit.title("%s  %s!" % [result.dino.rarity_code(), result.dino.rarity_name()], 46, color,
			HORIZONTAL_ALIGNMENT_CENTER)
	rarity_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rarity_label.offset_top = flipper.position.y - 80
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rarity_label)
	_stage_nodes.append(rarity_label)
	_title.text = ""

	var caption := UiKit.title(_caption(result), 34, Palette.HIGHLIGHT if result.is_new or result.shiny \
			else Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	caption.offset_top = flipper.position.y + flipper.size.y + 18
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(caption)
	_stage_nodes.append(caption)

	_hint.text = "Tap to continue" if _index < _results.size() - 1 else "Tap to finish"
	rarity_label.modulate.a = 0.0
	caption.modulate.a = 0.0
	await pop.finished
	for label in [rarity_label, caption]:
		label.create_tween().tween_property(label, "modulate:a", 1.0, 0.2)
	_play_reveal_sounds(result)
	_add_share_button(result)
	_waiting_for_tap = true
	if Session.autoplay:
		await get_tree().create_timer(1.2).timeout
		_advance()


## "Share" in the top-right corner of each reveal (the title is hidden then, so it's free).
func _add_share_button(result: HatchResult) -> void:
	var share := UiKit.button("Share", UiKit.BUTTON_AMBER, 64, 26)
	share.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	share.offset_left = -190
	share.offset_right = -24
	share.offset_top = 56
	share.offset_bottom = 120
	share.pressed.connect(func() -> void:
		share.disabled = true
		share.text = "..."
		await ShareCard.share_dino(result.dino, result.shiny or result.upgraded_to_shiny, true)
		if is_instance_valid(share):
			share.disabled = false
			share.text = "Share")
	_content.add_child(share)
	_stage_nodes.append(share)
	share.modulate.a = 0.0
	share.create_tween().tween_property(share, "modulate:a", 1.0, 0.2)


func _play_reveal_sounds(result: HatchResult) -> void:
	var rarity := result.dino.rarity
	if rarity >= DinoDef.Rarity.EPIC:
		Sound.play(&"reveal_epic")
	elif rarity >= DinoDef.Rarity.RARE:
		Sound.play(&"reveal_rare")
	await get_tree().create_timer(0.35).timeout
	if result.shiny or result.upgraded_to_shiny:
		Sound.play(&"shiny")
	if result.is_new:
		Sound.play(&"new_dino")
	elif result.amber > 0:
		Sound.play(&"amber")


func _caption(result: HatchResult) -> String:
	var lines: Array[String] = []
	if result.shiny:
		lines.append("SHINY!")
	if result.is_new:
		lines.append("NEW!")
	elif result.upgraded_to_shiny:
		lines.append("Your copy is now Shiny")
	else:
		lines.append("Duplicate: +%d Amber" % result.amber)
	return "  ".join(lines)


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	if not _waiting_for_tap:
		return
	_waiting_for_tap = false
	_index += 1
	if _index < _results.size():
		_show_egg()
	elif _results.size() == 1:
		_finish()
	else:
		_show_summary()


func _show_summary() -> void:
	_waiting_for_tap = false
	_index = _results.size()
	_clear_stage()
	_skip.visible = false
	_title.text = "Your clutch"
	_hint.text = "Hold a card to see it up close."
	var row := UiKit.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	for result in _results:
		var slot := UiKit.vbox(8)
		var card := DinoCard.create(result.dino, DinoCard.Mode.FULL, null, result.shiny)
		slot.add_child(card)
		var caption := UiKit.label(_caption(result), 22, Palette.HIGHLIGHT if result.is_new or result.shiny \
				else Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		caption.custom_minimum_size = Vector2(card.size.x, 0)
		slot.add_child(caption)
		row.add_child(slot)
	var column := UiKit.vbox(30)
	column.add_child(row)
	var done := UiKit.button("Done", UiKit.BUTTON_GREEN, 96, 34)
	done.pressed.connect(_finish)
	column.add_child(done)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_content.add_child(center)
	_stage_nodes.append(center)
	if Session.autoplay:
		await get_tree().create_timer(1.5).timeout
		_finish()


func _finish() -> void:
	finished.emit()
	queue_free()


## The egg's broken shell flies apart: Jo's painted shell pieces (or drawn chips without them),
## arcing out and falling with a spin.
func _spawn_shells(origin: Vector2, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	var painted := ResourceLoader.exists("res://assets/eggs/shard_1.webp")
	for i in count:
		var shard: Node2D
		if painted:
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/eggs/shard_%d.webp" % (i % SHARD_COUNT + 1))
			var size := rng.randf_range(0.35, 0.65) * (1.2 if i < SHARD_COUNT else 0.8)
			sprite.scale = Vector2(size * (1 if rng.randf() < 0.5 else -1), size)
			shard = sprite
		else:
			var chip := Polygon2D.new()
			var r := rng.randf_range(18.0, 38.0)
			chip.polygon = PackedVector2Array([Vector2(-r, -r * 0.4), Vector2(r * 0.7, -r * 0.6),
					Vector2(r * 0.5, r * 0.5), Vector2(-r * 0.6, r * 0.3)])
			chip.color = EggView.SHELL if i % 3 else EggView.SHELL_SHADE
			shard = chip
		shard.position = origin + Vector2(rng.randf_range(-70, 70), rng.randf_range(-90, 60))
		shard.rotation = rng.randf_range(-PI, PI)
		_content.add_child(shard)
		_stage_nodes.append(shard)
		# Up and out first, then falling: two legs give a rough arc.
		var angle := rng.randf_range(-PI * 0.95, -PI * 0.05)
		var speed := rng.randf_range(260, 560)
		var peak := shard.position + Vector2(cos(angle) * speed, sin(angle) * speed * 0.8)
		var land := peak + Vector2(cos(angle) * speed * 0.4, rng.randf_range(380, 620))
		var tween := shard.create_tween()
		tween.tween_property(shard, "position", peak, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shard, "position", land, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var spin := shard.create_tween().set_parallel()
		spin.tween_property(shard, "rotation", shard.rotation + rng.randf_range(-7, 7), 0.87)
		spin.tween_property(shard, "modulate:a", 0.0, 0.35).set_delay(0.6)


## Sparks in the rarity color bursting out of the egg.
func _spawn_sparks(origin: Vector2, color: Color, amount: int) -> void:
	var sparks := CPUParticles2D.new()
	sparks.position = origin
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = amount
	sparks.lifetime = 0.9
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 260.0
	sparks.initial_velocity_max = 720.0
	sparks.gravity = Vector2(0, 900)
	sparks.damping_min = 60.0
	sparks.damping_max = 120.0
	sparks.scale_amount_min = 4.0
	sparks.scale_amount_max = 9.0
	var fade := Gradient.new()
	fade.set_color(0, Color(color.lightened(0.5), 1.0))
	fade.set_color(1, Color(color, 0.0))
	sparks.color_ramp = fade
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = glow
	_content.add_child(sparks)
	_stage_nodes.append(sparks)
	sparks.emitting = true


## Warm dust motes drifting up through the lantern light.
func _dust() -> CPUParticles2D:
	var screen := _screen()
	var dust := CPUParticles2D.new()
	dust.position = Vector2(screen.x / 2, screen.y * 0.8)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(screen.x * 0.55, screen.y * 0.25)
	dust.amount = 36
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.direction = Vector2.UP
	dust.spread = 25.0
	dust.initial_velocity_min = 12.0
	dust.initial_velocity_max = 38.0
	dust.gravity = Vector2(6, -4)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.8, 0.45, 0.0))
	fade.add_point(0.3, Color(1.0, 0.8, 0.45, 0.55))
	fade.set_color(1, Color(1.0, 0.8, 0.45, 0.0))
	dust.color_ramp = fade
	return dust


## Screen y of the slab top in the cover-fitted backdrop (the middle of the screen without one).
func _slab_top() -> float:
	var screen := _screen()
	if _backdrop == null:
		return screen.y * 0.62
	var image := _backdrop.texture.get_size()
	var scale := maxf(screen.x / image.x, screen.y / image.y)
	return screen.y / 2 + (SLAB_Y - 0.5) * image.y * scale


func _dim_backdrop(light: float) -> void:
	if _backdrop:
		_backdrop.create_tween().tween_property(_backdrop, "modulate", Color(light, light, light), 0.4)


func _flash_and_shake(rarity: int) -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.45)
	fade.tween_callback(flash.queue_free)
	var strength := 14.0 if rarity == DinoDef.Rarity.EPIC else 26.0
	var shake := _content.create_tween()
	for i in 10:
		var falloff := 1.0 - i / 10.0
		shake.tween_property(_content, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff, 0.04)
	shake.tween_property(_content, "position", Vector2.ZERO, 0.04)


## Rotating light rays behind a freshly hatched card.
class LightBurst:
	extends Control

	const RAYS := 14
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var spin := create_tween().set_loops()
		spin.tween_property(self, "rotation", TAU, 14.0).from(0.0)

	func _draw() -> void:
		var center := size / 2
		var radius := size.x / 2
		for i in RAYS:
			var a := TAU * i / RAYS
			var half := PI / RAYS * 0.45
			var points := PackedVector2Array([center,
					center + Vector2(cos(a - half), sin(a - half)) * radius,
					center + Vector2(cos(a + half), sin(a + half)) * radius])
			draw_colored_polygon(points, Color(color, 0.22))
		for i in range(6, 0, -1):
			draw_circle(center, radius * 0.12 * i, Color(color, 0.05), true, -1.0, true)
