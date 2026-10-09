extends "res://tests/test_case.gd"

var catalog := DinoCatalog.load_default()


func _party(ids: Array) -> Array[DinoDef]:
	var defs: Array[DinoDef] = []
	for id in ids:
		defs.append(catalog.find(id))
	return defs


func _snapshot(state: BattleState) -> String:
	var parts: Array[String] = ["turn %d winner %d" % [state.turn, state.winner]]
	for i in 2:
		var side := state.side(i)
		var health: Array[int] = []
		for dino in side.party:
			health.append(dino.health)
		parts.append("side %d active %d hp %s" % [i, side.active, health])
	return " | ".join(parts)


## Plays like the battle screen does (player = an AI on autopilot), recording events, and stops
## after `stop_after` events. Returns [state, rival ai, events].
func _play_live(seed_value: int, stop_after: int) -> Array:
	var player := _party([&"t_rex", &"pteranodon", &"ichthyosaurus"])
	var rival := _party([&"triceratops", &"mosasaurus", &"plesiosaurus"])
	var state := BattleEngine.create(player, rival)
	var ai := BattleAI.new(seed_value)
	var autopilot := BattleAI.new(seed_value + 1)
	var events: Array = []
	while not state.is_over() and events.size() < stop_after:
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
		var mine := autopilot.choose_action(state, 0)
		var theirs := ai.choose_action(state, 1)
		var pair: Array[BattleAction] = [mine, theirs]
		BattleEngine.resolve_turn(state, pair)
		ai.observe(mine)
		autopilot.observe(theirs)
		events.append(BattleReplay.turn_event(mine, theirs))
	return [state, ai, events]


func test_replay_rebuilds_the_battle_and_the_ai() -> void:
	for stop_after in [1, 4, 9, 15]:
		var live: Array = _play_live(42, stop_after)
		var events: Array = JSON.parse_string(JSON.stringify(live[2]))  # as it comes back from the save
		var state := BattleEngine.create(_party([&"t_rex", &"pteranodon", &"ichthyosaurus"]),
				_party([&"triceratops", &"mosasaurus", &"plesiosaurus"]))
		var ai := BattleAI.new(42)
		BattleReplay.replay(state, ai, events)
		assert_eq(_snapshot(state), _snapshot(live[0]), "same battle after %d events" % stop_after)
		assert_eq(ai.rng.state, (live[1] as BattleAI).rng.state, "AI random numbers in step after %d" % stop_after)
		if not state.is_over() and not state.side(1).needs_replacement():
			assert_eq(ai.choose_action(state, 1).kind, (live[1] as BattleAI).choose_action(live[0], 1).kind,
					"AI makes the same next move after %d" % stop_after)


func test_full_battle_replays_to_the_same_winner() -> void:
	var live: Array = _play_live(7, 999)
	assert_true((live[0] as BattleState).is_over(), "the live battle finished")
	var state := BattleEngine.create(_party([&"t_rex", &"pteranodon", &"ichthyosaurus"]),
			_party([&"triceratops", &"mosasaurus", &"plesiosaurus"]))
	BattleReplay.replay(state, BattleAI.new(7), live[2])
	assert_eq(_snapshot(state), _snapshot(live[0]))


func test_battle_in_progress_survives_a_save() -> void:
	var p := PlayerProfile.new_game(21)
	p.battle = {"rival": "rory", "seed": 12345, "player": ["t_rex", "pteranodon", "ichthyosaurus"],
			"rival_party": ["triceratops", "mosasaurus", "plesiosaurus"], "coaching": false,
			"events": [[BattleReplay.TURN, 0, -1, 2, -1], [BattleReplay.RIVAL_REPLACE, 1]]}
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(JSON.stringify(loaded.battle), JSON.stringify(p.battle))
	var old_save := PlayerProfile.new_game(22).to_dict()
	old_save.erase("battle")
	assert_eq(PlayerProfile.from_dict(old_save, catalog).battle.size(), 0)
