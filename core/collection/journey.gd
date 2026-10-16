class_name Journey
extends RefCounted
## The Journey through time (Jo, 2026-10-15): three era chapters of 5 rivals + Rory as the boss,
## then the Extinction Day finale. Stages (RivalDef.ROSTER, in order) unlock one after another;
## a win earns 1-3 stars (one per dino left standing) and each stage keeps its best in
## PlayerProfile.journey_stars, which is also how a stage counts as cleared. Rewards live in
## PlayerProfile.record_battle; the numbers in Economy.

const CHAPTER_NAMES: Array[String] = ["Triassic", "Jurassic", "Cretaceous", "Extinction Day"]
const FINALE := 3
const MAX_STARS := 3
## Star chests per era chapter: [stars needed, Amber, clutches, Rare clutches].
const STAR_CHESTS := [[6, 100, 0, 0], [12, 0, 1, 0], [18, 0, 0, 1]]

static var _stages: Array[RivalDef] = []
## Development only: every stage counts as unlocked for this run (the DEV button on the Journey tab).
## Doesn't touch the save. TODO(release): delete with the button (docs/RELEASE_CHECKLIST.md).
static var dev_unlock_all := false


static func stages() -> Array[RivalDef]:
	if _stages.is_empty():
		_stages = RivalDef.load_roster()
	return _stages


static func find(id: StringName) -> RivalDef:
	for stage in stages():
		if stage.id == id:
			return stage
	return null


static func chapter_stages(chapter: int) -> Array[RivalDef]:
	return stages().filter(func(stage: RivalDef) -> bool: return stage.chapter == chapter)


static func best_stars(profile: PlayerProfile, stage: RivalDef) -> int:
	return int(profile.journey_stars.get(String(stage.id), 0))


static func is_cleared(profile: PlayerProfile, stage: RivalDef) -> bool:
	return best_stars(profile, stage) > 0


## The first stage is always open; every other one opens when the one before it is cleared.
static func is_unlocked(profile: PlayerProfile, stage: RivalDef) -> bool:
	if dev_unlock_all:
		return true
	var index := stages().find(stage)
	return index <= 0 or is_cleared(profile, stages()[index - 1])


static func chapter_unlocked(profile: PlayerProfile, chapter: int) -> bool:
	var list := chapter_stages(chapter)
	return not list.is_empty() and is_unlocked(profile, list[0])


## A chapter is cleared when its boss (its last stage) is.
static func chapter_cleared(profile: PlayerProfile, chapter: int) -> bool:
	var list := chapter_stages(chapter)
	return not list.is_empty() and is_cleared(profile, list[-1])


## The first stage not cleared yet, or null when the whole Journey is done.
static func next_stage(profile: PlayerProfile) -> RivalDef:
	for stage in stages():
		if not is_cleared(profile, stage):
			return stage
	return null


static func complete(profile: PlayerProfile) -> bool:
	return next_stage(profile) == null


static func chapter_stars(profile: PlayerProfile, chapter: int) -> int:
	var total := 0
	for stage in chapter_stages(chapter):
		total += best_stars(profile, stage)
	return total


static func total_stars(profile: PlayerProfile) -> int:
	var total := 0
	for stage in stages():
		total += best_stars(profile, stage)
	return total


static func max_total_stars() -> int:
	return stages().size() * MAX_STARS


# --- Star chests (era chapters only) -----------------------------------------------------------

static func chest_claimed(profile: PlayerProfile, chapter: int, index: int) -> bool:
	return profile.claimed_goals.get(_chest_key(chapter, index), false)


static func chest_ready(profile: PlayerProfile, chapter: int, index: int) -> bool:
	return chapter < FINALE and chapter_stars(profile, chapter) >= STAR_CHESTS[index][0] \
			and not chest_claimed(profile, chapter, index)


static func claim_chest(profile: PlayerProfile, chapter: int, index: int) -> bool:
	if not chest_ready(profile, chapter, index):
		return false
	var chest: Array = STAR_CHESTS[index]
	profile.claimed_goals[_chest_key(chapter, index)] = true
	profile.amber += chest[1]
	profile.clutches += chest[2]
	profile.rare_clutches += chest[3]
	return true


static func any_chest_ready(profile: PlayerProfile) -> bool:
	for chapter in FINALE:
		for index in STAR_CHESTS.size():
			if chest_ready(profile, chapter, index):
				return true
	return false


static func _chest_key(chapter: int, index: int) -> String:
	return "chest_%d_%d" % [chapter, index]
