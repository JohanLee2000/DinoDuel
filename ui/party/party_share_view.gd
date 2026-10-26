class_name PartyShareView
extends ColorRect
## Share party (Jo, 2026-10-26): the open party's code (PartyCode), to copy or to share with a
## picture of the party. A friend enters it on their Party tab (Duel a friend) and battles it.


static func open() -> PartyShareView:
	var view := PartyShareView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


## Why the open party can't be shared, or "" if it can.
static func problem(profile: PlayerProfile, catalog: DinoCatalog) -> String:
	var lineup := profile.lineup_defs(catalog)
	if lineup.size() != PartyRules.BRING_SIZE:
		return "Pick %d dinos for this party first." % PartyRules.BRING_SIZE
	if not PartyRules.has_valid_pick(lineup):
		return "This party's 3 cheapest dinos cost more than %d Party Points, so it can't battle." % PartyRules.POINT_CAP
	return ""


## The open party's code.
static func code_for(profile: PlayerProfile) -> String:
	var shiny: Array[StringName] = []
	for id in profile.lineup:
		if profile.is_shiny(id):
			shiny.append(id)
	return PartyCode.encode(_player(profile), profile.party_name(profile.party_slot), profile.lineup, shiny)


static func _player(profile: PlayerProfile) -> String:
	return profile.player_name if profile.player_name != "" else "A friend"


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			queue_free())
	var profile := Session.profile
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 600
	column.add_child(UiKit.title("Share %s" % profile.party_name(profile.party_slot), 36, Palette.HIGHLIGHT,
			HORIZONTAL_ALIGNMENT_CENTER))
	var cards := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	for dino in profile.lineup_defs(Session.catalog):
		var card := DinoCard.create(dino, DinoCard.Mode.MINI, null, profile.is_shiny(dino.id), 88)
		card.inspect_on_hold = false
		cards.add_child(card)
	column.add_child(cards)

	var trouble := problem(profile, Session.catalog)
	if trouble != "":
		column.add_child(UiKit.label(trouble, 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var code := code_for(profile)
		column.add_child(UiKit.label("Friends enter this code on their Party tab (Duel a friend) to battle this party, played by the game. It's this exact party: share again after you change it.",
				25, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var box := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.BACKGROUND, 0.95)
		style.border_color = Palette.HIGHLIGHT
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(14)
		box.add_theme_stylebox_override("panel", style)
		var code_label := UiKit.label(code, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		code_label.add_theme_font_override("font", Fonts.bold())
		code_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		box.add_child(code_label)
		column.add_child(box)
		var buttons := UiKit.hbox(12)
		var copy := UiKit.icon_button("Copy code", &"cards", UiKit.BUTTON_GRAY, 72, 26)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(code)
			Sound.play(&"tap")
			UiKit.set_icon_text(copy, "Copied!"))
		buttons.add_child(copy)
		var share := UiKit.icon_button("Share", &"share", UiKit.BUTTON_GREEN, 72, 26)
		share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		share.pressed.connect(func() -> void:
			Sound.play(&"tap")
			share.disabled = true
			var shiny: Array[StringName] = []
			for id in profile.lineup:
				if profile.is_shiny(id):
					shiny.append(id)
			await ShareCard.share_party(_player(profile), profile.party_name(profile.party_slot), profile.lineup, shiny, code)
			if is_instance_valid(share):
				share.disabled = false)
		buttons.add_child(share)
		column.add_child(buttons)
	var close := UiKit.button("Close", UiKit.BUTTON_GRAY, 64, 26)
	close.pressed.connect(queue_free)
	column.add_child(close)
	var panel := UiKit.panel(column, Palette.PANEL, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	add_child(center)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		queue_free()
