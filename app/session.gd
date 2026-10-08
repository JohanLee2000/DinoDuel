extends Node
## App-wide state that survives scene changes. Registered as an autoload named `Session`:
## Godot creates one instance at startup and every script can reach it by name, a bit like a
## React context provider at the root of the app.

signal profile_changed

const MAIN_SCENE := "res://ui/main/main.tscn"
const PRE_BATTLE_SCENE := "res://ui/pre_battle/pre_battle.tscn"
const BATTLE_SCENE := "res://ui/battle/battle_screen.tscn"

enum Tab { BATTLE, PARTY, EGGS, DEX }

var catalog: DinoCatalog
var profile: PlayerProfile
var rival: RivalDef
var player_party: Array[DinoDef] = []
var rival_party: Array[DinoDef] = []
var battle_seed := 0
## A Tab value; kept as int so other scripts can set it from a plain index.
var current_tab: int = Tab.BATTLE
## Debug: the AI plays both sides. Pass `-- --autoplay` on the command line.
var autoplay := false
## In autoplay, battles to play before hatching the rewards and stopping.
var autoplay_battles_left := 0
## Dev: open this dino's Dex popup on launch (for screenshots). Pass `--open-dex=<id>`.
var dev_open_dex: StringName
## Dev: show any card full-screen on launch, owned or not. `--open-card=<id>` or `<id>:shiny`.
var dev_open_card := ""


func _ready() -> void:
	catalog = DinoCatalog.load_default()
	rival = load("res://data/rivals/rory.tres")
	var args := OS.get_cmdline_user_args()
	autoplay = "--autoplay" in args
	if autoplay:
		# Autoplay runs get their own throwaway save so they never touch real progress.
		SaveStore.folder = "user://autoplay"
		SaveStore.delete_all()
		autoplay_battles_left = 1
	elif "--sandbox" in args:
		# Dev: reuse the last autoplay save instead of real progress.
		SaveStore.folder = "user://autoplay"
	if "--fresh-save" in args:
		SaveStore.delete_all()
	for arg in args:
		if arg.begins_with("--tab="):
			current_tab = int(arg.get_slice("=", 1))
		elif arg.begins_with("--open-dex="):
			dev_open_dex = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--open-card="):
			dev_open_card = arg.get_slice("=", 1)
	profile = SaveStore.load_profile(catalog)
	if profile == null:
		profile = PlayerProfile.new_game(randi())
		save()


## Call after every change to the profile. Saves are small, so saving often is cheap and means
## progress survives the app being killed in the background.
func save() -> void:
	SaveStore.save_profile(profile)
	profile_changed.emit()


## Opens the main tabs. Pass -1 to keep the last tab.
func go_to_main(tab: int = -1) -> void:
	if tab >= 0:
		current_tab = tab
	get_tree().change_scene_to_file(MAIN_SCENE)


func go_to_pre_battle() -> void:
	for dino in rival.brings:
		profile.mark_seen(dino.id)
	save()
	get_tree().change_scene_to_file(PRE_BATTLE_SCENE)


## The rival picks its party now, without seeing the player's pick.
func start_battle(party: Array[DinoDef]) -> void:
	player_party = party
	battle_seed = randi()
	rival_party = rival.make_ai(battle_seed).choose_party(rival.brings, rival.point_cap)
	get_tree().change_scene_to_file(BATTLE_SCENE)


func rematch() -> void:
	start_battle(player_party)


## Applies rewards and saves. Returns {"amber": int, "clutches": int}.
func finish_battle(won: bool) -> Dictionary:
	var reward := profile.record_battle(won)
	save()
	return reward
