class_name HunterId
extends RefCounted
## The Fossil Hunter ID (Jo, 2026-11-03): the player's profile. An avatar (any dino they own, a
## rival they've beaten, or the Professaur), a title earned by playing, 3 showcase cards and their
## stats. These are the rules; the screen is ui/profile/profile_view.gd.

const SHOWCASE_SIZE := 3
## Avatar ids: "dino:<id>", "rival:<character>", or this.
const PROFESSAUR := "professaur"
const DEFAULT_TITLE := "hunter"
## Fixed titles: id -> [title, how to earn it]. Every set also gives one ("set:<id>", see titles()).
const TITLES := {
	"hunter": ["Fossil Hunter", "Everyone starts here."],
	"champ_0": ["Triassic Champion", "Clear the Triassic."],
	"champ_1": ["Jurassic Champion", "Clear the Jurassic."],
	"champ_2": ["Cretaceous Champion", "Clear the Cretaceous."],
	"survivor": ["Extinction Survivor", "Survive Extinction Day."],
	"stars": ["Star Collector", "Earn every star on the Journey."],
	"streak": ["Unstoppable", "Win 5 battles in a row."],
	"eggs": ["Egg Enthusiast", "Hatch 100 eggs."],
	"shiny": ["Shiny Hunter", "Own 5 Shiny dinos."],
	"era": ["Era Expert", "Collect every dino of one era."],
	"complete": ["Completionist", "Collect every dino."],
	"trusted": ["Trusted Partner", "Raise a dino to Trusted Partner."],
	"legend": ["Legend Tamer", "Raise a dino to Legend."],
	"friendly": ["Friendly Rival", "Win 10 friend duels."],
}
const STREAK_TITLE_WINS := 5
const EGGS_TITLE := 100
const SHINY_TITLE := 5
const FRIEND_TITLE_WINS := 10


# --- Avatars --------------------------------------------------------------------------------

## The avatar to show: the chosen one while it's still unlocked, otherwise the partner (or the
## first dino in the party).
static func avatar_of(profile: PlayerProfile) -> String:
	if profile.avatar != "" and avatar_unlocked(profile, profile.avatar):
		return profile.avatar
	if profile.partner != &"" and profile.owns(profile.partner):
		return "dino:%s" % profile.partner
	if not profile.lineup.is_empty():
		return "dino:%s" % profile.lineup[0]
	return PROFESSAUR


static func avatar_unlocked(profile: PlayerProfile, avatar: String) -> bool:
	if avatar == PROFESSAUR:
		return true
	if avatar.begins_with("dino:"):
		return profile.owns(StringName(avatar.trim_prefix("dino:")))
	if avatar.begins_with("rival:"):
		return avatar.trim_prefix("rival:") in beaten_rivals(profile)
	return false


## Characters of the rivals the player has beaten at least once, in Journey order (Rory once).
static func beaten_rivals(profile: PlayerProfile) -> Array[String]:
	var characters: Array[String] = []
	for stage in Journey.stages():
		var character := String(stage.character)
		if character != "" and Journey.is_cleared(profile, stage) and not character in characters:
			characters.append(character)
	return characters


## Every avatar the player can pick: beaten rivals, the Professaur, then their dinos, rarest first.
static func avatar_choices(profile: PlayerProfile, catalog: DinoCatalog) -> Array[String]:
	var choices: Array[String] = []
	for character in beaten_rivals(profile):
		choices.append("rival:%s" % character)
	choices.append(PROFESSAUR)
	var owned := catalog.dinos.filter(func(d: DinoDef) -> bool: return profile.owns(d.id))
	owned.sort_custom(func(a: DinoDef, b: DinoDef) -> bool:
		return a.rarity > b.rarity if a.rarity != b.rarity else a.display_name < b.display_name)
	for dino in owned:
		choices.append("dino:%s" % dino.id)
	return choices


# --- Titles ---------------------------------------------------------------------------------

## Every title id: the fixed ones, then one per set.
static func titles() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(TITLES.keys())
	for set_id in DinoSets.ids():
		ids.append("set:%s" % set_id)
	return ids


static func title_text(id: String) -> String:
	if id.begins_with("set:"):
		return "%s Collector" % DinoSets.title_of(StringName(id.trim_prefix("set:")))
	return TITLES.get(id, TITLES[DEFAULT_TITLE])[0]


