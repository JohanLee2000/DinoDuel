class_name ShareCard
extends RefCounted
## "Share a pull": draws a 1080x1350 picture of a dino card (the real card, over its type's battle
## backdrop with rays in its rarity color, the logo, a headline and who hatched it), saves it, and
## opens the share sheet with a line of text (app/share.gd).

const SIZE := Vector2i(1080, 1350)
const PATH := "user://share/dino_duel_pull.png"
const CARD_WIDTH := 560.0
const LINK := "https://johanlee2000.github.io/DinoDuel/"
const BACKDROPS := ["res://assets/battle/land.webp", "res://assets/battle/sky.webp", "res://assets/battle/sea.webp"]


## Renders and shares. `hatched`: just came out of an egg (vs shown off from the Dex).
static func share_dino(dino: DinoDef, shiny: bool, hatched: bool) -> void:
	var path := await render(dino, shiny, hatched)
	Share.image(path, message(dino, shiny, hatched))


static func message(dino: DinoDef, shiny: bool, hatched: bool) -> String:
	var kind := ("Shiny " if shiny else "") + dino.rarity_name()
	if hatched:
		var article := "an" if kind.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
		return "I just hatched %s %s %s in Dino Duel! 🦖\n%s" % [article, kind, dino.display_name, LINK]
	return "Check out my %s %s in Dino Duel! 🦖\n%s" % [kind, dino.display_name, LINK]


static func render(dino: DinoDef, shiny: bool, hatched: bool) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Control.new()
	root.size = Vector2(SIZE)
	viewport.add_child(root)
	# Deferred, so this also works if it's called while the scene tree is busy adding nodes.
	tree.root.add_child.call_deferred(viewport)
	await tree.process_frame
	_compose(root, dino, shiny, hatched)
	# A few frames so the card's shaders and text settle before the picture is taken.
	for i in 4:
		await tree.process_frame
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	image.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	image.save_png(PATH)
	return PATH


static func _compose(root: Control, dino: DinoDef, shiny: bool, hatched: bool) -> void:
	var size := Vector2(SIZE)
	var color := Palette.RARITY_COLORS[dino.rarity]
	var base := ColorRect.new()
	base.color = Palette.BACKGROUND
	base.size = size
	root.add_child(base)
	var backdrop := TextureRect.new()
	backdrop.texture = load(BACKDROPS[dino.dino_type])
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size = size
	backdrop.modulate = Color(0.5, 0.5, 0.55)
	root.add_child(backdrop)

	var card := DinoCard.create(dino, DinoCard.Mode.LARGE, null, shiny, CARD_WIDTH)
	card.inspect_on_hold = false
	var card_top := 280.0
	var fx := RevealFx.create(dino.rarity, false)
	fx.size = Vector2.ONE * 1300
	fx.position = Vector2(size.x / 2, card_top + card.size.y / 2) - fx.size / 2
	root.add_child(fx)
	card.position = Vector2((size.x - card.size.x) / 2, card_top)
	root.add_child(card)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(520, 520 * 200.0 / 758.0)
	logo.position = Vector2((size.x - logo.size.x) / 2, 36)
	root.add_child(logo)

	var headline := ("SHINY " if shiny else "") + "%s %s%s" % [dino.rarity_code(), dino.rarity_name(), " PULL!" if hatched else ""]
	_text(root, headline.to_upper(), 54, color.lightened(0.25), 196, Fonts.title())
	var who := Session.profile.player_name if Session.profile.player_name != "" else "a fossil hunter"
	_text(root, "%s by %s" % ["Hatched" if hatched else "Collected", who], 34, Palette.TEXT, card_top + card.size.y + 22, Fonts.bold())
	_text(root, "Hatch. Collect. Battle.", 26, Palette.TEXT_DIM, size.y - 52, Fonts.body())


static func _text(root: Control, text: String, font_size: int, color: Color, y: float, font: Font) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 10)
	label.size = Vector2(root.size.x, font_size * 1.4)
	label.position = Vector2(0, y)
	root.add_child(label)
