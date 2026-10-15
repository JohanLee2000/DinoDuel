extends "res://tests/test_case.gd"
## The Journey (docs/GAME_DESIGN.md): unlocks, stars, rewards, star chests, old saves, Alphas,
## the finale's early meteor, and the rivals' conditional habits.

var catalog := DinoCatalog.load_default()


func _stage(id: StringName) -> RivalDef:
	return Journey.find(id)


## Clears every stage up to (not including) `until`, with `stars` each.
func _clear_until(p: PlayerProfile, until: StringName, stars := 1) -> void:
	for stage in Journey.stages():
		if stage.id == until:
			return
		p.record_battle(true, stage, stars)


func test_stages_unlock_in_order() -> void:
	var p := PlayerProfile.new_game(1)
	assert_true(Journey.is_unlocked(p, _stage(&"rae")))
	assert_false(Journey.is_unlocked(p, _stage(&"fern")))
	assert_eq(Journey.next_stage(p).id, &"rae")
	p.record_battle(false, _stage(&"rae"))
	assert_false(Journey.is_unlocked(p, _stage(&"fern")), "a loss doesn't clear a stage")
	p.record_battle(true, _stage(&"rae"), 1)
	assert_true(Journey.is_unlocked(p, _stage(&"fern")))
	assert_false(Journey.chapter_unlocked(p, 1))
	_clear_until(p, &"pip")
	assert_true(Journey.chapter_cleared(p, 0))
	assert_true(Journey.chapter_unlocked(p, 1), "beating the boss opens the next era")
	assert_false(Journey.chapter_unlocked(p, 2))
	_clear_until(p, &"")
	assert_true(Journey.complete(p))
	assert_true(Journey.next_stage(p) == null)


func test_first_clear_then_replay_rewards() -> void:
	var p := PlayerProfile.new_game(1)
	var amber := p.amber
	var first := p.record_battle(true, _stage(&"rae"), 2)
	assert_true(first["first_clear"])
	assert_eq(first["clutches"], Economy.WIN_CLUTCHES)
	assert_eq(first["amber"], Economy.JOURNEY_WIN_AMBER[0] + Economy.JOURNEY_FIRST_CLEAR_AMBER[0])
	assert_eq(p.amber, amber + first["amber"])
	var replay := p.record_battle(true, _stage(&"rae"), 1)
	assert_false(replay["first_clear"])
	assert_eq(replay["amber"], Economy.REPLAY_AMBER)
	assert_eq(replay["clutches"], Economy.WIN_CLUTCHES, "replays still give the clutch")
	assert_eq(Journey.best_stars(p, _stage(&"rae")), 2, "a worse replay keeps the best")
	var better := p.record_battle(true, _stage(&"rae"), 3)
	assert_true(better["new_best"])
	assert_eq(Journey.best_stars(p, _stage(&"rae")), 3)
	var loss := p.record_battle(false, _stage(&"rae"))
	assert_eq([loss["amber"], loss["clutches"], loss["stars"]], [Economy.LOSS_AMBER, 0, 0])
	assert_eq(p.record_against(&"rae"), [3, 1])


func test_later_chapters_pay_more_and_bosses_give_rare_clutches() -> void:
	var p := PlayerProfile.new_game(1)
	_clear_until(p, &"rory_triassic")
	var boss := p.record_battle(true, _stage(&"rory_triassic"), 1)
	assert_eq(boss["rare_clutches"], Economy.BOSS_FIRST_CLEAR_RARE_CLUTCHES)
	assert_eq(boss["amber"], Economy.JOURNEY_WIN_AMBER[0], "a boss's bonus is the Rare clutch, not Amber")
	var pip := p.record_battle(true, _stage(&"pip"), 1)
	assert_eq(pip["amber"], Economy.JOURNEY_WIN_AMBER[1] + Economy.JOURNEY_FIRST_CLEAR_AMBER[1])
	assert_eq(p.record_battle(true, _stage(&"rory_triassic"), 1)["rare_clutches"], 0, "only the first clear")
	_clear_until(p, &"rory_finale")
	var rare := p.rare_clutches
	var finale := p.record_battle(true, _stage(&"rory_finale"), 3)
	assert_eq(finale["rare_clutches"], Economy.FINALE_FIRST_CLEAR_RARE_CLUTCHES)
	assert_eq(p.rare_clutches, rare + Economy.FINALE_FIRST_CLEAR_RARE_CLUTCHES)


