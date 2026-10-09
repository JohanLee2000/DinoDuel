extends Control
## Party Battle screen. Takes the player's secret action, asks the rival AI for its own, resolves
## the turn with BattleEngine, then replays the engine's event list as simple animations.
##
## The engine finishes the whole turn instantly, so this screen keeps its own copy of each dino's
## shown HP (_shown_health) and updates it event by event as the animation plays.

enum Phase { CHOOSE_ACTION, CHOOSE_SWAP, CHOOSE_REPLACEMENT, ANIMATING, OVER }

const PLAYER := 0
const RIVAL := 1
const STEP_PAUSE := 0.6
const MATCHUP_TEXT := {
	"0-1": "Bite beats Charge!", "1-0": "Bite beats Charge!",
	"1-2": "Charge smashes through Brace!", "2-1": "Charge smashes through Brace!",
	"2-0": "Brace beats Bite!", "0-2": "Brace beats Bite!",
}
const BUTTON_COLORS: Array[Color] = [Color("d92b3a"), Color("ff7a1a"), Color("2e7bff"), Color("34445e")]
const MOVE_ICON_SIZE := 40
const BENCH_CARD_WIDTH := 92.0
## The layout is designed for a 1280-unit-tall screen. Taller phones (most modern ones, 19.5:9 and
## up) get bigger cards instead of an empty band above the buttons; this many extra units of
## height make the cards 100% bigger, up to MAX_CARD_SCALE.
const EXTRA_HEIGHT_PER_SCALE := 900.0
## Height the layout needs at the current text sizes before cards start growing.
const BASE_LAYOUT_HEIGHT := 1320.0
const MAX_CARD_SCALE := 1.3
## First battle (tutorial): the rival's scripted moves for the opening turns, and the counter the
## coach suggests for each, so the player meets the whole triangle once.
const COACH_RIVAL_MOVES: Array[BattleAction.Kind] = [BattleAction.Kind.BITE, BattleAction.Kind.BRACE,
		BattleAction.Kind.CHARGE]
const COACH_PLAYER_MOVES: Array[BattleAction.Kind] = [BattleAction.Kind.BRACE, BattleAction.Kind.CHARGE,
		BattleAction.Kind.BITE]
const COACH_SCRIPT_TIPS: Array[String] = [
	"%s is about to [b]Bite[/b]. [b]Brace[/b] blocks a Bite and bites back. Tap [b]Brace[/b]!",
	"%s is raising a [b]Brace[/b]. [b]Charge[/b] smashes through it for double damage. Tap [b]Charge[/b]!",
	"%s is winding up a [b]Charge[/b]. [b]Bite[/b] hits first and cancels it. Tap [b]Bite[/b]!",
]
## Room kept free for the coach's tip box when sizing the cards.
const COACH_PANEL_HEIGHT := 175.0
const PICKER_CARD_WIDTH := 200.0

var _state: BattleState
var _ai: BattleAI
## Plays the player's side in --autoplay debug mode.
var _autopilot: BattleAI
var _phase := Phase.ANIMATING
var _active_cards: Array[DinoCard] = [null, null]
## Per side: party index -> bench DinoCard.
var _bench_cards: Array[Dictionary] = [{}, {}]
## Per side: the HP currently on screen for each party member.
var _shown_health: Array = [[], []]
var _log_lines: Array[String] = []
var _card_scale := 1.0
var _coaching := false
var _backdrop: BattleBackdrop
## The "who comes in?" panel shown for a swap or after a knockout.
var _picker: Control
var _leave_button: Button
var _leave_dialog: Control
var _coach_panel: PanelContainer
var _coach_text: RichTextLabel
var _coach_pulse: Tween
var _coach_tips_given := {}
var _last_player_kind := -1

@onready var _slots: Array[Control] = [%PlayerSlot, %EnemySlot]
@onready var _benches: Array[VBoxContainer] = [%PlayerBench, %EnemyBench]
@onready var _buttons: Array[Button] = [%BiteButton, %ChargeButton, %BraceButton, %SwapButton]
@onready var _rival_name: Label = %RivalName
@onready var _turn_label: Label = %TurnLabel
@onready var _log: RichTextLabel = %Log
@onready var _hint: Label = %Hint
@onready var _overlay: ColorRect = %Overlay


