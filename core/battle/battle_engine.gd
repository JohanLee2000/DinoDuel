class_name BattleEngine
extends RefCounted
## The Party Battle rules. Pure functions over BattleState with no UI or randomness, so the
## same code can drive AI battles, balance simulations, tests, and server-side PvP later.
##
## resolve_turn() mutates the state and returns a list of events (plain Dictionaries) that
## the UI plays back as animations, similar to an action log in Redux.

const ADVANTAGE_MULTIPLIER := 1.5
const CHARGE_MULTIPLIER := 2.0
const BENCH_HEAL := 1
## From this turn on, a meteor shower hits both active dinos each turn so battles always end.
## It can bring a dino down to 1 HP but never knocks one out by itself.
const METEOR_START_TURN := 20


static func create(player_party: Array[DinoDef], opponent_party: Array[DinoDef]) -> BattleState:
	var state := BattleState.new()
	state.sides.append(BattleSide.from_party(player_party))
	state.sides.append(BattleSide.from_party(opponent_party))
	return state


static func has_advantage(attacker: Combatant, defender: Combatant) -> bool:
	return DinoDef.type_beats(attacker.def.dino_type, defender.def.dino_type)


static func damage(attacker: Combatant, defender: Combatant, is_charge: bool) -> int:
	var raw := float(attacker.attack)
	if has_advantage(attacker, defender):
		raw *= ADVANTAGE_MULTIPLIER
	if is_charge:
		raw *= CHARGE_MULTIPLIER
	return maxi(1, floori(raw) - defender.defense)


static func legal_actions(state: BattleState, side_index: int) -> Array[BattleAction]:
	var side := state.side(side_index)
	var actions: Array[BattleAction] = [BattleAction.bite(), BattleAction.charge()]
	if not side.active_dino().braced_last_turn:
		actions.append(BattleAction.brace())
	for i in side.bench():
		actions.append(BattleAction.swap(i))
	return actions


static func is_legal(state: BattleState, side_index: int, action: BattleAction) -> bool:
	for legal in legal_actions(state, side_index):
		if legal.equals(action):
			return true
	return false


## Resolves one turn. actions[0] is the player's, actions[1] the opponent's.
static func resolve_turn(state: BattleState, actions: Array[BattleAction]) -> Array[Dictionary]:
	assert(not state.is_over(), "Battle is already over")
	assert(not state.side(0).needs_replacement() and not state.side(1).needs_replacement(),
			"Replace knocked-out dinos before resolving a turn")
	for i in 2:
		assert(is_legal(state, i, actions[i]), "Illegal action %s for side %d" % [actions[i], i])

	var events: Array[Dictionary] = []
	events.append({"type": "turn_start", "turn": state.turn,
			"actions": [actions[0].kind, actions[1].kind]})

	# 1. Swaps go first.
	for i in 2:
		if actions[i].kind == BattleAction.Kind.SWAP:
			var side := state.side(i)
			var from := side.active
			side.active_dino().braced_last_turn = false
			side.active = actions[i].swap_to
			events.append({"type": "swap", "side": i, "from": from, "to": side.active})

	# 2. Braces go up.
	var bracing: Array[bool] = [false, false]
	for i in 2:
		if actions[i].kind == BattleAction.Kind.BRACE:
			bracing[i] = true
			events.append({"type": "brace", "side": i})

	# 3. Bites, fastest first. A blocked Bite triggers the bracer's counter-bite.
	var bitten: Array[bool] = [false, false]
	for group in _speed_groups(state, actions, BattleAction.Kind.BITE):
		var hits: Array[Dictionary] = []
		for i in group:
			var attacker := state.side(i).active_dino()
			var target := state.side(BattleState.other(i)).active_dino()
			if attacker.is_knocked_out() or target.is_knocked_out():
				continue
			if bracing[BattleState.other(i)]:
				events.append({"type": "blocked", "side": BattleState.other(i)})
				hits.append(_hit(BattleState.other(i), "counter", target, attacker, false))
			else:
				hits.append(_hit(i, "bite", attacker, target, false))
				bitten[BattleState.other(i)] = true
		_apply_hits(state, hits, events)

	# 4. Charges, fastest first. Cancelled if the charger was bitten this turn.
	for group in _speed_groups(state, actions, BattleAction.Kind.CHARGE):
		var hits: Array[Dictionary] = []
		for i in group:
			var attacker := state.side(i).active_dino()
			var target := state.side(BattleState.other(i)).active_dino()
			if attacker.is_knocked_out() or target.is_knocked_out():
				continue
			if bitten[i]:
				events.append({"type": "charge_cancelled", "side": i})
				continue
			var hit := _hit(i, "charge", attacker, target, true)
			hit["through_brace"] = bracing[BattleState.other(i)]
			hits.append(hit)
		_apply_hits(state, hits, events)

	_end_turn(state, actions, events)
	return events


