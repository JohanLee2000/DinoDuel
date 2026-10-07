class_name DinoDef
extends Resource
## Static definition of one dinosaur card. One .tres file per dino lives in res://data/dinos/
## and can be edited in the Godot inspector.

enum DinoType { LAND, SKY, SEA }
enum Era { TRIASSIC, JURASSIC, CRETACEOUS }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const TYPE_NAMES: Array[String] = ["Land", "Sky", "Sea"]
const ERA_NAMES: Array[String] = ["Triassic", "Jurassic", "Cretaceous"]
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

@export var id: StringName
@export var display_name: String
@export var dino_type: DinoType
@export var era: Era
@export var rarity: Rarity
@export_range(0, 30) var attack: int = 1
@export_range(0, 10) var defense: int = 0
@export_range(0, 20) var speed: int = 1
@export_range(1, 60) var health: int = 1
## Reserved for abilities; decided after the M1 playtest.
@export var ability_id: StringName
@export_multiline var flavor_text: String


func type_name() -> String:
	return TYPE_NAMES[dino_type]


func era_name() -> String:
	return ERA_NAMES[era]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


## Land beats Sky, Sky beats Sea, Sea beats Land.
static func type_beats(attacker: DinoType, defender: DinoType) -> bool:
	return (attacker + 1) % 3 == defender
