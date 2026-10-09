class_name CheckInView
extends Control
## Daily check-in popup: a week of tiles (Economy.CHECKIN_BONUSES), today's one lit up, and a
## Claim button for the free clutch plus today's bonus. Opens by itself on the first visit of a
## new day (see Session.take_checkin_prompt), and from the Eggs and Goals tabs.

signal closed

const TILE_HEIGHT := 150.0
## Rare clutches wear Super Rare purple.
const RARE_TINT := Color("b05cff")

var _tiles: Array[PanelContainer] = []
var _claim: Button
var _note: Label
var _pulse: Tween


static func open() -> CheckInView:
	var view := CheckInView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func close() -> void:
	closed.emit()
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := UiKit.modal_layer(0.85)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := UiKit.vbox(16)
	column.custom_minimum_size.x = 600
	column.add_child(UiKit.title("Daily check-in", 40, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.label("Every day: a free egg clutch. Keep checking in for a bonus that grows all week.",
			29, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var rows := UiKit.vbox(10)
	var first := UiKit.hbox(10)
	var second := UiKit.hbox(10)
	for day in Economy.CHECKIN_BONUSES.size():
		var tile := _tile(day)
		(first if day < 4 else second).add_child(tile)
		_tiles.append(tile)
	# Day 7 is the big one: it takes the room of two tiles.
	_tiles[-1].size_flags_stretch_ratio = 2.0
	rows.add_child(first)
	rows.add_child(second)
	column.add_child(rows)
	_note = UiKit.label("", 29, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_note)
	_claim = UiKit.button("", UiKit.BUTTON_GREEN, 84, 30)
	_claim.pressed.connect(_on_claim)
	column.add_child(_claim)
	center.add_child(UiKit.panel(column, Palette.PANEL, 28))
	_refresh()


func _refresh() -> void:
	var profile := Session.profile
	var can_claim := profile.can_claim_daily(SaveStore.today())
	if _pulse:
		_pulse.kill()
		_pulse = null
	for day in _tiles.size():
		_tiles[day].self_modulate = Color.WHITE
		_style_tile(day, day_state(day))
	if can_claim:
		_note.text = "Today: 1 egg clutch + %s" % bonus_text(profile.checkin_day)
		_claim.text = "Claim day %d" % (profile.checkin_day + 1)
	else:
		_note.text = "Checked in for today. Missing a day won't reset your streak."
		_claim.text = "See you tomorrow!"
		UiKit.style_button(_claim, UiKit.BUTTON_GRAY)


## 0 = claimed this week, 1 = today's (not claimed yet), 2 = still to come.
static func day_state(day: int) -> int:
	var profile := Session.profile
	var next := profile.checkin_day
	if not profile.can_claim_daily(SaveStore.today()) and next == 0:
		# Day 7 was claimed today: show the finished week until tomorrow.
		return 0
	if day < next:
		return 0
	if day == next and profile.can_claim_daily(SaveStore.today()):
		return 1
	return 2


func _on_claim() -> void:
	var profile := Session.profile
	if not profile.can_claim_daily(SaveStore.today()):
		close()
		return
	var day := profile.checkin_day
	profile.claim_daily(SaveStore.today())
	Session.save()
	Sound.play(&"clutch_open")
	Sound.play(&"amber")
	_refresh()
	var tile := _tiles[day]
	tile.pivot_offset = tile.size / 2
	var pop := tile.create_tween()
	pop.tween_property(tile, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	pop.tween_property(tile, "scale", Vector2.ONE, 0.2)


static func bonus_text(day: int) -> String:
	var bonus: Dictionary = Economy.CHECKIN_BONUSES[day]
	if bonus.has("rare_clutches"):
		return "a Rare clutch!"
	if bonus.has("clutches"):
		return "%d extra clutch" % bonus["clutches"]
	return "%d Amber" % bonus["amber"]


func _tile(day: int) -> PanelContainer:
	var bonus: Dictionary = Economy.CHECKIN_BONUSES[day]
	var box := UiKit.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(UiKit.title("Day %d" % (day + 1), 28, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	var icon := TextureRect.new()
	icon.texture = Icons.texture(&"amber" if bonus.has("amber") else &"egg", 44)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(0, 46)
	if bonus.has("rare_clutches"):
		icon.modulate = RARE_TINT.lightened(0.3)
	box.add_child(icon)
	var amount := "+%d" % bonus["amber"] if bonus.has("amber") else ("Rare clutch" if bonus.has("rare_clutches") else "+1 clutch")
	box.add_child(UiKit.label(amount, 28, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER, false))
	var mark := UiKit.label("", 28, Palette.HEAL, HORIZONTAL_ALIGNMENT_CENTER, false)
	mark.name = "Mark"
	box.add_child(mark)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(0, TILE_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	return tile


func _style_tile(day: int, state: int) -> void:
	var tile := _tiles[day]
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Palette.PANEL_BORDER
	style.set_border_width_all(2)
	if Economy.CHECKIN_BONUSES[day].has("rare_clutches"):
		style.bg_color = Color(RARE_TINT, 0.16)
	if state == 1:
		style.border_color = Palette.HIGHLIGHT
		style.set_border_width_all(4)
		style.shadow_color = Color(Palette.HIGHLIGHT, 0.4)
		style.shadow_size = 12
	tile.add_theme_stylebox_override("panel", style)
	tile.modulate = Color(1, 1, 1, 0.55) if state == 0 else Color.WHITE
	(tile.find_child("Mark", true, false) as Label).text = "✔ Claimed" if state == 0 \
			else ("Today" if state == 1 else "")
	if state == 1:
		_pulse = tile.create_tween().set_loops()
		_pulse.tween_property(tile, "self_modulate", Color(1.25, 1.2, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(tile, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
