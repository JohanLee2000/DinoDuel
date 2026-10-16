class_name PartySlots
extends HBoxContainer
## The saved party slots (Jo, 2026-10-16): Party 1 / 2 / 3 as buttons, the open one gold. Tapping
## one switches to it (and saves); the pencil renames the open one. On the Party tab and the pick
## screen before a battle.

signal switched

## The pencil button (the Party tab has it; the pick screen only switches).
var with_rename := true


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var profile := Session.profile
	for slot in PlayerProfile.PARTY_SLOTS:
		var open := slot == profile.party_slot
		var button := UiKit.button(profile.party_name(slot), UiKit.BUTTON_GREEN if open else UiKit.BUTTON_GRAY, 62, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(func() -> void:
			if slot == profile.party_slot:
				return
			Sound.play(&"tap")
			profile.select_party(slot)
			Session.save()
			refresh()
			switched.emit())
		add_child(button)
	if with_rename:
		var pencil := UiKit.button("", UiKit.BUTTON_GRAY, 62, 24)
		pencil.icon = Icons.texture(&"edit", 30)
		pencil.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pencil.custom_minimum_size.x = 70
		pencil.pressed.connect(_rename)
		add_child(pencil)


## A small popup to name the open party (at most PARTY_NAME_MAX_LENGTH characters).
func _rename() -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var slot := profile.party_slot
	var dialog := UiKit.modal_layer(0.85)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := UiKit.vbox(16)
	column.custom_minimum_size.x = 560
	column.add_child(UiKit.title("Name this party", 36, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var field := LineEdit.new()
	field.text = profile.party_name(slot)
	field.max_length = PlayerProfile.PARTY_NAME_MAX_LENGTH
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.custom_minimum_size = Vector2(0, 84)
	field.select_all_on_focus = true
	field.add_theme_font_size_override("font_size", 34)
	field.add_theme_font_override("font", Fonts.bold())
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.BACKGROUND, 0.95)
		style.border_color = Palette.HIGHLIGHT if state == "focus" else Palette.PANEL_BORDER
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(14)
		field.add_theme_stylebox_override(state, style)
	column.add_child(field)
	var buttons := UiKit.hbox(12)
	var cancel := UiKit.button("Cancel", UiKit.BUTTON_GRAY, 72, 28)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(dialog.queue_free)
	buttons.add_child(cancel)
	var save := UiKit.button("Save", UiKit.BUTTON_GREEN, 72, 28)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm := func() -> void:
		if profile.rename_party(slot, field.text):
			Sound.play(&"tap")
			Session.save()
			refresh()
		dialog.queue_free()
	save.pressed.connect(confirm)
	field.text_submitted.connect(func(_text: String) -> void: confirm.call())
	field.text_changed.connect(func(text: String) -> void: save.disabled = text.strip_edges().is_empty())
	buttons.add_child(save)
	column.add_child(buttons)
	center.add_child(UiKit.panel(column, Palette.PANEL, 24))
	dialog.add_child(center)
	get_tree().current_scene.add_child(dialog)
	field.grab_focus.call_deferred()
