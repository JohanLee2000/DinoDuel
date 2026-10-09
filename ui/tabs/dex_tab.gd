extends VBoxContainer
## Dino Dex: every dino by era. Owned ones show in full, ones you've battled show faded, and
## the rest are "???". Tap any card to see it or craft it with Amber.

var _body: VBoxContainer
var _summary: Label
var _scroll: ScrollContainer
var _era_titles: Array[Label] = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Dino Dex"))
	_summary = UiKit.label("", 24, Palette.TEXT_DIM)
	add_child(_summary)
	if OS.is_debug_build() and not Session.store_shots:
		# Development only: debug builds (editor, USB installs) show this; release builds don't.
		# TODO(release): delete this button and PlayerProfile.unlock_all (docs/RELEASE_CHECKLIST.md).
		var unlock := UiKit.button("DEV: unlock all dinos", UiKit.BUTTON_GRAY, 56, 22)
		unlock.pressed.connect(func() -> void:
			Session.profile.unlock_all(Session.catalog)
			Session.save()
			_refresh())
		add_child(unlock)
	_body = UiKit.vbox(18)
	_scroll = UiKit.vscroll(_body)
	add_child(_scroll)
	_refresh()
	if Session.dev_dex_era >= 0:
		_scroll_to_era(Session.dev_dex_era)
		Session.dev_dex_era = -1
	if Session.dev_open_dex:
		_open.call_deferred(Session.catalog.find(Session.dev_open_dex))
		Session.dev_open_dex = &""


func _refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	_era_titles.clear()
	var profile := Session.profile
	var shinies := 0
	for id in profile.owned:
		shinies += 1 if profile.is_shiny(id) else 0
	_summary.text = "%d/%d discovered · %d Shiny · tap a card to see it big or craft it" % [
			profile.owned.size(), Session.catalog.dinos.size(), shinies]

	for era in DinoDef.ERA_NAMES.size():
		var dinos := Session.catalog.dinos.filter(func(d: DinoDef) -> bool: return d.era == era)
		var owned := dinos.filter(func(d: DinoDef) -> bool: return profile.owns(d.id)).size()
		var complete := owned == dinos.size()
		var era_title := UiKit.title("%s  %d/%d%s" % [DinoDef.ERA_NAMES[era], owned, dinos.size(),
				"   ★ Complete" if complete else ""], 28, Palette.HIGHLIGHT if complete else Palette.TEXT)
		_era_titles.append(era_title)
		_body.add_child(era_title)
		var row := UiKit.grid(3, 12)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for dino in dinos:
			var card: DinoCard
			if profile.owns(dino.id):
				card = DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino.id))
			elif profile.seen.has(dino.id):
				card = DinoCard.create(dino, DinoCard.Mode.FULL)
				card.modulate = Color(1, 1, 1, 0.45)
			else:
				card = DinoCard.create_unknown(dino, DinoCard.Mode.FULL)
			card.inspect_on_hold = false
			card.pressed.connect(_open.bind(dino))
			row.add_child(card)
		_body.add_child(row)


## Dev (--dex-era): scrolls so that era's heading is at the top, once the grid has been laid out.
func _scroll_to_era(era: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_era_titles[era].position.y)


func _open(dino: DinoDef) -> void:
	var profile := Session.profile
	var owned := profile.owns(dino.id)
	var known := owned or profile.seen.has(dino.id)
	var extras: Array[Control] = []
	if not owned:
		var hint := "You've battled this one but don't own it yet." if known 				else "Not discovered yet. Hatch eggs to find it, or craft it now."
		extras.append(UiKit.label(hint, 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var craft := UiKit.button("Craft for %d Amber (you have %d)" % [Economy.CRAFT_COST[dino.rarity],
				profile.amber], UiKit.BUTTON_AMBER)
		craft.disabled = not profile.can_craft(dino)
		extras.append(craft)
		var viewer := CardViewer.open(dino, false, known, extras)
		craft.pressed.connect(_craft.bind(dino, viewer))
		viewer.closed.connect(_refresh)
	else:
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
		if not profile.opened_dex_card:
			profile.opened_dex_card = true
			Session.save()


func _craft(dino: DinoDef, viewer: CardViewer) -> void:
	var result := Session.profile.craft(dino)
	if result == null:
		return
	Sound.play(&"amber")
	Session.save()
	viewer.close()
	var results: Array[HatchResult] = [result]
	var view := HatchView.create(results, "Crafted from a fossil!")
	view.finished.connect(_refresh)
	get_tree().current_scene.add_child(view)
