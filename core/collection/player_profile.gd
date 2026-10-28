class_name PlayerProfile
extends RefCounted
## Everything that's saved about the player: collection, Amber, eggs, party lineup, Dex, stats.
## Pure data + rules; reading and writing the file lives in app/save_store.gd.
##
## Egg results come from an RNG whose state is saved, so closing the app mid-hatch and
## reopening it can't reroll a clutch.

const SAVE_VERSION := 1
const HATCH_HISTORY_SIZE := 50
## Saved party slots (Jo, 2026-10-16): Party 1 / 2 / 3, each a lineup of 6 with a name.
const PARTY_SLOTS := 3
const PARTY_NAME_MAX_LENGTH := 16
## How many friends (party codes) the friends list keeps.
const FRIENDS_MAX := 30

## id -> true if the copy you own is Shiny.
var owned: Dictionary = {}
## Ids met in battle but not owned yet; the Dex shows these with their names.
var seen: Dictionary = {}
var amber := 0
var clutches := 0
## Rare clutches (Economy.RARE_CLUTCH_ODDS), hatched the same way as normal ones.
var rare_clutches := 0
## The 6 dinos you bring to battles: the open party slot's lineup.
var lineup: Array[StringName] = []
## The party slots: {name, lineup}. The open one's lineup is `lineup` (written back on a switch and
## when saving), so everything else can keep using `lineup`.
var parties: Array[Dictionary] = []
var party_slot := 0
## Dinos collected but not looked at yet (a small dot on their cards in the Dex and Party tabs).
var new_dinos: Dictionary = {}
## Dino mastery (Mastery): id -> {battles, wins, counters, bosses}.
var mastery: Dictionary = {}
## Friends whose party codes you've dueled, most recent first: {code, player, party, wins, losses}.
var friends: Array[Dictionary] = []
## The version whose What's new the player last saw (WhatsNew); "" for saves from before it.
var whats_new_seen := ""
## Google Play's rating card (ReviewPrompt): how many times the game asked, and the last day.
var review_asks := 0
var review_asked_day := -1
var clutches_without_epic := 0
var last_daily_day := -1
## Daily check-in streak: which of the 7 days (0-6) the next check-in is.
var checkin_day := 0
var wins := 0
var losses := 0
## Per rival (Journey stage): stage id -> [wins, losses].
var rival_record: Dictionary = {}
## The Journey: stage id (String) -> best stars (1-3). A stage is cleared once it's in here.
var journey_stars: Dictionary = {}
var eggs_hatched := 0
## The last HATCH_HISTORY_SIZE clutches hatched, newest first (Eggs tab > Hatch history, 2026-10-16):
## {time (Unix seconds, 0 if unknown), rare, eggs: [{id, shiny, new, upgraded, amber}]}.
var hatch_history: Array[Dictionary] = []
## The first battle comes with a coach (see BattleScreen); this flips once it's been played.
var tutorial_done := false
## New games start by picking a partner (Economy.STARTER_PARTNERS); saves from before that have
## their 6 starters already, so they count as chosen.
var partner_chosen := false
var partner: StringName = &""
## What the player asked to be called (entered before the story intro; used by the Professaur).
var player_name := ""
const NAME_MAX_LENGTH := 16
## The Professaur has shown a new player around the tabs (old saves count as shown).
var tour_done := false
## The new-player "First steps" checklist is showing (new games only; off once its reward is claimed).
var first_steps_active := false
## First steps that can't be read from the rest of the save.
var opened_dex_card := false
## Goals (core/collection/goals.gd): counters for achievements, today's quests, and what's claimed.
var stats: Dictionary = {}
var quest_day := -1
## Each: {"id": String, "progress": int, "claimed": bool}.
var quests: Array = []
var quest_bonus_claimed := false
var claimed_goals: Dictionary = {}
## A battle in progress, so it can continue if Android closes the game (see BattleReplay); empty
## when not in a battle. Keys: rival, seed, player, rival_party (dino ids), coaching, events.
var battle: Dictionary = {}
var _rng := RandomNumberGenerator.new()


