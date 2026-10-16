extends "res://tests/test_case.gd"
## The Dex / Party search, filters and sorting (ui/common/collection_filter.gd). Only its pure
## parts (matches, sorted); the chips themselves aren't built here.

var catalog := DinoCatalog.load_default()


func _profile() -> PlayerProfile:
	var p := PlayerProfile.new_game(1)
	p.choose_partner(&"tanystropheus")
	p.add_dino(catalog.find(&"t_rex"), false)
	p.add_dino(catalog.find(&"mosasaurus"), false)
	p.mark_seen(&"pteranodon")
	return p


func _shown(filter: CollectionFilter, p: PlayerProfile) -> Array[StringName]:
	var ids: Array[StringName] = []
	for dino in catalog.dinos:
		if filter.matches(dino, p):
			ids.append(dino.id)
	filter.free()
	return ids


func test_search_finds_known_names_only() -> void:
	var p := _profile()
	var filter := CollectionFilter.create("test_search")
	filter.query = "REX"
	assert_eq(_shown(filter, p), [&"t_rex"] as Array[StringName], "case doesn't matter")
	filter = CollectionFilter.create("test_search")
	filter.query = "ptera"
	assert_true(&"pteranodon" in _shown(filter, p), "battled dinos can be found by name")
	filter = CollectionFilter.create("test_search")
	filter.query = "Spinosaurus"
	assert_eq(_shown(filter, p).size(), 0, "undiscovered dinos stay ???")


func test_filters_add_up_within_a_group_and_narrow_across_groups() -> void:
	var p := _profile()
	var filter := CollectionFilter.create("test_groups")
	filter.types = {int(DinoDef.DinoType.LAND): true, int(DinoDef.DinoType.SEA): true}
	for id in _shown(filter, p):
		assert_true(catalog.find(id).dino_type != DinoDef.DinoType.SKY)
	filter = CollectionFilter.create("test_groups")
	filter.types = {int(DinoDef.DinoType.SEA): true}
	filter.tiers = {int(DinoDef.Rarity.LEGENDARY): true}
	filter.showing = CollectionFilter.Show.OWNED
	assert_eq(_shown(filter, p), [&"mosasaurus"] as Array[StringName])


func test_show_missing_and_can_craft() -> void:
	var p := _profile()
	var filter := CollectionFilter.create("test_show")
	filter.showing = CollectionFilter.Show.MISSING
	var missing := _shown(filter, p)
	assert_eq(missing.size(), catalog.dinos.size() - p.owned.size())
	filter = CollectionFilter.create("test_show")
	filter.showing = CollectionFilter.Show.CAN_CRAFT
	assert_eq(_shown(filter, p).size(), 0, "no Amber, nothing to craft")
	p.amber = Economy.CRAFT_COST[DinoDef.Rarity.COMMON]
	filter = CollectionFilter.create("test_show")
	filter.showing = CollectionFilter.Show.CAN_CRAFT
	for id in _shown(filter, p):
		assert_eq(catalog.find(id).rarity, DinoDef.Rarity.COMMON)
		assert_false(p.owns(id))


func test_sorts() -> void:
	var p := _profile()
	var owned: Array[DinoDef] = []
	for dino in catalog.dinos:
		if p.owns(dino.id):
			owned.append(dino)
	var filter := CollectionFilter.create("test_sort")
	for sort in [CollectionFilter.Sort.ATTACK, CollectionFilter.Sort.DEFENSE, CollectionFilter.Sort.SPEED]:
		filter.sort = sort
		var stat := func(d: DinoDef) -> int:
			return d.attack if sort == CollectionFilter.Sort.ATTACK else (d.defense if sort == CollectionFilter.Sort.DEFENSE else d.speed)
		var by_stat := filter.sorted(owned)
		for i in by_stat.size() - 1:
			assert_true(stat.call(by_stat[i]) >= stat.call(by_stat[i + 1]), "highest first")
	filter.sort = CollectionFilter.Sort.USUAL
	var usual := filter.sorted(owned)
	for i in usual.size() - 1:
		assert_true(usual[i].dino_type <= usual[i + 1].dino_type, "usual order: Land, Sky, Sea")
	filter.free()
