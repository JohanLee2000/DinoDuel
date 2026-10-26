class_name FriendDuelView
extends ColorRect
## Duel a friend (Jo, 2026-10-26): paste a friend's party code (PartyCode) to battle their party,
## played by the game's AI. Friends you've dueled stay in a list with your record against each,
## to rematch anytime. Everything is offline: the code holds the whole party.

var _field: LineEdit
var _found: VBoxContainer
var _friends: VBoxContainer
var _friends_scroll: ScrollContainer
var _info: Dictionary = {}


static func open(code := "") -> FriendDuelView:
	var view := FriendDuelView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	if code != "":
		view._field.text = code
		view._read(code)
	return view


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 620
	column.add_child(UiKit.title("Duel a friend", 38, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("Paste a friend's party code. The game plays their party, so you can battle it anytime, offline. It counts for your dinos' mastery and daily quests.",
			25, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UiKit.hbox(10)
	_field = LineEdit.new()
	_field.placeholder_text = "%s..." % PartyCode.PREFIX
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.custom_minimum_size = Vector2(0, 66)
	_field.add_theme_font_size_override("font_size", 26)
	_field.add_theme_color_override("font_placeholder_color", Color(Palette.TEXT_DIM, 0.8))
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.BACKGROUND, 0.95)
		style.border_color = Palette.HIGHLIGHT if state == "focus" else Palette.PANEL_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 10
		_field.add_theme_stylebox_override(state, style)
	_field.text_changed.connect(_read)
	_field.text_submitted.connect(func(_text: String) -> void: _field.release_focus())
	row.add_child(_field)
	var paste := UiKit.button("Paste", UiKit.BUTTON_GRAY, 66, 25)
	paste.custom_minimum_size.x = 130
	paste.pressed.connect(func() -> void:
		Sound.play(&"tap")
		_field.text = DisplayServer.clipboard_get().strip_edges()
		_read(_field.text))
	row.add_child(paste)
	column.add_child(row)
	_found = UiKit.vbox(10)
	column.add_child(_found)

	_friends = UiKit.vbox(8)
	_friends_scroll = UiKit.vscroll(_friends)
	_friends_scroll.custom_minimum_size.y = 300
	column.add_child(_friends_scroll)
	var close := UiKit.button("Close", UiKit.BUTTON_GRAY, 64, 26)
	close.pressed.connect(queue_free)
	column.add_child(close)
	var panel := UiKit.panel(column, Palette.PANEL, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	add_child(center)
	_list_friends()


## Reads the field: shows the friend's party and a Battle button, or why the code doesn't work.
func _read(text: String) -> void:
	for child in _found.get_children():
		_found.remove_child(child)
		child.queue_free()
	_info = {}
	if text.strip_edges() == "":
		return
	_info = PartyCode.decode(text, Session.catalog)
	if _info.is_empty():
		_found.add_child(UiKit.label("That isn't a party code, or part of it is missing. Ask your friend to share it again.",
				26, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
		return
	_found.add_child(_party_preview(_info))


## The friend's name, party name and 6 cards, with Battle (or why you can't battle yet).
func _party_preview(info: Dictionary) -> Control:
	var box := UiKit.vbox(10)
	box.add_child(UiKit.title("%s's %s" % [info["player"], info["party"]], 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var cards := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	for id in info["ids"]:
		var card := DinoCard.create(Session.catalog.find(id), DinoCard.Mode.MINI, null, id in info["shiny_ids"], 88)
		card.inspect_on_hold = false
		cards.add_child(card)
	box.add_child(cards)
	var mine := PartyShareView.problem(Session.profile, Session.catalog)
	if mine != "":
		box.add_child(UiKit.label("Your party isn't ready: %s" % mine.left(1).to_lower() + mine.substr(1), 25,
				Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var battle := UiKit.button("Battle!", UiKit.BUTTON_GREEN, 76, 30)
		battle.pressed.connect(func() -> void:
			Sound.play(&"tap")
			Session.start_friend_duel(info))
		box.add_child(battle)
	return UiKit.panel(box, Palette.BACKGROUND, 12)


## Friends you've dueled: name, party, record, and Duel / remove.
func _list_friends() -> void:
	for child in _friends.get_children():
		_friends.remove_child(child)
		child.queue_free()
	var profile := Session.profile
	_friends_scroll.visible = not profile.friends.is_empty()
	if profile.friends.is_empty():
		return
	_friends.add_child(UiKit.title("Friends", 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	for i in profile.friends.size():
		var entry: Dictionary = profile.friends[i]
		var row := UiKit.hbox(10)
		var words := UiKit.vbox(0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(UiKit.label("%s · %s" % [entry["player"], entry["party"]], 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		words.add_child(UiKit.label("You: %d win%s, %d loss%s" % [entry["wins"], "" if entry["wins"] == 1 else "s",
				entry["losses"], "" if entry["losses"] == 1 else "es"], 23, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
		row.add_child(words)
		var duel := UiKit.let_scroll(UiKit.button("Duel", UiKit.BUTTON_GREEN, 56, 24))
		duel.custom_minimum_size.x = 110
		duel.pressed.connect(func() -> void:
			Sound.play(&"tap")
			_field.text = entry["code"]
			_read(entry["code"]))
		row.add_child(duel)
		var forget := UiKit.let_scroll(UiKit.button("", UiKit.BUTTON_GRAY, 56, 24))
		forget.icon = Icons.texture(&"close", 24)
		forget.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forget.custom_minimum_size.x = 56
		forget.pressed.connect(func() -> void:
			Sound.play(&"tap")
			profile.forget_friend(i)
			Session.save()
			_list_friends())
		row.add_child(forget)
		_friends.add_child(UiKit.panel(row, Palette.BACKGROUND, 10))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		queue_free()
