extends VBoxContainer
## Goals tab, in three sections (Jo, 2026-10-15): Today (the daily check-in, today's three quests
## and the bonus clutch for all three), Collection (milestones, full eras, family and themed sets)
## and Achievements. "Claim all ready rewards" claims everything at once and sums up what it gave;
## each row keeps its own Claim too. Tapping a set shows its cards, and tapping a card opens its Dex
## entry. Rules live in core/collection/goals.gd and core/collection/dino_sets.gd.

const SECTION_NAMES: Array[String] = ["Today", "Collection", "Achievements"]
const SET_CARD_WIDTH := 180.0

## The section on show; kept while the app is open.
static var _section: int = Goals.Section.TODAY

var _body: VBoxContainer
var _scroll: ScrollContainer
var _claim_all: Button
var _section_row: HBoxContainer
var _countdown: Label
## Bumped on every rebuild, so a rebuild still adding rows stops if a newer one has started.
var _build := 0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Goals"))
	_claim_all = UiKit.button("", UiKit.BUTTON_GREEN, 76, 28)
	_claim_all.pressed.connect(_on_claim_all)
	add_child(_claim_all)
	_section_row = UiKit.hbox(8)
	add_child(_section_row)
	_body = UiKit.vbox(16)
	_scroll = UiKit.vscroll(_body)
	add_child(_scroll)
	Session.refresh_quests()
	# Dev (--open=goals:<section>|set:<id>|claimall): for screenshots.
	if Session.dev_open.begins_with("goals:"):
		_section = int(Session.dev_open.get_slice(":", 1))
	_refresh(true)
	if Session.dev_open.begins_with("set:"):
		_open_set.call_deferred(StringName(Session.dev_open.get_slice(":", 1)))
	elif Session.dev_open == "claimall":
		_on_claim_all.call_deferred()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(_update_countdown)
	add_child(timer)


## Rebuilds the open section. When the tab opens (`staged`), Collection builds its sets a frame
## later so switching to Goals feels instant on phones. After a claim it's all rebuilt at once and
## the scroll position kept: a staged rebuild showed only the short top part for a frame, which
## jumped the list to the top.
func _refresh(staged := false) -> void:
	_build += 1
	var build := _build
	var keep_scroll := _scroll.scroll_vertical
	for child in _body.get_children():
		# Removed right away (not just queued), so old and new rows never stack for a frame.
		_body.remove_child(child)
		child.queue_free()
	_countdown = null
	_update_header()
	match _section:
		Goals.Section.TODAY:
			_build_today()
		Goals.Section.COLLECTION:
			await _build_collection(staged, build)
		Goals.Section.ACHIEVEMENTS:
			_build_achievements()
	if build != _build:
		return
	_scroll.scroll_vertical = keep_scroll
	_restore_scroll.call_deferred(keep_scroll)


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = value


## Claim all (only while something's ready) and the section buttons, each with a red dot if
## something in it is ready.
func _update_header() -> void:
	var profile := Session.profile
	var today := SaveStore.today()
	var total := Goals.ready_total(profile, Session.catalog, today)
	_claim_all.visible = total > 0
	_claim_all.text = "Claim all ready rewards  (%d)" % total
	for child in _section_row.get_children():
		_section_row.remove_child(child)
		child.queue_free()
	for section in SECTION_NAMES.size():
		var button := UiKit.button(SECTION_NAMES[section], UiKit.BUTTON_GREEN if section == _section else UiKit.BUTTON_GRAY, 64, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _section == section:
				return
			Sound.play(&"tap")
			_section = section
			_scroll.scroll_vertical = 0
			_refresh(true))
		if Goals.ready_in(section, profile, Session.catalog, today) > 0:
			button.add_child(_red_dot())
		_section_row.add_child(button)


