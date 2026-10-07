extends VBoxContainer
## Dino Dex: every dino by era. Owned ones show in full, ones you've battled show faded, and
## the rest are "???". Tap any card to see it or craft it with Amber.

var _body: VBoxContainer
var _summary: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Dino Dex"))
	_summary = UiKit.label("", 20, Palette.TEXT_DIM)
	add_child(_summary)
	_body = UiKit.vbox(18)
	add_child(UiKit.vscroll(_body))
	_refresh()
	if Session.dev_open_dex:
		_open.call_deferred(Session.catalog.find(Session.dev_open_dex))
		Session.dev_open_dex = &""


func _refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	var profile := Session.profile
	var shinies := 0
	for id in profile.owned:
		shinies += 1 if profile.is_shiny(id) else 0
	_summary.text = "%d/%d discovered · %d Shiny · tap a card to see it big or craft it" % [
			profile.owned.size(), Session.catalog.dinos.size(), shinies]

	for era in DinoDef.ERA_NAMES.size():
		var dinos := Session.catalog.dinos.filter(func(d: DinoDef) -> bool: return d.era == era)
		var owned := dinos.filter(func(d: DinoDef) -> bool: return profile.owns(d.id)).size()
		_body.add_child(UiKit.title("%s  %d/%d" % [DinoDef.ERA_NAMES[era], owned, dinos.size()], 28,
				Palette.HIGHLIGHT if owned == dinos.size() else Palette.TEXT))
		var row := UiKit.grid(6, 6)
		for dino in dinos:
			var card: DinoCard
			if profile.owns(dino.id):
				card = DinoCard.create(dino, DinoCard.Mode.MINI, null, profile.is_shiny(dino.id))
			elif profile.seen.has(dino.id):
				card = DinoCard.create(dino, DinoCard.Mode.MINI)
				card.modulate = Color(1, 1, 1, 0.45)
			else:
				card = DinoCard.create_unknown(dino, DinoCard.Mode.MINI)
			card.inspect_on_hold = false
			card.pressed.connect(_open.bind(dino))
			row.add_child(card)
		_body.add_child(row)


func _open(dino: DinoDef) -> void:
	var profile := Session.profile
	var owned := profile.owns(dino.id)
	var known := owned or profile.seen.has(dino.id)
	var extras: Array[Control] = []
	if not owned:
		var hint := "You've battled this one but don't own it yet." if known 				else "Not discovered yet. Hatch eggs to find it, or craft it now."
		extras.append(UiKit.label(hint, 20, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var craft := UiKit.button("Craft for %d Amber (you have %d)" % [Economy.CRAFT_COST[dino.rarity],
				profile.amber], UiKit.BUTTON_AMBER)
		craft.disabled = not profile.can_craft(dino)
		extras.append(craft)
		var viewer := CardViewer.open(dino, false, known, extras)
		craft.pressed.connect(_craft.bind(dino, viewer))
		viewer.closed.connect(_refresh)
	else:
		CardViewer.open(dino, profile.is_shiny(dino.id))


func _craft(dino: DinoDef, viewer: CardViewer) -> void:
	var result := Session.profile.craft(dino)
	if result == null:
		return
	Session.save()
	viewer.close()
	var results: Array[HatchResult] = [result]
	var view := HatchView.create(results, "Crafted from a fossil!")
	view.finished.connect(_refresh)
	get_tree().current_scene.add_child(view)
