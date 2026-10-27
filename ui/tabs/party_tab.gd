extends VBoxContainer
## Party tab: choose the 6 dinos you bring to battles. Before each battle you pick 3 of them.
## Three saved parties (PartySlots) to switch between and name. Share the open party's code, or
## duel a friend's (PartyShareView, FriendDuelView). A search, filters and sorting
## (CollectionFilter) help find dinos in a big collection. New dinos have a dot until tapped.

var _slots: PartySlots
var _lineup_row: HBoxContainer
var _grid: GridContainer
var _status: Label
var _filter: CollectionFilter
var _scroll: ScrollContainer
var _empty: Label
## id -> its card in the grid.
var _cards := {}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	# Compact header (Jo, 2026-10-26): Share and Duel beside the title, no intro text (How to play
	# and the tour explain it), a one-line status, and Sort inside the Filters panel.
	var header := UiKit.hbox(10)
	var heading := UiKit.title("Your party", 34, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	var share := UiKit.icon_button("Share", &"share", UiKit.BUTTON_EMERALD, 56, 23)
	share.custom_minimum_size.x = 150
	share.pressed.connect(func() -> void:
		Sound.play(&"tap")
		PartyShareView.open())
	header.add_child(share)
	var duel := UiKit.icon_button("Duel a friend", &"move_bite", UiKit.BUTTON_RED, 56, 23)
	duel.custom_minimum_size.x = 210
	duel.pressed.connect(func() -> void:
		Sound.play(&"tap")
		FriendDuelView.open())
	header.add_child(duel)
	add_child(header)
	_slots = PartySlots.new()
	_slots.switched.connect(_refresh)
	add_child(_slots)
	_lineup_row = UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	add_child(_lineup_row)
	_status = UiKit.label("", 29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)
	_filter = CollectionFilter.create("party", false, true)
	_filter.changed.connect(func() -> void:
		_apply_filter()
		_scroll.scroll_vertical = 0)
	add_child(_filter)
	_empty = UiKit.label("No dinos match. Try another search, or clear the filters.", 29, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_empty)
	_grid = UiKit.grid(3)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder := CenterContainer.new()
	holder.add_child(_grid)
	_scroll = UiKit.vscroll(holder)
	add_child(_scroll)
	_refresh()


func _refresh() -> void:
	var profile := Session.profile
	for child in _lineup_row.get_children():
		child.queue_free()
	# Removed right away (not just queued), so _apply_filter's ordering only sees the new cards.
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	for id in profile.lineup:
		var mini := DinoCard.create(Session.catalog.find(id), DinoCard.Mode.MINI, null, profile.is_shiny(id))
		mini.mastery_rank = Mastery.rank_of(profile, id)
		mini.pressed.connect(_toggle.bind(id))
		_lineup_row.add_child(mini)
	for i in PartyRules.BRING_SIZE - profile.lineup.size():
		_lineup_row.add_child(_empty_slot())

	var owned := _owned()
	_status.text = "%d/%d in party · tap to add or remove · hold to zoom" % [profile.lineup.size(), PartyRules.BRING_SIZE]
	_status.remove_theme_color_override("font_color")
	var lineup := profile.lineup_defs(Session.catalog)
	if lineup.size() == PartyRules.BRING_SIZE and not PartyRules.has_valid_pick(lineup):
		_status.text = "Too expensive: your 3 cheapest cost more than %d Party Points, so you can't battle. Swap one for a cheaper dino." \
				% PartyRules.POINT_CAP
		_status.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	for dino in owned:
		var card := DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino.id))
		var in_lineup := dino.id in profile.lineup
		card.selected = in_lineup
		card.set_badge("IN PARTY" if in_lineup else "")
		card.dimmed = not in_lineup and profile.lineup.size() >= PartyRules.BRING_SIZE
		card.is_new = profile.is_new(dino.id)
		card.mastery_rank = Mastery.rank_of(profile, dino.id)
		card.pressed.connect(_toggle.bind(dino.id))
		_grid.add_child(card)
		_cards[dino.id] = card
	_apply_filter()


## Puts the cards in the chosen order and hides the ones the search and filters leave out.
func _apply_filter() -> void:
	var profile := Session.profile
	var order := _filter.sorted(_owned())
	var shown := 0
	for i in order.size():
		var card: DinoCard = _cards[order[i].id]
		_grid.move_child(card, i)
		card.visible = _filter.matches(order[i], profile)
		shown += 1 if card.visible else 0
	_empty.visible = shown == 0


func _toggle(id: StringName) -> void:
	Sound.play(&"card_pick")
	Session.profile.mark_viewed(id)
	var lineup := Session.profile.lineup.duplicate()
	if id in lineup:
		lineup.erase(id)
	elif lineup.size() < PartyRules.BRING_SIZE:
		lineup.append(id)
	else:
		_status.text = "Your party is full. Tap one above to take it out first."
		if _cards.has(id):
			_cards[id].is_new = false
		Session.save()
		return
	Session.profile.set_lineup(lineup)
	Session.save()
	_refresh()


func _owned() -> Array[DinoDef]:
	var owned: Array[DinoDef] = []
	for dino in Session.catalog.dinos:
		if Session.profile.owns(dino.id):
			owned.append(dino)
	return owned


func _empty_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = DinoCard.size_for(DinoCard.Mode.MINI)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS  # let drags reach the scroll area
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	slot.add_theme_stylebox_override("panel", style)
	var plus := UiKit.label("+", 40, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(plus)
	return slot
