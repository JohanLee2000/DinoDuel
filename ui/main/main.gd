class_name MainScreen
extends Control
## The app shell: top bar with Amber and clutches, the current tab, and the bottom tab bar.
## New players go through the name entry, story, partner pick and the Professaur's tour here.

const TABS := [
	{"name": "Journey", "icon": &"map", "script": "res://ui/tabs/battle_tab.gd"},
	{"name": "Party", "icon": &"cards", "script": "res://ui/tabs/party_tab.gd"},
	{"name": "Eggs", "icon": &"egg_outline", "script": "res://ui/tabs/eggs_tab.gd"},
	{"name": "Dex", "icon": &"book", "script": "res://ui/tabs/dex_tab.gd"},
	{"name": "Goals", "icon": &"trophy", "script": "res://ui/tabs/goals_tab.gd"},
]
const TAB_ICON_SIZE := 30

var _buttons: Array[Button] = []
## Per tab: the red dot that means something's waiting there.
var _dots: Array[Control] = []
var _current: Control
var _first_steps: FirstStepsBar
var _tab_glow: Tween
var _amber_icon: Control
var _gear: Button

@onready var _content: MarginContainer = %Content
@onready var _nav_bar: HBoxContainer = %NavBar
@onready var _amber_label: Label = %AmberLabel
@onready var _clutch_label: Label = %ClutchLabel


func _ready() -> void:
	if Session.resume_saved_battle():
		return
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(230, 62)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label: Label = %Title
	title_label.replace_by(logo)
	title_label.queue_free()
	_amber_icon = _add_icon_before(_amber_label, &"amber")
	_add_icon_before(_clutch_label, &"egg")
	_gear = Button.new()
	_gear.icon = Icons.texture(&"gear", 34)
	_gear.flat = true
	_gear.custom_minimum_size = Vector2(56, 56)
	_gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear.pressed.connect(func() -> void: SettingsView.open())
	_clutch_label.get_parent().add_child(_gear)
	Sound.music(&"main")
	for i in TABS.size():
		# Icon above the name; the active tab is gold (see _style_tabs).
		var button := UiKit.button(TABS[i]["name"], Palette.PANEL, 82, 20)
		button.icon = Icons.texture(TABS[i]["icon"], TAB_ICON_SIZE)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_tab.bind(i))
		_nav_bar.add_child(button)
		_buttons.append(button)
		var dot := Panel.new()
		var red := StyleBoxFlat.new()
		red.bg_color = Color("ff3b4e")
		red.border_color = Color.WHITE
		red.set_border_width_all(2)
		red.set_corner_radius_all(10)
		dot.add_theme_stylebox_override("panel", red)
		dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -26
		dot.offset_right = -8
		dot.offset_top = 6
		dot.offset_bottom = 24
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		button.add_child(dot)
		_dots.append(dot)
	_first_steps = FirstStepsBar.new()
	_first_steps.go_to_tab.connect(_show_tab)
	var column := _content.get_parent()
	column.add_child(_first_steps)
	column.move_child(_first_steps, _content.get_index())
	# Experiment (2026-10-16): Google Play's in-app update offer; see docs/IN_APP_UPDATES.md.
	var update_banner := UpdateBanner.new()
	column.add_child(update_banner)
	column.move_child(update_banner, _first_steps.get_index())
	Session.profile_changed.connect(_update_bar)
	_show_tab(Session.current_tab)
	if Session.dev_open_card != "":
		var parts := Session.dev_open_card.split(":")
		CardViewer.open.call_deferred(Session.catalog.find(StringName(parts[0])), parts.size() > 1)
		Session.dev_open_card = ""
	if not Session.profile.partner_chosen:
		_start_new_player.call_deferred()
	elif not Session.profile.tour_done:
		ProfessorTour.start.call_deferred(self)
	elif Session.dev_open == "" and Session.dev_open_card == "" and Session.take_checkin_prompt():
		_open_checkin.call_deferred()
	if Session.dev_tab_timing:
		_dev_time_tabs.call_deferred()
	match Session.dev_open:
		"settings":
			SettingsView.open.call_deferred()
		"history":
			HatchHistoryView.open.call_deferred()
		"checkin":
			_open_checkin.call_deferred()
		"help":
			HelpView.open.call_deferred()
		_ when Session.dev_open.begins_with("help:"):
			HelpView.open.call_deferred(int(Session.dev_open.get_slice(":", 1)) - 1)
		_ when Session.dev_open.begins_with("rival:"):
			RivalView.open.call_deferred(Journey.find(StringName(Session.dev_open.get_slice(":", 1))), true)
		_ when Session.dev_open.begins_with("prebattle:"):
			Session.dev_prepick = int(Session.dev_open.get_slice(":", 2))
			Session.go_to_pre_battle.call_deferred(Journey.find(StringName(Session.dev_open.get_slice(":", 1))))
		_ when Session.dev_open.begins_with("intro:"):
			ProfessaurNote.chapter_intro.call_deferred(int(Session.dev_open.get_slice(":", 1)))
	Session.dev_open = ""


