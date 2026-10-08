extends "res://tests/test_case.gd"

const LAND := DinoDef.DinoType.LAND
const SKY := DinoDef.DinoType.SKY
const SEA := DinoDef.DinoType.SEA


func _battle(player: Array, opponent: Array) -> BattleState:
	return BattleEngine.create(party(player), party(opponent))


func _health(state: BattleState, side_index: int) -> int:
	return state.side(side_index).active_dino().health


func test_type_triangle() -> void:
	assert_true(DinoDef.type_beats(LAND, SKY), "Land beats Sky")
	assert_true(DinoDef.type_beats(SKY, SEA), "Sky beats Sea")
	assert_true(DinoDef.type_beats(SEA, LAND), "Sea beats Land")
	assert_false(DinoDef.type_beats(SKY, LAND))
	assert_false(DinoDef.type_beats(LAND, LAND))


func test_damage_formula() -> void:
	var state := _battle(
			[make_dino(6, 1, 5, 20), make_dino(5, 0, 5, 20, LAND)],
			[make_dino(1, 2, 5, 20), make_dino(1, 1, 5, 20, SKY)])
	var att := state.side(0).party[0]
	assert_eq(BattleEngine.damage(att, state.side(1).party[0], false), 4, "6 atk - 2 def")
	assert_eq(BattleEngine.damage(state.side(1).party[0], att, false), 1, "minimum 1 damage")
	assert_eq(BattleEngine.damage(att, state.side(1).party[0], true), 10, "charge doubles before defense")
	var land := state.side(0).party[1]
	var sky := state.side(1).party[1]
	assert_eq(BattleEngine.damage(land, sky, false), 6, "floor(5 * 1.5) - 1")
	assert_eq(BattleEngine.damage(land, sky, true), 14, "floor(5 * 1.5 * 2) - 1")


