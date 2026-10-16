class_name UpdateCheck
extends Node
## Experiment (Jo, 2026-10-16): Google Play's in-app update prompt, through addons/inapp_update.
## Once per launch, on the main screen, asks Play whether a newer version is out. If so,
## UpdateBanner offers it: Update downloads it in the background (Play's "flexible" update) and
## then offers Restart. If the player has ignored it for IMMEDIATE_AFTER_DAYS, Play's full-screen
## prompt is used instead. Only does anything in builds installed from Google Play; elsewhere the
## plugin is missing and this stays quiet. To remove the experiment, see docs/IN_APP_UPDATES.md.

signal changed

enum State { CHECKING, NONE, AVAILABLE, DOWNLOADING, DOWNLOADED }

const IMMEDIATE_AFTER_DAYS := 7

## Lives on the root, so it keeps listening while the scenes change.
static var instance: UpdateCheck

var state := State.CHECKING
## The player chose Later: the banner stays hidden until the next launch (unless it's downloaded).
var dismissed := false
## Download progress, 0 to 1.
var progress := 0.0
var _play: InappUpdate


## Starts the check (once per launch). Returns null where in-app updates can't work.
static func start(tree: SceneTree) -> UpdateCheck:
	if instance == null and Engine.has_singleton(InappUpdate.PLUGIN_SINGLETON_NAME):
		instance = UpdateCheck.new()
		tree.root.add_child.call_deferred(instance)
	return instance


func _ready() -> void:
	_play = InappUpdate.new()
	_play.immediate_staleness_days = IMMEDIATE_AFTER_DAYS
	add_child(_play)
	_play.update_available.connect(func(_version_code: int, _priority: int) -> void:
		if _play.recommended_update_type() == InappUpdate.UpdateType.IMMEDIATE:
			_play.start_immediate_update()
		_set_state(State.AVAILABLE))
	_play.update_not_available.connect(func() -> void: _set_state(State.NONE))
	_play.update_check_failed.connect(func(_reason: String) -> void: _set_state(State.NONE))
	_play.update_download_progress.connect(func(done: int, total: int) -> void:
		progress = float(done) / total if total > 0 else 0.0
		_set_state(State.DOWNLOADING))
	_play.update_downloaded.connect(func() -> void: _set_state(State.DOWNLOADED))
	_play.update_flow_canceled.connect(func() -> void:
		dismissed = true
		_set_state(State.AVAILABLE))
	_play.update_flow_failed.connect(func(_reason: String) -> void: _set_state(State.AVAILABLE))
	_play.check_for_update()


## Update: Play's small "Update?" sheet, then the download in the background.
func download() -> void:
	progress = 0.0
	_set_state(State.DOWNLOADING)
	_play.start_flexible_update()


## Restart: installs the downloaded update; Play restarts the game.
func restart() -> void:
	_play.complete_flexible_update()


func later() -> void:
	dismissed = true
	changed.emit()


func _set_state(value: State) -> void:
	state = value
	changed.emit()
