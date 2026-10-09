class_name Goals
extends RefCounted
## Daily quests, collection rewards and achievements (decided by Jo, 2026-10-09). The rules live
## here; PlayerProfile stores the progress (stats, quests, claimed_goals). Everything is offline:
## achievements are in-game only, no Google Play Games.

# --- Daily quests ---------------------------------------------------------------------------

const QUESTS_PER_DAY := 3
const QUEST_BONUS_CLUTCHES := 1
## A win this fast (or faster) counts for "quick" quests.
const QUICK_WIN_TURNS := 12
## Rivals with this many stars or more count as "hard".
const HARD_RIVAL_STARS := 3
## id -> [text, target, Amber reward, group]. A day never has two quests from the same group.
const QUEST_POOL := {
	&"win_2": ["Win 2 battles", 2, 40, &"win"],
	&"play_3": ["Battle 3 times", 3, 30, &"play"],
	&"hatch_3": ["Hatch 3 eggs", 3, 25, &"hatch"],
	&"win_land": ["Win with a Land dino in your party", 1, 35, &"type"],
	&"win_sky": ["Win with a Sky dino in your party", 1, 35, &"type"],
	&"win_sea": ["Win with a Sea dino in your party", 1, 35, &"type"],
	&"win_bond": ["Win with an era bond (all 3 from one era)", 1, 40, &"bond"],
	&"win_balanced": ["Win with a balanced party (Land, Sky and Sea)", 1, 40, &"balanced"],
	&"win_flawless": ["Win without losing a dino", 1, 50, &"flawless"],
	&"win_quick": ["Win in 12 turns or fewer", 1, 45, &"quick"],
	&"win_hard": ["Beat a rival with 3 stars or more", 1, 50, &"hard"],
}


## Rolls today's quests if the day has changed. The same day always gives the same quests.
static func refresh_quests(profile: PlayerProfile, today: int) -> void:
	if profile.quest_day == today and profile.quests.size() == QUESTS_PER_DAY:
		return
	profile.quest_day = today
	profile.quest_bonus_claimed = false
	profile.quests.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.seed_for(today)
	var ids: Array = QUEST_POOL.keys()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	var groups := {}
	for id in ids:
		var group: StringName = QUEST_POOL[id][3]
		if groups.has(group):
			continue
		groups[group] = true
		profile.quests.append({"id": String(id), "progress": 0, "claimed": false})
		if profile.quests.size() == QUESTS_PER_DAY:
			break


static func quest_text(quest: Dictionary) -> String:
	return QUEST_POOL[StringName(quest["id"])][0]


static func quest_target(quest: Dictionary) -> int:
	return QUEST_POOL[StringName(quest["id"])][1]


static func quest_reward(quest: Dictionary) -> int:
	return QUEST_POOL[StringName(quest["id"])][2]


static func quest_done(quest: Dictionary) -> bool:
	return int(quest["progress"]) >= quest_target(quest)


## Gives the quest's Amber. Returns false if it isn't done or was already claimed.
static func claim_quest(profile: PlayerProfile, index: int) -> bool:
	if index < 0 or index >= profile.quests.size():
		return false
	var quest: Dictionary = profile.quests[index]
	if quest["claimed"] or not quest_done(quest):
		return false
	quest["claimed"] = true
	profile.amber += quest_reward(quest)
	_track_amber(profile)
	return true


static func quest_bonus_ready(profile: PlayerProfile) -> bool:
	return not profile.quest_bonus_claimed and profile.quests.size() == QUESTS_PER_DAY \
			and profile.quests.all(func(quest: Dictionary) -> bool: return quest_done(quest))


## The bonus clutch for finishing all of today's quests.
static func claim_quest_bonus(profile: PlayerProfile) -> bool:
	if not quest_bonus_ready(profile):
		return false
	profile.quest_bonus_claimed = true
	profile.clutches += QUEST_BONUS_CLUTCHES
	_add(profile, &"quest_days")
	return true


# --- Collection -----------------------------------------------------------------------------

## [dinos discovered, Amber, clutches].
const MILESTONES := [[5, 50, 0], [10, 0, 1], [15, 150, 0], [20, 0, 2], [25, 300, 0], [30, 0, 3]]
const ERA_CLUTCHES := 1


static func discovered(profile: PlayerProfile) -> int:
	return profile.owned.size()


static func milestone_ready(profile: PlayerProfile, index: int) -> bool:
	return discovered(profile) >= MILESTONES[index][0] and not _claimed(profile, "milestone_%d" % MILESTONES[index][0])


static func milestone_claimed(profile: PlayerProfile, index: int) -> bool:
	return _claimed(profile, "milestone_%d" % MILESTONES[index][0])


static func claim_milestone(profile: PlayerProfile, index: int) -> bool:
	if not milestone_ready(profile, index):
		return false
	profile.claimed_goals["milestone_%d" % MILESTONES[index][0]] = true
	profile.amber += MILESTONES[index][1]
	profile.clutches += MILESTONES[index][2]
	_track_amber(profile)
	return true


