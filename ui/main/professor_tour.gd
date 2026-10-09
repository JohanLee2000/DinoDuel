class_name ProfessorTour
extends Control
## Professor Saurus shows a new player around after they pick a partner: what the top bar and each
## tab are for, then the First steps banner. Each step switches to its tab, dims everything except
## the part being explained, and shows his speech box. Tap to continue; Skip ends it.

signal finished

const PORTRAIT_ART := "res://assets/characters/professor_saurus.webp"
const PORTRAIT_SIZE := 132.0

var _main: MainScreen
var _steps: Array[Dictionary] = []
var _index := -1
var _shade: ColorRect
var _outline: Panel
var _outline_pulse: Tween
var _box: PanelContainer
var _text: RichTextLabel
var _footer: Label


static func start(main: MainScreen) -> ProfessorTour:
	var tour := ProfessorTour.new()
	tour._main = main
	main.add_child(tour)
	return tour


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_steps = _script()
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/main/spotlight.gdshader")
	_shade.material = material
	_shade.gui_input.connect(_on_input)
	add_child(_shade)

	_outline = Panel.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Palette.HIGHLIGHT
	ring.set_border_width_all(4)
	ring.set_corner_radius_all(16)
	_outline.add_theme_stylebox_override("panel", ring)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_outline)

	_box = _build_box()
	add_child(_box)
	_next()

	if Session.autoplay:
		while is_inside_tree() and _index < _steps.size():
			await get_tree().create_timer(1.2).timeout
			if is_inside_tree():
				_next()


## The tour, in order. `tab` switches the page shown behind; `target` returns the screen rect to
## point at (from MainScreen).
func _script() -> Array[Dictionary]:
	var profile := Session.profile
	var partner := Session.catalog.find(profile.partner)
	var partner_name := partner.display_name if partner else "your partner"
	return [
		{"text": "Welcome to camp, [b]%s[/b]! I'm Professor Saurus. Those fossil eggs are the real thing, and your %s is the proof. Let me show you around." % [profile.player_name, partner_name],
				"tab": Session.Tab.BATTLE},
		{"text": "Up here are your [b]Amber[/b] and your [b]egg clutches[/b]. You earn Amber from battles and duplicate dinos, and spend it on eggs and crafting.",
				"target": _main.stats_rect},
		{"text": "[b]Battle[/b]: challenge rival collectors. Each turn you both secretly pick Bite, Charge, Brace or Swap. Win to earn a clutch of %d eggs!" % Economy.EGGS_PER_CLUTCH,
				"tab": Session.Tab.BATTLE, "target": _main.tab_rect.bind(Session.Tab.BATTLE)},
		{"text": "[b]Party[/b]: the %d dinos you bring. Before each battle you see your rival's %d and pick %d, up to %d Party Points." \
				% [PartyRules.BRING_SIZE, PartyRules.BRING_SIZE, PartyRules.PARTY_SIZE, PartyRules.POINT_CAP],
				"tab": Session.Tab.PARTY, "target": _main.tab_rect.bind(Session.Tab.PARTY)},
		{"text": "[b]Eggs[/b]: crack open your clutches here. There's a free clutch every day, and you have [b]%d[/b] waiting right now!" % profile.clutches,
				"tab": Session.Tab.EGGS, "target": _main.tab_rect.bind(Session.Tab.EGGS)},
		{"text": "[b]Dex[/b]: every dino you've discovered. Hold any card to see it up close, and craft the ones you're missing with Amber.",
				"tab": Session.Tab.DEX, "target": _main.tab_rect.bind(Session.Tab.DEX)},
		{"text": "Sound settings and [b]How to play[/b] are behind the gear, whenever you need a refresher.",
				"target": _main.gear_rect},
		{"text": "I've written your [b]first steps[/b] up here. Finish them all and I'll send you a bonus egg clutch. Start by hatching your eggs. Good luck, %s!" % profile.player_name,
				"tab": Session.Tab.EGGS, "target": _main.first_steps_rect, "show_steps": true},
	]


