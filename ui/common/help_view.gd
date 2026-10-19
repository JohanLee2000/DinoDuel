class_name HelpView
extends Control
## "How to play" (topics menu, Jo 2026-10-19): a short list of topics (Battles, Your party, the
## Journey, Eggs and Amber, Collection, Goals), each a few pages. Opened as the menu from Settings,
## at the Battles topic from the ? button in battle, and as the moves page alone (with a "Let's go"
## button) at the start of the first battle's tutorial. Numbers in the texts come from the game's
## rules ({placeholders}, see _numbers), so they can't go stale, and most pages have a picture built
## from the game's real pieces (see Pictures).

signal closed

const MOVE_COLORS := ["d92b3a", "ff7a1a", "2e7bff", "8fa3bf"]
## Mastery ribbon names, by rank (the colors are DinoCard.RIBBON_COLORS).
const RIBBON_NAMES := {2: "bronze", 3: "silver", 4: "gold", 5: "pink"}
const TOPICS := [
	{
		"title": "Battles",
		"icon": "move_bite",
		"about": "Moves, stats, damage and types",
		"pages": [
			{
				"title": "Battle moves",
				"picture": "_pic_moves",
				"rows": [
					["", "Each turn you and your rival pick a move [b]at the same time[/b]. Knock out all 3 of the rival's dinos to win."],
					["move:0", "A quick hit. [b]Beats Charge[/b] by cancelling it."],
					["move:1", "Double damage, but acts last. [b]Beats Brace[/b] by smashing through it."],
					["move:2", "Blocks a Bite and bites back: [b]beats Bite[/b]. Can't Brace two turns in a row."],
					["move:3", "[b]Swap Dino[/b] goes first. Benched dinos heal {bench_heal} HP every turn."],
				],
			},
			{"title": "Dino stats", "custom": "_stats_page"},
			{"title": "Damage and speed", "custom": "_damage_page"},
			{
				"title": "Land, Sky and Sea",
				"picture": "_pic_types",
				"rows": [
					["type_land", "[b]Land beats Sky[/b]: it pounces on pterosaurs on the ground."],
					["type_sky", "[b]Sky beats Sea[/b]: it dives on marine reptiles."],
					["type_sea", "[b]Sea beats Land[/b]: it ambushes at the water's edge."],
					["", "Hitting a type you beat does [b]+50% damage[/b]. The damage on the move buttons already includes it, with a gold [b]Type advantage[/b] tag above them."],
				],
			},
			{
				"title": "Knockouts and the meteor",
				"picture": "_pic_knockout",
				"rows": [
					["", "When one of your dinos is knocked out, you pick who comes in next. Benched dinos keep the HP they have."],
					["", "From turn [b]{meteor_turn}[/b], a [b]meteor shower[/b] hits both active dinos every turn. It can bring one down to 1 HP, but never knocks it out."],
					["", "Tap the text box during a battle to read the whole battle log."],
					["", "[b]Leave[/b] ends the battle early. It counts as a loss, with no reward."],
				],
			},
		],
	},
	{
		"title": "Your party",
		"icon": "cards",
		"about": "Picking 3, Party Points, bonuses, saved parties",
		"pages": [
			{
				"title": "Bring 6, pick 3",
				"picture": "_pic_pick_summary",
				"rows": [
					["", "Bring [b]6[/b] dinos. Before each battle you see the rival's 6, then secretly pick [b]3[/b]."],
					["", "Party Points: N 1, R 2, SR 3, SSR 4, UR 5. Your 3 must add up to [b]{cap} or less[/b]."],
					["", "[b]Era bond[/b]: all 3 from the same era give +{bond_attack} Attack and +{bond_speed} Speed each."],
					["", "[b]Balanced[/b]: one Land, one Sky and one Sea give +{balanced_hp} HP each."],
					["", "The pick screen shows the points you have left and which bonuses you'll get."],
				],
			},
			{
				"title": "Saved parties",
				"picture": "_pic_party_slots",
				"rows": [
					["cards", "Keep up to [b]{party_slots} parties[/b]: tap Party 1, 2 or 3 on the Party tab. Changes save on their own."],
					["edit", "Tap the pencil to name the open party, like \"Sea squad\"."],
					["", "Switch parties on the pick screen too, to bring the right 6 against each rival."],
					["", "Search, filter and sort by ATK, DEF or SPD to find dinos fast. [b]Hold any card[/b] to see it bigger."],
				],
			},
		],
	},
	{
		"title": "The Journey",
		"icon": "map",
		"about": "The trail, rivals, stars and chests",
		"pages": [
			{
				"title": "The trail",
				"picture": "_pic_trail",
				"rows": [
					["map", "The Journey travels through time: the [b]Triassic[/b], [b]Jurassic[/b] and [b]Cretaceous[/b], then the finale, [b]Extinction Day[/b]."],
					["", "Each era is a trail of rivals. Tap the [b]glowing[/b] one to see their team and what you'll win, then battle."],
					["", "Win to open the next rival on the trail. You can battle rivals you've beaten again anytime."],
					["crown", "[b]Rival Rory[/b] waits at the end of every era. Beat him to open the next era."],
					["", "On Extinction Day the meteor shower starts on turn [b]{finale_meteor}[/b], not {meteor_turn}. Be quick!"],
				],
			},
			{
				"title": "Reading your rivals",
				"picture": "_pic_rival",
				"rows": [
					["", "Every rival has a [b]habit[/b], like biting a lot or bracing often. Their description hints at it: read it and play the counter."],
					["", "Later rivals [b]learn[/b] how you play, so mix up your moves."],
					["", "You see their 6 dinos before you pick yours: bring types that beat theirs."],
					["crown", "Bosses bring an [b]Alpha[/b]: +{alpha_hp}% HP and +{alpha_attack} Attack, and it always plays."],
				],
			},
			{
				"title": "Stars, chests and rewards",
				"picture": "_pic_stars_chests",
				"rows": [
					["star", "[b]Stars[/b]: when you win, one for each of your dinos still standing (up to 3). Your best result against each rival counts."],
					["chest", "Each era has 3 [b]star chests[/b]: {chests}. Tap a full chest on the Journey tab to open it."],
					["egg", "Your [b]first win[/b] against a rival gives an egg clutch and bonus Amber. Bosses add a Rare clutch, and the finale 2."],
					["", "[b]Win again[/b] for an egg clutch + {replay_amber} Amber, and another try at 3 stars. A rival's popup shows exactly what you'll get."],
				],
			},
		],
	},
	{
		"title": "Eggs and Amber",
		"icon": "egg",
		"about": "Clutches, odds, Shiny dinos, crafting",
		"pages": [
			{
				"title": "Clutches and eggs",
				"rows": [
					["egg", "A clutch holds [b]{eggs} eggs[/b], and each hatches one dino. Win battles and check in daily for free clutches."],
					["egg", "Buy a clutch for {clutch_price} Amber, or a [b]Rare clutch[/b] (better odds) for {rare_price}. With both kinds waiting, Hatch asks which one."],
					["", "Tap an egg to crack it: its glow shows how rare it is. 1 in {shiny} is a [b]Shiny[/b], with a special look."],
					["", "No SSR (Epic) or better for {pity_minus} clutches in a row? The next one is guaranteed one."],
					["history", "[b]Hatch history[/b] on the Eggs tab lists your last {history} clutches."],
				],
			},
			{
				"title": "Amber and crafting",
				"picture": "_pic_craft",
				"rows": [
					["amber", "Duplicates melt into Amber: N {melt_0}, R {melt_1}, SR {melt_2}, SSR {melt_3}, UR {melt_4}."],
					["book", "In the Dex, tap a missing dino to [b]craft[/b] it for Amber: N {craft_0}, R {craft_1}, SR {craft_2}, SSR {craft_3}, UR {craft_4}."],
					["", "Amber also comes from battles, daily quests, goals and star chests."],
				],
			},
		],
	},
	{
		"title": "Collection",
		"icon": "book",
		"about": "The Dex, sets and dino mastery",
		"pages": [
			{
				"title": "The Dex",
				"picture": "_pic_dex",
				"rows": [
					["book", "Every dino, by era. The ones you own show in full, ones you've battled show faded, and the rest are \"???\"."],
					["", "A [color=#ff3b4e]red dot[/color] marks a new dino you haven't looked at yet."],
					["", "Search, filter by type, tier and era, or show only Owned, Missing or Can craft."],
					["", "Collect a whole era for a gold badge, and every dino in a [b]set[/b] for Amber (on the Goals tab)."],
				],
			},
			{"title": "Dino mastery", "picture": "_pic_mastery", "custom": "_mastery_page"},
		],
	},
	{
		"title": "Goals",
		"icon": "trophy",
		"about": "Daily quests, check-in, sets, achievements",
		"pages": [
			{
				"title": "Goals",
				"picture": "_pic_goals",
				"rows": [
					["", "[b]Today[/b]: the daily check-in and {quests} quests, plus a bonus clutch for finishing all of them. New quests every day at midnight."],
					["egg", "Check in every day for a free clutch and a bonus that grows all week ({checkin_last} on day {checkin_days}). Missing a day pauses the streak; it doesn't reset."],
					["", "[b]Collection[/b]: rewards every 10 dinos, for each era and for each set. Tap a set to see its cards."],
					["trophy", "[b]Achievements[/b]: long-term goals that pay Amber."],
					["", "[b]Claim all[/b] collects every ready reward at once. A red dot shows where something is ready."],
				],
			},
		],
	},
]

