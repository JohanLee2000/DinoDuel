class_name CollectionFilter
extends VBoxContainer
## Search and filters for the Dex and Party tabs (2026-10-15): a name search and a Filters button
## that opens chips for type, tier and era, plus a row of Show chips (Dex: All / Owned / Missing /
## Can craft) or Sort chips (Party: ATK / DEF / SPD, highest first; none on = the usual order).
## Within a group, chips add up (Land + Sea shows both); groups narrow each other. Choices last
## while the app is open, one set per tab, but aren't saved.

signal changed

enum Show { ALL, OWNED, MISSING, CAN_CRAFT }
enum Sort { USUAL, ATTACK, DEFENSE, SPEED }

const SHOW_NAMES: Array[String] = ["All", "Owned", "Missing", "Can craft"]
## Sort chips, in Sort order after USUAL.
const SORT_NAMES: Array[String] = ["ATK", "DEF", "SPD"]
const TIER_NAMES: Array[String] = ["N", "R", "SR", "SSR", "UR"]
const TYPE_ICONS: Array[StringName] = [&"type_land", &"type_sky", &"type_sea"]
const CHIP_HEIGHT := 58
const CHIP_FONT := 23

## Per tab: the last choices, so switching tabs and back keeps them.
static var _saved := {}

var query := ""
var types := {}
var tiers := {}
var eras := {}
var showing := Show.ALL
var sort := Sort.USUAL

var _key: String
var _with_show := false
var _with_sort := false
var _search: LineEdit
var _filters_button: Button
var _panel: Control


## `key` names whose choices these are ("dex", "party"). Dex passes with_show, Party with_sort.
static func create(key: String, with_show := false, with_sort := false) -> CollectionFilter:
	var filter := CollectionFilter.new()
	filter._key = key
	filter._with_show = with_show
	filter._with_sort = with_sort
	var saved: Dictionary = _saved.get(key, {})
	filter.query = saved.get("query", "")
	filter.types = saved.get("types", {}).duplicate()
	filter.tiers = saved.get("tiers", {}).duplicate()
	filter.eras = saved.get("eras", {}).duplicate()
	filter.showing = saved.get("show", Show.ALL)
	filter.sort = saved.get("sort", Sort.USUAL)
	return filter


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	# Dev (--open=filters[:<search>]): the Filters panel starts open, for screenshots. Session is
	# looked up here rather than named, so the tests (which run without autoloads) can load this.
	var session := get_node_or_null(^"/root/Session")
	var dev_open: String = session.dev_open if session else ""
	var dev := dev_open.begins_with("filters")
	if dev and ":" in dev_open:
		query = dev_open.get_slice(":", 1)
	var top := UiKit.hbox(10)
	_search = LineEdit.new()
	_search.placeholder_text = "Search by name"
	_search.text = query
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size = Vector2(0, CHIP_HEIGHT + 6)
	_search.add_theme_font_size_override("font_size", 26)
	_search.add_theme_color_override("font_placeholder_color", Color(Palette.TEXT_DIM, 0.8))
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.PANEL, 0.95)
		style.border_color = Palette.HIGHLIGHT if state == "focus" else Palette.PANEL_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.content_margin_left = 16
		style.content_margin_right = 10
		_search.add_theme_stylebox_override(state, style)
	_search.text_changed.connect(func(text: String) -> void:
		query = text.strip_edges()
		_changed())
	# The keyboard's Done/Enter just closes the keyboard; results already update as you type.
	_search.text_submitted.connect(func(_text: String) -> void: _search.release_focus())
	top.add_child(_search)
	_filters_button = UiKit.button("", UiKit.BUTTON_GRAY, CHIP_HEIGHT + 6, 25)
	_filters_button.custom_minimum_size.x = 170
	_filters_button.pressed.connect(func() -> void:
		Sound.play(&"tap")
		_panel.visible = not _panel.visible)
	top.add_child(_filters_button)
	add_child(top)

	if _with_show:
		add_child(_chip_row("", SHOW_NAMES, func(i: int) -> bool: return showing == i,
				func(i: int) -> void: showing = i as Show))
	if _with_sort:
		add_child(_sort_row())

	var groups := UiKit.vbox(8)
	groups.add_child(_toggle_row("Type", DinoDef.TYPE_NAMES, types, TYPE_ICONS))
	groups.add_child(_toggle_row("Tier", TIER_NAMES, tiers))
	groups.add_child(_toggle_row("Era", DinoDef.ERA_NAMES, eras))
	var clear := UiKit.button("Clear filters", UiKit.BUTTON_GRAY, 52, 22)
	clear.pressed.connect(func() -> void:
		Sound.play(&"tap")
		types.clear()
		tiers.clear()
		eras.clear()
		for row in groups.get_children():
			for chip in row.get_children():
				if chip is Button and chip.has_meta("on"):
					_style_chip(chip, false)
		_changed())
	groups.add_child(clear)
	_panel = UiKit.panel(groups, Palette.PANEL, 12)
	_panel.visible = dev
	add_child(_panel)
	_update_filters_button()


