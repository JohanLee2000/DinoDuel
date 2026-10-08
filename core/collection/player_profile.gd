class_name PlayerProfile
extends RefCounted
## Everything that's saved about the player: collection, Amber, eggs, party lineup, Dex, stats.
## Pure data + rules; reading and writing the file lives in app/save_store.gd.
##
## Egg results come from an RNG whose state is saved, so closing the app mid-hatch and
## reopening it can't reroll a clutch.

const SAVE_VERSION := 1

## id -> true if the copy you own is Shiny.
var owned: Dictionary = {}
## Ids met in battle but not owned yet; the Dex shows these with their names.
var seen: Dictionary = {}
var amber := 0
var clutches := 0
## The 6 dinos you bring to battles.
var lineup: Array[StringName] = []
var clutches_without_epic := 0
var last_daily_day := -1
var wins := 0
var losses := 0
var eggs_hatched := 0
var _rng := RandomNumberGenerator.new()


static func new_game(seed_value: int) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile._rng.seed = seed_value
	for id in Economy.STARTER_DINOS:
		profile.owned[id] = false
	profile.lineup.assign(Economy.STARTER_DINOS)
	profile.clutches = Economy.STARTER_CLUTCHES
	return profile


# --- Collection -----------------------------------------------------------------------------

func owns(id: StringName) -> bool:
	return owned.has(id)


func is_shiny(id: StringName) -> bool:
	return owned.get(id, false)


func mark_seen(id: StringName) -> void:
	if not owns(id):
		seen[id] = true


## Adds a dino. Duplicates melt into Amber; a Shiny duplicate upgrades a non-Shiny copy instead.
func add_dino(dino: DinoDef, shiny: bool) -> HatchResult:
	var result := HatchResult.new()
	result.dino = dino
	result.shiny = shiny
	if not owns(dino.id):
		result.is_new = true
		owned[dino.id] = shiny
		seen.erase(dino.id)
	elif shiny and not is_shiny(dino.id):
		result.upgraded_to_shiny = true
		owned[dino.id] = true
	else:
		result.amber = Economy.MELT_VALUE[dino.rarity]
		amber += result.amber
	return result


## Development helper: owns every dino in the catalog (keeps existing Shiny copies).
func unlock_all(catalog: DinoCatalog) -> void:
	for dino in catalog.dinos:
		if not owns(dino.id):
			owned[dino.id] = false
		seen.erase(dino.id)


func can_craft(dino: DinoDef) -> bool:
	return not owns(dino.id) and amber >= Economy.CRAFT_COST[dino.rarity]


func craft(dino: DinoDef) -> HatchResult:
	if not can_craft(dino):
		return null
	amber -= Economy.CRAFT_COST[dino.rarity]
	return add_dino(dino, false)


# --- Eggs -----------------------------------------------------------------------------------

## Opens one clutch. Returns an empty array if there are no clutches to open.
func hatch_clutch(catalog: DinoCatalog) -> Array[HatchResult]:
	var results: Array[HatchResult] = []
	if clutches <= 0:
		return results
	clutches -= 1
	var rarities: Array[int] = []
	for i in Economy.EGGS_PER_CLUTCH:
		rarities.append(_roll(Economy.RARITY_ODDS))
	var has_epic := rarities.any(func(r: int) -> bool: return r >= DinoDef.Rarity.EPIC)
	if not has_epic and clutches_without_epic >= Economy.PITY_CLUTCHES - 1:
		rarities[rarities.size() - 1] = _roll(Economy.PITY_ODDS)
		has_epic = true
	clutches_without_epic = 0 if has_epic else clutches_without_epic + 1

	for rarity in rarities:
		var dino := _pick_dino(catalog, rarity)
		results.append(add_dino(dino, _rng.randf() < Economy.SHINY_ODDS))
		eggs_hatched += 1
	return results


func buy_clutch() -> bool:
	if amber < Economy.CLUTCH_PRICE:
		return false
	amber -= Economy.CLUTCH_PRICE
	clutches += 1
	return true


## `today` is a day number (see SaveStore.today()). One free clutch per calendar day.
func can_claim_daily(today: int) -> bool:
	return today != last_daily_day


