extends VBoxContainer
## Eggs tab: one Hatch button (Rare clutches first), the shop (check-in, clutch, Rare clutch) as
## three tiles, and the odds.

var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	add_child(UiKit.title("Fossil eggs"))
	add_child(UiKit.label("Each clutch holds %d eggs, and each egg hatches one dino. Duplicates melt into Amber, which crafts the dinos you're missing in the Dex." \
			% Economy.EGGS_PER_CLUTCH, 29, Palette.TEXT_DIM))
	_body = UiKit.vbox(14)
	add_child(UiKit.vscroll(_body))
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	var profile := Session.profile

	var banner := ClutchBanner.new()
	banner.clutches = profile.clutches
	banner.rare_clutches = profile.rare_clutches
	banner.hatch_pressed.connect(func() -> void: _hatch(profile.clutches <= 0))
	_body.add_child(banner)
	# One big Hatch button. Rare clutches go first: there's no reason to save them.
	var rare_first := profile.rare_clutches > 0
	var waiting := profile.rare_clutches if rare_first else profile.clutches
	var hatch_text := "Hatch a Rare clutch" if rare_first else "Hatch a clutch"
	if waiting > 1:
		hatch_text += "  (%d)" % waiting
	var hatch := UiKit.let_scroll(UiKit.button(hatch_text, UiKit.BUTTON_RARE if rare_first else UiKit.BUTTON_GREEN, 110, 34))
	hatch.disabled = waiting <= 0
	hatch.pressed.connect(_hatch.bind(rare_first))
	_body.add_child(hatch)

	# The shop: check-in, a clutch and a Rare clutch as three tiles.
	var shop := UiKit.hbox(10)
	var checked_in := not profile.can_claim_daily(SaveStore.today())
	var bonus: Dictionary = Economy.CHECKIN_BONUSES[profile.checkin_day]
	var bonus_short := "+%d Amber" % bonus.get("amber", 0)
	if bonus.has("clutches"):
		bonus_short = "+%d clutch" % bonus["clutches"]
	elif bonus.has("rare_clutches"):
		bonus_short = "+Rare clutch"
	var checkin := _tile("Check-in", "Done today ✔" if checked_in else "Day %d: %s" % [profile.checkin_day + 1, bonus_short],
			&"egg", Palette.PANEL if checked_in else UiKit.BUTTON_GREEN)
	checkin.pressed.connect(func() -> void: CheckInView.open().closed.connect(_refresh))
	shop.add_child(checkin)
	for offer in [[false, Economy.CLUTCH_PRICE], [true, Economy.RARE_CLUTCH_PRICE]]:
		var rare: bool = offer[0]
		var price: int = offer[1]
		var short := price - profile.amber
		var buy := _tile("Rare clutch" if rare else "Clutch", "%d Amber" % price if short <= 0 else "Need %d more" % short,
				&"egg", UiKit.BUTTON_RARE if rare else UiKit.BUTTON_AMBER)
		buy.disabled = short > 0
		buy.pressed.connect(func() -> void:
			if profile.buy_rare_clutch() if rare else profile.buy_clutch():
				Sound.play(&"amber")
				Session.save()
				_refresh())
		shop.add_child(buy)
	_body.add_child(shop)

	_body.add_child(UiKit.panel(_odds_box()))

	if Session.autoplay and profile.clutches > 0 and profile.tour_done:
		await get_tree().create_timer(0.8).timeout
		_hatch(false)


func _odds_box() -> VBoxContainer:
	var box := UiKit.vbox(6)
	box.add_child(UiKit.label("Odds for each egg", 30))
	var odds := UiKit.grid(3, 6)
	for heading in ["", "Clutch", "Rare clutch"]:
		var label := UiKit.label(heading, 28, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
		label.custom_minimum_size = Vector2(200 if heading == "" else 150, 0)
		odds.add_child(label)
	for rarity in DinoDef.RARITY_NAMES.size():
		odds.add_child(UiKit.label(DinoDef.RARITY_NAMES[rarity], 29, Palette.RARITY_COLORS[rarity],
				HORIZONTAL_ALIGNMENT_LEFT, false))
		for table in [Economy.RARITY_ODDS, Economy.RARE_CLUTCH_ODDS]:
			odds.add_child(UiKit.label("%d%%" % roundi(table[rarity] * 100), 29, Palette.TEXT,
					HORIZONTAL_ALIGNMENT_LEFT, false))
	box.add_child(odds)
	var left := Economy.PITY_CLUTCHES - Session.profile.clutches_without_epic
	box.add_child(UiKit.label("Shiny: 1 in %d eggs (same stats, special look)." % roundi(1.0 / Economy.SHINY_ODDS),
			28, Palette.TEXT_DIM))
	box.add_child(UiKit.label("Guaranteed Epic or better at least every %d clutches. Yours: within the next %d." \
			% [Economy.PITY_CLUTCHES, left], 28, Palette.TEXT_DIM))
	return box


## A shop tile: an egg on top, a name and a price or status under it.
func _tile(title: String, detail: String, icon_name: StringName, color: Color) -> Button:
	var tile := UiKit.let_scroll(UiKit.button("%s\n%s" % [title, detail], color, 150, 22))
	tile.icon = Icons.texture(icon_name, 44)
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_stretch_ratio = 1.0
	tile.clip_text = true
	# The egg keeps its own colors (a purple egg for a Rare clutch).
	var egg := Color.WHITE if color != UiKit.BUTTON_RARE else CheckInView.RARE_TINT.lightened(0.45)
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		tile.add_theme_color_override(color_name, egg)
	tile.add_theme_color_override("icon_disabled_color", Color(egg, 0.45))
	return tile


func _hatch(rare := false) -> void:
	var results := Session.profile.hatch_clutch(Session.catalog, rare)
	if results.is_empty():
		return
	Sound.play(&"clutch_open")
	# Save before the reveal so closing the app mid-animation can't reroll the clutch.
	Session.save()
	var view := HatchView.create(results)
	view.finished.connect(_refresh)
	get_tree().current_scene.add_child(view)
	_refresh()
