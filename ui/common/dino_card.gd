class_name DinoCard
extends Control
## A dino card in the style of Jo's concept sheet (docs/concept/card_concept_sheet.webp):
## full-bleed painting inside a glowing frame in the tier color, the tier crest (N, R, SR, SSR,
## UR) top-left, the type medallion top-right, a name banner with the dino's title, and four
## stat boxes along the bottom. SSR and UR frames pulse; UR and Shiny frames shift through
## colors; Shiny cards also get a holo sheen over the art. Undiscovered dinos show the card back.
##
## Everything is laid out in fractions of the card width, so the same card renders crisply from
## a tiny bench card to the full-screen view.
##
## Tap emits `pressed`. Holding the card opens the full-size CardViewer.

## Emitted on tap. A drag (e.g. scrolling a list of cards) doesn't count as a tap.
signal pressed

enum Mode { MINI, FULL, BATTLE, LARGE }

const WIDTHS := {Mode.MINI: 104.0, Mode.FULL: 212.0, Mode.BATTLE: 200.0, Mode.LARGE: 480.0}
## Card height / width, as in the concept sheet.
const ASPECT := 1.68
## Frame thickness as a fraction of the card width.
const BORDER := 0.045
## Paintings are 2:3 portraits. They're shown at the full width inside the frame, anchored to the
## top, so nothing is cropped; the window is taller than 2:3, and the extra space at the bottom is
## the dark panel behind the name banner and stats.
const ART_ASPECT := 1.5
## The part of card_back.png inside its own painted frame (fractions of the image).
const CARD_BACK_INNER := Rect2(0.07, 0.05, 0.86, 0.9)
const TAP_SLOP := 16.0
const HOLD_SECONDS := 0.45
const FRAME_SHADER := preload("res://ui/common/card_frame.gdshader")
const HABITAT_SHADER := preload("res://ui/common/habitat.gdshader")
const HOLO_SHADER := preload("res://ui/common/holo.gdshader")
const TILT_SHADER := preload("res://ui/common/tilt_shine.gdshader")
const CARD_BACK_PATH := "res://assets/branding/card_back.png"
## Placeholder backdrops per type until the paintings exist: top, middle, bottom, horizon, rays.
const HABITATS := [
	[Color("f6b26b"), Color("c77b3f"), Color("3b2a1e"), 0.55, 0.0],
	[Color("6fb8f2"), Color("cdebff"), Color("6e8fb5"), 0.6, 0.0],
	[Color("3fb6e0"), Color("1462b8"), Color("04122e"), 0.35, 1.0],
]
const PANEL := Color(0.03, 0.07, 0.14, 0.88)

var def: DinoDef
var combatant: Combatant
var mode := Mode.FULL
var width := 212.0
## Opens the full-size view when the card is held.
var inspect_on_hold := true
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()
var dimmed := false:
	set(value):
		dimmed = value
		modulate = Color(1, 1, 1, 0.4) if value else Color.WHITE
## In battle: darkens the card and stamps "K.O." across it.
var knocked_out := false:
	set(value):
		knocked_out = value
		if _overlay:
			_overlay.queue_redraw()
## Size of the K.O. stamp; it starts big and slams down to 1 (see tween_health).
var stamp_scale := 1.0:
	set(value):
		stamp_scale = value
		if _overlay:
			_overlay.queue_redraw()
## Shiny copies get a color-shifting frame and a holo sheen. Cosmetic only.
var shiny := false
## Undiscovered dinos show the card back (used by the Dex).
var unknown := false
## Health drawn on the HP bar; tweened by the battle screen.
var shown_health := 0.0:
	set(value):
		shown_health = value
		if _overlay:
			_overlay.queue_redraw()

var _overlay: Control
## Shaders that follow the phone's tilt (see enable_tilt_shine / set_tilt).
var _tilt_materials: Array[ShaderMaterial] = []
var _badge_text := ""
var _press_position := Vector2.INF
var _press_serial := 0


