extends Node3D
## Keeps a crowd of civilians strolling the sidewalks around the player: spawns them on blocks a
## little out of view and recycles ones that drift far away. Some carry requests.

const Civilian := preload("res://scripts/npc/civilian.gd")
const City := preload("res://scripts/city/city_builder.gd")
const GameSettings := preload("res://scripts/game_settings.gd")

const COUNT := 16
## Fewer, heavier pedestrians when they use full VRoid models.
const COUNT_VRM := 12
const NPC_DIR := "res://characters/npc/"
const TINT_CHANCE := 0.6
const SPAWN_MIN := 22.0
const SPAWN_MAX := 85.0
const DESPAWN := 120.0
const REQUEST_CHANCE := 0.3
const CHECK_INTERVAL := 1.0

var player
var city
var enabled := true

var _check_t := 0.0
var _models := []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_models = models()


## Exported pedestrian models: every .vrm in characters/npc/ (file names containing "male" /
## "female" set the gender for names).
static func models() -> Array:
	var out := []
	var dir := DirAccess.open(NPC_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		var file: String = f.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension().to_lower() == "vrm" and not out.has(NPC_DIR + file) and ResourceLoader.exists(NPC_DIR + file):
			out.append(NPC_DIR + file)
	return out


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0 or player == null:
		return
	_check_t = CHECK_INTERVAL
	var alive := 0
	for npc in get_children():
		if not npc.keep and npc.global_position.distance_to(player.global_position) > DESPAWN:
			npc.queue_free()
		else:
			alive += 1
	if not enabled:
		return
	for i in mini((COUNT_VRM if not _models.is_empty() else COUNT) - alive, 3):
		_spawn()


func _spawn() -> void:
	var origin: Vector3 = player.global_position
	for attempt in 12:
		var ix := _rng.randi_range(0, City.BLOCKS - 1)
		var iz := _rng.randi_range(0, City.BLOCKS - 1)
		var center := Vector3((ix - (City.BLOCKS - 1) / 2.0) * City.CELL, 0, (iz - (City.BLOCKS - 1) / 2.0) * City.CELL)
		# A random point on the block's sidewalk loop.
		var t := _rng.randf_range(-1.0, 1.0) * Civilian.RING
		var side := _rng.randi() % 4
		var offset: Vector3 = [Vector3(t, 0, -Civilian.RING), Vector3(Civilian.RING, 0, t), Vector3(t, 0, Civilian.RING), Vector3(-Civilian.RING, 0, t)][side]
		var pos: Vector3 = center + offset + Vector3.UP * (City.CURB_H + 0.05)
		var d := pos.distance_to(origin)
		if d < SPAWN_MIN or d > SPAWN_MAX:
			continue
		var npc := Civilian.new()
		npc.block_center = center
		if not _models.is_empty():
			var path: String = _models[_rng.randi() % _models.size()]
			npc.body_path = path
			npc.gender = "female" if path.get_file().contains("female") else "male"
			if _rng.randf() < TINT_CHANCE:
				# Same model, different clothes colours: a cheap way to multiply variety.
				var presets := GameSettings.PRESETS
				npc.body_tints = {"tops": Color(presets[_rng.randi_range(1, presets.size() - 1)][1]),
					"bottoms": Color(presets[_rng.randi_range(1, presets.size() - 1)][1])}
		npc.position = pos
		if _rng.randf() < REQUEST_CHANCE:
			npc.request = _make_request()
		add_child(npc)
		return


func _make_request() -> Dictionary:
	if city != null and not city.places.is_empty() and _rng.randf() < 0.45:
		var ids: Array = city.places.keys()
		var id: String = ids[_rng.randi() % ids.size()]
		return {"type": "directions", "place": id}
	var items := [["house keys", "keys"], ["phone", "phone"], ["wallet", "wallet"], ["lucky charm", "charm"], ["earbuds case", "earbuds"]]
	var item: Array = items[_rng.randi() % items.size()]
	return {"type": "lost_item", "item": item[0], "reward": _rng.randi_range(5, 15) * 100}
