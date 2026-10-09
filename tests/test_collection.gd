extends "res://tests/test_case.gd"

var catalog := DinoCatalog.load_default()


func _dino(id: StringName) -> DinoDef:
	return catalog.find(id)


func test_new_game_has_starters_and_a_clutch() -> void:
	var p := PlayerProfile.new_game(1)
	assert_eq(p.owned.size(), 5, "5 basics before the partner")
	assert_false(p.partner_chosen)
	assert_true(p.choose_partner(&"tanystropheus"))
	assert_eq(p.owned.size(), 6)
	assert_eq(p.lineup.size(), 6)
	assert_eq(p.partner, &"tanystropheus")
	assert_eq(p.clutches, Economy.STARTER_CLUTCHES)
	assert_eq(p.amber, 0)
	var three: Array[DinoDef] = []
	three.assign(p.lineup_defs(catalog).slice(0, 3))
	assert_eq(PartyRules.validate(three), "", "starter lineup can battle")


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
	p.clutches = 1
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
	for rarity in 3:
		var share: float = counts[rarity] / total
		assert_true(absf(share - Economy.RARITY_ODDS[rarity]) < 0.02, "tier %d: %.3f" % [rarity, share])
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


func test_daily_check_in_once_per_day() -> void:
	var p := PlayerProfile.new_game(1)
	assert_true(p.claim_daily(100))
	assert_false(p.claim_daily(100))
	assert_true(p.claim_daily(101))
	assert_eq(p.checkin_day, 2)
	# Day 1 and 2 bonuses are Amber, so only the free clutches were added.
	assert_eq(p.clutches, Economy.STARTER_CLUTCHES + 2 * Economy.DAILY_CLUTCHES)
	assert_eq(p.amber, Economy.CHECKIN_BONUSES[0]["amber"] + Economy.CHECKIN_BONUSES[1]["amber"])


func test_check_in_streak_pauses_on_a_missed_day_and_loops_after_day_7() -> void:
	var p := PlayerProfile.new_game(1)
	p.claim_daily(10)
	p.claim_daily(15)
	assert_eq(p.checkin_day, 2, "a gap doesn't reset the streak")
	var expected_amber := p.amber
	var expected_clutches := p.clutches
	var expected_rare := 0
	for day in range(2, 7):
		var bonus: Dictionary = Economy.CHECKIN_BONUSES[day]
		expected_amber += int(bonus.get("amber", 0))
		expected_clutches += Economy.DAILY_CLUTCHES + int(bonus.get("clutches", 0))
		expected_rare += int(bonus.get("rare_clutches", 0))
		p.claim_daily(20 + day)
	assert_eq(p.amber, expected_amber)
	assert_eq(p.clutches, expected_clutches)
	assert_eq(p.rare_clutches, 1, "day 7 is a rare clutch")
	assert_eq(expected_rare, 1)
	assert_eq(p.checkin_day, 0, "back to day 1 after day 7")


func test_rare_clutch_buys_and_hatches_with_better_odds() -> void:
	var total := 0.0
	for odds in Economy.RARE_CLUTCH_ODDS:
		total += odds
	assert_true(absf(total - 1.0) < 0.0001, "rare odds add up to 1")
	var p := PlayerProfile.new_game(7)
	assert_false(p.buy_rare_clutch(), "can't afford")
	p.amber = Economy.RARE_CLUTCH_PRICE
	assert_true(p.buy_rare_clutch())
	assert_eq(p.amber, 0)
	assert_eq(p.rare_clutches, 1)
	var normal_before := p.clutches
	assert_eq(p.hatch_clutch(catalog, true).size(), Economy.EGGS_PER_CLUTCH)
	assert_eq(p.rare_clutches, 0)
	assert_eq(p.clutches, normal_before, "a rare hatch leaves normal clutches alone")
	assert_true(p.hatch_clutch(catalog, true).is_empty(), "none left")
	# Over many clutches, rare ones give far fewer Commons.
	var commons := [0, 0]
	for rare in [false, true]:
		var q := PlayerProfile.new_game(99)
		q.clutches = 300
		q.rare_clutches = 300
		for i in 300:
			for result in q.hatch_clutch(catalog, rare):
				commons[int(rare)] += 1 if result.dino.rarity == DinoDef.Rarity.COMMON else 0
	assert_true(commons[1] < commons[0] * 0.75, "rare: %d Commons vs normal: %d" % [commons[1], commons[0]])


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


func test_record_per_rival() -> void:
	var p := PlayerProfile.new_game(1)
	p.record_battle(true, &"rae")
	p.record_battle(false, &"rae")
	p.record_battle(true, &"fern")
	assert_eq(p.record_against(&"rae"), [1, 1])
	assert_eq(p.record_against(&"fern"), [1, 0])
	assert_eq(p.record_against(&"rory"), [0, 0])
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(loaded.record_against(&"rae"), [1, 1])


