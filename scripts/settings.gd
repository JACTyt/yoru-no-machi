extends RefCounted
## Player options (user://settings.cfg): audio volumes, controls, camera, display. `apply()` pushes
## audio and display options to the engine; the camera reads its values directly.

const Sfx := preload("res://scripts/audio/sfx.gd")
const PATH := "user://settings.cfg"
const DEFAULTS := {
	"master_volume": 0.8, "music_volume": 0.55, "sfx_volume": 0.85,
	"mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": true, "fov": 70.0,
	"fullscreen": false, "vsync": true, "shadows": "High", "show_hints": true,
}
const SHADOW_SIZES := {"Low": 2048, "High": 4096}

static var values := {}
static var _loaded := false


static func get_value(key: String):
	ensure_loaded()
	return values.get(key, DEFAULTS[key])


static func set_value(key: String, value) -> void:
	ensure_loaded()
	values[key] = value
	apply()


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in DEFAULTS:
			values[key] = cfg.get_value("options", key, DEFAULTS[key])
	apply()


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("options", key, values[key])
	cfg.save(PATH)


static func apply() -> void:
	Sfx.ensure_buses()
	_volume("Master", values["master_volume"])
	_volume("Music", values["music_volume"])
	_volume("SFX", values["sfx_volume"])
	if DisplayServer.get_name() != "headless":
		var full: bool = values["fullscreen"]
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and not (not full and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES.get(values["shadows"], 4096), true)


static func _volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)