func _ready() -> void:
	_coaching = Session.coaching
	Sound.music(&"battle")
	var extra_height := get_viewport_rect().size.y - BASE_LAYOUT_HEIGHT
	if _coaching:
		extra_height -= COACH_PANEL_HEIGHT
	_card_scale = clampf(1.0 + extra_height / EXTRA_HEIGHT_PER_SCALE, 1.0, MAX_CARD_SCALE)
	_state = BattleEngine.create(Session.player_party, Session.rival_party)
	_ai = Session.rival.make_ai(Session.battle_seed)
	# Continuing a battle the game was closed during: replay its moves to get back to that point.
	var resumed := not Session.resume_events.is_empty()
	if resumed:
		BattleReplay.replay(_state, _ai, Session.resume_events)
		Session.resume_events = []
	_backdrop = BattleBackdrop.new()
	add_child(_backdrop)
	move_child(_backdrop, $Background.get_index() + 1)
	resized.connect(_update_backdrop_focus.call_deferred)
	if Session.autoplay:
		_autopilot = BattleAI.new(Session.battle_seed + 1)

	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(Palette.PANEL, 0.92)
	log_style.border_color = Palette.PANEL_BORDER
	log_style.set_border_width_all(1)
	log_style.set_corner_radius_all(8)
	log_style.set_content_margin_all(10)
	_rival_name.add_theme_font_override("font", Fonts.title())
	_turn_label.add_theme_font_override("font", Fonts.condensed_bold())
	%LogPanel.add_theme_stylebox_override("panel", log_style)
	for i in _buttons.size():
		UiKit.style_button(_buttons[i], BUTTON_COLORS[i])
		_buttons[i].icon = Icons.texture(Icons.MOVES[i], MOVE_ICON_SIZE)
		_buttons[i].add_theme_constant_override("icon_max_width", MOVE_ICON_SIZE)
		_buttons[i].icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_buttons[0].pressed.connect(func() -> void: _submit(BattleAction.bite()))
	_buttons[1].pressed.connect(func() -> void: _submit(BattleAction.charge()))
	_buttons[2].pressed.connect(func() -> void: _submit(BattleAction.brace()))
	_buttons[3].pressed.connect(_on_swap_pressed)
	UiKit.style_button(%HatchButton, UiKit.BUTTON_AMBER)
	UiKit.style_button(%RematchButton, UiKit.BUTTON_GREEN)
	UiKit.style_button(%BackButton, UiKit.BUTTON_GRAY)
	%HatchButton.pressed.connect(Session.go_to_main.bind(Session.Tab.EGGS))
	%RematchButton.pressed.connect(Session.go_to_pre_battle)
	%BackButton.pressed.connect(Session.go_to_main.bind(Session.Tab.BATTLE))

	_rival_name.text = Session.rival.display_name
	var help := UiKit.button("?", UiKit.BUTTON_GRAY, 52, 28)
	help.custom_minimum_size.x = 64
	help.pressed.connect(func() -> void: HelpView.open())
	_turn_label.get_parent().add_child(help)
	_leave_button = UiKit.button("Leave", UiKit.BUTTON_RED, 52, 24)
	_leave_button.custom_minimum_size.x = 110
	_leave_button.pressed.connect(_confirm_leave)
	_turn_label.get_parent().add_child(_leave_button)
	if _coaching:
		_build_coach()
	for side in 2:
		_snapshot_health(side)
		_rebuild_side(side)
	if resumed:
		_say("[b]Battle resumed.[/b] Turn %d against %s." % [_state.turn, Session.rival.display_name])
		_after_turn()
		return
	_say("[b]%s[/b] sends out [b]%s[/b]. Go, [b]%s[/b]!" % [Session.rival.display_name,
			_name(RIVAL), _name(PLAYER)])
	var bonuses: Array[String] = []
	if _state.side(PLAYER).era_bond:
		bonuses.append("Era bond")
	if _state.side(PLAYER).balanced:
		bonuses.append("Balanced party")
	if not bonuses.is_empty():
		_say("Your party bonuses: %s." % ", ".join(bonuses))
	if _coaching:
		await HelpView.open(0, true).closed
	_begin_choice()


# --- Player input ---------------------------------------------------------------------------