func _build_box() -> PanelContainer:
	var row := UiKit.hbox(16)
	row.add_child(_portrait())
	var column := UiKit.vbox(6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.title("Professor Saurus", 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false))
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 27)
	_text.add_theme_font_size_override("bold_font_size", 27)
	_text.add_theme_font_override("bold_font", Fonts.bold())
	_text.add_theme_color_override("default_color", Palette.TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	# Skip lives in the speech box so it never covers what the tour points at.
	var footer_row := UiKit.hbox(10)
	var skip := UiKit.button("Skip tour", UiKit.BUTTON_GRAY, 48, 20)
	skip.custom_minimum_size.x = 140
	skip.pressed.connect(_finish)
	footer_row.add_child(skip)
	_footer = UiKit.label("", 21, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_row.add_child(_footer)
	column.add_child(footer_row)
	row.add_child(column)
	var box := UiKit.panel(row, Palette.PANEL, 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in [row, column, footer_row]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## Jo's painting if it exists, otherwise the placeholder icon.
func _portrait() -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(PORTRAIT_ART):
		# Round, gold-rimmed crop of the painting.
		var round_style := StyleBoxFlat.new()
		round_style.bg_color = Color.WHITE
		round_style.set_corner_radius_all(int(PORTRAIT_SIZE / 2))
		frame.add_theme_stylebox_override("panel", round_style)
		frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		image.texture = load(PORTRAIT_ART)
	else:
		frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		image.texture = Icons.texture(&"professor", int(PORTRAIT_SIZE))
	frame.add_child(image)
	return frame


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Sound.play(&"tap")
		_next()


func _next() -> void:
	_index += 1
	if _index >= _steps.size():
		_finish()
		return
	var step := _steps[_index]
	if step.get("show_steps", false):
		Session.profile.tour_done = true
		Session.save()
	if step.has("tab"):
		_main.show_tab(step["tab"])
	_text.text = step["text"]
	_footer.text = "%d / %d   ·   Tap to continue" % [_index + 1, _steps.size()]
	# Wait for the new tab to lay out before measuring what to point at.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var rect: Rect2 = step["target"].call() if step.has("target") else Rect2()
	_point_at(rect.grow(8) if rect.has_area() else Rect2())


func _point_at(rect: Rect2) -> void:
	var screen := size
	var material := _shade.material as ShaderMaterial
	material.set_shader_parameter("rect_size", screen)
	material.set_shader_parameter("hole", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	if _outline_pulse:
		_outline_pulse.kill()
	_outline.visible = rect.size != Vector2.ZERO
	if _outline.visible:
		_outline.position = rect.position
		_outline.size = rect.size
		_outline_pulse = _outline.create_tween().set_loops()
		_outline_pulse.tween_property(_outline, "modulate:a", 0.35, 0.6)
		_outline_pulse.tween_property(_outline, "modulate:a", 1.0, 0.6)

	# Speech box: full width, away from what's highlighted (top-half target -> box below it, and
	# vice versa). Its height comes from the text, so measure after a layout pass.
	_box.modulate.a = 0.0
	_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_box.offset_left = 16
	_box.offset_right = -16
	_box.grow_vertical = Control.GROW_DIRECTION_END
	_box.offset_bottom = _box.offset_top
	await get_tree().process_frame
	var box_height := _box.size.y
	var y := (screen.y - box_height) / 2
	if rect.size != Vector2.ZERO:
		var below := rect.end.y + 24
		var above := rect.position.y - box_height - 24
		y = below if rect.get_center().y < screen.y / 2 else above
	y = clampf(y, 90, screen.y - box_height - 20)
	_box.offset_top = y
	_box.offset_bottom = y + box_height
	_box.create_tween().tween_property(_box, "modulate:a", 1.0, 0.15)


func _finish() -> void:
	if not is_inside_tree():
		return
	if not Session.profile.tour_done:
		Session.profile.tour_done = true
		Session.save()
	_main.show_tab(Session.Tab.EGGS)
	finished.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish()
