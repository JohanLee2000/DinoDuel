extends VBoxContainer
## Party tab: choose the 6 dinos you bring to battles. Before each battle you pick 3 of them.

var _lineup_row: HBoxContainer
var _grid: GridContainer
var _status: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Your party"))
	add_child(UiKit.label("Bring %d dinos. Before each battle you see your rival's 6 and pick 3." \
			% PartyRules.BRING_SIZE, 20, Palette.TEXT_DIM))
	_lineup_row = UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	add_child(_lineup_row)
	_status = UiKit.label("", 20, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)
	_grid = UiKit.grid(3)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder := CenterContainer.new()
	holder.add_child(_grid)
	add_child(UiKit.vscroll(holder))
	_refresh()


func _refresh() -> void:
	var profile := Session.profile
	for child in _lineup_row.get_children() + _grid.get_children():
		child.queue_free()

	for id in profile.lineup:
		var mini := DinoCard.create(Session.catalog.find(id), DinoCard.Mode.MINI, null, profile.is_shiny(id))
		mini.pressed.connect(_toggle.bind(id))
		_lineup_row.add_child(mini)
	for i in PartyRules.BRING_SIZE - profile.lineup.size():
		_lineup_row.add_child(_empty_slot())

	var owned := _owned_sorted()
	_status.text = "%d/%d in your party · tap to add or remove · hold to zoom · %d collected" % [
			profile.lineup.size(), PartyRules.BRING_SIZE, owned.size()]
	_status.remove_theme_color_override("font_color")
	var lineup := profile.lineup_defs(Session.catalog)
	if lineup.size() == PartyRules.BRING_SIZE and not PartyRules.has_valid_pick(lineup):
		_status.text = "Too expensive: your 3 cheapest cost more than %d Party Points, so you can't battle. Swap one for a cheaper dino." 				% PartyRules.POINT_CAP
		_status.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	for dino in owned:
		var card := DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino.id))
		var in_lineup := dino.id in profile.lineup
		card.selected = in_lineup
		card.set_badge("IN PARTY" if in_lineup else "")
		card.dimmed = not in_lineup and profile.lineup.size() >= PartyRules.BRING_SIZE
		card.pressed.connect(_toggle.bind(dino.id))
		_grid.add_child(card)


func _toggle(id: StringName) -> void:
	Sound.play(&"card_pick")
	var lineup := Session.profile.lineup.duplicate()
	if id in lineup:
		lineup.erase(id)
	elif lineup.size() < PartyRules.BRING_SIZE:
		lineup.append(id)
	else:
		_status.text = "Your party is full. Tap one above to take it out first."
		return
	Session.profile.set_lineup(lineup)
	Session.save()
	_refresh()


func _owned_sorted() -> Array[DinoDef]:
	var owned: Array[DinoDef] = []
	for dino in Session.catalog.dinos:
		if Session.profile.owns(dino.id):
			owned.append(dino)
	owned.sort_custom(func(a: DinoDef, b: DinoDef) -> bool:
		if a.dino_type != b.dino_type:
			return a.dino_type < b.dino_type
		return a.rarity > b.rarity)
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
