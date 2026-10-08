extends "res://tests/test_case.gd"


func test_catalog_loads_all_dinos() -> void:
	var catalog := DinoCatalog.load_default()
	assert_eq(catalog.dinos.size(), 15)
	var ids := {}
	for dino in catalog.dinos:
		assert_false(ids.has(dino.id), "duplicate id %s" % dino.id)
		ids[dino.id] = true
		assert_true(dino.display_name != "", "%s has a name" % dino.id)
	assert_eq(catalog.find(&"t_rex").rarity, DinoDef.Rarity.LEGENDARY)


func test_starter_parties_get_both_bonuses() -> void:
	var catalog := DinoCatalog.load_default()
	for ids in [[&"coelophysis", &"eudimorphodon", &"nothosaurus"],
			[&"stegosaurus", &"rhamphorhynchus", &"ichthyosaurus"]]:
		var starter: Array[DinoDef] = []
		for id in ids:
			starter.append(catalog.find(id))
		assert_true(PartyRules.has_era_bond(starter), "%s era bond" % [ids])
		assert_true(PartyRules.is_balanced(starter), "%s balanced" % [ids])


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