## Builds a card. Pass a Combatant to show live battle stats and an HP bar. `custom_width`
## overrides the mode's default width.
static func create(dino: DinoDef, card_mode: Mode, live: Combatant = null, is_shiny := false,
		custom_width := 0.0) -> DinoCard:
	var card := DinoCard.new()
	card.def = dino
	card.mode = card_mode
	card.combatant = live
	card.shiny = is_shiny
	card.width = custom_width if custom_width > 0.0 else WIDTHS[card_mode]
	card._build()
	return card


## A face-down card (the card back) for a dino the player hasn't discovered yet.
static func create_unknown(dino: DinoDef, card_mode: Mode, custom_width := 0.0) -> DinoCard:
	var card := DinoCard.new()
	card.def = dino
	card.mode = card_mode
	card.unknown = true
	card.width = custom_width if custom_width > 0.0 else WIDTHS[card_mode]
	card._build()
	return card


## Just the card back at a given width, e.g. for a card about to be flipped over: the stone and
## claw-mark center of the card back art inside the same glowing frame the fronts use (in blue).
static func create_back(card_width: float) -> Control:
	var h := card_width * ASPECT
	var border := card_width * BORDER
	var back := Control.new()
	back.size = Vector2(card_width, h)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := Control.new()
	clip.position = Vector2(border, border)
	clip.size = back.size - Vector2(border, border) * 2
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(clip)
	var source: Texture2D = load(CARD_BACK_PATH)
	var inner := AtlasTexture.new()
	inner.atlas = source
	var source_size := Vector2(source.get_size())
	inner.region = Rect2(CARD_BACK_INNER.position * source_size, CARD_BACK_INNER.size * source_size)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = inner
	art.size = clip.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art)
	back.add_child(_make_frame(card_width, h, border, Palette.ACCENT, 0.7, 0.0, 0.0))
	return back


## Full size of a card in this mode, including the HP bar when it shows one.
static func size_for(card_mode: Mode, with_health := false) -> Vector2:
	return size_for_width(WIDTHS[card_mode], with_health)


static func size_for_width(w: float, with_health: bool) -> Vector2:
	return Vector2(w, w * ASPECT + (_bar_height(w) + w * 0.04 if with_health else 0.0))


static func _bar_height(w: float) -> float:
	return maxf(10.0, w * 0.075)


func display_health(health: int) -> void:
	shown_health = health
	knocked_out = health <= 0


## Animates the HP bar to `health`. A knockout slams the K.O. stamp down onto the card.
func tween_health(health: int, duration := 0.35) -> void:
	create_tween().tween_property(self, "shown_health", float(health), duration)
	if health <= 0 and not knocked_out:
		stamp_scale = 2.6
		create_tween().tween_property(self, "stamp_scale", 1.0, 0.24).set_delay(duration * 0.6) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	knocked_out = health <= 0


func set_badge(text: String) -> void:
	_badge_text = text
	if _overlay:
		_overlay.queue_redraw()


func card_height() -> float:
	return width * ASPECT


func tier_color() -> Color:
	return Palette.RARITY_COLORS[def.rarity]


func _small() -> bool:
	return width < 150.0


# --- Building -------------------------------------------------------------------------------

func _build() -> void:
	size = size_for_width(width, combatant != null)
	custom_minimum_size = size
	pivot_offset = Vector2(width, card_height()) / 2
	# PASS lets a parent ScrollContainer still see drags that start on the card.
	mouse_filter = Control.MOUSE_FILTER_PASS
	var w := width
	var h := card_height()

	if unknown:
		var back := create_back(w)
		add_child(back)
	else:
		var border := w * BORDER
		var window := Rect2(border, border, w - border * 2, h - border * 2)
		var panel := ColorRect.new()
		panel.color = Color(PANEL, 1.0)
		panel.position = window.position
		panel.size = window.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		# Full width, top-aligned, exact 2:3: the whole painting shows.
		var art_rect := Rect2(window.position, Vector2(window.size.x, window.size.x * ART_ASPECT))
		_add_art(art_rect)
		if shiny:
			_add_holo(window)
		# Blend the bottom of the painting into the panel behind the name and stats.
		var fade := Control.new()
		fade.position = art_rect.position
		fade.size = art_rect.size
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.draw.connect(func() -> void:
			var top := fade.size.y * 0.66
			var colors := PackedColorArray([Color(PANEL, 0.0), Color(PANEL, 0.0), Color(PANEL, 1.0), Color(PANEL, 1.0)])
			fade.draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(fade.size.x, top),
					Vector2(fade.size.x, fade.size.y), Vector2(0, fade.size.y)]), colors))
		add_child(fade)
		add_child(_make_frame(w, h, border, tier_color(), 0.55 + def.rarity * 0.1,
				1.0 if def.rarity == DinoDef.Rarity.LEGENDARY else (0.6 if shiny else 0.0),
				1.0 if def.rarity >= DinoDef.Rarity.EPIC or shiny else 0.0))

	_overlay = Control.new()
	_overlay.size = size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	if combatant:
		shown_health = combatant.health


