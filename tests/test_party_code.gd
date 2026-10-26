extends "res://tests/test_case.gd"
## Party codes, ghost duels' rivals and the friends list (core/collection/party_code.gd).

var catalog := DinoCatalog.load_default()

const PARTY: Array[StringName] = [&"t_rex", &"pteranodon", &"mosasaurus", &"coelophysis", &"plesiosaurus", &"icarosaurus"]


func test_every_dino_has_a_permanent_number() -> void:
	for dino in catalog.dinos:
		assert_true(dino.id in PartyCode.DINO_NUMBERS, "%s needs a number in PartyCode.DINO_NUMBERS (add it at the end)" % dino.id)
	var unique := {}
	for id in PartyCode.DINO_NUMBERS:
		assert_false(unique.has(id), "%s is numbered twice" % id)
		unique[id] = true
	assert_true(PartyCode.DINO_NUMBERS.size() <= 255, "a number has to fit in one byte")


func test_a_code_round_trips() -> void:
	var shiny: Array[StringName] = [&"t_rex"]
	var code := PartyCode.encode("Zoë", "Sea squad", PARTY, shiny)
	assert_true(code.begins_with(PartyCode.PREFIX))
	var info := PartyCode.decode(code, catalog)
	assert_eq(info["player"], "Zoë")
	assert_eq(info["party"], "Sea squad")
	assert_eq(info["ids"], PARTY)
	assert_eq(info["shiny_ids"], shiny)
	assert_eq(info["code"], code)


func test_a_code_is_found_inside_a_pasted_message() -> void:
	var code := PartyCode.encode("Sam", "Party 1", PARTY)
	var message := "Can you beat my Dino Duel party? 🦖\nPaste this code:\n%s\nhttps://example.com" % code
	assert_eq(PartyCode.decode(message, catalog).get("code", ""), code)
	assert_true(PartyCode.decode("no code here", catalog).is_empty())


func test_damaged_or_unbattleable_codes_are_rejected() -> void:
	var code := PartyCode.encode("Sam", "Party 1", PARTY)
	var flipped := code.substr(0, 8) + ("A" if code[8] != "A" else "B") + code.substr(9)
	assert_true(PartyCode.decode(flipped, catalog).is_empty(), "a changed character fails the checksum")
	assert_true(PartyCode.decode(code.left(code.length() - 6), catalog).is_empty(), "a cut-off code")
	var legends: Array[StringName] = []
	for dino in catalog.dinos:
		if dino.rarity == DinoDef.Rarity.LEGENDARY and legends.size() < PartyRules.BRING_SIZE:
			legends.append(dino.id)
	assert_true(PartyCode.decode(PartyCode.encode("Sam", "Big", legends), catalog).is_empty(),
			"a party whose 3 cheapest go over the cap can't battle")


func test_the_ghost_rival_brings_the_party_and_picks_a_legal_3() -> void:
	var info := PartyCode.decode(PartyCode.encode("Sam", "Party 1", PARTY), catalog)
	var rival := PartyCode.make_rival(info, catalog)
	assert_eq(rival.id, PartyCode.FRIEND_ID)
	assert_eq(rival.display_name, "Sam")
	assert_eq(rival.brings.size(), PartyRules.BRING_SIZE)
	var picked := rival.pick_party(rival.make_ai(7))
	assert_eq(PartyRules.validate(picked), "")


func test_friends_list_keeps_records_and_updates_by_name() -> void:
	var p := PlayerProfile.new_game(40)
	var first := PartyCode.decode(PartyCode.encode("Sam", "Party 1", PARTY), catalog)
	p.remember_friend(first)
	p.record_friend_duel(first, true)
	p.record_friend_duel(first, false)
	p.record_friend_duel(first, true)
	assert_eq(p.friend_record("sam"), [2, 1], "names match whatever the case")
	var newer: Array[StringName] = PARTY.duplicate()
	newer[0] = &"triceratops"
	var second := PartyCode.decode(PartyCode.encode("Sam", "Sea squad", newer), catalog)
	p.remember_friend(second)
	assert_eq(p.friends.size(), 1, "a newer code from the same friend replaces the old one")
	assert_eq(p.friends[0]["code"], second["code"])
	assert_eq(p.friend_record("Sam"), [2, 1], "and their record stays")
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), catalog)
	assert_eq(loaded.friends, p.friends, "saved")
	for i in PlayerProfile.FRIENDS_MAX + 5:
		p.remember_friend({"code": "DD1-x%d" % i, "player": "Friend %d" % i, "party": "P"})
	assert_eq(p.friends.size(), PlayerProfile.FRIENDS_MAX)


func test_friend_duels_count_for_quests_not_achievements() -> void:
	var p := PlayerProfile.new_game(41)
	Goals.refresh_quests(p, 500)
	p.quests[0] = {"id": "win_2", "progress": 0, "claimed": false}
	var party: Array[DinoDef] = [catalog.find(&"coelophysis"), catalog.find(&"eudimorphodon"), catalog.find(&"tanystropheus")]
	Goals.on_battle(p, {"won": true, "party": party, "turns": 5, "dinos_left": 3, "friendly": true})
	assert_eq(int(p.quests[0]["progress"]), 1, "a friend duel win counts for Win 2 battles")
	assert_false(Goals.achievement_unlocked(p, catalog, &"flawless"), "but not for achievements")
	assert_false(Goals.achievement_unlocked(p, catalog, &"lightning"))
