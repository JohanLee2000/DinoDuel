class_name DexEntry
extends RefCounted
## A dino's Dex entry: its card full-screen, with Share if you own it, or how to get it and a Craft
## button if you don't. Opened from the Dex and from a set's cards on the Goals tab.


## `crafted` is called once a crafted dino's reveal has finished, so the caller can refresh.
static func open(dino: DinoDef, crafted: Callable = Callable()) -> void:
	var profile := Session.profile
	var owned := profile.owns(dino.id)
	if owned:
		var share := UiKit.pill_button("Share", &"share")
		share.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		share.custom_minimum_size.x = 340
		share.pressed.connect(func() -> void:
			share.disabled = true
			await ShareCard.share_dino(dino, profile.is_shiny(dino.id), false)
			if is_instance_valid(share):
				share.disabled = false)
		var owned_extras: Array[Control] = [share]
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
