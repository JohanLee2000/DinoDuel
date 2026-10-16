extends "res://tests/test_case.gd"
## Dino mastery (core/collection/mastery.gd), party slots and "new" dots (PlayerProfile).

var catalog := DinoCatalog.load_default()


func _party(ids: Array) -> Array[DinoDef]:
	var defs: Array[DinoDef] = []
	for id in ids:
		defs.append(catalog.find(id))
	return defs


func test_ranks_are_earned_in_order() -> void:
	var p := PlayerProfile.new_game(30)
	var party := _party([&"coelophysis", &"eudimorphodon", &"protoceratops"])
	assert_eq(Mastery.rank_of(p, &"coelophysis"), 0)
	var ups := Mastery.record_battle(p, party, false, false, {})
	assert_eq(Mastery.rank_of(p, &"coelophysis"), 1, "Recruit after the first battle, even a loss")
	assert_eq(ups.size(), 3)
	assert_eq(Mastery.title_of(1), "Recruit")
	for i in 3:
		Mastery.record_battle(p, party, true, true, {&"coelophysis": 2})
	assert_eq(Mastery.rank_of(p, &"coelophysis"), 2, "Fighter at 3 wins; Trusted Partner waits for Veteran")
	var stats := Mastery.stats_of(p, &"coelophysis")
	assert_eq(stats, {"battles": 4, "wins": 3, "counters": 6, "bosses": 3})
	for i in 7:
		Mastery.record_battle(p, party, true, false, {})
	assert_eq(Mastery.rank_of(p, &"coelophysis"), 4, "10 wins and 3 bosses: Veteran, then Trusted Partner")
	assert_true(Mastery.next_text(p, &"coelophysis").begins_with("Next: Legend: win 25 battles (10/25) and counter 25 moves (6/25)"))
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(Mastery.stats_of(loaded, &"coelophysis"), stats.merged({"battles": 11, "wins": 10}, true), "saved")


func test_counters_come_from_the_moves_played() -> void:
	var mine := _party([&"argentinosaurus", &"brachiosaurus", &"triceratops"])
	var theirs := _party([&"argentinosaurus", &"brachiosaurus", &"triceratops"])
	var stage := Journey.find(&"rae")
	var bite := BattleAction.Kind.BITE
	var charge := BattleAction.Kind.CHARGE
	var brace := BattleAction.Kind.BRACE
	var events: Array = [
		[BattleReplay.TURN, bite, -1, charge, -1],  # Bite beats Charge: a counter.
		[BattleReplay.TURN, brace, -1, bite, -1],  # Brace beats Bite: a counter.
		[BattleReplay.TURN, bite, -1, brace, -1],  # Brace beats Bite: the rival's.
	]
	var counts := Mastery.counters_in(stage.start_battle(mine, theirs), events)
	assert_eq(counts, {&"argentinosaurus": 2})
	assert_true(Mastery.beats(charge, brace))
	assert_false(Mastery.beats(BattleAction.Kind.SWAP, bite), "swaps never count")


func test_party_slots_switch_rename_and_save() -> void:
	var p := PlayerProfile.new_game(31)
	p.choose_partner(&"dilophosaurus")
	var first := p.lineup.duplicate()
	assert_eq(p.party_name(0), "Party 1")
	p.select_party(1)
	assert_eq(p.lineup, first, "a new slot starts as a copy")
	var smaller: Array[StringName] = [first[0], first[1], first[2]]
	assert_eq(p.set_lineup(smaller), "")
	assert_true(p.rename_party(1, "  Sea squad  "))
	assert_eq(p.party_name(1), "Sea squad")
	assert_false(p.rename_party(1, "   "), "names can't be empty")
	assert_eq(p.party_name(1), "Sea squad")
	p.select_party(0)
	assert_eq(p.lineup, first, "Party 1 kept its 6")
	assert_eq(p.party_lineup(1), smaller)
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(loaded.party_slot, 0)
	assert_eq(loaded.party_lineup(1), smaller)
	assert_eq(loaded.party_name(1), "Sea squad")
	var old := p.to_dict()
	old.erase("parties")
	old.erase("party_slot")
	var from_old := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(old)), catalog)
	assert_eq(from_old.party_lineup(2), first, "older saves: every slot starts with the lineup")


func test_new_dinos_get_a_dot_until_viewed() -> void:
	var p := PlayerProfile.new_game(32)
	p.choose_partner(&"tanystropheus")
	assert_true(p.new_dinos.is_empty(), "starters and the partner aren't new")
	p.add_dino(catalog.find(&"t_rex"), false)
	assert_true(p.is_new(&"t_rex"))
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_true(loaded.is_new(&"t_rex"), "saved")
	assert_true(p.mark_viewed(&"t_rex"))
	assert_false(p.is_new(&"t_rex"))
	p.add_dino(catalog.find(&"t_rex"), false)
	assert_false(p.is_new(&"t_rex"), "a duplicate doesn't bring the dot back")
