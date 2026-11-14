extends VehicleBody3D
## Drivable car with a procedural anime body. Player-driven while `active`; with `autopilot` it
## follows city traffic: keeps its lane, turns at intersections, stops for signals and obstacles.

const CarModels := preload("res://scripts/city/car_models.gd")
const City := preload("res://scripts/city/city_builder.gd")
const Toon := preload("res://scripts/toon.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const REVERSE_POWER := 1600.0
const BRAKE_POWER := 40.0
const MAX_STEER := 0.55
const TOP_REVERSE_SPEED := 12.0
const CRUISE_SPEED := 12.0
const TURN_SPEED := 6.0
const LOOKAHEAD := 7.0
const SENSOR_RANGE := 16.0
## Physics layer shared by vehicles and characters; city geometry stays on layer 1 only.
const SENSOR_MASK := 2
const RUN_OVER_SPEED := 6.0
const PEDESTRIAN_HIT_COOLDOWN := 0.8
## Seconds of full throttle a full tank / battery lasts; idling and cruising use much less.
const TANK_SECONDS := 240.0
const IDLE_USE := 0.15

var model := "sedan"
var color := Color(0.95, 0.3, 0.45)
var active := false
var autopilot := false
var traffic ## traffic.gd node; required while `autopilot` is on.
## Someone is at the wheel: the heroine has to pull them out first (taxis offer a ride instead).
var has_driver := false
## Autopilot waits in place (taxi taking an order).
var hold := false
## 0..1 tank (or battery charge, see `electric`). Only the player's driving uses it.
var fuel := 1.0
var electric := false
var ai_dir := Vector3.BACK ## Travel direction (cardinal).
var ai_node := Vector3.ZERO ## Center of the next intersection.
var ai_next_dir := Vector3.BACK ## Direction to take at `ai_node`.

var _spec: Dictionary
var _brake_mat: ShaderMaterial
var _half_length := 2.3
var _stuck_t := 0.0
var _flip_t := 0.0
var _recent_hits := {}
var _engine: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("cars")
	_spec = CarModels.spec(model)
	mass = _spec["mass"]
	electric = _spec.get("electric", false)
	collision_layer = 3
	collision_mask = 3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.4, 0)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	var built := CarModels.build(self, _spec, color)
	_brake_mat = built["brake"]
	var size: Vector3 = built["size"]
	_half_length = size.z * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y - 0.3, size.z)
	shape.shape = box
	shape.position.y = 0.3 + box.size.y * 0.5
	add_child(shape)

	Sfx.ensure_buses()
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = Sfx.stream("engine_ev" if electric else "engine")
	_engine.bus = "SFX"
	_engine.unit_size = 5.0
	_engine.max_distance = 60.0
	_engine.position.y = 0.6
	add_child(_engine)

	var r: float = _spec["wheel_radius"]
	var half_base: float = _spec["wheelbase"] * 0.5
	for x in [-_spec["track"], _spec["track"]]:
		_add_wheel(Vector3(x, r + 0.12, half_base), true)
		_add_wheel(Vector3(x, r + 0.12, -half_base), false)


func _add_wheel(pos: Vector3, front: bool) -> void:
	var r: float = _spec["wheel_radius"]
	var wheel := VehicleWheel3D.new()
	wheel.position = pos
	wheel.use_as_steering = front
	wheel.use_as_traction = not front
	wheel.wheel_radius = r
	wheel.wheel_rest_length = 0.12
	wheel.suspension_travel = 0.15
	wheel.suspension_stiffness = 40.0
	wheel.wheel_friction_slip = 2.8
	wheel.wheel_roll_influence = 0.15
	add_child(wheel)
	var tire := Toon.add_mesh(wheel, Toon.cylinder(r, 0.22), Color(0.07, 0.07, 0.09), Vector3.ZERO, true, 0.02)
	tire.rotation.z = PI / 2.0
	var rim := Toon.add_mesh(wheel, Toon.cylinder(r * 0.62, 0.23), Color(0.72, 0.74, 0.8), Vector3.ZERO, false)
	rim.rotation.z = PI / 2.0
	var hub := Toon.add_mesh(wheel, Toon.cylinder(r * 0.2, 0.24), Color(0.3, 0.31, 0.35), Vector3.ZERO, false)
	hub.rotation.z = PI / 2.0


