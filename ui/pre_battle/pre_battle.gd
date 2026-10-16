extends Control
## Before a battle: both lineups of 6 are revealed and you secretly pick 3 of yours within the
## point cap. The rival picks its 3 when the battle starts, without seeing yours. Under the cards a
## summary shows progress (picked, points as a bar in each pick's tier color), what to do next,
## and whether each party bonus is on (2026-10-15).

enum Bonus { OFF, PENDING, ON }

var _cards: Array[DinoCard] = []
var _picked: Array[DinoDef] = []
var _count_label: Label
var _points_bar: HBoxContainer
var _guide: Label
var _era_chip: PanelContainer
var _balance_chip: PanelContainer
var _flashing := false

@onready var _rival_panel: PanelContainer = %RivalPanel
@onready var _rival_label: Label = %RivalLabel
@onready var _rival_brings: HBoxContainer = %RivalBrings
@onready var _hint: Label = %Hint
@onready var _grid: GridContainer = %Grid
@onready var _summary: Label = %Summary
@onready var _battle_button: Button = %BattleButton


func _ready() -> void:
	Sound.music(&"main")
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.PANEL
	panel_style.border_color = Palette.PANEL_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	%Title.add_theme_font_override("font", Fonts.title())
	_rival_panel.add_theme_stylebox_override("panel", panel_style)
	UiKit.style_button(_battle_button, UiKit.BUTTON_GREEN)
	UiKit.style_button(%BackButton, UiKit.BUTTON_GRAY)

	var rival := Session.rival
	_rival_label.text = "%s brings these 6 and will pick 3:" % rival.display_name
	_rival_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The rival's sprite beside who they are.
	var heading := UiKit.hbox(12)
	_rival_label.get_parent().add_child(heading)
	_rival_label.get_parent().move_child(heading, 0)
	var sprite := TextureRect.new()
	sprite.texture = RivalArt.sprite(rival.character)
	sprite.custom_minimum_size = Vector2(120, 120)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	heading.add_child(sprite)
	_rival_label.reparent(heading)
	_rival_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for dino in rival.brings:
		_rival_brings.add_child(DinoCard.create(dino, DinoCard.Mode.MINI))
	var notes := "Stars: one for each of your dinos still standing when you win."
	if not rival.alphas.is_empty():
		var names: Array[String] = []
		for dino in rival.brings:
			if dino.id in rival.alphas:
				names.append(dino.display_name)
		notes = "Alpha %s: extra Health and Attack, and always plays. " % " and ".join(names) + notes
	if rival.meteor_turn > 0:
		notes += " The meteor shower starts on turn %d." % rival.meteor_turn
	_rival_label.get_parent().get_parent().add_child(UiKit.label(notes, 24, Palette.TEXT_DIM))

	var profile := Session.profile
	# Saved parties: switching shows that party's 6 (picks still in it stay picked).
	var slots := PartySlots.new()
	slots.with_rename = false
	slots.switched.connect(func() -> void:
		_picked.assign(_picked.filter(func(dino: DinoDef) -> bool: return dino.id in profile.lineup))
		_build_cards()
		_refresh())
	_hint.add_sibling(slots)
	_build_cards()
	# Keep last battle's pick if those dinos are still in the lineup.
	for dino in Session.player_party:
		if dino.id in profile.lineup and _picked.size() < PartyRules.PARTY_SIZE:
			_picked.append(dino)
	_build_summary()
	if Session.dev_prepick > 0:
		_picked.clear()
		for card in _cards:
			if _picked.size() < Session.dev_prepick and PartyRules.points(_picked) + PartyRules.points_of(card.def) <= PartyRules.POINT_CAP:
				_picked.append(card.def)
		Session.dev_prepick = 0
	_battle_button.pressed.connect(func() -> void: Session.start_battle(_picked.duplicate()))
	%BackButton.pressed.connect(Session.go_to_main.bind(Session.Tab.BATTLE))
	_refresh()

	if Session.autoplay:
		_picked = BattleAI.new(randi()).choose_party(profile.lineup_defs(Session.catalog))
		_refresh()
		await get_tree().create_timer(1.0).timeout
		Session.start_battle(_picked)