func test_faster_bite_knocks_out_before_reply() -> void:
	var state := _battle([make_dino(10, 0, 9, 10)], [make_dino(10, 0, 1, 5)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(_health(state, 0), 10, "slower dino never got to bite")
	assert_eq(events_of(events, "bite").size(), 1)
	assert_eq(state.winner, 0)


func test_equal_speed_bites_land_together() -> void:
	var state := _battle([make_dino(10, 0, 5, 5)], [make_dino(10, 0, 5, 5)])
	BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(state.winner, BattleState.DRAW, "both knocked out at once")


func test_brace_blocks_bite_and_counters() -> void:
	var state := _battle([make_dino(5, 1, 9, 20)], [make_dino(4, 1, 1, 20)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.brace()))
	assert_eq(_health(state, 1), 20, "bracer takes nothing")
	assert_eq(_health(state, 0), 17, "biter eats a 4 - 1 counter")
	assert_eq(events_of(events, "blocked").size(), 1)
	assert_eq(events_of(events, "counter").size(), 1)


func test_charge_breaks_brace() -> void:
	var state := _battle([make_dino(5, 1, 1, 20)], [make_dino(4, 1, 9, 20)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.charge(), BattleAction.brace()))
	assert_eq(_health(state, 1), 11, "2 x 5 - 1 = 9 damage through the brace")
	assert_eq(_health(state, 0), 20)
	assert_true(events_of(events, "charge")[0]["through_brace"])


func test_bite_cancels_charge() -> void:
	var state := _battle([make_dino(5, 1, 1, 20)], [make_dino(9, 1, 9, 20)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.charge()))
	assert_eq(_health(state, 0), 20, "charge was cancelled")
	assert_eq(_health(state, 1), 16)
	assert_eq(events_of(events, "charge_cancelled").size(), 1)


func test_bite_cancels_charge_even_when_charger_is_faster() -> void:
	var state := _battle([make_dino(9, 0, 9, 20)], [make_dino(2, 0, 1, 20)])
	BattleEngine.resolve_turn(state, actions(BattleAction.charge(), BattleAction.bite()))
	assert_eq(_health(state, 1), 20, "charges always resolve after bites")
	assert_eq(_health(state, 0), 18)


func test_charges_resolve_in_speed_order() -> void:
	var state := _battle([make_dino(5, 0, 9, 10)], [make_dino(5, 0, 1, 10)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.charge(), BattleAction.charge()))
	assert_eq(_health(state, 0), 10, "faster charge knocked them out first")
	assert_eq(state.winner, 0)
	assert_eq(events_of(events, "charge").size(), 1)


func test_swap_goes_first_and_incoming_takes_hit() -> void:
	var state := _battle([make_dino(5, 0, 1, 10), make_dino(5, 0, 1, 12)], [make_dino(4, 0, 9, 10)])
	BattleEngine.resolve_turn(state, actions(BattleAction.swap(1), BattleAction.bite()))
	assert_eq(state.side(0).active, 1)
	assert_eq(state.side(0).party[1].health, 8, "incoming dino took the bite")
	assert_eq(state.side(0).party[0].health, 10, "outgoing dino untouched")


func test_cannot_brace_twice_in_a_row() -> void:
	var state := _battle([make_dino(5, 0, 1, 30)], [make_dino(1, 0, 1, 30)])
	BattleEngine.resolve_turn(state, actions(BattleAction.brace(), BattleAction.brace()))
	assert_false(BattleEngine.is_legal(state, 0, BattleAction.brace()), "brace on cooldown")
	BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_true(BattleEngine.is_legal(state, 0, BattleAction.brace()), "brace available again")


func test_bench_heals_each_turn() -> void:
	var state := _battle([make_dino(1, 0, 1, 30), make_dino(1, 0, 1, 10)], [make_dino(1, 5, 1, 30)])
	state.side(0).party[1].health = 8
	BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(state.side(0).party[1].health, 9)
	BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(state.side(0).party[1].health, 10, "never above max")


func test_knockout_needs_replacement() -> void:
	var state := _battle([make_dino(1, 0, 1, 5), make_dino(1, 0, 1, 10)], [make_dino(10, 0, 9, 30)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(events_of(events, "ko").size(), 1)
	assert_true(state.side(0).needs_replacement())
	assert_false(state.is_over())
	BattleEngine.replace_active(state, 0, 1)
	assert_eq(state.side(0).active, 1)
	assert_false(state.side(0).needs_replacement())


func test_winner_when_party_is_wiped() -> void:
	var state := _battle([make_dino(10, 0, 9, 30)], [make_dino(1, 0, 1, 5)])
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(state.winner, 0)
	assert_eq(events_of(events, "battle_end").size(), 1)


func test_meteor_shower_breaks_stalls() -> void:
	var state := _battle([make_dino(1, 9, 1, 30)], [make_dino(1, 9, 1, 30)])
	state.turn = BattleEngine.METEOR_START_TURN + 2
	var events := BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(events_of(events, "meteor")[0]["damage"], 3, "meteor grows each turn")
	assert_eq(_health(state, 0), 26, "1 bite + 3 meteor")


func test_meteor_never_knocks_out() -> void:
	var state := _battle([make_dino(1, 9, 1, 3)], [make_dino(1, 9, 1, 30)])
	state.turn = BattleEngine.METEOR_START_TURN + 5
	BattleEngine.resolve_turn(state, actions(BattleAction.bite(), BattleAction.bite()))
	assert_eq(_health(state, 0), 1, "bite to 2, meteor stops at 1")
	assert_false(state.is_over())


func test_party_bonuses_apply() -> void:
	var triassic := party([make_dino(5, 0, 5, 10, LAND), make_dino(5, 0, 5, 10, SKY),
			make_dino(5, 0, 5, 10, SEA)])
	var side := BattleSide.from_party(triassic)
	assert_true(side.era_bond and side.balanced)
	assert_eq(side.party[0].attack, 6)
	assert_eq(side.party[0].speed, 6)
	assert_eq(side.party[0].max_health, 12)
	var mixed := party([make_dino(5, 0, 5, 10, LAND), make_dino(5, 0, 5, 10, LAND, DinoDef.Era.JURASSIC),
			make_dino(5, 0, 5, 10, SEA)])
	var plain := BattleSide.from_party(mixed)
	assert_false(plain.era_bond or plain.balanced)
	assert_eq(plain.party[0].attack, 5)


func test_has_valid_pick() -> void:
	var cheap := make_dino(1, 1, 1, 1)
	var legend := make_dino(1, 1, 1, 1, LAND, DinoDef.Era.TRIASSIC, DinoDef.Rarity.LEGENDARY)
	var epic := make_dino(1, 1, 1, 1, LAND, DinoDef.Era.TRIASSIC, DinoDef.Rarity.EPIC)
	assert_true(PartyRules.has_valid_pick(party([legend, epic, cheap, cheap, epic, legend])), "1 + 1 + 4 fits")
	assert_true(PartyRules.has_valid_pick(party([legend, epic, epic, legend, cheap, legend])), "1 + 4 + 4 = 9 fits exactly")
	assert_false(PartyRules.has_valid_pick(party([legend, legend, epic, legend, cheap, legend])), "1 + 4 + 5 doesn't")
	assert_false(PartyRules.has_valid_pick(party([cheap, cheap])), "too few")


func test_party_validation() -> void:
	var common := make_dino(1, 1, 1, 1)
	var legend := make_dino(1, 1, 1, 1, LAND, DinoDef.Era.TRIASSIC, DinoDef.Rarity.LEGENDARY)
	var rare := make_dino(1, 1, 1, 1, LAND, DinoDef.Era.TRIASSIC, DinoDef.Rarity.SUPER_RARE)
	assert_eq(PartyRules.validate(party([common, legend, rare])), "", "1 + 5 + 3 = 9 fits")
	var legend2 := make_dino(1, 1, 1, 1, LAND, DinoDef.Era.TRIASSIC, DinoDef.Rarity.LEGENDARY)
	assert_true(PartyRules.validate(party([common, legend, legend2])) != "", "11 points is over the cap")
	assert_true(PartyRules.validate(party([common, legend])) != "", "too few")
	assert_true(PartyRules.validate(party([common, common, legend])) != "", "duplicates")