## The glowing frame (see card_frame.gdshader), on a rect that extends past the card for the glow.
static func _make_frame(w: float, h: float, border: float, color: Color, glow_strength: float,
		rainbow: float, pulse: float) -> ColorRect:
	var glow := w * 0.07
	var frame := ColorRect.new()
	frame.position = Vector2(-glow, -glow)
	frame.size = Vector2(w + glow * 2, h + glow * 2)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FRAME_SHADER
	material.set_shader_parameter("rect_size", frame.size)
	material.set_shader_parameter("card_size", Vector2(w, h))
	material.set_shader_parameter("glow", glow)
	material.set_shader_parameter("border", border)
	material.set_shader_parameter("radius", w * 0.07)
	material.set_shader_parameter("tier_color", color)
	material.set_shader_parameter("glow_strength", glow_strength)
	material.set_shader_parameter("rainbow", rainbow)
	material.set_shader_parameter("pulse", pulse)
	frame.material = material
	return frame


## The painting if there is one, otherwise a habitat backdrop with a silhouette.
func _add_art(rect: Rect2) -> void:
	var clip := Control.new()
	clip.position = rect.position
	clip.size = rect.size
	# Cover-fit draws past its rect, so clip the art to the card.
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	var painting := DinoArt.for_card(def, shiny, width)
	if painting:
		var art := TextureRect.new()
		# Thumbnails have mipmaps, which keep them smooth on small bench cards.
		if painting.resource_path.begins_with(DinoArt.THUMB_FOLDER):
			art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# Expand mode first: otherwise the size can't go below the texture's own size.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture = painting
		art.size = rect.size
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(art)
		return
	var habitat: Array = HABITATS[def.dino_type]
	var backdrop := ColorRect.new()
	backdrop.size = rect.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = HABITAT_SHADER
	material.set_shader_parameter("top_color", habitat[0])
	material.set_shader_parameter("mid_color", habitat[1])
	material.set_shader_parameter("bottom_color", habitat[2])
	material.set_shader_parameter("horizon", habitat[3])
	material.set_shader_parameter("rays", habitat[4])
	material.set_shader_parameter("rect_size", rect.size)
	material.set_shader_parameter("radius", 0.0)
	backdrop.material = material
	clip.add_child(backdrop)
	var shape := TextureRect.new()
	shape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shape.position = Vector2(rect.size.x * 0.06, rect.size.y * 0.2)
	shape.size = Vector2(rect.size.x * 0.88, rect.size.y * 0.36)
	shape.texture = Icons.texture(Icons.silhouette(def.dino_type), int(shape.size.y))
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(shape)


func _add_holo(rect: Rect2) -> void:
	var holo := ColorRect.new()
	holo.position = rect.position
	holo.size = rect.size
	holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = HOLO_SHADER
	material.set_shader_parameter("rect_size", rect.size)
	material.set_shader_parameter("radius", 0.0)
	material.set_shader_parameter("rainbow", 1.0)
	material.set_shader_parameter("strength", 0.26)
	holo.material = material
	add_child(holo)
	_tilt_materials.append(material)


