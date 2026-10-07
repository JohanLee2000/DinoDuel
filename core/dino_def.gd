class_name DinoDef
extends Resource
## Static definition of one dinosaur card. One .tres file per dino lives in res://data/dinos/
## and can be edited in the Godot inspector.

enum DinoType { LAND, SKY, SEA }
enum Era { TRIASSIC, JURASSIC, CRETACEOUS }
## Tiers N, R, SR, SSR, UR. Values are stored in the .tres files, so only append new ones.
enum Rarity { COMMON, RARE, SUPER_RARE, EPIC, LEGENDARY }

const TYPE_NAMES: Array[String] = ["Land", "Sky", "Sea"]
const ERA_NAMES: Array[String] = ["Triassic", "Jurassic", "Cretaceous"]
const RARITY_NAMES: Array[String] = ["Common", "Rare", "Super Rare", "Epic", "Legendary"]
## Short tier codes shown on the card crest.
const RARITY_CODES: Array[String] = ["N", "R", "SR", "SSR", "UR"]

@export var id: StringName
@export var display_name: String
## Short title under the name on the card, e.g. "King of the Cretaceous".
@export var epithet: String
@export var dino_type: DinoType
@export var era: Era
@export var rarity: Rarity
@export_range(0, 30) var attack: int = 1
@export_range(0, 10) var defense: int = 0
@export_range(0, 20) var speed: int = 1
@export_range(1, 60) var health: int = 1
## What kind of animal it is, e.g. "Tyrannosaur dinosaur" or "Marine reptile (pliosaur)".
@export var group: String
## Size line for the card's info strip, e.g. "Length 12 m · 8 t".
@export var size_text: String
## Card art. Leave empty to use res://assets/dinos/<id>.png (see DinoArt), or a placeholder.
@export var art: Texture2D
## Reserved for abilities; decided after the M1 playtest.
@export var ability_id: StringName
## A real fact about the animal, shown as the card's flavor text.
@export_multiline var flavor_text: String


func type_name() -> String:
	return TYPE_NAMES[dino_type]


func era_name() -> String:
	return ERA_NAMES[era]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func rarity_code() -> String:
	return RARITY_CODES[rarity]


## Land beats Sky, Sky beats Sea, Sea beats Land.
static func type_beats(attacker: DinoType, defender: DinoType) -> bool:
	return (attacker + 1) % 3 == defender