func _begin_choice() -> void:
	_hide_picker()
	_phase = Phase.CHOOSE_ACTION
	_turn_label.text = "Turn %d" % _state.turn
	_hint.text = "Choose your move. %s picks at the same time." % Session.rival.display_name
	_set_bench_highlight(false)
	_update_buttons()
	if _coaching:
		_coach_turn()
	if _autopilot:
		await get_tree().create_timer(0.7).timeout
		if _coaching and _state.turn <= COACH_PLAYER_MOVES.size():
			_submit(BattleAction.of_kind(COACH_PLAYER_MOVES[_state.turn - 1]))
		else:
			_submit(_autopilot.choose_action(_state, PLAYER))


func _update_buttons() -> void:
	var me := _state.side(PLAYER).active_dino()
	var them := _state.side(RIVAL).active_dino()
	var edge := " +50%" if BattleEngine.has_advantage(me, them) else ""
	_buttons[0].text = "Bite: %d dmg%s\nbeats Charge" % [BattleEngine.damage(me, them, false), edge]
	_buttons[1].text = "Charge: %d dmg%s\nbeats Brace, acts last" % [BattleEngine.damage(me, them, true), edge]
	var can_brace := BattleEngine.is_legal(_state, PLAYER, BattleAction.brace())
	_buttons[2].text = "Brace\nbeats Bite" if can_brace else "Brace\nresting this turn"
	var can_swap := not _state.side(PLAYER).bench().is_empty()
	_buttons[3].text = "Cancel swap" if _phase == Phase.CHOOSE_SWAP else "Swap\ngoes first"
	var choosing := _phase == Phase.CHOOSE_ACTION or _phase == Phase.CHOOSE_SWAP
	for i in 3:
		_buttons[i].disabled = not choosing or _phase == Phase.CHOOSE_SWAP
	_buttons[2].disabled = _buttons[2].disabled or not can_brace
	_buttons[3].disabled = not choosing or not can_swap


func _on_swap_pressed() -> void:
	if _phase == Phase.CHOOSE_SWAP:
		_begin_choice()
		return
	_phase = Phase.CHOOSE_SWAP
	_hint.text = "Tap a benched dino to swap in."
	_set_bench_highlight(true)
	_update_buttons()
	_show_picker(false)


func _on_bench_pressed(side: int, index: int) -> void:
	if side != PLAYER or not index in _state.side(PLAYER).bench():
		return
	if _phase in [Phase.CHOOSE_ACTION, Phase.CHOOSE_SWAP, Phase.CHOOSE_REPLACEMENT]:
		Sound.play(&"card_pick")
	match _phase:
		Phase.CHOOSE_ACTION, Phase.CHOOSE_SWAP:
			_submit(BattleAction.swap(index))
		Phase.CHOOSE_REPLACEMENT:
			_replace_player(index)


func _submit(action: BattleAction) -> void:
	if _phase != Phase.CHOOSE_ACTION and _phase != Phase.CHOOSE_SWAP:
		return
	_phase = Phase.ANIMATING
	_hide_picker()
	_set_bench_highlight(false)
	_update_buttons()
	_hint.text = ""
	_stop_coach_highlight()
	_last_player_kind = action.kind

	var rival_action := _ai.choose_action(_state, RIVAL)
	if _coaching and _state.turn <= COACH_RIVAL_MOVES.size():
		var scripted := BattleAction.of_kind(COACH_RIVAL_MOVES[_state.turn - 1])
		if BattleEngine.is_legal(_state, RIVAL, scripted):
			rival_action = scripted
	var pair: Array[BattleAction] = [action, rival_action]
	for side in 2:
		_snapshot_health(side)
	var events := BattleEngine.resolve_turn(_state, pair)
	_ai.observe(action)
	Session.record_battle_event(BattleReplay.turn_event(action, rival_action))
	if _autopilot:
		_autopilot.observe(rival_action)
	await _play(events)
	await _after_turn()


func _after_turn() -> void:
	if not _state.is_over() and _state.side(RIVAL).needs_replacement():
		var index := _ai.choose_replacement(_state, RIVAL)
		Session.record_battle_event([BattleReplay.RIVAL_REPLACE, index])
		await _play(BattleEngine.replace_active(_state, RIVAL, index))
	if _state.is_over():
		_show_result()
		return
	if _state.side(PLAYER).needs_replacement():
		_phase = Phase.CHOOSE_REPLACEMENT
		_hint.text = "Choose who comes in next."
		_set_bench_highlight(true)
		_update_buttons()
		_show_picker(true)
		if _autopilot:
			# Store screenshots need the "who comes in?" panel on screen long enough to capture.
			await get_tree().create_timer(3.0 if Session.store_shots else 0.7).timeout
			_replace_player(_autopilot.choose_replacement(_state, PLAYER))
		return
	_begin_choice()


func _replace_player(index: int) -> void:
	if _phase != Phase.CHOOSE_REPLACEMENT:
		return
	_phase = Phase.ANIMATING
	_hide_picker()
	_set_bench_highlight(false)
	Session.record_battle_event([BattleReplay.PLAYER_REPLACE, index])
	await _play(BattleEngine.replace_active(_state, PLAYER, index))
	_begin_choice()


# --- Event playback -------------------------------------------------------------------------

func _play(events: Array[Dictionary]) -> void:
	for event in events:
		match event["type"]:
			"turn_start":
				var kinds: Array = event["actions"]
				_say("You: [b]%s[/b]   %s: [b]%s[/b]" % [BattleAction.KIND_NAMES[kinds[0]],
						Session.rival.display_name, BattleAction.KIND_NAMES[kinds[1]]])
				var key := "%d-%d" % [kinds[0], kinds[1]]
				if MATCHUP_TEXT.has(key):
					_say("[color=#ffd166]%s[/color]" % MATCHUP_TEXT[key])
				await _pause()
			"swap", "replace":
				var side: int = event["side"]
				Sound.play(&"swap")
				_rebuild_side(side)
				var verb := "swap" if event["type"] == "swap" else "send"
				if side == RIVAL:
					verb += "s"
				_say("%s %s in [b]%s[/b]." % [_who(side), verb, _name(side)])
				await _pause()
			"brace":
				Sound.play(&"brace")
				_popup(_active_cards[event["side"]], "BRACE", Palette.HIGHLIGHT)
			"blocked":
				Sound.play(&"block")
				_popup(_active_cards[event["side"]], "BLOCKED!", Palette.HIGHLIGHT)
				await _pause(0.4)
			"bite", "counter", "charge":
				await _show_hit(event)
			"charge_cancelled":
				Sound.play(&"interrupted")
				_popup(_active_cards[event["side"]], "INTERRUPTED", Palette.TEXT_DIM)
				_say("%s's charge was interrupted." % _name(event["side"]))
				await _pause()
			"meteor":
				var target: int = event["target_side"]
				Sound.play(&"meteor")
				_set_shown_health(target, _state.side(target).active, event["health_after"])
				_popup(_active_cards[target], "-%d" % event["damage"], Palette.DAMAGE)
				_active_cards[target].tween_health(event["health_after"])
				_say("Meteor shower hits %s for %d!" % [_name(target), event["damage"]])
				await _pause(0.4)
			"ko":
				Sound.play(&"ko")
				_say("[color=#ff6b5e]%s is knocked out![/color]" % _state.side(event["side"]).party[event["index"]].def.display_name)
				await _pause()
			"heal":
				var side: int = event["side"]
				_set_shown_health(side, event["index"], event["health_after"])
				if _bench_cards[side].has(event["index"]):
					_bench_cards[side][event["index"]].tween_health(event["health_after"])


func _show_hit(event: Dictionary) -> void:
	var side: int = event["side"]
	var target: int = event["target_side"]
	var attacker_card := _active_cards[side]
	var target_card := _active_cards[target]
	var lunge := Vector2(0, -36 if side == PLAYER else 36)
	# The charge sound builds up during the lunge; its slam is timed to land with the hit.
	if event["type"] == "charge":
		Sound.play(&"charge", 0.88 if event["advantage"] else 1.0)
	var tween := create_tween()
	tween.tween_property(attacker_card, "position", lunge, 0.12)
	tween.tween_property(attacker_card, "position", Vector2.ZERO, 0.15)
	await tween.finished

	_set_shown_health(target, _state.side(target).active, event["health_after"])
	target_card.tween_health(event["health_after"])
	_shake(target_card)
	# Type-edge hits land a little lower and heavier.
	if event["type"] != "charge":
		Sound.play(&"bite", 0.88 if event["advantage"] else 1.0)
	var label := "-%d" % event["damage"]
	if event["type"] == "charge":
		label = "CHARGE -%d" % event["damage"]
	elif event["type"] == "counter":
		label = "COUNTER -%d" % event["damage"]
	_popup(target_card, label, Palette.DAMAGE)
	var verb: String = {"bite": "bites", "counter": "counter-bites", "charge": "charges"}[event["type"]]
	var edge := " [color=#ffd166](type edge!)[/color]" if event["advantage"] else ""
	_say("%s %s for %d.%s" % [_name(side), verb, event["damage"], edge])
	await _pause()