## Which topic is open (-1: the topics menu) and which of its pages.
var _topic := -1
var _page := 0
var _intro := false
var _title: Label
var _subtitle: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _nav: HBoxContainer


## Opens How to play over the current screen: the topics menu, or `topic` (an index into TOPICS)
## at `page`. `intro` shows just that page with a "Let's go" button (the tutorial's opening card).
static func open(topic := -1, page := 0, intro := false) -> HelpView:
	var view := HelpView.new()
	view._topic = topic
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

	var column := UiKit.vbox(16)
	var header := UiKit.hbox(12)
	var words := UiKit.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle = UiKit.label("", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
	words.add_child(_subtitle)
	_title = UiKit.title("", 40, Palette.HIGHLIGHT)
	words.add_child(_title)
	header.add_child(words)
	if not _intro:
		var close_button := UiKit.button("", UiKit.BUTTON_GRAY, 60, 24)
		close_button.icon = Icons.texture(&"close", 28)
		close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		close_button.custom_minimum_size.x = 64
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		close_button.pressed.connect(close)
		header.add_child(close_button)
	column.add_child(header)
	_body = UiKit.vbox(16)
	_scroll = UiKit.vscroll(_body)
	column.add_child(_scroll)
	_nav = UiKit.hbox(12)
	column.add_child(_nav)
	margin.add_child(UiKit.panel(column, Palette.PANEL, 28))
	_show()
	if _intro and Session.autoplay:
		await get_tree().create_timer(2.0).timeout
		close()


## Draws the menu or the open page, and the buttons under it.
func _show() -> void:
	for node in [_body, _nav]:
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
	_scroll.scroll_vertical = 0
	if _topic < 0:
		_show_menu()
		return
	var topic: Dictionary = TOPICS[_topic]
	var pages: Array = topic["pages"]
	var page: Dictionary = pages[_page]
	_title.text = ("How to play" if _intro else page["title"]).to_upper()
	_subtitle.text = "" if _intro else "%s  ·  %d / %d" % [topic["title"], _page + 1, pages.size()]
	_subtitle.visible = not _intro
	if page.has("picture"):
		_body.add_child(_framed(call(page["picture"])))
	if page.has("custom"):
		call(page["custom"])
	var numbers := _numbers()
	for row in page.get("rows", []):
		_body.add_child(_row(row[0], String(row[1]).format(numbers)))

	if _intro:
		var go := UiKit.button("Let's go!", UiKit.BUTTON_GREEN, 84, 30)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(close)
		_nav.add_child(go)
		return
	# Back from a topic's first page, and Next past its last, both lead to the topics menu (a
	# one-page topic just has the one Topics button).
	if pages.size() > 1:
		var back := UiKit.button("Topics" if _page == 0 else "Back", UiKit.BUTTON_GRAY, 76, 28)
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back.pressed.connect(_turn.bind(-1))
		_nav.add_child(back)
	var next := UiKit.button("Topics" if _page == pages.size() - 1 else "Next", UiKit.BUTTON_GREEN, 76, 28)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_turn.bind(1))
	_nav.add_child(next)


