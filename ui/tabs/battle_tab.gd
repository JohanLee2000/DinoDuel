extends VBoxContainer
## Battle tab: who you can fight. One rival for now; the Journey map replaces this in M3.


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var rival := Session.rival
	var profile := Session.profile

	var info := UiKit.vbox(10)
	info.add_child(UiKit.title(rival.display_name))
	info.add_child(UiKit.label(rival.intro, 20, Palette.TEXT_DIM))
	info.add_child(UiKit.label("Brings these 6, picks 3:", 20, Palette.TEXT))
	var brings := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	for dino in rival.brings:
		brings.add_child(DinoCard.create(dino, DinoCard.Mode.MINI))
	info.add_child(brings)
	info.add_child(UiKit.label("Your record: %d wins, %d losses" % [profile.wins, profile.losses],
			20, Palette.TEXT_DIM))
	add_child(UiKit.panel(info))

	add_child(UiKit.label("Win: %d egg clutch + %d Amber.   Lose: %d Amber." % [
			Economy.WIN_CLUTCHES, Economy.WIN_AMBER, Economy.LOSS_AMBER], 20, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))

	var lineup := profile.lineup_defs(Session.catalog)
	var problem := ""
	if lineup.size() != PartyRules.BRING_SIZE:
		problem = "Pick %d dinos in the Party tab first." % PartyRules.BRING_SIZE
	elif not PartyRules.has_valid_pick(lineup):
		problem = "Your 3 cheapest dinos cost more than %d Party Points. Swap in a cheaper one in the Party tab." 				% PartyRules.POINT_CAP
	var ready_to_fight := problem == ""
	var challenge := UiKit.button("Challenge %s" % rival.display_name, UiKit.BUTTON_GREEN, 110, 34)
	challenge.disabled = not ready_to_fight
	challenge.pressed.connect(Session.go_to_pre_battle)
	add_child(challenge)
	if not ready_to_fight:
		add_child(UiKit.label(problem, 20, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	add_child(UiKit.label("More rivals are on the way.", 18, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	if Session.autoplay and ready_to_fight:
		await get_tree().create_timer(0.8).timeout
		Session.go_to_pre_battle()
