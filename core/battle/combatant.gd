class_name Combatant
extends RefCounted
## A dino's live state inside one battle. Stats include party bonuses.

var def: DinoDef
var attack: int
var defense: int
var speed: int
var max_health: int
var health: int
var braced_last_turn := false
## A boss's signature dino (RivalDef.alphas): extra Health and Attack, and a gold badge.
var alpha := false


static func from_def(dino: DinoDef, era_bond: bool, balanced: bool) -> Combatant:
	var c := Combatant.new()
	c.def = dino
	c.attack = dino.attack + (PartyRules.ERA_BOND_ATTACK if era_bond else 0)
	c.defense = dino.defense
	c.speed = dino.speed + (PartyRules.ERA_BOND_SPEED if era_bond else 0)
	c.max_health = dino.health + (PartyRules.BALANCED_HEALTH if balanced else 0)
	c.health = c.max_health
	return c


## Makes this an Alpha: BattleEngine.ALPHA_HEALTH_BONUS more Health (rounded up) and
## BattleEngine.ALPHA_ATTACK_BONUS more Attack.
func make_alpha() -> void:
	alpha = true
	attack += BattleEngine.ALPHA_ATTACK_BONUS
	max_health = ceili(max_health * (1.0 + BattleEngine.ALPHA_HEALTH_BONUS))
	health = max_health


func is_knocked_out() -> bool:
	return health <= 0


func clone() -> Combatant:
	var c := Combatant.new()
	c.def = def
	c.attack = attack
	c.defense = defense
	c.speed = speed
	c.max_health = max_health
	c.health = health
	c.braced_last_turn = braced_last_turn
	c.alpha = alpha
	return c
