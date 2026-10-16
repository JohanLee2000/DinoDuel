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
## Moves to replay when continuing a saved battle (see resume_saved_battle); empty for a new one.
var resume_events: Array = []
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
## The day the check-in last popped up by itself (it does so once a day).
var _checkin_prompt_day := -1
## Dev: `--tab-timing` opens every tab twice and writes how long each took to user://tab_timing.txt.
var dev_tab_timing := false
## Dev: a showcase save for Play Store screenshots (everything collected, no DEV buttons) that
## never touches real progress. Pass `--store-shots`.
var store_shots := false
## Dev: a brand-new throwaway save whose first battle is coached even under --autoplay, to watch
## the tutorial. Pass `--tutorial`.
var dev_tutorial := false
## Dev: open a popup on launch for screenshots: `--open=settings` or `--open=help`.
var dev_open := ""
## Dev: how many dinos the pick screen picks for you (`--open=prebattle:<stage>:<n>`).
var dev_prepick := 0
## Dev: scroll the Dex to this era on launch (0 Triassic, 1 Jurassic, 2 Cretaceous). `--dex-era=N`.
var dev_dex_era := -1


func _ready() -> void:
	Sound.setup(get_tree())
	catalog = DinoCatalog.load_default()
	rivals = Journey.stages()
	rival = rivals[0]
	var args := OS.get_cmdline_user_args()
	if OS.is_debug_build() and FileAccess.file_exists(DEV_ARGS_FILE):
		# Phones have no command line, so USB debug installs read dev flags from this file
		# (pushed with adb), e.g. "--store-shots --tab=3".
		args.append_array(FileAccess.get_file_as_string(DEV_ARGS_FILE).strip_edges().split(" ", false))
	Power.setup(get_tree(), not "--uncapped" in args)
	DinoArt.use_thumbs = not "--no-thumbs" in args
	Journey.dev_unlock_all = "--unlock-stages" in args
	dev_tab_timing = "--tab-timing" in args
	if DisplayServer.get_name() != "headless" and DinoArt.use_thumbs:
		DinoArt.warm_up(catalog)
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
	# Seed 136's first egg is Cymbospondylus, so it's left out here and hatches as a new UR.
	var showcase := PlayerProfile.new_game(136)
	for dino in catalog.dinos:
		if dino.id != &"cymbospondylus":
			showcase.owned[dino.id] = dino.id in [&"t_rex", &"mosasaurus", &"quetzalcoatlus"]
	var lineup: Array[StringName] = [&"t_rex", &"pteranodon", &"mosasaurus", &"velociraptor",
			&"triceratops", &"quetzalcoatlus"]
	showcase.set_lineup(lineup)
	# Journey: the Triassic cleared, partway through the Jurassic. [stage, won, stars].
	for result in [[&"rae", true, 3], [&"fern", true, 3], [&"cora", true, 2], [&"gus", false, 0],
			[&"gus", true, 3], [&"dusty", true, 2], [&"rory_triassic", false, 0], [&"rory_triassic", true, 2],
			[&"pip", true, 3], [&"marina", true, 2], [&"hank", true, 1], [&"sela", false, 0]]:
		showcase.record_battle(result[1], Journey.find(result[0]), result[2])
	showcase.amber = 1240
	showcase.tutorial_done = true
	showcase.partner_chosen = true
	showcase.player_name = "Jo"
	showcase.tour_done = true
	showcase.first_steps_active = false
	showcase.clutches = 1
	showcase.eggs_hatched = 57
	# Mastery ribbons and "new" dots for screenshots.
	for entry in [[&"t_rex", 31, 27, 30, 4], [&"pteranodon", 14, 11, 9, 3], [&"mosasaurus", 12, 10, 12, 1],
			[&"velociraptor", 5, 3, 4, 0], [&"triceratops", 2, 1, 1, 0]]:
		showcase.mastery[String(entry[0])] = {"battles": entry[1], "wins": entry[2], "counters": entry[3], "bosses": entry[4]}
	for id in [&"quetzalcoatlus", &"velociraptor", &"coelophysis"]:
		showcase.new_dinos[id] = true
	# A few recent clutches for the Hatch history (newest first): [rare, hours ago, eggs].
	var now := int(Time.get_unix_time_from_system())
	for clutch in [[true, 1, [[&"quetzalcoatlus", false, true], [&"triceratops", false, false], [&"pteranodon", true, false]]],
			[false, 5, [[&"velociraptor", false, true], [&"coelophysis", false, false], [&"mosasaurus", false, true]]],
			[false, 26, [[&"t_rex", false, true], [&"eudimorphodon", false, false], [&"hesperornis", false, false]]]]:
		var eggs: Array = []
		for egg in clutch[2]:
			var dino := catalog.find(egg[0])
			eggs.append({"id": String(egg[0]), "shiny": egg[1], "new": egg[2], "upgraded": egg[1] and not egg[2],
					"amber": 0 if egg[2] or egg[1] else Economy.MELT_VALUE[dino.rarity]})
		showcase.hatch_history.append({"time": now - clutch[1] * 3600, "rare": clutch[0], "eggs": eggs})
	return showcase


