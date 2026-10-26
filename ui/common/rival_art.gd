class_name RivalArt
extends RefCounted
## Rival sprites (Jo's pixel art, docs/JOURNEY_ART.md): res://assets/rivals/<character>.webp, made
## by tools/prepare_sprites.py, which also writes heads.json: where each head is, as fractions of
## the sprite [x, y, size of a square], for the round Journey map markers.

const FOLDER := "res://assets/rivals/"
const HEADS := "res://assets/rivals/heads.json"

static var _sprites := {}
static var _heads := {}
static var _head_boxes := {}


## The full sprite, or null if there's no art for `character` yet.
static func sprite(character: StringName) -> Texture2D:
	if not _sprites.has(character):
		var path := FOLDER + "%s.webp" % character
		_sprites[character] = load(path) if ResourceLoader.exists(path) else null
	return _sprites[character]


## The head-and-shoulders crop of the sprite (for round markers), or null.
static func head(character: StringName) -> Texture2D:
	if _heads.has(character):
		return _heads[character]
	var full := sprite(character)
	var crop: Texture2D = null
	if full:
		var box: Array = _boxes().get(String(character), [0.3, 0.0, 0.34])
		var atlas := AtlasTexture.new()
		atlas.atlas = full
		var w := float(full.get_width())
		atlas.region = Rect2(box[0] * w, box[1] * w, box[2] * w, box[2] * w)
		crop = atlas
	_heads[character] = crop
	return crop


## The round-marker face for a rival: its head crop, or for a friend's party (no sprite) the
## painting of the first dino they bring.
static func face(rival: RivalDef) -> Texture2D:
	var crop := head(rival.character) if rival.character != &"" else null
	if crop == null and not rival.brings.is_empty():
		return DinoArt.thumb(rival.brings[0], false)
	return crop


static func _boxes() -> Dictionary:
	if _head_boxes.is_empty() and ResourceLoader.exists(HEADS):
		var json := load(HEADS) as JSON
		if json and json.data is Dictionary:
			_head_boxes = json.data
	return _head_boxes
