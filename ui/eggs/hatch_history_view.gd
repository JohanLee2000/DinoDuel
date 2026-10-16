class_name HatchHistoryView
extends ColorRect
## Hatch history (Jo, 2026-10-16): a popup listing the last clutches hatched, newest first
## (PlayerProfile.hatch_history). Each clutch shows its kind and when, then its three dinos with
## what each one did: New!, Shiny!, Now Shiny! or the Amber a duplicate melted into. Tap a dino
## for its Dex entry.

const CARD_WIDTH := 132.0
## Clutches added per frame, so the popup opens at once even with a long history.
const BATCH := 6
const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func open() -> HatchHistoryView:
	var view := HatchHistoryView.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(view)
	return view


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UiKit.vbox(12)
	column.custom_minimum_size.x = 640
	column.add_child(UiKit.title("Hatch history", 38, Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	var profile := Session.profile
	var history := profile.hatch_history
	column.add_child(UiKit.label(_summary(profile), 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var list := UiKit.vbox(10)
	var scroll := UiKit.vscroll(list)
	scroll.custom_minimum_size.y = get_viewport_rect().size.y * 0.62
	if history.is_empty():
		list.add_child(UiKit.label("Nothing here yet. Hatch a clutch and it shows up here.", 28, Palette.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER))
		scroll.custom_minimum_size.y = 0
	column.add_child(scroll)
	var close := UiKit.button("Close", UiKit.BUTTON_GRAY, 68, 26)
	close.pressed.connect(queue_free)
	column.add_child(close)
	var panel := UiKit.panel(column, Palette.PANEL, 22)
	# Taps on the panel stay here; only taps outside it close the popup.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	add_child(center)

	for i in history.size():
		list.add_child(_clutch_row(history[i]))
		if i % BATCH == BATCH - 1:
			await get_tree().process_frame
			if not is_inside_tree():
				return


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		queue_free()


## "142 eggs hatched · 3 Shiny and 5 UR in your last 50 clutches"
func _summary(profile: PlayerProfile) -> String:
	var shiny := 0
	var legendary := 0
	for entry in profile.hatch_history:
		for egg in entry["eggs"]:
			shiny += 1 if egg["shiny"] else 0
			var dino := Session.catalog.find(StringName(egg["id"]))
			legendary += 1 if dino.rarity == DinoDef.Rarity.LEGENDARY else 0
	var text := "%d egg%s hatched in all" % [profile.eggs_hatched, "" if profile.eggs_hatched == 1 else "s"]
	if not profile.hatch_history.is_empty():
		var count := profile.hatch_history.size()
		text += "  ·  %d Shiny and %d UR in your last %d clutch%s" % [shiny, legendary, count, "" if count == 1 else "es"]
	return text


func _clutch_row(entry: Dictionary) -> Control:
	var box := UiKit.vbox(8)
	var header := UiKit.hbox(10)
	var rare: bool = entry["rare"]
	var kind := UiKit.title("Rare clutch" if rare else "Clutch", 28,
			CheckInView.RARE_TINT.lightened(0.35) if rare else Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_LEFT, false)
	kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(kind)
	header.add_child(UiKit.label(_when(entry["time"]), 25, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false))
	box.add_child(header)
	var eggs := UiKit.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	for egg in entry["eggs"]:
		eggs.add_child(_egg(egg))
	box.add_child(eggs)
	return UiKit.panel(box, Palette.BACKGROUND, 12)


## One egg: its dino's card and what it did.
func _egg(egg: Dictionary) -> Control:
	var dino := Session.catalog.find(StringName(egg["id"]))
	var cell := UiKit.vbox(4)
	cell.custom_minimum_size.x = CARD_WIDTH + 30
	var card := DinoCard.create(dino, DinoCard.Mode.MINI, null, egg["shiny"], CARD_WIDTH)
	card.inspect_on_hold = false
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pressed.connect(func() -> void: DexEntry.open(dino))
	cell.add_child(card)
	var text := "+%d Amber" % egg["amber"] if egg["amber"] > 0 else "Duplicate"
	var color := Palette.TEXT_DIM
	if egg["new"]:
		text = "New!"
		color = Palette.HEAL
	elif egg["upgraded"]:
		text = "Now Shiny!"
		color = Palette.HIGHLIGHT
	if egg["shiny"] and egg["new"]:
		text = "New Shiny!"
		color = Palette.HIGHLIGHT
	cell.add_child(UiKit.label(text, 24, color, HORIZONTAL_ALIGNMENT_CENTER, false))
	return cell


## "Oct 16, 11:42" in the phone's time zone, or "" if the time wasn't recorded.
func _when(time: int) -> String:
	if time <= 0:
		return ""
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var date := Time.get_datetime_dict_from_unix_time(time + bias_minutes * 60)
	return "%s %d, %d:%02d" % [MONTHS[int(date["month"]) - 1], date["day"], date["hour"], date["minute"]]