func test_lineup_rules() -> void:
	var p := PlayerProfile.new_game(1)
	var not_owned: Array[StringName] = [&"t_rex"]
	assert_true(p.set_lineup(not_owned) != "")
	var dupes: Array[StringName] = [&"coelophysis", &"coelophysis"]
	assert_true(p.set_lineup(dupes) != "")
	var ok: Array[StringName] = [&"coelophysis", &"protoceratops"]
	assert_eq(p.set_lineup(ok), "")
	assert_eq(p.lineup.size(), 2)


func test_unlock_all_keeps_shinies() -> void:
	var p := PlayerProfile.new_game(1)
	p.add_dino(_dino(&"coelophysis"), true)
	p.mark_seen(&"t_rex")
	p.unlock_all(catalog)
	assert_eq(p.owned.size(), catalog.dinos.size())
	assert_true(p.is_shiny(&"coelophysis"))
	assert_true(p.seen.is_empty())


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
	p.rare_clutches = 2
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


func test_tutorial_flag_saves_and_old_saves_infer_it() -> void:
	var fresh := PlayerProfile.new_game(1)
	assert_false(fresh.tutorial_done, "new players get the coached first battle")
	fresh.tutorial_done = true
	assert_true(PlayerProfile.from_dict(fresh.to_dict(), catalog).tutorial_done, "flag survives a save")
	var old_save := PlayerProfile.new_game(2).to_dict()
	old_save.erase("tutorial_done")
	assert_false(PlayerProfile.from_dict(old_save, catalog).tutorial_done, "old save, never battled")
	old_save["wins"] = 3
	assert_true(PlayerProfile.from_dict(old_save, catalog).tutorial_done, "old save that has battled")


func test_partner_is_chosen_once_from_the_starter_three() -> void:
	var p := PlayerProfile.new_game(1)
	assert_false(p.choose_partner(&"t_rex"), "not a starter partner")
	assert_true(p.choose_partner(&"archaeopteryx"))
	assert_false(p.choose_partner(&"dilophosaurus"), "only one partner")
	assert_false(p.owns(&"dilophosaurus"))
	var reloaded := PlayerProfile.from_dict(p.to_dict(), catalog)
	assert_true(reloaded.partner_chosen)
	assert_eq(reloaded.partner, &"archaeopteryx")
	var old_save := PlayerProfile.new_game(2).to_dict()
	old_save.erase("partner_chosen")
	assert_true(PlayerProfile.from_dict(old_save, catalog).partner_chosen, "old saves already have their 6")


func test_every_partner_gives_a_battle_ready_lineup() -> void:
	for id in Economy.STARTER_PARTNERS:
		var p := PlayerProfile.new_game(3)
		p.choose_partner(id)
		var lineup := p.lineup_defs(catalog)
		assert_eq(lineup.size(), PartyRules.BRING_SIZE, "%s lineup" % id)
		assert_true(PartyRules.has_valid_pick(lineup), "%s can field a party" % id)
		assert_eq(catalog.find(id).rarity, DinoDef.Rarity.RARE, "%s is Rare" % id)


func test_forfeit_is_a_loss_without_amber() -> void:
	var p := PlayerProfile.new_game(1)
	var amber := p.amber
	var clutches := p.clutches
	p.record_forfeit(&"rae")
	assert_eq(p.losses, 1)
	assert_eq(p.record_against(&"rae"), [0, 1])
	assert_eq(p.amber, amber, "no Amber for quitting")
	assert_eq(p.clutches, clutches)


func test_first_steps_follow_progress_and_pay_once() -> void:
	var p := PlayerProfile.new_game(5)
	assert_true(p.first_steps_active)
	assert_eq(p.next_first_step(), &"partner")
	p.choose_partner(&"tanystropheus")
	assert_eq(p.next_first_step(), &"hatch")
	p.clutches = 1
	var hatched := p.hatch_clutch(catalog)
	assert_eq(p.next_first_step(), &"dex")
	p.opened_dex_card = true
	assert_eq(p.next_first_step(), &"party")
	var new_dino: StringName = &""
	for result in hatched:
		if not p._is_starter(result.dino.id):
			new_dino = result.dino.id
	if new_dino != &"":
		var lineup: Array[StringName] = p.lineup.slice(0, 5)
		lineup.append(new_dino)
		assert_eq(p.set_lineup(lineup), "")
	assert_eq(p.next_first_step(), &"battle")
	assert_false(p.claim_first_steps_reward(), "not finished yet")
	p.record_battle(true, &"rae")
	assert_eq(p.next_first_step(), &"")
	var clutches := p.clutches
	assert_true(p.claim_first_steps_reward())
	assert_eq(p.clutches, clutches + Economy.FIRST_STEPS_CLUTCHES)
	assert_false(p.first_steps_active)
	assert_false(p.claim_first_steps_reward(), "only once")


