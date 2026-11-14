extends Node3D
## Third-person orbit camera: follows a target, auto-aligns behind vehicles, frames lock-on targets, shakes.

const AnimePost := preload("res://scripts/anime_post.gd")
const Settings := preload("res://scripts/settings.gd")

const MOUSE_SENSITIVITY := 0.003
## Mouse-wheel zoom range as a multiple of the target's base distance.
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.0

var target: Node3D
var lock_target: Node3D
var yaw := 0.0
var pitch := -0.25
var height := 1.5
var spring: SpringArm3D
var camera: Camera3D
var _mouse_idle := 0.0
var _trauma := 0.0
var _base_distance := 4.0
var _zoom := 1.0


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.margin = 0.2
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	spring.add_child(camera)
	camera.make_current()
	AnimePost.attach(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_target(t: Node3D, distance: float, h: float) -> void:
	if target == null:
		global_position = t.global_position + Vector3.UP * h
	target = t
	height = h
	_base_distance = distance
	spring.spring_length = distance * _zoom
	spring.clear_excluded_objects()
	if t is CollisionObject3D:
		spring.add_excluded_object((t as CollisionObject3D).get_rid())


## Adds screen shake; strength ~0.2 (light hit) to ~0.6 (heavy).
func shake(strength: float) -> void:
	if not Settings.get_value("camera_shake"):
		return
	_trauma = minf(_trauma + strength, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens: float = MOUSE_SENSITIVITY * Settings.get_value("mouse_sensitivity")
		var invert := -1.0 if Settings.get_value("invert_y") else 1.0
		yaw -= motion.relative.x * sens
		pitch = clampf(pitch - motion.relative.y * sens * invert, -1.2, 0.4)
		_mouse_idle = 0.0
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.is_pressed():
		# Recapture after alt-tab; Esc / the pause menu own freeing the mouse.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_mouse_idle += delta
	if lock_target != null and is_instance_valid(lock_target):
		# Look past the player toward the locked enemy.
		var d := lock_target.global_position - target.global_position
		if Vector2(d.x, d.z).length() > 0.5:
			yaw = lerp_angle(yaw, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * delta))
			pitch = lerpf(pitch, -0.3, 1.0 - exp(-3.0 * delta))
	elif target is VehicleBody3D:
		var car := target as VehicleBody3D
		if car.linear_velocity.length() > 3.0 and _mouse_idle > 0.8:
			# Vehicles drive along +Z, the rig looks along -Z.
			yaw = lerp_angle(yaw, car.global_rotation.y + PI, 1.0 - exp(-3.0 * delta))
	spring.spring_length = lerpf(spring.spring_length, _base_distance * _zoom, 1.0 - exp(-10.0 * delta))
	var goal := target.global_position + Vector3.UP * height
	global_position = global_position.lerp(goal, 1.0 - exp(-12.0 * delta))
	rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	# Shake uses real time so it still reads during hit-stop.
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	camera.fov = Settings.get_value("fov")
	_trauma = maxf(_trauma - real_delta * 2.5, 0.0)
	var s := _trauma * _trauma
	camera.h_offset = randf_range(-1.0, 1.0) * s * 0.25
	camera.v_offset = randf_range(-1.0, 1.0) * s * 0.25
