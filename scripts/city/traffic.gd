extends Node3D
## Ambient traffic: keeps `count` autopilot cars circulating on the road grid, topping up when
## the player takes one and respawning wrecks away from the player.

const CarScript := preload("res://scripts/car.gd")
const City := preload("res://scripts/city/city_builder.gd")

const MODELS := ["sedan", "sedan", "sedan", "compact", "compact", "coupe", "van", "taxi"]
const COLORS := [
	Color(0.95, 0.95, 0.97), Color(0.12, 0.12, 0.15), Color(0.7, 0.72, 0.78), Color(0.85, 0.2, 0.25),
	Color(0.2, 0.4, 0.85), Color(0.98, 0.85, 0.35), Color(0.55, 0.85, 0.75), Color(0.95, 0.6, 0.7),
]
const TAXI_COLOR := Color(1.0, 0.72, 0.18)
const MIN_PLAYER_DISTANCE := 45.0
const TOP_UP_INTERVAL := 2.0

var count := 16
var city
var player

var _cars := []
var _top_up_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in count:
		_spawn()


func _process(delta: float) -> void:
	_top_up_t -= delta
	if _top_up_t > 0.0:
		return
	_top_up_t = TOP_UP_INTERVAL
	_cars = _cars.filter(func(c): return is_instance_valid(c) and c.autopilot)
	if _cars.size() < count:
		_spawn()


func _spawn() -> void:
	var car = CarScript.new()
	car.model = MODELS[_rng.randi() % MODELS.size()]
	car.color = TAXI_COLOR if car.model == "taxi" else COLORS[_rng.randi() % COLORS.size()]
	car.autopilot = true
	car.has_driver = true
	car.traffic = self
	_place(car)
	add_child(car)
	_cars.append(car)


func respawn(car) -> void:
	_place(car)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


## Puts the car mid-block on a random lane, clear of the player and other cars.
func _place(car) -> void:
	var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	var pos := Vector3.ZERO
	var dir := Vector3.BACK
	var to := Vector3.ZERO
	for attempt in 30:
		var from := Vector3(_rng.randi_range(-City.GRID, City.GRID), 0, _rng.randi_range(-City.GRID, City.GRID)) * City.CELL
		dir = dirs[_rng.randi() % 4]
		to = from + dir * City.CELL
		if not City.in_grid(to):
			continue
		pos = from + dir * _rng.randf_range(14.0, City.CELL - 14.0) + City.lane_left(dir) * City.LANE_OFFSET
		if _clear(pos, car):
			break
	car.ai_dir = dir
	car.ai_node = to
	car.ai_next_dir = choose_next(to, dir)
	var xform := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), pos + Vector3.UP * 0.3)
	if car.is_inside_tree():
		car.global_transform = xform
	else:
		car.transform = xform


func _clear(pos: Vector3, self_car) -> bool:
	if player != null and is_instance_valid(player) and player.global_position.distance_to(pos) < MIN_PLAYER_DISTANCE:
		return false
	for c in _cars:
		if c != self_car and is_instance_valid(c) and c.is_inside_tree() and c.global_position.distance_to(pos) < 12.0:
			return false
	return true


## Puts an autopilot car at `pos` driving along `dir` (cardinal), aimed at the next junction.
func place_on_road(car, pos: Vector3, dir: Vector3) -> void:
	var node := Vector3(roundf(pos.x / City.CELL), 0, roundf(pos.z / City.CELL)) * City.CELL
	if absf(dir.x) > 0.5:
		node.x = (ceilf(pos.x / City.CELL) if dir.x > 0.0 else floorf(pos.x / City.CELL)) * City.CELL
	else:
		node.z = (ceilf(pos.z / City.CELL) if dir.z > 0.0 else floorf(pos.z / City.CELL)) * City.CELL
	if not City.in_grid(node):
		dir = -dir
		node -= dir * City.CELL * -1.0
	car.ai_dir = dir
	car.ai_node = node
	car.ai_next_dir = choose_next(node, dir)
	car.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), pos + Vector3.UP * 0.3)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


## A taxi with a driver, waiting (`hold`) at `pos` until someone takes it.
func spawn_taxi(pos: Vector3, dir: Vector3):
	var car = CarScript.new()
	car.model = "taxi"
	car.color = TAXI_COLOR
	car.autopilot = true
	car.has_driver = true
	car.hold = true
	car.traffic = self
	car.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), pos + Vector3.UP * 0.3)
	add_child(car)
	place_on_road(car, pos, dir)
	return car


## Picks straight/left/right at `node`, never leaving the grid and never U-turning.
func choose_next(node: Vector3, dir: Vector3) -> Vector3:
	var left := City.lane_left(dir)
	var options := []
	for d in [dir, dir, left, -left]:
		if City.in_grid(node + d * City.CELL):
			options.append(d)
	return options[_rng.randi() % options.size()] if not options.is_empty() else -dir