func test_first_steps_party_step_cannot_get_stuck() -> void:
	var p := PlayerProfile.new_game(6)
	p.choose_partner(&"dilophosaurus")
	p.eggs_hatched = 3  # hatched, but (say) only duplicates of starters
	assert_true(p.first_step_done(&"party"), "nothing new to add, so the step is done")


func test_old_saves_skip_first_steps() -> void:
	var old_save := PlayerProfile.new_game(7).to_dict()
	old_save.erase("first_steps_active")
	assert_false(PlayerProfile.from_dict(old_save, catalog).first_steps_active)


func test_player_name_is_trimmed_and_saved() -> void:
	var p := PlayerProfile.new_game(8)
	assert_false(p.set_player_name("   "), "blank names are refused")
	assert_true(p.set_player_name("  Jo the Fossil Hunter Extraordinaire  "))
	assert_eq(p.player_name.length() <= PlayerProfile.NAME_MAX_LENGTH, true)
	assert_eq(p.player_name, "Jo the Fossil Hu")
	assert_eq(PlayerProfile.from_dict(p.to_dict(), catalog).player_name, p.player_name)
	assert_false(p.tour_done, "new players get the tour")
	var old_save := PlayerProfile.new_game(9).to_dict()
	old_save.erase("tour_done")
	assert_true(PlayerProfile.from_dict(old_save, catalog).tour_done, "old saves skip the tour")


func test_restart_starts_a_brand_new_game() -> void:
	# What Session.restart_game saves in place of the old profile.
	var fresh := PlayerProfile.new_game(77)
	assert_eq(fresh.player_name, "", "asks for a name again")
	assert_false(fresh.partner_chosen, "asks for a partner again")
	assert_false(fresh.tour_done)
	assert_true(fresh.first_steps_active)
	assert_eq(fresh.owned.size(), Economy.STARTER_BASICS.size())
	assert_eq(fresh.amber, 0)
	assert_eq(fresh.wins + fresh.losses, 0)
	assert_eq(fresh.battle.size(), 0)


func test_sets_cover_every_dino_once_and_pay_once() -> void:
	var family_of := {}
	for id in DinoSets.FAMILIES:
		for dino_id in DinoSets.members(id):
			assert_false(family_of.has(dino_id), "%s is in two families" % dino_id)
			family_of[dino_id] = id
	for dino in catalog.dinos:
		assert_true(family_of.has(dino.id), "%s has a family" % dino.id)
	for id in DinoSets.ids():
		for dino_id in DinoSets.members(id):
			assert_true(catalog.find(dino_id) != null, "%s in %s is a real dino" % [dino_id, id])
	var p := PlayerProfile.new_game(1)
	assert_false(DinoSets.claim(p, &"croc_cousins"), "not complete yet")
	for dino_id in DinoSets.members(&"croc_cousins"):
		p.add_dino(catalog.find(dino_id), false)
	assert_true(DinoSets.ready(p, &"croc_cousins"))
	assert_true(Goals.anything_to_claim(p, catalog))
	var amber := p.amber
	assert_true(DinoSets.claim(p, &"croc_cousins"))
	assert_eq(p.amber, amber + 3 * DinoSets.AMBER_PER_DINO)
	assert_false(DinoSets.claim(p, &"croc_cousins"), "only once")
	assert_eq(DinoSets.sets_of(&"t_rex"), [&"hunters", &"famous_five"] as Array[StringName])


func test_exported_save_imports_and_rejects_damaged_files() -> void:
	var p := PlayerProfile.new_game(321)
	p.set_player_name("Jo")
	p.amber = 777
	p.add_dino(catalog.find(&"t_rex"), true)
	p.record_battle(true, &"rae")
	var text := SaveStore.export_text(p)
	var back := SaveStore.parse_export(text, catalog)
	assert_true(back != null, "a fresh export loads")
	assert_eq(JSON.stringify(back.to_dict()), JSON.stringify(p.to_dict()), "everything comes back")
	assert_true(SaveStore.export_date(text) != "")
	# Editing the save inside the file breaks the check.
	var edited := text.replace("\\\"amber\\\":%d" % p.amber, "\\\"amber\\\":99999")
	assert_true(edited != text, "the edit applied")
	assert_true(SaveStore.parse_export(edited, catalog) == null, "an edited file is refused")
	assert_true(SaveStore.parse_export("{}", catalog) == null, "not a save")
	assert_true(SaveStore.parse_export("not json", catalog) == null, "not even JSON")
	assert_true(SaveStore.parse_export(JSON.stringify(p.to_dict()), catalog) == null, "a raw save isn't an export")