func _dev_time_tabs() -> void:
	var lines: Array[String] = []
	for round in 2:
		for i in TABS.size():
			await get_tree().process_frame
			var start := Time.get_ticks_usec()
			_show_tab(i)
			await RenderingServer.frame_post_draw
			lines.append("round %d  %-6s %6.1f ms" % [round + 1, TABS[i]["name"], (Time.get_ticks_usec() - start) / 1000.0])
	var file := FileAccess.open("user://tab_timing.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")


func _open_checkin() -> void:
	CheckInView.open().closed.connect(func() -> void: show_tab(Session.current_tab))


## Brand-new players: their name, the story panels, then the partner pick. Picking reloads this
## screen, and the Professaur's tour starts from _ready.
func _start_new_player() -> void:
	if Session.profile.player_name.is_empty():
		await NameEntry.open().finished
	await StoryIntro.open().finished
	PartnerPick.open()


func show_tab(index: int) -> void:
	_show_tab(index)


# Screen rects for the Professaur's tour.

func tab_rect(index: int) -> Rect2:
	return _buttons[index].get_global_rect()


func stats_rect() -> Rect2:
	return _amber_icon.get_global_rect().merge(_clutch_label.get_global_rect())


func gear_rect() -> Rect2:
	return _gear.get_global_rect()


func first_steps_rect() -> Rect2:
	return _first_steps.get_global_rect() if _first_steps.visible else Rect2()


func _show_tab(index: int) -> void:
	Session.refresh_quests()
	Session.current_tab = index
	if _current:
		_current.queue_free()
	_current = load(TABS[index]["script"]).new()
	_content.add_child(_current)
	_style_tabs()
	_update_bar()


## The open tab is gold; the others are dark with dim labels.
func _style_tabs() -> void:
	for i in _buttons.size():
		var active := i == Session.current_tab
		UiKit.style_button(_buttons[i], UiKit.BUTTON_GREEN if active else Palette.PANEL)
		if not active:
			for color_name in ["font_color", "icon_normal_color"]:
				_buttons[i].add_theme_color_override(color_name, Palette.TEXT_DIM)


func _update_bar() -> void:
	var profile := Session.profile
	_amber_label.text = str(profile.amber)
	_clutch_label.text = str(profile.clutches + profile.rare_clutches)
	_dots[Session.Tab.EGGS].visible = profile.clutches > 0 or profile.rare_clutches > 0
	_dots[Session.Tab.GOALS].visible = profile.can_claim_daily(SaveStore.today()) \
			or Goals.anything_to_claim(profile, Session.catalog)
	_dots[Session.Tab.BATTLE].visible = Journey.any_chest_ready(profile)
	_first_steps.refresh()
	_glow_tab(_first_steps.next_tab())


## Pulses the tab button the First steps checklist wants next (unless it's already open).
func _glow_tab(index: int) -> void:
	if _tab_glow:
		_tab_glow.kill()
		_tab_glow = null
	for i in _buttons.size():
		_buttons[i].modulate = Color.WHITE
	_style_tabs()
	if index < 0 or index == Session.current_tab:
		return
	var button := _buttons[index]
	for color_name in ["font_color", "icon_normal_color"]:
		button.add_theme_color_override(color_name, Palette.HIGHLIGHT)
	_tab_glow = button.create_tween().set_loops()
	_tab_glow.tween_property(button, "modulate", Color(1.6, 1.4, 0.7), 0.5).set_trans(Tween.TRANS_SINE)
	_tab_glow.tween_property(button, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)


func _add_icon_before(label: Label, icon_name: StringName) -> Control:
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name, 38)
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	label.get_parent().add_child(icon)
	label.get_parent().move_child(icon, label.get_index())
	label.add_theme_font_override("font", Fonts.condensed_bold())
	label.add_theme_font_size_override("font_size", 33)
	return icon


## Android back button: go to the Journey tab first, then leave the app. Coming back to the game
## on a new day (Android often keeps it in the background overnight) opens the check-in.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		# Only on the plain tabs, not over a hatch, the tour or another popup.
		if get_child_count() <= 2 and Session.take_checkin_prompt():
			_open_checkin()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_child_count() > 2:
			# An overlay (hatch view or card popup) is open; let it be.
			return
		if Session.current_tab != Session.Tab.BATTLE:
			_show_tab(Session.Tab.BATTLE)
		else:
			get_tree().quit()