static func new_game(seed_value: int) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile._rng.seed = seed_value
	for id in Economy.STARTER_BASICS:
		profile.owned[id] = false
	profile.lineup.assign(Economy.STARTER_BASICS)
	profile.clutches = Economy.STARTER_CLUTCHES
	profile.first_steps_active = true
	return profile


## A per-player, per-day seed (for picking that day's quests), separate from the hatch RNG.
func seed_for(day: int) -> int:
	return hash([day, _rng.seed])


## Sets the player's name: trimmed, at most NAME_MAX_LENGTH characters. Returns false if empty.
func set_player_name(text: String) -> bool:
	var clean := text.strip_edges().left(NAME_MAX_LENGTH).strip_edges()
	if clean.is_empty():
		return false
	player_name = clean
	return true


## Adds the chosen partner to the collection and the lineup. Only once, and only a starter partner.
func choose_partner(id: StringName) -> bool:
	if partner_chosen or not id in Economy.STARTER_PARTNERS:
		return false
	if not owns(id):
		owned[id] = false
	seen.erase(id)
	if not id in lineup and lineup.size() < PartyRules.BRING_SIZE:
		lineup.append(id)
	partner = id
	partner_chosen = true
	return true


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
		new_dinos[dino.id] = true
		seen.erase(dino.id)
	elif shiny and not is_shiny(dino.id):
		result.upgraded_to_shiny = true
		owned[dino.id] = true
	else:
		result.amber = Economy.MELT_VALUE[dino.rarity]
		amber += result.amber
	return result


func can_craft(dino: DinoDef) -> bool:
	return not owns(dino.id) and amber >= Economy.CRAFT_COST[dino.rarity]


func craft(dino: DinoDef) -> HatchResult:
	if not can_craft(dino):
		return null
	amber -= Economy.CRAFT_COST[dino.rarity]
	Goals.on_craft(self)
	return add_dino(dino, false)


# --- Eggs -----------------------------------------------------------------------------------

## Opens one clutch (a rare one if `rare`). Returns an empty array if there's none to open.
## Hatches one clutch (a Rare one if `rare`). `time` (Unix seconds) goes in the hatch history.
func hatch_clutch(catalog: DinoCatalog, rare := false, time := 0) -> Array[HatchResult]:
	var results: Array[HatchResult] = []
	if (rare_clutches if rare else clutches) <= 0:
		return results
	if rare:
		rare_clutches -= 1
	else:
		clutches -= 1
	var rarities: Array[int] = []
	for i in Economy.EGGS_PER_CLUTCH:
		rarities.append(_roll(Economy.RARE_CLUTCH_ODDS if rare else Economy.RARITY_ODDS))
	var has_epic := rarities.any(func(r: int) -> bool: return r >= DinoDef.Rarity.EPIC)
	if not has_epic and clutches_without_epic >= Economy.PITY_CLUTCHES - 1:
		rarities[rarities.size() - 1] = _roll(Economy.PITY_ODDS)
		has_epic = true
	clutches_without_epic = 0 if has_epic else clutches_without_epic + 1

	for rarity in rarities:
		var dino := _pick_dino(catalog, rarity)
		results.append(add_dino(dino, _rng.randf() < Economy.SHINY_ODDS))
		eggs_hatched += 1
	Goals.on_hatch(self, results)
	_log_hatch(results, rare, time)
	return results


func _log_hatch(results: Array[HatchResult], rare: bool, time: int) -> void:
	var eggs: Array = []
	for result in results:
		eggs.append({"id": String(result.dino.id), "shiny": result.shiny, "new": result.is_new,
				"upgraded": result.upgraded_to_shiny, "amber": result.amber})
	hatch_history.push_front({"time": time, "rare": rare, "eggs": eggs})
	if hatch_history.size() > HATCH_HISTORY_SIZE:
		hatch_history.resize(HATCH_HISTORY_SIZE)


func buy_clutch() -> bool:
	if amber < Economy.CLUTCH_PRICE:
		return false
	amber -= Economy.CLUTCH_PRICE
	clutches += 1
	return true


func buy_rare_clutch() -> bool:
	if amber < Economy.RARE_CLUTCH_PRICE:
		return false
	amber -= Economy.RARE_CLUTCH_PRICE
	rare_clutches += 1
	return true


