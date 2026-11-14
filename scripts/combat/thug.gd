extends CharacterBody3D
## Street thug: chases the player, telegraphs a punch (glows red), staggers and gets launched when hit.

const Toon := preload("res://scripts/toon.gd")
const VrmCharacter := preload("res://scripts/vrm_character.gd")

signal died(thug: Node3D)

const SPEED := 3.4
const ATTACK_RANGE := 1.7
const AGGRO_RANGE := 18.0
const WINDUP := 0.65
const STRIKE := 0.15
const RECOVER := 0.7
const DAMAGE := 10.0
const WANDER_SPEED := 1.3
const GANG_RADIUS := 12.0
const CALM_DISTANCE := 25.0
const LINES := ["Got a problem?", "Nice night, huh.", "Keep walking.", "You lost or something?", "Don't start nothing.", "...", "Heh. Cute jacket."]

var target ## Heroine node (duck-typed: is_alive / take_hit).
## Conversation interface shared with civilians (see interactions.gd).
var npc_name := "Street punk"
var personality := "thug"
var mood := 25
var request := {}
## Hostile thugs chase and attack; neutral ones wander near home until provoked.
var hostile := true
## When true (city streets), a hostile thug gives up once the player has been far away for a while.
var calm_down := false
var max_hp := 60.0
var hp := 60.0
var color := Color(0.24, 0.26, 0.36)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var state := "chase"
var _t := 0.0
var _stagger_time := 0.3
var _cooldown := 0.0
var _flash := 0.0
var _glow := 0.0
var _struck := false
var model: Node3D
var arm: Node3D
var body_mat: ShaderMaterial
var bar: Node3D
var bar_fill: MeshInstance3D
var _home := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _wander_wait := 0.0
var _far_time := 0.0
var _speech: Label3D
## Optional VRoid body (story bosses) and a floating name tag.
var vrm_path := ""
var display_name := ""
var damage := DAMAGE
var _vrm
var _last_state := ""


func _ready() -> void:
	add_to_group("enemies")
	_cooldown = randf_range(0.5, 1.5)
	_home = global_position
	_wander_to = _home
	_wander_wait = randf_range(0.5, 3.0)
	if not hostile:
		state = "wander"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	# Layer 2 lets traffic sensors see pedestrians.
	collision_layer = 3
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	_build_model()
	_build_bar()
	_build_vrm()


func is_alive() -> bool:
	return state != "dead"


## Model faces -Z.
## Swaps the capsule figure for a VRoid model; the hidden capsule rig still drives facing.
func _build_vrm() -> void:
	if not display_name.is_empty():
		var tag := Label3D.new()
		tag.text = display_name
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 40
		tag.pixel_size = 0.005
		tag.outline_size = 10
		tag.modulate = Color(1.0, 0.45, 0.45)
		tag.outline_modulate = Color(0.1, 0.02, 0.04)
		tag.position.y = 2.45
		add_child(tag)
	if vrm_path.is_empty() or not ResourceLoader.exists(vrm_path):
		return
	for c in model.get_children():
		c.visible = false
	_vrm = VrmCharacter.new()
	_vrm.model_scene = load(vrm_path)
	model.add_child(_vrm)
	var f: Vector3 = _vrm.forward_local()
	# The capsule rig faces -Z.
	_vrm.rotation.y = PI - atan2(f.x, f.z)


func _animate_vrm() -> void:
	if _vrm == null:
		return
	_vrm.move_speed = Vector2(velocity.x, velocity.z).length() if state in ["wander", "chase"] else 0.0
	if state == _last_state:
		return
	_last_state = state
	match state:
		"windup":
			# Land the punch's impact (about 40% into the clip) as the windup ends.
			var length: float = _vrm.clip_length("ual1/Punch_Cross")
			_vrm.play_action_clip("ual1/Punch_Cross", maxf(length * 0.4 / WINDUP, 0.3), 0.1)
			_vrm.set_expression("angry", 1.0)
		"stagger":
			_vrm.play_action_clip("ual1/Hit_Chest", 1.0, 0.05)
		"dead":
			_vrm.play_action_clip("ual1/Death01", 1.0, 0.1, "", true)


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var pants := Color(0.12, 0.12, 0.16)
	Toon.add_mesh(model, Toon.capsule(0.12, 0.8), pants, Vector3(-0.14, 0.4, 0))
	Toon.add_mesh(model, Toon.capsule(0.12, 0.8), pants, Vector3(0.14, 0.4, 0))
	var torso := Toon.add_mesh(model, Toon.capsule(0.32, 0.9), color, Vector3(0, 1.1, 0), true, 0.03)
	body_mat = torso.material_override as ShaderMaterial
	Toon.add_mesh(model, Toon.sphere(0.24), Color(0.95, 0.82, 0.74), Vector3(0, 1.68, 0))
	Toon.add_mesh(model, Toon.sphere(0.29), color.darkened(0.2), Vector3(0, 1.72, 0.07))
	# Face mask with a painted grin; reads clearly at range.
	Toon.add_mesh(model, Toon.box(Vector3(0.3, 0.16, 0.04)), Color(0.92, 0.92, 0.95), Vector3(0, 1.62, -0.22), true, 0.01)
	Toon.add_mesh(model, Toon.box(Vector3(0.18, 0.02, 0.01)), Color(0.8, 0.1, 0.2), Vector3(0, 1.6, -0.245), false)
	var left := Node3D.new()
	left.position = Vector3(-0.42, 1.42, 0)
	model.add_child(left)
	Toon.add_mesh(left, Toon.capsule(0.1, 0.75), color, Vector3(0, -0.32, 0))
	arm = Node3D.new()
	arm.position = Vector3(0.42, 1.42, 0)
	model.add_child(arm)
	Toon.add_mesh(arm, Toon.capsule(0.1, 0.75), color, Vector3(0, -0.32, 0))
	Toon.add_mesh(arm, Toon.sphere(0.11), Color(0.95, 0.82, 0.74), Vector3(0, -0.72, 0))