## Whether `dino` passes the search, the Show choice and the filters.
func matches(dino: DinoDef, profile: PlayerProfile) -> bool:
	if not types.is_empty() and not types.has(int(dino.dino_type)):
		return false
	if not tiers.is_empty() and not tiers.has(int(dino.rarity)):
		return false
	if not eras.is_empty() and not eras.has(int(dino.era)):
		return false
	var owned := profile.owns(dino.id)
	match showing:
		Show.OWNED:
			if not owned:
				return false
		Show.MISSING:
			if owned:
				return false
		Show.CAN_CRAFT:
			if not profile.can_craft(dino):
				return false
	if query != "":
		# Undiscovered dinos are "???" in the Dex, so searching can't find them by name.
		if not (owned or profile.seen.has(dino.id)):
			return false
		if dino.display_name.findn(query) < 0:
			return false
	return true


## `dinos` in the chosen Sort order: highest first, or the usual Land, Sky, Sea, rarest first.
func sorted(dinos: Array[DinoDef]) -> Array[DinoDef]:
	var result := dinos.duplicate()
	result.sort_custom(func(a: DinoDef, b: DinoDef) -> bool:
		var keys_a := _sort_keys(a)
		var keys_b := _sort_keys(b)
		for i in keys_a.size():
			if keys_a[i] != keys_b[i]:
				return keys_a[i] > keys_b[i]
		return a.display_name < b.display_name)
	return result


## How many chips are on in the Filters panel (the search and Show/Sort rows aren't counted).
func active_filters() -> int:
	return types.size() + tiers.size() + eras.size()


func is_narrowed() -> bool:
	return query != "" or showing != Show.ALL or active_filters() > 0


func _sort_keys(dino: DinoDef) -> Array:
	match sort:
		Sort.ATTACK:
			return [dino.attack, dino.speed]
		Sort.DEFENSE:
			return [dino.defense, dino.health]
		Sort.SPEED:
			return [dino.speed, dino.attack]
	return [-int(dino.dino_type), int(dino.rarity)]


func _changed() -> void:
	_saved[_key] = {"query": query, "types": types.duplicate(), "tiers": tiers.duplicate(),
			"eras": eras.duplicate(), "show": showing, "sort": sort}
	_update_filters_button()
	changed.emit()


func _update_filters_button() -> void:
	var count := active_filters()
	_filters_button.text = "Filters (%d)" % count if count > 0 else "Filters"
	UiKit.style_button(_filters_button, UiKit.BUTTON_GREEN if count > 0 else UiKit.BUTTON_GRAY)


## One-of-a-kind chips (Show, Sort): exactly one is on.
func _chip_row(heading: String, names: Array[String], is_on: Callable, choose: Callable) -> Control:
	var row := UiKit.hbox(6)
	if heading != "":
		row.add_child(_heading(heading))
	for i in names.size():
		var chip := _chip(names[i], is_on.call(i))
		chip.pressed.connect(func() -> void:
			if is_on.call(i):
				return
			Sound.play(&"tap")
			choose.call(i)
			for other in row.get_children():
				if other is Button:
					_style_chip(other, other == chip)
			_changed())
		row.add_child(chip)
	return row


## Sort chips: at most one on. Tapping the one that's on turns it off (the usual order again).
func _sort_row() -> Control:
	var row := UiKit.hbox(6)
	row.add_child(_heading("Sort"))
	for i in SORT_NAMES.size():
		var value := (i + 1) as Sort
		var chip := _chip(SORT_NAMES[i], sort == value)
		chip.pressed.connect(func() -> void:
			Sound.play(&"tap")
			sort = Sort.USUAL if sort == value else value
			for other in row.get_children():
				if other is Button:
					_style_chip(other, other == chip and sort == value)
			_changed())
		row.add_child(chip)
	return row


## Add-up chips (type, tier, era): each one toggles its index in `chosen`.
func _toggle_row(heading: String, names: Array[String], chosen: Dictionary,
		icons: Array[StringName] = []) -> Control:
	var row := UiKit.hbox(6)
	row.add_child(_heading(heading))
	for i in names.size():
		var chip := _chip(names[i], chosen.has(i), icons[i] if i < icons.size() else &"")
		chip.pressed.connect(func() -> void:
			Sound.play(&"tap")
			if chosen.has(i):
				chosen.erase(i)
			else:
				chosen[i] = true
			_style_chip(chip, chosen.has(i))
			_changed())
		row.add_child(chip)
	return row


func _heading(text: String) -> Label:
	var label := UiKit.label(text, 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.custom_minimum_size.x = 64
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _chip(text: String, on: bool, icon_name: StringName = &"") -> Button:
	var chip := UiKit.button(text, UiKit.BUTTON_GRAY, CHIP_HEIGHT, CHIP_FONT)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.set_meta("on", on)
	if icon_name != &"":
		chip.icon = Icons.texture(icon_name, 30)
		chip.expand_icon = false
	_style_chip(chip, on)
	return chip


## On: gold. Off: dark. Type icons keep their own colors either way.
func _style_chip(chip: Button, on: bool) -> void:
	chip.set_meta("on", on)
	UiKit.style_button(chip, UiKit.BUTTON_GREEN if on else UiKit.BUTTON_GRAY)
	if chip.icon:
		for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			chip.add_theme_color_override(color_name, Color.WHITE)
