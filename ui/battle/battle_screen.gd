extends Control
## Herd Battle screen. Takes the player's secret action, asks the rival AI for its own, resolves
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
const BUTTON_COLORS: Array[Color] = [Color("b54a3c"), Color("c97a26"), Color("3a6fb0"), Color("5a6275")]

var _state: BattleState
var _ai: BattleAI
## Plays the player's side in --autoplay debug mode.
var _autopilot: BattleAI
var _phase := Phase.ANIMATING
var _active_cards: Array[DinoCard] = [null, null]
## Per side: herd index -> bench DinoCard.
var _bench_cards: Array[Dictionary] = [{}, {}]
## Per side: the HP currently on screen for each herd member.
var _shown_health: Array = [[], []]
var _log_lines: Array[String] = []

@onready var _slots: Array[Control] = [%PlayerSlot, %EnemySlot]
@onready var _benches: Array[VBoxContainer] = [%PlayerBench, %EnemyBench]
@onready var _buttons: Array[Button] = [%BiteButton, %ChargeButton, %BraceButton, %SwapButton]
@onready var _rival_name: Label = %RivalName
@onready var _turn_label: Label = %TurnLabel
@onready var _log: RichTextLabel = %Log
@onready var _hint: Label = %Hint
@onready var _overlay: ColorRect = %Overlay


func _ready() -> void:
	_state = BattleEngine.create(Session.player_herd, Session.rival_herd)
	_ai = Session.rival.make_ai(Session.battle_seed)
	if Session.autoplay:
		_autopilot = BattleAI.new(Session.battle_seed + 1)

	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Palette.PANEL
	log_style.set_corner_radius_all(12)
	log_style.set_content_margin_all(10)
	%LogPanel.add_theme_stylebox_override("panel", log_style)
	for i in _buttons.size():
		_style_button(_buttons[i], BUTTON_COLORS[i])
	_buttons[0].pressed.connect(func() -> void: _submit(BattleAction.bite()))
	_buttons[1].pressed.connect(func() -> void: _submit(BattleAction.charge()))
	_buttons[2].pressed.connect(func() -> void: _submit(BattleAction.brace()))
	_buttons[3].pressed.connect(_on_swap_pressed)
	_style_button(%RematchButton, Color("3f8f55"))
	_style_button(%NewHerdButton, BUTTON_COLORS[3])
	%RematchButton.pressed.connect(Session.rematch)
	%NewHerdButton.pressed.connect(Session.back_to_herd_select)

	_rival_name.text = Session.rival.display_name
	for side in 2:
		_snapshot_health(side)
		_rebuild_side(side)
	_say("[b]%s[/b] sends out [b]%s[/b]. Go, [b]%s[/b]!" % [Session.rival.display_name,
			_name(RIVAL), _name(PLAYER)])
	var bonuses: Array[String] = []
	if _state.side(PLAYER).era_bond:
		bonuses.append("Era bond")
	if _state.side(PLAYER).balanced:
		bonuses.append("Balanced herd")
	if not bonuses.is_empty():
		_say("Your herd bonuses: %s." % ", ".join(bonuses))
	_begin_choice()


# --- Player input ---------------------------------------------------------------------------

func _begin_choice() -> void:
	_phase = Phase.CHOOSE_ACTION
	_turn_label.text = "Turn %d" % _state.turn
	_hint.text = "Choose your move. %s picks at the same time." % Session.rival.display_name
	_set_bench_highlight(false)
	_update_buttons()
	if _autopilot:
		await get_tree().create_timer(0.7).timeout
		_submit(_autopilot.choose_action(_state, PLAYER))


func _update_buttons() -> void:
	var me := _state.side(PLAYER).active_dino()
	var them := _state.side(RIVAL).active_dino()
	var edge := " (type edge)" if BattleEngine.has_advantage(me, them) else ""
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


func _on_bench_pressed(side: int, index: int) -> void:
	if side != PLAYER or not index in _state.side(PLAYER).bench():
		return
	match _phase:
		Phase.CHOOSE_ACTION, Phase.CHOOSE_SWAP:
			_submit(BattleAction.swap(index))
		Phase.CHOOSE_REPLACEMENT:
			_replace_player(index)


func _submit(action: BattleAction) -> void:
	if _phase != Phase.CHOOSE_ACTION and _phase != Phase.CHOOSE_SWAP:
		return
	_phase = Phase.ANIMATING
	_set_bench_highlight(false)
	_update_buttons()
	_hint.text = ""

	var rival_action := _ai.choose_action(_state, RIVAL)
	var pair: Array[BattleAction] = [action, rival_action]
	for side in 2:
		_snapshot_health(side)
	var events := BattleEngine.resolve_turn(_state, pair)
	_ai.observe(action)
	if _autopilot:
		_autopilot.observe(rival_action)
	await _play(events)
	await _after_turn()


