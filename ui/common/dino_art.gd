class_name DinoArt
extends RefCounted
## Finds a dino's painting by file name, so new art only needs to be dropped into the folder
## (tools/prepare_art.py does this; see docs/ART_BRIEF.md):
##   res://assets/dinos/<id>.webp        the card painting (2:3 portrait)
##   res://assets/dinos/<id>_shiny.webp  Shiny version (alternate coloring); falls back to <id>
## .png and .jpg work too. With no file, cards show a placeholder backdrop and silhouette.
##
## Small cards use a 360 px thumbnail from res://assets/dinos/thumbs/ instead (written by
## tools/prepare_art.py). Decoding the full 1000x1500 paintings made tabs full of cards take most
## of a second to open (2026-10-09); thumbnails load ~8x faster and stay in memory once loaded
## (45 of them is ~45 MB, versus ~270 MB for the full paintings the Dex used to hold).

const FOLDER := "res://assets/dinos/"
const THUMB_FOLDER := "res://assets/dinos/thumbs/"
## Cards up to this wide (game units; the screen is 720 wide) use the thumbnail.
const THUMB_MAX_WIDTH := 270.0

static var _thumbs := {}
## Dev: `--no-thumbs` turns thumbnails off, to measure the difference.
static var use_thumbs := true


static func full(dino: DinoDef, shiny: bool) -> Texture2D:
	if dino.art and not shiny:
		return dino.art
	if shiny:
		var shiny_art := _load("%s_shiny" % dino.id)
		if shiny_art:
			return shiny_art
	return dino.art if dino.art else _load(dino.id)


## The painting to show on a card `width` units wide.
static func for_card(dino: DinoDef, shiny: bool, width: float) -> Texture2D:
	if use_thumbs and width <= THUMB_MAX_WIDTH and not dino.art:
		var small := thumb(dino, shiny)
		if small:
			return small
	return full(dino, shiny)


static func thumb(dino: DinoDef, shiny: bool) -> Texture2D:
	var file_name := String(dino.id)
	if shiny and ResourceLoader.exists(THUMB_FOLDER + file_name + "_shiny.webp"):
		file_name += "_shiny"
	if _thumbs.has(file_name):
		return _thumbs[file_name]
	var path := THUMB_FOLDER + file_name + ".webp"
	var texture: Texture2D = null
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
		texture = ResourceLoader.load_threaded_get(path)
	elif ResourceLoader.exists(path):
		texture = load(path)
	_thumbs[file_name] = texture
	return texture


## Starts loading every thumbnail on background threads, so the first tabs open fast.
static func warm_up(catalog: DinoCatalog) -> void:
	for dino in catalog.dinos:
		var path := THUMB_FOLDER + "%s.webp" % dino.id
		if not _thumbs.has(String(dino.id)) and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


static func _load(file_name: String) -> Texture2D:
	for ext in [".webp", ".png", ".jpg"]:
		var path: String = FOLDER + file_name + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null
