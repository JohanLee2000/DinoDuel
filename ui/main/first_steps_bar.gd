class_name FirstStepsBar
extends PanelContainer
## New-player checklist under the top bar: "FIRST STEPS 2/5" and the next thing to do. Tap it to
## see the whole list. When everything's done it turns into a button to claim the bonus clutch.
## The steps themselves live in PlayerProfile (FIRST_STEPS / first_step_done).

## Fired when the player taps the next step, with the tab it belongs to.
signal go_to_tab(tab: int)

## Step -> [title, what to do, tab index (Session.Tab: 0 Battle, 1 Party, 2 Eggs, 3 Dex)].
const STEPS := {
	&"partner": ["Choose a partner", "Pick your first dino.", 0],
	&"hatch": ["Hatch your eggs", "Open the Eggs tab and tap Hatch a clutch.", 2],
	&"dex": ["Meet your dinos", "Open the Dex tab and tap any dino you own.", 3],
	&"party": ["Build your party", "In the Party tab, swap a starter for a dino you hatched.", 1],
	&"battle": ["Win your first battle", "Challenge Rookie Rae on the Battle tab.", 0],
}

var _expanded := false
var _body: VBoxContainer


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PANEL, 0.96)
	style.border_color = Palette.HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	_body = UiKit.vbox(8)
	add_child(_body)
	gui_input.connect(_on_input)
	refresh()


func refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	var profile := Session.profile
	visible = profile.first_steps_active
	if not visible:
		return
	var steps := PlayerProfile.FIRST_STEPS
	var done := steps.filter(func(step: StringName) -> bool: return profile.first_step_done(step)).size()
	var next := profile.next_first_step()

	var header := UiKit.hbox(10)
	var title := UiKit.title("First steps  %d/%d" % [done, steps.size()], 28, Palette.HIGHLIGHT,
			HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.label("▲" if _expanded else "▼", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false))
	_body.add_child(header)

	if next == &"":
		var claim := UiKit.button("All done! Claim your bonus egg clutch", UiKit.BUTTON_GREEN, 76, 26)
		claim.pressed.connect(_claim)
		_body.add_child(claim)
		return
	if _expanded:
		for step in steps:
			var is_done := profile.first_step_done(step)
			var line := UiKit.label("%s  %s" % ["✔" if is_done else "○", STEPS[step][0]], 25,
					Palette.TEXT_DIM if is_done else (Palette.HIGHLIGHT if step == next else Palette.TEXT),
					HORIZONTAL_ALIGNMENT_LEFT, false)
			_body.add_child(line)
		_body.add_child(UiKit.label("Finish them all for a bonus egg clutch.", 23, Palette.TEXT_DIM))
	else:
		_body.add_child(UiKit.label("%s: %s" % [STEPS[next][0], STEPS[next][1]], 25, Palette.TEXT))


## The tab with the next step, so the nav bar can make it glow; -1 when there's nothing to do.
func next_tab() -> int:
	var next := Session.profile.next_first_step()
	if not Session.profile.first_steps_active or next == &"":
		return -1
	return STEPS[next][2]


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sound.play(&"tap")
		_expanded = not _expanded
		refresh()
		var tab := next_tab()
		if tab >= 0 and tab != Session.current_tab:
			go_to_tab.emit(tab)


func _claim() -> void:
	if Session.profile.claim_first_steps_reward():
		Sound.play(&"clutch_open")
		Session.save()
		go_to_tab.emit(Session.Tab.EGGS)
