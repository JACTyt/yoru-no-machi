extends CharacterBody3D
## On-foot protagonist: camera-relative movement, sprint, jump.

const Toon := preload("res://scripts/toon.gd")

const WALK_SPEED := 5.0
const RUN_SPEED := 10.0
const JUMP_VELOCITY := 7.0
const ACCEL := 12.0

var rig
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model: Node3D
var spawn_point := Vector3(0, 1, 0)
var _bob := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	model = Node3D.new()
	add_child(model)
	_build_model()


func _build_model() -> void:
	var skin := Color(1.0, 0.87, 0.8)
	var hair := Color(0.95, 0.38, 0.6)
	var jacket := Color(0.16, 0.17, 0.3)
	# Legs and body
	Toon.add_mesh(model, Toon.capsule(0.1, 0.65), Color(0.1, 0.1, 0.14), Vector3(-0.12, 0.33, 0))
	Toon.add_mesh(model, Toon.capsule(0.1, 0.65), Color(0.1, 0.1, 0.14), Vector3(0.12, 0.33, 0))
	Toon.add_mesh(model, Toon.capsule(0.27, 0.8), jacket, Vector3(0, 0.88, 0))
	# Scarf
	Toon.add_mesh(model, Toon.cylinder(0.2, 0.1), Color(0.9, 0.15, 0.2), Vector3(0, 1.22, 0))
	var tail := Toon.add_mesh(model, Toon.box(Vector3(0.1, 0.4, 0.04)), Color(0.9, 0.15, 0.2), Vector3(0.1, 1.05, 0.22))
	tail.rotation.x = -0.4
	# Head, hair, eyes (face looks along -Z)
	Toon.add_mesh(model, Toon.sphere(0.26), skin, Vector3(0, 1.48, 0))
	Toon.add_mesh(model, Toon.sphere(0.28), hair, Vector3(0, 1.56, 0.06))
	for x in [-0.14, 0.0, 0.14]:
		var bang := Toon.add_mesh(model, _prism(Vector3(0.14, 0.2, 0.08)), hair, Vector3(x, 1.6, -0.18))
		bang.rotation.z = PI
	for i in 3:
		var spike := Toon.add_mesh(model, _prism(Vector3(0.18, 0.35, 0.1)), hair, Vector3((i - 1) * 0.13, 1.55, 0.28))
		spike.rotation.x = 1.9
	for x in [-0.09, 0.09]:
		Toon.add_mesh(model, Toon.box(Vector3(0.07, 0.11, 0.02)), Color(0.12, 0.18, 0.4), Vector3(x, 1.46, -0.245), false)
		Toon.add_mesh(model, Toon.box(Vector3(0.025, 0.035, 0.01)), Color.WHITE, Vector3(x + 0.015, 1.48, -0.258), false)


func _prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


func set_driving(on: bool) -> void:
	visible = not on
	set_physics_process(not on)
	collision_layer = 0 if on else 1
	collision_mask = 0 if on else 1
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_yaw: float = rig.yaw
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0.0, input.y)
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * speed, 1.0 - exp(-ACCEL * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-12.0 * delta))
		_bob += delta * speed * 2.2
		model.position.y = absf(sin(_bob)) * 0.06
	else:
		model.position.y = lerpf(model.position.y, 0.0, 1.0 - exp(-10.0 * delta))

	if global_position.y < -30.0:
		global_position = spawn_point
		velocity = Vector3.ZERO
