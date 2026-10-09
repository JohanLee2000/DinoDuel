class_name Power
extends Node
## Keeps the game light on battery and heat (2026-10-09):
## - Frames are capped at 60 per second (phones with 120 Hz screens would otherwise draw twice as
##   many for a card game that doesn't need them).
## - After IDLE_SECONDS without a touch, it drops to IDLE_FPS; the next touch brings 60 back.
##   Slow animations (card glows, drifting backgrounds) still look fine at 30.
## - The screen only stays awake during battles and hatching; elsewhere the phone's own sleep
##   timer applies, so a game left open on a menu lets the screen turn off.
## - When the game goes to the background, music pauses.
## Dev: `--uncapped` turns all of this off, for measuring the difference.

const ACTIVE_FPS := 60
const IDLE_FPS := 30
const IDLE_SECONDS := 8.0

static var _node: Power

var _idle_time := 0.0
var _idle := false
var _enabled := true
var _keep_awake := false


static func setup(tree: SceneTree, enabled := true) -> void:
	if _node:
		return
	_node = Power.new()
	_node.name = "Power"
	_node._enabled = enabled
	tree.root.add_child.call_deferred(_node)


## Battles and hatching keep the screen on; everything else follows the phone's sleep setting.
static func keep_screen_awake(awake: bool) -> void:
	if _node:
		_node._keep_awake = awake
		_node._apply_screen()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _enabled:
		Engine.max_fps = 0
		DisplayServer.screen_set_keep_on(true)
		set_process(false)
		return
	Engine.max_fps = ACTIVE_FPS
	_apply_screen()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton \
			or event is InputEventKey:
		_idle_time = 0.0
		if _idle:
			_idle = false
			Engine.max_fps = ACTIVE_FPS


func _process(delta: float) -> void:
	if _idle:
		return
	_idle_time += delta
	if _idle_time >= IDLE_SECONDS:
		_idle = true
		Engine.max_fps = IDLE_FPS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			Sound.pause_all(true)
		NOTIFICATION_APPLICATION_RESUMED:
			Sound.pause_all(false)
			_idle_time = 0.0
			_idle = false
			if _enabled:
				Engine.max_fps = ACTIVE_FPS


func _apply_screen() -> void:
	if _enabled:
		DisplayServer.screen_set_keep_on(_keep_awake)
