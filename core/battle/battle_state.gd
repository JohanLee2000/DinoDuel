class_name BattleState
extends RefCounted
## Full state of a battle. Side 0 is the player, side 1 the opponent.

const ONGOING := -1
const DRAW := 2

var sides: Array[BattleSide] = []
var turn := 1
var winner := ONGOING


func side(index: int) -> BattleSide:
	return sides[index]


func is_over() -> bool:
	return winner != ONGOING


func clone() -> BattleState:
	var state := BattleState.new()
	for s in sides:
		state.sides.append(s.clone())
	state.turn = turn
	state.winner = winner
	return state


static func other(side_index: int) -> int:
	return 1 - side_index
