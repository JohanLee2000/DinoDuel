class_name SettingsView
extends Control
## Settings popup from the gear in the top bar: sound effects and music volume, How to play,
## and credits.


static func open() -> SettingsView:
	var view := SettingsView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := UiKit.modal_layer(0.8)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := UiKit.vbox(16)
	column.custom_minimum_size.x = 560
	column.add_child(UiKit.title("Settings", 40, Palette.HIGHLIGHT))
	column.add_child(_volume_row("Sound effects", Sound.sfx_volume(), Sound.set_sfx_volume, true))
	column.add_child(_volume_row("Music", Sound.music_volume(), Sound.set_music_volume, false))
	var help := UiKit.button("How to play", UiKit.BUTTON_GRAY, 76, 26)
	help.pressed.connect(func() -> void: HelpView.open())
	column.add_child(help)
	var done := UiKit.button("Done", UiKit.BUTTON_GREEN, 76, 26)
	done.pressed.connect(close)
	column.add_child(done)
	column.add_child(UiKit.label("Sound effects by Kenney (CC0)", 18, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))


func _volume_row(text: String, volume: float, apply: Callable, preview: bool) -> Control:
	var box := UiKit.vbox(4)
	var top := UiKit.hbox(12)
	var label := UiKit.label(text, 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var amount := UiKit.label("", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	top.add_child(amount)
	box.add_child(top)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundf(volume * 100)
	slider.custom_minimum_size = Vector2(0, 56)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var knob := Icons.texture(&"knob", 40)
	for icon in ["grabber", "grabber_highlight"]:
		slider.add_theme_icon_override(icon, knob)
	for style_name in ["slider", "grabber_area", "grabber_area_highlight"]:
		var style := StyleBoxFlat.new()
		style.bg_color = UiKit.BUTTON_GRAY if style_name == "slider" else Palette.HIGHLIGHT
		style.set_corner_radius_all(6)
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		slider.add_theme_stylebox_override(style_name, style)
	var show_amount := func(value: float) -> void:
		amount.text = "Off" if value <= 0 else "%d%%" % value
	show_amount.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		apply.call(value / 100.0)
		show_amount.call(value))
	if preview:
		# Let the player hear the new level when they let go.
		slider.drag_ended.connect(func(_changed: bool) -> void: Sound.play(&"tap"))
	box.add_child(slider)
	return box


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
