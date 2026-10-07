class_name DinoArt
extends RefCounted
## Finds a dino's painting by file name, so new art only needs to be dropped into the folder
## (tools/prepare_art.py does this; see docs/ART_BRIEF.md):
##   res://assets/dinos/<id>.webp        the card painting (2:3 portrait)
##   res://assets/dinos/<id>_shiny.webp  Shiny version (alternate coloring); falls back to <id>
## .png and .jpg work too. With no file, cards show a placeholder backdrop and silhouette.

const FOLDER := "res://assets/dinos/"


static func full(dino: DinoDef, shiny: bool) -> Texture2D:
	if dino.art and not shiny:
		return dino.art
	if shiny:
		var shiny_art := _load("%s_shiny" % dino.id)
		if shiny_art:
			return shiny_art
	return dino.art if dino.art else _load(dino.id)


static func _load(file_name: String) -> Texture2D:
	for ext in [".webp", ".png", ".jpg"]:
		var path: String = FOLDER + file_name + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null
