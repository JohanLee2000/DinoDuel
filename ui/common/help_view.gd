class_name HelpView
extends Control
## "How to play": a few short pages on battles, types, parties and eggs. Opened from the ? button
## in battle and from Settings. The first battle's tutorial opens the moves page alone, with a
## "Let's go" button.

signal closed

const MOVE_COLORS := ["d92b3a", "ff7a1a", "2e7bff", "8fa3bf"]
const PAGES := [
	{
		"title": "Battle moves",
		"rows": [
			["", "Each turn you and your rival pick a move [b]at the same time[/b]. Knock out all 3 of the rival's dinos to win."],
			["move:0", "A quick hit. [b]Beats Charge[/b] by cancelling it."],
			["move:1", "Double damage, but acts last. [b]Beats Brace[/b] by smashing through it."],
			["move:2", "Blocks a Bite and bites back: [b]beats Bite[/b]. Can't Brace two turns in a row."],
			["move:3", "Goes first. Benched dinos heal 1 HP every turn."],
		],
	},
	{
		"title": "Land, Sky and Sea",
		"rows": [
			["type_land", "[b]Land beats Sky[/b]: it pounces on pterosaurs on the ground."],
			["type_sky", "[b]Sky beats Sea[/b]: it dives on marine reptiles."],
			["type_sea", "[b]Sea beats Land[/b]: it ambushes at the water's edge."],
			["", "Hitting a type you beat does [b]+50% damage[/b]. The move buttons say \"type edge\" when you have it."],
			["", "Damage is Attack (x1.5 type edge, x2 Charge) minus the target's Defense, at least 1. Faster dinos hit first."],
		],
	},
	{
		"title": "Your party",
		"rows": [
			["", "Bring [b]6[/b] dinos. You see the rival's 6, then secretly pick [b]3[/b]."],
			["", "Party Points: N 1, R 2, SR 3, SSR 4, UR 5. Your 3 must add up to [b]%d or less[/b]."],
			["", "[b]Era bond[/b]: all 3 from the same era give +1 Attack and +1 Speed each."],
			["", "[b]Balanced[/b]: one Land, one Sky and one Sea give +2 HP each."],
			["", "From turn 20 a meteor shower hits both active dinos every turn, but never knocks one out."],
		],
	},
	{
		"title": "Eggs and Amber",
		"rows": [
			["egg", "Win a battle: a clutch of [b]3 eggs[/b] and %d Amber. Lose: %d Amber."],
			["egg", "Claim a free clutch every day, or buy one for %d Amber."],
			["", "Tap an egg to crack it: its glow shows how rare it is. 1 in %d is a [b]Shiny[/b] with a special look."],
			["amber", "Duplicates melt into Amber. Spend it in the Dex to craft the dinos you're missing."],
		],
	},
]

var _page := 0
var _intro := false
var _body: VBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button


## Opens the pages over the current screen. `intro` shows just that one page with a "Let's go"
## button (the tutorial's opening card).
static func open(page := 0, intro := false) -> HelpView:
	var view := HelpView.new()
	view._page = page
	view._intro = intro
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	closed.emit()
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.modal_layer(0.88))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)

	var column := UiKit.vbox(18)
	column.custom_minimum_size.x = 640
	_body = UiKit.vbox(16)
	column.add_child(_body)
	var nav := UiKit.hbox(12)
	if _intro:
		var go := UiKit.button("Let's go!", UiKit.BUTTON_GREEN, 84, 30)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(close)
		nav.add_child(go)
	else:
		_prev = UiKit.button("Back", UiKit.BUTTON_GRAY, 76, 26)
		_prev.pressed.connect(_turn.bind(-1))
		_page_label = UiKit.label("", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
		_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_next = UiKit.button("Next", UiKit.BUTTON_GREEN, 76, 26)
		_next.pressed.connect(_turn.bind(1))
		for b in [_prev, _next]:
			b.custom_minimum_size.x = 170
		nav.add_child(_prev)
		nav.add_child(_page_label)
		nav.add_child(_next)
	column.add_child(nav)
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))
	_show_page()
	if _intro and Session.autoplay:
		await get_tree().create_timer(2.0).timeout
		close()


func _turn(step: int) -> void:
	if _page + step >= PAGES.size():
		close()
		return
	_page = clampi(_page + step, 0, PAGES.size() - 1)
	_show_page()


func _show_page() -> void:
	for child in _body.get_children():
		child.queue_free()
	var page: Dictionary = PAGES[_page]
	_body.add_child(UiKit.title("How to play" if _intro else page["title"], 40, Palette.HIGHLIGHT))
	for row in page["rows"]:
		_body.add_child(_row(row[0], _fill_numbers(row[1])))
	if not _intro:
		_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
		_prev.disabled = _page == 0
		_next.text = "Done" if _page == PAGES.size() - 1 else "Next"


## Puts the live game numbers into the texts that mention them, so they can't go stale.
func _fill_numbers(text: String) -> String:
	if text.contains("%d or less"):
		return text % PartyRules.POINT_CAP
	if text.begins_with("Win a battle"):
		return text % [Economy.WIN_AMBER, Economy.LOSS_AMBER]
	if text.contains("buy one for"):
		return text % Economy.CLUTCH_PRICE
	if text.contains("1 in %d"):
		return text % roundi(1.0 / Economy.SHINY_ODDS)
	return text


func _row(icon: String, text: String) -> Control:
	var row := UiKit.hbox(16)
	if icon.begins_with("move:"):
		var index := int(icon.get_slice(":", 1))
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(MOVE_COLORS[index])
		style.set_corner_radius_all(10)
		chip.add_theme_stylebox_override("panel", style)
		chip.custom_minimum_size = Vector2(118, 48)
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var move_name := UiKit.title(BattleAction.KIND_NAMES[index], 24, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
		move_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(move_name)
		row.add_child(chip)
	elif icon != "":
		var image := TextureRect.new()
		image.texture = Icons.texture(StringName(icon), 56)
		image.custom_minimum_size = Vector2(56, 56)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(image)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 27)
	label.add_theme_font_size_override("bold_font_size", 27)
	label.add_theme_font_override("bold_font", Fonts.bold())
	label.add_theme_color_override("default_color", Palette.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
