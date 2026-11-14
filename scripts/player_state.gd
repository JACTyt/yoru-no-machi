extends RefCounted
## Per-save progress shared by the HUD, map, shops and interactions (static: survives scene reloads
## until the save is loaded again).

const START_MONEY := 3000

static var money := START_MONEY
static var has_waypoint := false
static var waypoint := Vector3.ZERO
## item id → count
static var inventory := {}
## Counters the story reacts to ("thugs_defeated", "cars_stolen", "civilians_hurt").
static var stats := {}
## Phone story progress (see story.gd).
static var story := {}
## Quick-use slots (keys 1-4): item ids, "" when empty.
static var hotbar := ["", "", "", ""]
## Cars bought through the CarGo app: [{"model", "color" (html)}].
static var cars := []
## Outfit sets bought at the boutique.
static var styles := []


static func reset() -> void:
	money = START_MONEY
	has_waypoint = false
	inventory = {"onigiri": 2}
	stats = {}
	story = {}
	hotbar = ["onigiri", "", "", ""]
	cars = []
	styles = []


static func to_dict() -> Dictionary:
	var d := {"money": money, "inventory": inventory, "stats": stats, "story": story, "hotbar": hotbar, "cars": cars, "styles": styles}
	if has_waypoint:
		d["waypoint"] = [waypoint.x, waypoint.z]
	return d


static func from_dict(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	inventory = d.get("inventory", {}) if d.get("inventory") is Dictionary else {}
	for k in inventory:
		inventory[k] = int(inventory[k])
	stats = d.get("stats", {}) if d.get("stats") is Dictionary else {}
	story = d.get("story", {}) if d.get("story") is Dictionary else {}
	hotbar = d.get("hotbar", ["", "", "", ""]) if d.get("hotbar") is Array and d["hotbar"].size() == 4 else ["", "", "", ""]
	cars = d.get("cars", []) if d.get("cars") is Array else []
	styles = d.get("styles", []) if d.get("styles") is Array else []
	var w = d.get("waypoint")
	has_waypoint = w is Array and w.size() == 2
	if has_waypoint:
		waypoint = Vector3(w[0], 0, w[1])


static func add_item(id: String, count := 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	if inventory[id] <= 0:
		inventory.erase(id)
	elif not hotbar.has(id) and hotbar.has(""):
		# New items fill the first free quick slot.
		hotbar[hotbar.find("")] = id


static func bump(stat: String, by := 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + by


static func set_waypoint(pos: Vector3) -> void:
	has_waypoint = true
	waypoint = Vector3(pos.x, 0, pos.z)


static func clear_waypoint() -> void:
	has_waypoint = false


static func format_money(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + "¥" + s + out
