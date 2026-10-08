class_name SettingsView
extends Control
## Settings popup from the gear in the top bar: sound effects and music on/off, How to play,
## and credits.


static func open() -> SettingsView:
	var view := SettingsView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	Sound.play(&"back")
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
	column.add_child(_toggle("Sound effects", Sound.sfx_on(), Sound.set_sfx_on))
	column.add_child(_toggle("Music", Sound.music_on(), Sound.set_music_on))
	var help := UiKit.button("How to play", UiKit.BUTTON_GRAY, 76, 26)
	help.pressed.connect(func() -> void: HelpView.open())
	column.add_child(help)
	var done := UiKit.button("Done", UiKit.BUTTON_GREEN, 76, 26)
	done.pressed.connect(close)
	column.add_child(done)
	column.add_child(UiKit.label("Sound effects by Kenney (CC0)", 18, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))


func _toggle(text: String, on: bool, apply: Callable) -> Control:
	var row := UiKit.hbox(12)
	var label := UiKit.label(text, 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := UiKit.button("", UiKit.BUTTON_GRAY, 64, 24)
	button.custom_minimum_size.x = 140
	var show_state := func(state: bool) -> void:
		button.text = "On" if state else "Off"
		UiKit.style_button(button, UiKit.BUTTON_GREEN if state else UiKit.BUTTON_GRAY)
	show_state.call(on)
	button.pressed.connect(func() -> void:
		var state := button.text != "On"
		apply.call(state)
		show_state.call(state))
	row.add_child(button)
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