## Your 6 (the open party slot's lineup) as cards, with their mastery ribbons.
func _build_cards() -> void:
	for card in _cards:
		_grid.remove_child(card)
		card.queue_free()
	_cards.clear()
	var profile := Session.profile
	for dino in profile.lineup_defs(Session.catalog):
		var card := DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino.id))
		card.mastery_rank = Mastery.rank_of(profile, dino.id)
		card.pressed.connect(_toggle.bind(dino))
		_grid.add_child(card)
		_cards.append(card)


func _toggle(dino: DinoDef) -> void:
	Sound.play(&"card_pick")
	if dino in _picked:
		_picked.erase(dino)
	elif _picked.size() >= PartyRules.PARTY_SIZE:
		_flash_guide("You've picked 3. Tap a picked dino to swap it out.")
		return
	elif PartyRules.points(_picked) + PartyRules.points_of(dino) > PartyRules.POINT_CAP:
		_flash_guide("%s would go over the %d-point cap." % [dino.display_name, PartyRules.POINT_CAP])
		return
	else:
		_picked.append(dino)
	_refresh()


func _refresh() -> void:
	var points := PartyRules.points(_picked)
	for card in _cards:
		var is_picked := card.def in _picked
		card.selected = is_picked
		card.set_badge("PICKED" if is_picked else "")
		var fits := _picked.size() < PartyRules.PARTY_SIZE \
				and points + PartyRules.points_of(card.def) <= PartyRules.POINT_CAP
		card.dimmed = not is_picked and not fits

	var left := PartyRules.PARTY_SIZE - _picked.size()
	_count_label.text = "%d / %d selected  •  %d / %d points" % [_picked.size(), PartyRules.PARTY_SIZE,
			points, PartyRules.POINT_CAP]
	# The bar: one segment per point, colored by the tier of the pick that uses it.
	var segment := 0
	for dino in _picked:
		for i in PartyRules.points_of(dino):
			_paint_segment(segment, Palette.RARITY_COLORS[dino.rarity])
			segment += 1
	while segment < PartyRules.POINT_CAP:
		_paint_segment(segment, Color(1, 1, 1, 0.1))
		segment += 1
	if not _flashing:
		_guide.text = _guide_text(points)
		_guide.add_theme_color_override("font_color", Palette.TEXT)
	_show_bonuses()
	_battle_button.disabled = PartyRules.validate(_picked) != ""
	_battle_button.text = "Start battle" if left == 0 else "Choose %d more" % left
	# The coach spells it out on the first battle; otherwise the summary says it all.
	_hint.visible = Session.wants_coach()
	if Session.wants_coach():
		_hint.text = "First battle! Tap 3 of your dinos. The PTS on each card must add up to %d or less. One Land, one Sky and one Sea gives each +2 HP." \
				% PartyRules.POINT_CAP
		_hint.add_theme_color_override("font_color", Palette.HIGHLIGHT)


## What to do next, e.g. "Choose 1 more dino costing 3 points or less."
func _guide_text(points: int) -> String:
	var left := PartyRules.PARTY_SIZE - _picked.size()
	var room := PartyRules.POINT_CAP - points
	if left == 0:
		return "Ready! Tap a picked dino to swap it out."
	if _cards.size() < PartyRules.PARTY_SIZE:
		return "%s has only %d dino%s. Add more on the Party tab." % [Session.profile.party_name(Session.profile.party_slot),
				_cards.size(), "" if _cards.size() == 1 else "s"]
	if _picked.is_empty():
		return "Choose %d dinos costing %d points or less in total." % [PartyRules.PARTY_SIZE, PartyRules.POINT_CAP]
	var fits := _cards.any(func(card: DinoCard) -> bool:
		return not card.def in _picked and PartyRules.points_of(card.def) <= room)
	if not fits:
		return "None of your others fit in %d point%s. Tap a picked dino to swap it out." % [room, "" if room == 1 else "s"]
	if left == 1:
		return "Choose 1 more dino costing %d point%s or less." % [room, "" if room == 1 else "s"]
	return "Choose %d more dinos with %d points between them." % [left, room]