## Full-screen view of a UR or Shiny card: adds a glare that moves with set_tilt().
func enable_tilt_shine() -> void:
	var border := width * BORDER
	var rect := Rect2(border, border, width - border * 2, card_height() - border * 2)
	var glare := ColorRect.new()
	glare.position = rect.position
	glare.size = rect.size
	glare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = TILT_SHADER
	material.set_shader_parameter("rect_size", rect.size)
	material.set_shader_parameter("radius", width * 0.05)
	material.set_shader_parameter("rainbow", 1.0 if shiny or def.rarity == DinoDef.Rarity.LEGENDARY else 0.3)
	glare.material = material
	# Under the frame and the stats overlay, over the art.
	add_child(glare)
	move_child(glare, _overlay.get_index() if _overlay else get_child_count() - 1)
	_tilt_materials.append(material)


## -1..1 on each axis.
func set_tilt(tilt: Vector2) -> void:
	for material in _tilt_materials:
		material.set_shader_parameter("tilt", tilt)


# --- Input ----------------------------------------------------------------------------------

# Touches arrive as emulated mouse events on phones, so this covers both.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _press_position != Vector2.INF:
		if _press_position.distance_to(event.global_position) > TAP_SLOP:
			_press_position = Vector2.INF
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_position = event.global_position
		_press_serial += 1
		if inspect_on_hold:
			_watch_hold(_press_serial)
	elif _press_position != Vector2.INF and _press_position.distance_to(event.global_position) < TAP_SLOP:
		_press_position = Vector2.INF
		pressed.emit()


func _watch_hold(serial: int) -> void:
	await get_tree().create_timer(HOLD_SECONDS).timeout
	if serial == _press_serial and _press_position != Vector2.INF and is_inside_tree():
		_press_position = Vector2.INF
		CardViewer.open(def, shiny, not unknown)


# --- Drawing --------------------------------------------------------------------------------

## Selection ring, drawn behind the card so only the part outside the frame shows.
func _draw() -> void:
	if not (selected or highlighted):
		return
	var grow := width * 0.045
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color.WHITE if selected else Color(Palette.HIGHLIGHT, 0.7)
	ring.set_corner_radius_all(int(width * 0.1))
	draw_style_box(ring, Rect2(-grow, -grow, width + grow * 2, card_height() + grow * 2))


func _draw_overlay() -> void:
	if not unknown:
		_draw_name_banner()
		_draw_stats()
		_draw_type_medallion()
		_draw_tier_crest()
	if _badge_text != "":
		_draw_badge()
	if combatant:
		_draw_health_bar()
	if knocked_out:
		_draw_knocked_out()


func _draw_knocked_out() -> void:
	var w := width
	var h := card_height()
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(0.02, 0.03, 0.07, 0.62)
	shade.set_corner_radius_all(int(w * 0.07))
	_overlay.draw_style_box(shade, Rect2(0, 0, w, h))
	# A tilted red stamp in the middle.
	var font_size := int(w * 0.3)
	var stamp := Vector2(w * 0.78, font_size * 1.15)
	_overlay.draw_set_transform(Vector2(w, h) / 2, -0.26, Vector2.ONE * stamp_scale)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.35)
	box.border_color = Palette.DAMAGE
	box.set_border_width_all(maxi(2, int(w * 0.025)))
	box.set_corner_radius_all(int(w * 0.04))
	_overlay.draw_style_box(box, Rect2(-stamp / 2, stamp))
	_text_centered(Fonts.display(), "K.O.", Vector2.ZERO, font_size, Palette.DAMAGE, true)
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Tier crest: a shield badge with N / R / SR / SSR / UR, crowned for SSR and UR.
func _draw_tier_crest() -> void:
	var o := _overlay
	var w := width
	var cw := w * (0.3 if _small() else 0.25)
	var ch := cw * 0.78
	var origin := Vector2(w * 0.035, w * 0.035)
	var shape := PackedVector2Array([origin, origin + Vector2(cw, 0), origin + Vector2(cw, ch * 0.62),
			origin + Vector2(cw * 0.5, ch), origin + Vector2(0, ch * 0.62)])
	var tier := tier_color()
	o.draw_colored_polygon(shape, Color(tier.darkened(0.75), 0.95))
	var inner := PackedVector2Array()
	var middle := origin + Vector2(cw * 0.5, ch * 0.45)
	for point in shape:
		inner.append(middle + (point - middle) * 0.78)
	inner.append(inner[0])
	o.draw_polyline(inner, Color(tier, 0.6), maxf(1.0, w * 0.006), true)
	shape.append(shape[0])
	o.draw_polyline(shape, tier.lightened(0.2), maxf(1.5, w * 0.014), true)
	var code := def.rarity_code()
	var font := Fonts.display()
	var fitted := int(ch * 0.62)
	while fitted > 6 and font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > cw * 0.82:
		fitted -= 1
	_text_centered(font, code, origin + Vector2(cw * 0.5, ch * 0.42), fitted, tier.lerp(Color.WHITE, 0.45), true)
	if def.rarity >= DinoDef.Rarity.EPIC:
		var crown_w := cw * 0.55
		var crown := Icons.texture(&"crown", int(crown_w * 0.62))
		o.draw_texture_rect(crown, Rect2(origin + Vector2(cw * 0.5 - crown_w / 2, -crown_w * 0.42),
				Vector2(crown_w, crown_w * 0.62)), false)
	if not _small():
		# Party Point cost, needed when picking a party.
		var pts := PartyRules.points_of(def)
		var pill := Rect2(origin + Vector2(cw * 0.12, ch + w * 0.01), Vector2(cw * 0.76, w * 0.065))
		_draw_panel(pill, tier, pill.size.y / 2)
		_text_centered(Fonts.display(), "%d PT%s" % [pts, "" if pts == 1 else "S"], pill.get_center(),
				int(pill.size.y * 0.72), Color.WHITE, false)


