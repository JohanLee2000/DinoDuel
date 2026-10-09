class_name NameEntry
extends Control
## The very first screen for a new player: type your name. It's saved in the profile and used by
## Professor Saurus (and the story later). Kept in the top half so the phone keyboard doesn't
## cover it.

signal finished

var _field: LineEdit
var _continue: Button


static func open() -> NameEntry:
	var view := NameEntry.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = load("res://assets/story/panel_2.webp")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.32, 0.32, 0.36)
	add_child(background)

	var column := UiKit.vbox(22)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_left = 36
	column.offset_right = -36
	column.offset_top = 110
	add_child(column)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 150)
	column.add_child(logo)
	column.add_child(UiKit.title("Welcome, fossil hunter!", 44, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("What should we call you?", 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	_field = LineEdit.new()
	_field.placeholder_text = "Your name"
	_field.max_length = PlayerProfile.NAME_MAX_LENGTH
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.custom_minimum_size = Vector2(0, 88)
	_field.add_theme_font_size_override("font_size", 36)
	_field.add_theme_font_override("font", Fonts.bold())
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.PANEL, 0.95)
		style.border_color = Palette.HIGHLIGHT if state == "focus" else Palette.PANEL_BORDER
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(14)
		_field.add_theme_stylebox_override(state, style)
	_field.text_changed.connect(func(_text: String) -> void: _update_button())
	_field.text_submitted.connect(func(_text: String) -> void: _submit())
	column.add_child(_field)

	_continue = UiKit.button("Continue", UiKit.BUTTON_GREEN, 88, 32)
	_continue.pressed.connect(_submit)
	column.add_child(_continue)
	_update_button()
	_field.grab_focus.call_deferred()

	if Session.autoplay:
		await get_tree().create_timer(0.6).timeout
		_field.text = "Tester"
		_submit()


func _update_button() -> void:
	_continue.disabled = _field.text.strip_edges().is_empty()


func _submit() -> void:
	if not Session.profile.set_player_name(_field.text):
		Sound.play(&"error")
		return
	Session.save()
	DisplayServer.virtual_keyboard_hide()
	finished.emit()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.35)
	fade.tween_callback(queue_free)
