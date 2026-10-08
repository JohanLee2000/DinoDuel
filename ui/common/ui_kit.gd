class_name UiKit
extends RefCounted
## Small helpers for building placeholder UI in code, so every screen looks consistent.

## Primary actions are gold, secondary navy, and the "spend Amber" action orange.
const BUTTON_GREEN := Color("ffb22e")
const BUTTON_GRAY := Color("1c2c48")
const BUTTON_AMBER := Color("ff7a1a")


## Wrapping labels need a width from their parent, so pass wrap = false inside rows and grids.
static func label(text: String, font_size := 22, color := Palette.TEXT,
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


## A glossy, glowing button: lighter top border, darker bottom edge, a soft glow in its own
## color, and it sinks when pressed. Dark text on bright colors, light text on dark ones.
static func style_button(b: Button, color: Color) -> void:
	var text_color := Palette.INK if color.get_luminance() > 0.45 else Palette.TEXT
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
