extends CharacterBody3D
## Playable heroine: camera-relative movement, dash with perfect dodge, light/heavy melee combos,
## lock-on and hit reactions. Drives the VRM visual through layered procedural poses.

const VrmCharacter := preload("res://scripts/vrm_character.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Moves := preload("res://scripts/combat/moves.gd")
const SlashTrail := preload("res://scripts/combat/slash_trail.gd")
const CombatFx := preload("res://scripts/combat/combat_fx.gd")

const GameSettings := preload("res://scripts/game_settings.gd")

const WALK_SPEED := 4.5
const RUN_SPEED := 8.0
const ACCEL := 12.0
const JUMP_VELOCITY := 6.5
const DASH_SPEED := 17.0
const DASH_TIME := 0.2
const DASH_COOLDOWN := 0.3
const HURT_TIME := 0.35
const COMBO_RESET := 0.6
const LOCK_RANGE := 16.0
const SOFT_LOCK_RANGE := 4.5

enum State { MOVE, DASH, ATTACK, HURT, DEAD }

signal health_changed(hp: float, max_hp: float)
signal hit_landed(count: int)
signal perfect_dodge
signal parried
signal guard_broken
signal died

const MAX_STAMINA := 100.0
const SPRINT_DRAIN := 16.0
const DASH_COST := 20.0
const STRONG_COST := 40.0
const STAMINA_REGEN := 30.0
const STAMINA_DELAY := 0.8
## Block: hold C / Ctrl / mouse 4. Parry: R / mouse 5 — always a quick evasive roll; it parries
## any enemy that is winding up or striking within PARRY_RANGE, and anything that hits her mid-roll.
const PARRY_RANGE := 3.2
const PARRY_COST := 12.0
const ROLL_TIME := 0.42
const ROLL_SPEED := 9.0
const BLOCK_SPEED := 1.6
const BLOCK_CHIP := 0.15
const BLOCK_STAMINA := 18.0
const COUNTER_TIME := 1.5
const COUNTER_BONUS := 1.5
const BLOCK_CLIP := "ual2/Idle_Shield"
## Stances (X crouch, Z prone): slower movement, lower collision, their own clips.
const CROUCH_SPEED := 1.8
const PRONE_SPEED := 0.9
const STANCE_CLIPS := ["ual1/Crouch_Fwd", "ual1/Crouch_Idle", "ual1/Swim_Fwd"]
## The swim stroke doubles as a belly crawl; it needs lifting so the body rests on the ground.
const PRONE_OFFSET := Vector3(0, 0.32, 0)
const LIE_CLIP := "ual2/LayToIdle"

var rig
var spawn_point := Vector3(0, 1, 0)
var max_hp := 100.0
var hp := 100.0
var stamina := MAX_STAMINA
var _stamina_rest := 0.0
var _charged := false
var _step_t := 0.0
var lock_target ## Thug node (duck-typed: is_alive / take_hit).

var visual
var state := State.MOVE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _facing := 0.0
var _base_yaw := 0.0
var _spin := 0.0
var _state_t := 0.0
var _dash_dir := Vector3.ZERO
var _dash_cooldown := 0.0
var blocking := false
var _block_t := 0.0
var _dash_time := DASH_TIME
## "stand", "crouch" or "prone".
var stance := "stand"
var _capsule: CapsuleShape3D
var _shape: CollisionShape3D
var _lying := false
var _counter_t := 0.0
var _invulnerable := false
var _move: Dictionary = {}
var _combo := 0
var _combo_timer := 0.0
var _queued := ""
var _hit_this_move: Array = []
var _hit_count := 0
var _hit_count_timer := 0.0
var _speed_lines := 0.0
var _trail
## True while the current state is animated by a clip rather than procedural poses.
var _clip_driven := false
## Set while UI (interaction wheel) owns the mouse/keys; movement input is ignored.
var input_locked := false
var _emoting := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 3
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.3
	_capsule.height = 1.6
	_shape.shape = _capsule
	_shape.position.y = 0.8
	add_child(_shape)

	visual = VrmCharacter.new()
	visual.model_scene = load(GameSettings.heroine_path())
	add_child(visual)
	GameSettings.apply_look(visual)
	var f: Vector3 = visual.forward_local()
	_base_yaw = atan2(f.x, f.z)

	_trail = SlashTrail.new()
	add_child(_trail)


func is_alive() -> bool:
	return state != State.DEAD and visible


func set_driving(on: bool) -> void:
	visible = not on
	set_physics_process(not on)
	# Layer 2 lets traffic sensors see the heroine.
	collision_layer = 0 if on else 3
	collision_mask = 0 if on else 1
	velocity = Vector3.ZERO
	_emoting = false
	visual.force_clip = ""
	_set_lock(null)


func forward_dir() -> Vector3:
	return Vector3(sin(_facing), 0.0, cos(_facing))


func _physics_process(delta: float) -> void:
	_state_t += delta
	_dash_cooldown -= delta
	_combo_timer -= delta
	_hit_count_timer -= delta
	if _hit_count_timer <= 0.0:
		_hit_count = 0
	if not is_on_floor():
		velocity.y -= gravity * delta
	if lock_target != null and (not is_instance_valid(lock_target) or not lock_target.is_alive()):
		_set_lock(null)
	if Input.is_action_just_pressed("lock_on") and state != State.DEAD:
		_set_lock(null if lock_target != null else _nearest_enemy(LOCK_RANGE))

	match state:
		State.MOVE:
			_state_move(delta)
		State.DASH:
			_state_dash()
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_decelerate(delta, 8.0)
			if _state_t >= HURT_TIME:
				state = State.MOVE
		State.DEAD:
			_decelerate(delta, 6.0)
			if _state_t >= 2.5:
				_respawn()

	move_and_slide()
	_update_visual(delta)
	if global_position.y < -30.0:
		_respawn()


func _input_dir() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = rig.yaw if rig != null else 0.0
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)


