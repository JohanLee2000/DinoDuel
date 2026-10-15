class_name BattleAI
extends RefCounted
## Picks actions for one side without seeing the other side's choice.
##
## Each turn it simulates every pair of (my action, their action) one turn ahead, guesses how
## likely the opponent is to pick each action, then samples its own action with a softmax so it
## stays unpredictable. It also remembers which actions the opponent has been using (call
## observe() after every turn), so a player who always Bites gets punished. Personality biases
## nudge it toward a style (e.g. a rival who loves to Charge), which gives players a habit to
## learn and exploit in return. Conditional habits (HABITS, set from RivalDef.habits) are readable
## patterns on top, like "Braces right after taking a hit" (the Journey, Jo 2026-10-15).

## How many observed turns it takes for the opponent's habits to count as much as reasoning.
const HABIT_TRUST_TURNS := 3.0
## Never trust habits completely, so the AI can't be baited forever.
const MAX_HABIT_WEIGHT := 0.85
## Starting count for each action kind, so nothing is ruled out before the opponent has acted.
const HABIT_PRIOR := 0.25
const WIN_BONUS := 1.0
## Party picks favor covering more types (per extra type), so one type-counter can't sweep a team.
const TYPE_SPREAD_BONUS := 3.0

## Conditional habits: when the condition holds, that move gets HABIT_PULL added to its score.
##   brace_after_hit       Braces right after its active dino took damage
##   brace_then_charge     Charges right after Bracing
##   bite_when_hurt        Bites when its active dino is at half Health or less
##   copy_last             Copies the opponent's last move (not Swaps)
##   counter_last          Plays what beats the opponent's last move
##   swap_on_disadvantage  Swaps out when the opponent has the type edge (and a bench dino doesn't
##                         lose to it too)
const HABITS: Array[StringName] = [&"brace_after_hit", &"brace_then_charge", &"bite_when_hurt",
		&"copy_last", &"counter_last", &"swap_on_disadvantage"]
const HABIT_PULL := 0.6
## What beats each move: Brace blocks Bite, Bite cancels Charge, Charge smashes Brace.
const COUNTER_OF := {
	BattleAction.Kind.BITE: BattleAction.Kind.BRACE,
	BattleAction.Kind.CHARGE: BattleAction.Kind.BITE,
	BattleAction.Kind.BRACE: BattleAction.Kind.CHARGE,
}

var rng: RandomNumberGenerator
## Difficulty knob. Lower = picks the best-scoring action more often. Higher = more random.
var temperature := 0.05
## Added to the score of each action kind, indexed by BattleAction.Kind.
var biases: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Whether it adapts to the opponent's habits. Easy rivals don't, so their own habits stay
## readable and exploitable.
var learns_habits := true
## How often the opponent has used each action kind.
var _seen_kinds: Array[float] = [HABIT_PRIOR, HABIT_PRIOR, HABIT_PRIOR, HABIT_PRIOR]
var _turns_seen := 0
## Conditional habits this AI has (ids from HABITS).
var habits: Array[StringName] = []
## Scales HABIT_PULL for this AI (RivalDef.habit_strength).
var habit_strength := 1.0
## What happened last turn, for the conditional habits. -1 = nothing yet.
var _my_last_kind := -1
var _their_last_kind := -1
var _last_active := -1
var _last_health := -1