## Era bond and Balanced as two chips: gold when on, plain while still possible, dim when not.
func _show_bonuses() -> void:
	var count := _picked.size()
	var same_era := _picked.all(func(d: DinoDef) -> bool: return d.era == _picked[0].era)
	if count == 0:
		_set_chip(_era_chip, "Era bond: all 3 from one era", Bonus.PENDING)
	elif not same_era:
		_set_chip(_era_chip, "No era bond: mixed eras", Bonus.OFF)
	elif count == PartyRules.PARTY_SIZE:
		_set_chip(_era_chip, "Era bond on: +%d ATK +%d SPD" % [PartyRules.ERA_BOND_ATTACK, PartyRules.ERA_BOND_SPEED], Bonus.ON)
	else:
		_set_chip(_era_chip, "Era bond: %d more %s" % [PartyRules.PARTY_SIZE - count,
				DinoDef.ERA_NAMES[_picked[0].era]], Bonus.PENDING)

	var missing: Array[String] = []
	for type in DinoDef.TYPE_NAMES.size():
		if not _picked.any(func(d: DinoDef) -> bool: return d.dino_type == type):
			missing.append(DinoDef.TYPE_NAMES[type])
	if count == 0:
		_set_chip(_balance_chip, "Balanced: Land + Sky + Sea", Bonus.PENDING)
	elif missing.size() != PartyRules.PARTY_SIZE - count:
		_set_chip(_balance_chip, "Not balanced: two of a type", Bonus.OFF)
	elif missing.is_empty():
		_set_chip(_balance_chip, "Balanced on: +%d HP" % PartyRules.BALANCED_HEALTH, Bonus.ON)
	else:
		_set_chip(_balance_chip, "Balanced: needs %s" % " + ".join(missing), Bonus.PENDING)


## The summary under the cards (it takes the place of the old one-line Summary label).
func _build_summary() -> void:
	var box := UiKit.vbox(8)
	_count_label = UiKit.label("", 31, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_count_label.add_theme_font_override("font", Fonts.bold())
	box.add_child(_count_label)
	_points_bar = UiKit.hbox(4)
	for i in PartyRules.POINT_CAP:
		var piece := Panel.new()
		piece.custom_minimum_size = Vector2(0, 14)
		piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		piece.add_theme_stylebox_override("panel", style)
		_points_bar.add_child(piece)
	box.add_child(_points_bar)
	_guide = UiKit.label("", 27, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_guide)
	var chips := UiKit.hbox(10)
	_era_chip = _bonus_chip()
	_balance_chip = _bonus_chip()
	chips.add_child(_era_chip)
	chips.add_child(_balance_chip)
	box.add_child(chips)
	var summary: Label = %Summary
	summary.add_sibling(UiKit.panel(box, Palette.PANEL, 12))
	summary.visible = false


func _paint_segment(index: int, color: Color) -> void:
	var style := _points_bar.get_child(index).get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = color


func _bonus_chip() -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", style)
	var text := UiKit.label("", 23, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", Fonts.bold())
	chip.add_child(text)
	return chip


func _set_chip(chip: PanelContainer, text: String, state: Bonus) -> void:
	var style := chip.get_theme_stylebox("panel") as StyleBoxFlat
	var label := chip.get_child(0) as Label
	label.text = text
	match state:
		Bonus.ON:
			style.bg_color = Color(Palette.HIGHLIGHT, 0.2)
			style.border_color = Palette.HIGHLIGHT
			label.add_theme_color_override("font_color", Palette.HIGHLIGHT)
		Bonus.PENDING:
			style.bg_color = Color(1, 1, 1, 0.05)
			style.border_color = Color(Palette.TEXT, 0.35)
			label.add_theme_color_override("font_color", Palette.TEXT)
		Bonus.OFF:
			style.bg_color = Color(0, 0, 0, 0.2)
			style.border_color = Color(Palette.TEXT, 0.12)
			label.add_theme_color_override("font_color", Color(Palette.TEXT, 0.5))


## A short warning in the guide line (e.g. over the cap), then back to the usual text.
func _flash_guide(text: String) -> void:
	Sound.play(&"error")
	_flashing = true
	_guide.text = text
	_guide.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		_flashing = false
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Session.go_to_main(Session.Tab.BATTLE)
