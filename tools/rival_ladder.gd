extends SceneTree
## How often a decent player (strong AI) with a new player's party beats each rival, once per
## starter partner. Checks the difficulty ladder stays easy-to-hard. About 300 battles per cell.
##     "$GODOT" --headless --path . --script res://tools/rival_ladder.gd


func _init() -> void:
	var catalog := DinoCatalog.load_default()
	var rivals := RivalDef.load_roster()
	var header := "%-16s" % "Partner"
	for rival in rivals:
		header += "%14s" % rival.display_name
	print(header)
	for partner_id in Economy.STARTER_PARTNERS:
		var party: Array[DinoDef] = []
		for id in Economy.STARTER_BASICS + [partner_id]:
			party.append(catalog.find(id))
		var line := "%-16s" % catalog.find(partner_id).display_name
		for rival in rivals:
			line += "%13.0f%%" % (100.0 * _win_rate(party, rival, 300))
		print(line)
	quit()


func _win_rate(party: Array[DinoDef], rival: RivalDef, battles: int) -> float:
	var wins := 0
	for b in battles:
		var player := BattleAI.new(b * 7 + 1)
		var ai := rival.make_ai(b * 7 + 3)
		var state := BattleEngine.create(player.choose_party(party), ai.choose_party(rival.brings, rival.point_cap))
		var ais: Array[BattleAI] = [player, ai]
		while not state.is_over():
			var pair: Array[BattleAction] = [player.choose_action(state, 0), ai.choose_action(state, 1)]
			BattleEngine.resolve_turn(state, pair)
			player.observe(pair[1])
			ai.observe(pair[0])
			for i in 2:
				if not state.is_over() and state.side(i).needs_replacement():
					BattleEngine.replace_active(state, i, ais[i].choose_replacement(state, i))
		if state.winner == 0:
			wins += 1
	return float(wins) / battles
