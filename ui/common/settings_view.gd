class_name SettingsView
extends Control
## Settings popup from the gear in the top bar: sound effects and music volume, How to play,
## the Professaur's tour again, Restart game (with a confirmation), and credits. Export / Import
## save is built but commented out until Jo decides about it.


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
	var tour := UiKit.icon_button("Professaur's tour", &"map", UiKit.BUTTON_GRAY, 76, 26)
	tour.pressed.connect(_replay_tour)
	column.add_child(tour)
	# Export / Import save, switched off for now (see the note above _export_save).
#	var transfer := UiKit.hbox(12)
#	var export := UiKit.icon_button("Export save", &"export", UiKit.BUTTON_GRAY, 76, 24)
#	export.pressed.connect(_export_save)
#	var import := UiKit.icon_button("Import save", &"import", UiKit.BUTTON_GRAY, 76, 24)
#	import.pressed.connect(_pick_import)
#	for button in [export, import]:
#		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
#		transfer.add_child(button)
#	column.add_child(transfer)
	var restart := UiKit.icon_button("Restart game", &"restart", UiKit.BUTTON_RED, 76, 26)
	restart.pressed.connect(_confirm_restart)
	column.add_child(restart)
	var done := UiKit.button("Done", UiKit.BUTTON_GREEN, 76, 26)
	done.pressed.connect(close)
	column.add_child(done)
	column.add_child(UiKit.label("Sound effects by Kenney (CC0)", 22, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))


## Closes Settings and has the Professaur show the player around again.
func _replay_tour() -> void:
	var main := get_tree().current_scene as MainScreen
	close()
	if main:
		ProfessorTour.start(main, true)


## Export / Import save: built and tested 2026-10-09, switched off until Jo decides whether it
## ships in production. To bring it back, uncomment this block and the Export / Import row in
## _ready. The save-file side (SaveStore.write_export / read_export / parse_export, Share.file,
## the export and import icons) is still live and covered by tests.
### Export save: writes the save to a file and opens the share sheet, so the player can send it to
### themselves (Drive, email, another phone...).
#func _export_save() -> void:
#	var path := SaveStore.write_export(Session.profile)
#	if path == "" or not Share.file(path, "application/json",
#			"My Dino Duel save. On the new phone: Settings > Import save.", "Save your Dino Duel progress"):
#		_message("Couldn't export", "Something went wrong writing the save file. Please try again.")


### Import save: the phone's file picker, then a confirmation showing what's in the file.
#func _pick_import() -> void:
#	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
#		_message("Can't import here", "This device has no file picker.")
#		return
#	DisplayServer.file_dialog_show("Choose a Dino Duel save", "", "", false,
#			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(), _on_import_picked)


#func _on_import_picked(status: bool, paths: PackedStringArray, _filter: int) -> void:
#	if status and not paths.is_empty():
#		_confirm_import.call_deferred(paths[0])


#func _confirm_import(path: String) -> void:
#	var file := FileAccess.open(path, FileAccess.READ)
#	var text := file.get_as_text() if file and file.get_length() <= SaveStore.IMPORT_MAX_BYTES else ""
#	var imported := SaveStore.parse_export(text, Session.catalog) if text != "" else null
#	if imported == null:
#		_message("Not a Dino Duel save", "That file isn't a save exported from Dino Duel, or it's damaged.")
#		return
#	var current := Session.profile
#	var exported := SaveStore.export_date(text).replace("T", " ").left(16)
#	var column := _dialog_column("Load this save?", Palette.HIGHLIGHT)
#	column.add_child(UiKit.label("%s%s: %d dinos, %d Amber, %d wins." % [
#			"Saved %s by " % exported if exported != "" else "", imported.player_name if imported.player_name != "" else "a player",
#			imported.owned.size(), imported.amber, imported.wins], 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
#	column.add_child(UiKit.label("It replaces the progress on this phone (%d dinos, %d Amber). This can't be undone." \
#			% [current.owned.size(), current.amber], 26, Palette.DAMAGE.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER))
#	var dialog := _open_dialog(column)
#	var keep := UiKit.button("Keep this phone's save", UiKit.BUTTON_GREEN, 84, 30)
#	keep.pressed.connect(dialog.queue_free)
#	column.add_child(keep)
#	var load_it := UiKit.button("Load this save", UiKit.BUTTON_RED, 76, 26)
#	load_it.pressed.connect(func() -> void: Session.import_profile(imported))
#	column.add_child(load_it)


## A small popup with a title, a line of text and OK.
func _message(heading: String, text: String) -> void:
	var column := _dialog_column(heading, Palette.HIGHLIGHT)
	column.add_child(UiKit.label(text, 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var dialog := _open_dialog(column)
	var ok := UiKit.button("OK", UiKit.BUTTON_GREEN, 76, 28)
	ok.pressed.connect(dialog.queue_free)
	column.add_child(ok)


func _dialog_column(heading: String, color: Color) -> VBoxContainer:
	var column := UiKit.vbox(18)
	column.custom_minimum_size.x = 580
	column.add_child(UiKit.title(heading, 40, color, HORIZONTAL_ALIGNMENT_CENTER))
	return column


## Shows `column` in a panel over everything; the back button closes the newest one.
func _open_dialog(column: Control) -> ColorRect:
	var dialog := UiKit.modal_layer(0.85)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))
	dialog.add_child(center)
	add_child(dialog)
	return dialog


## "Are you sure?" before wiping the save.
func _confirm_restart() -> void:
	var column := _dialog_column("Restart the game?", Palette.DAMAGE)
	column.add_child(UiKit.label("This deletes all of your save data: every dino you've collected, your Amber and eggs, " \
			+ "Goals progress and rival records.", 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("You'll start again from the very beginning, with a new name and a new partner. " \
			+ "This can't be undone.", 26, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var dialog := _open_dialog(column)
	var keep := UiKit.button("Keep my progress", UiKit.BUTTON_GREEN, 84, 30)
	keep.pressed.connect(dialog.queue_free)
	column.add_child(keep)
	var wipe := UiKit.button("Delete everything and restart", UiKit.BUTTON_RED, 76, 26)
	wipe.pressed.connect(Session.restart_game)
	column.add_child(wipe)


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