func _after_turn() -> void:
	if not _state.is_over() and _state.side(RIVAL).needs_replacement():
		var index := _ai.choose_replacement(_state, RIVAL)
		await _play(BattleEngine.replace_active(_state, RIVAL, index))
	if _state.is_over():
		_show_result()
		return
	if _state.side(PLAYER).needs_replacement():
		_phase = Phase.CHOOSE_REPLACEMENT
		_hint.text = "Choose who comes in next."
		_set_bench_highlight(true)
		_update_buttons()
		if _autopilot:
			await get_tree().create_timer(0.7).timeout
			_replace_player(_autopilot.choose_replacement(_state, PLAYER))
		return
	_begin_choice()


func _replace_player(index: int) -> void:
	if _phase != Phase.CHOOSE_REPLACEMENT:
		return
	_phase = Phase.ANIMATING
	_set_bench_highlight(false)
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
				_rebuild_side(side)
				var verb := "swaps in" if event["type"] == "swap" else "sends in"
				_say("%s %s [b]%s[/b]." % [_who(side), verb, _name(side)])
				await _pause()
			"brace":
				_popup(_active_cards[event["side"]], "BRACE", Palette.HIGHLIGHT)
			"blocked":
				_popup(_active_cards[event["side"]], "BLOCKED!", Palette.HIGHLIGHT)
				await _pause(0.4)
			"bite", "counter", "charge":
				await _show_hit(event)
			"charge_cancelled":
				_popup(_active_cards[event["side"]], "INTERRUPTED", Palette.TEXT_DIM)
				_say("%s's charge was interrupted." % _name(event["side"]))
				await _pause()
			"meteor":
				var target: int = event["target_side"]
				_set_shown_health(target, _state.side(target).active, event["health_after"])
				_popup(_active_cards[target], "-%d" % event["damage"], Palette.DAMAGE)
				_active_cards[target].tween_health(event["health_after"])
				_say("Meteor shower hits %s for %d!" % [_name(target), event["damage"]])
				await _pause(0.4)
			"ko":
				_say("[color=#ff6b5e]%s is knocked out![/color]" % _state.side(event["side"]).herd[event["index"]].def.display_name)
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
	var tween := create_tween()
	tween.tween_property(attacker_card, "position", lunge, 0.12)
	tween.tween_property(attacker_card, "position", Vector2.ZERO, 0.15)
	await tween.finished

	_set_shown_health(target, _state.side(target).active, event["health_after"])
	target_card.tween_health(event["health_after"])
	_shake(target_card)
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
	label.add_theme_font_size_override("font_size", 34)
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
			battle_side.active_dino())
	card.display_health(_shown_health[side][battle_side.active])
	_slots[side].add_child(card)
	_active_cards[side] = card

	for child in _benches[side].get_children():
		child.queue_free()
	_bench_cards[side] = {}
	for i in battle_side.herd.size():
		if i == battle_side.active:
			continue
		var mini := DinoCard.create(battle_side.herd[i].def, DinoCard.Mode.MINI, battle_side.herd[i])
		mini.display_health(_shown_health[side][i])
		mini.pressed.connect(_on_bench_pressed.bind(side, i))
		_benches[side].add_child(mini)
		_bench_cards[side][i] = mini


func _set_bench_highlight(on: bool) -> void:
	var bench := _state.side(PLAYER).bench()
	for index in _bench_cards[PLAYER]:
		_bench_cards[PLAYER][index].highlighted = on and index in bench


func _snapshot_health(side: int) -> void:
	_shown_health[side] = []
	for dino in _state.side(side).herd:
		_shown_health[side].append(dino.health)


func _set_shown_health(side: int, index: int, health: int) -> void:
	_shown_health[side][index] = health


func _show_result() -> void:
	_phase = Phase.OVER
	_update_buttons()
	var left := 0
	for dino in _state.side(PLAYER).herd:
		if not dino.is_knocked_out():
			left += 1
	var title := "Draw"
	if _state.winner == PLAYER:
		title = "Victory!"
	elif _state.winner == RIVAL:
		title = "Defeat"
	%ResultTitle.text = title
	%ResultDetail.text = "%d turns · %d of %d dinos still standing" % [_state.turn - 1, left,
			_state.side(PLAYER).herd.size()]
	_overlay.show()
	if _autopilot:
		await get_tree().create_timer(2.5).timeout
		get_tree().quit()


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


func _style_button(button: Button, color: Color) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(14)
		style.set_content_margin_all(8)
		match state_name:
			"normal":
				style.bg_color = color
			"hover":
				style.bg_color = color.lightened(0.12)
			"pressed":
				style.bg_color = color.darkened(0.2)
			"disabled":
				style.bg_color = color.darkened(0.6)
			"focus":
				style.draw_center = false
				style.border_color = Palette.HIGHLIGHT
				style.set_border_width_all(3)
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
