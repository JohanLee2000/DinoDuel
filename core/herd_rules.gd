class_name HerdRules
extends RefCounted
## Rules for building a herd: size, point cap, and herd-wide bonuses.

const HERD_SIZE := 3
const BRING_SIZE := 6
const POINT_CAP := 9
## Herd Points per rarity, indexed by DinoDef.Rarity.
const RARITY_POINTS: Array[int] = [1, 2, 3, 4, 5]

const ERA_BOND_ATTACK := 1
const ERA_BOND_SPEED := 1
const BALANCED_HEALTH := 2


static func points_of(dino: DinoDef) -> int:
	return RARITY_POINTS[dino.rarity]


static func points(herd: Array[DinoDef]) -> int:
	var total := 0
	for dino in herd:
		total += points_of(dino)
	return total


## Returns "" when the herd is legal, otherwise a short reason to show the player.
static func validate(herd: Array[DinoDef], cap: int = POINT_CAP) -> String:
	if herd.size() != HERD_SIZE:
		return "Pick %d dinos" % HERD_SIZE
	var ids := {}
	for dino in herd:
		if ids.has(dino.id):
			return "No duplicates in a herd"
		ids[dino.id] = true
	if points(herd) > cap:
		return "Over the %d-point cap" % cap
	return ""


## All dinos from the same era.
static func has_era_bond(herd: Array[DinoDef]) -> bool:
	if herd.size() != HERD_SIZE:
		return false
	for dino in herd:
		if dino.era != herd[0].era:
			return false
	return true


## One Land, one Sky, one Sea.
static func is_balanced(herd: Array[DinoDef]) -> bool:
	if herd.size() != HERD_SIZE:
		return false
	var seen := {}
	for dino in herd:
		seen[dino.dino_type] = true
	return seen.size() == 3