func test_star_chests_open_once_each() -> void:
	var p := PlayerProfile.new_game(1)
	assert_false(Journey.chest_ready(p, 0, 0))
	_clear_until(p, &"cora", 3)
	assert_eq(Journey.chapter_stars(p, 0), 6)
	assert_true(Journey.chest_ready(p, 0, 0))
	assert_false(Journey.chest_ready(p, 0, 1))
	var amber := p.amber
	assert_true(Journey.claim_chest(p, 0, 0))
	assert_eq(p.amber, amber + Journey.STAR_CHESTS[0][1])
	assert_false(Journey.claim_chest(p, 0, 0), "only once")
	assert_false(Journey.any_chest_ready(p))
	_clear_until(p, &"pip", 3)
	var rare := p.rare_clutches
	assert_true(Journey.claim_chest(p, 0, 2), "18 stars")
	assert_eq(p.rare_clutches, rare + 1)
	assert_false(Journey.chest_ready(p, Journey.FINALE, 0), "the finale has no chests")


func test_stars_save_and_old_saves_carry_over() -> void:
	var p := PlayerProfile.new_game(5)
	p.record_battle(true, _stage(&"rae"), 3)
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(Journey.best_stars(loaded, _stage(&"rae")), 3)
	# A save from before the Journey: beaten rivals count as cleared with 1 star; old Rory doesn't.
	var old := PlayerProfile.new_game(6).to_dict()
	old.erase("journey_stars")
	old["rival_record"] = {"rae": [2, 1], "fern": [0, 3], "cora": [1, 0], "rory": [1, 0]}
	var migrated := PlayerProfile.from_dict(old, catalog)
	assert_eq(Journey.best_stars(migrated, _stage(&"rae")), 1)
	assert_eq(Journey.best_stars(migrated, _stage(&"cora")), 1)
	assert_false(Journey.is_cleared(migrated, _stage(&"fern")))
	assert_eq(migrated.journey_stars.size(), 2)
	assert_eq(Journey.next_stage(migrated).id, &"fern")


func test_journey_goals() -> void:
	var p := PlayerProfile.new_game(7)
	Goals.refresh_quests(p, 900)
	p.quests = [{"id": "win_hard", "progress": 0, "claimed": false}]
	var first := p.record_battle(true, _stage(&"rae"), 2)
	Goals.on_battle(p, {"won": true, "party": [], "turns": 10, "dinos_left": 2, "first_clear": first["first_clear"]})
	assert_eq(int(p.quests[0]["progress"]), 1, "a first clear counts")
	var again := p.record_battle(true, _stage(&"rae"), 2)
	Goals.on_battle(p, {"won": true, "party": [], "turns": 10, "dinos_left": 2, "first_clear": again["first_clear"]})
	assert_eq(int(p.quests[0]["progress"]), 1, "a replay doesn't")
	assert_false(Goals.achievement_unlocked(p, catalog, &"clear_triassic"))
	_clear_until(p, &"pip")
	assert_true(Goals.achievement_unlocked(p, catalog, &"clear_triassic"))
	assert_eq(Goals.achievement_target(catalog, &"star_collector"), 57)
	_clear_until(p, &"")
	for day in range(1000, 1030):
		var q := PlayerProfile.from_dict(p.to_dict(), catalog)
		q.quest_day = -1
		Goals.refresh_quests(q, day)
		for quest in q.quests:
			assert_true(quest["id"] != "win_hard", "no 'clear a new stage' quest once the Journey is done")


func test_alphas_are_stronger_and_always_play() -> void:
	var rex := catalog.find(&"t_rex")
	var others := [catalog.find(&"triceratops"), catalog.find(&"pteranodon")]
	var theirs := party([rex] + others)
	var state := BattleEngine.create(theirs, theirs, [&"t_rex"])
	var plain := state.side(0).party[0]
	var alpha := state.side(1).party[0]
	assert_false(plain.alpha)
	assert_true(alpha.alpha)
	assert_eq(alpha.attack, plain.attack + BattleEngine.ALPHA_ATTACK_BONUS)
	assert_eq(alpha.max_health, ceili(plain.max_health * (1.0 + BattleEngine.ALPHA_HEALTH_BONUS)))
	assert_eq(alpha.health, alpha.max_health)
	assert_true(state.clone().side(1).party[0].alpha, "clones keep it")
	assert_false(state.side(1).party[1].alpha, "only the named dino")


func test_finale_meteor_starts_early() -> void:
	var tough := party([make_dino(1, 5, 5, 60)])
	var state := BattleEngine.create(tough, tough, [], 3)
	var meteors := 0
	for turn in 3:
		var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
		meteors += events_of(events, "meteor").size()
		assert_eq(meteors, 0 if turn < 2 else 2, "turn %d" % (turn + 1))
	var finale := _stage(&"rory_finale")
	assert_eq(finale.start_battle(tough, tough).meteor_turn, finale.meteor_turn)
	assert_eq(BattleEngine.create(tough, tough).meteor_turn, BattleEngine.METEOR_START_TURN)


