class_name PartnerPick
extends Control
## First launch: choose a partner dino (Economy.STARTER_PARTNERS) to join the 5 starter dinos.
## Tap a card to see what it's like, hold it to zoom, then confirm. Covers the tabs until done.

const CARD_WIDTH := 212.0

var _choice: DinoDef
var _cards: Array[DinoCard] = []
var _info: Label
var _confirm: Button


static func open() -> PartnerPick:
	var view := PartnerPick.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := UiKit.modal_layer(0.96)
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var column := UiKit.vbox(22)
	column.custom_minimum_size.x = 680
	column.add_child(UiKit.title("Choose your partner", 48, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("Your first dino. You also get %d more to start your party, plus %d egg clutch%s to hatch." \
			% [Economy.STARTER_BASICS.size(), Economy.STARTER_CLUTCHES, "" if Economy.STARTER_CLUTCHES == 1 else "es"],
			29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var row := UiKit.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	for id in Economy.STARTER_PARTNERS:
		var dino := Session.catalog.find(id)
		var card := DinoCard.create(dino, DinoCard.Mode.FULL, null, false, CARD_WIDTH)
		card.pressed.connect(_select.bind(dino))
		row.add_child(card)
		_cards.append(card)
	column.add_child(row)

	_info = UiKit.label("Tap a dino to meet it. Hold a card to see it up close.", 30, Palette.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
	_info.custom_minimum_size.y = 120
	column.add_child(_info)

	_confirm = UiKit.button("Choose a partner", UiKit.BUTTON_GREEN, 92, 32)
	_confirm.disabled = true
	_confirm.pressed.connect(_confirm_choice)
	column.add_child(_confirm)
	center.add_child(column)

	if Session.autoplay:
		await get_tree().create_timer(0.8).timeout
		_select(Session.catalog.find(Economy.STARTER_PARTNERS[0]))
		await get_tree().create_timer(0.8).timeout
		_confirm_choice()


func _select(dino: DinoDef) -> void:
	Sound.play(&"card_pick")
	_choice = dino
	for card in _cards:
		card.selected = card.def == dino
		card.dimmed = card.def != dino
	_info.text = "%s  ·  %s %s  ·  %s %s\n%s" % [dino.display_name.to_upper(), dino.rarity_code(),
			dino.rarity_name(), Palette.TYPE_LABELS[dino.dino_type].capitalize(), DinoDef.ERA_NAMES[dino.era],
			dino.flavor_text]
	_confirm.text = "Choose %s" % dino.display_name
	_confirm.disabled = false


func _confirm_choice() -> void:
	if _choice == null or not Session.profile.choose_partner(_choice.id):
		return
	Sound.play(&"new_dino")
	Session.save()
	# Reload the tabs so they show the full party of 6, starting where the first step is: hatching.
	Session.go_to_main(Session.Tab.EGGS)