func _build_bar() -> void:
	bar = Node3D.new()
	bar.position.y = 2.2
	bar.visible = false
	add_child(bar)
	_bar_quad(Vector2(0.84, 0.1), Color(0.05, 0.03, 0.08), 0)
	bar_fill = _bar_quad(Vector2(0.8, 0.06), Color(1.0, 0.25, 0.35), 1)


func _bar_quad(size: Vector2, c: Color, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = c
	mat.render_priority = 10 + priority
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.add_child(mi)
	return mi


## Turns this thug (and its crew nearby) against the player.
func provoke(alert_gang := true) -> void:
	if state == "dead":
		return
	_far_time = 0.0
	if not hostile:
		hostile = true
		if state == "wander":
			state = "chase"
		say("Oh, you're dead.")
	if alert_gang:
		for other in get_tree().get_nodes_in_group("enemies"):
			if other != self and other.global_position.distance_to(global_position) < GANG_RADIUS:
				other.provoke(false)


func say(text: String) -> void:
	if _speech == null:
		_speech = Label3D.new()
		_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_speech.no_depth_test = true
		_speech.font_size = 48
		_speech.pixel_size = 0.004
		_speech.outline_size = 12
		_speech.outline_modulate = Color(0.06, 0.03, 0.1)
		_speech.position.y = 2.5
		add_child(_speech)
	_speech.text = text
	_speech.modulate.a = 1.0
	var tw := _speech.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_speech, "modulate:a", 0.0, 0.5)


func begin_talk(at: Vector3) -> void:
	if state == "wander":
		_face(at - global_position, 100.0, 1.0)
		_wander_wait = INF
		_wander_to = global_position


func end_talk() -> void:
	if state == "wander":
		_wander_wait = 1.0


func face(pos: Vector3) -> void:
	_face(pos - global_position, 100.0, 1.0)


func change_mood(delta_mood: int) -> void:
	mood = clampi(mood + delta_mood, 0, 100)


## Thugs have no clip set; reactions are a quick arm gesture.
func react(_clip: String, _speed := 1.0) -> float:
	var tw := create_tween()
	tw.tween_property(arm, "rotation:x", 1.2, 0.15)
	tw.tween_property(arm, "rotation:x", 0.0, 0.3)
	return 0.45


## Neutral reaction when the player talks to this thug.
func talk() -> void:
	if state == "wander" and target != null:
		_face((target.global_position - global_position), 100.0, 1.0)
		_wander_wait = 3.0
		_wander_to = global_position
	say(LINES[randi() % LINES.size()])


## The heroine parried this thug's punch: long stagger, pushed back.
func parried(from: Vector3) -> void:
	if state == "dead":
		return
	state = "stagger"
	_stagger_time = 1.3
	_t = 0.0
	_glow = 0.0
	var away := global_position - from
	away.y = 0.0
	velocity = away.normalized() * 4.0
	say("Tch—!")