## `today` is a day number (see SaveStore.today()). One check-in per calendar day.
func can_claim_daily(today: int) -> bool:
	return today != last_daily_day


## The daily check-in: a free clutch plus today's streak bonus (Economy.CHECKIN_BONUSES), then
## the streak moves on a day. Days missed in between don't matter; the streak just waits.
func claim_daily(today: int) -> bool:
	if not can_claim_daily(today):
		return false
	last_daily_day = today
	clutches += Economy.DAILY_CLUTCHES
	var bonus: Dictionary = Economy.CHECKIN_BONUSES[checkin_day]
	amber += int(bonus.get("amber", 0))
	clutches += int(bonus.get("clutches", 0))
	rare_clutches += int(bonus.get("rare_clutches", 0))
	checkin_day = (checkin_day + 1) % Economy.CHECKIN_BONUSES.size()
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


## Switches to another party slot (the current lineup is kept in its slot).
func select_party(slot: int) -> void:
	if slot < 0 or slot >= PARTY_SLOTS:
		return
	_ensure_parties()
	parties[party_slot]["lineup"] = lineup.duplicate()
	party_slot = slot
	lineup.assign((parties[slot]["lineup"] as Array).filter(func(id: StringName) -> bool: return owns(id)))


## Renames a party slot: trimmed, at most PARTY_NAME_MAX_LENGTH characters. False if empty.
func rename_party(slot: int, text: String) -> bool:
	var clean := text.strip_edges().left(PARTY_NAME_MAX_LENGTH).strip_edges()
	if clean.is_empty() or slot < 0 or slot >= PARTY_SLOTS:
		return false
	_ensure_parties()
	parties[slot]["name"] = clean
	return true


func party_name(slot: int) -> String:
	_ensure_parties()
	return parties[slot]["name"]


## A slot's lineup (the open one's is `lineup`).
func party_lineup(slot: int) -> Array[StringName]:
	_ensure_parties()
	var ids: Array[StringName] = []
	ids.assign(lineup if slot == party_slot else parties[slot]["lineup"])
	return ids


## Fills in missing slots: new ones start as a copy of the current lineup.
func _ensure_parties() -> void:
	while parties.size() < PARTY_SLOTS:
		parties.append({"name": "Party %d" % (parties.size() + 1), "lineup": lineup.duplicate()})


func is_new(id: StringName) -> bool:
	return new_dinos.has(id)


## Clears a dino's "new" dot once the player has looked at it. True if it had one.
func mark_viewed(id: StringName) -> bool:
	return new_dinos.erase(id)


## Adds a friend's party code to the friends list (to the top), or updates them if a friend with
## the same name is already there: their newer code replaces the old one, and their record stays.
func remember_friend(info: Dictionary) -> void:
	var index := _friend_index(info["player"])
	var entry := {"code": info["code"], "player": info["player"], "party": info["party"], "wins": 0, "losses": 0}
	if index >= 0:
		entry["wins"] = friends[index]["wins"]
		entry["losses"] = friends[index]["losses"]
		friends.remove_at(index)
	friends.push_front(entry)
	if friends.size() > FRIENDS_MAX:
		friends.resize(FRIENDS_MAX)


## A ghost duel against a friend's party ended (a forfeit counts as a loss).
func record_friend_duel(info: Dictionary, won: bool) -> void:
	var index := _friend_index(info["player"])
	if index < 0:
		remember_friend(info)
		index = 0
	friends[index]["wins" if won else "losses"] += 1


## [wins, losses] against a friend.
func friend_record(player: String) -> Array:
	var index := _friend_index(player)
	return [friends[index]["wins"], friends[index]["losses"]] if index >= 0 else [0, 0]


func forget_friend(index: int) -> void:
	if index >= 0 and index < friends.size():
		friends.remove_at(index)


func _friend_index(player: String) -> int:
	for i in friends.size():
		if String(friends[i]["player"]).to_lower() == player.to_lower():
			return i
	return -1


func lineup_defs(catalog: DinoCatalog) -> Array[DinoDef]:
	var defs: Array[DinoDef] = []
	for id in lineup:
		var dino := catalog.find(id)
		if dino:
			defs.append(dino)
	return defs


