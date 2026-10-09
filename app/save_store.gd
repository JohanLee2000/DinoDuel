class_name SaveStore
extends RefCounted
## Reads and writes the player's save as JSON in `user://`, the app's private storage (on Android
## that's internal storage only this app can read; on Windows it's under %APPDATA%\Godot).
##
## Writes go to a temp file first and the previous save is kept as a backup, so a crash or a
## dead battery mid-write can't destroy progress.
##
## Moving to a new phone (Jo, 2026-10-09): Android Auto Backup is on in the export presets, so
## Android keeps a copy in the player's own Google account. Settings also has Export save (a file
## sent through the share sheet) and Import save (read back from the phone's file picker).

const FILE := "save.json"
const BACKUP_FILE := "save.backup.json"
const TEMP_FILE := "save.tmp.json"

## Tests point this at a scratch folder so they never touch real progress.
static var folder := "user://"

## Exported saves: the save as text plus a check value, so a damaged or hand-edited file is
## refused instead of loaded. (It isn't encryption; it catches broken files and casual edits.)
const EXPORT_KIND := "dino_duel_save"
const EXPORT_FORMAT := 1
const EXPORT_FOLDER := "user://share/save"
const EXPORT_CHECK_SALT := "dino-duel-fossil-amber-1"
## Anything bigger than this can't be a save.
const IMPORT_MAX_BYTES := 1024 * 1024


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


## The text of an exported save file.
static func export_text(profile: PlayerProfile) -> String:
	var save_text := JSON.stringify(profile.to_dict())
	return JSON.stringify({
		"kind": EXPORT_KIND,
		"format": EXPORT_FORMAT,
		"exported": Time.get_datetime_string_from_system(false, true),
		"check": _check(save_text),
		"save": save_text,
	}, "\t")


## Writes an export file for sharing and returns its user:// path (or "" if it couldn't).
## Earlier exports are deleted first, so they don't pile up.
static func write_export(profile: PlayerProfile) -> String:
	DirAccess.make_dir_recursive_absolute(EXPORT_FOLDER)
	var dir := DirAccess.open(EXPORT_FOLDER)
	if dir == null:
		return ""
	for old in dir.get_files():
		dir.remove(old)
	var who := profile.player_name.validate_filename().replace(" ", "_")
	var name := "DinoDuel_%s%s.json" % [who + "_" if who != "" else "", Time.get_date_string_from_system()]
	var path := EXPORT_FOLDER.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(export_text(profile))
	file.close()
	return path


## The profile in an exported save's text, or null if it isn't a valid Dino Duel save.
static func parse_export(text: String, catalog: DinoCatalog) -> PlayerProfile:
	var wrapper: Variant = JSON.parse_string(text)
	if not wrapper is Dictionary or wrapper.get("kind", "") != EXPORT_KIND:
		return null
	if int(wrapper.get("format", 0)) > EXPORT_FORMAT:
		return null
	var save_text := String(wrapper.get("save", ""))
	if save_text == "" or _check(save_text) != String(wrapper.get("check", "")):
		return null
	var data: Variant = JSON.parse_string(save_text)
	if not data is Dictionary:
		return null
	return PlayerProfile.from_dict(data, catalog)


## Reads an exported save from a path (on Android, the content:// link the file picker returns).
static func read_export(path: String, catalog: DinoCatalog) -> PlayerProfile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > IMPORT_MAX_BYTES:
		return null
	return parse_export(file.get_as_text(), catalog)


## When an exported file was made, for the import confirmation ("" if unknown).
static func export_date(text: String) -> String:
	var wrapper: Variant = JSON.parse_string(text)
	return String(wrapper.get("exported", "")) if wrapper is Dictionary else ""


static func _check(save_text: String) -> String:
	return (EXPORT_CHECK_SALT + save_text).sha256_text()


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
