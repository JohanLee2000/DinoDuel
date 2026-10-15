extends SceneTree
## Simulated players on the Journey (docs/GAME_DESIGN.md, "Difficulty"). Each one starts like a new
## player (the starters, a partner, the starter clutch), plays the stages in order and retries until
## it wins, hatches everything it earns, checks in daily, claims its Goals and star chests, and
## spends spare Amber on clutches. Against each rival it brings its best 3 from what it owns,
## favoring type edges against the rival's 6, and plays like a decent player (a strong AI).
##
## On reaching a stage it first plays TRIALS practice battles (no rewards) to measure its chance of
## winning with the collection it has then. Prints one JSON line per simulated player;
## tools/journey_report.py runs several of these in parallel and sums them up.
##     "$GODOT" --headless --path . --script res://tools/journey_sim.gd -- <players> <first seed> [trials]

## How many battles an engaged player plays per day (for the daily check-in and quests).
const BATTLES_PER_DAY := 6
## Daily quests, roughly: an engaged player finishes them (Amber + the bonus clutch).
const DAILY_QUEST_AMBER := 110
const MAX_ATTEMPTS := 80
## The pool the player picks its 3 from: its strongest dinos of each type.
const POOL_PER_TYPE := 4

var catalog: DinoCatalog
## Where eggs come from: source -> clutches (Rare clutches count as one), and Amber per source,
## over the first LEDGER_BATTLES battles.
const LEDGER_BATTLES := 30
var _ledger := {}
## Dinos owned at the start of these days.
const SAMPLE_DAYS: Array[int] = [3, 7, 14, 30]
var _owned_on := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var players := int(args[0]) if args.size() > 0 else 4
	var first_seed := int(args[1]) if args.size() > 1 else 1
	var trials := int(args[2]) if args.size() > 2 else 12
	catalog = DinoCatalog.load_default()
	for i in players:
		print(JSON.stringify(_play_journey(first_seed + i, trials)))
	quit()


func _play_journey(seed_value: int, trials: int) -> Dictionary:
	_ledger = {}
	_owned_on = {}
	var profile := PlayerProfile.new_game(seed_value)
	var partner: StringName = Economy.STARTER_PARTNERS[seed_value % Economy.STARTER_PARTNERS.size()]
	profile.choose_partner(partner)
	_hatch_all(profile)
	var battles := 0
	var day := 0
	var results: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	profile.claim_daily(day)
	for stage in Journey.stages():
		var wins := 0
		for t in trials:
			if _battle(profile, stage, rng.randi())[0]:
				wins += 1
		var entry := {"id": String(stage.id), "p": float(wins) / trials, "owned": profile.owned.size(),
				"day": day, "battles": battles, "attempts": 0}
		var won := false
		while not won and entry["attempts"] < MAX_ATTEMPTS:
			var result := _battle(profile, stage, rng.randi())
			won = result[0]
			var counting := battles < LEDGER_BATTLES
			_track(profile, "battles", counting, func() -> void: profile.record_battle(won, stage, result[1]))
			entry["attempts"] += 1
			battles += 1
			if battles == 1:
				_track(profile, "first steps", counting, func() -> void: profile.clutches += Economy.FIRST_STEPS_CLUTCHES)
			if battles % BATTLES_PER_DAY == 0:
				day += 1
				if day in SAMPLE_DAYS:
					_owned_on[str(day)] = profile.owned.size()
				_track(profile, "check-in", counting, func() -> void: profile.claim_daily(day))
				_track(profile, "daily quests", counting, func() -> void:
					profile.amber += DAILY_QUEST_AMBER
					profile.clutches += Goals.QUEST_BONUS_CLUTCHES)
			_claim_everything(profile, counting)
			_track(profile, "bought", counting, func() -> void:
				while profile.buy_clutch():
					pass)
			_hatch_all(profile)
		if not won:
			# Stuck: record it and carry on as if cleared, to keep measuring the later stages.
			entry["stuck"] = true
			profile.journey_stars[String(stage.id)] = 1
		results.append(entry)
	return {"seed": seed_value, "partner": String(partner), "battles": battles, "days": day,
			"owned": profile.owned.size(), "stages": results, "ledger": _ledger,
			"owned_on": _owned_on}


