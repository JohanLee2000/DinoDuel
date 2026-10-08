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


static func from_def(dino: DinoDef, era_bond: bool, balanced: bool) -> Combatant:
	var c := Combatant.new()
	c.def = dino
	c.attack = dino.attack + (PartyRules.ERA_BOND_ATTACK if era_bond else 0)
	c.defense = dino.defense
	c.speed = dino.speed + (PartyRules.ERA_BOND_SPEED if era_bond else 0)
	c.max_health = dino.health + (PartyRules.BALANCED_HEALTH if balanced else 0)
	c.health = c.max_health
	return c


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
	return c