## Call after every change to the profile. Saves are small, so saving often is cheap and means
## progress survives the app being killed in the background.
func save() -> void:
	SaveStore.save_profile(profile)
	profile_changed.emit()


## Settings > Reset game (after the player confirms): deletes the save and starts a brand-new
## game from the name entry. Sound settings are kept; they're device preferences, not progress.
func restart_game() -> void:
	SaveStore.delete_all()
	_switch_profile(PlayerProfile.new_game(randi()))


## Settings > Import save (after the player confirms): the imported progress replaces this
## phone's, and the game starts again from the main screen.
func import_profile(imported: PlayerProfile) -> void:
	_switch_profile(imported)


func _switch_profile(new_profile: PlayerProfile) -> void:
	profile = new_profile
	player_party = []
	rival_party = []
	rival = rivals[0]
	coaching = false
	resume_events = []
	current_tab = Tab.BATTLE
	save()
	refresh_quests()
	go_to_main(Tab.BATTLE)


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
	rival_party = rival.pick_party(rival.make_ai(battle_seed))
	coaching = wants_coach()
	resume_events = []
	# Saved from the start, so the battle can continue if Android closes the game mid-fight.
	profile.battle = {"rival": String(rival.id), "seed": battle_seed, "player": _ids(player_party),
			"rival_party": _ids(rival_party), "coaching": coaching, "events": []}
	save()
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Called by the battle screen after every move (BattleReplay event), so it survives a restart.
func record_battle_event(event: Array) -> void:
	if profile.battle.is_empty():
		return
	profile.battle["events"].append(event)
	save()


## If the game was closed mid-battle, goes back into it. Returns whether it did.
func resume_saved_battle() -> bool:
	var saved := profile.battle
	if saved.is_empty() or autoplay:
		return false
	var found: Array = rivals.filter(func(each: RivalDef) -> bool: return String(each.id) == saved.get("rival", ""))
	var mine := _defs(saved.get("player", []))
	var theirs := _defs(saved.get("rival_party", []))
	if found.is_empty() or mine.size() != PartyRules.PARTY_SIZE or theirs.size() != PartyRules.PARTY_SIZE:
		# Something it refers to no longer exists: drop it rather than crash.
		profile.battle = {}
		save()
		return false
	rival = found[0]
	player_party = mine
	rival_party = theirs
	battle_seed = int(saved.get("seed", 0))
	coaching = bool(saved.get("coaching", false)) and not profile.tutorial_done
	resume_events = (saved.get("events", []) as Array).duplicate(true)
	get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)
	return true


func _ids(party: Array[DinoDef]) -> Array:
	return party.map(func(dino: DinoDef) -> String: return String(dino.id))


func _defs(ids: Array) -> Array[DinoDef]:
	var defs: Array[DinoDef] = []
	for id in ids:
		var dino := catalog.find(StringName(id))
		if dino:
			defs.append(dino)
	return defs


## Whether the main screen should pop up the daily check-in: the first time the game is opened
## (or brought back from the background) on a day it hasn't been claimed, never during the
## new-player intro or in dev runs. Asking uses up the prompt for the day.
func take_checkin_prompt() -> bool:
	var today := SaveStore.today()
	if _checkin_prompt_day == today or autoplay or store_shots or dev_tutorial:
		return false
	if not (profile.partner_chosen and profile.tour_done and profile.can_claim_daily(today)):
		return false
	_checkin_prompt_day = today
	return true


## Whether the next battle gets the tutorial coach: only the player's first one.
func wants_coach() -> bool:
	return not profile.tutorial_done and (not autoplay or dev_tutorial)


## Leaving a battle partway (see BattleScreen): recorded as a loss with no reward. A coached first
## battle stays unfinished, so the coach comes back next time.
func forfeit_battle() -> void:
	profile.battle = {}
	profile.record_forfeit(rival.id)
	coaching = false
	save()
	go_to_main(Tab.BATTLE)


func rematch() -> void:
	start_battle(player_party)


## Rolls today's daily quests if the day has changed since they were last rolled.
func refresh_quests() -> void:
	var day := profile.quest_day
	Goals.refresh_quests(profile, SaveStore.today())
	if profile.quest_day != day:
		save()


## Applies rewards and saves; returns them (see PlayerProfile.record_battle). `dinos_left` is the
## stars a win earns; `turns` and `dinos_left` also feed daily quests and achievements.
func finish_battle(won: bool, turns := 0, dinos_left := 0) -> Dictionary:
	refresh_quests()
	# Mastery: count the battle for each dino in the party, with its counters from the moves played.
	var events: Array = profile.battle.get("events", [])
	var counters := Mastery.counters_in(rival.start_battle(player_party, rival_party), events)
	profile.battle = {}
	var reward := profile.record_battle(won, rival, dinos_left)
	reward["mastery"] = Mastery.record_battle(profile, player_party, won, rival.is_boss, counters)
	Goals.on_battle(profile, {"won": won, "rival_id": rival.id, "party": player_party, "turns": turns,
			"dinos_left": dinos_left, "first_clear": reward["first_clear"],
			"meteor_turn": rival.meteor_turn if rival.meteor_turn > 0 else BattleEngine.METEOR_START_TURN})
	if coaching:
		profile.tutorial_done = true
		coaching = false
	save()
	return reward
