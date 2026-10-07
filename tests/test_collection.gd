extends "res://tests/test_case.gd"

var catalog := DinoCatalog.load_default()


func _dino(id: StringName) -> DinoDef:
	return catalog.find(id)


func test_new_game_has_starters_and_a_clutch() -> void:
	var p := PlayerProfile.new_game(1)
	assert_eq(p.owned.size(), 6)
	assert_eq(p.lineup.size(), 6)
	assert_eq(p.clutches, Economy.STARTER_CLUTCHES)
	assert_eq(p.amber, 0)
	var three: Array[DinoDef] = []
	three.assign(p.lineup_defs(catalog).slice(0, 3))
	assert_eq(HerdRules.validate(three), "", "starter lineup can battle")


func test_new_dino_is_kept() -> void:
	var p := PlayerProfile.new_game(1)
	var result := p.add_dino(_dino(&"t_rex"), false)
	assert_true(result.is_new)
	assert_true(p.owns(&"t_rex"))
	assert_eq(p.amber, 0)


func test_duplicate_melts_into_amber() -> void:
	var p := PlayerProfile.new_game(1)
	var result := p.add_dino(_dino(&"coelophysis"), false)
	assert_false(result.is_new)
	assert_eq(result.amber, Economy.MELT_VALUE[DinoDef.Rarity.COMMON])
	assert_eq(p.amber, Economy.MELT_VALUE[DinoDef.Rarity.COMMON])


func test_shiny_duplicate_upgrades_then_melts() -> void:
	var p := PlayerProfile.new_game(1)
	var upgrade := p.add_dino(_dino(&"coelophysis"), true)
	assert_true(upgrade.upgraded_to_shiny)
	assert_eq(upgrade.amber, 0)
	assert_true(p.is_shiny(&"coelophysis"))
	var again := p.add_dino(_dino(&"coelophysis"), true)
	assert_eq(again.amber, Economy.MELT_VALUE[DinoDef.Rarity.COMMON], "second shiny melts")
	var plain := p.add_dino(_dino(&"coelophysis"), false)
	assert_eq(plain.amber, Economy.MELT_VALUE[DinoDef.Rarity.COMMON])
	assert_true(p.is_shiny(&"coelophysis"), "a plain dupe never downgrades")


func test_hatch_uses_a_clutch_and_gives_three() -> void:
	var p := PlayerProfile.new_game(1)
	assert_eq(p.hatch_clutch(catalog).size(), 3)
	assert_eq(p.clutches, 0)
	assert_eq(p.hatch_clutch(catalog).size(), 0, "no clutch, no eggs")
	assert_eq(p.eggs_hatched, 3)


func test_hatch_odds_roughly_match_table() -> void:
	var p := PlayerProfile.new_game(99)
	p.clutches = 4000
	var counts := [0, 0, 0, 0, 0]
	var shinies := 0
	for i in 4000:
		for result in p.hatch_clutch(catalog):
			counts[result.dino.rarity] += 1
			shinies += 1 if result.shiny else 0
	var total := 12000.0
	assert_true(absf(counts[0] / total - 0.60) < 0.02, "common %.3f" % (counts[0] / total))
	assert_true(absf(counts[1] / total - 0.25) < 0.02, "uncommon %.3f" % (counts[1] / total))
	assert_true(absf(counts[2] / total - 0.10) < 0.015, "rare %.3f" % (counts[2] / total))
	assert_true(absf(shinies / total - Economy.SHINY_ODDS) < 0.008, "shiny %.4f" % (shinies / total))


func test_pity_guarantees_epic_every_ten_clutches() -> void:
	for seed_value in 20:
		var p := PlayerProfile.new_game(seed_value)
		p.clutches = 200
		var dry := 0
		for i in 200:
			var got_epic := false
			for result in p.hatch_clutch(catalog):
				got_epic = got_epic or result.dino.rarity >= DinoDef.Rarity.EPIC
			dry = 0 if got_epic else dry + 1
			if dry >= Economy.PITY_CLUTCHES:
				_fail("seed %d: %d clutches without an Epic" % [seed_value, dry])
				return


func test_same_seed_same_eggs() -> void:
	var a := PlayerProfile.new_game(7)
	var b := PlayerProfile.new_game(7)
	a.clutches = 5
	b.clutches = 5
	for i in 5:
		assert_eq(_ids(a.hatch_clutch(catalog)), _ids(b.hatch_clutch(catalog)))


