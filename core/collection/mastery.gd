class_name Mastery
extends RefCounted
## Dino mastery (Jo, 2026-10-16): each dino you own builds its own history (battles, wins,
## counters, Journey bosses beaten) and earns ranks in order, each with a title. Rewards are
## cosmetic: the title in its Dex entry and a ribbon on its card from Fighter up. PlayerProfile
## keeps the numbers (`mastery`); the battle's recorded moves give the counters.

## [title, what earns it, needs]. Ranks are earned in order.
const RANKS := [
	["Recruit", "Fought its first battle.", {"battles": 1}],
	["Fighter", "Won 3 battles.", {"wins": 3}],
	["Veteran", "Won 10 battles.", {"wins": 10}],
	["Trusted Partner", "Helped defeat 3 Journey bosses.", {"bosses": 3}],
	["Legend", "Won 25 battles and countered 25 moves.", {"wins": 25, "counters": 25}],
]
const STATS: Array[String] = ["battles", "wins", "counters", "bosses"]
## What each stat is called in "Next: ..." lines, e.g. "win 25 battles (9/25)".
const NEED_TEXT := {"battles": "fight %d battle%s", "wins": "win %d battle%s", "counters": "counter %d move%s",
		"bosses": "help defeat %d Journey boss%s"}


## Its numbers so far: battles, wins, counters, bosses (all 0 for a dino that hasn't fought).
static func stats_of(profile: PlayerProfile, id: StringName) -> Dictionary:
	var saved: Dictionary = profile.mastery.get(String(id), {})
	var result := {}
	for stat in STATS:
		result[stat] = int(saved.get(stat, 0))
	return result


## How many ranks it has earned (0 to RANKS.size()).
static func rank_of(profile: PlayerProfile, id: StringName) -> int:
	var stats := stats_of(profile, id)
	var rank := 0
	while rank < RANKS.size() and _meets(stats, RANKS[rank][2]):
		rank += 1
	return rank


static func title_of(rank: int) -> String:
	return RANKS[rank - 1][0] if rank > 0 else ""


static func description_of(rank: int) -> String:
	return RANKS[rank - 1][1] if rank > 0 else ""


## "Next: Legend: win 25 battles (9/25) and counter 25 moves (14/25)", or "" at the top rank.
static func next_text(profile: PlayerProfile, id: StringName) -> String:
	var rank := rank_of(profile, id)
	if rank >= RANKS.size():
		return ""
	var stats := stats_of(profile, id)
	var parts: Array[String] = []
	var needs: Dictionary = RANKS[rank][2]
	for stat in needs:
		var amount: int = needs[stat]
		var plural := ("es" if stat == "bosses" else "s") if amount != 1 else ""
		parts.append((NEED_TEXT[stat] % [amount, plural]) + " (%d/%d)" % [mini(stats[stat], amount), amount])
	return "Next: %s: %s" % [RANKS[rank][0], " and ".join(parts)]


## After a finished battle: counts it for each of the party's dinos. `counters` is id -> how many
## of its moves beat the rival's (counters_in). Returns the ranks earned, as [{id, rank}].
static func record_battle(profile: PlayerProfile, party: Array[DinoDef], won: bool, boss: bool,
		counters: Dictionary) -> Array[Dictionary]:
	var ranked_up: Array[Dictionary] = []
	for dino in party:
		var before := rank_of(profile, dino.id)
		var stats := stats_of(profile, dino.id)
		stats["battles"] += 1
		stats["wins"] += 1 if won else 0
		stats["bosses"] += 1 if won and boss else 0
		stats["counters"] += int(counters.get(dino.id, 0))
		profile.mastery[String(dino.id)] = stats
		var after := rank_of(profile, dino.id)
		if after > before:
			ranked_up.append({"id": dino.id, "rank": after})
	return ranked_up


## Per dino id: how many turns its move beat the rival's (Bite > Charge > Brace > Bite). Replays
## the battle's recorded moves (BattleReplay events) on `state`, a fresh start of the same battle.
static func counters_in(state: BattleState, events: Array) -> Dictionary:
	var counts := {}
	for event in events:
		match int(event[0]):
			BattleReplay.TURN:
				var mine := int(event[1])
				var theirs := int(event[3])
				if beats(mine, theirs):
					var id := state.side(BattleReplay.PLAYER).active_dino().def.id
					counts[id] = int(counts.get(id, 0)) + 1
				var pair: Array[BattleAction] = [BattleReplay._action(mine, int(event[2])),
						BattleReplay._action(theirs, int(event[4]))]
				BattleEngine.resolve_turn(state, pair)
			BattleReplay.PLAYER_REPLACE:
				BattleEngine.replace_active(state, BattleReplay.PLAYER, int(event[1]))
			BattleReplay.RIVAL_REPLACE:
				BattleEngine.replace_active(state, BattleReplay.RIVAL, int(event[1]))
	return counts


## Bite beats Charge, Charge beats Brace, Brace beats Bite. Swaps never count.
static func beats(mine: int, theirs: int) -> bool:
	var swap := BattleAction.Kind.SWAP
	return mine != swap and theirs != swap and theirs == (mine + 1) % 3


static func _meets(stats: Dictionary, needs: Dictionary) -> bool:
	for stat in needs:
		if stats[stat] < needs[stat]:
			return false
	return true
