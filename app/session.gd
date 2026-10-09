extends Node
## App-wide state that survives scene changes. Registered as an autoload named `Session`:
## Godot creates one instance at startup and every script can reach it by name, a bit like a
## React context provider at the root of the app.

signal profile_changed

const MAIN_SCENE := "res://ui/main/main.tscn"
const PRE_BATTLE_SCENE := "res://ui/pre_battle/pre_battle.tscn"
const BATTLE_SCENE := "res://ui/battle/battle_screen.tscn"
## Debug builds also read dev flags from this file (see _ready).
const DEV_ARGS_FILE := "user://dev_args.txt"

enum Tab { BATTLE, PARTY, EGGS, DEX, GOALS }

var catalog: DinoCatalog
var profile: PlayerProfile
var rival: RivalDef
## Every rival, easiest first.
var rivals: Array[RivalDef] = []
var player_party: Array[DinoDef] = []
var rival_party: Array[DinoDef] = []
var battle_seed := 0
## True during the player's first battle, which comes with a coach (see BattleScreen).
var coaching := false
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
## Dev: a showcase save for Play Store screenshots (everything collected, no DEV buttons) that
## never touches real progress. Pass `--store-shots`.
var store_shots := false
## Dev: a brand-new throwaway save whose first battle is coached even under --autoplay, to watch
## the tutorial. Pass `--tutorial`.
var dev_tutorial := false
## Dev: open a popup on launch for screenshots: `--open=settings` or `--open=help`.
var dev_open := ""
## Dev: scroll the Dex to this era on launch (0 Triassic, 1 Jurassic, 2 Cretaceous). `--dex-era=N`.
var dev_dex_era := -1


func _ready() -> void:
	Sound.setup(get_tree())
	catalog = DinoCatalog.load_default()
	rivals = RivalDef.load_roster()
	rival = rivals[0]
	var args := OS.get_cmdline_user_args()
	if OS.is_debug_build() and FileAccess.file_exists(DEV_ARGS_FILE):
		# Phones have no command line, so USB debug installs read dev flags from this file
		# (pushed with adb), e.g. "--store-shots --tab=3".
		args.append_array(FileAccess.get_file_as_string(DEV_ARGS_FILE).strip_edges().split(" ", false))
	autoplay = "--autoplay" in args
	if autoplay:
		# Autoplay runs get their own throwaway save so they never touch real progress.
		SaveStore.folder = "user://autoplay"
		SaveStore.delete_all()
		autoplay_battles_left = 1
	elif "--sandbox" in args:
		# Dev: reuse the last autoplay save instead of real progress.
		SaveStore.folder = "user://autoplay"
	store_shots = "--store-shots" in args
	if store_shots:
		SaveStore.folder = "user://store_shots"
		SaveStore.delete_all()
	dev_tutorial = "--tutorial" in args
	if dev_tutorial:
		SaveStore.folder = "user://tutorial"
		SaveStore.delete_all()
	if "--fresh-save" in args:
		SaveStore.delete_all()
	for arg in args:
		if arg.begins_with("--tab="):
			current_tab = int(arg.get_slice("=", 1))
		elif arg.begins_with("--open-dex="):
			dev_open_dex = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--open-card="):
			dev_open_card = arg.get_slice("=", 1)
		elif arg.begins_with("--open="):
			dev_open = arg.get_slice("=", 1)
		elif arg.begins_with("--dex-era="):
			dev_dex_era = int(arg.get_slice("=", 1))
		elif arg.begins_with("--rival="):
			# Dev: which rival --autoplay challenges.
			for each in rivals:
				if each.id == StringName(arg.get_slice("=", 1)):
					rival = each
	profile = SaveStore.load_profile(catalog)
	if profile == null:
		profile = _showcase_profile() if store_shots else PlayerProfile.new_game(randi())
		save()
	refresh_quests()


## Dev: the save the store screenshots show. Built directly rather than with
## PlayerProfile.unlock_all, so it keeps working after that is deleted for release.
func _showcase_profile() -> PlayerProfile:
	# Seed 136's first egg is Brachiosaurus, so it's left out here and hatches as a new UR.
	var showcase := PlayerProfile.new_game(136)
	for dino in catalog.dinos:
		if dino.id != &"brachiosaurus":
			showcase.owned[dino.id] = dino.id in [&"t_rex", &"mosasaurus", &"quetzalcoatlus"]
	var lineup: Array[StringName] = [&"t_rex", &"pteranodon", &"mosasaurus", &"velociraptor",
			&"triceratops", &"quetzalcoatlus"]
	showcase.set_lineup(lineup)
	for result in [[&"rae", true], [&"rae", true], [&"fern", true], [&"fern", false], [&"cora", true],
			[&"dusty", false]]:
		showcase.record_battle(result[1], result[0])
	showcase.amber = 1240
	showcase.tutorial_done = true
	showcase.partner_chosen = true
	showcase.player_name = "Jo"
	showcase.tour_done = true
	showcase.first_steps_active = false
	showcase.clutches = 1
	return showcase


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


## Opens the pick screen against `chosen`, or the current rival (e.g. for a rematch).
func go_to_pre_battle(chosen: RivalDef = null) -> void:
	if chosen:
		rival = chosen
	for dino in rival.brings:
		profile.mark_seen(dino.id)
	save()
	get_tree().change_scene_to_file(PRE_BATTLE_SCENE)


## The rival picks its party now, without seeing the player's pick.
func start_battle(party: Array[DinoDef]) -> void:
	player_party = party
	battle_seed = randi()
	rival_party = rival.make_ai(battle_seed).choose_party(rival.brings, rival.point_cap)
	coaching = wants_coach()
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Whether the next battle gets the tutorial coach: only the player's first one.
func wants_coach() -> bool:
	return not profile.tutorial_done and (not autoplay or dev_tutorial)


## Leaving a battle partway (see BattleScreen): recorded as a loss with no reward. A coached first
## battle stays unfinished, so the coach comes back next time.
func forfeit_battle() -> void:
	profile.record_forfeit(rival.id)
	coaching = false
	save()
	go_to_main(Tab.BATTLE)


func rematch() -> void:
	start_battle(player_party)


## Applies rewards and saves. Returns {"amber": int, "clutches": int}.
## Rolls today's daily quests if the day has changed since they were last rolled.
func refresh_quests() -> void:
	var day := profile.quest_day
	Goals.refresh_quests(profile, SaveStore.today())
	if profile.quest_day != day:
		save()


## `turns` and `dinos_left` feed daily quests and achievements (see Goals.on_battle).
func finish_battle(won: bool, turns := 0, dinos_left := 0) -> Dictionary:
	refresh_quests()
	var reward := profile.record_battle(won, rival.id)
	Goals.on_battle(profile, {"won": won, "rival_id": rival.id, "difficulty": rival.difficulty,
			"party": player_party, "turns": turns, "dinos_left": dinos_left})
	if coaching:
		profile.tutorial_done = true
		coaching = false
	save()
	return reward
