class_name DinoCatalog
extends Resource
## Every dino in the game. Listing them explicitly (instead of scanning the folder) keeps
## loading reliable in exported Android builds, where resource files get remapped.

const PATH := "res://data/dino_catalog.tres"

@export var dinos: Array[DinoDef] = []


static func load_default() -> DinoCatalog:
	return load(PATH) as DinoCatalog


func find(id: StringName) -> DinoDef:
	for dino in dinos:
		if dino.id == id:
			return dino
	return null
