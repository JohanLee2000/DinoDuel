extends SceneTree
## Plays thousands of AI-vs-AI battles and prints balance stats.
##   godot --headless --path . --script res://tools/balance_sim.gd -- [battles]
##
## Each side brings 6 random dinos and the AI picks 3 within the point cap, like a real battle.
## Also pits the AI against one-note bots (always Bite, always Charge...) to check that no
## single action dominates the Bite/Charge/Brace triangle.

var catalog: DinoCatalog
var rng := RandomNumberGenerator.new()


func _init() -> void:
	catalog = DinoCatalog.load_default()
	rng.seed = 2026
	var battles := 2000
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		battles = int(args[0])

	_ai_vs_ai(battles)
	print("")
	print("AI vs one-note bots (AI win rate; should be well above 50%):")
	for kind in [BattleAction.Kind.BITE, BattleAction.Kind.CHARGE, BattleAction.Kind.BRACE]:
		print("  vs always-%-6s %5.1f%%" % [BattleAction.KIND_NAMES[kind], _ai_vs_bot(kind, battles / 4) * 100.0])
	print("Reference: perfect counter-player (Brace when it can, else Bite) vs always-Bite: %.1f%%" % [
			_exploiter_vs_biter(battles / 4) * 100.0])
	quit()


func _ai_vs_ai(battles: int) -> void:
	var picks := {}
	var wins := {}
	var action_counts: Array[int] = [0, 0, 0, 0]
	var total_turns := 0
	var meteor_battles := 0
	var draws := 0
	var bonus_games := {"era_bond": 0, "balanced": 0}
	var bonus_wins := {"era_bond": 0, "balanced": 0}
	for b in battles:
		var ais: Array[BattleAI] = [BattleAI.new(b * 2), BattleAI.new(b * 2 + 1)]
		var parties: Array = [ais[0].choose_party(_random_bring()), ais[1].choose_party(_random_bring())]
		var state := BattleEngine.create(parties[0], parties[1])
		while not state.is_over():
			var pair: Array[BattleAction] = [ais[0].choose_action(state, 0), ais[1].choose_action(state, 1)]
			for action in pair:
				action_counts[action.kind] += 1
			BattleEngine.resolve_turn(state, pair)
			ais[0].observe(pair[1])
			ais[1].observe(pair[0])
			_replace_knockouts(state, ais)
		total_turns += state.turn - 1
		if state.turn > BattleEngine.METEOR_START_TURN:
			meteor_battles += 1
		if state.winner == BattleState.DRAW:
			draws += 1
		for side in 2:
			var won := state.winner == side
			for dino in parties[side]:
				picks[dino.id] = picks.get(dino.id, 0) + 1
				wins[dino.id] = wins.get(dino.id, 0) + (1 if won else 0)
			for bonus in ["era_bond", "balanced"]:
				if state.side(side).get(bonus):
					bonus_games[bonus] += 1
					bonus_wins[bonus] += 1 if won else 0

	print("%d AI-vs-AI battles, avg %.1f turns, %.1f%% reached the meteor shower, %.1f%% draws" % [
			battles, float(total_turns) / battles, 100.0 * meteor_battles / battles, 100.0 * draws / battles])
	var total_actions := 0
	for n in action_counts:
		total_actions += n
	var mix := []
	for k in 4:
		mix.append("%s %.0f%%" % [BattleAction.KIND_NAMES[k], 100.0 * action_counts[k] / total_actions])
	print("Action mix: ", ", ".join(mix))
	for bonus in ["era_bond", "balanced"]:
		if bonus_games[bonus] > 0:
			print("Parties with %s: %d games, win rate %.1f%%" % [
					bonus, bonus_games[bonus], 100.0 * bonus_wins[bonus] / bonus_games[bonus]])
	print("")
	print("%-16s %-5s %-10s %-9s %6s %8s" % ["Dino", "Type", "Era", "Rarity", "Picks", "Win %"])
	for dino in catalog.dinos:
		var n: int = picks.get(dino.id, 0)
		var rate: float = 100.0 * wins.get(dino.id, 0) / n if n > 0 else 0.0
		print("%-16s %-5s %-10s %-9s %6d %7.1f%%" % [dino.display_name, dino.type_name(),
				dino.era_name(), dino.rarity_name(), n, rate])


func _ai_vs_bot(kind: BattleAction.Kind, battles: int) -> float:
	var ai_wins := 0
	for b in battles:
		var ai := BattleAI.new(b + 99999)
		var bot_picker := BattleAI.new(b + 55555)
		var parties: Array = [ai.choose_party(_random_bring()), bot_picker.choose_party(_random_bring())]
		var state := BattleEngine.create(parties[0], parties[1])
		var ais: Array[BattleAI] = [ai, bot_picker]
		while not state.is_over():
			var bot_action := BattleAction._make(kind)
			if not BattleEngine.is_legal(state, 1, bot_action):
				bot_action = BattleAction.bite()
			var pair: Array[BattleAction] = [ai.choose_action(state, 0), bot_action]
			BattleEngine.resolve_turn(state, pair)
			ai.observe(bot_action)
			_replace_knockouts(state, ais)
		if state.winner == 0:
			ai_wins += 1
	return float(ai_wins) / battles


## Upper bound for how badly always-Bite can be punished: the opponent knows it's coming.
func _exploiter_vs_biter(battles: int) -> float:
	var wins := 0
	for b in battles:
		var pickers: Array[BattleAI] = [BattleAI.new(b + 99999), BattleAI.new(b + 55555)]
		var state := BattleEngine.create(pickers[0].choose_party(_random_bring()),
				pickers[1].choose_party(_random_bring()))
		while not state.is_over():
			var mine := BattleAction.brace()
			if not BattleEngine.is_legal(state, 0, mine):
				mine = BattleAction.bite()
			var pair: Array[BattleAction] = [mine, BattleAction.bite()]
			BattleEngine.resolve_turn(state, pair)
			_replace_knockouts(state, pickers)
		if state.winner == 0:
			wins += 1
	return float(wins) / battles


func _replace_knockouts(state: BattleState, ais: Array[BattleAI]) -> void:
	for i in 2:
		if not state.is_over() and state.side(i).needs_replacement():
			BattleEngine.replace_active(state, i, ais[i].choose_replacement(state, i))


## Six random dinos that can field a legal party (re-rolled otherwise, like a player would).
func _random_bring() -> Array[DinoDef]:
	while true:
		var pool := catalog.dinos.duplicate()
		var brought: Array[DinoDef] = []
		while brought.size() < PartyRules.BRING_SIZE:
			brought.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		if PartyRules.has_valid_pick(brought):
			return brought
	return []
