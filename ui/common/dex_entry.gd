class_name DexEntry
extends RefCounted
## A dino's Dex entry: its card full-screen, with Share if you own it, or how to get it and a Craft
## button if you don't. Opened from the Dex and from a set's cards on the Goals tab.


## `crafted` is called once a crafted dino's reveal has finished, so the caller can refresh.
static func open(dino: DinoDef, crafted: Callable = Callable()) -> void:
	var profile := Session.profile
	var owned := profile.owns(dino.id)
	if profile.mark_viewed(dino.id):
		Session.save()
	if owned:
		var share := UiKit.pill_button("Share", &"share")
		share.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		share.custom_minimum_size.x = 340
		share.pressed.connect(func() -> void:
			share.disabled = true
			await ShareCard.share_dino(dino, profile.is_shiny(dino.id), false)
			if is_instance_valid(share):
				share.disabled = false)
		var owned_extras: Array[Control] = [_mastery_panel(profile, dino), share]
		CardViewer.open(dino, profile.is_shiny(dino.id), true, owned_extras)
		# First steps: "Meet your dinos".
		if not profile.opened_dex_card:
			profile.opened_dex_card = true
			Session.save()
		return

	var known := profile.seen.has(dino.id)
	var extras: Array[Control] = []
	var hint := "You've battled this one but don't own it yet." if known \
			else "Not discovered yet. Hatch eggs to find it, or craft it now."
	extras.append(UiKit.label(hint, 29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var cost: int = Economy.CRAFT_COST[dino.rarity]
	var craft := UiKit.button("Craft  ·  %d Amber" % cost, UiKit.BUTTON_AMBER)
	craft.disabled = not profile.can_craft(dino)
	extras.append(craft)
	if profile.amber < cost:
		extras.append(UiKit.label("Need %d more" % (cost - profile.amber), 29, Palette.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER))
	var viewer := CardViewer.open(dino, false, known, extras)
	craft.pressed.connect(func() -> void: _craft(dino, viewer, crafted))


## Its mastery: the title it has earned (with what earned it), its numbers, and the next rank.
static func _mastery_panel(profile: PlayerProfile, dino: DinoDef) -> Control:
	var rank := Mastery.rank_of(profile, dino.id)
	var stats := Mastery.stats_of(profile, dino.id)
	var box := UiKit.vbox(4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = DinoCard.RIBBON_COLORS.get(rank, Palette.TEXT)
	var earned := Mastery.description_of(rank).trim_suffix(".")
	var headline := "%s: %s" % [Mastery.title_of(rank), earned.left(1).to_lower() + earned.substr(1)] 			if rank > 0 else "No mastery yet: take it into battle to start its story"
	box.add_child(UiKit.label(headline, 26, color, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label("%d battles  ·  %d wins  ·  %d counters  ·  %d bosses" % [stats["battles"], stats["wins"],
			stats["counters"], stats["bosses"]], 23, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var next := Mastery.next_text(profile, dino.id)
	if next != "":
		box.add_child(UiKit.label(next, 23, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var panel := UiKit.panel(box, Palette.PANEL, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = CardViewer.CARD_WIDTH
	return panel


static func _craft(dino: DinoDef, viewer: CardViewer, crafted: Callable) -> void:
	var result := Session.profile.craft(dino)
	if result == null:
		return
	Sound.play(&"amber")
	Session.save()
	viewer.close()
	var results: Array[HatchResult] = [result]
	var view := HatchView.create(results, "Crafted from a fossil!")
	if crafted.is_valid():
		view.finished.connect(crafted)
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
