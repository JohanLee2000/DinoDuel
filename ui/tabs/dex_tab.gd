extends VBoxContainer
## Dino Dex: every dino by era. Owned ones show in full, ones you've battled show faded, and
## the rest are "???". Tap any card to see it or craft it with Amber. A search and filters
## (CollectionFilter) narrow it down; they only hide cards, so changing them is instant.

var _body: VBoxContainer
var _summary: Label
var _scroll: ScrollContainer
var _filter: CollectionFilter
var _era_titles: Array[Label] = []
## Per era: its grid of cards.
var _era_grids: Array[GridContainer] = []
var _empty: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Dino Dex"))
	_summary = UiKit.label("", 29, Palette.TEXT_DIM)
	add_child(_summary)
	if OS.is_debug_build() and not Session.store_shots:
		# Development only: debug builds (editor, USB installs) show this; release builds don't.
		# TODO(release): delete this button and PlayerProfile.unlock_all (docs/RELEASE_CHECKLIST.md).
		var unlock := UiKit.button("DEV: unlock all dinos", UiKit.BUTTON_GRAY, 56, 26)
		unlock.pressed.connect(func() -> void:
			Session.profile.unlock_all(Session.catalog)
			Session.save()
			_refresh())
		add_child(unlock)
	_filter = CollectionFilter.create("dex", true)
	_filter.changed.connect(func() -> void:
		_apply_filter()
		_scroll.scroll_vertical = 0)
	add_child(_filter)
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
	_era_grids.clear()
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
				"   ★ Complete" if complete else ""], 30, Palette.HIGHLIGHT if complete else Palette.TEXT)
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
		_era_grids.append(row)
		_body.add_child(row)
	_empty = UiKit.label("No dinos match. Try another search, or clear the filters.", 29, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(_empty)
	_apply_filter()


## Shows only the cards that pass the search and filters, and hides eras left empty.
func _apply_filter() -> void:
	var profile := Session.profile
	var any := false
	for era in _era_grids.size():
		var shown := 0
		for card in _era_grids[era].get_children():
			card.visible = _filter.matches((card as DinoCard).def, profile)
			shown += 1 if card.visible else 0
		_era_titles[era].visible = shown > 0
		_era_grids[era].visible = shown > 0
		any = any or shown > 0
	_empty.visible = not any


## Dev (--dex-era): scrolls so that era's heading is at the top, once the grid has been laid out.
func _scroll_to_era(era: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_era_titles[era].position.y)


## Tapping a card opens its Dex entry (DexEntry: Share, or Craft if it's missing).
func _open(dino: DinoDef) -> void:
	DexEntry.open(dino, _refresh)