func _build_today() -> void:
	var profile := Session.profile
	_body.add_child(_checkin_strip())
	var header := UiKit.hbox(10)
	var heading := UiKit.title("Daily quests", 30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_countdown = UiKit.label(_countdown_text(), 28, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_countdown)
	_body.add_child(header)
	for i in profile.quests.size():
		var quest: Dictionary = profile.quests[i]
		_body.add_child(_row(Goals.quest_text(quest), "", int(quest["progress"]), Goals.quest_target(quest),
				"+%d Amber" % Goals.quest_reward(quest), bool(quest["claimed"]),
				func() -> bool: return Goals.claim_quest(profile, i)))
	var all_done := profile.quests.all(func(q: Dictionary) -> bool: return Goals.quest_done(q))
	_body.add_child(_row("Finish all 3 quests", "A bonus for clearing the day.",
			1 if all_done else 0, 1, "+%d egg clutch" % Goals.QUEST_BONUS_CLUTCHES, profile.quest_bonus_claimed,
			func() -> bool: return Goals.claim_quest_bonus(profile)))


func _build_collection(staged: bool, build: int) -> void:
	var profile := Session.profile
	var catalog := Session.catalog
	var found := Goals.discovered(profile)
	_body.add_child(UiKit.label("%d of %d dinos discovered" % [found, catalog.dinos.size()], 29, Palette.TEXT))
	var milestones := UiKit.grid(3, 10)
	for i in Goals.MILESTONES.size():
		milestones.add_child(_milestone_chip(i))
	_body.add_child(milestones)
	for era in DinoDef.ERA_NAMES.size():
		var progress := Goals.era_progress(profile, catalog, era)
		_body.add_child(_row("Complete the %s" % DinoDef.ERA_NAMES[era], "Discover every %s dino. Earns a gold badge in the Dex." % DinoDef.ERA_NAMES[era],
				progress[0], progress[1], "+%d Amber" % Goals.ERA_AMBER, Goals.era_claimed(profile, era),
				func() -> bool: return Goals.claim_era(profile, catalog, era)))

	if staged:
		await get_tree().process_frame
		if build != _build:
			return
	var set_ids := DinoSets.ids()
	var earned := set_ids.filter(func(id: StringName) -> bool: return DinoSets.claimed(profile, id)).size()
	_body.add_child(UiKit.title("Sets  %d/%d" % [earned, set_ids.size()], 30, Palette.HIGHLIGHT,
			HORIZONTAL_ALIGNMENT_LEFT, false))
	_body.add_child(UiKit.label("Collect every dino in a set for Amber and a badge. Families split all %d dinos; themes mix them up. Tap a set to see its cards." \
			% catalog.dinos.size(), 28, Palette.TEXT_DIM))
	# Families, then themed sets, each with ready-to-claim first and earned badges last.
	for group in [["Families", DinoSets.FAMILIES.keys()], ["Themed sets", DinoSets.THEMES.keys()]]:
		_body.add_child(_divider(group[0]))
		var ids: Array = group[1]
		var set_rank := {}
		for i in ids.size():
			var id: StringName = ids[i]
			set_rank[id] = (2 if DinoSets.claimed(profile, id) else (0 if DinoSets.ready(profile, id) else 1)) * 100 + i
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return set_rank[a] < set_rank[b])
		for id in ids:
			var counts := DinoSets.progress(profile, id)
			_body.add_child(_row(DinoSets.title_of(id), DinoSets.blurb(id), counts[0], counts[1],
					"+%d Amber" % DinoSets.reward(id), DinoSets.claimed(profile, id),
					func() -> bool: return DinoSets.claim(profile, id), _set_members(id), true,
					_open_set.bind(id)))


