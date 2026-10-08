class_name RivalDef
extends Resource
## A journey opponent: who they are, which 6 dinos they bring, and how their AI tends to play.

@export var id: StringName
@export var display_name: String
@export_multiline var intro: String
@export var brings: Array[DinoDef] = []
@export var point_cap := PartyRules.POINT_CAP

@export_group("Personality")
## Difficulty. Lower = plays its best-scoring move more often. Higher = more random.
@export_range(0.01, 1.0) var temperature := 0.05
@export var bite_bias := 0.0
@export var charge_bias := 0.0
@export var brace_bias := 0.0
@export var swap_bias := 0.0


func make_ai(seed_value: int) -> BattleAI:
	var ai := BattleAI.new(seed_value)
	ai.temperature = temperature
	ai.biases = [bite_bias, charge_bias, brace_bias, swap_bias]
	return ai
