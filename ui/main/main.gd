class_name MainScreen
extends Control
## The app shell: top bar with Amber and clutches, the current tab, and the bottom tab bar.
## New players go through the name entry, story, partner pick and the Professaur's tour here.

const TABS := [
	{"name": "Battle", "script": "res://ui/tabs/battle_tab.gd"},
	{"name": "Party", "script": "res://ui/tabs/party_tab.gd"},
	{"name": "Eggs", "script": "res://ui/tabs/eggs_tab.gd"},
	{"name": "Dex", "script": "res://ui/tabs/dex_tab.gd"},
	{"name": "Goals", "script": "res://ui/tabs/goals_tab.gd"},
]

var _buttons: Array[Button] = []
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
		var button := UiKit.button(TABS[i]["name"], Palette.PANEL, 88, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_tab.bind(i))
		_nav_bar.add_child(button)
		_buttons.append(button)
	_first_steps = FirstStepsBar.new()
	_first_steps.go_to_tab.connect(_show_tab)
	var column := _content.get_parent()
	column.add_child(_first_steps)
	column.move_child(_first_steps, _content.get_index())
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
	match Session.dev_open:
		"settings":
			SettingsView.open.call_deferred()
		"checkin":
			_open_checkin.call_deferred()
		"help":
			HelpView.open.call_deferred()
		_ when Session.dev_open.begins_with("help:"):
			HelpView.open.call_deferred(int(Session.dev_open.get_slice(":", 1)) - 1)
	Session.dev_open = ""


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
	for i in _buttons.size():
		UiKit.style_button(_buttons[i], UiKit.BUTTON_GREEN if i == index else Palette.PANEL)
	_update_bar()


func _update_bar() -> void:
	var profile := Session.profile
	_amber_label.text = str(profile.amber)
	_clutch_label.text = str(profile.clutches)
	var eggs_waiting := profile.clutches > 0 or profile.rare_clutches > 0 or profile.can_claim_daily(SaveStore.today())
	_buttons[Session.Tab.EGGS].text = "Eggs (!)" if eggs_waiting else "Eggs"
	_buttons[Session.Tab.GOALS].text = "Goals (!)" if Goals.anything_to_claim(profile, Session.catalog) else "Goals"
	_first_steps.refresh()
	_glow_tab(_first_steps.next_tab())


## Pulses the tab button the First steps checklist wants next (unless it's already open).
func _glow_tab(index: int) -> void:
	if _tab_glow:
		_tab_glow.kill()
		_tab_glow = null
	for i in _buttons.size():
		_buttons[i].modulate = Color.WHITE
		UiKit.style_button(_buttons[i], UiKit.BUTTON_GREEN if i == Session.current_tab else Palette.PANEL)
	if index < 0 or index == Session.current_tab:
		return
	var button := _buttons[index]
	for state in ["normal", "hover", "pressed", "focus"]:
		var outlined := (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		outlined.border_color = Palette.HIGHLIGHT
		outlined.set_border_width_all(3)
		button.add_theme_stylebox_override(state, outlined)
	_tab_glow = button.create_tween().set_loops()
	_tab_glow.tween_property(button, "modulate", Color(1.6, 1.4, 0.7), 0.5).set_trans(Tween.TRANS_SINE)
	_tab_glow.tween_property(button, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)


func _add_icon_before(label: Label, icon_name: StringName) -> Control:
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name, 34)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	label.get_parent().add_child(icon)
	label.get_parent().move_child(icon, label.get_index())
	label.add_theme_font_override("font", Fonts.condensed_bold())
	label.add_theme_font_size_override("font_size", 30)
	return icon


## Android back button: go to the Battle tab first, then leave the app.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_child_count() > 2:
			# An overlay (hatch view or card popup) is open; let it be.
			return
		if Session.current_tab != Session.Tab.BATTLE:
			_show_tab(Session.Tab.BATTLE)
		else:
			get_tree().quit()