func _init(seed_value: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value


func choose_action(state: BattleState, me: int) -> BattleAction:
	var them := BattleState.other(me)
	var mine := BattleEngine.legal_actions(state, me)
	var theirs := BattleEngine.legal_actions(state, them)

	# payoff[a][b] = how good the result is for me if I pick mine[a] and they pick theirs[b].
	var payoff: Array = []
	for a in mine:
		var row: Array[float] = []
		for b in theirs:
			var sim := state.clone()
			var pair: Array[BattleAction] = [a, b]
			if me == 1:
				pair = [b, a]
			BattleEngine.resolve_turn(sim, pair)
			row.append(evaluate(sim, me))
		payoff.append(row)

	# Guess the opponent: assume they reason one step about my likely moves, played evenly.
	var my_guess := _even_weights(mine)
	var their_scores: Array[float] = []
	for b in theirs.size():
		var value := 0.0
		for a in mine.size():
			value -= my_guess[a] * payoff[a][b]
		their_scores.append(value)
	var their_guess := _softmax(their_scores, temperature * 4.0, _even_weights(theirs))
	var habit_weight := minf(MAX_HABIT_WEIGHT, _turns_seen / (_turns_seen + HABIT_TRUST_TURNS))
	if not learns_habits:
		habit_weight = 0.0
	var habits := _habit_weights(theirs)
	for b in theirs.size():
		their_guess[b] = lerpf(their_guess[b], habits[b], habit_weight)

	var my_scores: Array[float] = []
	for a in mine.size():
		var value := 0.0
		for b in theirs.size():
			value += their_guess[b] * payoff[a][b]
		my_scores.append(value + biases[mine[a].kind])
	var pulls := _habit_pulls(state, me)
	for a in mine.size():
		my_scores[a] += pulls[mine[a].kind] * habit_strength
	var chosen := mine[_sample(_softmax(my_scores, temperature, _even_weights(mine)))]
	var side := state.side(me)
	_my_last_kind = chosen.kind
	_last_active = side.active
	_last_health = side.active_dino().health
	return chosen


## Records what the opponent did this turn. Call once per resolved turn.
func observe(opponent_action: BattleAction) -> void:
	_seen_kinds[opponent_action.kind] += 1.0
	_turns_seen += 1
	_their_last_kind = opponent_action.kind


## Extra score per action kind from the conditional habits that apply right now.
func _habit_pulls(state: BattleState, me: int) -> Array[float]:
	var pulls: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if habits.is_empty():
		return pulls
	var side := state.side(me)
	var mine := side.active_dino()
	var theirs := state.side(BattleState.other(me)).active_dino()
	for habit in habits:
		match habit:
			&"brace_after_hit":
				if side.active == _last_active and mine.health < _last_health:
					pulls[BattleAction.Kind.BRACE] += HABIT_PULL
			&"brace_then_charge":
				if _my_last_kind == BattleAction.Kind.BRACE and side.active == _last_active:
					pulls[BattleAction.Kind.CHARGE] += HABIT_PULL
			&"bite_when_hurt":
				if mine.health * 2 <= mine.max_health:
					pulls[BattleAction.Kind.BITE] += HABIT_PULL
			&"copy_last":
				if _their_last_kind >= 0 and _their_last_kind != BattleAction.Kind.SWAP:
					pulls[_their_last_kind] += HABIT_PULL
			&"counter_last":
				if COUNTER_OF.has(_their_last_kind):
					pulls[COUNTER_OF[_their_last_kind]] += HABIT_PULL
			&"swap_on_disadvantage":
				if BattleEngine.has_advantage(theirs, mine) and side.bench().any(
						func(i: int) -> bool: return not BattleEngine.has_advantage(theirs, side.party[i])):
					pulls[BattleAction.Kind.SWAP] += HABIT_PULL
	return pulls


## The opponent's legal actions weighted by how often they've used each kind.
func _habit_weights(actions: Array[BattleAction]) -> Array[float]:
	var swaps := 0
	for action in actions:
		if action.kind == BattleAction.Kind.SWAP:
			swaps += 1
	var weights: Array[float] = []
	var total := 0.0
	for action in actions:
		var w := _seen_kinds[action.kind]
		if action.kind == BattleAction.Kind.SWAP:
			w /= swaps
		weights.append(w)
		total += w
	for i in weights.size():
		weights[i] /= total
	return weights


## Picks which bench dino comes in after a knockout: the best matchup against their active dino.
func choose_replacement(state: BattleState, me: int) -> int:
	var side := state.side(me)
	var enemy := state.side(BattleState.other(me)).active_dino()
	var best := -1
	var best_score := -INF
	for i in side.bench():
		var dino := side.party[i]
		var dealt := float(BattleEngine.damage(dino, enemy, false)) / maxf(1.0, enemy.health)
		var taken := float(BattleEngine.damage(enemy, dino, false)) / maxf(1.0, dino.health)
		var score := dealt - taken + rng.randf() * 0.05
		if score > best_score:
			best_score = score
			best = i
	return best


## Picks PARTY_SIZE dinos out of the ones brought, within the point cap. `required` (a boss's
## Alphas) are always in it.
func choose_party(brought: Array[DinoDef], cap: int = PartyRules.POINT_CAP,
		required: Array[StringName] = []) -> Array[DinoDef]:
	var best: Array[DinoDef] = []
	var best_score := -INF
	for combo in _combinations(brought, PartyRules.PARTY_SIZE):
		if PartyRules.validate(combo, cap) != "":
			continue
		var ids: Array = combo.map(func(dino: DinoDef) -> StringName: return dino.id)
		if required.any(func(id: StringName) -> bool: return not id in ids):
			continue
		var types := {}
		for dino in combo:
			types[dino.dino_type] = true
		var score := party_strength(combo) + (types.size() - 1) * TYPE_SPREAD_BONUS + rng.randf() * 3.0
		if score > best_score:
			best_score = score
			best = combo
	return best


## Rough power estimate used for party picks. Tuned against the balance sim, not exact.
static func party_strength(party: Array[DinoDef]) -> float:
	var era_bond := PartyRules.has_era_bond(party)
	var balanced := PartyRules.is_balanced(party)
	var total := 0.0
	for dino in party:
		var c := Combatant.from_def(dino, era_bond, balanced)
		total += c.attack * 2.0 + c.defense * 3.0 + c.max_health * 0.6 + c.speed * 0.3
	return total


## Positive when `me` is ahead. Each dino counts its remaining health fraction, plus a bonus
## for being alive, so knockouts matter more than chip damage. Winning adds a small bonus on the
## same scale; a huge win score would make any long-shot winning gamble look worth it.
static func evaluate(state: BattleState, me: int) -> float:
	var value := _side_value(state.side(me)) - _side_value(state.side(BattleState.other(me)))
	if state.winner == me:
		value += WIN_BONUS
	elif state.winner == BattleState.other(me):
		value -= WIN_BONUS
	return value


static func _side_value(side: BattleSide) -> float:
	var value := 0.0
	for dino in side.party:
		if not dino.is_knocked_out():
			value += 1.0 + float(dino.health) / dino.max_health
	return value


## Weights that treat Bite, Charge, Brace and "some Swap" as equally likely, so having two swap
## targets doesn't double the odds of swapping.
static func _even_weights(actions: Array[BattleAction]) -> Array[float]:
	var swap_count := 0
	for action in actions:
		if action.kind == BattleAction.Kind.SWAP:
			swap_count += 1
	var kinds := actions.size() - swap_count + (1 if swap_count > 0 else 0)
	var weights: Array[float] = []
	for action in actions:
		var w := 1.0 / kinds
		if action.kind == BattleAction.Kind.SWAP:
			w /= swap_count
		weights.append(w)
	return weights


static func _softmax(scores: Array[float], temp: float, prior: Array[float]) -> Array[float]:
	var top: float = scores.max()
	var weights: Array[float] = []
	var total := 0.0
	for i in scores.size():
		var w := prior[i] * exp((scores[i] - top) / maxf(temp, 0.001))
		weights.append(w)
		total += w
	for i in weights.size():
		weights[i] /= total
	return weights


func _sample(weights: Array[float]) -> int:
	var roll := rng.randf()
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


static func _combinations(items: Array[DinoDef], k: int) -> Array:
	var result: Array = []
	var current: Array[DinoDef] = []
	_combine(items, k, 0, current, result)
	return result


static func _combine(items: Array[DinoDef], k: int, start: int, current: Array[DinoDef], out: Array) -> void:
	if current.size() == k:
		out.append(current.duplicate())
		return
	for i in range(start, items.size()):
		current.append(items[i])
		_combine(items, k, i + 1, current, out)
		current.pop_back()
