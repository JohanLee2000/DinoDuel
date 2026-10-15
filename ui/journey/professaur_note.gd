class_name ProfessaurNote
extends Control
## The Professaur says a few words in a popup: used when a new Journey chapter opens.

signal closed

## What he says when each chapter opens. "%s" is the player's name.
const CHAPTER_INTROS: Array[String] = [
	"Welcome to the [b]Journey[/b], %s! Every rival on this trail has a habit: read their notes, play the counter, and you'll go far. Rory went ahead to the end of the Triassic. Let's catch up!",
	"You beat Rory? Impressive! He's run off to the [b]Jurassic[/b]. Giants and sea monsters live here, and these rivals have trickier habits. Keep your eyes open, %s.",
	"The [b]Cretaceous[/b]! The biggest creatures of all. Most rivals here learn how you play, so don't get predictable, %s.",
	"Something bright is in the sky, %s. Rory's waiting at the crater for one last battle, and the [b]meteor shower[/b] starts on turn 8. Win it before the sky falls!",
]

var _text := ""


static func open(text: String) -> ProfessaurNote:
	var note := ProfessaurNote.new()
	note._text = text
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(note)
	return note


static func chapter_intro(chapter: int) -> ProfessaurNote:
	var player := Session.profile.player_name if Session.profile.player_name != "" else "explorer"
	return open(CHAPTER_INTROS[chapter] % player)


func close() -> void:
	closed.emit()
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.modal_layer(0.7))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := UiKit.vbox(16)
	column.custom_minimum_size.x = 600
	var row := UiKit.hbox(18)
	row.add_child(ProfessorTour.portrait(124))
	var words := UiKit.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UiKit.title("The Professaur", 30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_size_override("normal_font_size", 28)
	text.add_theme_font_size_override("bold_font_size", 28)
	text.add_theme_font_override("bold_font", Fonts.bold())
	text.add_theme_color_override("default_color", Palette.TEXT)
	text.text = _text
	words.add_child(text)
	row.add_child(words)
	column.add_child(row)
	var go := UiKit.button("Let's go!", UiKit.BUTTON_GREEN, 76, 28)
	go.pressed.connect(close)
	column.add_child(go)
	var panel := UiKit.panel(column, Palette.PANEL, 24)
	center.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