## [owned, total] for one era.
static func era_progress(profile: PlayerProfile, catalog: DinoCatalog, era: int) -> Array:
	var dinos := catalog.dinos.filter(func(d: DinoDef) -> bool: return d.era == era)
	return [dinos.filter(func(d: DinoDef) -> bool: return profile.owns(d.id)).size(), dinos.size()]


static func era_complete(profile: PlayerProfile, catalog: DinoCatalog, era: int) -> bool:
	var progress := era_progress(profile, catalog, era)
	return progress[1] > 0 and progress[0] >= progress[1]


static func era_ready(profile: PlayerProfile, catalog: DinoCatalog, era: int) -> bool:
	return era_complete(profile, catalog, era) and not _claimed(profile, "era_%d" % era)


static func era_claimed(profile: PlayerProfile, era: int) -> bool:
	return _claimed(profile, "era_%d" % era)


static func claim_era(profile: PlayerProfile, catalog: DinoCatalog, era: int) -> bool:
	if not era_ready(profile, catalog, era):
		return false
	profile.claimed_goals["era_%d" % era] = true
	profile.clutches += ERA_CLUTCHES
	return true


# --- Achievements ---------------------------------------------------------------------------

const FAST_WIN_TURNS := 8
const METEOR_TURN := 20
## id -> [title, description, target, Amber]. The order is the order they're listed in.
const ACHIEVEMENTS := {
	&"first_win": ["First Victory", "Win a battle.", 1, 50],
	&"veteran": ["Veteran Hunter", "Win 25 battles.", 25, 150],
	&"champion": ["Champion", "Win 100 battles.", 100, 300],
	&"rival_sweep": ["Rival Sweep", "Beat every rival at least once.", 5, 150],
	&"beat_rory": ["Rory Who?", "Beat Rival Rory.", 1, 100],
	&"flawless": ["Flawless", "Win without losing a dino.", 1, 75],
	&"lightning": ["Lightning Strike", "Win in 8 turns or fewer.", 1, 75],
	&"last_standing": ["Last Dino Standing", "Win with only one dino left.", 1, 75],
	&"meteor": ["Meteor Survivor", "Win a battle that lasted into the meteor shower.", 1, 75],
	&"perfect_party": ["Perfect Party", "Win with an era bond and a balanced party at once.", 1, 100],
	&"egg_cracker": ["Egg Cracker", "Hatch 30 eggs.", 30, 100],
	&"hatchery": ["Hatchery", "Hatch 100 eggs.", 100, 250],
	&"legendary": ["Legendary Find", "Hatch a Legendary dino.", 1, 150],
	&"shiny": ["Something Shiny", "Find a Shiny dino.", 1, 100],
	&"crafter": ["Fossil Crafter", "Craft a dino with Amber.", 1, 50],
	&"daily_grind": ["Daily Grind", "Finish all daily quests on 7 days.", 7, 150],
	&"amber_hoard": ["Amber Hoard", "Have 1,000 Amber at once.", 1000, 100],
	&"complete_dex": ["Complete Dex", "Discover every dino.", 30, 500],
}


static func achievement_progress(profile: PlayerProfile, catalog: DinoCatalog, id: StringName) -> int:
	match id:
		&"first_win", &"veteran", &"champion":
			return profile.wins
		&"rival_sweep":
			return _rivals().filter(func(rival: RivalDef) -> bool: return profile.record_against(rival.id)[0] > 0).size()
		&"beat_rory":
			return profile.record_against(&"rory")[0]
		&"flawless":
			return _stat(profile, &"flawless_wins")
		&"lightning":
			return _stat(profile, &"fast_wins")
		&"last_standing":
			return _stat(profile, &"last_standing_wins")
		&"meteor":
			return _stat(profile, &"meteor_wins")
		&"perfect_party":
			return _stat(profile, &"perfect_party_wins")
		&"egg_cracker", &"hatchery":
			return profile.eggs_hatched
		&"legendary":
			return _stat(profile, &"legendaries_hatched")
		&"shiny":
			return maxi(_stat(profile, &"shinies_found"), profile.owned.values().count(true))
		&"crafter":
			return _stat(profile, &"crafted")
		&"daily_grind":
			return _stat(profile, &"quest_days")
		&"amber_hoard":
			return maxi(_stat(profile, &"max_amber"), profile.amber)
		&"complete_dex":
			return discovered(profile)
	return 0


static func achievement_target(catalog: DinoCatalog, id: StringName) -> int:
	match id:
		&"rival_sweep":
			return _rivals().size()
		&"complete_dex":
			return catalog.dinos.size()
	return ACHIEVEMENTS[id][2]


static func achievement_unlocked(profile: PlayerProfile, catalog: DinoCatalog, id: StringName) -> bool:
	return achievement_progress(profile, catalog, id) >= achievement_target(catalog, id)


static func achievement_claimed(profile: PlayerProfile, id: StringName) -> bool:
	return _claimed(profile, "ach_%s" % id)


