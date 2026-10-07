extends Node
## App-wide state that survives scene changes. Registered as an autoload named `Session`:
## Godot creates one instance at startup and every script can reach it by name, a bit like a
## React context provider at the root of the app.

const HERD_SELECT_SCENE := "res://ui/herd_select/herd_select.tscn"
const BATTLE_SCENE := "res://ui/battle/battle_screen.tscn"

var catalog: DinoCatalog
var rival: RivalDef
var player_herd: Array[DinoDef] = []
var rival_herd: Array[DinoDef] = []
var battle_seed := 0
## Debug: the AI plays both sides. Pass `-- --autoplay` on the command line.
var autoplay := false


func _ready() -> void:
	catalog = DinoCatalog.load_default()
	rival = load("res://data/rivals/rory.tres")
	autoplay = "--autoplay" in OS.get_cmdline_user_args()


## The rival picks its herd now, without seeing the player's pick.
func start_battle(herd: Array[DinoDef]) -> void:
	player_herd = herd
	battle_seed = randi()
	rival_herd = rival.make_ai(battle_seed).choose_herd(rival.brings, rival.point_cap)
	get_tree().change_scene_to_file(BATTLE_SCENE)


func rematch() -> void:
	start_battle(player_herd)


func back_to_herd_select() -> void:
	get_tree().change_scene_to_file(HERD_SELECT_SCENE)
