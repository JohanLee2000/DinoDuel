extends VBoxContainer
## Battle tab: the Journey stages in order, by chapter, each with the 6 dinos they bring, your best
## stars and your record. Locked stages open one by one. (Interim list: the illustrated Journey map
## replaces it, see docs/GAME_DESIGN.md.)

const BRING_CARD_WIDTH := 96.0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Journey"))
	add_child(UiKit.label("Every win: an egg clutch. Clearing a stage the first time pays a bonus. Stars: one per dino still standing.",
			28, Palette.TEXT_DIM))

	var problem := _party_problem()
	if problem != "":
		add_child(UiKit.label(problem, 29, Palette.HIGHLIGHT))

	var list := UiKit.vbox(14)
	var chapter := -1
	for rival in Session.rivals:
		if rival.chapter != chapter:
			chapter = rival.chapter
			list.add_child(UiKit.title("%s  ★ %d/%d" % [Journey.CHAPTER_NAMES[chapter],
					Journey.chapter_stars(Session.profile, chapter), Journey.chapter_stages(chapter).size() * Journey.MAX_STARS],
					30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
		var unlocked := Journey.is_unlocked(Session.profile, rival)
		var start_here := rival == Session.rivals[0] and Session.wants_coach() \
				and (not Session.profile.first_steps_active or Session.profile.next_first_step() == &"battle")
		list.add_child(_rival_panel(rival, problem == "" and unlocked, unlocked, start_here))
	add_child(UiKit.vscroll(list))

	if Session.autoplay and problem == "" and Session.profile.tour_done:
		await get_tree().create_timer(0.8).timeout
		Session.go_to_pre_battle(Session.rival)


## Why the player can't battle right now, or "" if they can.
func _party_problem() -> String:
	var lineup := Session.profile.lineup_defs(Session.catalog)
	if lineup.size() != PartyRules.BRING_SIZE:
		return "Pick %d dinos in the Party tab first." % PartyRules.BRING_SIZE
	if not PartyRules.has_valid_pick(lineup):
		return "Your 3 cheapest dinos cost more than %d Party Points. Swap in a cheaper one in the Party tab." \
				% PartyRules.POINT_CAP
	return ""


func _rival_panel(rival: RivalDef, can_fight: bool, unlocked: bool, start_here := false) -> Control:
	var box := UiKit.vbox(10)

	var header := UiKit.hbox(10)
	var name_label := UiKit.title(rival.display_name + ("  ·  BOSS" if rival.is_boss else ""), 30,
			Palette.HIGHLIGHT if rival.is_boss else Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var best := Journey.best_stars(Session.profile, rival)
	for i in Journey.MAX_STARS:
		var star := TextureRect.new()
		star.texture = Icons.texture(&"star" if i < best else &"star_empty", 26)
		star.custom_minimum_size = Vector2(26, 26)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(star)
	box.add_child(header)

	box.add_child(UiKit.label(rival.intro, 28, Palette.TEXT_DIM))

	var brings := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	for dino in rival.brings:
		var card := DinoCard.create(dino, DinoCard.Mode.MINI, null, false, BRING_CARD_WIDTH)
		# Tapping (as well as holding) a rival's dino shows its card full size.
		card.pressed.connect(CardViewer.open.bind(dino))
		brings.add_child(card)
	box.add_child(brings)

	var footer := UiKit.hbox(12)
	var record := Session.profile.record_against(rival.id)
	var record_text := "Not fought yet"
	if record[0] + record[1] > 0:
		record_text = "Won %d · Lost %d" % [record[0], record[1]]
	if not unlocked:
		record_text = "Beat %s to unlock" % Session.rivals[Session.rivals.find(rival) - 1].display_name
	if start_here:
		record_text = "Start here! A coach shows you the moves."
	var record_label := UiKit.label(record_text, 29, Palette.HIGHLIGHT if record[0] > 0 or start_here \
			else Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, start_here)
	record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(record_label)
	var challenge := UiKit.let_scroll(UiKit.button("Challenge", UiKit.BUTTON_GREEN, 72, 28))
	challenge.custom_minimum_size.x = 220
	challenge.disabled = not can_fight
	challenge.pressed.connect(Session.go_to_pre_battle.bind(rival))
	footer.add_child(challenge)
	box.add_child(footer)
	var panel := UiKit.panel(box)
	if not unlocked:
		panel.modulate = Color(1, 1, 1, 0.55)
	return panel
