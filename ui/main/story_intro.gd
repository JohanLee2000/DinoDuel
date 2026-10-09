class_name StoryIntro
extends Control
## The new-player intro: four full-screen story panels, one line each, before the partner pick.
## Tap to advance, Skip to jump ahead. Each panel uses its own painting from assets/story/ when
## there is one (panel_1.webp ...), otherwise a scene built from the game's existing art.

signal finished

const STORY_ART := "res://assets/story/panel_%d.webp"
const PANELS: Array[String] = [
	"66 million years ago, the dinosaurs vanished.\nHowever, their fossils didn't.",
	"You've found a way to wake them: fossil eggs sealed in amber, ready to hatch.",
	"Other collectors are hunting too. Battle them, win their eggs, and fill your Dino Dex.",
	"Every hunter needs a partner.\nChoose yours.",
]
const FADE := 0.45

var _index := -1
var _stage: Control
var _busy := false
var _skip_button: Button


static func open() -> StoryIntro:
	var view := StoryIntro.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Palette.BACKGROUND
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.gui_input.connect(_on_input)
	add_child(black)
	_skip_button = UiKit.button("Skip", UiKit.BUTTON_GRAY, 56, 27)
	_skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.offset_left = -160
	_skip_button.offset_right = -24
	_skip_button.offset_top = 48
	_skip_button.offset_bottom = 104
	_skip_button.pressed.connect(_finish)
	add_child(_skip_button)
	_next()
	if Session.autoplay:
		for i in PANELS.size():
			await get_tree().create_timer(1.4).timeout
			if not is_inside_tree():
				return
			_next()



func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next()


func _next() -> void:
	if _busy:
		return
	_index += 1
	if _index >= PANELS.size():
		_finish()
		return
	_busy = true
	Sound.play(&"card_flip" if _index > 0 else &"glow")
	var old := _stage
	_stage = _build_panel(_index)
	add_child(_stage)
	move_child(_stage, 1)
	move_child(_skip_button, get_child_count() - 1)
	_stage.modulate.a = 0.0
	var fade := _stage.create_tween()
	fade.tween_property(_stage, "modulate:a", 1.0, FADE)
	if old:
		fade.tween_callback(old.queue_free)
	await fade.finished
	_busy = false


func _finish() -> void:
	if not is_inside_tree():
		return
	finished.emit()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE)
	fade.tween_callback(queue_free)


func _build_panel(index: int) -> Control:
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var custom := STORY_ART % (index + 1)
	if ResourceLoader.exists(custom):
		panel.add_child(_painting(load(custom), 1.0))
	else:
		_build_scene(panel, index)
	panel.add_child(_caption(PANELS[index], index))
	return panel


## The fallback scene for each panel, from art the game already has.
func _build_scene(panel: Control, index: int) -> void:
	match index:
		0:
			panel.add_child(_painting(load("res://assets/battle/land.webp")))
		1:
			panel.add_child(_painting(load("res://assets/battle/land.webp"), 0.35))
			var egg := EggView.new()
			egg.rarity = DinoDef.Rarity.EPIC
			egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			egg.size = egg.custom_minimum_size * 1.25
			egg.position = (get_viewport_rect().size - egg.size) / 2 + Vector2(0, -150)
			egg.show_glowing(1.4)
			panel.add_child(egg)
			var pulse := egg.create_tween().set_loops()
			pulse.tween_method(egg.show_glowing, 1.2, 1.7, 1.1).set_trans(Tween.TRANS_SINE)
			pulse.tween_method(egg.show_glowing, 1.7, 1.2, 1.1).set_trans(Tween.TRANS_SINE)
		2:
			panel.add_child(_painting(load("res://assets/battle/sea.webp"), 0.55))
			var screen := get_viewport_rect().size
			for entry in [[&"mosasaurus", Vector2(0.3, 0.36), -9.0], [&"t_rex", Vector2(0.7, 0.36), 9.0]]:
				var card := DinoCard.create(Session.catalog.find(entry[0]), DinoCard.Mode.FULL, null, false, 250.0)
				card.inspect_on_hold = false
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.position = screen * entry[1] - card.size / 2
				card.pivot_offset = card.size / 2
				card.rotation_degrees = entry[2]
				panel.add_child(card)
		3:
			panel.add_child(_painting(load("res://assets/battle/sky.webp")))


## A full-screen image that slowly zooms in (Ken Burns), dimmed by `dim`.
func _painting(texture: Texture2D, dim := 0.8) -> Control:
	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture = texture
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.modulate = Color(dim, dim, dim)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(image)
	image.resized.connect(func() -> void: image.pivot_offset = image.size / 2, CONNECT_ONE_SHOT)
	image.create_tween().tween_property(image, "scale", Vector2(1.12, 1.12), 9.0).from(Vector2.ONE)
	return clip


func _caption(text: String, index: int) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark fade behind the words so they read on any painting.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.BACKGROUND, 0.0))
	gradient.set_color(1, Color(Palette.BACKGROUND, 0.92))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.fill_from = Vector2(0, 0)
	fill.fill_to = Vector2(0, 1)
	fill.width = 4
	fill.height = 256
	shade.texture = fill
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -560
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)

	var column := UiKit.vbox(18)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	column.offset_left = 36
	column.offset_right = -36
	column.offset_top = -330
	column.offset_bottom = -70
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := UiKit.label(text, 36, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	words.add_theme_font_override("font", Fonts.bold())
	words.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	words.add_theme_constant_override("shadow_offset_y", 3)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(words)
	var dots := ""
	for i in PANELS.size():
		dots += "●  " if i == index else "○  "
	var footer := UiKit.label("%s\nTap to continue" % dots.strip_edges(), 29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	holder.add_child(column)
	return holder
