extends "res://tests/test_case.gd"

var catalog := DinoCatalog.load_default()


func _party(ids: Array) -> Array[DinoDef]:
	var defs: Array[DinoDef] = []
	for id in ids:
		defs.append(catalog.find(id))
	return defs


func _win(profile: PlayerProfile, party: Array[DinoDef], turns := 15, left := 2) -> void:
	profile.record_battle(true, Journey.find(&"rae"), left)
	Goals.on_battle(profile, {"won": true, "rival_id": &"rae", "party": party,
			"turns": turns, "dinos_left": left})


func test_quests_are_three_distinct_and_stable_for_a_day() -> void:
	var p := PlayerProfile.new_game(11)
	Goals.refresh_quests(p, 500)
	assert_eq(p.quests.size(), Goals.QUESTS_PER_DAY)
	var groups := {}
	for quest in p.quests:
		groups[Goals.QUEST_POOL[StringName(quest["id"])][3]] = true
	assert_eq(groups.size(), Goals.QUESTS_PER_DAY, "no two quests of the same kind")
	var first := JSON.stringify(p.quests)
	p.quests[0]["progress"] = 1
	Goals.refresh_quests(p, 500)
	assert_eq(int(p.quests[0]["progress"]), 1, "same day keeps progress")
	Goals.refresh_quests(p, 501)
	assert_eq(p.quest_day, 501)
	assert_true(p.quests.all(func(q: Dictionary) -> bool: return int(q["progress"]) == 0), "new day, fresh quests")
	var again := PlayerProfile.new_game(11)
	Goals.refresh_quests(again, 500)
	assert_eq(JSON.stringify(again.quests), first, "same player and day roll the same quests")


func test_quest_progress_claim_and_bonus() -> void:
	var p := PlayerProfile.new_game(12)
	p.quest_day = 1
	p.quests = [{"id": "win_2", "progress": 0, "claimed": false},
			{"id": "win_sea", "progress": 0, "claimed": false},
			{"id": "hatch_3", "progress": 0, "claimed": false}]
	var sea_party := _party([&"ichthyosaurus", &"stegosaurus", &"rhamphorhynchus"])
	_win(p, sea_party)
	assert_eq(int(p.quests[0]["progress"]), 1)
	assert_eq(int(p.quests[1]["progress"]), 1, "a Sea dino was in the party")
	assert_false(Goals.claim_quest(p, 0), "1 of 2 wins isn't done")
	var amber := p.amber
	assert_true(Goals.claim_quest(p, 1))
	assert_eq(p.amber, amber + Goals.quest_reward(p.quests[1]))
	assert_false(Goals.claim_quest(p, 1), "only once")
	p.record_battle(false, Journey.find(&"rae"))
	Goals.on_battle(p, {"won": false, "party": sea_party, "turns": 10, "dinos_left": 0})
	assert_eq(int(p.quests[0]["progress"]), 1, "losses don't count as wins")
	_win(p, sea_party)
	p.clutches = 1
	p.hatch_clutch(catalog)
	assert_eq(int(p.quests[2]["progress"]), 3)
	assert_true(Goals.quest_bonus_ready(p))
	var clutches := p.clutches
	assert_true(Goals.claim_quest_bonus(p))
	assert_eq(p.clutches, clutches + Goals.QUEST_BONUS_CLUTCHES)
	assert_false(Goals.claim_quest_bonus(p), "bonus only once a day")


func test_collection_milestones_and_eras() -> void:
	var p := PlayerProfile.new_game(13)
	p.choose_partner(&"tanystropheus")
	assert_false(Goals.milestone_ready(p, 0), "6 starters aren't 10 dinos yet")
	for dino in catalog.dinos.slice(0, 10):
		p.owned[dino.id] = false
	assert_true(Goals.milestone_ready(p, 0))
	var amber := p.amber
	var clutches_before := p.clutches
	assert_true(Goals.claim_milestone(p, 0))
	assert_eq(p.amber, amber + Goals.MILESTONES[0][1])
	assert_eq(p.clutches, clutches_before, "milestones pay Amber only")
	assert_false(Goals.claim_milestone(p, 0))
	assert_false(Goals.milestone_ready(p, 1), "20 not reached yet")
	assert_false(Goals.era_ready(p, catalog, 0))
	for dino in catalog.dinos:
		if dino.era == 0:
			p.owned[dino.id] = false
	amber = p.amber
	assert_true(Goals.claim_era(p, catalog, 0))
	assert_eq(p.amber, amber + Goals.ERA_AMBER)
	assert_false(Goals.claim_era(p, catalog, 0), "only once")


