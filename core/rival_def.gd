class_name RivalDef
extends Resource
## One Journey stage (Jo, 2026-10-15): who you battle, which 6 dinos they bring, and how their AI
## plays. Rory is one character with a stage per boss battle (see `character`).

## The Journey, in order: 5 rivals + Rory per era chapter, then the finale. Listed explicitly so
## exported Android builds always find them.
const ROSTER: Array[String] = [
	"res://data/rivals/rae.tres",
	"res://data/rivals/fern.tres",
	"res://data/rivals/cora.tres",
	"res://data/rivals/gus.tres",
	"res://data/rivals/dusty.tres",
	"res://data/rivals/rory_triassic.tres",
	"res://data/rivals/pip.tres",
	"res://data/rivals/marina.tres",
	"res://data/rivals/hank.tres",
	"res://data/rivals/sela.tres",
	"res://data/rivals/bo.tres",
	"res://data/rivals/rory_jurassic.tres",
	"res://data/rivals/tia.tres",
	"res://data/rivals/sully.tres",
	"res://data/rivals/della.tres",
	"res://data/rivals/vera.tres",
	"res://data/rivals/grit.tres",
	"res://data/rivals/rory_cretaceous.tres",
	"res://data/rivals/rory_finale.tres",
]

## Stage id: the key for the player's record and stars against this stage.
@export var id: StringName
@export var display_name: String
@export_multiline var intro: String
@export var brings: Array[DinoDef] = []
@export var point_cap := PartyRules.POINT_CAP

@export_group("Journey")
## 0 Triassic, 1 Jurassic, 2 Cretaceous, 3 the finale (Journey.CHAPTER_NAMES).
@export_range(0, 3) var chapter := 0
## The chapter's last stage: Rory, with an Alpha.
@export var is_boss := false
## Who this is, for the portrait (assets/rivals/<character>.webp); Rory's stages share one.
@export var character: StringName
## Dinos in `brings` that are Alphas: they always play, with extra Health and Attack.
@export var alphas: Array[StringName] = []
## The turn the meteor shower starts; 0 = the usual BattleEngine.METEOR_START_TURN.
@export var meteor_turn := 0

@export_group("Personality")
## Difficulty. Lower = plays its best-scoring move more often. Higher = more random.
@export_range(0.01, 1.0) var temperature := 0.05
@export var bite_bias := 0.0
@export var charge_bias := 0.0
@export var brace_bias := 0.0
@export var swap_bias := 0.0
## Conditional habits, ids from BattleAI.HABITS (e.g. brace_after_hit).
@export var habits: Array[StringName] = []
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
	ai.habits = habits.duplicate()
	ai.learns_habits = learns_habits
	return ai


## The 3 this rival fields (its Alphas always among them).
func pick_party(ai: BattleAI) -> Array[DinoDef]:
	return ai.choose_party(brings, point_cap, alphas)


## A battle against this stage, with its Alphas and meteor timing.
func start_battle(player_party: Array[DinoDef], rival_party: Array[DinoDef]) -> BattleState:
	return BattleEngine.create(player_party, rival_party, alphas, meteor_turn)
