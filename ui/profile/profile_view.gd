class_name ProfileView
extends ColorRect
## The Fossil Hunter ID (Jo, 2026-11-03), opened from the avatar at the top left: avatar, name,
## title, the 3 showcase cards and the player's stats. Tap the avatar, the pencil, the title or the
## showcase to change them. Rules: core/collection/hunter_id.gd.

signal closed

const SHOWCASE_CARD_WIDTH := 170.0
## The ID and its popups: this wide, and as tall as their content up to the screen's height (inside
## the safe area, SCREEN_MARGIN from the edges); taller content scrolls.
const COLUMN_WIDTH := 640.0
const SCREEN_MARGIN := 20.0
const MIN_SCROLL_HEIGHT := 200.0
const PICKER_AVATAR := 96.0
const PICKER_TILE := 132.0
## Gap between an avatar's frame and the gold ring that marks the selected one.
const RING_GAP := 7.0

var _body: VBoxContainer
var _panel: PanelContainer
var _scroll: ScrollContainer


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
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.add_child(UiKit.title("Fossil Hunter ID", 34, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_body = UiKit.vbox(16)
	_scroll = UiKit.vscroll(_body)
	column.add_child(_scroll)
	var done := UiKit.button("Close", UiKit.BUTTON_GREEN, 68, 26)
	done.pressed.connect(close)
	column.add_child(done)
	_panel = UiKit.panel(column, Palette.PANEL, 22)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)
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
	avatar.add_child(Avatar.of_player(150, Palette.HIGHLIGHT, 5))
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
	_fit_later(_panel, _scroll)


## Sizes `scroll` to its content, or if the panel would then be taller than the screen, to the room
## there is (the rest scrolls). Runs at the end of this frame, when the content has its size, and
## again next frame in case wrapped text changed it.
func _fit_later(panel: Control, scroll: ScrollContainer) -> void:
	_fit_height.call_deferred(panel, scroll)
	get_tree().process_frame.connect(func() -> void: _fit_height(panel, scroll), CONNECT_ONE_SHOT)


func _fit_height(panel: Control, scroll: ScrollContainer) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(scroll) or scroll.get_child_count() == 0:
		return
	var insets := SafeAreaMargin.insets_for(self)
	var room := get_viewport_rect().size.y - insets[1] - insets[3] - 2.0 * SCREEN_MARGIN
	var others := panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	var content := (scroll.get_child(0) as Control).get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(content, maxf(MIN_SCROLL_HEIGHT, room - others))


## A popup over the ID: a title, `content`, and Close. It scrolls `content` if `scrolls`, or else the
## ScrollContainer `fill` inside it (sized like the ID: to its content, up to the screen's height).
func _popup(heading: String, content: Control, scrolls := true, fill: ScrollContainer = null) -> ColorRect:
	var layer := UiKit.modal_layer(0.85)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			layer.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.add_child(UiKit.title(heading, 34, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := fill
	if scrolls:
		scroll = UiKit.vscroll(content)
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
	if scroll:
		_fit_later(panel, scroll)
	return layer


## The Professaur and the rivals (beaten ones to pick, the rest locked until you beat them on the
## Journey), then every dino you own, rarest first. Tap one to preview it, then Use avatar.
## `query` types a search (dev flag --open=profile:avatar:<search>).
func _pick_avatar(query := "") -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var selection := {"id": HunterId.avatar_of(profile)}
	var content := UiKit.vbox(12)
	var preview := CenterContainer.new()
	content.add_child(preview)
	var caption := UiKit.label("", 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(caption)
	var search := LineEdit.new()
	search.placeholder_text = "Search dinosaurs or rivals"
	search.custom_minimum_size.y = 56
	search.add_theme_font_size_override("font_size", 24)
	content.add_child(search)
	var lists := UiKit.vbox(10)
	var list_scroll := UiKit.vscroll(lists)
	content.add_child(list_scroll)
	var empty := UiKit.label("No matching avatars", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	empty.hide()
	content.add_child(empty)
	var use_button := UiKit.button("Use avatar", UiKit.BUTTON_GREEN, 64, 26)
	content.add_child(use_button)

	var beaten := HunterId.beaten_rivals(profile)
	var rivals := HunterId.rival_characters()
	var people: Array[String] = [HunterId.PROFESSAUR]
	for character in beaten:
		people.append("rival:%s" % character)
	var locked: Array[String] = []
	for character in rivals:
		if not character in beaten:
			locked.append("rival:%s" % character)
	var dinos := HunterId.avatar_choices(profile, Session.catalog).filter(
			func(id: String) -> bool: return id.begins_with("dino:"))
	# Each section: its heading, a hint shown when not searching, and a grid of tiles.
	var sections: Array[Dictionary] = []
	var entries: Array[Dictionary] = []
	var show_selection := func() -> void:
		for child in preview.get_children():
			preview.remove_child(child)
			child.queue_free()
		preview.add_child(Avatar.portrait(selection.id, 160, Palette.HIGHLIGHT, 5))
		caption.text = Avatar.display_name(selection.id)
		for entry in entries:
			var on: bool = entry.id == selection.id and not entry.locked
			entry.ring.visible = on
			entry.badge.visible = on
			entry.label.add_theme_color_override("font_color",
					Palette.HIGHLIGHT if on else (Palette.TEXT_DIM if entry.locked else Palette.TEXT))
	var select := func(id: String) -> void:
		Sound.play(&"tap")
		selection.id = id
		show_selection.call()
	for part in [["Rivals", people, locked], ["Your dinos (%d)" % dinos.size(), dinos, []]]:
		var heading := UiKit.title(part[0], 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
		lists.add_child(heading)
		var hint: Control = null
		if not part[2].is_empty():
			hint = UiKit.label("Beat rivals on the Journey to unlock them: %d of %d so far."
					% [beaten.size(), rivals.size()], 22, Palette.TEXT_DIM)
			lists.add_child(hint)
		var grid := UiKit.grid(4, 12)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lists.add_child(grid)
		var section := {"heading": heading, "hint": hint, "grid": grid, "entries": []}
		for id in part[1] + part[2]:
			var entry := _avatar_tile(id, id in part[2])
			entry.button.pressed.connect(func() -> void: select.call(id))
			grid.add_child(entry.tile)
			section.entries.append(entry)
			entries.append(entry)
		sections.append(section)

	search.text_changed.connect(func(query: String) -> void:
		var words := query.strip_edges().to_lower()
		var any := false
		for section in sections:
			var shown := false
			for entry in section.entries:
				entry.tile.visible = words == "" or (not entry.locked
						and Avatar.display_name(entry.id).to_lower().contains(words))
				shown = shown or entry.tile.visible
			section.heading.visible = shown
			section.grid.visible = shown
			if section.hint:
				section.hint.visible = words == ""
			any = any or shown
		empty.visible = not any)
	show_selection.call()
	if query != "":
		search.text = query
		search.text_changed.emit(query)
	var layer := _popup("Choose your avatar", content, false, list_scroll)
	use_button.pressed.connect(func() -> void:
		profile.avatar = selection.id
		Session.save()
		Sound.play(&"card_pick")
		layer.queue_free()
		_refresh())


## One avatar in the picker, with its name under it. The selected one gets a gold ring around its
## frame and a check mark; a locked rival is a dark shape with a lock.
func _avatar_tile(id: String, locked: bool) -> Dictionary:
	var tile := UiKit.vbox(4)
	tile.custom_minimum_size.x = PICKER_TILE
	var button := UiKit.let_scroll(Button.new())
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = locked
	button.custom_minimum_size = Vector2(PICKER_TILE, PICKER_AVATAR + 2 * RING_GAP)
	var spot := Vector2((PICKER_TILE - PICKER_AVATAR) / 2, RING_GAP)
	var ring := Panel.new()
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Palette.HIGHLIGHT
	style.set_border_width_all(4)
	style.set_corner_radius_all(Avatar.corner_radius(PICKER_AVATAR + 2 * RING_GAP, id.begins_with("dino:")))
	ring.add_theme_stylebox_override("panel", style)
	ring.position = spot - Vector2.ONE * RING_GAP
	ring.size = Vector2.ONE * (PICKER_AVATAR + 2 * RING_GAP)
	ring.hide()
	button.add_child(ring)
	var art := Avatar.portrait(id, PICKER_AVATAR, Palette.PANEL_BORDER, 4, locked)
	art.position = spot
	button.add_child(art)
	var badge := TextureRect.new()
	badge.texture = Icons.texture(&"check", 17)
	badge.position = spot + Vector2.ONE * (PICKER_AVATAR - 28)
	badge.hide()
	button.add_child(badge)
	if locked:
		var lock := TextureRect.new()
		lock.texture = Icons.texture(&"lock", 20)
		lock.position = spot + Vector2.ONE * (PICKER_AVATAR - 40) / 2
		lock.modulate = Color(1, 1, 1, 0.8)
		button.add_child(lock)
	for node in button.get_children():
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(button)
	var label := UiKit.label("Locked" if locked else Avatar.display_name(id), 18,
			Palette.TEXT_DIM if locked else Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	label.custom_minimum_size.x = PICKER_TILE
	tile.add_child(label)
	return {"id": id, "locked": locked, "tile": tile, "button": button, "ring": ring, "badge": badge, "label": label}


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