func _pause(seconds := STEP_PAUSE) -> void:
	await get_tree().create_timer(seconds).timeout


func _shake(card: DinoCard) -> void:
	var tween := create_tween()
	for offset in [12.0, -10.0, 6.0, 0.0]:
		tween.tween_property(card, "position:x", offset, 0.05)


## A floating label that drifts up from a card and fades out.
func _popup(card: DinoCard, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_font_override("font", Fonts.condensed_bold())
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.global_position = card.global_position + Vector2(card.size.x / 2 - 60, card.size.y * 0.3)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


# --- Board ----------------------------------------------------------------------------------

func _rebuild_side(side: int) -> void:
	var battle_side := _state.side(side)
	if _active_cards[side]:
		_active_cards[side].queue_free()
	var card := DinoCard.create(battle_side.active_dino().def, DinoCard.Mode.BATTLE,
			battle_side.active_dino(), _is_shiny(side, battle_side.active_dino().def),
			DinoCard.WIDTHS[DinoCard.Mode.BATTLE] * _card_scale)
	card.display_health(_shown_health[side][battle_side.active])
	_slots[side].custom_minimum_size = card.size
	_slots[side].add_child(card)
	_active_cards[side] = card
	# Each side's half of the background follows its active dino's type.
	_backdrop.set_types(_state.side(PLAYER).active_dino().def.dino_type, _state.side(RIVAL).active_dino().def.dino_type)
	_update_backdrop_focus.call_deferred()

	for child in _benches[side].get_children():
		child.queue_free()
	_bench_cards[side] = {}
	var bench_label := UiKit.label("BENCH", 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	bench_label.add_theme_font_override("font", Fonts.condensed_bold())
	_benches[side].add_child(bench_label)
	for i in battle_side.party.size():
		if i == battle_side.active:
			continue
		var mini := DinoCard.create(battle_side.party[i].def, DinoCard.Mode.MINI, battle_side.party[i],
				_is_shiny(side, battle_side.party[i].def), BENCH_CARD_WIDTH * _card_scale)
		mini.display_health(_shown_health[side][i])
		mini.pressed.connect(_on_bench_pressed.bind(side, i))
		_benches[side].add_child(mini)
		_bench_cards[side][i] = mini


func _update_backdrop_focus() -> void:
	if _active_cards[RIVAL] and _active_cards[PLAYER]:
		_backdrop.set_focus(_slots[RIVAL].get_global_rect(), _slots[PLAYER].get_global_rect())


func _is_shiny(side: int, dino: DinoDef) -> bool:
	return side == PLAYER and Session.profile.is_shiny(dino.id)


func _set_bench_highlight(on: bool) -> void:
	var bench := _state.side(PLAYER).bench()
	for index in _bench_cards[PLAYER]:
		_bench_cards[PLAYER][index].highlighted = on and index in bench


func _snapshot_health(side: int) -> void:
	_shown_health[side] = []
	for dino in _state.side(side).party:
		_shown_health[side].append(dino.health)


func _set_shown_health(side: int, index: int, health: int) -> void:
	_shown_health[side][index] = health


func _show_result() -> void:
	_phase = Phase.OVER
	_leave_button.hide()
	if _leave_dialog:
		_leave_dialog.queue_free()
	_update_buttons()
	var left := 0
	for dino in _state.side(PLAYER).party:
		if not dino.is_knocked_out():
			left += 1
	var title := "Draw"
	if _state.winner == PLAYER:
		title = "Victory!"
	elif _state.winner == RIVAL:
		title = "Defeat"
	%ResultTitle.text = title
	Sound.play(&"victory" if _state.winner == PLAYER else &"defeat")
	_stop_coach_highlight()
	if _coach_panel:
		_coach_panel.hide()
	var reward := Session.finish_battle(_state.winner == PLAYER, _state.turn - 1, left)
	var gains: Array[String] = []
	if reward["clutches"] > 0:
		gains.append("%d egg clutch" % reward["clutches"])
	gains.append("%d Amber" % reward["amber"])
	%ResultDetail.text = "%d turns · %d of %d dinos still standing
Rewards: %s" % [_state.turn - 1,
			left, _state.side(PLAYER).party.size(), " + ".join(gains)]
	%HatchButton.visible = reward["clutches"] > 0
	if _coaching:
		%ResultDetail.text += "\n\nTutorial done! Tap ? in any battle to see the rules again."
	_overlay.show()
	if _autopilot:
		await get_tree().create_timer(2.5).timeout
		if Session.autoplay_battles_left > 0:
			Session.autoplay_battles_left -= 1
			Session.go_to_main(Session.Tab.EGGS)
		else:
			get_tree().quit()


# --- Leaving -------------------------------------------------------------------------------

func _confirm_leave() -> void:
	if _phase == Phase.OVER or _leave_dialog:
		return
	_leave_dialog = UiKit.modal_layer(0.75)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := UiKit.vbox(18)
	column.custom_minimum_size.x = 560
	column.add_child(UiKit.title("Leave this battle?", 38, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("It counts as a loss against %s, with no Amber." % Session.rival.display_name, 26,
			Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var stay := UiKit.button("Keep fighting", UiKit.BUTTON_GREEN, 84, 30)
	stay.pressed.connect(func() -> void:
		_leave_dialog.queue_free()
		_leave_dialog = null)
	column.add_child(stay)
	var leave := UiKit.button("Leave battle", UiKit.BUTTON_RED, 76, 26)
	leave.pressed.connect(Session.forfeit_battle)
	column.add_child(leave)
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))
	_leave_dialog.add_child(center)
	add_child(_leave_dialog)


## Android back button: same as Leave (asks first).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# A help page or card view on top handles back itself.
		if get_children().any(func(child: Node) -> bool: return child is HelpView or child is CardViewer):
			return
		_confirm_leave()


# --- Choosing who comes in ------------------------------------------------------------------

## A panel over the move buttons with the benched dinos as big cards: after a knockout (must pick)
## or for a swap (can cancel by tapping Cancel or anywhere outside).
func _show_picker(knocked_out: bool) -> void:
	_hide_picker()
	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	if not knocked_out:
		shade.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				_begin_choice())
	_picker.add_child(shade)

	var column := UiKit.vbox(14)
	var fallen := _state.side(PLAYER).active_dino().def.display_name
	column.add_child(UiKit.title("%s is knocked out!" % fallen if knocked_out else "Swap in which dino?", 34,
			Palette.DAMAGE if knocked_out else Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("Tap who comes in next. Benched dinos keep the HP they have." if knocked_out
			else "Swap goes first this turn, and the dino you swap out heals on the bench.", 25, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER))
	var row := UiKit.hbox(20, BoxContainer.ALIGNMENT_CENTER)
	var side := _state.side(PLAYER)
	for index in side.bench():
		var dino := side.party[index]
		var card := DinoCard.create(dino.def, DinoCard.Mode.BATTLE, dino, _is_shiny(PLAYER, dino.def), PICKER_CARD_WIDTH)
		card.display_health(_shown_health[PLAYER][index])
		card.highlighted = true
		card.pressed.connect(_on_bench_pressed.bind(PLAYER, index))
		row.add_child(card)
	column.add_child(row)
	if not knocked_out:
		var cancel := UiKit.button("Cancel", UiKit.BUTTON_GRAY, 76, 28)
		cancel.pressed.connect(_begin_choice)
		column.add_child(cancel)

	var panel := UiKit.panel(column, Palette.PANEL, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Pinned to the bottom: a full-screen column with a stretchy spacer above the panel.
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for margin in [["left", 12], ["right", 12], ["bottom", 24]]:
		holder.add_theme_constant_override("margin_" + margin[0], margin[1])
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	stack.add_child(panel)
	holder.add_child(stack)
	_picker.add_child(holder)
	_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picker)
	_picker.modulate.a = 0.0
	_picker.create_tween().tween_property(_picker, "modulate:a", 1.0, 0.2)


func _hide_picker() -> void:
	if _picker:
		_picker.queue_free()
		_picker = null


# --- Coach (first battle) -------------------------------------------------------------------

func _build_coach() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PANEL, 0.96)
	style.border_color = Palette.HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_coach_panel = PanelContainer.new()
	_coach_panel.add_theme_stylebox_override("panel", style)
	var row := UiKit.hbox(12)
	_coach_text = RichTextLabel.new()
	_coach_text.bbcode_enabled = true
	_coach_text.fit_content = true
	_coach_text.scroll_active = false
	_coach_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coach_text.add_theme_font_size_override("normal_font_size", 28)
	_coach_text.add_theme_font_size_override("bold_font_size", 28)
	_coach_text.add_theme_font_override("bold_font", Fonts.bold())
	_coach_text.add_theme_color_override("default_color", Palette.TEXT)
	row.add_child(_coach_text)
	var skip := UiKit.button("Skip tips", UiKit.BUTTON_GRAY, 56, 24)
	skip.custom_minimum_size.x = 130
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_skip_coach)
	row.add_child(skip)
	_coach_panel.add_child(row)
	_coach_panel.hide()
	var column := _hint.get_parent()
	column.add_child(_coach_panel)
	column.move_child(_coach_panel, _hint.get_index() + 1)