## Runs `action` and, when `counting`, adds what it gave to the ledger under `source`.
func _track(profile: PlayerProfile, source: String, counting: bool, action: Callable) -> void:
	var before := [profile.clutches + profile.rare_clutches, profile.amber]
	action.call()
	if counting:
		var entry: Array = _ledger.get(source, [0, 0])
		entry[0] += profile.clutches + profile.rare_clutches - before[0]
		entry[1] += profile.amber - before[1]
		_ledger[source] = entry


## One battle against `stage` with the player's best 3. Returns [won, dinos left].
func _battle(profile: PlayerProfile, stage: RivalDef, seed_value: int) -> Array:
	var player := BattleAI.new(seed_value)
	var rival := stage.make_ai(seed_value + 1)
	var state := stage.start_battle(_pick(profile, stage, seed_value), stage.pick_party(rival))
	var ais: Array[BattleAI] = [player, rival]
	while not state.is_over():
		var pair: Array[BattleAction] = [player.choose_action(state, 0), rival.choose_action(state, 1)]
		BattleEngine.resolve_turn(state, pair)
		player.observe(pair[1])
		rival.observe(pair[0])
		for i in 2:
			if not state.is_over() and state.side(i).needs_replacement():
				BattleEngine.replace_active(state, i, ais[i].choose_replacement(state, i))
	var left := 0
	for dino in state.side(0).party:
		if not dino.is_knocked_out():
			left += 1
	return [state.winner == 0, left]


## The player's 3: the best-scoring legal party from its strongest dinos of each type, with a bonus
## for type edges against the rival's 6 (the player sees them before picking).
func _pick(profile: PlayerProfile, stage: RivalDef, seed_value: int) -> Array[DinoDef]:
	var owned: Array[DinoDef] = []
	for id in profile.owned:
		owned.append(catalog.find(id))
	var pool: Array[DinoDef] = []
	for type in 3:
		var of_type := owned.filter(func(d: DinoDef) -> bool: return d.dino_type == type)
		of_type.sort_custom(func(a: DinoDef, b: DinoDef) -> bool: return _power(a) > _power(b))
		pool.append_array(of_type.slice(0, POOL_PER_TYPE))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Array[DinoDef] = []
	var best_score := -INF
	for combo in BattleAI._combinations(pool, PartyRules.PARTY_SIZE):
		if PartyRules.validate(combo) != "":
			continue
		var score := BattleAI.party_strength(combo) + rng.randf() * 3.0
		for mine in combo:
			for theirs in stage.brings:
				if DinoDef.type_beats(mine.dino_type, theirs.dino_type):
					score += 1.5
				elif DinoDef.type_beats(theirs.dino_type, mine.dino_type):
					score -= 1.5
		if score > best_score:
			best_score = score
			best = combo
	return best


static func _power(dino: DinoDef) -> float:
	return dino.attack * 2.0 + dino.defense * 3.0 + dino.health * 0.6 + dino.speed * 0.3


func _hatch_all(profile: PlayerProfile) -> void:
	while profile.clutches > 0:
		profile.hatch_clutch(catalog)
	while profile.rare_clutches > 0:
		profile.hatch_clutch(catalog, true)


func _claim_everything(profile: PlayerProfile, counting := false) -> void:
	_track(profile, "milestones", counting, func() -> void:
		for i in Goals.MILESTONES.size():
			Goals.claim_milestone(profile, i))
	_track(profile, "eras", counting, func() -> void:
		for era in DinoDef.ERA_NAMES.size():
			Goals.claim_era(profile, catalog, era))
	_track(profile, "sets", counting, func() -> void:
		for id in DinoSets.ids():
			DinoSets.claim(profile, id))
	_track(profile, "achievements", counting, func() -> void:
		for id in Goals.ACHIEVEMENTS:
			Goals.claim_achievement(profile, catalog, id))
	_track(profile, "star chests", counting, func() -> void:
		for chapter in Journey.FINALE:
			for index in Journey.STAR_CHESTS.size():
				Journey.claim_chest(profile, chapter, index))
