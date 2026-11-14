extends CharacterBody3D
## City pedestrian: strolls the sidewalk loop around its block, stops to chat, reacts to the
## heroine (handshakes, kisses, slaps), panics when violence breaks out and remembers how she
## treated it (`mood`, 0..100). Some carry a small request the heroine can help with.

const Mannequin := preload("res://scripts/npc/mannequin.gd")
const VrmBody := preload("res://scripts/npc/vrm_body.gd")

signal knocked_down

const WALK_SPEED := 1.35
const FLEE_SPEED := 5.0
const RING := 18.25 ## Sidewalk centerline around a block, from the block center.
const NAMES := ["Aoi", "Ren", "Yui", "Haruto", "Mei", "Sora", "Kaito", "Rin", "Daichi", "Hina", "Takumi", "Nana", "Kenji", "Emi", "Shun", "Miyu", "Riku", "Koharu", "Yuto", "Akari"]
const NAMES_F := ["Yui", "Mei", "Hina", "Nana", "Emi", "Miyu", "Koharu", "Akari", "Sakura", "Aya", "Rina", "Haruka"]
const NAMES_M := ["Haruto", "Kaito", "Daichi", "Takumi", "Kenji", "Shun", "Riku", "Yuto", "Sota", "Ryo", "Itsuki", "Kazuki"]
const PERSONALITIES := ["cheerful", "shy", "grumpy", "flirty", "calm"]
const OUTFITS := [Color(0.25, 0.32, 0.55), Color(0.85, 0.85, 0.88), Color(0.15, 0.15, 0.18), Color(0.75, 0.35, 0.4), Color(0.4, 0.6, 0.5),
	Color(0.9, 0.75, 0.45), Color(0.55, 0.45, 0.7), Color(0.35, 0.5, 0.75), Color(0.95, 0.6, 0.65)]
const HAIRS := [Color(0.12, 0.1, 0.12), Color(0.35, 0.22, 0.15), Color(0.6, 0.42, 0.25), Color(0.85, 0.75, 0.55), Color(0.55, 0.55, 0.62), Color(0.75, 0.4, 0.5)]
const SKINS := [Color(1.0, 0.88, 0.8), Color(0.96, 0.8, 0.68), Color(0.85, 0.66, 0.52)]

var npc_name := ""
var personality := "calm"
var mood := 50
## {} or {"type": "lost_item" | "directions", ...}; "accepted" once the heroine agreed to help.
var request := {}
var hostile := false ## Civilians never fight; kept for code that scans both NPC kinds.
var keep := false ## Not despawned by the pedestrian manager (busy with the heroine).
var stationary := false ## Interior staff / students: stay put.
var seated := false
var block_center := Vector3.ZERO
## Exported VRoid model to wear ("" = stylised mannequin), clothing tints and gender for names.
var body_path := ""
var body_tints := {}
var gender := ""
## Custom first line when the heroine talks to them (story characters).
var greeting := ""
var max_hp := 40.0
var hp := 40.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var state := "walk"
var body: Node3D
var _t := 0.0
var _wait := 0.0
var _route_i := 0
var _flee_from := Vector3.ZERO
var _speech: Label3D
var _marker: Label3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("civilians")
	collision_layer = 3
	_rng.randomize()
	if npc_name.is_empty():
		var pool: Array = NAMES_F if gender == "female" else (NAMES_M if gender == "male" else NAMES)
		npc_name = pool[_rng.randi() % pool.size()]
		personality = PERSONALITIES[_rng.randi() % PERSONALITIES.size()]
		mood = _rng.randi_range(35, 60)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	if not body_path.is_empty() and ResourceLoader.exists(body_path):
		body = VrmBody.new()
		body.model_path = body_path
		body.tints = body_tints
	else:
		body = Mannequin.new()
		body.outfit = OUTFITS[_rng.randi() % OUTFITS.size()]
		body.hair = HAIRS[_rng.randi() % HAIRS.size()]
		body.skin = SKINS[_rng.randi() % SKINS.size()]
		body.hair_style = Mannequin.HAIR_STYLES[_rng.randi() % Mannequin.HAIR_STYLES.size()]
	add_child(body)
	_marker = Label3D.new()
	_marker.text = "!"
	_marker.font_size = 96
	_marker.pixel_size = 0.005
	_marker.outline_size = 16
	_marker.modulate = Color(1.0, 0.85, 0.3)
	_marker.outline_modulate = Color(0.25, 0.1, 0.05)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.position.y = 2.3
	add_child(_marker)
	if seated:
		state = "seated"
		body.play("ual1/Sitting_Idle")
	elif stationary:
		state = "idle"
		_wait = INF
	else:
		_route_i = _nearest_corner()


func is_alive() -> bool:
	return state != "down"


func say(text: String, seconds := 2.5) -> void:
	if _speech == null:
		_speech = Label3D.new()
		_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_speech.no_depth_test = true
		_speech.font_size = 44
		_speech.pixel_size = 0.004
		_speech.outline_size = 12
		_speech.outline_modulate = Color(0.06, 0.03, 0.1)
		_speech.position.y = 2.05
		_speech.width = 900
		_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_speech)
	_speech.text = text
	_speech.modulate.a = 1.0
	var tw := _speech.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_speech, "modulate:a", 0.0, 0.5)


func face(pos: Vector3) -> void:
	var d := pos - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		body.rotation.y = atan2(d.x, d.z)