func test_claim_all_takes_every_ready_reward_and_counts_by_section() -> void:
	var p := PlayerProfile.new_game(15)
	p.choose_partner(&"tanystropheus")
	var today := 900
	Goals.refresh_quests(p, today)
	for quest in p.quests:
		quest["progress"] = Goals.quest_target(quest)
	for dino in catalog.dinos:
		if dino.era == 0:
			p.owned[dino.id] = false
	var today_ready := Goals.ready_in(Goals.Section.TODAY, p, catalog, today)
	assert_eq(today_ready, 1 + Goals.QUESTS_PER_DAY + 1, "check-in, 3 quests and the day's bonus")
	assert_true(Goals.ready_in(Goals.Section.COLLECTION, p, catalog, today) >= 3, "milestones 10 and 20 and the Triassic")
	var total := Goals.ready_total(p, catalog, today)
	var amber := p.amber
	var result := Goals.claim_all(p, catalog, today)
	assert_true(result["count"] >= total, "everything ready, plus anything the claims unlocked")
	assert_eq(result["amber"], p.amber - amber)
	assert_true(result["clutches"] >= Economy.DAILY_CLUTCHES + Goals.QUEST_BONUS_CLUTCHES, "check-in and quest bonus clutches")
	assert_eq(Goals.ready_total(p, catalog, today), 0, "nothing left to claim")
	assert_false(Goals.anything_to_claim(p, catalog))
	assert_eq(Goals.claim_all(p, catalog, today)["count"], 0, "a second go claims nothing")


func test_achievements_track_battles_hatches_and_crafts() -> void:
	var p := PlayerProfile.new_game(14)
	var perfect := _party([&"coelophysis", &"eudimorphodon", &"tanystropheus"])
	assert_true(PartyRules.has_era_bond(perfect) and PartyRules.is_balanced(perfect), "test party is Triassic and balanced")
	_win(p, perfect, 7, 3)
	for id in [&"first_win", &"flawless", &"lightning", &"perfect_party"]:
		assert_true(Goals.achievement_unlocked(p, catalog, id), "%s unlocked" % id)
	assert_false(Goals.achievement_unlocked(p, catalog, &"last_standing"))
	_win(p, perfect, 22, 1)
	assert_true(Goals.achievement_unlocked(p, catalog, &"last_standing"))
	assert_true(Goals.achievement_unlocked(p, catalog, &"meteor"))
	var amber := p.amber
	assert_true(Goals.claim_achievement(p, catalog, &"first_win"))
	assert_eq(p.amber, amber + Goals.ACHIEVEMENTS[&"first_win"][3])
	assert_false(Goals.claim_achievement(p, catalog, &"first_win"))
	assert_false(Goals.claim_achievement(p, catalog, &"champion"), "not unlocked")
	p.amber = 5000
	var rex := catalog.find(&"t_rex")
	p.craft(rex)
	assert_true(Goals.achievement_unlocked(p, catalog, &"crafter"))
	assert_true(Goals.achievement_unlocked(p, catalog, &"amber_hoard"), "had 1000+ Amber")


func test_goals_survive_a_save() -> void:
	var p := PlayerProfile.new_game(15)
	Goals.refresh_quests(p, 900)
	_win(p, _party([&"coelophysis", &"eudimorphodon", &"ichthyosaurus"]))
	Goals.claim_achievement(p, catalog, &"first_win")
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(JSON.stringify(loaded.quests), JSON.stringify(p.quests))
	assert_eq(loaded.quest_day, 900)
	assert_true(Goals.achievement_claimed(loaded, &"first_win"))
	assert_eq(Goals.achievement_progress(loaded, catalog, &"flawless"), Goals.achievement_progress(p, catalog, &"flawless"))
	var old_save := PlayerProfile.new_game(16).to_dict()
	for key in ["stats", "quest_day", "quests", "quest_bonus_claimed", "claimed_goals"]:
		old_save.erase(key)
	var old := PlayerProfile.from_dict(old_save, catalog)
	assert_eq(old.quests.size(), 0)
	assert_eq(old.claimed_goals.size(), 0)