## Puts a new active dino in after a knockout. Free; doesn't use up a turn.
static func replace_active(state: BattleState, side_index: int, party_index: int) -> Array[Dictionary]:
	var side := state.side(side_index)
	assert(side.needs_replacement(), "Side %d has no knocked-out active dino" % side_index)
	assert(party_index in side.bench(), "Dino %d can't come in" % party_index)
	var from := side.active
	side.active = party_index
	return [{"type": "replace", "side": side_index, "from": from, "to": party_index}]


static func _hit(side_index: int, kind: String, attacker: Combatant, target: Combatant,
		is_charge: bool) -> Dictionary:
	return {
		"type": kind,
		"side": side_index,
		"target_side": BattleState.other(side_index),
		"damage": damage(attacker, target, is_charge),
		"advantage": has_advantage(attacker, target),
	}


## Applies a group of hits that land at the same instant (speed ties), then reports KOs.
static func _apply_hits(state: BattleState, hits: Array[Dictionary], events: Array[Dictionary]) -> void:
	for hit in hits:
		var target := state.side(hit["target_side"]).active_dino()
		target.health = maxi(0, target.health - hit["damage"])
		hit["health_after"] = target.health
		events.append(hit)
	for hit in hits:
		var target_side := state.side(hit["target_side"])
		if target_side.active_dino().is_knocked_out() and not _ko_reported(events, hit["target_side"], target_side.active):
			events.append({"type": "ko", "side": hit["target_side"], "index": target_side.active})


static func _ko_reported(events: Array[Dictionary], side_index: int, party_index: int) -> bool:
	for event in events:
		if event["type"] == "ko" and event["side"] == side_index and event["index"] == party_index:
			return true
	return false


## Sides using `kind` this turn, grouped by speed (fastest first). Equal speeds share a group
## and hit simultaneously.
static func _speed_groups(state: BattleState, actions: Array[BattleAction], kind: BattleAction.Kind) -> Array:
	var users: Array[int] = []
	for i in 2:
		if actions[i].kind == kind:
			users.append(i)
	if users.size() < 2:
		return [users] if users.size() == 1 else []
	var speed_0 := state.side(0).active_dino().speed
	var speed_1 := state.side(1).active_dino().speed
	if speed_0 == speed_1:
		return [[0, 1]]
	return [[0], [1]] if speed_0 > speed_1 else [[1], [0]]


static func _end_turn(state: BattleState, actions: Array[BattleAction], events: Array[Dictionary]) -> void:
	if state.turn >= METEOR_START_TURN:
		var meteor := state.turn - METEOR_START_TURN + 1
		var hits: Array[Dictionary] = []
		for i in 2:
			var dino := state.side(i).active_dino()
			var dealt := mini(meteor, dino.health - 1)
			if dealt > 0:
				hits.append({"type": "meteor", "side": i, "target_side": i, "damage": dealt, "advantage": false})
		_apply_hits(state, hits, events)

	for i in 2:
		var side := state.side(i)
		side.active_dino().braced_last_turn = actions[i].kind == BattleAction.Kind.BRACE
		for b in side.bench():
			var dino := side.party[b]
			dino.braced_last_turn = false
			if dino.health < dino.max_health:
				dino.health = mini(dino.max_health, dino.health + BENCH_HEAL)
				events.append({"type": "heal", "side": i, "index": b, "amount": BENCH_HEAL,
						"health_after": dino.health})

	var lost: Array[bool] = [state.side(0).is_defeated(), state.side(1).is_defeated()]
	if lost[0] and lost[1]:
		state.winner = BattleState.DRAW
	elif lost[0]:
		state.winner = 1
	elif lost[1]:
		state.winner = 0
	if state.is_over():
		events.append({"type": "battle_end", "winner": state.winner})
	state.turn += 1
