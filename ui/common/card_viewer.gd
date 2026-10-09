class_name CardViewer
extends Control
## Full-screen view of one card so players can read it comfortably. Opens when any card is held,
## and from the Dex. Tap anywhere (except on extra buttons) to close.
##
## UR and Shiny cards catch the light: tilting the phone, or dragging the card, slides a glare and
## their holo sheen across them (DinoCard.enable_tilt_shine).

signal closed

const CARD_WIDTH := 470.0
## How far the phone has to tilt (change in gravity, m/s²) or the card be dragged (pixels) for
## the light to reach the edge.
const TILT_RANGE := 3.0
const DRAG_RANGE := 220.0

var _dino: DinoDef
var _shiny := false
var _known := true
var _extras: Array[Control] = []
var _shine_card: DinoCard
var _tilt := Vector2.ZERO
var _drag_tilt := Vector2.ZERO
var _drag_from := Vector2.INF
var _rest_gravity := Vector3.ZERO


## Opens the viewer on top of the current screen. `extras` are shown under the card (e.g. a
## craft button in the Dex).
static func open(dino: DinoDef, shiny := false, known := true, extras: Array[Control] = []) -> CardViewer:
	var viewer := CardViewer.new()
	viewer._dino = dino
	viewer._shiny = shiny
	viewer._known = known
	viewer._extras = extras
	var tree := Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(viewer)
	return viewer


func close() -> void:
	closed.emit()
	queue_free()


func _ready() -> void:
	Sound.play(&"card_open")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := UiKit.modal_layer(0.9)
	layer.gui_input.connect(_on_layer_input)
	add_child(layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := UiKit.vbox(18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	var card := DinoCard.create(_dino, DinoCard.Mode.LARGE, null, _shiny, CARD_WIDTH) if _known \
			else DinoCard.create_unknown(_dino, DinoCard.Mode.LARGE, CARD_WIDTH)
	card.inspect_on_hold = false
	card.pressed.connect(close)
	if _known and (_shiny or _dino.rarity == DinoDef.Rarity.LEGENDARY):
		_shine_card = card
		card.enable_tilt_shine()
		card.gui_input.connect(_on_card_input)
	set_process(_shine_card != null)
	var holder := Control.new()
	holder.custom_minimum_size = card.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(card)
	column.add_child(holder)
	card.scale = Vector2(0.8, 0.8)
	card.modulate.a = 0.0
	var tween := card.create_tween().set_parallel()
	tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.15)

	# The card face is mostly painting, so the details live here.
	if _known:
		var tier := Palette.RARITY_COLORS[_dino.rarity]
		var heading := "%s  %s  ·  %s" % [_dino.rarity_code(), _dino.rarity_name(), Palette.TYPE_LABELS[_dino.dino_type]]
		if _shiny:
			heading += "  ·  SHINY"
		column.add_child(_centered_label(heading, 28, tier, true))
		column.add_child(_centered_label("%s · %s era · %s" % [_dino.group, _dino.era_name(), _dino.size_text],
				24, Palette.TEXT_DIM))
		var pts := PartyRules.points_of(_dino)
		column.add_child(_centered_label("Beats %s  ·  Weak to %s  ·  %d Party Point%s" % [
				DinoDef.TYPE_NAMES[(_dino.dino_type + 1) % 3], DinoDef.TYPE_NAMES[(_dino.dino_type + 2) % 3],
				pts, "" if pts == 1 else "s"], 24, Palette.ACCENT))
		column.add_child(_sets_line())
		if _dino.flavor_text != "":
			column.add_child(_centered_label(_dino.flavor_text, 25, Palette.TEXT))
	for extra in _extras:
		column.add_child(extra)
	column.add_child(_centered_label("Tap anywhere to close", 22, Palette.TEXT_DIM))


## The sets this dino counts toward (see DinoSets), with a gold star on the badges earned.
func _sets_line() -> RichTextLabel:
	var parts: Array[String] = []
	for id in DinoSets.sets_of(_dino.id):
		if DinoSets.claimed(Session.profile, id):
			parts.append("[color=#%s]★ %s[/color]" % [Palette.HIGHLIGHT.to_html(), DinoSets.title_of(id)])
		else:
			parts.append(DinoSets.title_of(id))
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	line.add_theme_font_size_override("normal_font_size", 24)
	line.add_theme_color_override("default_color", Palette.TEXT_DIM)
	line.text = "[center]Sets: %s[/center]" % "  ·  ".join(parts)
	return line


func _centered_label(text: String, font_size: int, color: Color, as_title := false) -> Label:
	var label := UiKit.title(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER) if as_title \
			else UiKit.label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	var target := _drag_tilt
	var gravity := Input.get_gravity()
	if gravity.length() > 1.0:
		# Relative to how the phone was held when the card opened, slowly re-centring.
		if _rest_gravity == Vector3.ZERO:
			_rest_gravity = gravity
		_rest_gravity = _rest_gravity.lerp(gravity, minf(1.0, delta * 0.5))
		var change := (gravity - _rest_gravity) / TILT_RANGE
		target += Vector2(change.x, change.z)
	target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	_tilt = _tilt.lerp(target, 1.0 - exp(-delta * 8.0))
	_shine_card.set_tilt(_tilt)


func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = event.global_position if event.pressed else Vector2.INF
		if not event.pressed:
			_drag_tilt = Vector2.ZERO
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF:
		_drag_tilt = (event.global_position - _drag_from) / DRAG_RANGE


func _on_layer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
