class_name BattleAction
extends RefCounted
## What one side does on a turn. Both sides pick secretly, then the engine resolves them together.

enum Kind { BITE, CHARGE, BRACE, SWAP }

const KIND_NAMES: Array[String] = ["Bite", "Charge", "Brace", "Swap"]

var kind: Kind
## Herd index to swap to; only used when kind == SWAP.
var swap_to := -1


static func bite() -> BattleAction:
	return _make(Kind.BITE)


static func charge() -> BattleAction:
	return _make(Kind.CHARGE)


static func brace() -> BattleAction:
	return _make(Kind.BRACE)


static func swap(index: int) -> BattleAction:
	var action := _make(Kind.SWAP)
	action.swap_to = index
	return action


static func _make(k: Kind) -> BattleAction:
	var action := BattleAction.new()
	action.kind = k
	return action


func equals(other: BattleAction) -> bool:
	return kind == other.kind and swap_to == other.swap_to


func _to_string() -> String:
	if kind == Kind.SWAP:
		return "Swap(%d)" % swap_to
	return KIND_NAMES[kind]
