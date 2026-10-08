class_name PartyRules
extends RefCounted
## Rules for building a party: size, point cap, and party-wide bonuses.

const PARTY_SIZE := 3
const BRING_SIZE := 6
const POINT_CAP := 9
## Party Points per rarity, indexed by DinoDef.Rarity.
const RARITY_POINTS: Array[int] = [1, 2, 3, 4, 5]

const ERA_BOND_ATTACK := 1
const ERA_BOND_SPEED := 1
const BALANCED_HEALTH := 2


static func points_of(dino: DinoDef) -> int:
	return RARITY_POINTS[dino.rarity]


static func points(party: Array[DinoDef]) -> int:
	var total := 0
	for dino in party:
		total += points_of(dino)
	return total


## Returns "" when the party is legal, otherwise a short reason to show the player.
static func validate(party: Array[DinoDef], cap: int = POINT_CAP) -> String:
	if party.size() != PARTY_SIZE:
		return "Pick %d dinos" % PARTY_SIZE
	var ids := {}
	for dino in party:
		if ids.has(dino.id):
			return "No duplicates in a party"
		ids[dino.id] = true
	if points(party) > cap:
		return "Over the %d-point cap" % cap
	return ""


## True if some PARTY_SIZE of the brought dinos fit under the cap, i.e. the cheapest ones do.
## With expensive tiers in the set, a lineup of 6 can otherwise be impossible to battle with.
static func has_valid_pick(brought: Array[DinoDef], cap: int = POINT_CAP) -> bool:
	if brought.size() < PARTY_SIZE:
		return false
	var costs: Array[int] = []
	for dino in brought:
		costs.append(points_of(dino))
	costs.sort()
	return costs[0] + costs[1] + costs[2] <= cap


## All dinos from the same era.
static func has_era_bond(party: Array[DinoDef]) -> bool:
	if party.size() != PARTY_SIZE:
		return false
	for dino in party:
		if dino.era != party[0].era:
			return false
	return true


## One Land, one Sky, one Sea.
static func is_balanced(party: Array[DinoDef]) -> bool:
	if party.size() != PARTY_SIZE:
		return false
	var seen := {}
	for dino in party:
		seen[dino.dino_type] = true
	return seen.size() == 3
