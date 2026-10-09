class_name HelpView
extends Control
## "How to play": a few short pages on battles, stats, types, parties and eggs. Opened from the ? button
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
	{"title": "Dino stats", "custom": "_stats_page"},
	{"title": "Damage and speed", "custom": "_damage_page"},
	{
		"title": "Land, Sky and Sea",
		"rows": [
			["type_land", "[b]Land beats Sky[/b]: it pounces on pterosaurs on the ground."],
			["type_sky", "[b]Sky beats Sea[/b]: it dives on marine reptiles."],
			["type_sea", "[b]Sea beats Land[/b]: it ambushes at the water's edge."],
			["", "Hitting a type you beat does [b]+50% damage[/b]. The move buttons show [b]+50%[/b] when you have it."],
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
			["", "[b]Hold any card[/b] to see it bigger, with its stats and a fact about the real animal."],
		],
	},
	{
		"title": "Eggs and Amber",
		"rows": [
			["egg", "Win a battle: a clutch of [b]3 eggs[/b] and %d Amber. Lose: %d Amber."],
			["egg", "Check in every day for a free clutch and a bonus that grows all week. Or buy one for %d Amber, or a [b]Rare clutch[/b] (better odds) for %d."],
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
		_prev = UiKit.button("Back", UiKit.BUTTON_GRAY, 76, 28)
		_prev.pressed.connect(_turn.bind(-1))
		_page_label = UiKit.label("", 29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
		_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_next = UiKit.button("Next", UiKit.BUTTON_GREEN, 76, 28)
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
	if page.has("custom"):
		call(page["custom"])
	for row in page.get("rows", []):
		_body.add_child(_row(row[0], _fill_numbers(row[1])))
	if not _intro:
		_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
		_prev.disabled = _page == 0
		_next.text = "Done" if _page == PAGES.size() - 1 else "Next"


# --- Stats pages ----------------------------------------------------------------------------

const STAT_TEXT: Array[String] = [
	"[b]Attack[/b]: how hard it hits. More Attack, more damage.",
	"[b]Defense[/b]: taken off every hit it receives.",
	"[b]Speed[/b]: the faster dino's Bite or Charge lands first.",
	"[b]Health[/b]: at 0 it's knocked out (K.O.).",
]


## A card with every stat ringed, arrows pointing at each, and what each one does.
func _stats_page() -> void:
	_body.add_child(_rich("Every dino card shows four stats along the bottom."))
	var card := _example_card(&"t_rex", 240.0, [[0, Palette.STAT_COLORS[0]], [1, Palette.STAT_COLORS[1]],
			[2, Palette.STAT_COLORS[2]], [3, Palette.STAT_COLORS[3]]])
	var holder := UiKit.vbox(0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(card)
	holder.add_child(StatPointers.make(card))
	_body.add_child(holder)
	for i in 4:
		_body.add_child(_row("stat:%d" % i, STAT_TEXT[i]))
	_body.add_child(_rich("[color=#8dffa0]Green[/color] numbers are boosted by your party bonuses (era bond, balanced)."))


## A worked example: T. rex against Pteranodon, with the numbers from the real damage rules.
func _damage_page() -> void:
	var rex_def := Session.catalog.find(&"t_rex")
	var ptera_def := Session.catalog.find(&"pteranodon")
	var rex := Combatant.from_def(rex_def, false, false)
	var ptera := Combatant.from_def(ptera_def, false, false)
	var row := UiKit.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	row.add_child(_example_card(&"t_rex", 190.0, [[0, Palette.STAT_COLORS[0]], [2, Palette.STAT_COLORS[2]]]))
	var versus := UiKit.title("vs", 34, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	versus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(versus)
	row.add_child(_example_card(&"pteranodon", 190.0, [[1, Palette.STAT_COLORS[1]], [2, Palette.STAT_COLORS[2]]]))
	_body.add_child(row)

	var edge := BattleEngine.ADVANTAGE_MULTIPLIER
	var boosted := floori(rex.attack * edge)
	_body.add_child(_row("move:0", "[b]%s bites[/b]: Attack %d × %s (Land beats Sky) = %d, minus %s's Defense %d = [b]%d damage[/b]." % [
			rex_def.display_name, rex.attack, _num(edge), boosted, ptera_def.display_name, ptera.defense,
			BattleEngine.damage(rex, ptera, false)]))
	_body.add_child(_row("move:1", "[b]A Charge doubles it[/b]: %d × %s × 2 = %d, minus %d = [b]%d damage[/b]." % [
			rex.attack, _num(edge), floori(rex.attack * edge * BattleEngine.CHARGE_MULTIPLIER), ptera.defense,
			BattleEngine.damage(rex, ptera, true)]))
	_body.add_child(_row("move:0", "[b]%s bites back[/b]: %d − %d = [b]%d damage[/b] (Sky doesn't beat Land)." % [
			ptera_def.display_name, ptera.attack, rex.defense, BattleEngine.damage(ptera, rex, false)]))
	_body.add_child(_row("stat:2", "[b]Who hits first?[/b] Speed %d beats %d, so %s's Bite lands first. Equal Speed: both hit at once." % [
			ptera.speed, rex.speed, ptera_def.display_name]))
	_body.add_child(_rich("Damage is rounded down and is never less than 1."))


func _example_card(id: StringName, card_width: float, rings: Array) -> DinoCard:
	var card := DinoCard.create(Session.catalog.find(id), DinoCard.Mode.FULL, null, false, card_width)
	card.inspect_on_hold = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(StatRings.make(card, rings))
	return card


func _rich(text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = text
	label.add_theme_font_size_override("normal_font_size", 28)
	label.add_theme_font_size_override("bold_font_size", 28)
	label.add_theme_font_override("bold_font", Fonts.bold())
	label.add_theme_color_override("default_color", Palette.TEXT_DIM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _num(value: float) -> String:
	return str(value).trim_suffix(".0")


## Pulsing rings around chosen stat boxes on a card: [[stat index, color], ...].
class StatRings:
	extends Control

	var _card: DinoCard
	var _rings: Array = []

	static func make(card: DinoCard, rings: Array) -> StatRings:
		var overlay := StatRings.new()
		overlay._card = card
		overlay._rings = rings
		overlay.size = card.size
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return overlay

	func _ready() -> void:
		var pulse := create_tween().set_loops()
		pulse.tween_property(self, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		for ring in _rings:
			var box: Rect2 = _card.stat_box_rect(ring[0]).grow(_card.width * 0.022)
			var style := StyleBoxFlat.new()
			style.draw_center = false
			style.border_color = ring[1]
			style.set_border_width_all(maxi(3, int(_card.width * 0.018)))
			style.set_corner_radius_all(int(_card.width * 0.04))
			draw_style_box(style, box)


## Under a card: an arrow pointing up at each stat box, with its name in the stat's color.
class StatPointers:
	extends Control

	var _card: DinoCard

	static func make(card: DinoCard) -> StatPointers:
		var pointers := StatPointers.new()
		pointers._card = card
		pointers.custom_minimum_size = Vector2(card.size.x, 52)
		pointers.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pointers

	func _draw() -> void:
		var font := Fonts.condensed_bold()
		for i in 4:
			var x := _card.stat_box_rect(i).get_center().x
			var color := Palette.STAT_COLORS[i]
			draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x - 8, 16), Vector2(x + 8, 16)]), color)
			draw_line(Vector2(x, 14), Vector2(x, 22), color, 3.0)
			var text := Palette.STAT_CODES[i]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, Vector2(x - width / 2, 46), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)


## Puts the live game numbers into the texts that mention them, so they can't go stale.
func _fill_numbers(text: String) -> String:
	if text.contains("%d or less"):
		return text % PartyRules.POINT_CAP
	if text.begins_with("Win a battle"):
		return text % [Economy.WIN_AMBER, Economy.LOSS_AMBER]
	if text.contains("buy one for"):
		return text % [Economy.CLUTCH_PRICE, Economy.RARE_CLUTCH_PRICE]
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
		chip.custom_minimum_size = Vector2(150, 48)
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var inside := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
		var glyph := TextureRect.new()
		glyph.texture = Icons.texture(Icons.MOVES[index], 30)
		glyph.custom_minimum_size = Vector2(30, 30)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inside.add_child(glyph)
		var move_name := UiKit.title(BattleAction.KIND_NAMES[index], 29, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
		move_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inside.add_child(move_name)
		chip.add_child(inside)
		row.add_child(chip)
	elif icon.begins_with("stat:"):
		var stat := int(icon.get_slice(":", 1))
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.STAT_COLORS[stat], 0.22)
		style.border_color = Palette.STAT_COLORS[stat]
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		chip.add_theme_stylebox_override("panel", style)
		chip.custom_minimum_size = Vector2(150, 48)
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var inside := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
		var glyph := TextureRect.new()
		glyph.texture = Icons.texture(Palette.STAT_ICONS[stat], 28)
		glyph.custom_minimum_size = Vector2(28, 28)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inside.add_child(glyph)
		var code := UiKit.title(Palette.STAT_CODES[stat], 29, Palette.STAT_COLORS[stat], HORIZONTAL_ALIGNMENT_CENTER, false)
		code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inside.add_child(code)
		chip.add_child(inside)
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
	label.add_theme_font_size_override("normal_font_size", 28)
	label.add_theme_font_size_override("bold_font_size", 28)
	label.add_theme_font_override("bold_font", Fonts.bold())
	label.add_theme_color_override("default_color", Palette.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