static func claim_achievement(profile: PlayerProfile, catalog: DinoCatalog, id: StringName) -> bool:
	if achievement_claimed(profile, id) or not achievement_unlocked(profile, catalog, id):
		return false
	profile.claimed_goals["ach_%s" % id] = true
	profile.amber += ACHIEVEMENTS[id][3]
	_track_amber(profile)
	return true


# --- Events (called by PlayerProfile and Session) -------------------------------------------

## After a finished battle (not a forfeit). `summary`: won, rival_id, difficulty, party (the 3
## picked DinoDefs), turns, dinos_left.
static func on_battle(profile: PlayerProfile, summary: Dictionary) -> void:
	var won: bool = summary.get("won", false)
	var party: Array[DinoDef] = []
	party.assign(summary.get("party", []))
	var turns: int = summary.get("turns", 999)
	var left: int = summary.get("dinos_left", 0)
	_add(profile, &"battles")
	if won:
		if party.size() > 0 and left >= party.size():
			_add(profile, &"flawless_wins")
		if turns <= FAST_WIN_TURNS:
			_add(profile, &"fast_wins")
		if left == 1:
			_add(profile, &"last_standing_wins")
		if turns >= METEOR_TURN:
			_add(profile, &"meteor_wins")
		if PartyRules.has_era_bond(party) and PartyRules.is_balanced(party):
			_add(profile, &"perfect_party_wins")
	for quest in profile.quests:
		quest["progress"] = int(quest["progress"]) + _battle_counts_for(StringName(quest["id"]), summary, party)
	_track_amber(profile)


static func on_hatch(profile: PlayerProfile, results: Array[HatchResult]) -> void:
	for result in results:
		if result.dino.rarity == DinoDef.Rarity.LEGENDARY:
			_add(profile, &"legendaries_hatched")
		if result.shiny:
			_add(profile, &"shinies_found")
	for quest in profile.quests:
		if StringName(quest["id"]) == &"hatch_3":
			quest["progress"] = int(quest["progress"]) + results.size()
	_track_amber(profile)


static func on_craft(profile: PlayerProfile) -> void:
	_add(profile, &"crafted")


static func _battle_counts_for(id: StringName, summary: Dictionary, party: Array[DinoDef]) -> int:
	var won: bool = summary.get("won", false)
	if id == &"play_3":
		return 1
	if not won:
		return 0
	match id:
		&"win_2":
			return 1
		&"win_land":
			return 1 if party.any(func(d: DinoDef) -> bool: return d.dino_type == DinoDef.DinoType.LAND) else 0
		&"win_sky":
			return 1 if party.any(func(d: DinoDef) -> bool: return d.dino_type == DinoDef.DinoType.SKY) else 0
		&"win_sea":
			return 1 if party.any(func(d: DinoDef) -> bool: return d.dino_type == DinoDef.DinoType.SEA) else 0
		&"win_bond":
			return 1 if PartyRules.has_era_bond(party) else 0
		&"win_balanced":
			return 1 if PartyRules.is_balanced(party) else 0
		&"win_flawless":
			return 1 if party.size() > 0 and int(summary.get("dinos_left", 0)) >= party.size() else 0
		&"win_quick":
			return 1 if int(summary.get("turns", 999)) <= QUICK_WIN_TURNS else 0
		&"win_hard":
			return 1 if int(summary.get("difficulty", 0)) >= HARD_RIVAL_STARS else 0
	return 0


# --- Summary --------------------------------------------------------------------------------

## Whether anything on the Goals tab is waiting to be claimed (for the tab's "(!)").
static func anything_to_claim(profile: PlayerProfile, catalog: DinoCatalog) -> bool:
	if quest_bonus_ready(profile):
		return true
	for quest in profile.quests:
		if quest_done(quest) and not quest["claimed"]:
			return true
	for i in MILESTONES.size():
		if milestone_ready(profile, i):
			return true
	for era in DinoDef.ERA_NAMES.size():
		if era_ready(profile, catalog, era):
			return true
	for id in ACHIEVEMENTS:
		if not achievement_claimed(profile, id) and achievement_unlocked(profile, catalog, id):
			return true
	return false


static var _roster: Array[RivalDef] = []


static func _rivals() -> Array[RivalDef]:
	if _roster.is_empty():
		_roster = RivalDef.load_roster()
	return _roster


static func _claimed(profile: PlayerProfile, key: String) -> bool:
	return profile.claimed_goals.get(key, false)


## Stats use String keys, since that's what comes back from the JSON save.
static func _stat(profile: PlayerProfile, key: StringName) -> int:
	return int(profile.stats.get(String(key), 0))


static func _add(profile: PlayerProfile, key: StringName, amount := 1) -> void:
	profile.stats[String(key)] = _stat(profile, key) + amount


static func _track_amber(profile: PlayerProfile) -> void:
	profile.stats["max_amber"] = maxi(_stat(profile, &"max_amber"), profile.amber)