## Turns to face a world position immediately (interactions line the heroine up with NPCs).
func face_towards(pos: Vector3) -> void:
	var d := pos - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		_facing = atan2(d.x, d.z)


## Swaps the model in place (outfit change from the wardrobe).
func reload_visual() -> void:
	var old = visual
	visual = VrmCharacter.new()
	visual.model_scene = load(GameSettings.heroine_path())
	add_child(visual)
	GameSettings.apply_look(visual)
	var f: Vector3 = visual.forward_local()
	_base_yaw = atan2(f.x, f.z)
	_emoting = false
	old.queue_free()


## Plays a one-shot clip (handshake, push, kiss...) from the move state; returns its duration.
func perform(clip: String, speed := 1.0) -> float:
	if state != State.MOVE:
		return 0.0
	_emoting = false
	visual.force_clip = ""
	velocity.x = 0.0
	velocity.z = 0.0
	return visual.clip_length(clip) / speed if visual.play_action_clip(clip, speed, 0.12) else 0.0


## Loops a looping clip (dance, phone call...) until the player moves or acts.
## LIE_CLIP is special: she lies down on her back and stays there.
func play_emote(clip: String) -> void:
	if state != State.MOVE or not visual.has_clips:
		return
	set_stance("stand")
	if clip == LIE_CLIP:
		visual.force_clip = ""
		visual.play_action_clip(LIE_CLIP, 0.001, 0.25, "", false)
		_lying = true
	else:
		visual.force_clip = clip
	_emoting = true


## Changes stance, resizing the collision capsule (crouch ~1.1 m tall, prone ~0.6 m).
func set_stance(new_stance: String) -> void:
	if new_stance == stance:
		return
	stance = new_stance
	var h: float = {"stand": 1.6, "crouch": 1.1, "prone": 0.6}[stance]
	_capsule.height = h
	_shape.position.y = h * 0.5
	if stance == "stand" and STANCE_CLIPS.has(visual.force_clip):
		visual.force_clip = ""
		visual.force_speed = 1.0


func _stance_visual() -> void:
	visual.body_offset = PRONE_OFFSET if stance == "prone" and state == State.MOVE else visual.body_offset
	if stance == "stand" or state != State.MOVE or blocking or _emoting:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if stance == "crouch":
		visual.force_clip = "ual1/Crouch_Fwd" if speed > 0.3 else "ual1/Crouch_Idle"
		visual.force_speed = clampf(speed / CROUCH_SPEED, 0.6, 1.4) if speed > 0.3 else 1.0
	else:
		visual.force_clip = "ual1/Swim_Fwd"
		visual.force_speed = clampf(speed / PRONE_SPEED, 0.0, 1.3)


func _state_move(delta: float) -> void:
	var dir := Vector3.ZERO if input_locked else _input_dir()
	if _emoting and (dir.length() > 0.1 or Input.is_action_just_pressed("attack_light") \
			or Input.is_action_just_pressed("attack_heavy") or Input.is_action_just_pressed("sprint") \
			or Input.is_action_just_pressed("jump")):
		_emoting = false
		visual.force_clip = ""
		if _lying:
			_lying = false
			visual.play_action_clip(LIE_CLIP, 1.4, 0.1)
	if not input_locked:
		if Input.is_action_just_pressed("crouch"):
			set_stance("stand" if stance == "crouch" else "crouch")
		elif Input.is_action_just_pressed("prone"):
			set_stance("stand" if stance == "prone" else "prone")
		elif stance != "stand" and (Input.is_action_just_pressed("sprint") or Input.is_action_just_pressed("jump")):
			set_stance("stand")
	if input_locked:
		_decelerate(delta, ACCEL)
		return
	_update_block(delta)
	var running := Input.is_action_pressed("sprint") and dir.length() > 0.1 and stamina > 0.0 and not blocking
	if running:
		_spend(SPRINT_DRAIN * delta)
	running = running and stance == "stand"
	var speed := BLOCK_SPEED if blocking else (RUN_SPEED if running else WALK_SPEED)
	if stance == "crouch":
		speed = CROUCH_SPEED
	elif stance == "prone":
		speed = PRONE_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * speed, 1.0 - exp(-ACCEL * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if lock_target != null:
		_face(lock_target.global_position - global_position, 10.0, delta)
	elif dir.length() > 0.1:
		_face(dir, 12.0, delta)

	if is_on_floor() and Input.is_action_just_pressed("jump") and stance == "stand":
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_pressed("parry") and stamina >= PARRY_COST and _dash_cooldown <= 0.0:
		set_stance("stand")
		_try_parry(dir)
		return
	if blocking:
		return
	if Input.is_action_just_pressed("attack_light"):
		_start_attack("light")
	elif Input.is_action_just_pressed("attack_heavy"):
		_start_attack("heavy")
	elif Input.is_action_just_pressed("attack_strong") and stamina >= STRONG_COST:
		_spend(STRONG_COST)
		_start_attack("strong")


## Raises / lowers the guard while the block button is held (move state only).
func _update_block(delta: float) -> void:
	var want := Input.is_action_pressed("block") and not input_locked and is_on_floor()
	if want and not blocking:
		blocking = true
		_block_t = 0.0
		_emoting = false
		visual.force_clip = BLOCK_CLIP if visual.has_clips else ""
	elif not want and blocking:
		_end_block()
	if blocking:
		_block_t += delta
		var target := _pick_target()
		if target != null:
			_face(target.global_position - global_position, 10.0, delta)


func _end_block() -> void:
	blocking = false
	if visual.force_clip == BLOCK_CLIP:
		visual.force_clip = ""


## Parry roll: dodges sideways out of the attack, staying turned toward the attacker.
func _start_dash(dir: Vector3, keep_facing := false) -> void:
	_dash_dir = (dir if dir.length() > 0.1 else forward_dir()).normalized()
	state = State.DASH
	_state_t = 0.0
	_dash_time = ROLL_TIME
	_invulnerable = true
	_queued = ""
	if lock_target == null and not keep_facing:
		_face(_dash_dir, 0.0, 0.0)
	var roll_len: float = visual.clip_length("ual1/Roll")
	_clip_driven = visual.play_action_clip("ual1/Roll", maxf(roll_len / ROLL_TIME, 1.0), 0.05)
	CombatFx.dust(get_parent(), global_position)


func _state_dash() -> void:
	var k := 1.0 - _state_t / _dash_time
	velocity.x = _dash_dir.x * ROLL_SPEED * (0.4 + 0.6 * k)
	velocity.z = _dash_dir.z * ROLL_SPEED * (0.4 + 0.6 * k)
	_speed_lines = 1.0
	if Input.is_action_just_pressed("attack_light"):
		_queued = "light"
	elif Input.is_action_just_pressed("attack_heavy"):
		_queued = "heavy"
	if _state_t > _dash_time * 0.8:
		_invulnerable = false
	if _state_t >= _dash_time:
		state = State.MOVE
		_dash_cooldown = DASH_COOLDOWN
		if _queued != "":
			_start_attack(_queued)


## Attacks `target` specifically (interaction-wheel kick), overriding the soft lock.
func attack_target(kind: String, target: Node3D) -> void:
	if state != State.MOVE:
		return
	_emoting = false
	visual.force_clip = ""
	_start_attack(kind)
	_face(target.global_position - global_position, 0.0, 0.0)


## Uses stamina and pauses its regeneration briefly.
func _spend(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_rest = STAMINA_DELAY


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, MAX_STAMINA)


func _start_attack(kind: String) -> void:
	_charged = false
	set_stance("stand")
	Sfx.play(self, "charge" if kind == "strong" else "whoosh", global_position, -4.0, randf_range(0.9, 1.15))
	if kind == "strong":
		_move = Moves.STRONG
		_combo = 0
	elif kind == "heavy":
		_move = Moves.HEAVY
		_combo = 0
	else:
		if _combo_timer <= 0.0 and state != State.ATTACK:
			_combo = 0
		_move = Moves.LIGHT[_combo % Moves.LIGHT.size()]
		_combo += 1
	state = State.ATTACK
	_state_t = 0.0
	_queued = ""
	_hit_this_move.clear()
	var target := _pick_target()
	if target != null:
		_face(target.global_position - global_position, 0.0, 0.0)
	elif _input_dir().length() > 0.1:
		_face(_input_dir(), 0.0, 0.0)
	if _move.has("charge_clip"):
		_clip_driven = visual.play_action_clip(_move["charge_clip"], 1.2, 0.08)
		visual.set_expression("angry", 1.0)
	else:
		_clip_driven = _move.has("clip") and visual.play_action_clip(
				_move["clip"], _move.get("clip_speed", 1.0), 0.06, _move.get("clip_then", ""))
	var limb: String = _move.get("clip_limb", _move["limb"]) if _clip_driven else _move["limb"]
	_trail.attach(visual.skeleton, limb, _move["color"])
	visual.set_expression("angry", 0.5)


func _state_attack(delta: float) -> void:
	var m := _move
	var t := _state_t
	var hit_start: float = m["hit"][0]
	var hit_end: float = m["hit"][1]

	# Lunge into the strike, then plant. Charged moves hold still while gathering power.
	var charge: float = m.get("charge", 0.0)
	var lunge := 0.0
	if t < charge:
		_speed_lines = 1.0
		if rig != null:
			rig.shake(0.04)
	elif t < hit_end:
		lunge = float(m["lunge"]) * (1.0 - (t - charge) / (hit_end - charge))
	if charge > 0.0 and t >= charge and not _charged:
		_charged = true
		_clip_driven = visual.play_action_clip(m["clip"], m.get("clip_speed", 1.0), 0.05, m.get("clip_then", ""))
		CombatFx.shockwave(get_parent(), global_position + Vector3.UP * 0.1, m["color"])
		CombatFx.slow_motion(get_tree(), 0.55, 0.25)
		if rig != null:
			rig.shake(0.4)
	var fwd := forward_dir()
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	if t < hit_start:
		var target := _pick_target()
		if target != null:
			_face(target.global_position - global_position, 20.0, delta)

	if t >= hit_start and t <= hit_end:
		_do_hits(m)
	_trail.emitting = t >= hit_start - 0.05 and t <= hit_end + 0.03

	if Input.is_action_just_pressed("attack_light"):
		_queued = "light"
	elif Input.is_action_just_pressed("attack_heavy"):
		_queued = "heavy"
	if t >= float(m["cancel"]) and _queued != "":
		_trail.emitting = false
		if _queued == "dash":
			_start_dash(_input_dir())
		else:
			_start_attack(_queued)
		return
	if t >= float(m["duration"]):
		_trail.emitting = false
		visual.stop_action_clip()
		state = State.MOVE
		_combo_timer = COMBO_RESET
		visual.set_expression("neutral")


func _do_hits(m: Dictionary) -> void:
	var fwd := forward_dir()
	var center := global_position + Vector3.UP + fwd * float(m["reach"]) * 0.6
	var heavy: bool = m.get("heavy", false)
	# Civilians can be hit too (GTA rules); they never get soft-locked though.
	for enemy in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("civilians"):
		if enemy in _hit_this_move or not enemy.is_alive():
			continue
		var enemy_center: Vector3 = enemy.global_position + Vector3.UP
		if enemy_center.distance_to(center) > float(m["radius"]) + 0.4:
			continue
		_hit_this_move.append(enemy)
		var dir: Vector3 = enemy.global_position - global_position
		dir.y = 0.0
		var impulse := dir.normalized() * float(m["knockback"]) + Vector3.UP * float(m.get("launch", 0.0))
		var damage := float(m["damage"])
		if _counter_t > 0.0:
			# Counter after a parry.
			damage *= COUNTER_BONUS
			_counter_t = 0.0
		enemy.take_hit(damage, impulse, heavy)
		Sfx.play(self, "hit_heavy" if heavy else "hit", enemy_center)
		CombatFx.hit_spark(get_parent(), enemy_center.lerp(center, 0.5), m["color"], heavy)
		CombatFx.hit_stop(get_tree(), 0.09 if heavy else 0.045)
		if heavy:
			CombatFx.impact_frame(get_tree(), 0.14 if m.get("strong", false) else 0.06)
		if rig != null:
			rig.shake(0.5 if heavy else 0.2)
		_hit_count += 1
		_hit_count_timer = 1.6
		hit_landed.emit(_hit_count)


## `attacker` (optional) is staggered by a parry; vehicles cannot be blocked.
func take_hit(damage: float, impulse: Vector3, heavy := false, attacker = null) -> void:
	if state == State.DEAD or not visible:
		return
	if stance != "stand" and not _invulnerable:
		set_stance("stand")
	_lying = false
	if blocking and state == State.MOVE and not (attacker is VehicleBody3D):
		var toward := -impulse
		toward.y = 0.0
		if toward.length() < 0.01 or forward_dir().dot(toward.normalized()) > 0.1:
			_guard_hit(damage, impulse, heavy)
			return
	_emoting = false
	if blocking:
		_end_block()
	visual.force_clip = ""
	if _invulnerable:
		# Hit mid-roll: that's a parry too.
		_parry_effects()
		if attacker != null and is_instance_valid(attacker) and attacker.has_method("parried"):
			attacker.parried(global_position)
		perfect_dodge.emit()
		parried.emit()
		return
	hp = maxf(hp - damage, 0.0)
	health_changed.emit(hp, max_hp)
	velocity = impulse
	_trail.emitting = false
	CombatFx.hit_spark(get_parent(), global_position + Vector3.UP * 1.1, Color(1.0, 0.3, 0.4), false)
	if rig != null:
		rig.shake(0.35)
	visual.set_expression("surprised", 0.8)
	_state_t = 0.0
	if hp <= 0.0:
		state = State.DEAD
		_set_lock(null)
		_clip_driven = visual.play_action_clip("ual1/Death01", 1.0, 0.1, "", true)
		visual.set_expression("sad")
		died.emit()
	else:
		state = State.HURT
		var clip := "ual2/Hit_Knockback" if impulse.length() > 6.0 else "ual1/Hit_Chest"
		_clip_driven = visual.play_action_clip(clip, 1.0, 0.05)


## Parry button: staggers every enemy that is mid-attack nearby and rolls out sideways; with no
## attack coming it is an evasive roll (still parries anything that lands during it).
func _try_parry(input_dir: Vector3) -> void:
	_end_block()
	_spend(PARRY_COST)
	var threats := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.state in ["windup", "strike"] and e.global_position.distance_to(global_position) <= PARRY_RANGE:
			threats.append(e)
	if threats.is_empty():
		_start_dash(input_dir if input_dir.length() > 0.1 else -forward_dir(), lock_target != null)
		Sfx.play(self, "whoosh", global_position)
		return
	var nearest = threats[0]
	for e in threats:
		e.parried(global_position)
		if e.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position):
			nearest = e
	_parry_effects()
	var back := global_position - nearest.global_position
	back.y = 0.0
	back = back.normalized()
	_face(-back, 0.0, 0.0)
	var side := Vector3(-back.z, 0, back.x) * (1.0 if randf() < 0.5 else -1.0)
	_start_dash(side * 0.8 + back * 0.5, true)
	parried.emit()