func take_hit(damage: float, impulse: Vector3, heavy := false) -> void:
	if state == "dead":
		return
	provoke()
	get_tree().call_group("civilians", "witness", global_position, self)
	hp -= damage
	_flash = 1.0
	_glow = 0.0
	velocity = impulse
	bar.visible = true
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	bar_fill.scale.x = maxf(ratio, 0.001)
	bar_fill.position.x = -(1.0 - ratio) * 0.4
	_t = 0.0
	if hp <= 0.0:
		state = "dead"
		velocity = impulse * 1.4 + Vector3.UP * 5.0
		collision_layer = 0
		remove_from_group("enemies")
		bar.visible = false
		died.emit(self)
	else:
		state = "stagger"
		_stagger_time = 0.55 if heavy else 0.3


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_t += delta
	_cooldown -= delta
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	var to_target := Vector3.ZERO
	var has_target: bool = target != null and is_instance_valid(target) and target.is_alive()
	if has_target:
		to_target = target.global_position - global_position
		to_target.y = 0.0

	match state:
		"wander":
			_glow = 0.0
			arm.rotation.x = lerpf(arm.rotation.x, 0.0, 1.0 - exp(-8.0 * delta))
			var to_spot := _wander_to - global_position
			to_spot.y = 0.0
			if to_spot.length() > 0.4:
				_face(to_spot, 5.0, delta)
				_steer(to_spot.normalized() * WANDER_SPEED + _separation(), 6.0, delta)
			else:
				_steer(Vector3.ZERO, 6.0, delta)
				_wander_wait -= delta
				if _wander_wait <= 0.0:
					_wander_to = _home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
					_wander_wait = randf_range(2.0, 5.0)
		"chase":
			_glow = move_toward(_glow, 0.0, delta * 4.0)
			if calm_down:
				var far: bool = not has_target or to_target.length() > CALM_DISTANCE
				_far_time = _far_time + delta if far else 0.0
				if _far_time > 6.0:
					hostile = false
					state = "wander"
					_wander_to = _home
			arm.rotation.x = lerpf(arm.rotation.x, 0.0, 1.0 - exp(-8.0 * delta))
			if has_target and to_target.length() < AGGRO_RANGE:
				_face(to_target, 8.0, delta)
				var dist := to_target.length()
				var want := to_target.normalized() * SPEED if dist > ATTACK_RANGE * 0.85 else Vector3.ZERO
				want += _separation() * 2.0
				_steer(want, 8.0, delta)
				if dist <= ATTACK_RANGE and _cooldown <= 0.0:
					state = "windup"
					_t = 0.0
			else:
				_steer(Vector3.ZERO, 6.0, delta)
		"windup":
			_steer(Vector3.ZERO, 10.0, delta)
			if has_target:
				_face(to_target, 3.0, delta)
			_glow = _t / WINDUP
			arm.rotation.x = lerpf(0.0, 1.1, ease(_t / WINDUP, 0.5))
			if _t >= WINDUP:
				state = "strike"
				_t = 0.0
				_struck = false
				var fwd := -model.global_basis.z
				velocity.x = fwd.x * 7.0
				velocity.z = fwd.z * 7.0
		"strike":
			arm.rotation.x = lerpf(1.1, -1.6, minf(_t / 0.06, 1.0))
			_glow = 1.0
			if not _struck and has_target and to_target.length() <= ATTACK_RANGE + 0.4:
				var fwd := -model.global_basis.z
				if fwd.dot(to_target.normalized()) > 0.4:
					_struck = true
					target.take_hit(damage, to_target.normalized() * 5.0 + Vector3.UP * 1.5, false, self)
			if _t >= STRIKE:
				state = "recover"
				_t = 0.0
		"recover":
			_glow = move_toward(_glow, 0.0, delta * 3.0)
			_steer(Vector3.ZERO, 8.0, delta)
			arm.rotation.x = lerpf(arm.rotation.x, 0.0, 1.0 - exp(-6.0 * delta))
			if _t >= RECOVER:
				state = "chase" if hostile else "wander"
				_cooldown = randf_range(1.0, 2.2)
		"stagger":
			_glow = 0.0
			arm.rotation.x = lerpf(arm.rotation.x, -0.6, 1.0 - exp(-10.0 * delta))
			model.rotation.x = lerpf(model.rotation.x, -0.25, 1.0 - exp(-12.0 * delta))
			_steer(Vector3.ZERO, 5.0, delta)
			if _t >= _stagger_time:
				state = "chase" if hostile else "wander"
				model.rotation.x = 0.0
		"dead":
			model.rotation.x = lerpf(model.rotation.x, -1.5, 1.0 - exp(-6.0 * delta))
			if is_on_floor():
				_steer(Vector3.ZERO, 4.0, delta)
			if _t > 1.0:
				model.scale = Vector3.ONE * maxf(1.0 - (_t - 1.0) * 3.0, 0.01)
			if _t > 1.35:
				queue_free()

	body_mat.set_shader_parameter("albedo", color.lerp(Color.WHITE, _flash))
	body_mat.set_shader_parameter("emission", Color(0.9, 0.08, 0.15) * _glow * 0.8)
	_animate_vrm()
	move_and_slide()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if bar.visible and cam != null:
		bar.global_basis = cam.global_basis


func _face(dir: Vector3, rate: float, delta: float) -> void:
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


func _steer(want: Vector3, rate: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3(want.x, 0.0, want.z), 1.0 - exp(-rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Keeps thugs from stacking on the same spot around the player.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var dist := d.length()
		if dist > 0.01 and dist < 1.6:
			push += d / dist * (1.6 - dist)
	return push