## [wins, losses] against one rival.
func record_against(rival_id: StringName) -> Array:
	return rival_record.get(rival_id, [0, 0])


## Applies battle rewards and returns what was given:
## {"amber", "clutches", "rare_clutches": int, "first_clear": bool, "stars": int, "new_best": bool}.
## Against a Journey `stage`, a win earns `stars` (dinos left standing) and the first clear pays
## the chapter's bonus (Economy); later wins pay Economy.REPLAY_AMBER.
func record_battle(won: bool, stage: RivalDef = null, stars := 0) -> Dictionary:
	var reward := {"amber": Economy.LOSS_AMBER, "clutches": 0, "rare_clutches": 0, "first_clear": false,
			"stars": 0, "new_best": false}
	if won:
		wins += 1
		reward["clutches"] = Economy.WIN_CLUTCHES
		reward["amber"] = Economy.WIN_AMBER
	else:
		losses += 1
	if stage:
		var key := String(stage.id)
		var record: Array = rival_record.get(stage.id, [0, 0])
		record[0 if won else 1] += 1
		rival_record[stage.id] = record
		if won:
			var best := int(journey_stars.get(key, 0))
			reward["first_clear"] = best == 0
			reward["stars"] = clampi(stars, 1, Journey.MAX_STARS)
			reward["new_best"] = reward["stars"] > best
			journey_stars[key] = maxi(best, reward["stars"])
			if reward["first_clear"]:
				reward["amber"] = Economy.JOURNEY_WIN_AMBER[stage.chapter]
				if stage.chapter == Journey.FINALE:
					reward["rare_clutches"] = Economy.FINALE_FIRST_CLEAR_RARE_CLUTCHES
				elif stage.is_boss:
					reward["rare_clutches"] = Economy.BOSS_FIRST_CLEAR_RARE_CLUTCHES
				else:
					reward["amber"] += Economy.JOURNEY_FIRST_CLEAR_AMBER[stage.chapter]
			else:
				reward["amber"] = Economy.REPLAY_AMBER
	amber += reward["amber"]
	clutches += reward["clutches"]
	rare_clutches += reward["rare_clutches"]
	return reward


## Leaving a battle partway: a loss in the record, but no Amber (or quitting would farm it).
func record_forfeit(rival_id: StringName = &"") -> void:
	losses += 1
	if rival_id != &"":
		var record: Array = rival_record.get(rival_id, [0, 0])
		record[1] += 1
		rival_record[rival_id] = record


# --- First steps (new players) ----------------------------------------------------------------

## The checklist in order. Most steps are read from the save, so they can't get out of sync.
const FIRST_STEPS: Array[StringName] = [&"partner", &"hatch", &"dex", &"party", &"battle"]


func first_step_done(step: StringName) -> bool:
	match step:
		&"partner":
			return partner_chosen
		&"hatch":
			return eggs_hatched > 0
		&"dex":
			return opened_dex_card
		&"party":
			return _party_has_a_new_dino() or (eggs_hatched > 0 and not _owns_a_new_dino())
		&"battle":
			return wins > 0
	return false


## The first step not done yet, or &"" when all are.
func next_first_step() -> StringName:
	for step in FIRST_STEPS:
		if not first_step_done(step):
			return step
	return &""


## Gives the checklist's bonus clutch once everything is done, and retires the checklist.
func claim_first_steps_reward() -> bool:
	if not first_steps_active or next_first_step() != &"":
		return false
	clutches += Economy.FIRST_STEPS_CLUTCHES
	first_steps_active = false
	return true


func _is_starter(id: StringName) -> bool:
	return id in Economy.STARTER_BASICS or id == partner


func _party_has_a_new_dino() -> bool:
	return lineup.size() == PartyRules.BRING_SIZE and lineup.any(func(id: StringName) -> bool: return not _is_starter(id))


## Whether there's anything beyond the starters to add (all-duplicate hatches can't block the step).
func _owns_a_new_dino() -> bool:
	return owned.keys().any(func(id: StringName) -> bool: return not _is_starter(id))