func _parry_effects() -> void:
	restore_stamina(15.0)
	_counter_t = COUNTER_TIME
	CombatFx.slow_motion(get_tree(), 0.3, 0.5)
	CombatFx.impact_frame(get_tree(), 0.08)
	CombatFx.hit_spark(get_parent(), global_position + Vector3.UP * 1.2 + forward_dir() * 0.5, Color(1.0, 0.85, 0.35), true)
	Sfx.play(self, "parry", global_position)
	_speed_lines = 1.0
	if rig != null:
		rig.shake(0.3)


func _guard_hit(damage: float, impulse: Vector3, heavy: bool) -> void:
	hp = maxf(hp - damage * BLOCK_CHIP, 1.0)
	health_changed.emit(hp, max_hp)
	_spend(BLOCK_STAMINA * (2.0 if heavy else 1.0))
	velocity = Vector3(impulse.x, 0.0, impulse.z) * 0.35
	CombatFx.hit_spark(get_parent(), global_position + Vector3.UP * 1.2 + forward_dir() * 0.4, Color(0.6, 0.85, 1.0), false)
	Sfx.play(self, "block", global_position)
	if rig != null:
		rig.shake(0.15)
	if stamina <= 0.0:
		# Guard break: the block collapses into a long stagger.
		_end_block()
		state = State.HURT
		_state_t = -0.5
		_clip_driven = visual.play_action_clip("ual1/Hit_Chest", 0.8, 0.05)
		visual.set_expression("surprised", 1.0)
		guard_broken.emit()


