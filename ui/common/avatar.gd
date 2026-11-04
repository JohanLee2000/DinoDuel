class_name Avatar
extends RefCounted
## Avatars for the Fossil Hunter ID (HunterId). Dinos are rounded squares framed in their tier color
## (N grey ... UR pink), never Shiny (Jo, 2026-11-04); rivals and the Professaur are circles.
## Dino portraits are 256 px crops built by tools/build_avatar_portraits.gd (docs/AVATAR_PORTRAITS.md).

## Where each dino's face is in its painting: [x, y, size of a square] as fractions of the
## painting's width. Tune with tools/preview_faces.py.
const FACES := "res://assets/dinos/faces.json"
const PORTRAITS := "res://assets/dinos/avatars/%s.webp"

static var _faces := {}
static var _portraits := {}


static func texture(avatar: String) -> Texture2D:
	if avatar.begins_with("rival:"):
		return RivalArt.head(StringName(avatar.trim_prefix("rival:")))
	if avatar.begins_with("dino:"):
		var dino := Session.catalog.find(StringName(avatar.trim_prefix("dino:")))
		if dino == null:
			return null
		var path := PORTRAITS % dino.id
		if ResourceLoader.exists(path):
			if not _portraits.has(path):
				_portraits[path] = load(path)
			return _portraits[path]
		# New art without a built portrait: crop the card thumbnail the same way.
		var thumb := DinoArt.thumb(dino, false)
		return face_crop(thumb, portrait_box(dino.id)) if thumb else null
	if ResourceLoader.exists(ProfessorTour.PORTRAIT_ART):
		return load(ProfessorTour.PORTRAIT_ART)
	return Icons.texture(&"professor", 128)


## The face box for a dino, from faces.json. A dino without one (new art) gets a square from the
## upper middle of its painting, where heads usually are.
static func face_box(dino_id: StringName) -> Array:
	if _faces.is_empty() and ResourceLoader.exists(FACES):
		var json := load(FACES) as JSON
		if json and json.data is Dictionary:
			_faces = json.data
	return _faces.get(String(dino_id), [0.09, 0.15, 0.82])


## Wider framing retains necks, crests and shoulders; also used by the asset builder.
static func portrait_box(dino_id: StringName) -> Array:
	var box := face_box(dino_id)
	var side := minf(1.0, float(box[2]) * 1.65)
	return [clampf(float(box[0]) - (side - float(box[2])) * 0.5, 0.0, 1.0 - side),
		clampf(float(box[1]) - (side - float(box[2])) * 0.3, 0.0, 1.5 - side), side]


## "Tyrannosaurus Rex", "Captain Cora", "The Professaur".
static func display_name(avatar: String) -> String:
	if avatar.begins_with("dino:"):
		var dino := Session.catalog.find(StringName(avatar.trim_prefix("dino:")))
		return dino.display_name if dino else "Dinosaur"
	if avatar.begins_with("rival:"):
		return HunterId.rival_name(avatar.trim_prefix("rival:"))
	return "The Professaur"


## The frame color: a dino's tier color, `other` for rivals and the Professaur.
static func rim_color(avatar: String, other := Palette.HIGHLIGHT) -> Color:
	if avatar.begins_with("dino:"):
		var dino := Session.catalog.find(StringName(avatar.trim_prefix("dino:")))
		if dino:
			return Palette.RARITY_COLORS[dino.rarity]
	return other


## Any avatar, `diameter` across: a dino in a rounded square framed in its tier color, a person
## in a circle with an `other_rim` frame. `silhouette` draws a locked rival as a dark shape.
static func portrait(avatar: String, diameter: float, other_rim := Palette.HIGHLIGHT, rim_width := 3,
		silhouette := false) -> Control:
	var art := circle(texture(avatar), diameter, rim_color(avatar, other_rim), rim_width, avatar.begins_with("dino:"))
	if silhouette:
		# A dark shape on a lighter disc: modulate only darkens, so lighten what's behind it (the
		# clipping disc doesn't draw itself unless told to).
		var frame := art.get_child(0) as Panel
		var disc := (frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		disc.bg_color = Color("3a4a68")
		frame.add_theme_stylebox_override("panel", disc)
		frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		(frame.get_child(0) as CanvasItem).modulate = Color(0.07, 0.09, 0.15)
	return art


## The square `box` ([x, y, size] as fractions of the width) of a painting.
static func face_crop(painting: Texture2D, box: Array) -> Texture2D:
	var crop := AtlasTexture.new()
	crop.atlas = painting
	var width := float(painting.get_width())
	var side := clampf(box[2], 0.05, 1.0) * width
	var x := clampf(box[0] * width, 0.0, width - side)
	var y := clampf(box[1] * width, 0.0, painting.get_height() - side)
	crop.region = Rect2(x, y, side, side)
	return crop


## The player's own avatar, `diameter` across.
static func of_player(diameter: float, rim := Palette.HIGHLIGHT, rim_width := 3) -> Control:
	return portrait(HunterId.avatar_of(Session.profile), diameter, rim, rim_width)


## Corner rounding of a dino's rounded square, `diameter` across.
static func corner_radius(diameter: float, rounded_square: bool) -> int:
	return int(diameter * 0.18) if rounded_square else int(diameter / 2)


## A texture in a circle (or rounded square) with a rim. Ignores input, so it can sit inside a button.
static func circle(art: Texture2D, diameter: float, rim_color: Color, rim_width := 3, rounded_square := false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * diameter
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := Panel.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color("1b2a47")
	disc.set_corner_radius_all(corner_radius(diameter, rounded_square))
	frame.add_theme_stylebox_override("panel", disc)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.size = holder.custom_minimum_size
	var face := TextureRect.new()
	face.texture = art
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(face)
	holder.add_child(frame)
	var rim := Panel.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = rim_color
	ring.set_border_width_all(rim_width)
	ring.set_corner_radius_all(corner_radius(diameter, rounded_square))
	rim.add_theme_stylebox_override("panel", ring)
	rim.size = holder.custom_minimum_size
	holder.add_child(rim)
	for node in [holder, frame, face, rim]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder
