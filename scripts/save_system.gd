extends RefCounted
## Save slots on disk (user://save_N.json) and the slot chosen for this session.
## Writes go to a temp file first and are renamed over the old save, so a crash mid-write
## never corrupts an existing slot.

const GameSettings := preload("res://scripts/game_settings.gd")

const SLOTS := 3
const VERSION := 1

## Active slot; -1 when nothing should be saved (combat arena, character studio).
static var slot := -1
static var play_time := 0.0


static func path(i: int) -> String:
	return "user://save_%d.json" % (i + 1)


static func read(i: int) -> Dictionary:
	if not FileAccess.file_exists(path(i)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path(i)))
	return data if data is Dictionary and data.has("version") else {}


static func write(i: int, data: Dictionary) -> bool:
	var tmp := path(i) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path(i))
	if err != OK:
		push_warning("Save failed: cannot replace %s (%s)" % [path(i), error_string(err)])
	return err == OK


static func erase(i: int) -> void:
	if FileAccess.file_exists(path(i)):
		DirAccess.remove_absolute(path(i))


## Makes slot `i` current; an existing save also restores its heroine.
static func begin(i: int) -> void:
	slot = i
	var data := read(i)
	play_time = float(data.get("play_time", 0.0))
	if GameSettings.HEROINES.has(data.get("heroine", "")):
		GameSettings.heroine = data["heroine"]


static func load_current() -> Dictionary:
	return {} if slot < 0 else read(slot)


## Saves `data` plus bookkeeping into the current slot.
static func save(data: Dictionary) -> bool:
	if slot < 0:
		return false
	data["version"] = VERSION
	data["heroine"] = GameSettings.heroine
	data["play_time"] = play_time
	data["saved_at"] = int(Time.get_unix_time_from_system())
	return write(slot, data)


static func format_play_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	return "%dh %02dm" % [minutes / 60, minutes % 60]


static func format_date(unix: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d.%02d.%d  %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]