func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func _physics_process(delta: float) -> void:
	if active:
		_player_drive(delta)
		_auto_right(delta)
	elif autopilot and traffic != null and not hold:
		_autopilot(delta)
	elif hold:
		engine_force = 0.0
		brake = 10.0
	else:
		engine_force = 0.0
		brake = 2.0
		steering = move_toward(steering, 0.0, delta)
	_brake_mat.set_shader_parameter("emission", Color(1.0, 0.08, 0.12) * (2.2 if brake > 3.0 else 0.25))
	_update_engine_sound()
	for body in _recent_hits.keys():
		_recent_hits[body] -= delta
		if _recent_hits[body] <= 0.0:
			_recent_hits.erase(body)


## Engine runs while someone drives; pitch follows speed and throttle. Parked cars are silent.
func _update_engine_sound() -> void:
	var running := (active and fuel > 0.0) or (autopilot and has_driver)
	if running != _engine.playing:
		if running:
			_engine.play()
		else:
			_engine.stop()
	if running:
		var rpm := clampf(absf(forward_speed()) / float(_spec["top_speed"]), 0.0, 1.0)
		_engine.pitch_scale = 0.7 + rpm * 1.6 + (0.15 if engine_force > 0.0 else 0.0)
		_engine.volume_db = -4.0 if active else -14.0


func _player_drive(delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer_in := Input.get_axis("move_right", "move_left")
	var speed := forward_speed()
	var top_speed: float = _spec["top_speed"]

	brake = 0.0
	engine_force = 0.0
	fuel = maxf(fuel - (absf(throttle) + IDLE_USE) / TANK_SECONDS * delta, 0.0)
	if fuel <= 0.0:
		throttle = minf(throttle, 0.0) if speed > 1.0 else 0.0
	if throttle < 0.0 and speed > 1.0:
		brake = BRAKE_POWER
	elif throttle > 0.0 and speed < top_speed:
		engine_force = throttle * _spec["power"]
	elif throttle < 0.0 and speed > -TOP_REVERSE_SPEED:
		engine_force = throttle * REVERSE_POWER
	if Input.is_action_pressed("jump"):
		brake = BRAKE_POWER * 0.6

	var steer_limit := lerpf(MAX_STEER, 0.15, clampf(absf(speed) / top_speed, 0.0, 1.0))
	steering = move_toward(steering, steer_in * steer_limit, delta * 2.5)


## Puts a player car that has rolled over back on its wheels after a moment.
func _auto_right(delta: float) -> void:
	if global_basis.y.y < 0.4 and linear_velocity.length() < 2.0:
		_flip_t += delta
		if _flip_t > 2.0:
			_flip_t = 0.0
			var yaw := atan2(global_basis.z.x, global_basis.z.z)
			global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.0)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		_flip_t = 0.0