## Picks this turn's tip: the scripted opening, then one-off tips the first time they apply.
func _coach_turn() -> void:
	var turn := _state.turn
	var rival_name := Session.rival.display_name
	if turn <= COACH_RIVAL_MOVES.size():
		var lead := ""
		if turn > 1 and _last_player_kind == COACH_PLAYER_MOVES[turn - 2]:
			lead = "Nice! "
		_coach_show(lead + COACH_SCRIPT_TIPS[turn - 1] % rival_name, COACH_PLAYER_MOVES[turn - 1])
		return
	var me := _state.side(PLAYER).active_dino()
	var them := _state.side(RIVAL).active_dino()
	var can_swap := not _state.side(PLAYER).bench().is_empty()
	if turn == COACH_RIVAL_MOVES.size() + 1:
		_coach_show("That's the whole triangle! From now on %s picks freely, so watch for habits." % rival_name)
		return
	if BattleEngine.has_advantage(me, them) and _coach_once(&"edge",
			"Your type beats theirs: [b]+50% damage[/b]. That's the [b]+50%[/b] on the move buttons. Land beats Sky, Sky beats Sea, Sea beats Land."):
		return
	if can_swap and BattleEngine.has_advantage(them, me) and _coach_once(&"bad_edge",
			"Careful: their type beats yours. [b]Swap[/b] to a different type to dodge the extra damage."):
		return
	if can_swap and me.health * 10 <= me.max_health * 4 and _coach_once(&"low",
			"Low on HP? [b]Swap[/b] goes first, and benched dinos heal 1 HP every turn."):
		return
	_coach_panel.hide()


