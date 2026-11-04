extends SceneTree
## Builds the 256 px dino avatar portraits in assets/dinos/avatars/ from the full paintings, framed
## like Avatar.portrait_box (keep the two in step). Rebuild after changing art or faces.json:
##   "$GODOT" --headless --path . --script res://tools/build_avatar_portraits.gd
## then --import, python tools/prepare_art.py --fix-imports (mipmaps), and --import again.
## Avatars are never Shiny, so Shiny paintings are skipped. See docs/AVATAR_PORTRAITS.md.

const SIZE := 256
## Lossy WebP: ~1/6 the size of lossless at this quality, and the game re-imports it lossy anyway.
const QUALITY := 0.9


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/dinos/avatars")
	var count := 0
	var faces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dinos/faces.json"))
	for file in DirAccess.get_files_at("res://assets/dinos"):
		if not file.ends_with(".webp") or file.get_basename().ends_with("_shiny"):
			continue
		var id := file.get_basename()
		# The full-size source file (the imported texture is limited to 768 px), read from disk.
		var painting := Image.load_from_file(ProjectSettings.globalize_path("res://assets/dinos/" + file))
		if painting == null:
			continue
		var face: Array = faces.get(id, [0.09, 0.15, 0.82])
		var span := minf(1.0, float(face[2]) * 1.65)
		var box := [clampf(float(face[0]) - (span - float(face[2])) * 0.5, 0.0, 1.0 - span),
			clampf(float(face[1]) - (span - float(face[2])) * 0.3, 0.0, 1.5 - span), span]
		var width := painting.get_width()
		var side := mini(int(float(box[2]) * width), mini(width, painting.get_height()))
		var rect := Rect2i(clampi(int(float(box[0]) * width), 0, width - side),
			clampi(int(float(box[1]) * width), 0, painting.get_height() - side), side, side)
		var portrait := painting.get_region(rect)
		portrait.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		if portrait.save_webp("res://assets/dinos/avatars/" + file, true, QUALITY) != OK:
			push_error("Couldn't save the portrait for " + id)
			quit(1)
			return
		count += 1
	print("Built %d avatar portraits" % count)
	quit()
