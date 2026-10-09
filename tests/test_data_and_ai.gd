extends "res://tests/test_case.gd"


func test_catalog_loads_all_dinos() -> void:
	var catalog := DinoCatalog.load_default()
	var ids := {}
	for dino in catalog.dinos:
		assert_false(ids.has(dino.id), "duplicate id %s" % dino.id)
		ids[dino.id] = true
		for field in ["display_name", "epithet", "group", "size_text", "flavor_text"]:
			assert_true(String(dino.get(field)) != "", "%s is missing %s" % [dino.id, field])
	# Every dino data file must be listed in the catalog, or it never appears in the game.
	for file in DirAccess.get_files_at("res://data/dinos"):
		if file.ends_with(".tres"):
			assert_true(ids.has(StringName(file.get_basename())), "%s isn't in the catalog" % file)
	assert_eq(catalog.find(&"t_rex").rarity, DinoDef.Rarity.LEGENDARY)


func test_starter_parties_get_bonuses() -> void:
	var catalog := DinoCatalog.load_default()
	var defs := func(ids: Array) -> Array[DinoDef]:
		var out: Array[DinoDef] = []
		for id in ids:
			out.append(catalog.find(id))
		return out
	var triassic: Array[DinoDef] = defs.call([&"coelophysis", &"eudimorphodon", &"tanystropheus"])
	assert_true(PartyRules.has_era_bond(triassic), "Triassic starter trio has an era bond")
	assert_true(PartyRules.is_balanced(triassic), "Triassic starter trio is balanced")
	var basics: Array[DinoDef] = defs.call([&"protoceratops", &"rhamphorhynchus", &"hesperornis"])
	assert_true(PartyRules.is_balanced(basics), "the basics alone can make a balanced party")
	for id in Economy.STARTER_BASICS:
		assert_eq(catalog.find(id).rarity, DinoDef.Rarity.COMMON, "%s is a Common" % id)


func test_rival_roster_is_valid() -> void:
	var rivals := RivalDef.load_roster()
	assert_true(rivals.size() >= 5)
	var ids := {}
	var last_difficulty := 0
	for rival in rivals:
		assert_false(ids.has(rival.id), "duplicate rival %s" % rival.id)
		ids[rival.id] = true
		assert_eq(rival.brings.size(), PartyRules.BRING_SIZE, "%s brings 6" % rival.id)
		assert_true(PartyRules.has_valid_pick(rival.brings, rival.point_cap), "%s can field a party" % rival.id)
		assert_true(rival.difficulty >= last_difficulty, "roster is ordered easiest first")
		last_difficulty = rival.difficulty


func test_ai_picks_legal_party() -> void:
	var rival := load("res://data/rivals/rory.tres") as RivalDef
	var ai := rival.make_ai(7)
	var picked := ai.choose_party(rival.brings, rival.point_cap)
	assert_eq(PartyRules.validate(picked, rival.point_cap), "")


func test_ai_battles_are_legal_finite_and_deterministic() -> void:
	var first := _ai_battle(42)
	var second := _ai_battle(42)
	assert_eq(first, second, "same seed, same battle")
	for seed_value in range(1, 30):
		_ai_battle(seed_value)


## Plays a full AI-vs-AI battle and returns its action log.
func _ai_battle(seed_value: int) -> String:
	var catalog := DinoCatalog.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ais: Array[BattleAI] = [BattleAI.new(seed_value), BattleAI.new(seed_value + 1000)]
	var parties: Array = []
	for i in 2:
		var brought: Array[DinoDef] = []
		while not PartyRules.has_valid_pick(brought):
			var pool := catalog.dinos.duplicate()
			brought.clear()
			while brought.size() < PartyRules.BRING_SIZE:
				brought.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		parties.append(ais[i].choose_party(brought))
		assert_eq(PartyRules.validate(parties[i]), "", "seed %d side %d party" % [seed_value, i])
	var state := BattleEngine.create(parties[0], parties[1])
	var history := ""
	while not state.is_over():
		if state.turn > 60:
			_fail("seed %d: battle did not end" % seed_value)
			break
		var pair: Array[BattleAction] = []
		for i in 2:
			var action := ais[i].choose_action(state, i)
			assert_true(BattleEngine.is_legal(state, i, action), "seed %d: illegal %s" % [seed_value, action])
			pair.append(action)
		history += "%s/%s " % [pair[0], pair[1]]
		BattleEngine.resolve_turn(state, pair)
		ais[0].observe(pair[1])
		ais[1].observe(pair[0])
		for i in 2:
			if not state.is_over() and state.side(i).needs_replacement():
				BattleEngine.replace_active(state, i, ais[i].choose_replacement(state, i))
	return history + "winner %d" % state.winner


## Uses fixed test dinos (not the catalog) so stat tuning can't change what's being tested:
## an even matchup where a cancelled Charge costs a full Bite of damage.
func test_ai_punishes_predictable_biting() -> void:
	var mine := party([make_dino(6, 1, 5, 15), make_dino(6, 1, 5, 15, DinoDef.DinoType.SKY)])
	var theirs := party([make_dino(6, 1, 5, 15), make_dino(6, 1, 5, 15, DinoDef.DinoType.SKY)])
	var state := BattleEngine.create(mine, theirs)
	var charges := 0
	for seed_value in 100:
		var ai := BattleAI.new(seed_value)
		for i in 10:
			ai.observe(BattleAction.bite())
		if ai.choose_action(state, 0).kind == BattleAction.Kind.CHARGE:
			charges += 1
	assert_true(charges < 10, "charged into a known biter %d/100 times" % charges)


## Easy rivals keep their habits readable: they don't adapt to yours.
func test_ai_without_habit_learning_ignores_habits() -> void:
	var mine := party([make_dino(6, 1, 5, 15), make_dino(6, 1, 5, 15, DinoDef.DinoType.SKY)])
	var theirs := party([make_dino(6, 1, 5, 15), make_dino(6, 1, 5, 15, DinoDef.DinoType.SKY)])
	var state := BattleEngine.create(mine, theirs)
	for seed_value in 20:
		var fresh := BattleAI.new(seed_value)
		fresh.learns_habits = false
		var watched := BattleAI.new(seed_value)
		watched.learns_habits = false
		for i in 10:
			watched.observe(BattleAction.bite())
		assert_eq(watched.choose_action(state, 0).kind, fresh.choose_action(state, 0).kind)


func test_easiest_rival_does_not_adapt() -> void:
	var rivals := RivalDef.load_roster()
	assert_false(rivals[0].learns_habits, "%s should not adapt" % rivals[0].id)
	assert_true(rivals[rivals.size() - 1].learns_habits, "the hardest rival adapts")