# --- Saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"owned": owned.duplicate(),
		"seen": seen.keys(),
		"amber": amber,
		"clutches": clutches,
		"rare_clutches": rare_clutches,
		"lineup": lineup.duplicate(),
		"parties": _saved_parties(),
		"party_slot": party_slot,
		"new_dinos": new_dinos.keys(),
		"mastery": mastery.duplicate(true),
		"friends": friends.duplicate(true),
		"whats_new_seen": whats_new_seen,
		"review_asks": review_asks,
		"review_asked_day": review_asked_day,
		"clutches_without_epic": clutches_without_epic,
		"last_daily_day": last_daily_day,
		"checkin_day": checkin_day,
		"wins": wins,
		"losses": losses,
		"rival_record": rival_record.duplicate(true),
		"journey_stars": journey_stars.duplicate(),
		"eggs_hatched": eggs_hatched,
		"hatch_history": hatch_history.duplicate(true),
		"tutorial_done": tutorial_done,
		"partner_chosen": partner_chosen,
		"partner": String(partner),
		"first_steps_active": first_steps_active,
		"player_name": player_name,
		"tour_done": tour_done,
		"stats": stats.duplicate(),
		"quest_day": quest_day,
		"quests": quests.duplicate(true),
		"quest_bonus_claimed": quest_bonus_claimed,
		"claimed_goals": claimed_goals.duplicate(),
		"battle": battle.duplicate(true),
		"opened_dex_card": opened_dex_card,
		# Strings, because JSON numbers are doubles and would round 64-bit RNG values.
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
	}


