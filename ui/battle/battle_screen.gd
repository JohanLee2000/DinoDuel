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
## Taller phones (most modern ones, 19.5:9 and up) get bigger cards instead of an empty band above
## the buttons; this many extra units of height make the cards 100% bigger, up to MAX_CARD_SCALE.
const EXTRA_HEIGHT_PER_SCALE := 900.0
## Height the layout needs at the current text sizes before cards start growing.
const BASE_LAYOUT_HEIGHT := 1320.0
const MAX_CARD_SCALE := 1.3
## Shorter screens shrink the cards instead (see _fit_to_screen), down to this.
const MIN_CARD_SCALE := 0.6
## Room kept free when fitting, in case the text box grows later. The fit already measures with the
## opening headline, usually the longest (two lines).
const FIT_SLACK := 24.0
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
const COACH_TRIANGLE_TIP := "That's the whole triangle! From now on %s picks freely, so watch for habits."
const COACH_EDGE_TIP := "Your type beats theirs: [b]+50% damage[/b], already in your move buttons. Land beats Sky, Sky beats Sea, Sea beats Land."
const COACH_BAD_EDGE_TIP := "Careful: their type beats yours. [b]Swap[/b] to a different type to dodge the extra damage."
const COACH_LOW_TIP := "Low on HP? [b]Swap[/b] goes first, and benched dinos heal 1 HP every turn."
const PICKER_CARD_WIDTH := 200.0
const HEADLINE_FONT_SIZE := 29
const HIT_COLOR := Color("ff6b5e")
const METEOR_COLOR := Color("ff8a3d")

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
## Every line of the battle log (the full log opens with a tap on the text box).
var _log_lines: Array[String] = []
## The text box (2026-10-15): the turn's key moment in a pill, the latest lines faded under it.
var _headline_pill: PanelContainer
var _headline_label: Label
var _full_log: Control
## The text box's top row: both moves this turn (centre) and the turn number (right).
var _moves_label: Label
var _box_turn_label: Label
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
var _screen_shake_tween: Tween
## Top bar: per side, a dot for each dino in the party, lit while it's still standing.
var _score_dots: Array = [[], []]
## "Type advantage · bonus included", over the move buttons while the player has the type edge.
var _edge_tag: PanelContainer

@onready var _slots: Array[Control] = [%PlayerSlot, %EnemySlot]
@onready var _benches: Array[VBoxContainer] = [%PlayerBench, %EnemyBench]
@onready var _buttons: Array[Button] = [%BiteButton, %ChargeButton, %BraceButton, %SwapButton]
@onready var _rival_name: Label = %RivalName
@onready var _turn_label: Label = %TurnLabel
@onready var _log: RichTextLabel = %Log
@onready var _hint: Label = %Hint
@onready var _overlay: ColorRect = %Overlay


func _ready() -> void:
	Power.keep_screen_awake(true)
	tree_exiting.connect(Power.keep_screen_awake.bind(false))
	_coaching = Session.coaching
	Sound.music(&"battle")
	var extra_height := get_viewport_rect().size.y - BASE_LAYOUT_HEIGHT
	if _coaching:
		extra_height -= COACH_PANEL_HEIGHT
	_card_scale = clampf(1.0 + extra_height / EXTRA_HEIGHT_PER_SCALE, 1.0, MAX_CARD_SCALE)
	_state = Session.rival.start_battle(Session.player_party, Session.rival_party)
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

	_build_log_box()
	_rival_name.add_theme_font_override("font", Fonts.title())
	_turn_label.add_theme_font_override("font", Fonts.condensed_bold())
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
	UiKit.add_icon(%HatchButton, "Hatch your eggs", &"egg", UiKit.BUTTON_AMBER, 32, Color.WHITE)
	UiKit.style_button(%RematchButton, UiKit.BUTTON_RED)
	UiKit.add_icon(%RematchButton, "Rematch", &"restart", UiKit.BUTTON_RED, 32)
	UiKit.style_button(%BackButton, UiKit.BUTTON_GREEN)
	UiKit.add_icon(%BackButton, "Back to party" if not Session.friend.is_empty() else "Back to journey", &"back",
			UiKit.BUTTON_GREEN, 32)
	%HatchButton.pressed.connect(Session.go_to_main.bind(Session.Tab.EGGS))
	%RematchButton.pressed.connect(Session.go_to_pre_battle)
	%BackButton.pressed.connect(func() -> void: Session.go_to_main(Session.home_tab()))

	_rival_name.text = Session.rival.display_name
	_build_top_bar()
	_build_edge_tag()
	var help := UiKit.button("?", UiKit.BUTTON_GRAY, 52, 28)
	help.custom_minimum_size.x = 64
	help.pressed.connect(func() -> void: HelpView.open(0))
	_turn_label.get_parent().add_child(help)
	_leave_button = UiKit.button("Leave", UiKit.BUTTON_RED, 52, 27)
	_leave_button.custom_minimum_size.x = 110
	_leave_button.pressed.connect(_confirm_leave)
	_turn_label.get_parent().add_child(_leave_button)
	if _coaching:
		_build_coach()
	for side in 2:
		_snapshot_health(side)
		_rebuild_side(side)
	_update_score()
	_fit_to_screen()
	if resumed:
		_log_lines.append(_log_header("Battle resumed"))
		_headline("Battle resumed: turn %d" % _state.turn, Palette.TEXT)
		_after_turn()
		return
	_log_lines.append(_log_header("Battle start"))
	_headline("%s sends out %s. Go, %s!" % [Session.rival.display_name, _name(RIVAL), _name(PLAYER)], Palette.TEXT)
	var bonuses: Array[String] = []
	if _state.side(PLAYER).era_bond:
		bonuses.append("Era bond")
	if _state.side(PLAYER).balanced:
		bonuses.append("Balanced party")
	if not bonuses.is_empty():
		_say("Your party bonuses: %s." % ", ".join(bonuses))
	await _rival_entrance()
	if _coaching:
		await HelpView.open(0, 0, true).closed
	_begin_choice()


