extends Control
## Pick 3 dinos for the next battle. In M1 the player can use the whole roster; from M2 on this
## becomes "pick 3 of the 6 you brought" from your own collection.

var _cards: Array[DinoCard] = []
var _picked: Array[DinoDef] = []

@onready var _rival_panel: PanelContainer = %RivalPanel
@onready var _rival_label: Label = %RivalLabel
@onready var _rival_brings: HBoxContainer = %RivalBrings
@onready var _hint: Label = %Hint
@onready var _grid: GridContainer = %Grid
@onready var _summary: Label = %Summary
@onready var _battle_button: Button = %BattleButton


func _ready() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.PANEL
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(10)
	_rival_panel.add_theme_stylebox_override("panel", panel_style)

	var rival := Session.rival
	_rival_label.text = "%s brings these 6 and will pick 3:" % rival.display_name
	for dino in rival.brings:
		_rival_brings.add_child(DinoCard.create(dino, DinoCard.Mode.MINI))

	for dino in Session.catalog.dinos:
		var card := DinoCard.create(dino, DinoCard.Mode.FULL)
		card.pressed.connect(_toggle.bind(dino))
		_grid.add_child(card)
		_cards.append(card)
	_picked.assign(Session.player_herd)
	_battle_button.pressed.connect(func() -> void: Session.start_battle(_picked))
	_refresh()

	if Session.autoplay:
		_picked = BattleAI.new(randi()).choose_herd(Session.catalog.dinos)
		_refresh()
		await get_tree().create_timer(1.0).timeout
		Session.start_battle(_picked)


func _toggle(dino: DinoDef) -> void:
	if dino in _picked:
		_picked.erase(dino)
	elif _picked.size() >= HerdRules.HERD_SIZE:
		_flash_hint("Your herd is full. Tap a picked dino to remove it.")
		return
	elif HerdRules.points(_picked) + HerdRules.points_of(dino) > HerdRules.POINT_CAP:
		_flash_hint("%s would go over the %d-point cap." % [dino.display_name, HerdRules.POINT_CAP])
		return
	else:
		_picked.append(dino)
	_refresh()


func _refresh() -> void:
	var points := HerdRules.points(_picked)
	for card in _cards:
		var is_picked := card.def in _picked
		card.selected = is_picked
		card.set_badge("IN HERD" if is_picked else "")
		var fits := _picked.size() < HerdRules.HERD_SIZE \
				and points + HerdRules.points_of(card.def) <= HerdRules.POINT_CAP
		card.dimmed = not is_picked and not fits

	var parts: Array[String] = ["Herd Points %d/%d" % [points, HerdRules.POINT_CAP]]
	if _picked.size() == HerdRules.HERD_SIZE:
		parts.append("Era bond: +1 ATK +1 SPD" if HerdRules.has_era_bond(_picked) else "No era bond")
		parts.append("Balanced: +2 HP" if HerdRules.is_balanced(_picked) else "Not balanced")
	_summary.text = "  ·  ".join(parts)
	_battle_button.disabled = HerdRules.validate(_picked) != ""
	_hint.text = "Pick 3 dinos within %d Herd Points. Same era = Era bond. Land + Sky + Sea = Balanced." \
			% HerdRules.POINT_CAP


func _flash_hint(text: String) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		_hint.remove_theme_color_override("font_color")
		_refresh()