func claim_daily(today: int) -> bool:
	if not can_claim_daily(today):
		return false
	last_daily_day = today
	clutches += Economy.DAILY_CLUTCHES
	return true


func _roll(odds: Array[float]) -> int:
	var roll := _rng.randf()
	for rarity in odds.size():
		roll -= odds[rarity]
		if roll < 0.0:
			return rarity
	return odds.size() - 1


## A random dino of that rarity, falling back to the next rarity down if the set has none.
func _pick_dino(catalog: DinoCatalog, rarity: int) -> DinoDef:
	for r in range(rarity, -1, -1):
		var pool := catalog.dinos.filter(func(d: DinoDef) -> bool: return d.rarity == r)
		if not pool.is_empty():
			return pool[_rng.randi_range(0, pool.size() - 1)]
	return catalog.dinos[0]


# --- Party and battles -----------------------------------------------------------------------

## Returns "" if the lineup was set, otherwise why not.
func set_lineup(ids: Array[StringName]) -> String:
	if ids.size() > PartyRules.BRING_SIZE:
		return "Bring at most %d" % PartyRules.BRING_SIZE
	var unique := {}
	for id in ids:
		if not owns(id):
			return "You don't own %s" % id
		if unique.has(id):
			return "No duplicates"
		unique[id] = true
	lineup = ids.duplicate()
	return ""


func lineup_defs(catalog: DinoCatalog) -> Array[DinoDef]:
	var defs: Array[DinoDef] = []
	for id in lineup:
		var dino := catalog.find(id)
		if dino:
			defs.append(dino)
	return defs


## Applies battle rewards and returns what was given: {"amber": int, "clutches": int}.
func record_battle(won: bool) -> Dictionary:
	var reward := {"amber": Economy.LOSS_AMBER, "clutches": 0}
	if won:
		wins += 1
		reward = {"amber": Economy.WIN_AMBER, "clutches": Economy.WIN_CLUTCHES}
	else:
		losses += 1
	amber += reward["amber"]
	clutches += reward["clutches"]
	return reward


# --- Saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"owned": owned.duplicate(),
		"seen": seen.keys(),
		"amber": amber,
		"clutches": clutches,
		"lineup": lineup.duplicate(),
		"clutches_without_epic": clutches_without_epic,
		"last_daily_day": last_daily_day,
		"wins": wins,
		"losses": losses,
		"eggs_hatched": eggs_hatched,
		# Strings, because JSON numbers are doubles and would round 64-bit RNG values.
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
	}


## Rebuilds a profile from saved data. Unknown dino ids (e.g. removed from the game) are dropped
## and missing fields fall back to defaults, so old or hand-edited saves still load.
static func from_dict(data: Dictionary, catalog: DinoCatalog) -> PlayerProfile:
	var profile := PlayerProfile.new()
	var owned_data: Dictionary = data.get("owned", {})
	for key in owned_data:
		var id := StringName(key)
		if catalog.find(id):
			profile.owned[id] = bool(owned_data[key])
	for key in data.get("seen", []):
		var id := StringName(key)
		if catalog.find(id) and not profile.owns(id):
			profile.seen[id] = true
	profile.amber = maxi(0, int(data.get("amber", 0)))
	profile.clutches = maxi(0, int(data.get("clutches", 0)))
	var lineup_ids: Array[StringName] = []
	for key in data.get("lineup", []):
		var id := StringName(key)
		if profile.owns(id) and not id in lineup_ids:
			lineup_ids.append(id)
	profile.lineup.assign(lineup_ids.slice(0, PartyRules.BRING_SIZE))
	profile.clutches_without_epic = int(data.get("clutches_without_epic", 0))
	profile.last_daily_day = int(data.get("last_daily_day", -1))
	profile.wins = int(data.get("wins", 0))
	profile.losses = int(data.get("losses", 0))
	profile.eggs_hatched = int(data.get("eggs_hatched", 0))
	profile._rng.seed = String(data.get("rng_seed", "0")).to_int()
	profile._rng.state = String(data.get("rng_state", "0")).to_int()
	return profile
