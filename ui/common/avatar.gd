class_name Avatar
extends RefCounted
## Round avatars for the Fossil Hunter ID (HunterId): a dino's painting (the top of its card art,
## Shiny if owned Shiny), a rival's head, or the Professaur's portrait, in a rimmed circle.


static func texture(avatar: String) -> Texture2D:
	if avatar.begins_with("rival:"):
		return RivalArt.head(StringName(avatar.trim_prefix("rival:")))
	if avatar.begins_with("dino:"):
		var dino := Session.catalog.find(StringName(avatar.trim_prefix("dino:")))
		if dino == null:
			return null
		var thumb := DinoArt.thumb(dino, Session.profile.is_shiny(dino.id))
		if thumb == null:
			return null
		# The paintings are tall (2:3): a square from their upper part, where the head usually is.
		var crop := AtlasTexture.new()
		crop.atlas = thumb
		var width := float(thumb.get_width())
		var side := width * 0.82
		crop.region = Rect2((width - side) / 2, thumb.get_height() * 0.1, side, side)
		return crop
	if ResourceLoader.exists(ProfessorTour.PORTRAIT_ART):
		return load(ProfessorTour.PORTRAIT_ART)
	return Icons.texture(&"professor", 128)


## The player's own avatar, `diameter` across.
static func of_player(diameter: float, rim := Palette.HIGHLIGHT) -> Control:
	return circle(texture(HunterId.avatar_of(Session.profile)), diameter, rim)


## A texture in a circle with a rim. Ignores input, so it can sit inside a button.
static func circle(art: Texture2D, diameter: float, rim_color: Color, rim_width := 3) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * diameter
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := Panel.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color("1b2a47")
	disc.set_corner_radius_all(int(diameter / 2))
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
	ring.set_corner_radius_all(int(diameter / 2))
	rim.add_theme_stylebox_override("panel", ring)
	rim.size = holder.custom_minimum_size
	holder.add_child(rim)
	for node in [holder, frame, face, rim]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder
