class_name BattleReplay
extends RefCounted
## Rebuilds a battle in progress from its moves, so a battle can continue after Android closes the
## game in the background (decided by Jo, 2026-10-09). The engine has no randomness and the rival
## AI's comes from a seed, so replaying the same moves in the same order, with the same AI calls,
## lands on exactly the same state, AI included.
##
## Events are small int arrays (they're saved as JSON):
##   [TURN, player kind, player swap_to, rival kind, rival swap_to]
##   [PLAYER_REPLACE, party index]
##   [RIVAL_REPLACE, party index]

enum { TURN, PLAYER_REPLACE, RIVAL_REPLACE }

const PLAYER := 0
const RIVAL := 1


static func turn_event(player_action: BattleAction, rival_action: BattleAction) -> Array:
	return [TURN, player_action.kind, player_action.swap_to, rival_action.kind, rival_action.swap_to]


## Applies `events` to a freshly created state and AI, making the same AI calls the battle screen
## made live (so the AI's random numbers and what it has learned stay in step).
static func replay(state: BattleState, ai: BattleAI, events: Array) -> void:
	for event in events:
		match int(event[0]):
			TURN:
				ai.choose_action(state, RIVAL)
				var player_action := _action(int(event[1]), int(event[2]))
				var pair: Array[BattleAction] = [player_action, _action(int(event[3]), int(event[4]))]
				BattleEngine.resolve_turn(state, pair)
				ai.observe(player_action)
			PLAYER_REPLACE:
				BattleEngine.replace_active(state, PLAYER, int(event[1]))
			RIVAL_REPLACE:
				ai.choose_replacement(state, RIVAL)
				BattleEngine.replace_active(state, RIVAL, int(event[1]))


static func _action(kind: int, swap_to: int) -> BattleAction:
	if kind == BattleAction.Kind.SWAP:
		return BattleAction.swap(swap_to)
	return BattleAction.of_kind(kind)
