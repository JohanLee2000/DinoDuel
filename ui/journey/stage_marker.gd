class_name StageMarker
extends Control
## One Journey stage on the map: the rival's head in a round frame, the best stars under it and
## their name, a crown for Rory, a lock until the stage opens, and a pulse on the next stage to
## play. Tap it to see the rival. The map places it so the circle sits on the trail (`anchor`).

signal pressed

const SIZE := 104.0
const BOSS_SIZE := 132.0
const CROWN_HEIGHT := 30.0
const STAR_SIZE := 26.0
const TAP_SLOP := 12.0

var stage: RivalDef
var stars := 0
var unlocked := true
var is_next := false
var _diameter := SIZE
var _press_position := Vector2.INF


static func create(for_stage: RivalDef, best_stars: int, is_unlocked: bool, next: bool) -> StageMarker:
	var marker := StageMarker.new()
	marker.stage = for_stage
	marker.stars = best_stars
	marker.unlocked = is_unlocked
	marker.is_next = next
	return marker


## Where the middle of the circle is, relative to the marker's top-left corner.
func anchor() -> Vector2:
	return Vector2(size.x / 2, CROWN_HEIGHT + _diameter / 2)


func _ready() -> void:
	_diameter = BOSS_SIZE if stage.is_boss else SIZE
	var width := maxf(_diameter + 40, 190)
	custom_minimum_size = Vector2(width, CROWN_HEIGHT + _diameter + STAR_SIZE + 46)
	size = custom_minimum_size
	# PASS so a drag that starts on a marker still scrolls the map.
	mouse_filter = Control.MOUSE_FILTER_PASS
	var center := anchor()
	var circle := Rect2(center - Vector2.ONE * _diameter / 2, Vector2.ONE * _diameter)

	if is_next and unlocked:
		var glow := _ring(circle.grow(10), Palette.HIGHLIGHT, 6)
		glow.pivot_offset = glow.size / 2
		var pulse := glow.create_tween().set_loops()
		pulse.tween_property(glow, "modulate:a", 0.25, 0.7).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	var frame := Panel.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color("1b2a47")
	disc.set_corner_radius_all(int(_diameter / 2))
	frame.add_theme_stylebox_override("panel", disc)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.position = circle.position
	frame.size = circle.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var face := TextureRect.new()
	face.texture = RivalArt.head(stage.character)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(face)
	if not unlocked:
		frame.modulate = Color(0.45, 0.45, 0.5)

	var rim_color := Palette.HIGHLIGHT if stage.is_boss or stars > 0 else (Palette.ACCENT if unlocked else Color("5b6b86"))
	_ring(circle, rim_color, 6 if stage.is_boss else 5)

	if stage.is_boss:
		var crown := _icon(&"crown", Vector2(64, 40))
		crown.position = Vector2(center.x - 32, circle.position.y - CROWN_HEIGHT - 4)
	if not unlocked:
		# A small lock on the rim, so you can still see who's coming.
		var badge := Panel.new()
		var dot := StyleBoxFlat.new()
		dot.bg_color = Color("26364f")
		dot.border_color = Color("5b6b86")
		dot.set_border_width_all(3)
		dot.set_corner_radius_all(20)
		badge.add_theme_stylebox_override("panel", dot)
		badge.size = Vector2(40, 40)
		badge.position = circle.end - Vector2(38, 38)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
		var lock := _icon(&"lock", Vector2(26, 26))
		lock.position = badge.position + Vector2(7, 6)

	var below := circle.end.y + 4
	if unlocked:
		for i in Journey.MAX_STARS:
			var star := _icon(&"star" if i < stars else &"star_empty", Vector2(STAR_SIZE, STAR_SIZE))
			star.position = Vector2(center.x + (i - 1) * (STAR_SIZE + 2) - STAR_SIZE / 2, below)
	var name_pill := PanelContainer.new()
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.03, 0.06, 0.12, 0.82)
	pill.set_corner_radius_all(12)
	pill.content_margin_left = 10
	pill.content_margin_right = 10
	pill.content_margin_top = 1
	pill.content_margin_bottom = 2
	name_pill.add_theme_stylebox_override("panel", pill)
	name_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiKit.label(stage.display_name, 21, Palette.HIGHLIGHT if stage.is_boss else Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, false)
	label.add_theme_font_override("font", Fonts.bold())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_pill.add_child(label)
	add_child(name_pill)
	name_pill.reset_size()
	name_pill.position = Vector2(center.x - name_pill.size.x / 2, below + STAR_SIZE + 2)


func _ring(rect: Rect2, color: Color, width: int) -> Panel:
	var ring := Panel.new()
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(rect.size.x / 2))
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	ring.add_theme_stylebox_override("panel", style)
	ring.position = rect.position
	ring.size = rect.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)
	return ring


func _icon(icon_name: StringName, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name, int(icon_size.y))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	return icon


## A tap (not a scroll) opens the rival.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _press_position != Vector2.INF:
		if _press_position.distance_to(event.global_position) > TAP_SLOP:
			_press_position = Vector2.INF
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_position = event.global_position
	elif _press_position != Vector2.INF:
		_press_position = Vector2.INF
		Sound.play(&"tap")
		pressed.emit()
