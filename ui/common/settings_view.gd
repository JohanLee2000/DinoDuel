class_name SettingsView
extends Control
## Settings popup from the gear in the top bar: sound effects and music volume, How to play,
## Restart game (with a confirmation), and credits.


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
	var help := UiKit.icon_button("How to play", &"book", UiKit.BUTTON_GRAY, 76, 26)
	help.pressed.connect(func() -> void: HelpView.open())
	column.add_child(help)
	var restart := UiKit.icon_button("Restart game", &"restart", UiKit.BUTTON_RED, 76, 26)
	restart.pressed.connect(_confirm_restart)
	column.add_child(restart)
	var done := UiKit.button("Done", UiKit.BUTTON_GREEN, 76, 26)
	done.pressed.connect(close)
	column.add_child(done)
	column.add_child(UiKit.label("Sound effects by Kenney (CC0)", 22, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))


## "Are you sure?" before wiping the save.
func _confirm_restart() -> void:
	var dialog := UiKit.modal_layer(0.85)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := UiKit.vbox(18)
	column.custom_minimum_size.x = 580
	column.add_child(UiKit.title("Restart the game?", 40, Palette.DAMAGE, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("This deletes all of your save data: every dino you've collected, your Amber and eggs, " \
			+ "Goals progress and rival records.", 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("You'll start again from the very beginning, with a new name and a new partner. " \
			+ "This can't be undone.", 26, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var keep := UiKit.button("Keep my progress", UiKit.BUTTON_GREEN, 84, 30)
	keep.pressed.connect(dialog.queue_free)
	column.add_child(keep)
	var wipe := UiKit.button("Delete everything and restart", UiKit.BUTTON_RED, 76, 26)
	wipe.pressed.connect(Session.restart_game)
	column.add_child(wipe)
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))
	dialog.add_child(center)
	add_child(dialog)


func _volume_row(text: String, volume: float, apply: Callable, preview: bool) -> Control:
	var box := UiKit.vbox(4)
	var top := UiKit.hbox(12)
	var label := UiKit.label(text, 28, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var amount := UiKit.label("", 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
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
		var dialog := get_child(get_child_count() - 1)
		if dialog is ColorRect and dialog != get_child(0):
			dialog.queue_free()
		else:
			close()
