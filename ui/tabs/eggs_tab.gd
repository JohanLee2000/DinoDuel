extends VBoxContainer
## Eggs tab: one Hatch button (asks Clutch or Rare clutch when you have both), the shop (check-in,
## clutch, Rare clutch) as three tiles, and the odds.

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
	banner.hatch_pressed.connect(_hatch_any)
	_body.add_child(banner)
	# One big Hatch button. With both kinds waiting, it asks which (_choose_clutch).
	var total := profile.clutches + profile.rare_clutches
	var only_rare := profile.clutches == 0 and profile.rare_clutches > 0
	var hatch_text := "Hatch a Rare clutch" if only_rare else "Hatch a clutch"
	if total > 1:
		hatch_text += "  (%d)" % total
	var hatch := UiKit.let_scroll(UiKit.button(hatch_text, UiKit.BUTTON_RARE if only_rare else UiKit.BUTTON_GREEN, 110, 34))
	hatch.disabled = total <= 0
	hatch.pressed.connect(_hatch_any)
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
func _tile(title: String, detail: String, icon_name: StringName, color: Color, font_size := 22) -> Button:
	var tile := UiKit.let_scroll(UiKit.button("%s\n%s" % [title, detail], color, 150, font_size))
	tile.icon = Icons.texture(icon_name, font_size * 2)
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


## Hatches a clutch; if there are both normal and Rare clutches, asks which first.
func _hatch_any() -> void:
	var profile := Session.profile
	if profile.clutches > 0 and profile.rare_clutches > 0:
		_choose_clutch()
	else:
		_hatch(profile.rare_clutches > 0)


func _choose_clutch() -> void:
	var profile := Session.profile
	var dialog := UiKit.modal_layer(0.8)
	dialog.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			dialog.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(16)
	column.custom_minimum_size.x = 560
	column.add_child(UiKit.title("Which clutch?", 38, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("Rare clutches have better odds: %d%% Epic and %d%% Legendary per egg." \
			% [roundi(Economy.RARE_CLUTCH_ODDS[DinoDef.Rarity.EPIC] * 100), roundi(Economy.RARE_CLUTCH_ODDS[DinoDef.Rarity.LEGENDARY] * 100)],
			26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UiKit.hbox(12)
	for rare in [false, true]:
		var count: int = profile.rare_clutches if rare else profile.clutches
		var pick := _tile("Rare clutch" if rare else "Clutch", "%d waiting" % count, &"egg",
				UiKit.BUTTON_RARE if rare else UiKit.BUTTON_GREEN, 28)
		pick.custom_minimum_size.y = 190
		pick.pressed.connect(func() -> void:
			dialog.queue_free()
			_hatch(rare))
		row.add_child(pick)
	column.add_child(row)
	var cancel := UiKit.button("Not now", UiKit.BUTTON_GRAY, 68, 26)
	cancel.pressed.connect(dialog.queue_free)
	column.add_child(cancel)
	var panel := UiKit.panel(column, Palette.PANEL, 24)
	# Taps on the panel stay here; only taps outside it close the popup.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	dialog.add_child(center)
	get_tree().current_scene.add_child(dialog)


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
