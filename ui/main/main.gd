extends Control
## The app shell: top bar with Amber and clutches, the current tab, and the bottom tab bar.

const TABS := [
	{"name": "Battle", "script": "res://ui/tabs/battle_tab.gd"},
	{"name": "Party", "script": "res://ui/tabs/party_tab.gd"},
	{"name": "Eggs", "script": "res://ui/tabs/eggs_tab.gd"},
	{"name": "Dex", "script": "res://ui/tabs/dex_tab.gd"},
]

var _buttons: Array[Button] = []
var _current: Control

@onready var _content: MarginContainer = %Content
@onready var _nav_bar: HBoxContainer = %NavBar
@onready var _amber_label: Label = %AmberLabel
@onready var _clutch_label: Label = %ClutchLabel


func _ready() -> void:
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(230, 62)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label: Label = %Title
	title_label.replace_by(logo)
	title_label.queue_free()
	_add_icon_before(_amber_label, &"amber")
	_add_icon_before(_clutch_label, &"egg")
	for i in TABS.size():
		var button := UiKit.button(TABS[i]["name"], Palette.PANEL, 88, 26)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_tab.bind(i))
		_nav_bar.add_child(button)
		_buttons.append(button)
	Session.profile_changed.connect(_update_bar)
	_show_tab(Session.current_tab)
	if Session.dev_open_card != "":
		var parts := Session.dev_open_card.split(":")
		CardViewer.open.call_deferred(Session.catalog.find(StringName(parts[0])), parts.size() > 1)
		Session.dev_open_card = ""


func _show_tab(index: int) -> void:
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
	var eggs_waiting := profile.clutches > 0 or profile.can_claim_daily(SaveStore.today())
	_buttons[Session.Tab.EGGS].text = "Eggs (!)" if eggs_waiting else "Eggs"


func _add_icon_before(label: Label, icon_name: StringName) -> void:
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name, 34)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	label.get_parent().add_child(icon)
	label.get_parent().move_child(icon, label.get_index())
	label.add_theme_font_override("font", Fonts.condensed_bold())
	label.add_theme_font_size_override("font_size", 30)


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
