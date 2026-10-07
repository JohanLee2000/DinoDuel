class_name DinoCard
extends PanelContainer
## Placeholder card: type-colored panel, rarity-colored border, name, stats, and (in battle) an
## HP bar. The art box will hold the Blender render later.

## Emitted on tap. A drag (e.g. scrolling a list of cards) doesn't count as a tap.
signal pressed

const TAP_SLOP := 16.0

enum Mode { FULL, BATTLE, MINI }

const SIZES := {
	Mode.FULL: Vector2(212, 300),
	Mode.BATTLE: Vector2(290, 330),
	Mode.MINI: Vector2(104, 132),
}

var def: DinoDef
var combatant: Combatant
var mode := Mode.FULL
var selected := false:
	set(value):
		selected = value
		_update_style()
var highlighted := false:
	set(value):
		highlighted = value
		_update_style()
var dimmed := false:
	set(value):
		dimmed = value
		modulate = Color(1, 1, 1, 0.4) if value else Color.WHITE

var _style := StyleBoxFlat.new()
var _health_bar: ProgressBar
var _health_fill := StyleBoxFlat.new()
var _health_label: Label
var _badge: Label
var _press_position := Vector2.INF


## Builds a card. Pass a Combatant to show live battle stats and health.
static func create(dino: DinoDef, card_mode: Mode, live: Combatant = null) -> DinoCard:
	var card := DinoCard.new()
	card.def = dino
	card.mode = card_mode
	card.combatant = live
	card._build()
	return card


func refresh() -> void:
	if combatant:
		display_health(combatant.health)


## Shows `health` right away. The battle screen uses this instead of reading the combatant,
## because the engine resolves a whole turn at once and the UI replays it step by step.
func display_health(health: int) -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = combatant.max_health
	_health_bar.value = health
	_set_health_text(health)


## Animates the HP bar from its current value to `health`.
func tween_health(health: int, duration := 0.35) -> void:
	if _health_bar == null:
		return
	var tween := create_tween()
	tween.tween_property(_health_bar, "value", float(health), duration)
	_set_health_text(health)


func _set_health_text(health: int) -> void:
	_health_fill.bg_color = Palette.health_color(float(health) / combatant.max_health)
	if _health_label:
		_health_label.text = "HP %d/%d" % [health, combatant.max_health]
	dimmed = health <= 0


func set_badge(text: String) -> void:
	_badge.text = text
	_badge.visible = text != ""


func _build() -> void:
	custom_minimum_size = SIZES[mode]
	size = SIZES[mode]
	# PASS lets a parent ScrollContainer still see drags that start on the card.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_style.bg_color = Palette.TYPE_COLORS[def.dino_type].darkened(0.35)
	_style.set_corner_radius_all(10 if mode == Mode.MINI else 14)
	_style.set_content_margin_all(6 if mode == Mode.MINI else 10)
	add_theme_stylebox_override("panel", _style)
	_update_style()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2 if mode == Mode.MINI else 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var stats_source: Variant = combatant if combatant else def
	match mode:
		Mode.MINI:
			box.add_child(_label(def.display_name, 14, Palette.TEXT, true))
			box.add_child(_art_box(46, 22))
			box.add_child(_label("%s %s" % [def.type_name(), _short_rarity()], 12, Palette.TEXT_DIM))
			if combatant:
				box.add_child(_make_health_bar(10))
			else:
				box.add_child(_label("%d/%d/%d/%d" % [def.attack, def.defense, def.speed, def.health],
						12, Palette.TEXT_DIM))
		Mode.FULL:
			box.add_child(_label(def.display_name, 20, Palette.TEXT, true))
			box.add_child(_art_box(110, 40))
			box.add_child(_label("%s  %s" % [def.type_name(), def.era_name()], 15, Palette.TEXT_DIM))
			box.add_child(_label("%s  %d pt%s" % [def.rarity_name(), HerdRules.points_of(def),
					"" if HerdRules.points_of(def) == 1 else "s"], 15,
					Palette.RARITY_COLORS[def.rarity]))
			box.add_child(_stats_grid(stats_source, 16))
		Mode.BATTLE:
			box.add_child(_label(def.display_name, 24, Palette.TEXT, true))
			box.add_child(_art_box(108, 44))
			box.add_child(_label("%s  %s  %s" % [def.type_name(), def.era_name(), def.rarity_name()],
					15, Palette.TEXT_DIM))
			box.add_child(_stats_grid(stats_source, 18))
			_health_label = _label("", 18, Palette.TEXT)
			box.add_child(_health_label)
			box.add_child(_make_health_bar(16))

	_badge = _label("", 13 if mode == Mode.MINI else 16, Color.BLACK)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Palette.HIGHLIGHT
	badge_style.set_corner_radius_all(8)
	badge_style.set_content_margin_all(3)
	_badge.add_theme_stylebox_override("normal", badge_style)
	_badge.visible = false
	box.add_child(_badge)
	refresh()


# Touches arrive as emulated mouse events on phones, so this covers both.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_position = event.global_position
	elif _press_position.distance_to(event.global_position) < TAP_SLOP:
		_press_position = Vector2.INF
		pressed.emit()


func _update_style() -> void:
	var border := Palette.RARITY_COLORS[def.rarity] if def else Color.WHITE
	var width := 3
	if selected:
		border = Palette.HIGHLIGHT
		width = 6
	elif highlighted:
		border = Palette.HIGHLIGHT
		width = 4
	_style.border_color = border
	_style.set_border_width_all(width)


## The art placeholder: a colored box with the dino's initials. Replaced by renders later.
func _art_box(height: int, font_size: int) -> Control:
	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(0, height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Palette.TYPE_COLORS[def.dino_type]
	art_style.set_corner_radius_all(8)
	art.add_theme_stylebox_override("panel", art_style)
	var initials := _label(_initials(), font_size, Color(1, 1, 1, 0.85))
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art.add_child(initials)
	return art


func _stats_grid(source: Variant, font_size: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 4)
	var health: int = source.max_health if source is Combatant else source.health
	var values := [source.attack, source.defense, source.speed, health]
	var base := [def.attack, def.defense, def.speed, def.health]
	for stat_name in ["ATK", "DEF", "SPD", "HP"]:
		var header := _label(stat_name, font_size - 5, Palette.TEXT_DIM)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(header)
	for i in 4:
		# Stats boosted by herd bonuses show in the highlight color.
		var value := _label(str(values[i]), font_size, Palette.HIGHLIGHT if values[i] > base[i] else Palette.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	return grid


func _make_health_bar(height: int) -> ProgressBar:
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(0, height)
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	back.set_corner_radius_all(height / 2)
	_health_fill.set_corner_radius_all(height / 2)
	_health_bar.add_theme_stylebox_override("background", back)
	_health_bar.add_theme_stylebox_override("fill", _health_fill)
	return _health_bar


func _label(text: String, font_size: int, color: Color, ellipsis := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ellipsis:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
	return label


func _initials() -> String:
	var words := def.display_name.replace(".", "").split(" ", false)
	if words.size() > 1:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return def.display_name.left(2).to_upper()


func _short_rarity() -> String:
	return def.rarity_name().left(1)
