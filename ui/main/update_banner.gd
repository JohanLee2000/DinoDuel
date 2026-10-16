class_name UpdateBanner
extends PanelContainer
## Experiment (2026-10-16): the strip under the top bar that offers a new version from Google Play
## (UpdateCheck): "A new version is out" with Update / Later, then the download progress, then
## Restart. Hidden when there's nothing to offer.

var _check: UpdateCheck
var _text: Label
var _buttons: HBoxContainer


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PANEL, 0.95)
	style.border_color = Palette.HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var row := UiKit.hbox(12)
	_text = UiKit.label("", 26, Palette.TEXT)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_text)
	_buttons = UiKit.hbox(8)
	row.add_child(_buttons)
	add_child(row)
	visible = false
	_check = UpdateCheck.start(get_tree())
	if _check:
		_check.changed.connect(_refresh)
		_refresh()


func _refresh() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	var state := _check.state
	visible = state == UpdateCheck.State.DOWNLOADING or state == UpdateCheck.State.DOWNLOADED \
			or (state == UpdateCheck.State.AVAILABLE and not _check.dismissed)
	match state:
		UpdateCheck.State.AVAILABLE:
			_text.text = "A new version of Dino Duel is out!"
			_buttons.add_child(_button("Later", UiKit.BUTTON_GRAY, _check.later))
			_buttons.add_child(_button("Update", UiKit.BUTTON_GREEN, _check.download))
		UpdateCheck.State.DOWNLOADING:
			_text.text = "Downloading the update…  %d%%" % roundi(_check.progress * 100)
		UpdateCheck.State.DOWNLOADED:
			_text.text = "Update ready. Restart to play the new version."
			_buttons.add_child(_button("Restart", UiKit.BUTTON_GREEN, _check.restart))


func _button(text: String, color: Color, action: Callable) -> Button:
	var button := UiKit.button(text, color, 60, 24)
	button.custom_minimum_size.x = 130
	button.pressed.connect(func() -> void:
		Sound.play(&"tap")
		action.call())
	return button