func _saved_parties() -> Array:
	_ensure_parties()
	var saved: Array = []
	for slot in PARTY_SLOTS:
		saved.append({"name": parties[slot]["name"], "lineup": party_lineup(slot).duplicate()})
	return saved


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
	profile.rare_clutches = maxi(0, int(data.get("rare_clutches", 0)))
	var lineup_ids: Array[StringName] = []
	for key in data.get("lineup", []):
		var id := StringName(key)
		if profile.owns(id) and not id in lineup_ids:
			lineup_ids.append(id)
	profile.lineup.assign(lineup_ids.slice(0, PartyRules.BRING_SIZE))
	# Party slots (saves from before them: the lineup becomes Party 1, and 2 and 3 copy it).
	for entry in data.get("parties", []):
		if not entry is Dictionary or profile.parties.size() >= PARTY_SLOTS:
			continue
		var ids: Array[StringName] = []
		for key in entry.get("lineup", []):
			var id := StringName(key)
			if profile.owns(id) and not id in ids and ids.size() < PartyRules.BRING_SIZE:
				ids.append(id)
		var name := String(entry.get("name", "")).strip_edges().left(PARTY_NAME_MAX_LENGTH)
		profile.parties.append({"name": name if name != "" else "Party %d" % (profile.parties.size() + 1), "lineup": ids})
	profile.party_slot = clampi(int(data.get("party_slot", 0)), 0, PARTY_SLOTS - 1)
	profile._ensure_parties()
	for key in data.get("new_dinos", []):
		if profile.owns(StringName(key)):
			profile.new_dinos[StringName(key)] = true
	for entry in data.get("friends", []):
		if entry is Dictionary and String(entry.get("code", "")).begins_with(PartyCode.PREFIX) \
				and profile.friends.size() < FRIENDS_MAX:
			profile.friends.append({"code": String(entry["code"]), "player": String(entry.get("player", "A friend")),
					"party": String(entry.get("party", "Party")), "wins": maxi(0, int(entry.get("wins", 0))),
					"losses": maxi(0, int(entry.get("losses", 0)))})
	profile.whats_new_seen = String(data.get("whats_new_seen", ""))
	profile.review_asks = maxi(0, int(data.get("review_asks", 0)))
	profile.review_asked_day = int(data.get("review_asked_day", -1))
	var saved_mastery: Dictionary = data.get("mastery", {})
	for key in saved_mastery:
		if catalog.find(StringName(key)) and saved_mastery[key] is Dictionary:
			var stats := {}
			for stat in Mastery.STATS:
				stats[stat] = maxi(0, int(saved_mastery[key].get(stat, 0)))
			profile.mastery[String(key)] = stats
	profile.clutches_without_epic = int(data.get("clutches_without_epic", 0))
	profile.last_daily_day = int(data.get("last_daily_day", -1))
	profile.checkin_day = posmod(int(data.get("checkin_day", 0)), Economy.CHECKIN_BONUSES.size())
	profile.wins = int(data.get("wins", 0))
	profile.losses = int(data.get("losses", 0))
	var records: Dictionary = data.get("rival_record", {})
	for key in records:
		var pair: Array = records[key]
		if pair.size() == 2:
			profile.rival_record[StringName(key)] = [int(pair[0]), int(pair[1])]
	if data.has("journey_stars"):
		var saved_stars: Dictionary = data["journey_stars"]
		for key in saved_stars:
			if Journey.find(StringName(key)):
				profile.journey_stars[String(key)] = clampi(int(saved_stars[key]), 1, Journey.MAX_STARS)
	else:
		# Saves from before the Journey: rivals already beaten (Rae, Fern, Cora, Dusty) count as
		# cleared stages with 1 star. The old Rory stage is gone, so his record doesn't carry over.
		for stage in Journey.stages():
			if profile.record_against(stage.id)[0] > 0:
				profile.journey_stars[String(stage.id)] = 1
	profile.eggs_hatched = int(data.get("eggs_hatched", 0))
	# Numbers come back from JSON as floats; ids no longer in the game are dropped.
	for entry in data.get("hatch_history", []):
		if not entry is Dictionary or profile.hatch_history.size() >= HATCH_HISTORY_SIZE:
			continue
		var eggs: Array = []
		for egg in entry.get("eggs", []):
			if egg is Dictionary and catalog.find(StringName(egg.get("id", ""))):
				eggs.append({"id": String(egg["id"]), "shiny": bool(egg.get("shiny", false)), "new": bool(egg.get("new", false)),
						"upgraded": bool(egg.get("upgraded", false)), "amber": int(egg.get("amber", 0))})
		profile.hatch_history.append({"time": int(entry.get("time", 0)), "rare": bool(entry.get("rare", false)), "eggs": eggs})
	# Saves from before the tutorial existed: anyone who has battled already knows the moves.
	profile.tutorial_done = bool(data.get("tutorial_done", profile.wins + profile.losses > 0))
	profile.partner_chosen = bool(data.get("partner_chosen", true))
	profile.partner = StringName(data.get("partner", ""))
	# Saves from before the checklist existed are past the new-player stage.
	profile.first_steps_active = bool(data.get("first_steps_active", false))
	profile.opened_dex_card = bool(data.get("opened_dex_card", false))
	profile.player_name = String(data.get("player_name", "")).left(NAME_MAX_LENGTH)
	profile.tour_done = bool(data.get("tour_done", true))
	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats:
		profile.stats[String(key)] = int(saved_stats[key])
	profile.quest_day = int(data.get("quest_day", -1))
	for quest in data.get("quests", []):
		if quest is Dictionary and Goals.QUEST_POOL.has(StringName(quest.get("id", ""))):
			profile.quests.append({"id": String(quest["id"]), "progress": int(quest.get("progress", 0)),
					"claimed": bool(quest.get("claimed", false))})
	profile.quest_bonus_claimed = bool(data.get("quest_bonus_claimed", false))
	var saved_battle: Variant = data.get("battle", {})
	if saved_battle is Dictionary and not (saved_battle as Dictionary).is_empty():
		var b: Dictionary = saved_battle
		var events: Array = []
		for event in b.get("events", []):
			events.append((event as Array).map(func(value: Variant) -> int: return int(value)))
		profile.battle = {"rival": String(b.get("rival", "")), "seed": int(b.get("seed", 0)),
				"player": Array(b.get("player", [])).map(func(id: Variant) -> String: return String(id)),
				"rival_party": Array(b.get("rival_party", [])).map(func(id: Variant) -> String: return String(id)),
				"coaching": bool(b.get("coaching", false)), "events": events}
	var saved_claims: Dictionary = data.get("claimed_goals", {})
	for key in saved_claims:
		profile.claimed_goals[String(key)] = bool(saved_claims[key])
	profile._rng.seed = String(data.get("rng_seed", "0")).to_int()
	profile._rng.state = String(data.get("rng_state", "0")).to_int()
	return profile