## Ready to claim first, then in progress, then the ones already claimed.
func _build_achievements() -> void:
	var profile := Session.profile
	var catalog := Session.catalog
	var unlocked := 0
	for id in Goals.ACHIEVEMENTS:
		unlocked += 1 if Goals.achievement_claimed(profile, id) else 0
	_body.add_child(UiKit.title("Achievements  %d/%d" % [unlocked, Goals.ACHIEVEMENTS.size()], 30,
			Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var listed: Array = Goals.ACHIEVEMENTS.keys()
	var rank := {}
	for i in listed.size():
		var id: StringName = listed[i]
		var group := 2 if Goals.achievement_claimed(profile, id) else (0 if Goals.achievement_unlocked(profile, catalog, id) else 1)
		rank[id] = group * 100 + i
	var ids := listed.duplicate()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return rank[a] < rank[b])
	for id in ids:
		var info: Array = Goals.ACHIEVEMENTS[id]
		_body.add_child(_row(info[0], info[1], Goals.achievement_progress(profile, catalog, id),
				Goals.achievement_target(catalog, id), "+%d Amber" % info[3], Goals.achievement_claimed(profile, id),
				func() -> bool: return Goals.claim_achievement(profile, catalog, id)))


func _on_claim_all() -> void:
	var result := Goals.claim_all(Session.profile, Session.catalog, SaveStore.today())
	if result["count"] == 0:
		return
	Sound.play(&"amber")
	Session.save()
	_refresh()
	_show_claimed(result)


## The short summary after Claim all: how many rewards, and the Amber and clutches they gave.
func _show_claimed(result: Dictionary) -> void:
	var dialog := UiKit.modal_layer(0.8)
	dialog.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			dialog.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 520
	column.add_child(UiKit.title("Rewards claimed!", 38, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var count: int = result["count"]
	column.add_child(UiKit.label("%d reward%s" % [count, "" if count == 1 else "s"], 28, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	var lines := [[result["amber"], &"amber", Color.WHITE, "+%d Amber"],
			[result["clutches"], &"egg", Color.WHITE, "+%d clutch"],
			[result["rare_clutches"], &"egg", CheckInView.RARE_TINT.lightened(0.3), "+%d Rare clutch"]]
	for line in lines:
		var amount: int = line[0]
		if amount <= 0:
			continue
		var row := UiKit.hbox(14, BoxContainer.ALIGNMENT_CENTER)
		var icon := TextureRect.new()
		icon.texture = Icons.texture(line[1], 48)
		icon.modulate = line[2]
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(52, 52)
		row.add_child(icon)
		var text: String = line[3] % amount
		if line[1] == &"egg" and amount > 1:
			text += "es"
		row.add_child(UiKit.label(text, 32, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		column.add_child(row)
	var ok := UiKit.button("Nice!", UiKit.BUTTON_GREEN, 72, 28)
	ok.pressed.connect(dialog.queue_free)
	column.add_child(ok)
	var panel := UiKit.panel(column, Palette.PANEL, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	dialog.add_child(center)
	get_tree().current_scene.add_child(dialog)


## A set's cards: the ones you own face up, the rest as card backs. Tap one for its Dex entry.
func _open_set(id: StringName) -> void:
	Sound.play(&"tap")
	var profile := Session.profile
	var dialog := UiKit.modal_layer(0.85)
	dialog.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			dialog.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(12)
	column.custom_minimum_size.x = SET_CARD_WIDTH * 3 + 40
	column.add_child(UiKit.title(DinoSets.title_of(id), 36, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label(DinoSets.blurb(id), 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var counts := DinoSets.progress(profile, id)
	var status := "★ Badge earned" if DinoSets.claimed(profile, id) else "+%d Amber when complete" % DinoSets.reward(id)
	column.add_child(UiKit.label("%d / %d collected  ·  %s" % [counts[0], counts[1], status], 27, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER))

	var grid := UiKit.grid(3, 12)
	var members := DinoSets.members(id)
	for dino_id in members:
		var dino := Session.catalog.find(dino_id)
		var card: DinoCard
		if profile.owns(dino_id):
			card = DinoCard.create(dino, DinoCard.Mode.FULL, null, profile.is_shiny(dino_id), SET_CARD_WIDTH)
		else:
			card = DinoCard.create_unknown(dino, DinoCard.Mode.FULL, SET_CARD_WIDTH)
		card.inspect_on_hold = false
		# After crafting one, show the set again with it face up.
		card.pressed.connect(func() -> void:
			DexEntry.open(dino, func() -> void:
				if is_instance_valid(dialog):
					dialog.queue_free()
				_refresh()
				_open_set(id)))
		grid.add_child(card)
	var holder := CenterContainer.new()
	holder.add_child(grid)
	var scroll := UiKit.vscroll(holder)
	var rows := ceili(members.size() / 3.0)
	var height := rows * (SET_CARD_WIDTH * DinoCard.ASPECT + 12)
	scroll.custom_minimum_size.y = minf(height, get_viewport_rect().size.y * 0.55)
	column.add_child(scroll)
	column.add_child(UiKit.label("Tap a card to open its Dex entry.", 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var close := UiKit.button("Close", UiKit.BUTTON_GRAY, 68, 26)
	close.pressed.connect(dialog.queue_free)
	column.add_child(close)
	var panel := UiKit.panel(column, Palette.PANEL, 20)
	# Taps on the panel stay here; only taps outside it close the popup.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	dialog.add_child(center)
	get_tree().current_scene.add_child(dialog)


## One goal: title, description, progress bar, reward, and Claim / Done.
## `extra` goes under the description; `badge` rows show a gold star once claimed (sets); `open`
## makes the whole row tappable (sets: shows its cards).
func _row(title: String, description: String, progress: int, target: int, reward: String, claimed: bool,
		claim: Callable, extra: Control = null, badge := false, open := Callable()) -> Control:
	var done := progress >= target
	var row := UiKit.hbox(14)
	var text := UiKit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if badge and claimed:
		text.add_child(UiKit.label("★ " + title, 30, Palette.HIGHLIGHT))
	else:
		text.add_child(UiKit.label(title, 30, Palette.TEXT_DIM if claimed else Palette.TEXT))
	if description != "":
		text.add_child(UiKit.label(description, 27, Palette.TEXT_DIM))
	if extra:
		text.add_child(extra)
	if target > 1:
		text.add_child(_bar(mini(progress, target), target))
	row.add_child(text)

	var side := UiKit.vbox(6)
	side.custom_minimum_size.x = 190
	side.add_child(UiKit.label(reward, 28, Palette.HIGHLIGHT if not claimed else Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER, false))
	if claimed:
		side.add_child(UiKit.label("★ Badge" if badge else "✔ Claimed", 29, Palette.HIGHLIGHT if badge else Palette.HEAL,
				HORIZONTAL_ALIGNMENT_CENTER, false))
	elif done:
		var button := UiKit.button("Claim", UiKit.BUTTON_GREEN, 60, 28)
		# In a tappable row the button keeps its taps, so Claim doesn't also open the row.
		if not open.is_valid():
			UiKit.let_scroll(button)
		button.pressed.connect(func() -> void:
			if claim.call():
				Sound.play(&"amber")
				Session.save()
				_refresh())
		side.add_child(button)
		_pulse(button)
	else:
		side.add_child(UiKit.label("%d / %d" % [progress, target], 29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false))
	if open.is_valid():
		side.add_child(UiKit.label("See cards ›", 25, Palette.ACCENT.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, false))
	row.add_child(side)
	var panel := UiKit.panel(row, Palette.PANEL, 14)
	if done and not claimed:
		var glow := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		glow.border_color = Palette.HIGHLIGHT
		glow.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", glow)
	if open.is_valid():
		_on_tap(panel, open)
	return panel


## Calls `action` when `control` is tapped: pressed and released without moving far, so a swipe
## still just scrolls the list.
func _on_tap(control: Control, action: Callable) -> void:
	var start := [Vector2.INF]
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			if start[0] != Vector2.INF and (start[0] as Vector2).distance_to(event.global_position) > DinoCard.TAP_SLOP:
				start[0] = Vector2.INF
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start[0] = event.global_position
			elif start[0] != Vector2.INF:
				start[0] = Vector2.INF
				action.call())


## A thin line with a label in the middle, between groups of rows.
func _divider(text: String) -> Control:
	var row := UiKit.hbox(12)
	for i in 2:
		var line := ColorRect.new()
		line.color = Palette.ACCENT.darkened(0.3)
		line.custom_minimum_size = Vector2(0, 3)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
		if i == 0:
			var label := UiKit.title(text, 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
			row.add_child(label)
	return row


## The dinos in a set: owned ones bright, missing ones dim.
func _set_members(id: StringName) -> RichTextLabel:
	var names: Array[String] = []
	for dino_id in DinoSets.members(id):
		var dino := Session.catalog.find(dino_id)
		var color := Palette.TEXT if Session.profile.owns(dino_id) else Color(Palette.TEXT_DIM, 0.6)
		names.append("[color=#%s]%s[/color]" % [color.to_html(), dino.display_name])
	var list := RichTextLabel.new()
	list.bbcode_enabled = true
	list.fit_content = true
	list.scroll_active = false
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_font_size_override("normal_font_size", 27)
	list.text = " · ".join(names)
	return list


## A week of dots for the daily check-in, with a Claim button that opens the full view.
func _checkin_strip() -> Control:
	var profile := Session.profile
	var row := UiKit.hbox(14)
	var text := UiKit.vbox(8)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiKit.title("Daily check-in", 30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var dots := UiKit.hbox(8)
	for day in Economy.CHECKIN_BONUSES.size():
		var state := CheckInView.day_state(day)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(40, 40)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(20)
		style.bg_color = Palette.HEAL if state == 0 else Color(1, 1, 1, 0.06)
		if Economy.CHECKIN_BONUSES[day].has("rare_clutches") and state != 0:
			style.bg_color = Color(CheckInView.RARE_TINT, 0.35)
		style.border_color = Palette.HIGHLIGHT if state == 1 else Palette.PANEL_BORDER
		style.set_border_width_all(3 if state == 1 else 1)
		dot.add_theme_stylebox_override("panel", style)
		dot.add_child(UiKit.label("✔" if state == 0 else str(day + 1), 26, Palette.INK if state == 0 else Palette.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER, false))
		dots.add_child(dot)
	text.add_child(dots)
	row.add_child(text)
	var side := UiKit.vbox(6)
	side.custom_minimum_size.x = 190
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	if profile.can_claim_daily(SaveStore.today()):
		var button := UiKit.button("Claim", UiKit.BUTTON_GREEN, 60, 28)
		UiKit.let_scroll(button)
		button.pressed.connect(func() -> void: CheckInView.open().closed.connect(_refresh))
		side.add_child(button)
		_pulse(button)
	else:
		side.add_child(UiKit.label("✔ Done today", 29, Palette.HEAL, HORIZONTAL_ALIGNMENT_CENTER, false))
	row.add_child(side)
	return UiKit.panel(row, Palette.PANEL, 14)


func _milestone_chip(index: int) -> Control:
	var profile := Session.profile
	var milestone: Array = Goals.MILESTONES[index]
	var box := UiKit.vbox(4)
	box.add_child(UiKit.title("%d dinos" % milestone[0], 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	var reward := "+%d Amber" % milestone[1] if milestone[1] > 0 else "+%d clutch%s" % [milestone[2], "" if milestone[2] == 1 else "es"]
	box.add_child(UiKit.label(reward, 27, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false))
	if Goals.milestone_claimed(profile, index):
		box.add_child(UiKit.label("✔", 30, Palette.HEAL, HORIZONTAL_ALIGNMENT_CENTER, false))
	elif Goals.milestone_ready(profile, index):
		var button := UiKit.button("Claim", UiKit.BUTTON_GREEN, 52, 26)
		UiKit.let_scroll(button)
		button.pressed.connect(func() -> void:
			if Goals.claim_milestone(profile, index):
				Sound.play(&"amber")
				Session.save()
				_refresh())
		box.add_child(button)
		_pulse(button)
	else:
		box.add_child(UiKit.label("%d / %d" % [Goals.discovered(profile), milestone[0]], 28, Palette.TEXT_DIM,
				HORIZONTAL_ALIGNMENT_CENTER, false))
	var chip := UiKit.panel(box, Palette.PANEL, 10)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return chip


func _bar(value: int, maximum: int) -> Control:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	# Let taps through to the row (tappable set rows) and drags to the list.
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in [["background", Color(1, 1, 1, 0.08)], ["fill", Palette.HIGHLIGHT]]:
		var style := StyleBoxFlat.new()
		style.bg_color = part[1]
		style.set_corner_radius_all(7)
		bar.add_theme_stylebox_override(part[0], style)
	return bar


## The red "something's ready" dot in a section button's corner (like the tab bar's).
func _red_dot() -> Control:
	var dot := Panel.new()
	var red := StyleBoxFlat.new()
	red.bg_color = Color("ff3b4e")
	red.border_color = Color.WHITE
	red.set_border_width_all(2)
	red.set_corner_radius_all(10)
	dot.add_theme_stylebox_override("panel", red)
	dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -24
	dot.offset_right = -6
	dot.offset_top = 6
	dot.offset_bottom = 24
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


func _pulse(button: Button) -> void:
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
	var pulse := button.create_tween().set_loops()
	pulse.tween_property(button, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## Every 30 s: rolls new quests once the day changes, and updates "New in 5h 12m".
func _update_countdown() -> void:
	if Session.profile.quest_day != SaveStore.today():
		Session.refresh_quests()
		_refresh()
		return
	if is_instance_valid(_countdown):
		_countdown.text = _countdown_text()


## "New in 5h 12m", counting to local midnight (when SaveStore.today() changes).
func _countdown_text() -> String:
	var now := Time.get_time_dict_from_system()
	var left := 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
	return "New in %dh %02dm" % [left / 3600, (left % 3600) / 60]
