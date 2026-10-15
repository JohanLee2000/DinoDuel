extends VBoxContainer
## Battle tab: the Journey (docs/GAME_DESIGN.md). Era tabs, a chapter banner with your stars and
## the star chests, and Jo's illustrated trail map for the era with a marker on every stage. Tap a
## marker to see the rival and challenge them. The Professaur introduces each chapter when it opens.

const MAPS: Array[String] = ["res://assets/journey/map_triassic.webp", "res://assets/journey/map_jurassic.webp",
		"res://assets/journey/map_cretaceous.webp", "res://assets/journey/map_finale.webp"]
## Where each stage sits on its era's map, as fractions of the map, in stage order (the boss last).
## Picked by eye on the clearings along each painted trail.
const STOPS := [
	[Vector2(0.48, 0.84), Vector2(0.74, 0.68), Vector2(0.32, 0.53), Vector2(0.70, 0.37), Vector2(0.31, 0.22), Vector2(0.50, 0.08)],
	[Vector2(0.46, 0.82), Vector2(0.74, 0.61), Vector2(0.28, 0.47), Vector2(0.72, 0.35), Vector2(0.32, 0.21), Vector2(0.52, 0.08)],
	[Vector2(0.50, 0.84), Vector2(0.72, 0.66), Vector2(0.30, 0.52), Vector2(0.72, 0.40), Vector2(0.34, 0.26), Vector2(0.50, 0.15)],
	[Vector2(0.56, 0.26)],
]
const TAB_NAMES: Array[String] = ["Triassic", "Jurassic", "Cretaceous", "Finale"]

## The era being shown, kept while the game runs so coming back to the tab stays on it.
static var _chapter := -1

var _problem := ""
var _scroll: ScrollContainer
var _holder: Control
var _map: TextureRect
var _markers: Array[StageMarker] = []


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_problem = _party_problem()
	if _chapter < 0 or not Journey.chapter_unlocked(Session.profile, _chapter):
		_chapter = _current_chapter()
	_build()
	_maybe_intro.call_deferred()
	if Session.autoplay and _problem == "" and Session.profile.tour_done:
		await get_tree().create_timer(0.8).timeout
		Session.go_to_pre_battle(Session.rival)


## The chapter of the next stage to clear (the finale once everything is done).
static func _current_chapter() -> int:
	var next := Journey.next_stage(Session.profile)
	return next.chapter if next else Journey.FINALE


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_markers.clear()
	add_child(_era_tabs())
	add_child(_banner())
	if OS.is_debug_build() and not Session.store_shots:
		# Development only: opens every stage for this run without touching the save.
		# TODO(release): delete this button and Journey.dev_unlock_all (docs/RELEASE_CHECKLIST.md).
		var dev := UiKit.button("DEV: lock stages again" if Journey.dev_unlock_all else "DEV: unlock all stages",
				UiKit.BUTTON_GRAY, 52, 24)
		dev.pressed.connect(func() -> void:
			Journey.dev_unlock_all = not Journey.dev_unlock_all
			if not Journey.chapter_unlocked(Session.profile, _chapter):
				_chapter = _current_chapter()
			_build())
		add_child(dev)
	if _problem != "":
		add_child(UiKit.label(_problem, 28, Palette.HIGHLIGHT))

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_map = TextureRect.new()
	_map.texture = load(MAPS[_chapter])
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_PASS
	_holder.add_child(_map)
	var stages := Journey.chapter_stages(_chapter)
	var next := Journey.next_stage(Session.profile)
	for stage in stages:
		var marker := StageMarker.create(stage, Journey.best_stars(Session.profile, stage),
				Journey.is_unlocked(Session.profile, stage), stage == next)
		marker.pressed.connect(func() -> void: RivalView.open(stage, _problem == ""))
		_holder.add_child(marker)
		_markers.append(marker)
	_scroll = UiKit.vscroll(_holder)
	_scroll.resized.connect(_layout_map)
	add_child(_scroll)
	_scroll_to_next.call_deferred()


## Fits the map to the width and puts each marker's circle on its stop.
func _layout_map() -> void:
	var width := _scroll.size.x
	var map_size := Vector2(width, width * 1.5)
	_holder.custom_minimum_size = Vector2(0, map_size.y)
	_map.size = map_size
	var stops: Array = STOPS[_chapter]
	for i in _markers.size():
		var marker := _markers[i]
		var at: Vector2 = stops[i] * map_size - marker.anchor()
		marker.position = Vector2(clampf(at.x, 0, width - marker.size.x), maxf(at.y, 0))


func _scroll_to_next() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_layout_map()
	var next := Journey.next_stage(Session.profile)
	for marker in _markers:
		if marker.stage == next:
			_scroll.scroll_vertical = int(marker.position.y + marker.anchor().y - _scroll.size.y / 2)
			return
	_scroll.scroll_vertical = 0