func _show_menu() -> void:
	_title.text = "HOW TO PLAY"
	_subtitle.visible = false
	_body.add_child(UiKit.label("Pick a topic.", 28, Palette.TEXT_DIM))
	for index in TOPICS.size():
		_body.add_child(_topic_button(index))
	var done := UiKit.button("Close", UiKit.BUTTON_GREEN, 76, 28)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(close)
	_nav.add_child(done)


## A wide button: the topic's icon, its name, and what it covers.
func _topic_button(index: int) -> Button:
	var topic: Dictionary = TOPICS[index]
	var button := UiKit.let_scroll(UiKit.button("", UiKit.BUTTON_GRAY, 108, 24))
	var row := UiKit.hbox(18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -18
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.texture(StringName(topic["icon"]), 52)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := UiKit.vbox(2)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiKit.title(topic["title"], 32, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var about := UiKit.label(topic["about"], 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
	about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(about)
	row.add_child(words)
	var arrow := UiKit.title("›", 44, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	button.add_child(row)
	button.pressed.connect(func() -> void:
		Sound.play(&"tap")
		_topic = index
		_page = 0
		_show())
	return button


func _turn(step: int) -> void:
	Sound.play(&"tap")
	var pages: Array = TOPICS[_topic]["pages"]
	_page += step
	if _page < 0 or _page >= pages.size():
		_topic = -1
		_page = 0
	_show()


## The live numbers the texts mention ({cap}, {meteor_turn}, ...).
func _numbers() -> Dictionary:
	var chests: Array[String] = []
	for chest in Journey.STAR_CHESTS:
		var reward := "%d Amber" % chest[1] if chest[1] > 0 else ("a clutch" if chest[2] > 0 else "a Rare clutch")
		chests.append("%d★ %s" % [chest[0], reward])
	var finale := Journey.chapter_stages(Journey.FINALE)
	var last_bonus: Dictionary = Economy.CHECKIN_BONUSES[Economy.CHECKIN_BONUSES.size() - 1]
	var numbers := {
		"bench_heal": BattleEngine.BENCH_HEAL,
		"meteor_turn": BattleEngine.METEOR_START_TURN,
		"finale_meteor": finale[0].meteor_turn if not finale.is_empty() else BattleEngine.METEOR_START_TURN,
		"cap": PartyRules.POINT_CAP,
		"bond_attack": PartyRules.ERA_BOND_ATTACK,
		"bond_speed": PartyRules.ERA_BOND_SPEED,
		"balanced_hp": PartyRules.BALANCED_HEALTH,
		"party_slots": PlayerProfile.PARTY_SLOTS,
		"alpha_hp": roundi(BattleEngine.ALPHA_HEALTH_BONUS * 100),
		"alpha_attack": BattleEngine.ALPHA_ATTACK_BONUS,
		"chests": "%s, %s and %s" % chests,
		"replay_amber": Economy.REPLAY_AMBER,
		"eggs": Economy.EGGS_PER_CLUTCH,
		"clutch_price": Economy.CLUTCH_PRICE,
		"rare_price": Economy.RARE_CLUTCH_PRICE,
		"shiny": roundi(1.0 / Economy.SHINY_ODDS),
		"pity_minus": Economy.PITY_CLUTCHES - 1,
		"history": PlayerProfile.HATCH_HISTORY_SIZE,
		"quests": Goals.QUESTS_PER_DAY,
		"checkin_days": Economy.CHECKIN_BONUSES.size(),
		"checkin_last": "a Rare clutch" if last_bonus.has("rare_clutches") else CheckInView.bonus_text(Economy.CHECKIN_BONUSES.size() - 1),
	}
	for tier in DinoDef.RARITY_NAMES.size():
		numbers["melt_%d" % tier] = Economy.MELT_VALUE[tier]
		numbers["craft_%d" % tier] = Economy.CRAFT_COST[tier]
	return numbers


## Mastery: what counts, then each rank, its ribbon and what earns it (from Mastery.RANKS).
func _mastery_page() -> void:
	_body.add_child(_rich("Every dino you own builds its own history: battles, wins, [b]counters[/b] (turns its move beat the rival's) and Journey bosses it helped defeat. Ranks are earned in order:"))
	for rank in range(1, Mastery.RANKS.size() + 1):
		var ribbon := " %s ribbon." % RIBBON_NAMES[rank].capitalize() if RIBBON_NAMES.has(rank) else ""
		var icon := "dot:%s" % (DinoCard.RIBBON_COLORS[rank] as Color).to_html(false) if DinoCard.RIBBON_COLORS.has(rank) else ""
		var earned := Mastery.description_of(rank)
		_body.add_child(_row(icon if icon != "" else "dot:-", "[b]%s[/b]: %s%s" % [Mastery.title_of(rank),
				earned.left(1).to_lower() + earned.substr(1), ribbon]))
	_body.add_child(_rich("A dino's rank and progress show in its Dex entry, and from Fighter up a ribbon shows on its card."))


# --- Pictures (Jo, 2026-10-19) --------------------------------------------------------------
# One per page where it helps, built from the game's real pieces (cards, map markers, icons and
# buttons), so they always look like what the player sees.

## The move buttons' colors in a battle (BattleScreen.BUTTON_COLORS).
const BATTLE_BUTTON_COLORS: Array[Color] = [Color("d92b3a"), Color("ff7a1a"), Color("2e7bff"), Color("34445e")]


## A page's picture in a slightly lighter box, centered. Pictures are only to look at, so taps and
## drags go through them (the page still scrolls).
func _framed(content: Control) -> Control:
	var well := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	well.add_theme_stylebox_override("panel", style)
	var center := CenterContainer.new()
	center.add_child(content)
	well.add_child(center)
	# Some pieces (map markers) build their insides once they're on screen.
	_inert.call_deferred(well)
	_inert(well)
	return well


static func _inert(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_inert(child)


## `content` with a short caption under it.
func _captioned(content: Control, text: String, color := Palette.TEXT_DIM) -> Control:
	var box := UiKit.vbox(6)
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(content)
	box.add_child(UiKit.label(text, 22, color, HORIZONTAL_ALIGNMENT_CENTER, false))
	return box


func _card(id: StringName, card_width: float, mode := DinoCard.Mode.FULL) -> DinoCard:
	var card := DinoCard.create(Session.catalog.find(id), mode, null, false, card_width)
	card.inspect_on_hold = false
	return card


## The four move buttons as they look in a battle (T. rex against Pteranodon), with the gold tag.
func _pic_moves() -> Control:
	var rex := Combatant.from_def(Session.catalog.find(&"t_rex"), false, false)
	var ptera := Combatant.from_def(Session.catalog.find(&"pteranodon"), false, false)
	var box := UiKit.vbox(10)
	box.add_child(_edge_tag())
	var grid := UiKit.grid(2, 10)
	var texts: Array[String] = ["Bite · %d damage\nBeats Charge" % BattleEngine.damage(rex, ptera, false),
			"Charge · %d damage\nBeats Brace, acts last" % BattleEngine.damage(rex, ptera, true),
			"Brace\nBeats Bite", "Swap Dino\nGoes first"]
	for i in 4:
		var button := UiKit.button(texts[i], BATTLE_BUTTON_COLORS[i], 80, 21)
		button.icon = Icons.texture(Icons.MOVES[i], 30)
		button.add_theme_constant_override("icon_max_width", 30)
		button.custom_minimum_size.x = 272
		grid.add_child(button)
	box.add_child(grid)
	return box


## "Type advantage · bonus included", as in a battle.
func _edge_tag() -> Control:
	var tag := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.92)
	style.border_color = Palette.HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 3
	style.content_margin_bottom = 5
	tag.add_theme_stylebox_override("panel", style)
	var text := UiKit.label("Type advantage · bonus included", 22, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	text.add_theme_font_override("font", Fonts.bold())
	tag.add_child(text)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tag


## Land, Sky and Sea in a circle, each arrow pointing at the type it beats.
func _pic_types() -> Control:
	var box := UiKit.vbox(10)
	box.add_child(TypeCycle.new())
	box.add_child(_edge_tag())
	return box


## A knocked-out dino and the benched one you pick to come in.
func _pic_knockout() -> Control:
	var row := UiKit.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	var out_def := Session.catalog.find(&"pteranodon")
	var out := Combatant.from_def(out_def, false, false)
	out.health = 0
	var ko := DinoCard.create(out_def, DinoCard.Mode.BATTLE, out, false, 170)
	ko.inspect_on_hold = false
	ko.display_health(0)
	row.add_child(_captioned(ko, "Knocked out"))
	var arrow := UiKit.title("→", 44, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var in_def := Session.catalog.find(&"mosasaurus")
	var benched := Combatant.from_def(in_def, false, false)
	benched.health = benched.max_health - 4
	var next := DinoCard.create(in_def, DinoCard.Mode.MINI, benched, false, 118)
	next.inspect_on_hold = false
	next.display_health(benched.health)
	next.highlighted = true
	row.add_child(_captioned(next, "Tap who comes in\n(keeps its HP)"))
	return row


## The pick screen's summary: picks and points, the points bar, and the two bonus chips.
func _pic_pick_summary() -> Control:
	var box := UiKit.vbox(8)
	box.custom_minimum_size.x = 540
	var count := UiKit.label("2 / 3 selected  •  7 / %d points" % PartyRules.POINT_CAP, 28, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, false)
	count.add_theme_font_override("font", Fonts.bold())
	box.add_child(count)
	var bar := UiKit.hbox(4)
	var used: Array[Color] = []
	for i in 3:
		used.append(Palette.RARITY_COLORS[DinoDef.Rarity.SUPER_RARE])
	for i in 4:
		used.append(Palette.RARITY_COLORS[DinoDef.Rarity.EPIC])
	for i in PartyRules.POINT_CAP:
		var piece := Panel.new()
		piece.custom_minimum_size = Vector2(0, 14)
		piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.bg_color = used[i] if i < used.size() else Color(1, 1, 1, 0.1)
		piece.add_theme_stylebox_override("panel", style)
		bar.add_child(piece)
	box.add_child(bar)
	box.add_child(UiKit.label("Choose 1 more dino costing %d points or less." % (PartyRules.POINT_CAP - 7), 24,
			Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	var chips := UiKit.hbox(10)
	chips.add_child(_chip("Era bond: 1 more Jurassic", false))
	chips.add_child(_chip("Balanced: needs Sea", false))
	box.add_child(chips)
	return box


## A bonus chip as on the pick screen: gold when it's on.
func _chip(text: String, on: bool) -> Control:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.bg_color = Color(Palette.HIGHLIGHT, 0.2) if on else Color(1, 1, 1, 0.05)
	style.border_color = Palette.HIGHLIGHT if on else Color(Palette.TEXT, 0.35)
	chip.add_theme_stylebox_override("panel", style)
	var label := UiKit.label(text, 21, Palette.HIGHLIGHT if on else Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	label.add_theme_font_override("font", Fonts.bold())
	chip.add_child(label)
	return chip


## The Party tab's slot buttons, with one renamed.
func _pic_party_slots() -> Control:
	var row := UiKit.hbox(8)
	row.custom_minimum_size.x = 540
	var names: Array[String] = ["Party 1", "Sea squad", "Party 3"]
	for i in names.size():
		var button := UiKit.button(names[i], UiKit.BUTTON_GREEN if i == 1 else UiKit.BUTTON_GRAY, 60, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	var pencil := UiKit.button("", UiKit.BUTTON_GRAY, 60, 22)
	pencil.icon = Icons.texture(&"edit", 28)
	pencil.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pencil.custom_minimum_size.x = 64
	row.add_child(pencil)
	return row


## Three markers from the Triassic trail: beaten (with stars), next (glowing) and locked.
func _pic_trail() -> Control:
	var row := UiKit.hbox(4, BoxContainer.ALIGNMENT_CENTER)
	for entry in [[&"rae", 3, true, false, "Beaten: best stars"], [&"fern", 0, true, true, "Next: tap it!"],
			[&"cora", 0, false, false, "Locked for now"]]:
		var stage := Journey.find(entry[0])
		if stage == null:
			continue
		var marker := StageMarker.create(stage, entry[1], entry[2], entry[3])
		row.add_child(_captioned(marker, entry[4], Palette.HIGHLIGHT if entry[3] else Palette.TEXT_DIM))
	return row


## Ranger Fern and her description: it gives her habit away.
func _pic_rival() -> Control:
	var stage := Journey.find(&"fern")
	var row := UiKit.hbox(14)
	row.custom_minimum_size.x = 540
	var sprite := TextureRect.new()
	sprite.texture = RivalArt.sprite(stage.character)
	sprite.custom_minimum_size = Vector2(130, 150)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(sprite)
	var words := UiKit.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UiKit.title(stage.display_name, 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	words.add_child(UiKit.label("\"%s\"" % stage.intro, 24, Palette.TEXT))
	row.add_child(words)
	return row


## Stars for one win, and an era's three chests with what they hold.
func _pic_stars_chests() -> Control:
	var box := UiKit.vbox(14)
	var stars := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	for i in Journey.MAX_STARS:
		stars.add_child(_icon(&"star" if i < 2 else &"star_empty", 46))
	var note := UiKit.label("  2 dinos still standing = 2 stars", 24, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stars.add_child(note)
	box.add_child(stars)
	var chests := UiKit.hbox(26, BoxContainer.ALIGNMENT_CENTER)
	for chest in Journey.STAR_CHESTS:
		var reward := "%d Amber" % chest[1] if chest[1] > 0 else ("a clutch" if chest[2] > 0 else "a Rare clutch")
		var column := UiKit.vbox(2)
		var icon := _icon(&"chest", 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		column.add_child(UiKit.title("%d ★" % chest[0], 26, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false))
		column.add_child(UiKit.label(reward, 22, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		chests.add_child(column)
	box.add_child(chests)
	return box


func _icon(icon_name: StringName, icon_size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name, icon_size)
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


## A missing dino in the Dex, with its Craft button.
func _pic_craft() -> Control:
	var row := UiKit.hbox(20, BoxContainer.ALIGNMENT_CENTER)
	var dino := Session.catalog.find(&"cryolophosaurus")
	var back := DinoCard.create_unknown(dino, DinoCard.Mode.FULL, 140)
	back.inspect_on_hold = false
	row.add_child(back)
	var side := UiKit.vbox(10)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	var cost: int = Economy.CRAFT_COST[dino.rarity]
	var craft := UiKit.button("Craft  ·  %d Amber" % cost, UiKit.BUTTON_AMBER, 72, 24)
	craft.custom_minimum_size.x = 300
	side.add_child(craft)
	var melt := UiKit.hbox(8)
	melt.add_child(_icon(&"amber", 34))
	var line := UiKit.label("A duplicate SR melts into %d" % Economy.MELT_VALUE[DinoDef.Rarity.SUPER_RARE], 22, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, false)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	melt.add_child(line)
	side.add_child(melt)
	row.add_child(side)
	return row


## The Dex's three looks: yours (here new, with the dot), battled but not yours, and not found yet.
func _pic_dex() -> Control:
	var row := UiKit.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	var owned := _card(&"triceratops", 150)
	owned.is_new = true
	row.add_child(_captioned(owned, "Yours (dot: new)"))
	var seen := _card(&"pteranodon", 150)
	seen.modulate = Color(1, 1, 1, 0.45)
	row.add_child(_captioned(seen, "Battled, not yours"))
	var unknown := DinoCard.create_unknown(Session.catalog.find(&"cryolophosaurus"), DinoCard.Mode.FULL, 150)
	unknown.inspect_on_hold = false
	row.add_child(_captioned(unknown, "Not found yet"))
	return row


## Where mastery shows: the ribbon on the card (circled), and the mastery panel in its Dex entry
## (a small copy of the card's details, the panel outlined), for a Legend T. rex.
func _pic_mastery() -> Control:
	var row := UiKit.hbox(18, BoxContainer.ALIGNMENT_CENTER)
	var card := _card(&"t_rex", 170)
	card.mastery_rank = Mastery.RANKS.size()
	card.add_child(RibbonRing.make(card))
	row.add_child(_captioned(card, "Its ribbon on the card"))
	row.add_child(_captioned(_mini_dex_entry(), "Its Dex entry\n(tap it in the Dex)"))
	return row


## A small copy of a Dex entry: the card, its tier line, and the mastery panel (outlined in gold).
func _mini_dex_entry() -> Control:
	var sample := PlayerProfile.new()
	sample.mastery["t_rex"] = {"battles": 31, "wins": 27, "counters": 30, "bosses": 4}
	var rank := Mastery.rank_of(sample, &"t_rex")
	var stats := Mastery.stats_of(sample, &"t_rex")
	var dino := Session.catalog.find(&"t_rex")

	var column := UiKit.vbox(6)
	column.custom_minimum_size.x = 250
	var card := _card(&"t_rex", 104)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(card)
	column.add_child(UiKit.label("%s %s  ·  %s" % [dino.rarity_code(), dino.rarity_name(), Palette.TYPE_LABELS[dino.dino_type]],
			17, Palette.RARITY_COLORS[dino.rarity], HORIZONTAL_ALIGNMENT_CENTER, false))
	var info := UiKit.vbox(2)
	var earned := Mastery.description_of(rank).trim_suffix(".")
	info.add_child(UiKit.label("%s: %s" % [Mastery.title_of(rank), earned.left(1).to_lower() + earned.substr(1)], 17,
			DinoCard.RIBBON_COLORS[rank], HORIZONTAL_ALIGNMENT_CENTER))
	info.add_child(UiKit.label("%d battles · %d wins · %d counters · %d bosses" % [stats["battles"], stats["wins"],
			stats["counters"], stats["bosses"]], 15, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var mastery := PanelContainer.new()
	var outline := StyleBoxFlat.new()
	outline.bg_color = Palette.PANEL
	outline.border_color = Palette.HIGHLIGHT
	outline.set_border_width_all(3)
	outline.set_corner_radius_all(10)
	outline.set_content_margin_all(8)
	mastery.add_theme_stylebox_override("panel", outline)
	mastery.add_child(info)
	column.add_child(mastery)
	var share := UiKit.button("Share", Color(1, 1, 1, 0.14), 34, 16)
	share.custom_minimum_size.x = 140
	share.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(share)

	# The card's details sit on the dark full-screen view.
	var view := PanelContainer.new()
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0, 0, 0, 0.55)
	dark.set_corner_radius_all(12)
	dark.set_content_margin_all(10)
	view.add_theme_stylebox_override("panel", dark)
	view.add_child(column)
	return view


## The top of the Goals tab: Claim all, then the three sections (a red dot where something's ready).
func _pic_goals() -> Control:
	var box := UiKit.vbox(10)
	box.custom_minimum_size.x = 540
	box.add_child(UiKit.button("Claim all ready rewards  (3)", UiKit.BUTTON_GREEN, 64, 24))
	var sections := UiKit.hbox(8)
	var names: Array[String] = ["Today", "Collection", "Achievements"]
	for i in names.size():
		var button := UiKit.button(names[i], UiKit.BUTTON_GREEN if i == 0 else UiKit.BUTTON_GRAY, 56, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i != 2:
			var dot := Panel.new()
			var red := StyleBoxFlat.new()
			red.bg_color = Color("ff3b4e")
			red.border_color = Color.WHITE
			red.set_border_width_all(2)
			red.set_corner_radius_all(10)
			dot.add_theme_stylebox_override("panel", red)
			dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			dot.offset_left = -22
			dot.offset_right = -6
			dot.offset_top = 5
			dot.offset_bottom = 21
			button.add_child(dot)
		sections.add_child(button)
	box.add_child(sections)
	return box


## Land, Sky and Sea medallions around a circle, an arrow from each to the type it beats.
class TypeCycle:
	extends Control

	const ICON := 84.0

	func _init() -> void:
		custom_minimum_size = Vector2(440, 300)

	func _draw() -> void:
		# Land on top, Sky lower right, Sea lower left: Land -> Sky -> Sea -> Land.
		var spots: Array[Vector2] = [Vector2(220, 58), Vector2(370, 232), Vector2(70, 232)]
		var font := Fonts.condensed_bold()
		for i in 3:
			var from := spots[i]
			var to := spots[(i + 1) % 3]
			var direction := (to - from).normalized()
			var start := from + direction * (ICON * 0.62)
			var end := to - direction * (ICON * 0.66)
			draw_line(start, end, Palette.HIGHLIGHT, 4.0, true)
			var side := Vector2(-direction.y, direction.x)
			draw_colored_polygon(PackedVector2Array([end + direction * 4, end - direction * 16 + side * 9,
					end - direction * 16 - side * 9]), Palette.HIGHLIGHT)
			var middle := (start + end) / 2 - side * 18
			var text := "beats"
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, middle - Vector2(width / 2, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.HIGHLIGHT)
		for i in 3:
			var icon := Icons.texture(Icons.type_icon(i), int(ICON))
			draw_texture_rect(icon, Rect2(spots[i] - Vector2.ONE * ICON / 2, Vector2.ONE * ICON), false)
			var label: String = DinoDef.TYPE_NAMES[i].to_upper()
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			var y := spots[i].y + ICON / 2 + 24 if i != 0 else spots[i].y - ICON / 2 - 6
			draw_string(font, Vector2(spots[i].x - width / 2, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.TEXT)


## A pulsing ring around a card's mastery ribbon.
class RibbonRing:
	extends Control

	var _card: DinoCard

	static func make(card: DinoCard) -> RibbonRing:
		var ring := RibbonRing.new()
		ring._card = card
		ring.size = card.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return ring

	func _ready() -> void:
		var pulse := create_tween().set_loops()
		pulse.tween_property(self, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		var rect := _card.ribbon_rect()
		draw_arc(rect.get_center(), rect.size.x * 1.25, 0, TAU, 40, Palette.HIGHLIGHT, 3.0, true)


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
	elif icon.begins_with("dot:"):
		var swatch := Panel.new()
		var disc := StyleBoxFlat.new()
		var hex := icon.get_slice(":", 1)
		disc.draw_center = hex != "-"
		disc.bg_color = Color(hex) if hex != "-" else Color.TRANSPARENT
		disc.border_color = Palette.OUTLINE if hex != "-" else Color(Palette.TEXT_DIM, 0.6)
		disc.set_border_width_all(3)
		disc.set_corner_radius_all(18)
		swatch.add_theme_stylebox_override("panel", disc)
		swatch.custom_minimum_size = Vector2(36, 36)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var slot := CenterContainer.new()
		slot.custom_minimum_size = Vector2(56, 40)
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		slot.add_child(swatch)
		row.add_child(slot)
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


## Android back: from a page to the topics menu, then closes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _topic >= 0 and not _intro:
			_topic = -1
			_page = 0
			_show()
		else:
			close()
