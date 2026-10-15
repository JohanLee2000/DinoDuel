class_name RivalView
extends Control
## A Journey stage up close (tap a map marker): the rival's sprite, name and habit hint (a boss's
## names its Alpha), their 6 (tap a card to see it), your best stars and record, what a win pays, and
## Challenge. Locked stages say who to beat first.

const CARD_WIDTH := 100.0

var _stage: RivalDef
var _can_battle := true


static func open(stage: RivalDef, can_battle: bool) -> RivalView:
	var view := RivalView.new()
	view._stage = stage
	view._can_battle = can_battle
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := UiKit.modal_layer(0.8)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var profile := Session.profile
	var unlocked := Journey.is_unlocked(profile, _stage)
	var column := UiKit.vbox(14)
	column.custom_minimum_size.x = 640

	# Sprite beside name, stage, stars and record.
	var top := UiKit.hbox(18)
	var sprite := TextureRect.new()
	sprite.texture = RivalArt.sprite(_stage.character)
	sprite.custom_minimum_size = Vector2(200, 200)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not unlocked:
		sprite.modulate = Color(0.45, 0.45, 0.5)
	top.add_child(sprite)
	var info := UiKit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UiKit.title(_stage.display_name, 38, Palette.HIGHLIGHT if _stage.is_boss else Palette.TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, false))
	info.add_child(UiKit.label(_where(), 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
	var stars := UiKit.hbox(4)
	var best := Journey.best_stars(profile, _stage)
	for i in Journey.MAX_STARS:
		var star := TextureRect.new()
		star.texture = Icons.texture(&"star" if i < best else &"star_empty", 34)
		star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		stars.add_child(star)
	info.add_child(stars)
	var record := profile.record_against(_stage.id)
	if record[0] + record[1] > 0:
		info.add_child(UiKit.label("Won %d · Lost %d" % [record[0], record[1]], 26, Palette.TEXT_DIM,
				HORIZONTAL_ALIGNMENT_LEFT, false))
	top.add_child(info)
	column.add_child(top)

	column.add_child(UiKit.label(_stage.intro, 28, Palette.TEXT))

	column.add_child(UiKit.label("Their team", 24, Palette.TEXT_DIM))
	var team := UiKit.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	for dino in _stage.brings:
		var card := DinoCard.create(dino, DinoCard.Mode.MINI, null, false, CARD_WIDTH)
		card.pressed.connect(CardViewer.open.bind(dino))
		team.add_child(card)
	column.add_child(team)

	column.add_child(UiKit.label(_reward_text(best > 0), 26, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	if _stage.meteor_turn > 0:
		column.add_child(UiKit.label("The meteor shower starts on turn %d here, not turn %d." \
				% [_stage.meteor_turn, BattleEngine.METEOR_START_TURN], 25, Palette.DAMAGE.lightened(0.2),
				HORIZONTAL_ALIGNMENT_CENTER))
	if unlocked and _stage == Session.rivals[0] and Session.wants_coach():
		column.add_child(UiKit.label("Start here! A coach shows you the moves.", 26, Palette.HEAL,
				HORIZONTAL_ALIGNMENT_CENTER))

	var buttons := UiKit.hbox(12)
	var back := UiKit.button("Back", UiKit.BUTTON_GRAY, 80, 28)
	back.custom_minimum_size.x = 180
	back.pressed.connect(close)
	buttons.add_child(back)
	if unlocked:
		var challenge := UiKit.button("Challenge", UiKit.BUTTON_GREEN, 80, 30)
		challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		challenge.disabled = not _can_battle
		challenge.pressed.connect(func() -> void: Session.go_to_pre_battle(_stage))
		buttons.add_child(challenge)
	else:
		var index := Journey.stages().find(_stage)
		var locked := UiKit.label("Beat %s to unlock" % Journey.stages()[index - 1].display_name, 27,
				Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
		locked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		locked.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		buttons.add_child(locked)
	column.add_child(buttons)

	var panel := UiKit.panel(column, Palette.PANEL, 24)
	center.add_child(panel)
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tween := panel.create_tween().set_parallel()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2)


## "Triassic · Stage 3", "Triassic · Boss", "Extinction Day".
func _where() -> String:
	if _stage.chapter == Journey.FINALE:
		return Journey.CHAPTER_NAMES[Journey.FINALE]
	var number := Journey.chapter_stages(_stage.chapter).find(_stage) + 1
	return "%s · %s" % [Journey.CHAPTER_NAMES[_stage.chapter], "Boss" if _stage.is_boss else "Stage %d" % number]


func _reward_text(cleared: bool) -> String:
	if cleared:
		return "Win again: an egg clutch + %d Amber" % Economy.REPLAY_AMBER
	var amber := Economy.JOURNEY_WIN_AMBER[_stage.chapter]
	if _stage.chapter == Journey.FINALE:
		return "First win: an egg clutch, %d Amber and %d Rare clutches" % [amber, Economy.FINALE_FIRST_CLEAR_RARE_CLUTCHES]
	if _stage.is_boss:
		return "First win: an egg clutch, %d Amber and a Rare clutch" % amber
	return "First win: an egg clutch and %d Amber" % (amber + Economy.JOURNEY_FIRST_CLEAR_AMBER[_stage.chapter])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
