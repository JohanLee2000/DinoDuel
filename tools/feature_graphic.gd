extends Control
## Renders the 1024x500 Google Play feature graphic into docs/store/feature_graphic.png, using the
## real in-game cards. Run (needs a window, so not --headless):
##     "$GODOT" --path . --resolution 1024x500 res://tools/feature_graphic.tscn

const SIZE := Vector2i(1024, 500)
const OUT := "res://docs/store/feature_graphic.png"
const BACKDROP := "res://assets/dinos/brachiosaurus.webp"
const LOGO := "res://assets/branding/logo.png"
const TAGLINE := "Hatch. Collect. Battle."
## [dino id, shiny, card width, center position, rotation in degrees], back to front.
const CARDS := [
	[&"quetzalcoatlus", false, 190.0, Vector2(862, 262), 10.0],
	[&"mosasaurus", false, 190.0, Vector2(594, 262), -10.0],
	[&"t_rex", true, 222.0, Vector2(728, 250), 0.0],
]


func _ready() -> void:
	get_window().content_scale_size = SIZE
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	size = Vector2(SIZE)
	_build()
	for i in 6:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("Saved %s (%dx%d)" % [OUT, image.get_width(), image.get_height()])
	get_tree().quit()


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = load(BACKDROP)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size = Vector2(SIZE)
	add_child(backdrop)

	# Navy on the left (behind the logo) fading to a light tint behind the cards.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.BACKGROUND, 0.97))
	gradient.set_color(1, Color(Palette.BACKGROUND, 0.45))
	gradient.add_point(0.45, Color(Palette.BACKGROUND, 0.88))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.width = 256
	fill.height = 4
	shade.texture = fill
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.size = Vector2(SIZE)
	add_child(shade)

	var logo := TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.size = Vector2(400, 400 * 200.0 / 758.0)
	logo.position = Vector2(40, 156)
	add_child(logo)

	var tagline := Label.new()
	tagline.text = TAGLINE
	tagline.add_theme_font_override("font", Fonts.display())
	tagline.add_theme_font_size_override("font_size", 40)
	tagline.add_theme_color_override("font_color", Palette.TEXT)
	tagline.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tagline.add_theme_constant_override("shadow_offset_y", 3)
	tagline.size = Vector2(400, 50)
	tagline.position = Vector2(40, 280)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)

	for entry in CARDS:
		var card := DinoCard.create(DinoCatalog.load_default().find(entry[0]), DinoCard.Mode.FULL, null,
				entry[1], entry[2])
		card.inspect_on_hold = false
		card.position = entry[3] - card.size / 2
		card.rotation_degrees = entry[4]
		add_child(card)
