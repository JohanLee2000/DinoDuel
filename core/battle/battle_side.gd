class_name BattleSide
extends RefCounted
## One player's party in a battle: the active dino plus the bench.

var party: Array[Combatant] = []
var active := 0
var era_bond := false
var balanced := false


static func from_party(defs: Array[DinoDef]) -> BattleSide:
	var side := BattleSide.new()
	side.era_bond = PartyRules.has_era_bond(defs)
	side.balanced = PartyRules.is_balanced(defs)
	for dino in defs:
		side.party.append(Combatant.from_def(dino, side.era_bond, side.balanced))
	return side


func active_dino() -> Combatant:
	return party[active]


## Indices of benched dinos that can still fight.
func bench() -> Array[int]:
	var result: Array[int] = []
	for i in party.size():
		if i != active and not party[i].is_knocked_out():
			result.append(i)
	return result


func is_defeated() -> bool:
	for dino in party:
		if not dino.is_knocked_out():
			return false
	return true


func needs_replacement() -> bool:
	return active_dino().is_knocked_out() and not is_defeated()


func clone() -> BattleSide:
	var side := BattleSide.new()
	for dino in party:
		side.party.append(dino.clone())
	side.active = active
	side.era_bond = era_bond
	side.balanced = balanced
	return side