func _respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	hp = max_hp
	health_changed.emit(hp, max_hp)
	state = State.MOVE
	visual.stop_action_clip()
	visual.set_expression("neutral")


func _decelerate(delta: float, rate: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3.ZERO, 1.0 - exp(-rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Turns toward `dir`; rate <= 0 snaps instantly.
func _face(dir: Vector3, rate: float, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.001:
		return
	var target := atan2(dir.x, dir.z)
	_facing = target if rate <= 0.0 else lerp_angle(_facing, target, 1.0 - exp(-rate * delta))


func _pick_target() -> Node3D:
	if lock_target != null:
		return lock_target
	return _nearest_enemy(SOFT_LOCK_RANGE)


func _nearest_enemy(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_dist := max_dist
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_alive():
			continue
		var dist: float = enemy.global_position.distance_to(global_position)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best


func _set_lock(target: Node3D) -> void:
	lock_target = target
	if rig != null:
		rig.lock_target = target


func _process(delta: float) -> void:
	_counter_t -= delta
	_footsteps(delta)
	_stamina_rest -= delta
	if _stamina_rest <= 0.0:
		# Sitting on a bench recovers twice as fast.
		var rate := STAMINA_REGEN * (2.0 if visual != null and visual.force_clip == "ual1/Sitting_Idle" else 1.0)
		stamina = minf(stamina + rate * delta, MAX_STAMINA)


func _update_visual(delta: float) -> void:
	var pose := {}
	var weight := 0.0
	var spin_target := 0.0
	match state:
		State.ATTACK:
			var m := _move
			var t := _state_t
			var hit_start: float = m["hit"][0]
			var hit_end: float = m["hit"][1]
			var duration: float = m["duration"]
			if t < hit_start * 0.6:
				pose = m["windup"]
				weight = clampf(t / 0.06, 0.0, 1.0)
			elif t < hit_start:
				pose = Moves.lerp_pose(m["windup"], m["strike"], ease((t - hit_start * 0.6) / (hit_start * 0.4), 0.4))
				weight = 1.0
			else:
				pose = m["strike"]
				weight = 1.0 - clampf((t - hit_end - 0.05) / maxf(duration - hit_end - 0.05, 0.01), 0.0, 1.0)
			if m.get("spin", false):
				# Full turn plus a quarter so the side kick meets the target, unwinding afterwards.
				var wind := smoothstep(0.0, hit_start, t) * (TAU + PI * 0.5)
				spin_target = wind if t < hit_end else lerpf(TAU + PI * 0.5, TAU, smoothstep(hit_end, duration, t))
		State.DASH:
			pose = Moves.DASH_POSE
			weight = 1.0
		State.HURT:
			pose = Moves.HURT_POSE
			weight = 1.0 - _state_t / HURT_TIME
		State.DEAD:
			pose = Moves.DOWN_POSE
			weight = minf(_state_t * 4.0, 1.0)
	if state != State.ATTACK or not _move.get("spin", false):
		_spin = 0.0
	else:
		_spin = spin_target
	# Clips already animate these states; procedural poses only fill in moves without one.
	if _clip_driven and state != State.MOVE:
		pose = {}

	if pose.is_empty():
		visual.action_weight = move_toward(visual.action_weight, 0.0, delta * 6.0)
	else:
		visual.action_pose = pose
		visual.action_weight = weight
	visual.body_offset = Vector3(0, -0.45 * visual.action_weight, 0) if state == State.DEAD and not _clip_driven else Vector3.ZERO
	_stance_visual()
	visual.rotation.y = _facing - _base_yaw + _spin
	visual.move_speed = Vector3(velocity.x, 0.0, velocity.z).length() if state == State.MOVE else 0.0
	visual.grounded = is_on_floor()
	visual.look_target = lock_target

	_speed_lines = move_toward(_speed_lines, 0.0, delta * 4.0)
	CombatFx.set_post(get_tree(), "speed_lines", _speed_lines)


## Soft footsteps while walking / running on the ground.
func _footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not visible or not is_on_floor() or speed < 0.8 or state != State.MOVE:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.27 if speed > WALK_SPEED + 0.5 else 0.42
		Sfx.play(self, "step", global_position, -14.0, randf_range(0.85, 1.15))