func _autopilot(delta: float) -> void:
	var pos := global_position
	pos.y = 0.0
	var turning := not ai_next_dir.is_equal_approx(ai_dir)
	var corner := _corner()
	# Hand over to the next road once the turn point (or the junction center) is reached.
	if (corner - pos).dot(ai_dir) < (3.0 if turning else 0.0):
		ai_dir = ai_next_dir
		ai_node += ai_dir * City.CELL
		ai_next_dir = traffic.choose_next(ai_node, ai_dir)
		turning = not ai_next_dir.is_equal_approx(ai_dir)
		corner = _corner()

	# Pure pursuit on the lane line, wrapping onto the next lane near a turn.
	var lane_origin := ai_node + City.lane_left(ai_dir) * City.LANE_OFFSET
	var along := (pos - lane_origin).dot(ai_dir)
	var target := lane_origin + ai_dir * (along + LOOKAHEAD)
	var to_corner := (corner - pos).dot(ai_dir)
	if turning and to_corner < LOOKAHEAD:
		target = corner + ai_next_dir * (LOOKAHEAD - maxf(to_corner, 0.0))
	var local := global_basis.inverse() * (target - global_position)
	steering = move_toward(steering, clampf(atan2(local.x, local.z) * 1.4, -MAX_STEER, MAX_STEER), delta * 3.0)

	var target_speed := CRUISE_SPEED
	if turning:
		target_speed = lerpf(TURN_SPEED, CRUISE_SPEED, clampf((to_corner - 6.0) / 16.0, 0.0, 1.0))
	var to_stop := (ai_node - pos).dot(ai_dir) - City.STOP_LINE
	var light: int = traffic.city.signal_state(ai_dir)
	if to_stop > -0.5 and to_stop < 30.0 and (light == 2 or (light == 1 and to_stop > 6.0)):
		target_speed = minf(target_speed, maxf(0.0, (to_stop - 0.5) * 0.7))
	var free := minf(_sensor(global_basis.z.rotated(Vector3.UP, steering)), _sensor((target - global_position).normalized()))
	target_speed = minf(target_speed, maxf(0.0, (free - 4.0) * 0.9))

	var speed := forward_speed()
	if speed < target_speed - 0.3:
		engine_force = _spec["power"] * clampf((target_speed - speed) * 0.4, 0.2, 1.0)
		brake = 0.0
	elif speed > target_speed + 0.8:
		engine_force = 0.0
		brake = BRAKE_POWER * clampf((speed - target_speed) / 6.0, 0.15, 1.0)
	else:
		engine_force = 0.0
		brake = 0.3
	if target_speed < 0.3 and speed < 1.0:
		brake = 8.0

	# Recover from wrecks: respawn elsewhere if flipped or wedged for too long.
	if global_basis.y.y < 0.4:
		_flip_t += delta
	else:
		_flip_t = 0.0
	if speed < 0.4 and target_speed > 2.0:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if _flip_t > 3.0 or _stuck_t > 6.0:
		_flip_t = 0.0
		_stuck_t = 0.0
		traffic.respawn(self)


## Where the lane meets the next one: the corner point for turns, the junction center otherwise.
func _corner() -> Vector3:
	var left := City.lane_left(ai_dir)
	if ai_next_dir.is_equal_approx(ai_dir):
		return ai_node + left * City.LANE_OFFSET
	return ai_node + (left + City.lane_left(ai_next_dir)) * City.LANE_OFFSET


## Free distance ahead of the front bumper toward `dir` (other cars and characters only).
func _sensor(dir: Vector3) -> float:
	dir.y = 0.0
	dir = dir.normalized()
	var from := global_position + global_basis.z * (_half_length + 0.2) + Vector3.UP * 0.7
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * SENSOR_RANGE, SENSOR_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return SENSOR_RANGE if hit.is_empty() else from.distance_to(hit["position"])


func _on_body_entered(body: Node) -> void:
	if not body.has_method("take_hit") or _recent_hits.has(body):
		return
	var v := linear_velocity
	if v.length() < RUN_OVER_SPEED:
		return
	_recent_hits[body] = PEDESTRIAN_HIT_COOLDOWN
	Sfx.play(self, "hit_heavy", global_position)
	if autopilot:
		Sfx.play(self, "horn", global_position)
	var impulse := v.normalized() * minf(v.length(), 14.0) + Vector3.UP * 4.0
	if body.is_in_group("player"):
		body.take_hit(clampf(v.length() * 2.2, 8.0, 60.0), impulse, true, self)
	else:
		body.take_hit(clampf(v.length() * 2.2, 8.0, 60.0), impulse, true)
