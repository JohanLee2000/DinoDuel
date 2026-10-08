class_name RivalDef
extends Resource
## A journey opponent: who they are, which 6 dinos they bring, and how their AI tends to play.

## Every rival, easiest first. Listed explicitly so exported Android builds always find them.
const ROSTER: Array[String] = [
	"res://data/rivals/rae.tres",
	"res://data/rivals/fern.tres",
	"res://data/rivals/cora.tres",
	"res://data/rivals/dusty.tres",
	"res://data/rivals/rory.tres",
]

@export var id: StringName
@export var display_name: String
@export_multiline var intro: String
@export var brings: Array[DinoDef] = []
@export var point_cap := PartyRules.POINT_CAP
## Shown as stars on the Battle tab (1 = beginner, 5 = hardest).
@export_range(1, 5) var difficulty := 1

@export_group("Personality")
## Difficulty. Lower = plays its best-scoring move more often. Higher = more random.
@export_range(0.01, 1.0) var temperature := 0.05
@export var bite_bias := 0.0
@export var charge_bias := 0.0
@export var brace_bias := 0.0
@export var swap_bias := 0.0
## Adapts to the player's habits. Turned off for easy rivals.
@export var learns_habits := true


static func load_roster() -> Array[RivalDef]:
	var rivals: Array[RivalDef] = []
	for path in ROSTER:
		rivals.append(load(path) as RivalDef)
	return rivals


func make_ai(seed_value: int) -> BattleAI:
	var ai := BattleAI.new(seed_value)
	ai.temperature = temperature
	ai.biases = [bite_bias, charge_bias, brace_bias, swap_bias]
	ai.learns_habits = learns_habits
	return ai
