extends VBoxContainer
## Eggs tab: hatch clutches (normal and Rare), the daily check-in, buy clutches with Amber, see the odds.

var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	add_child(UiKit.title("Fossil eggs"))
	add_child(UiKit.label("Each clutch holds %d eggs, and each egg hatches one dino. Duplicates melt into Amber, which crafts the dinos you're missing in the Dex." \
			% Economy.EGGS_PER_CLUTCH, 24, Palette.TEXT_DIM))
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
	var hatch := UiKit.button("Hatch a clutch", UiKit.BUTTON_GREEN, 110, 34)
	hatch.disabled = profile.clutches <= 0
	hatch.pressed.connect(_hatch.bind(false))
	_body.add_child(hatch)
	if profile.rare_clutches > 0:
		var rare := UiKit.button("Hatch a Rare clutch (%d)" % profile.rare_clutches, UiKit.BUTTON_RARE, 96, 32)
		rare.pressed.connect(_hatch.bind(true))
		_body.add_child(rare)

	var checkin := UiKit.button("Daily check-in: free clutch + %s" % CheckInView.bonus_text(profile.checkin_day),
			UiKit.BUTTON_GREEN)
	if not profile.can_claim_daily(SaveStore.today()):
		checkin.text = "Checked in today. Come back tomorrow!"
		checkin.disabled = true
	checkin.pressed.connect(func() -> void: CheckInView.open().closed.connect(_refresh))
	_body.add_child(checkin)

	# Buying: orange for a clutch, purple for a Rare one, dimmed until there's enough Amber.
	var shop := UiKit.hbox(12)
	for offer in [[false, Economy.CLUTCH_PRICE], [true, Economy.RARE_CLUTCH_PRICE]]:
		var rare: bool = offer[0]
		var price: int = offer[1]
		var short := price - profile.amber
		var price_text := "%d Amber" % price if short <= 0 else "%d Amber (need %d)" % [price, short]
		var buy := UiKit.icon_button("%s\n%s" % ["Rare clutch" if rare else "Clutch", price_text], &"egg",
				UiKit.BUTTON_RARE if rare else UiKit.BUTTON_AMBER, 104, 25,
				CheckInView.RARE_TINT.lightened(0.35) if rare else Color.WHITE)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.disabled = short > 0
		if buy.disabled:
			(buy.get_meta("caption") as Label).add_theme_color_override("font_color", Palette.TEXT_DIM)
			(buy.get_meta("glyph") as Control).modulate.a = 0.45
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
	box.add_child(UiKit.label("Odds for each egg", 28))
	var odds := UiKit.grid(3, 6)
	for heading in ["", "Clutch", "Rare clutch"]:
		var label := UiKit.label(heading, 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
		label.custom_minimum_size = Vector2(200 if heading == "" else 150, 0)
		odds.add_child(label)
	for rarity in DinoDef.RARITY_NAMES.size():
		odds.add_child(UiKit.label(DinoDef.RARITY_NAMES[rarity], 24, Palette.RARITY_COLORS[rarity],
				HORIZONTAL_ALIGNMENT_LEFT, false))
		for table in [Economy.RARITY_ODDS, Economy.RARE_CLUTCH_ODDS]:
			odds.add_child(UiKit.label("%d%%" % roundi(table[rarity] * 100), 24, Palette.TEXT,
					HORIZONTAL_ALIGNMENT_LEFT, false))
	box.add_child(odds)
	var left := Economy.PITY_CLUTCHES - Session.profile.clutches_without_epic
	box.add_child(UiKit.label("Shiny: 1 in %d eggs (same stats, special look)." % roundi(1.0 / Economy.SHINY_ODDS),
			22, Palette.TEXT_DIM))
	box.add_child(UiKit.label("Guaranteed Epic or better at least every %d clutches. Yours: within the next %d." \
			% [Economy.PITY_CLUTCHES, left], 22, Palette.TEXT_DIM))
	return box


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