func test_craft() -> void:
	var p := PlayerProfile.new_game(1)
	var rex := _dino(&"t_rex")
	assert_true(p.craft(rex) == null, "can't afford")
	p.amber = Economy.CRAFT_COST[DinoDef.Rarity.LEGENDARY] + 5
	assert_true(p.craft(rex).is_new)
	assert_eq(p.amber, 5)
	p.amber = 99999
	assert_true(p.craft(rex) == null, "already owned")


func test_daily_clutch_once_per_day() -> void:
	var p := PlayerProfile.new_game(1)
	assert_true(p.claim_daily(100))
	assert_false(p.claim_daily(100))
	assert_true(p.claim_daily(101))
	assert_eq(p.clutches, Economy.STARTER_CLUTCHES + 2)


func test_buy_clutch() -> void:
	var p := PlayerProfile.new_game(1)
	assert_false(p.buy_clutch())
	p.amber = Economy.CLUTCH_PRICE
	assert_true(p.buy_clutch())
	assert_eq(p.amber, 0)


func test_battle_rewards() -> void:
	var p := PlayerProfile.new_game(1)
	var win := p.record_battle(true)
	assert_eq(win["clutches"], Economy.WIN_CLUTCHES)
	p.record_battle(false)
	assert_eq(p.amber, Economy.WIN_AMBER + Economy.LOSS_AMBER)
	assert_eq([p.wins, p.losses], [1, 1])


func test_lineup_rules() -> void:
	var p := PlayerProfile.new_game(1)
	var not_owned: Array[StringName] = [&"t_rex"]
	assert_true(p.set_lineup(not_owned) != "")
	var dupes: Array[StringName] = [&"coelophysis", &"coelophysis"]
	assert_true(p.set_lineup(dupes) != "")
	var ok: Array[StringName] = [&"coelophysis", &"stegosaurus"]
	assert_eq(p.set_lineup(ok), "")
	assert_eq(p.lineup.size(), 2)


func test_seen_clears_when_owned() -> void:
	var p := PlayerProfile.new_game(1)
	p.mark_seen(&"t_rex")
	p.mark_seen(&"coelophysis")
	assert_true(p.seen.has(&"t_rex"))
	assert_false(p.seen.has(&"coelophysis"), "already owned")
	p.add_dino(_dino(&"t_rex"), false)
	assert_false(p.seen.has(&"t_rex"))


func test_save_round_trip_keeps_everything_including_rng() -> void:
	var p := PlayerProfile.new_game(12345)
	p.clutches = 10
	p.hatch_clutch(catalog)
	p.mark_seen(&"mosasaurus")
	p.claim_daily(500)
	p.record_battle(true)
	var json := JSON.stringify(p.to_dict())
	var loaded := PlayerProfile.from_dict(JSON.parse_string(json), catalog)
	assert_eq(JSON.stringify(loaded.to_dict()), json, "identical after reload")
	assert_eq(_ids(loaded.hatch_clutch(catalog)), _ids(p.hatch_clutch(catalog)), "RNG continues identically")


func test_load_tolerates_bad_data() -> void:
	var data := {"owned": {"coelophysis": false, "not_a_dino": true}, "lineup": ["coelophysis",
			"not_a_dino", "t_rex"], "amber": -50}
	var p := PlayerProfile.from_dict(data, catalog)
	assert_eq(p.owned.size(), 1)
	assert_eq(p.lineup.size(), 1, "unknown and unowned ids dropped")
	assert_eq(p.amber, 0)


func test_save_store_writes_and_recovers_from_backup() -> void:
	SaveStore.folder = "user://test_saves"
	SaveStore.delete_all()
	assert_true(SaveStore.load_profile(catalog) == null, "no save yet")
	var p := PlayerProfile.new_game(3)
	p.amber = 42
	assert_true(SaveStore.save_profile(p))
	p.amber = 43
	assert_true(SaveStore.save_profile(p))
	assert_eq(SaveStore.load_profile(catalog).amber, 43)
	# Corrupt the main save: the backup (previous save) is used instead.
	var file := FileAccess.open(SaveStore.folder.path_join(SaveStore.FILE), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(SaveStore.load_profile(catalog).amber, 42)
	SaveStore.delete_all()
	SaveStore.folder = "user://"


func _ids(results: Array[HatchResult]) -> Array:
	return results.map(func(r: HatchResult) -> String: return "%s%s" % [r.dino.id, "*" if r.shiny else ""])
