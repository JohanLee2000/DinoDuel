class_name UiKit
extends RefCounted
## Small helpers for building placeholder UI in code, so every screen looks consistent.

## Primary actions are gold, secondary navy, and the "spend Amber" action orange.
const BUTTON_GREEN := Color("ffb22e")
const BUTTON_GRAY := Color("1c2c48")
const BUTTON_AMBER := Color("ff7a1a")
## Actions that give something up, like leaving a battle.
const BUTTON_RED := Color("d92b3a")
## Rare clutches, in Super Rare purple.
const BUTTON_RARE := Color("8a46e6")


## Wrapping labels need a width from their parent, so pass wrap = false inside rows and grids.
static func label(text: String, font_size := 26, color := Palette.TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Heading text: bold condensed italic capitals with a dark outline, like the concept sheet.
static func title(text: String, font_size := 34, color := Palette.TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := label(text.to_upper(), font_size, color, align, wrap)
	l.add_theme_font_override("font", Fonts.title())
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 7))
	return l


static func button(text: String, color: Color, height := 84, font_size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, color)
	return b


## A button() with an icon in front of its text, the two centered together. White icons (see
## Icons) are tinted to the button's text color; pass `icon_tint` to color one yourself instead
## (Color.WHITE keeps a full-color icon as drawn).
static func icon_button(text: String, icon_name: StringName, color: Color, height := 84,
		font_size := 30, icon_tint := Color(0, 0, 0, 0)) -> Button:
	var b := button("", color, height, font_size)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := int(font_size * 1.25)
	var glyph := TextureRect.new()
	glyph.texture = Icons.texture(icon_name, icon_px)
	glyph.custom_minimum_size = Vector2(icon_px, icon_px)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.modulate = text_color_on(color) if icon_tint.a == 0.0 else icon_tint
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var caption := label(text, font_size, text_color_on(color), HORIZONTAL_ALIGNMENT_LEFT, false)
	caption.add_theme_font_override("font", Fonts.display())
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	center.add_child(row)
	b.add_child(center)
	b.set_meta("caption", caption)
	b.set_meta("glyph", glyph)
	# Sink with the button when it's pressed, like a plain button's text does.
	b.button_down.connect(func() -> void: center.offset_top = 3)
	b.button_up.connect(func() -> void: center.offset_top = 0)
	return b


## A glossy, glowing button: lighter top border, darker bottom edge, a soft glow in its own
## color, and it sinks when pressed. Dark text on bright colors, light text on dark ones.
## A modern pill button: frosted glass, thin light border, and an icon + text centered together
## (used for Share). Change its text with set_pill_text.
static func pill_button(text: String, icon_name: StringName, height := 76, font_size := 30) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, {"normal": 0.14, "hover": 0.2, "pressed": 0.26, "disabled": 0.08, "focus": 0.14}[state])
		style.border_color = Color(1, 1, 1, 0.45)
		style.set_border_width_all(2)
		style.set_corner_radius_all(height / 2)
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 10
		b.add_theme_stylebox_override(state, style)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := int(height * 0.42)
	var glyph := TextureRect.new()
	glyph.texture = Icons.texture(icon_name, icon_px)
	glyph.custom_minimum_size = Vector2(icon_px, icon_px)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var caption := label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
	caption.add_theme_font_override("font", Fonts.bold())
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	center.add_child(row)
	b.add_child(center)
	b.set_meta("caption", caption)
	return b


static func set_pill_text(b: Button, text: String) -> void:
	(b.get_meta("caption") as Label).text = text


## Dark text on bright buttons, light text on dark ones.
static func text_color_on(color: Color) -> Color:
	return Palette.INK if color.get_luminance() > 0.45 else Palette.TEXT


static func style_button(b: Button, color: Color) -> void:
	var text_color := text_color_on(color)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		style.bg_color = color
		style.border_color = color.lightened(0.35)
		style.set_border_width_all(2)
		style.border_width_bottom = 5
		style.shadow_color = Color(color, 0.35)
		style.shadow_size = 8
		match state_name:
			"normal":
				style.border_color = color.lightened(0.35)
			"hover":
				style.bg_color = color.lightened(0.08)
			"pressed":
				style.bg_color = color.darkened(0.12)
				style.border_width_bottom = 2
				style.content_margin_top = 11
			"disabled":
				style.bg_color = color.darkened(0.6)
				style.border_color = color.darkened(0.4)
				style.shadow_size = 0
			"focus":
				style.draw_center = false
				style.border_color = Color.WHITE
				style.set_border_width_all(2)
				style.shadow_size = 0
		b.add_theme_stylebox_override(state_name, style)
	b.add_theme_font_override("font", Fonts.display())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(color_name, text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color, 0.45))


static func panel(content: Control, color := Palette.PANEL, margin := 14) -> PanelContainer:
	var p := PanelContainer.new()
	# Panels default to STOP, which would swallow drags meant for a parent ScrollContainer.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.92)
	style.border_color = Palette.PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", style)
	p.add_child(content)
	return p


static func vbox(separation := 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation := 12, alignment := BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = alignment
	return box


static func grid(columns: int, separation := 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", separation)
	g.add_theme_constant_override("v_separation", separation)
	return g


## A scroll area that only scrolls vertically and fills the remaining height.
static func vscroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## A full-screen dimmed layer that blocks input to whatever is underneath.
static func modal_layer(alpha := 0.8) -> ColorRect:
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, alpha)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	return layer