func _draw_type_medallion() -> void:
	var w := width
	var size_px := w * (0.28 if _small() else 0.24)
	var top_left := Vector2(w - size_px - w * 0.03, w * 0.03)
	var icon := Icons.texture(Icons.type_icon(def.dino_type), int(size_px))
	_overlay.draw_texture_rect(icon, Rect2(top_left, Vector2.ONE * size_px), false)
	if not _small():
		_text_centered(Fonts.display(), Palette.TYPE_LABELS[def.dino_type],
				top_left + Vector2(size_px / 2, size_px + w * 0.03), int(w * 0.05), Color.WHITE, true)


func _draw_name_banner() -> void:
	var o := _overlay
	var w := width
	var h := card_height()
	var small := _small()
	var bh := w * (0.17 if small else 0.18)
	var y0 := h - w * (0.43 if small else 0.5)
	var x0 := w * 0.06
	var x1 := w * 0.94
	var slant := w * 0.045
	var banner := PackedVector2Array([Vector2(x0 + slant, y0), Vector2(x1 - slant, y0), Vector2(x1, y0 + bh / 2),
			Vector2(x1 - slant, y0 + bh), Vector2(x0 + slant, y0 + bh), Vector2(x0, y0 + bh / 2)])
	o.draw_colored_polygon(banner, PANEL)
	var tier := tier_color()
	banner.append(banner[0])
	o.draw_polyline(banner, Color(tier, 0.85), maxf(1.0, w * 0.007), true)
	o.draw_line(Vector2(x0 + slant * 1.5, y0 + 1.5), Vector2(x1 - slant * 1.5, y0 + 1.5), Color(tier.lightened(0.4), 0.7), 1.0)
	var name_rect := Rect2(x0 + slant, y0, x1 - x0 - slant * 2, bh * (1.0 if small else 0.62))
	_text_fit(Fonts.display(), def.display_name, name_rect, int(w * (0.12 if small else 0.088)), Color.WHITE)
	if not small and def.epithet != "":
		var epithet_rect := Rect2(x0 + slant, y0 + bh * 0.56, x1 - x0 - slant * 2, bh * 0.4)
		_text_fit(Fonts.italic(), def.epithet, epithet_rect, int(w * 0.048), Palette.HIGHLIGHT.lerp(tier, 0.35))