## Shows a tip only the first time `key` comes up. Returns whether it was shown.
func _coach_once(key: StringName, text: String) -> bool:
	if _coach_tips_given.has(key):
		return false
	_coach_tips_given[key] = true
	_coach_show(text)
	return true


func _coach_show(text: String, highlight := -1) -> void:
	_coach_text.text = text
	_coach_panel.show()
	_stop_coach_highlight()
	if highlight < 0:
		return
	var button := _buttons[highlight]
	button.pivot_offset = button.size / 2
	_coach_pulse = button.create_tween().set_loops()
	_coach_pulse.tween_property(button, "scale", Vector2(1.06, 1.06), 0.35)
	_coach_pulse.tween_property(button, "scale", Vector2.ONE, 0.35)


func _stop_coach_highlight() -> void:
	if _coach_pulse:
		_coach_pulse.kill()
		_coach_pulse = null
	for button in _buttons:
		button.scale = Vector2.ONE


func _skip_coach() -> void:
	_coaching = false
	Session.coaching = false
	Session.profile.tutorial_done = true
	Session.save()
	_stop_coach_highlight()
	_coach_panel.hide()


# --- Text helpers ---------------------------------------------------------------------------

func _say(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 3:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func _name(side: int) -> String:
	var prefix := "" if side == PLAYER else "Rival "
	return prefix + _state.side(side).active_dino().def.display_name


func _who(side: int) -> String:
	return "You" if side == PLAYER else Session.rival.display_name
