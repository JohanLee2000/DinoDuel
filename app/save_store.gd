class_name SaveStore
extends RefCounted
## Reads and writes the player's save as JSON in `user://`, the app's private storage (on Android
## that's internal storage only this app can read; on Windows it's under %APPDATA%\Godot).
##
## Writes go to a temp file first and the previous save is kept as a backup, so a crash or a
## dead battery mid-write can't destroy progress.

const FILE := "save.json"
const BACKUP_FILE := "save.backup.json"
const TEMP_FILE := "save.tmp.json"

## Tests point this at a scratch folder so they never touch real progress.
static var folder := "user://"


static func load_profile(catalog: DinoCatalog) -> PlayerProfile:
	for file_name in [FILE, BACKUP_FILE]:
		var data := _read(folder.path_join(file_name))
		if not data.is_empty():
			return PlayerProfile.from_dict(data, catalog)
	return null


static func save_profile(profile: PlayerProfile) -> bool:
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join(TEMP_FILE), FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()
	var dir := DirAccess.open(folder)
	if dir.file_exists(FILE):
		if dir.file_exists(BACKUP_FILE):
			dir.remove(BACKUP_FILE)
		dir.rename(FILE, BACKUP_FILE)
	var err := dir.rename(TEMP_FILE, FILE)
	if err != OK:
		push_error("Save failed: %s" % error_string(err))
		return false
	return true


static func delete_all() -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file_name in [FILE, BACKUP_FILE, TEMP_FILE]:
		if dir.file_exists(file_name):
			dir.remove(file_name)


## Today's local calendar date as a day number, for the daily clutch.
static func today() -> int:
	var date := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict(date) / 86400)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("Ignoring unreadable save at %s" % path)
	return {}
