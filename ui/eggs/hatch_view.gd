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

var _results: Array[HatchResult] = []
var _title_text := "Your clutch is hatching!"
var _index := 0
var _waiting_for_tap := false
var _content: Control
var _title: Label
var _hint: Label
var _skip: Button
var _stage_nodes: Array[Node] = []


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
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_title = UiKit.title("", 40, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 70
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_title)
	_hint = UiKit.label("", 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -200
	_hint.offset_bottom = -150
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_hint)
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
	var egg := EggView.new()
	egg.rarity = result.dino.rarity
	egg.size = egg.custom_minimum_size
	egg.position = (_screen() - egg.size) / 2 + Vector2(0, -30)
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
		card.visible = true)
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
	_waiting_for_tap = true
	if Session.autoplay:
		await get_tree().create_timer(1.2).timeout
		_advance()


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
		var caption := UiKit.label(_caption(result), 20, Palette.HIGHLIGHT if result.is_new or result.shiny \
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


func _spawn_shells(origin: Vector2, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	for i in count:
		var shard := Polygon2D.new()
		var r := rng.randf_range(18.0, 38.0)
		shard.polygon = PackedVector2Array([Vector2(-r, -r * 0.4), Vector2(r * 0.7, -r * 0.6),
				Vector2(r * 0.5, r * 0.5), Vector2(-r * 0.6, r * 0.3)])
		shard.color = EggView.SHELL if i % 3 else EggView.SHELL_SHADE
		shard.position = origin + Vector2(rng.randf_range(-60, 60), rng.randf_range(-80, 80))
		_content.add_child(shard)
		_stage_nodes.append(shard)
		var angle := rng.randf_range(0, TAU)
		var distance := rng.randf_range(260, 520)
		var target := shard.position + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, 220)
		var tween := shard.create_tween().set_parallel()
		tween.tween_property(shard, "position", target, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shard, "rotation", rng.randf_range(-6, 6), 0.9)
		tween.tween_property(shard, "modulate:a", 0.0, 0.5).set_delay(0.45)


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