## How often `ai` picks `kind` over 200 seeds, after `setup` puts it in the right situation.
func _rate(habits: Array[StringName], kind: BattleAction.Kind, setup: Callable) -> float:
	var hits := 0
	for seed_value in 200:
		var ai := BattleAI.new(seed_value)
		ai.temperature = 0.15
		ai.learns_habits = false
		ai.habits = habits
		var state: BattleState = setup.call(ai)
		if ai.choose_action(state, 1).kind == kind:
			hits += 1
	return hits / 200.0


func _even_state() -> BattleState:
	var mine := party([make_dino(6, 1, 5, 20), make_dino(6, 1, 5, 20, DinoDef.DinoType.SEA)])
	var theirs := party([make_dino(6, 1, 5, 20), make_dino(6, 1, 5, 20, DinoDef.DinoType.SEA)])
	return BattleEngine.create(mine, theirs)


func test_habits_change_how_rivals_play() -> void:
	var none: Array[StringName] = []
	var cases := [
		# [habit, the move it should favor, setup]
		[&"brace_after_hit", BattleAction.Kind.BRACE, func(ai: BattleAI) -> BattleState:
			var state := _even_state()
			ai.choose_action(state, 1)
			state.side(1).active_dino().health -= 6
			return state],
		[&"brace_then_charge", BattleAction.Kind.CHARGE, func(ai: BattleAI) -> BattleState:
			var state := _even_state()
			ai._my_last_kind = BattleAction.Kind.BRACE
			ai._last_active = 0
			return state],
		[&"bite_when_hurt", BattleAction.Kind.BITE, func(ai: BattleAI) -> BattleState:
			# A hurt dino often bites anyway, so start from a rival that leans toward Charging.
			ai.biases = [0.0, 0.6, 0.0, 0.0]
			var state := _even_state()
			state.side(1).active_dino().health = 8
			return state],
		[&"copy_last", BattleAction.Kind.CHARGE, func(ai: BattleAI) -> BattleState:
			ai.observe(BattleAction.charge())
			return _even_state()],
		[&"counter_last", BattleAction.Kind.BRACE, func(ai: BattleAI) -> BattleState:
			ai.observe(BattleAction.bite())
			return _even_state()],
		[&"swap_on_disadvantage", BattleAction.Kind.SWAP, func(ai: BattleAI) -> BattleState:
			# Their Land active has the edge on our Sky dino; our Sea dino on the bench doesn't lose to it.
			var mine := party([make_dino(6, 1, 5, 20)])
			var theirs := party([make_dino(6, 1, 5, 20, DinoDef.DinoType.SKY), make_dino(6, 1, 5, 20, DinoDef.DinoType.SEA)])
			return BattleEngine.create(mine, theirs)],
	]
	for case in cases:
		var habit: StringName = case[0]
		var with_habit := _rate([habit] as Array[StringName], case[1], case[2])
		var without := _rate(none, case[1], case[2])
		assert_true(with_habit >= 0.5, "%s: favored move picked %.0f%% of the time" % [habit, with_habit * 100])
		assert_true(with_habit > without + 0.2, "%s: %.0f%% with vs %.0f%% without" % [habit, with_habit * 100, without * 100])


## A battle against a rival with habits replays to exactly the same state and AI (for resuming).
func test_habit_rivals_replay_exactly() -> void:
	var stage := _stage(&"vera")
	var player := party([catalog.find(&"t_rex"), catalog.find(&"pteranodon"), catalog.find(&"ichthyosaurus")])
	var rival_party := stage.pick_party(stage.make_ai(99))
	var state := stage.start_battle(player, rival_party)
	var ai := stage.make_ai(99)
	var autopilot := BattleAI.new(100)
	var events: Array = []
	while not state.is_over() and events.size() < 12:
		if state.side(1).needs_replacement():
			var index := ai.choose_replacement(state, 1)
			BattleEngine.replace_active(state, 1, index)
			events.append([BattleReplay.RIVAL_REPLACE, index])
			continue
		if state.side(0).needs_replacement():
			var index := autopilot.choose_replacement(state, 0)
			BattleEngine.replace_active(state, 0, index)
			events.append([BattleReplay.PLAYER_REPLACE, index])
			continue
		var rival_action := ai.choose_action(state, 1)
		var player_action := autopilot.choose_action(state, 0)
		BattleEngine.resolve_turn(state, actions(player_action, rival_action))
		ai.observe(player_action)
		autopilot.observe(rival_action)
		events.append(BattleReplay.turn_event(player_action, rival_action))
	var resumed := stage.start_battle(player, rival_party)
	var resumed_ai := stage.make_ai(99)
	BattleReplay.replay(resumed, resumed_ai, events)
	assert_eq(resumed.turn, state.turn)
	for i in 2:
		for d in state.side(i).party.size():
			assert_eq(resumed.side(i).party[d].health, state.side(i).party[d].health)
	if not state.is_over() and not state.side(1).needs_replacement() and not state.side(0).needs_replacement():
		assert_eq(resumed_ai.choose_action(resumed, 1).kind, ai.choose_action(state, 1).kind, "same next move")