## Stops and turns to the heroine for a conversation.
func begin_talk(at: Vector3) -> void:
	if state == "seated":
		face(at)
		body.play("ual1/Sitting_Idle")
		return
	state = "talk"
	keep = true
	velocity = Vector3.ZERO
	face(at)
	body.play("ual1/Idle_Talking")


func end_talk() -> void:
	if state == "talk":
		state = "idle"
		_wait = INF if stationary else _rng.randf_range(1.0, 2.5)
		body.play("ual1/Idle")
	keep = request.get("accepted", false)


## One-shot reaction clip, then back to whatever it was doing.
func react(clip: String, speed := 1.0) -> float:
	var after := "ual1/Sitting_Idle" if state == "seated" else ("ual1/Idle_Talking" if state == "talk" else "ual1/Idle")
	return body.play_once(clip, after, speed)


func change_mood(delta_mood: int) -> void:
	mood = clampi(mood + delta_mood, 0, 100)


## Runs from `from` for a few seconds.
func flee(from: Vector3) -> void:
	if state == "down":
		return
	if state == "seated":
		body.play_once("ual1/Hit_Head", "ual1/Sitting_Idle")
		return
	state = "flee"
	keep = false
	_t = 0.0
	_flee_from = from
	body.release()


## Ducks and covers (nearby violence it cannot run from).
func cower() -> void:
	if state in ["down", "flee", "seated"]:
		return
	state = "cower"
	_t = 0.0
	body.play_once("ual1/Crouch_Idle", "ual1/Crouch_Idle", 1.0, true)


func take_hit(damage: float, impulse: Vector3, _heavy := false) -> void:
	if state == "down":
		return
	hp -= damage
	change_mood(-60)
	get_tree().call_group("civilians", "witness", global_position, self)
	request = {}
	velocity = impulse
	say(["Ow!", "Hey!!", "What's wrong with you?!", "Help!"][_rng.randi() % 4], 1.5)
	if hp <= 0.0 or impulse.length() > 6.0:
		state = "down"
		_t = 0.0
		hp = max_hp
		body.play_once("ual1/Death01", "", 1.2, true)
		knocked_down.emit()
	else:
		body.play_once("ual1/Hit_Chest", "ual1/Idle")
		flee(global_position - impulse)


## Violence nearby: bystanders run, people who can't (seated, staff) duck.
func witness(pos: Vector3, victim: Node) -> void:
	if victim == self or state == "down" or global_position.distance_to(pos) > 18.0:
		return
	change_mood(-10)
	if stationary or seated or _rng.randf() < 0.3:
		cower()
	else:
		flee(pos)


## Thrown out of a car by the heroine: lands on the ground, then runs.
func eject(push: Vector3) -> void:
	say(["My car!", "Are you crazy?!", "Thief!! Somebody stop her!"][_rng.randi() % 3], 2.0)
	change_mood(-80)
	velocity = push + Vector3.UP * 2.0
	state = "down"
	_t = 0.6
	body.play_once("ual2/Hit_Knockback", "", 1.0, true)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_t += delta
	_marker.visible = not request.is_empty() and not request.get("accepted", false) and state != "down"
	if state == "seated":
		return
	match state:
		"walk":
			var goal := _corner(_route_i)
			var to := goal - global_position
			to.y = 0.0
			if to.length() < 0.6:
				_route_i = (_route_i + 1) % 4
				if _rng.randf() < 0.35:
					state = "idle"
					_wait = _rng.randf_range(2.0, 6.0)
					if _rng.randf() < 0.3:
						body.play("ual2/Idle_TalkingPhone")
					else:
						body.play("ual1/Idle")
			else:
				_steer(to.normalized() * WALK_SPEED, delta)
				body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
				body.play("ual1/Walk")
		"idle":
			_steer(Vector3.ZERO, delta)
			_wait -= delta
			if _wait <= 0.0:
				state = "walk"
		"talk", "seated":
			_steer(Vector3.ZERO, delta)
		"cower":
			_steer(Vector3.ZERO, delta)
			if _t > 4.0:
				body.release()
				state = "walk" if not stationary else "idle"
				_wait = INF
		"flee":
			var away := global_position - _flee_from
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3.FORWARD
			_steer(away.normalized() * (0.0 if stationary else FLEE_SPEED), delta)
			body.rotation.y = lerp_angle(body.rotation.y, atan2(away.x, away.z), 1.0 - exp(-8.0 * delta))
			body.play("ual1/Crouch_Idle" if stationary else "ual1/Sprint")
			if _t > 7.0:
				state = "idle" if stationary else "walk"
				_wait = INF
				_route_i = _nearest_corner()
		"down":
			_steer(Vector3.ZERO, delta * 0.5)
			if _t > 3.0:
				body.release()
				body.play_once("ual2/LayToIdle", "ual1/Idle")
				state = "getting_up"
				_t = 0.0
		"getting_up":
			_steer(Vector3.ZERO, delta)
			if _t > 1.4:
				var threat := get_tree().get_first_node_in_group("player")
				flee(threat.global_position if threat != null else global_position + Vector3.FORWARD)
	move_and_slide()


func _steer(want: Vector3, delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z).lerp(want, 1.0 - exp(-8.0 * delta))
	velocity.x = h.x
	velocity.z = h.z


func _corner(i: int) -> Vector3:
	var signs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	return block_center + Vector3(signs[i].x, 0, signs[i].y) * RING


func _nearest_corner() -> int:
	var best := 0
	for i in 4:
		if _corner(i).distance_to(global_position) < _corner(best).distance_to(global_position):
			best = i
	return (best + 1) % 4