## "<Rival> wants to battle!": the rival's sprite slides in over a dark band, then the battle starts.
## Tap to skip.
func _rival_entrance() -> void:
	var art := RivalArt.sprite(Session.rival.character)
	if art == null:
		return
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, 0.0)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var view := get_viewport_rect().size
	var band := ColorRect.new()
	band.color = Color(0.02, 0.04, 0.09, 0.92)
	band.size = Vector2(view.x, 360)
	band.position = Vector2(0, view.y * 0.5 - 180)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band)
	var sprite := TextureRect.new()
	sprite.texture = art
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.size = Vector2(320, 320)
	sprite.position = Vector2(view.x, band.position.y + 20)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sprite)
	var words := UiKit.title("%s\nwants to battle!" % Session.rival.display_name, 40,
			Palette.HIGHLIGHT if Session.rival.is_boss else Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	words.position = Vector2(-view.x, band.position.y + 130)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(words)
	var tween := create_tween()
	tween.tween_property(layer, "color:a", 0.45, 0.15)
	tween.parallel().tween_property(sprite, "position:x", view.x - 340, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(words, "position:x", 28.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Store screenshots need it on screen long enough to capture.
	tween.tween_interval(3.0 if Session.store_shots else (0.5 if Session.autoplay else 1.3))
	tween.tween_property(layer, "modulate:a", 0.0, 0.25)
	var skipped := [false]
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and not skipped[0]:
			skipped[0] = true
			tween.custom_step(10.0))
	await tween.finished
	layer.queue_free()


# --- Player input ---------------------------------------------------------------------------

func _begin_choice() -> void:
	_hide_picker()
	_phase = Phase.CHOOSE_ACTION
	_turn_label.text = "Turn %d" % _state.turn
	_box_turn_label.text = "Turn %d" % _state.turn
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
	_buttons[0].text = "Bite · %d damage\nBeats Charge" % BattleEngine.damage(me, them, false)
	_buttons[1].text = "Charge · %d damage\nBeats Brace, acts last" % BattleEngine.damage(me, them, true)
	var can_brace := BattleEngine.is_legal(_state, PLAYER, BattleAction.brace())
	_buttons[2].text = "Brace\nBeats Bite" if can_brace else "Brace\nReady next turn"
	var can_swap := not _state.side(PLAYER).bench().is_empty()
	if _phase == Phase.CHOOSE_SWAP:
		_buttons[3].text = "Cancel swap"
	else:
		_buttons[3].text = "Swap Dino\nGoes first" if can_swap else "Swap Dino\nNo dinos available"
	var choosing := _phase == Phase.CHOOSE_ACTION or _phase == Phase.CHOOSE_SWAP
	_edge_tag.visible = _phase == Phase.CHOOSE_ACTION and BattleEngine.has_advantage(me, them)
	if _edge_tag.visible:
		# The tag takes the hint line's place (a space keeps the line's height).
		_hint.text = " "
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
				var moves := "You: %s · %s: %s" % [BattleAction.KIND_NAMES[kinds[0]], Session.rival.display_name,
						BattleAction.KIND_NAMES[kinds[1]]]
				_log_lines.append(_log_header("Turn %d" % (_state.turn - 1)))
				_log_lines.append(moves)
				_moves_label.text = moves
				var key := "%d-%d" % [kinds[0], kinds[1]]
				if MATCHUP_TEXT.has(key):
					_headline(MATCHUP_TEXT[key], Palette.HIGHLIGHT)
				elif kinds[0] == kinds[1]:
					_headline("Both %s!" % BattleAction.KIND_NAMES[kinds[0]], Palette.TEXT)
				else:
					_headline("Swap goes first", Palette.TEXT)
				await _pause()
			"swap", "replace":
				var side: int = event["side"]
				Sound.play(&"swap")
				_rebuild_side(side)
				_enter(_active_cards[side])
				var verb := "swap" if event["type"] == "swap" else "send"
				if side == RIVAL:
					verb += "s"
				_headline("%s %s in %s" % [_who(side), verb, _name(side)], Palette.ACCENT.lightened(0.3))
				await _pause()
			"brace":
				Sound.play(&"brace")
				_popup(_active_cards[event["side"]], "BRACE", Palette.HIGHLIGHT)
			"blocked":
				Sound.play(&"block")
				var blocker := _active_cards[event["side"]]
				HitBurst.spawn(self, blocker.get_global_rect().get_center(), Palette.ACCENT, 80.0 * _card_scale, 6)
				_shake(blocker, 0.6)
				_popup(blocker, "BLOCKED!", Palette.HIGHLIGHT)
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
				var struck := _active_cards[target]
				HitBurst.spawn(self, struck.get_global_rect().get_center(), METEOR_COLOR, 130.0 * _card_scale, 14)
				_flash(struck)
				_screen_shake(14.0)
				_damage_number(struck, event["damage"], "METEOR", METEOR_COLOR, true)
				struck.tween_health(event["health_after"])
				_headline("Meteor shower!", METEOR_COLOR)
				_say("Meteor shower hits %s for %d." % [_name(target), event["damage"]])
				await _pause(0.4)
			"ko":
				Sound.play(&"ko")
				_headline("%s is knocked out!" % _state.side(event["side"]).party[event["index"]].def.display_name, Palette.DAMAGE)
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
	var charge: bool = event["type"] == "charge"
	var knockout: bool = event["health_after"] <= 0
	var big: bool = event["advantage"] or charge or knockout
	# The charge sound builds up during the wind-up; its slam is timed to land with the hit.
	if charge:
		Sound.play(&"charge", 0.88 if event["advantage"] else 1.0)
	# Wind up (lean back, longer for a Charge), then strike toward the other card.
	var toward := -1.0 if side == PLAYER else 1.0
	attacker_card.pivot_offset = attacker_card.size / 2
	var wind_up := 0.16 if charge else 0.07
	var strike := create_tween()
	strike.tween_property(attacker_card, "position:y", -toward * (18.0 if charge else 8.0) * _card_scale,
			wind_up).set_trans(Tween.TRANS_SINE)
	strike.parallel().tween_property(attacker_card, "scale", Vector2(0.96, 0.96), wind_up)
	strike.tween_property(attacker_card, "position:y", toward * (62.0 if charge else 44.0) * _card_scale,
			0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	strike.parallel().tween_property(attacker_card, "scale", Vector2(1.08, 1.08), 0.09)
	await strike.finished

	# Impact.
	_set_shown_health(target, _state.side(target).active, event["health_after"])
	target_card.tween_health(event["health_after"])
	if not charge:
		# Type-edge hits land a little lower and heavier.
		Sound.play(&"bite", 0.88 if event["advantage"] else 1.0)
	var rect := target_card.get_global_rect()
	var contact := rect.get_center() - Vector2(0, toward * rect.size.y * 0.18)
	var color := Palette.HIGHLIGHT if event["advantage"] else HIT_COLOR
	HitBurst.spawn(self, contact, color, (120.0 if big else 85.0) * _card_scale, 14 if big else 9)
	_flash(target_card)
	_shake(target_card, 1.8 if knockout else (1.3 if big else 1.0))
	if big:
		_screen_shake(18.0 if knockout else 9.0)
	var caption: String = {"charge": "CHARGE", "counter": "COUNTER"}.get(event["type"], "")
	if event["advantage"]:
		caption = "TYPE EDGE" if caption == "" else caption + "  TYPE EDGE"
	_damage_number(target_card, event["damage"], caption, color, big)
	if big:
		# A beat of hit-stop so the big ones land.
		await _pause(0.08)

	var back := create_tween()
	back.tween_property(attacker_card, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.parallel().tween_property(attacker_card, "scale", Vector2.ONE, 0.22)
	var verb: String = {"bite": "bites", "counter": "counter-bites", "charge": "charges"}[event["type"]]
	var edge := " [color=#ffd166](type edge!)[/color]" if event["advantage"] else ""
	_say("%s %s for %d.%s" % [_name(side), verb, event["damage"], edge])
	await _pause()


func _pause(seconds := STEP_PAUSE) -> void:
	await get_tree().create_timer(seconds).timeout


func _shake(card: DinoCard, strength := 1.0) -> void:
	var tween := create_tween()
	for offset in [12.0, -10.0, 6.0, -3.0, 0.0]:
		tween.tween_property(card, "position:x", offset * strength, 0.045)


## The whole board jolts (the background stays put, so it reads as an impact).
func _screen_shake(strength: float) -> void:
	var board: Control = $SafeArea
	if _screen_shake_tween:
		_screen_shake_tween.kill()
	_screen_shake_tween = create_tween()
	for i in 6:
		var falloff := 1.0 - i / 6.0
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		_screen_shake_tween.tween_property(board, "position", offset, 0.035)
	_screen_shake_tween.tween_property(board, "position", Vector2.ZERO, 0.05)


## A white flash on a card that's just been hit.
func _flash(card: DinoCard) -> void:
	card.modulate = Color(2.2, 2.2, 2.2)
	card.create_tween().tween_property(card, "modulate", Color.WHITE, 0.18)


## A card arriving after a swap or knockout pops into place.
func _enter(card: DinoCard) -> void:
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.82, 0.82)
	card.modulate.a = 0.0
	var tween := card.create_tween().set_parallel()
	tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.14)


## A big damage number that pops out of the card, then floats up and fades. `caption` (CHARGE,
## TYPE EDGE...) sits small above it.
func _damage_number(card: DinoCard, damage: int, caption: String, color: Color, big: bool) -> void:
	var box := UiKit.vbox(-6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if caption != "":
		box.add_child(_outlined_label(caption, 26, color))
	box.add_child(_outlined_label("-%d" % damage, 84 if big else 64, color))
	add_child(box)
	box.reset_size()
	var center := card.get_global_rect().get_center()
	box.global_position = center - box.size / 2 + Vector2(randf_range(-20.0, 20.0), -card.size.y * 0.12)
	box.pivot_offset = box.size / 2
	box.scale = Vector2(1.9, 1.9)
	var tween := box.create_tween()
	tween.tween_property(box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "position:y", box.position.y - 80, 0.75).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(box, "modulate:a", 0.0, 0.45).set_delay(0.3)
	tween.tween_callback(box.queue_free)


func _outlined_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", Fonts.condensed_bold())
	label.add_theme_color_override("font_color", color.lightened(0.15))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(8, font_size / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


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
	var bench_label := UiKit.label("BENCH", 28, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
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


## The top bar: the rival's round face, their name, and a dot per dino on each side (lit while
## it's standing), so the score shows at a glance.
func _build_top_bar() -> void:
	var bar := _rival_name.get_parent()
	var face := _round_face(RivalArt.face(Session.rival), 60)
	bar.add_child(face)
	bar.move_child(face, 0)
	var name_box := UiKit.vbox(2)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(name_box)
	bar.move_child(name_box, 1)
	_rival_name.reparent(name_box)
	_rival_name.size_flags_horizontal = Control.SIZE_FILL
	name_box.add_child(_dots_row(RIVAL))
	var you := UiKit.vbox(2)
	you.alignment = BoxContainer.ALIGNMENT_CENTER
	var you_label := UiKit.label("YOU", 24, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	you_label.add_theme_font_override("font", Fonts.title())
	you.add_child(you_label)
	you.add_child(_dots_row(PLAYER))
	bar.add_child(you)
	bar.move_child(you, name_box.get_index() + 1)
	bar.add_theme_constant_override("separation", 12)


func _round_face(texture: Texture2D, diameter: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * diameter
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := Panel.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color("1b2a47")
	disc.set_corner_radius_all(int(diameter / 2))
	frame.add_theme_stylebox_override("panel", disc)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.size = holder.custom_minimum_size
	var face := TextureRect.new()
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(face)
	holder.add_child(frame)
	var rim := Panel.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Palette.HIGHLIGHT if Session.rival.is_boss else Palette.ACCENT
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(int(diameter / 2))
	rim.add_theme_stylebox_override("panel", ring)
	rim.size = holder.custom_minimum_size
	holder.add_child(rim)
	for node in [holder, frame, face, rim]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder


func _dots_row(side: int) -> HBoxContainer:
	var row := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER if side == PLAYER else BoxContainer.ALIGNMENT_BEGIN)
	_score_dots[side] = []
	for i in _state.side(side).party.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
		_score_dots[side].append(dot)
	return row


## Lights a dot per dino still standing (as shown on screen), the rest hollow.
func _update_score() -> void:
	for side in 2:
		var standing := 0
		for health in _shown_health[side]:
			standing += 1 if health > 0 else 0
		var color := Palette.HEAL if side == PLAYER else Palette.DAMAGE
		for i in _score_dots[side].size():
			var style := (_score_dots[side][i] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			var lit: bool = i < standing
			style.bg_color = color if lit else Color(0, 0, 0, 0.35)
			style.border_color = color.lightened(0.3) if lit else Color(1, 1, 1, 0.3)


## A small gold tag in the hint line's place, shown while the player has the type edge: the
## damage on the buttons already includes the bonus. Drawn over the line rather than laid out, so
## showing it never moves anything.
func _build_edge_tag() -> void:
	_edge_tag = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.92)
	style.border_color = Palette.HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 3
	style.content_margin_bottom = 5
	_edge_tag.add_theme_stylebox_override("panel", style)
	var text := UiKit.label("Type advantage · bonus included", 23, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	text.add_theme_font_override("font", Fonts.bold())
	_edge_tag.add_child(text)
	_edge_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_tag.set_anchors_preset(Control.PRESET_CENTER)
	_edge_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_edge_tag.grow_vertical = Control.GROW_DIRECTION_BOTH
	_edge_tag.visible = false
	_hint.add_child(_edge_tag)


## Shorter screens are only 1280 units tall: 16:10 tablets like the Galaxy Tab A8 (Jo, 2026-10-26)
## and 16:9 phones. That's less than the layout needs with full-size cards, so the move buttons fell
## off the bottom. Once everything is laid out (a frame later, after the opening headline), this
## measures how far it overflows and shrinks the cards just enough; the two card rows are what
## scales with them. Phones with room to spare are left as they are.
func _fit_to_screen() -> void:
	# The coach's tip box only appears once the battle begins, so it's measured holding its longest
	# tip, shown but invisible, and hidden again afterwards.
	var sizing_coach := _coaching and _coach_panel != null and not _coach_panel.visible
	if sizing_coach:
		_coach_text.text = _longest_coach_tip()
		_coach_panel.modulate.a = 0.0
		_coach_panel.show()
	# Up to three passes: a rebuilt row doesn't shrink quite in proportion (labels stay the same size).
	for attempt in 3:
		# Two frames: the replaced cards are only freed at the end of the first.
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var safe: MarginContainer = $SafeArea
		var room := get_viewport_rect().size.y - safe.get_theme_constant("margin_top") \
				- safe.get_theme_constant("margin_bottom")
		var overflow := ($SafeArea/Column as Control).get_combined_minimum_size().y + FIT_SLACK - room
		if overflow <= 0.0 or _card_scale <= MIN_CARD_SCALE:
			break
		var rows := 0.0
		for row: Control in [$SafeArea/Column/EnemyRow, $SafeArea/Column/PlayerRow]:
			rows += row.get_combined_minimum_size().y
		_card_scale = maxf(MIN_CARD_SCALE, _card_scale * (rows - overflow) / rows)
		for side in 2:
			_rebuild_side(side)
	# Still invisible means the coach hasn't spoken yet (_coach_show makes it visible).
	if sizing_coach and _coach_panel.modulate.a == 0.0:
		_coach_panel.hide()
		_coach_panel.modulate.a = 1.0


func _update_backdrop_focus() -> void:
	if _active_cards[RIVAL] and _active_cards[PLAYER]:
		_backdrop.set_focus(_slots[RIVAL].get_global_rect(), _slots[PLAYER].get_global_rect())


func _is_shiny(side: int, dino: DinoDef) -> bool:
	if side == RIVAL:
		# A friend's Shiny dinos look Shiny in their ghost duel too.
		return dino.id in Session.friend.get("shiny_ids", [])
	return Session.profile.is_shiny(dino.id)


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
	_update_score()


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
	var title_color := Palette.TEXT
	if _state.winner == PLAYER:
		title = "Victory!"
		title_color = Palette.HIGHLIGHT
	elif _state.winner == RIVAL:
		title = "Defeat"
		title_color = Palette.DAMAGE
	Sound.play(&"victory" if _state.winner == PLAYER else &"defeat")
	_stop_coach_highlight()
	if _coach_panel:
		_coach_panel.hide()
	var reward := Session.finish_battle(_state.winner == PLAYER, _state.turn - 1, left)
	var result_title: Label = %ResultTitle
	result_title.text = title.to_upper()
	result_title.add_theme_font_override("font", Fonts.title())
	result_title.add_theme_font_size_override("font_size", 76)
	result_title.add_theme_color_override("font_color", title_color)
	result_title.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	result_title.add_theme_constant_override("outline_size", 12)
	var summary := _result_summary(left, reward)
	result_title.add_sibling(summary)
	%ResultDetail.visible = _coaching
	%ResultDetail.text = "Tutorial done! Tap ? in any battle to see the rules again."
	%HatchButton.visible = reward["clutches"] > 0
	_overlay.show()
	# The title drops in, then the panel.
	result_title.pivot_offset = Vector2(result_title.size.x / 2, result_title.size.y / 2)
	result_title.scale = Vector2(1.6, 1.6)
	result_title.modulate.a = 0.0
	summary.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(result_title, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(result_title, "modulate:a", 1.0, 0.15)
	intro.tween_property(summary, "modulate:a", 1.0, 0.2)
	if _autopilot:
		await get_tree().create_timer(2.5).timeout
		if Session.autoplay_battles_left > 0:
			Session.autoplay_battles_left -= 1
			Session.go_to_main(Session.Tab.EGGS)
		else:
			get_tree().quit()


## The results panel: who it was against, turns and dinos standing as big tiles, and the rewards.
func _result_summary(left: int, reward: Dictionary) -> Control:
	var column := UiKit.vbox(16)
	column.add_child(UiKit.label("against %s" % Session.rival.display_name, 30, Palette.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER, false))
	var tiles := UiKit.hbox(14)
	var party_size := _state.side(PLAYER).party.size()
	tiles.add_child(_result_tile("Turns", str(_state.turn - 1), Palette.TEXT))
	tiles.add_child(_result_tile("Dinos standing", "%d / %d" % [left, party_size],
			Palette.HEAL if left > 0 else Palette.DAMAGE))
	if reward["stars"] > 0:
		# Journey stars: one per dino left standing, filling in one at a time.
		var tile := _result_tile("Stars" if not reward["new_best"] or reward["first_clear"] else "New best!",
				"☆".repeat(Journey.MAX_STARS), Palette.HIGHLIGHT)
		tiles.add_child(tile)
		var value: Label = tile.get_child(0).get_child(0)
		var fill := value.create_tween()
		fill.tween_interval(0.45)
		for i in reward["stars"]:
			fill.tween_callback(func() -> void:
				value.text = "★".repeat(i + 1) + "☆".repeat(Journey.MAX_STARS - i - 1)
				value.pivot_offset = value.size / 2
				value.scale = Vector2(1.35, 1.35)
				value.create_tween().tween_property(value, "scale", Vector2.ONE, 0.18)
				Sound.play(&"card_pick"))
			fill.tween_interval(0.3)
	column.add_child(tiles)

	var rewards := UiKit.vbox(10)
	if reward.get("friendly", false):
		# A friend's party: no rewards, just the record against them.
		rewards.add_child(UiKit.title("Friendly duel", 30, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false))
		var record := Session.profile.friend_record(Session.friend.get("player", ""))
		rewards.add_child(UiKit.label("Your record against %s: %d win%s, %d loss%s" % [Session.rival.display_name,
				record[0], "" if record[0] == 1 else "s", record[1], "" if record[1] == 1 else "es"], 29, Palette.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER))
	else:
		rewards.add_child(UiKit.title("First clear!" if reward["first_clear"] else "Rewards", 30, Palette.HIGHLIGHT,
				HORIZONTAL_ALIGNMENT_CENTER, false))
		var row := UiKit.hbox(28, BoxContainer.ALIGNMENT_CENTER)
		if reward["clutches"] > 0:
			row.add_child(_reward_item(&"egg", "+%d clutch%s" % [reward["clutches"], "" if reward["clutches"] == 1 else "es"]))
		if reward["rare_clutches"] > 0:
			row.add_child(_reward_item(&"egg", "+%d Rare" % reward["rare_clutches"]))
		row.add_child(_reward_item(&"amber", "+%d Amber" % reward["amber"]))
		rewards.add_child(row)
	# Mastery ranks earned in this battle, e.g. "Dilophosaurus is now a Veteran!" (from Fighter up:
	# every dino becomes a Recruit in its first battle).
	for earned in reward.get("mastery", []):
		var dino := Session.catalog.find(earned["id"])
		var rank: int = earned["rank"]
		if rank < 2:
			continue
		rewards.add_child(UiKit.label("★ %s is now %s %s!" % [dino.display_name, "an" if "AEIOU".contains(Mastery.title_of(rank)[0]) else "a",
				Mastery.title_of(rank)], 27, DinoCard.RIBBON_COLORS.get(rank, Palette.TEXT), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_result_well(rewards))
	return UiKit.panel(column, Palette.PANEL, 22)


func _result_tile(caption: String, value: String, color: Color) -> Control:
	var box := UiKit.vbox(0)
	box.add_child(UiKit.title(value, 58, color, HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiKit.label(caption, 28, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false))
	var tile := _result_well(box)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


func _reward_item(icon_name: StringName, text: String) -> Control:
	var item := UiKit.hbox(10)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name, 46)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(icon)
	var label := UiKit.label(text, 34, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.add_theme_font_override("font", Fonts.bold())
	item.add_child(label)
	return item


## A slightly lighter inset box inside the results panel.
func _result_well(content: Control) -> PanelContainer:
	var well := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Color(1, 1, 1, 0.1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	well.add_theme_stylebox_override("panel", style)
	well.add_child(content)
	return well


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
	column.add_child(UiKit.label("It counts as a loss against %s, with no Amber." % Session.rival.display_name, 30,
			Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var stay := UiKit.button("Keep fighting", UiKit.BUTTON_GREEN, 84, 30)
	stay.pressed.connect(func() -> void:
		_leave_dialog.queue_free()
		_leave_dialog = null)
	column.add_child(stay)
	var leave := UiKit.button("Leave battle", UiKit.BUTTON_RED, 76, 28)
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
		if is_instance_valid(_full_log):
			_full_log.queue_free()
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
			else "Swap goes first this turn, and the dino you swap out heals on the bench.", 29, Palette.TEXT,
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
	var skip := UiKit.button("Skip tips", UiKit.BUTTON_GRAY, 56, 27)
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
		_coach_show(COACH_TRIANGLE_TIP % rival_name)
		return
	if BattleEngine.has_advantage(me, them) and _coach_once(&"edge", COACH_EDGE_TIP):
		return
	if can_swap and BattleEngine.has_advantage(them, me) and _coach_once(&"bad_edge", COACH_BAD_EDGE_TIP):
		return
	if can_swap and me.health * 10 <= me.max_health * 4 and _coach_once(&"low", COACH_LOW_TIP):
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
	_coach_panel.modulate.a = 1.0
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


## The coach's longest tip, which the fit measures the tip box with (see _fit_to_screen).
func _longest_coach_tip() -> String:
	var rival_name := Session.rival.display_name
	var tips: Array[String] = [COACH_TRIANGLE_TIP % rival_name, COACH_EDGE_TIP, COACH_BAD_EDGE_TIP, COACH_LOW_TIP]
	for tip in COACH_SCRIPT_TIPS:
		tips.append("Nice! " + tip % rival_name)
	tips.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return tips[0]


func _skip_coach() -> void:
	_coaching = false
	Session.coaching = false
	Session.profile.tutorial_done = true
	Session.save()
	_stop_coach_highlight()
	_coach_panel.hide()


# --- Text helpers ---------------------------------------------------------------------------

## Adds a line to the log; the latest one shows faded under the headline.
func _say(line: String) -> void:
	_log_lines.append(line)
	_log.text = "[color=#%s]%s[/color]" % [Color(Palette.TEXT, 0.75).to_html(), line]


## A centred "Turn 3" heading for the full log, with a little space above it.
static func _log_header(text: String) -> String:
	return "[font_size=10] [/font_size]
[center][b][color=#%s]%s[/color][/b][/center]" % [Palette.HIGHLIGHT.to_html(), text]


## The turn's key moment (who beat what, a knockout, a swap) in the pill under the top row.
func _headline(text: String, color: Color) -> void:
	_log_lines.append("[b][color=#%s]%s[/color][/b]" % [color.to_html(), text])
	_headline_label.text = text
	_headline_label.add_theme_color_override("font_color", color)
	# A long headline wraps instead of stretching the screen wider than the phone.
	var room := (%LogPanel as Control).size.x - 80.0
	if room <= 0.0:
		room = get_viewport_rect().size.x - 120.0
	var width := Fonts.bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADLINE_FONT_SIZE).x
	if width > room:
		_headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_headline_label.custom_minimum_size.x = room
	else:
		_headline_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_headline_label.custom_minimum_size.x = 0
	var style := _headline_pill.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(color, 0.85)
	style.shadow_color = Color(color, 0.3)
	_headline_pill.visible = true
	_headline_pill.pivot_offset = _headline_pill.size / 2
	_headline_pill.scale = Vector2(1.08, 1.08)
	_headline_pill.create_tween().tween_property(_headline_pill, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The text box: a glassy panel. Top row: "Log" (tap the box for the whole log), both moves this
## turn, and the turn number. Under it the key moment in a pill, then the latest line, faded.
func _build_log_box() -> void:
	var panel: PanelContainer = %LogPanel
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.02, 0.04, 0.09, 0.78)
	glass.border_color = Color(Palette.ACCENT, 0.35)
	glass.set_border_width_all(1)
	glass.set_corner_radius_all(16)
	glass.content_margin_left = 12
	glass.content_margin_right = 12
	glass.content_margin_top = 6
	glass.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", glass)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_full_log())
	var column := UiKit.vbox(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := UiKit.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var log_hint := UiKit.label("≡ Log", 21, Color(Palette.TEXT_DIM, 0.8), HORIZONTAL_ALIGNMENT_LEFT, false)
	log_hint.custom_minimum_size.x = 90
	_moves_label = UiKit.label("", 23, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moves_label.clip_text = true
	_moves_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_box_turn_label = UiKit.label("Turn %d" % _state.turn, 23, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_box_turn_label.add_theme_font_override("font", Fonts.condensed_bold())
	_box_turn_label.custom_minimum_size.x = 90
	for label in [log_hint, _moves_label, _box_turn_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(label)
	column.add_child(top)

	_headline_pill = PanelContainer.new()
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.05, 0.08, 0.15, 0.95)
	pill.set_border_width_all(2)
	pill.set_corner_radius_all(24)
	pill.content_margin_left = 18
	pill.content_margin_right = 18
	pill.content_margin_top = 4
	pill.content_margin_bottom = 6
	pill.shadow_size = 10
	_headline_pill.add_theme_stylebox_override("panel", pill)
	_headline_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_headline_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_headline_pill.visible = false
	_headline_label = UiKit.label("", HEADLINE_FONT_SIZE, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_headline_label.add_theme_font_override("font", Fonts.bold())
	_headline_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_headline_pill.add_child(_headline_label)
	column.add_child(_headline_pill)

	_log.reparent(column)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 25)
	_log.add_theme_font_size_override("bold_font_size", 25)
	panel.add_child(column)
	# The turn number lives in the text box now, not next to the ? button.
	_turn_label.visible = false


func _open_full_log() -> void:
	var dialog := UiKit.modal_layer(0.8)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := UiKit.vbox(14)
	column.custom_minimum_size = Vector2(620, 0)
	column.add_child(UiKit.title("Battle log", 36, Palette.HIGHLIGHT))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_size_override("normal_font_size", 25)
	text.add_theme_font_size_override("bold_font_size", 25)
	text.add_theme_font_override("bold_font", Fonts.bold())
	text.text = "\n".join(_log_lines)
	var scroll := UiKit.vscroll(text)
	scroll.custom_minimum_size = Vector2(0, minf(900.0, get_viewport_rect().size.y * 0.6))
	column.add_child(scroll)
	var close := UiKit.button("Close", UiKit.BUTTON_GRAY, 72, 28)
	close.pressed.connect(dialog.queue_free)
	column.add_child(close)
	center.add_child(UiKit.panel(column, Palette.PANEL, 22))
	dialog.add_child(center)
	add_child(dialog)
	_full_log = dialog
	scroll.scroll_vertical = 1 << 20


func _name(side: int) -> String:
	var prefix := "" if side == PLAYER else "Rival "
	return prefix + _state.side(side).active_dino().def.display_name


func _who(side: int) -> String:
	return "You" if side == PLAYER else Session.rival.display_name
