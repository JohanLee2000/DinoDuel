extends VBoxContainer
## Eggs tab: hatch clutches, claim the daily clutch, buy clutches with Amber, see the odds.

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

	var count := UiKit.label("%d clutch%s ready to hatch" % [profile.clutches,
			"" if profile.clutches == 1 else "es"], 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(count)
	var hatch := UiKit.button("Hatch a clutch", UiKit.BUTTON_GREEN, 110, 34)
	hatch.disabled = profile.clutches <= 0
	hatch.pressed.connect(_hatch)
	_body.add_child(hatch)

	var today := SaveStore.today()
	var daily := UiKit.button("Claim today's free clutch", UiKit.BUTTON_AMBER)
	if not profile.can_claim_daily(today):
		daily.text = "Free clutch claimed. Come back tomorrow!"
		daily.disabled = true
	daily.pressed.connect(func() -> void:
		Sound.play(&"clutch_open")
		profile.claim_daily(today)
		Session.save()
		_refresh())
	_body.add_child(daily)

	var buy := UiKit.button("Buy a clutch for %d Amber" % Economy.CLUTCH_PRICE, UiKit.BUTTON_GRAY)
	buy.disabled = profile.amber < Economy.CLUTCH_PRICE
	buy.pressed.connect(func() -> void:
		Sound.play(&"amber")
		profile.buy_clutch()
		Session.save()
		_refresh())
	_body.add_child(buy)

	_body.add_child(UiKit.panel(_odds_box()))

	if Session.autoplay and profile.clutches > 0:
		await get_tree().create_timer(0.8).timeout
		_hatch()


func _odds_box() -> VBoxContainer:
	var box := UiKit.vbox(6)
	box.add_child(UiKit.label("Odds for each egg", 28))
	var odds := UiKit.grid(2, 6)
	for rarity in DinoDef.RARITY_NAMES.size():
		var name_label := UiKit.label(DinoDef.RARITY_NAMES[rarity], 24, Palette.RARITY_COLORS[rarity],
				HORIZONTAL_ALIGNMENT_LEFT, false)
		name_label.custom_minimum_size = Vector2(200, 0)
		odds.add_child(name_label)
		odds.add_child(UiKit.label("%d%%" % roundi(Economy.RARITY_ODDS[rarity] * 100), 24,
				Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	box.add_child(odds)
	var left := Economy.PITY_CLUTCHES - Session.profile.clutches_without_epic
	box.add_child(UiKit.label("Shiny: 1 in %d eggs (same stats, special look)." % roundi(1.0 / Economy.SHINY_ODDS),
			22, Palette.TEXT_DIM))
	box.add_child(UiKit.label("Guaranteed Epic or better at least every %d clutches. Yours: within the next %d." \
			% [Economy.PITY_CLUTCHES, left], 22, Palette.TEXT_DIM))
	return box


func _hatch() -> void:
	var results := Session.profile.hatch_clutch(Session.catalog)
	if results.is_empty():
		return
	Sound.play(&"clutch_open")
	# Save before the reveal so closing the app mid-animation can't reroll the clutch.
	Session.save()
	var view := HatchView.create(results)
	view.finished.connect(_refresh)
	get_tree().current_scene.add_child(view)
	_refresh()
