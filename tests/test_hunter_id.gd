extends "res://tests/test_case.gd"
## The Fossil Hunter ID (core/collection/hunter_id.gd): avatars, titles, showcase, win streaks.

var catalog := DinoCatalog.load_default()


func _profile() -> PlayerProfile:
	var p := PlayerProfile.new_game(60)
	p.choose_partner(&"dilophosaurus")
	return p


func test_avatar_falls_back_to_the_partner() -> void:
	var p := _profile()
	assert_eq(HunterId.avatar_of(p), "dino:dilophosaurus", "no avatar chosen: the partner")
	p.avatar = "dino:t_rex"
	assert_eq(HunterId.avatar_of(p), "dino:dilophosaurus", "a dino you don't own doesn't count")
	p.add_dino(catalog.find(&"t_rex"), false)
	assert_eq(HunterId.avatar_of(p), "dino:t_rex")
	p.avatar = HunterId.PROFESSAUR
	assert_eq(HunterId.avatar_of(p), HunterId.PROFESSAUR, "the Professaur is always there")


func test_rivals_become_avatars_once_beaten() -> void:
	var p := _profile()
	assert_false(HunterId.avatar_unlocked(p, "rival:rae"))
	p.record_battle(true, Journey.find(&"rae"), 3)
	assert_true(HunterId.avatar_unlocked(p, "rival:rae"))
	assert_true("rival:rae" in HunterId.avatar_choices(p, catalog))
	p.record_battle(true, Journey.find(&"rory_triassic"), 1)
	p.record_battle(true, Journey.find(&"rory_jurassic"), 1)
	assert_eq(HunterId.beaten_rivals(p).count("rory"), 1, "Rory is one avatar, however many times he's beaten")
	var choices := HunterId.avatar_choices(p, catalog)
	assert_true(choices.find("dino:dilophosaurus") > choices.find(HunterId.PROFESSAUR), "rivals and the Professaur first")


func test_titles_unlock_from_play() -> void:
	var p := _profile()
	assert_true(HunterId.title_unlocked(p, catalog, "hunter"))
	assert_false(HunterId.title_unlocked(p, catalog, "streak"))
	for i in HunterId.STREAK_TITLE_WINS:
		p.record_battle(true, Journey.find(&"rae"), 3)
	assert_eq(p.best_win_streak, HunterId.STREAK_TITLE_WINS)
	assert_true(HunterId.title_unlocked(p, catalog, "streak"))
	p.record_battle(false, Journey.find(&"fern"))
	assert_eq(p.win_streak, 0, "a loss ends the streak")
	assert_eq(p.best_win_streak, HunterId.STREAK_TITLE_WINS, "but the best stays")
	p.title = "complete"
	assert_eq(HunterId.title_of(p, catalog), HunterId.DEFAULT_TITLE, "a locked title shows as Fossil Hunter")
	p.title = "streak"
	assert_eq(HunterId.title_text(HunterId.title_of(p, catalog)), "Unstoppable")
	var set_id: StringName = DinoSets.ids()[0]
	for id in DinoSets.members(set_id):
		p.owned[id] = false
	assert_true(HunterId.title_unlocked(p, catalog, "set:%s" % set_id), "completing a set gives its title")
	assert_true(HunterId.title_text("set:%s" % set_id).ends_with("Collector"))
	for id in HunterId.titles():
		assert_true(HunterId.title_text(id) != "" and HunterId.title_how(id) != "", "%s has a name and a how" % id)


func test_profile_saves_and_drops_what_is_gone() -> void:
	var p := _profile()
	p.add_dino(catalog.find(&"t_rex"), true)
	p.avatar = "dino:t_rex"
	p.title = "hunter"
	p.showcase.assign([&"t_rex", &"dilophosaurus"])
	p.record_battle(true, Journey.find(&"rae"), 3)
	var data := p.to_dict()
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(data)), catalog)
	assert_eq([loaded.avatar, loaded.title, loaded.showcase, loaded.best_win_streak],
			[p.avatar, p.title, p.showcase, p.best_win_streak])
	data["showcase"] = ["t_rex", "spinosaurus", "t_rex", "dilophosaurus", "coelophysis"]
	var cleaned := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(data)), catalog)
	assert_eq(cleaned.showcase, [&"t_rex", &"dilophosaurus", &"coelophysis"] as Array[StringName],
			"unowned and repeated dinos dropped, at most 3")
	assert_eq(HunterId.stats(p, catalog).size(), 9)
	assert_eq(HunterId.rarest_dino(p, catalog).id, &"t_rex")