func _draw_stats() -> void:
	var w := width
	var small := _small()
	var values := _stat_values()
	var base := [def.attack, def.defense, def.speed, def.health]
	var tier := tier_color()
	for i in 4:
		var box := stat_box_rect(i)
		var box_h := box.size.y
		_draw_panel(box, tier, w * 0.025)
		var boosted: bool = values[i] > base[i]
		var value_color := Color("8dffa0") if boosted else Color.WHITE
		if small:
			_text_centered(Fonts.display(), str(values[i]), box.get_center(), int(box_h * 0.62), value_color, true)
			continue
		var icon_px := int(box_h * 0.3)
		var icon := Icons.texture(Palette.STAT_ICONS[i], icon_px)
		_overlay.draw_texture_rect(icon, Rect2(Vector2(box.get_center().x - icon_px / 2.0, box.position.y + box_h * 0.07),
				Vector2.ONE * icon_px), false)
		_text_centered(Fonts.condensed_bold(), Palette.STAT_CODES[i], Vector2(box.get_center().x, box.position.y + box_h * 0.5),
				int(box_h * 0.19), Palette.STAT_COLORS[i], false)
		_text_centered(Fonts.display(), str(values[i]), Vector2(box.get_center().x, box.position.y + box_h * 0.76),
				int(box_h * 0.34), value_color, true)


## Where stat box `index` (0 ATK, 1 DEF, 2 SPD, 3 HP) sits on this card, in card coordinates.
## The How to play pages use this to ring and point at stats.
func stat_box_rect(index: int) -> Rect2:
	var w := width
	var gap := w * 0.02
	var box_w := (w * 0.88 - gap * 3) / 4.0
	var box_h := w * (0.2 if _small() else 0.24)
	return Rect2(w * 0.06 + (box_w + gap) * index, card_height() - box_h - w * 0.06, box_w, box_h)


func _draw_badge() -> void:
	var w := width
	var size_px := int(w * (0.085 if not _small() else 0.12))
	var ribbon := Rect2(0, card_height() * 0.36, w, size_px * 1.6)
	_overlay.draw_rect(ribbon, Color(0, 0, 0, 0.72))
	_overlay.draw_line(ribbon.position, Vector2(ribbon.end.x, ribbon.position.y), Palette.HIGHLIGHT, 1.0)
	_overlay.draw_line(Vector2(0, ribbon.end.y), ribbon.end, Palette.HIGHLIGHT, 1.0)
	_text_centered(Fonts.display(), _badge_text, ribbon.get_center(), size_px, Palette.HIGHLIGHT, true)


func _draw_health_bar() -> void:
	var w := width
	var bar := Rect2(w * 0.04, card_height() + w * 0.04, w * 0.92, _bar_height(w))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.65)
	back.border_color = Palette.PANEL_BORDER
	back.set_border_width_all(1)
	back.set_corner_radius_all(int(bar.size.y / 2))
	_overlay.draw_style_box(back, bar)
	var fraction := clampf(shown_health / combatant.max_health, 0.0, 1.0)
	if fraction > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Palette.health_color(fraction)
		fill.set_corner_radius_all(int(bar.size.y / 2))
		_overlay.draw_style_box(fill, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * fraction), bar.size.y)))
	if not _small():
		_text_centered(Fonts.display(), "%d / %d" % [roundi(shown_health), combatant.max_health],
				bar.get_center(), int(bar.size.y * 0.9), Color.WHITE, true)


func _draw_panel(rect: Rect2, accent: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = Color(accent, 0.8)
	box.set_border_width_all(maxi(1, int(width * 0.006)))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	_overlay.draw_style_box(box, rect)


func _stat_values() -> Array:
	var source: Variant = combatant if combatant else def
	return [source.attack, source.defense, source.speed, combatant.max_health if combatant else def.health]


# --- Text helpers ---------------------------------------------------------------------------

func _text_centered(font: Font, text: String, center: Vector2, font_size: int, color: Color, outline: bool) -> void:
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(center.x - text_w / 2, center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	if outline:
		_overlay.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				maxi(2, int(font_size * 0.16)), Palette.OUTLINE)
	_overlay.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Draws text centered in `rect`, shrinking the font until it fits.
func _text_fit(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var fitted := font_size
	while fitted > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > rect.size.x:
		fitted -= 1
	_text_centered(font, text, rect.get_center(), fitted, color, true)
