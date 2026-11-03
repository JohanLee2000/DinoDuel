class_name ProfileView
extends ColorRect
## The Fossil Hunter ID (Jo, 2026-11-03), opened from the avatar at the top left: avatar, name,
## title, the 3 showcase cards and the player's stats. Tap the avatar, the pencil, the title or the
## showcase to change them. Rules: core/collection/hunter_id.gd.

signal closed

const SHOWCASE_CARD_WIDTH := 170.0
const PICKER_AVATAR := 96.0

var _body: VBoxContainer


static func open() -> ProfileView:
	var view := ProfileView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	closed.emit()
	queue_free()


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 620
	column.add_child(UiKit.title("Fossil Hunter ID", 34, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_body = UiKit.vbox(16)
	var scroll := UiKit.vscroll(_body)
	scroll.custom_minimum_size.y = minf(860.0, get_viewport_rect().size.y * 0.7)
	column.add_child(scroll)
	var done := UiKit.button("Close", UiKit.BUTTON_GREEN, 68, 26)
	done.pressed.connect(close)
	column.add_child(done)
	var panel := UiKit.panel(column, Palette.PANEL, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	add_child(center)
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var profile := Session.profile
	var catalog := Session.catalog

	# Avatar, name and title.
	var header := UiKit.hbox(18)
	var avatar := Button.new()
	avatar.flat = true
	avatar.custom_minimum_size = Vector2.ONE * 150
	avatar.add_child(Avatar.of_player(150, Palette.HIGHLIGHT))
	avatar.pressed.connect(_pick_avatar)
	header.add_child(avatar)
	var words := UiKit.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_row := UiKit.hbox(10)
	var name_label := UiKit.title(profile.player_name if profile.player_name != "" else "Fossil hunter", 36, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, false)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)
	var pencil := UiKit.button("", UiKit.BUTTON_GRAY, 50, 22)
	pencil.icon = Icons.texture(&"edit", 26)
	pencil.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pencil.custom_minimum_size.x = 56
	pencil.pressed.connect(_rename)
	name_row.add_child(pencil)
	words.add_child(name_row)
	var title := UiKit.button(HunterId.title_text(HunterId.title_of(profile, catalog)), UiKit.BUTTON_GRAY, 54, 24)
	title.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	title.pressed.connect(_pick_title)
	words.add_child(title)
	words.add_child(UiKit.label("Tap your avatar or title to change them.", 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
	header.add_child(words)
	_body.add_child(header)

	# Showcase.
	_body.add_child(UiKit.title("Showcase", 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var cards := UiKit.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	var shown := HunterId.showcase_of(profile)
	for i in HunterId.SHOWCASE_SIZE:
		if i < shown.size():
			var dino := catalog.find(shown[i])
			var card := DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino.id), SHOWCASE_CARD_WIDTH)
			card.inspect_on_hold = false
			card.mastery_rank = Mastery.rank_of(profile, dino.id)
			card.pressed.connect(_pick_showcase)
			cards.add_child(card)
		else:
			var empty := UiKit.button("+", UiKit.BUTTON_GRAY, int(SHOWCASE_CARD_WIDTH * DinoCard.ASPECT), 44)
			empty.custom_minimum_size.x = SHOWCASE_CARD_WIDTH
			empty.pressed.connect(_pick_showcase)
			cards.add_child(empty)
	_body.add_child(cards)

	# Stats.
	_body.add_child(UiKit.title("Stats", 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var grid := UiKit.grid(2, 8)
	for row in HunterId.stats(profile, catalog):
		var label := UiKit.label(row[0], 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var value := UiKit.label(row[1], 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		value.add_theme_font_override("font", Fonts.bold())
		grid.add_child(value)
	_body.add_child(UiKit.panel(grid, Palette.BACKGROUND, 14))


## A popup over the ID: a title, `content` (in a tall scroll area if `scrolls`), and Close.
func _popup(heading: String, content: Control, scrolls := true) -> ColorRect:
	var layer := UiKit.modal_layer(0.85)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			layer.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 620
	column.add_child(UiKit.title(heading, 34, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	if scrolls:
		var scroll := UiKit.vscroll(content)
		scroll.custom_minimum_size.y = minf(820.0, get_viewport_rect().size.y * 0.66)
		column.add_child(scroll)
	else:
		column.add_child(content)
	var close_button := UiKit.button("Close", UiKit.BUTTON_GRAY, 64, 26)
	close_button.pressed.connect(layer.queue_free)
	column.add_child(close_button)
	var panel := UiKit.panel(column, Palette.PANEL, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	layer.add_child(center)
	add_child(layer)
	return layer


## Beaten rivals and the Professaur, then every dino you own.
func _pick_avatar() -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var current := HunterId.avatar_of(profile)
	var content := UiKit.vbox(12)
	var holder: Array[ColorRect] = []
	var sections := [["Rivals you've beaten", func(a: String) -> bool: return not a.begins_with("dino:")],
			["Your dinos", func(a: String) -> bool: return a.begins_with("dino:")]]
	var choices := HunterId.avatar_choices(profile, Session.catalog)
	for section in sections:
		var picked: Array = choices.filter(section[1])
		content.add_child(UiKit.title(section[0], 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		if picked == [HunterId.PROFESSAUR]:
			content.add_child(UiKit.label("Beat rivals on the Journey to use them as your avatar.", 23, Palette.TEXT_DIM))
		var grid := UiKit.grid(5, 12)
		for avatar in picked:
			var button := UiKit.let_scroll(Button.new())
			button.flat = true
			button.custom_minimum_size = Vector2.ONE * PICKER_AVATAR
			button.add_child(Avatar.circle(Avatar.texture(avatar), PICKER_AVATAR,
					Palette.HIGHLIGHT if avatar == current else Palette.PANEL_BORDER, 5 if avatar == current else 2))
			button.pressed.connect(func() -> void:
				Sound.play(&"card_pick")
				profile.avatar = avatar
				Session.save()
				holder[0].queue_free()
				_refresh())
			grid.add_child(button)
		content.add_child(grid)
	holder.append(_popup("Choose your avatar", content))


## Every title: the ones you've earned to pick, the rest with how to earn them.
func _pick_title() -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var catalog := Session.catalog
	var current := HunterId.title_of(profile, catalog)
	var content := UiKit.vbox(8)
	var holder: Array[ColorRect] = []
	var ids := HunterId.titles()
	var earned := ids.filter(func(id: String) -> bool: return HunterId.title_unlocked(profile, catalog, id))
	var locked := ids.filter(func(id: String) -> bool: return not HunterId.title_unlocked(profile, catalog, id))
	content.add_child(UiKit.label("%d of %d earned" % [earned.size(), ids.size()], 24, Palette.TEXT_DIM))
	for id in earned:
		var button := UiKit.let_scroll(UiKit.button(HunterId.title_text(id), UiKit.BUTTON_GREEN if id == current else UiKit.BUTTON_GRAY, 60, 25))
		button.pressed.connect(func() -> void:
			Sound.play(&"tap")
			profile.title = id
			Session.save()
			holder[0].queue_free()
			_refresh())
		content.add_child(button)
	for id in locked:
		var row := UiKit.hbox(12)
		var lock := TextureRect.new()
		lock.texture = Icons.texture(&"lock", 30)
		lock.custom_minimum_size = Vector2(30, 30)
		lock.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.modulate = Color(1, 1, 1, 0.6)
		row.add_child(lock)
		var words := UiKit.vbox(0)
		words.add_child(UiKit.label(HunterId.title_text(id), 25, Color(Palette.TEXT, 0.6), HORIZONTAL_ALIGNMENT_LEFT, false))
		words.add_child(UiKit.label(HunterId.title_how(id), 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
		row.add_child(words)
		content.add_child(UiKit.panel(row, Palette.BACKGROUND, 10))
	holder.append(_popup("Choose your title", content))


## Your dinos, rarest first: tap up to 3 to show them off.
func _pick_showcase() -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var content := UiKit.vbox(10)
	var count := UiKit.label("", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	content.add_child(count)
	var grid := UiKit.grid(4, 10)
	var owned := Session.catalog.dinos.filter(func(d: DinoDef) -> bool: return profile.owns(d.id))
	owned.sort_custom(func(a: DinoDef, b: DinoDef) -> bool:
		return a.rarity > b.rarity if a.rarity != b.rarity else a.display_name < b.display_name)
	var cards := {}
	var update := func() -> void:
		count.text = "%d / %d shown  ·  tap to add or remove" % [HunterId.showcase_of(profile).size(), HunterId.SHOWCASE_SIZE]
		for id in cards:
			var shown: bool = id in profile.showcase
			cards[id].selected = shown
			cards[id].set_badge("SHOWN" if shown else "")
	for dino in owned:
		var card := DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino.id), 136)
		card.inspect_on_hold = false
		card.pressed.connect(func() -> void:
			if dino.id in profile.showcase:
				profile.showcase.erase(dino.id)
			elif profile.showcase.size() < HunterId.SHOWCASE_SIZE:
				profile.showcase.append(dino.id)
			else:
				Sound.play(&"error")
				return
			Sound.play(&"card_pick")
			Session.save()
			update.call()
			_refresh())
		cards[dino.id] = card
		grid.add_child(card)
	var centered := CenterContainer.new()
	centered.add_child(grid)
	content.add_child(centered)
	update.call()
	_popup("Choose your showcase", content)


## A new name (the same rules as the first time: up to 16 characters).
func _rename() -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var content := UiKit.vbox(14)
	var field := LineEdit.new()
	field.text = profile.player_name
	field.max_length = PlayerProfile.NAME_MAX_LENGTH
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
	content.add_child(field)
	var save := UiKit.button("Save", UiKit.BUTTON_GREEN, 72, 28)
	content.add_child(save)
	var layer := _popup("Your name", content, false)
	var confirm := func() -> void:
		if profile.set_player_name(field.text):
			Session.save()
			_refresh()
		layer.queue_free()
	save.pressed.connect(confirm)
	field.text_submitted.connect(func(_text: String) -> void: confirm.call())
	field.text_changed.connect(func(text: String) -> void: save.disabled = text.strip_edges().is_empty())
	field.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
