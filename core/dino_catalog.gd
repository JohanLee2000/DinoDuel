class_name DinoCatalog
extends Resource
## Every dino in the game. Listing them explicitly (instead of scanning the folder) keeps
## loading reliable in exported Android builds, where resource files get remapped.

const PATH := "res://data/dino_catalog.tres"

@export var dinos: Array[DinoDef] = []

static var _default: DinoCatalog


static func load_default() -> DinoCatalog:
	if _default == null:
		_default = load(PATH) as DinoCatalog
	return _default


func find(id: StringName) -> DinoDef:
	for dino in dinos:
		if dino.id == id:
			return dino
	return null


## The dino's collector number in the set, starting at 1 (shown as "005/015" on cards).
func number_of(dino: DinoDef) -> int:
	for i in dinos.size():
		if dinos[i].id == dino.id:
			return i + 1
	return 0