func _era_tabs() -> HBoxContainer:
	var row := UiKit.hbox(8)
	for chapter in TAB_NAMES.size():
		var open := Journey.chapter_unlocked(Session.profile, chapter)
		var button: Button
		if open:
			button = UiKit.button(TAB_NAMES[chapter], UiKit.BUTTON_GREEN if chapter == _chapter else UiKit.BUTTON_GRAY, 64, 23)
			button.pressed.connect(func() -> void:
				if _chapter != chapter:
					Sound.play(&"tap")
					_chapter = chapter
					_build())
		else:
			button = UiKit.icon_button(TAB_NAMES[chapter], &"lock", UiKit.BUTTON_GRAY, 64, 22)
			button.disabled = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	return row


## The era's name and stars, and its three star chests (tap a full one to open it).
func _banner() -> Control:
	var profile := Session.profile
	var row := UiKit.hbox(12)
	var words := UiKit.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UiKit.title(Journey.CHAPTER_NAMES[_chapter], 32, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var most := Journey.chapter_stages(_chapter).size() * Journey.MAX_STARS
	words.add_child(UiKit.label("★ %d / %d stars" % [Journey.chapter_stars(profile, _chapter), most], 26, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(words)
	if _chapter == Journey.FINALE:
		var note := UiKit.label("The meteor shower\nstarts on turn %d!" % Journey.chapter_stages(_chapter)[0].meteor_turn,
				25, Palette.DAMAGE.lightened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, false)
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(note)
	else:
		for index in Journey.STAR_CHESTS.size():
			row.add_child(_chest(index))
	return UiKit.panel(row, Palette.PANEL, 12)


func _chest(index: int) -> Control:
	var profile := Session.profile
	var needed: int = Journey.STAR_CHESTS[index][0]
	var claimed := Journey.chest_claimed(profile, _chapter, index)
	var ready := Journey.chest_ready(profile, _chapter, index)
	var button := Button.new()
	button.flat = true
	button.icon = Icons.texture(&"chest", 44)
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "✔" if claimed else "%d★" % needed
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_font_override("font", Fonts.bold())
	button.add_theme_color_override("font_color", Palette.HEAL if claimed else (Palette.HIGHLIGHT if ready else Palette.TEXT_DIM))
	button.custom_minimum_size = Vector2(72, 84)
	if claimed:
		button.modulate.a = 0.45
	elif not ready:
		button.modulate = Color(0.6, 0.6, 0.65)
	else:
		button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
		var pulse := button.create_tween().set_loops()
		pulse.tween_property(button, "scale", Vector2(1.12, 1.12), 0.45).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(button, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	button.pressed.connect(func() -> void:
		if Journey.claim_chest(Session.profile, _chapter, index):
			Sound.play(&"amber")
			Session.save()
			_toast("Chest opened: " + _chest_reward(index))
			_build()
		elif not claimed:
			_toast("%d stars in the %s: %s" % [needed, Journey.CHAPTER_NAMES[_chapter], _chest_reward(index)]))
	return button


static func _chest_reward(index: int) -> String:
	var chest: Array = Journey.STAR_CHESTS[index]
	if chest[3] > 0:
		return "a Rare clutch"
	if chest[2] > 0:
		return "an egg clutch"
	return "%d Amber" % chest[1]


## A short message that floats over the map and fades.
func _toast(text: String) -> void:
	var label := UiKit.label(text, 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	label.add_theme_font_override("font", Fonts.bold())
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := get_tree().current_scene
	layer.add_child(label)
	label.reset_size()
	label.global_position = Vector2((get_viewport_rect().size.x - label.size.x) / 2, get_viewport_rect().size.y * 0.42)
	var tween := label.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


## The Professaur introduces a chapter the first time it's open (once the tour is over).
func _maybe_intro() -> void:
	var profile := Session.profile
	if Session.autoplay or Session.store_shots or Session.dev_tutorial or not profile.tour_done:
		return
	var chapter := _current_chapter()
	if profile.claimed_goals.get("intro_%d" % chapter, false):
		return
	for earlier in chapter + 1:
		profile.claimed_goals["intro_%d" % earlier] = true
	Session.save()
	_chapter = chapter
	_build()
	ProfessaurNote.chapter_intro(chapter)


## Why the player can't battle right now, or "" if they can.
func _party_problem() -> String:
	var lineup := Session.profile.lineup_defs(Session.catalog)
	if lineup.size() != PartyRules.BRING_SIZE:
		return "Pick %d dinos in the Party tab first." % PartyRules.BRING_SIZE
	if not PartyRules.has_valid_pick(lineup):
		return "Your 3 cheapest dinos cost more than %d Party Points. Swap in a cheaper one in the Party tab." \
				% PartyRules.POINT_CAP
	return ""
