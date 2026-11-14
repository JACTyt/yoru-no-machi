extends Node3D
## NPC body built from an exported VRoid model, with the same interface as mannequin.gd
## (play / play_once / release) so civilians can use either. Faces +Z. `tints` recolours clothing
## parts (see GameSettings.PARTS) for pedestrian variety.

const VrmCharacter := preload("res://scripts/vrm_character.gd")
const GameSettings := preload("res://scripts/game_settings.gd")

## Locomotion clips map onto the VRM's own speed-driven walk/run instead of a forced loop.
const LOCOMOTION_SPEED := {"ual1/Idle": 0.0, "ual1/Walk": 1.4, "ual1/Jog_Fwd": 3.5, "ual1/Sprint": 5.5}

var model_path := ""
var tints := {}
var vrm

var _once_until := 0.0
var _after := ""
var _time := 0.0


func _ready() -> void:
	vrm = VrmCharacter.new()
	vrm.model_scene = load(model_path)
	add_child(vrm)
	var f: Vector3 = vrm.forward_local()
	vrm.rotation.y = -atan2(f.x, f.z)
	if not tints.is_empty():
		GameSettings.tint(vrm, tints)


## Loops `clip`; ignored while a one-shot is playing unless `force`.
func play(clip: String, speed := 1.0, force := false) -> void:
	if not force and _time < _once_until:
		return
	if LOCOMOTION_SPEED.has(clip):
		vrm.force_clip = ""
		vrm.move_speed = LOCOMOTION_SPEED[clip]
	else:
		vrm.move_speed = 0.0
		vrm.force_clip = clip
		vrm.force_speed = speed


## Plays `clip` once, then loops `after`; returns the clip's duration.
func play_once(clip: String, after := "ual1/Idle", speed := 1.0, hold := false) -> float:
	vrm.force_clip = ""
	vrm.move_speed = 0.0
	if not vrm.play_action_clip(clip, speed, 0.12, "", hold):
		return 0.0
	var length: float = vrm.clip_length(clip) / speed
	_once_until = INF if hold else _time + length
	_after = after
	return length


func release() -> void:
	_once_until = 0.0
	vrm.stop_action_clip()


func set_expression(expr: String, weight := 1.0) -> void:
	vrm.set_expression(expr, weight)


func _process(delta: float) -> void:
	_time += delta
	if _once_until != INF and _once_until > 0.0 and _time >= _once_until:
		_once_until = 0.0
		if not _after.is_empty():
			play(_after, 1.0, true)
