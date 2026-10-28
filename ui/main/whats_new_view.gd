class_name WhatsNewView
extends ColorRect
## What's new (Jo, 2026-10-28): the Professaur's news from camp, one section per release
## (WhatsNew.RELEASES). Shown once after an update, and from Settings any time.

signal closed

var _releases: Array[Dictionary] = []


static func open(releases: Array[Dictionary]) -> WhatsNewView:
	var view := WhatsNewView.new()
	view._releases = releases
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	closed.emit()
	queue_free()


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 600
	var header := UiKit.hbox(16)
	header.add_child(ProfessorTour.portrait(100))
	var words := UiKit.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UiKit.title("What's new", 38, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	words.add_child(UiKit.label("News from camp, from the Professaur", 25, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
	header.add_child(words)
	column.add_child(header)

	var list := UiKit.vbox(16)
	for release in _releases:
		var box := UiKit.vbox(8)
		box.add_child(UiKit.title("Version %s" % release["version"], 28, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		for item in release["items"]:
			box.add_child(_item(item))
		list.add_child(UiKit.panel(box, Palette.BACKGROUND, 14))
	var scroll := UiKit.vscroll(list)
	scroll.custom_minimum_size.y = minf(560.0, get_viewport_rect().size.y * 0.5)
	column.add_child(scroll)
	var ok := UiKit.button("Let's play!", UiKit.BUTTON_GREEN, 76, 28)
	ok.pressed.connect(close)
	column.add_child(ok)
	var panel := UiKit.panel(column, Palette.PANEL, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	add_child(center)


## One change: a gold star and the text.
func _item(text: String) -> Control:
	var row := UiKit.hbox(12)
	var star := TextureRect.new()
	star.texture = Icons.texture(&"star", 30)
	star.custom_minimum_size = Vector2(30, 30)
	star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(star)
	var label := UiKit.label(text, 27, Palette.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
