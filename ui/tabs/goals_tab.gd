extends VBoxContainer
## Goals tab: the daily check-in, today's three quests (plus a bonus clutch for all three),
## collection rewards (milestones, full eras and sets), and achievements. Rules live in
## core/collection/goals.gd and core/collection/dino_sets.gd.

var _body: VBoxContainer
var _scroll: ScrollContainer
var _countdown: Label
## Bumped on every rebuild, so a rebuild still adding rows stops if a newer one has started.
var _build := 0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UiKit.title("Goals"))
	_body = UiKit.vbox(16)
	_scroll = UiKit.vscroll(_body)
	add_child(_scroll)
	_refresh()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(_update_countdown)
	add_child(timer)


## Builds the top of the tab (check-in, quests, collection) right away and adds the sets and
## achievements below over the next frames, so switching to Goals feels instant on phones.
func _refresh() -> void:
	_build += 1
	var build := _build
	var keep_scroll := _scroll.scroll_vertical
	for child in _body.get_children():
		child.queue_free()
	var profile := Session.profile
	var catalog := Session.catalog

	_body.add_child(_checkin_strip())

	# Daily quests.
	var header := UiKit.hbox(10)
	var heading := UiKit.title("Daily quests", 30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_countdown = UiKit.label("", 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_countdown)
	_body.add_child(header)
	_update_countdown()
	for i in profile.quests.size():
		var quest: Dictionary = profile.quests[i]
		_body.add_child(_row(Goals.quest_text(quest), "", int(quest["progress"]), Goals.quest_target(quest),
				"+%d Amber" % Goals.quest_reward(quest), bool(quest["claimed"]),
				func() -> bool: return Goals.claim_quest(profile, i)))
	var all_done := profile.quests.all(func(q: Dictionary) -> bool: return Goals.quest_done(q))
	_body.add_child(_row("Finish all 3 quests", "A bonus for clearing the day.",
			1 if all_done else 0, 1, "+%d egg clutch" % Goals.QUEST_BONUS_CLUTCHES, profile.quest_bonus_claimed,
			func() -> bool: return Goals.claim_quest_bonus(profile)))

	# Collection.
	_body.add_child(UiKit.title("Collection", 30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var found := Goals.discovered(profile)
	_body.add_child(UiKit.label("%d of %d dinos discovered" % [found, catalog.dinos.size()], 24, Palette.TEXT))
	var milestones := UiKit.grid(3, 10)
	for i in Goals.MILESTONES.size():
		milestones.add_child(_milestone_chip(i))
	_body.add_child(milestones)
	for era in DinoDef.ERA_NAMES.size():
		var progress := Goals.era_progress(profile, catalog, era)
		_body.add_child(_row("Complete the %s" % DinoDef.ERA_NAMES[era], "Discover every %s dino. Earns a gold badge in the Dex." % DinoDef.ERA_NAMES[era],
				progress[0], progress[1], "+%d egg clutch" % Goals.ERA_CLUTCHES, Goals.era_claimed(profile, era),
				func() -> bool: return Goals.claim_era(profile, catalog, era)))

	await get_tree().process_frame
	if build != _build:
		return
	# Sets: ready to claim first, then the rest in order, earned badges last.
	var set_ids := DinoSets.ids()
	var earned := set_ids.filter(func(id: StringName) -> bool: return DinoSets.claimed(profile, id)).size()
	_body.add_child(UiKit.title("Sets  %d/%d" % [earned, set_ids.size()], 30, Palette.HIGHLIGHT,
			HORIZONTAL_ALIGNMENT_LEFT, false))
	_body.add_child(UiKit.label("Collect every dino in a set for Amber and a badge. Families split all %d dinos; themes mix them up." \
			% catalog.dinos.size(), 22, Palette.TEXT_DIM))
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
					func() -> bool: return DinoSets.claim(profile, id), _set_members(id), true))

	await get_tree().process_frame
	if build != _build:
		return
	# Achievements: ready to claim first, then in progress, then the ones already claimed.
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
	_restore_scroll.call_deferred(keep_scroll)


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = value


## One goal: title, description, progress bar, reward, and Claim / Done.
## `extra` goes under the description; `badge` rows show a gold star once claimed (sets).
func _row(title: String, description: String, progress: int, target: int, reward: String, claimed: bool,
		claim: Callable, extra: Control = null, badge := false) -> Control:
	var done := progress >= target
	var row := UiKit.hbox(14)
	var text := UiKit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if badge and claimed:
		text.add_child(UiKit.label("★ " + title, 26, Palette.HIGHLIGHT))
	else:
		text.add_child(UiKit.label(title, 26, Palette.TEXT_DIM if claimed else Palette.TEXT))
	if description != "":
		text.add_child(UiKit.label(description, 21, Palette.TEXT_DIM))
	if extra:
		text.add_child(extra)
	if target > 1:
		text.add_child(_bar(mini(progress, target), target))
	row.add_child(text)

	var side := UiKit.vbox(6)
	side.custom_minimum_size.x = 190
	side.add_child(UiKit.label(reward, 22, Palette.HIGHLIGHT if not claimed else Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER, false))
	if claimed:
		side.add_child(UiKit.label("★ Badge" if badge else "✔ Claimed", 24, Palette.HIGHLIGHT if badge else Palette.HEAL,
				HORIZONTAL_ALIGNMENT_CENTER, false))
	elif done:
		var button := UiKit.button("Claim", UiKit.BUTTON_GREEN, 60, 26)
		button.pressed.connect(func() -> void:
			if claim.call():
				Sound.play(&"amber")
				Session.save()
				_refresh())
		side.add_child(button)
		_pulse(button)
	else:
		side.add_child(UiKit.label("%d / %d" % [progress, target], 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false))
	row.add_child(side)
	var panel := UiKit.panel(row, Palette.PANEL, 14)
	if done and not claimed:
		var glow := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		glow.border_color = Palette.HIGHLIGHT
		glow.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", glow)
	return panel


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
			var label := UiKit.title(text, 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
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
	list.add_theme_font_size_override("normal_font_size", 21)
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
		dot.add_child(UiKit.label("✔" if state == 0 else str(day + 1), 20, Palette.INK if state == 0 else Palette.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER, false))
		dots.add_child(dot)
	text.add_child(dots)
	row.add_child(text)
	var side := UiKit.vbox(6)
	side.custom_minimum_size.x = 190
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	if profile.can_claim_daily(SaveStore.today()):
		var button := UiKit.button("Claim", UiKit.BUTTON_GREEN, 60, 26)
		button.pressed.connect(func() -> void: CheckInView.open().closed.connect(_refresh))
		side.add_child(button)
		_pulse(button)
	else:
		side.add_child(UiKit.label("✔ Done today", 24, Palette.HEAL, HORIZONTAL_ALIGNMENT_CENTER, false))
	row.add_child(side)
	return UiKit.panel(row, Palette.PANEL, 14)


func _milestone_chip(index: int) -> Control:
	var profile := Session.profile
	var milestone: Array = Goals.MILESTONES[index]
	var box := UiKit.vbox(4)
	box.add_child(UiKit.title("%d dinos" % milestone[0], 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	var reward := "+%d Amber" % milestone[1] if milestone[1] > 0 else "+%d clutch%s" % [milestone[2], "" if milestone[2] == 1 else "es"]
	box.add_child(UiKit.label(reward, 21, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false))
	if Goals.milestone_claimed(profile, index):
		box.add_child(UiKit.label("✔", 26, Palette.HEAL, HORIZONTAL_ALIGNMENT_CENTER, false))
	elif Goals.milestone_ready(profile, index):
		var button := UiKit.button("Claim", UiKit.BUTTON_GREEN, 52, 22)
		button.pressed.connect(func() -> void:
			if Goals.claim_milestone(profile, index):
				Sound.play(&"amber")
				Session.save()
				_refresh())
		box.add_child(button)
		_pulse(button)
	else:
		box.add_child(UiKit.label("%d / %d" % [Goals.discovered(profile), milestone[0]], 22, Palette.TEXT_DIM,
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
	for part in [["background", Color(1, 1, 1, 0.08)], ["fill", Palette.HIGHLIGHT]]:
		var style := StyleBoxFlat.new()
		style.bg_color = part[1]
		style.set_corner_radius_all(7)
		bar.add_theme_stylebox_override(part[0], style)
	return bar


func _pulse(button: Button) -> void:
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
	var pulse := button.create_tween().set_loops()
	pulse.tween_property(button, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## "New quests in 5h 12m", counting to local midnight (when SaveStore.today() changes).
func _update_countdown() -> void:
	if _countdown == null:
		return
	var now := Time.get_time_dict_from_system()
	var left := 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
	_countdown.text = "New in %dh %02dm" % [left / 3600, (left % 3600) / 60]
	if Session.profile.quest_day != SaveStore.today():
		Session.refresh_quests()
		_refresh()
