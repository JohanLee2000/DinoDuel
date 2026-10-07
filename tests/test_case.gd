extends RefCounted
## Base for test files. Any method starting with "test_" is run by tests/run_tests.gd.

var failures: Array[String] = []
var current_test := ""


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		_fail("expected %s, got %s. %s" % [expected, actual, message])


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		_fail("expected true. %s" % message)


func assert_false(condition: bool, message := "") -> void:
	if condition:
		_fail("expected false. %s" % message)


func _fail(text: String) -> void:
	failures.append("%s: %s" % [current_test, text])


## Builds a throwaway dino for a test. Defaults to a plain Land Common.
func make_dino(attack: int, defense: int, speed: int, health: int,
		dino_type := DinoDef.DinoType.LAND, era := DinoDef.Era.TRIASSIC,
		rarity := DinoDef.Rarity.COMMON) -> DinoDef:
	var dino := DinoDef.new()
	dino.id = StringName("test_%d" % dino.get_instance_id())
	dino.display_name = dino.id
	dino.attack = attack
	dino.defense = defense
	dino.speed = speed
	dino.health = health
	dino.dino_type = dino_type
	dino.era = era
	dino.rarity = rarity
	return dino


func herd(dinos: Array) -> Array[DinoDef]:
	var result: Array[DinoDef] = []
	result.assign(dinos)
	return result


func actions(player: BattleAction, opponent: BattleAction) -> Array[BattleAction]:
	var result: Array[BattleAction] = [player, opponent]
	return result


func events_of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event["type"] == type:
			result.append(event)
	return result