static func title_how(id: String) -> String:
	if id.begins_with("set:"):
		return "Collect the whole %s set." % DinoSets.title_of(StringName(id.trim_prefix("set:")))
	return TITLES.get(id, TITLES[DEFAULT_TITLE])[1]


static func title_unlocked(profile: PlayerProfile, catalog: DinoCatalog, id: String) -> bool:
	if id.begins_with("set:"):
		return DinoSets.complete(profile, StringName(id.trim_prefix("set:")))
	match id:
		"hunter":
			return true
		"champ_0", "champ_1", "champ_2":
			return Journey.chapter_cleared(profile, int(id.right(1)))
		"survivor":
			return Journey.chapter_cleared(profile, Journey.FINALE)
		"stars":
			return Journey.total_stars(profile) >= Journey.max_total_stars()
		"streak":
			return profile.best_win_streak >= STREAK_TITLE_WINS
		"eggs":
			return profile.eggs_hatched >= EGGS_TITLE
		"shiny":
			return profile.owned.values().count(true) >= SHINY_TITLE
		"era":
			for era in DinoDef.ERA_NAMES.size():
				if Goals.era_complete(profile, catalog, era):
					return true
			return false
		"complete":
			return profile.owned.size() >= catalog.dinos.size()
		"trusted":
			return _best_rank(profile) >= 4
		"legend":
			return _best_rank(profile) >= Mastery.RANKS.size()
		"friendly":
			return friend_wins(profile) >= FRIEND_TITLE_WINS
	return false


## The title to show: the chosen one while it's unlocked, otherwise Fossil Hunter.
static func title_of(profile: PlayerProfile, catalog: DinoCatalog) -> String:
	if profile.title != "" and title_unlocked(profile, catalog, profile.title):
		return profile.title
	return DEFAULT_TITLE


# --- Showcase and stats ---------------------------------------------------------------------

## The showcase's dinos (only ones still owned).
static func showcase_of(profile: PlayerProfile) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in profile.showcase:
		if profile.owns(id) and ids.size() < SHOWCASE_SIZE:
			ids.append(id)
	return ids


static func friend_wins(profile: PlayerProfile) -> int:
	var total := 0
	for entry in profile.friends:
		total += int(entry["wins"])
	return total


## The dino with the most battles (mastery), or null before any battle.
static func favorite_dino(profile: PlayerProfile, catalog: DinoCatalog) -> DinoDef:
	var best: DinoDef = null
	var most := 0
	for dino in catalog.dinos:
		var battles: int = Mastery.stats_of(profile, dino.id)["battles"]
		if battles > most:
			most = battles
			best = dino
	return best


## The rarest dino owned (a Shiny wins a tie), or null.
static func rarest_dino(profile: PlayerProfile, catalog: DinoCatalog) -> DinoDef:
	var best: DinoDef = null
	for dino in catalog.dinos:
		if not profile.owns(dino.id):
			continue
		if best == null or dino.rarity > best.rarity \
				or (dino.rarity == best.rarity and profile.is_shiny(dino.id) and not profile.is_shiny(best.id)):
			best = dino
	return best


## The ID's stats, as [label, value] rows.
static func stats(profile: PlayerProfile, catalog: DinoCatalog) -> Array:
	var shinies: int = profile.owned.values().count(true)
	var legends := 0
	for dino in catalog.dinos:
		legends += 1 if Mastery.rank_of(profile, dino.id) >= Mastery.RANKS.size() else 0
	var favorite := favorite_dino(profile, catalog)
	var rarest := rarest_dino(profile, catalog)
	return [
		["Dinos", "%d / %d" % [profile.owned.size(), catalog.dinos.size()] + ("  (%d Shiny)" % shinies if shinies > 0 else "")],
		["Journey stars", "%d / %d" % [Journey.total_stars(profile), Journey.max_total_stars()]],
		["Battles won", "%d of %d" % [profile.wins, profile.wins + profile.losses]],
		["Best win streak", str(profile.best_win_streak)],
		["Eggs hatched", str(profile.eggs_hatched)],
		["Favorite dino", favorite.display_name if favorite else "-"],
		["Rarest dino", ("Shiny " if rarest and profile.is_shiny(rarest.id) else "") + (rarest.display_name if rarest else "-")],
		["Legends", str(legends)],
		["Friend duels won", str(friend_wins(profile))],
	]


static func _best_rank(profile: PlayerProfile) -> int:
	var best := 0
	for id in profile.mastery:
		best = maxi(best, Mastery.rank_of(profile, StringName(id)))
	return best
