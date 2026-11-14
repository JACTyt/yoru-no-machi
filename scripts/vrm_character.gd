extends Node3D
## Wraps an imported VRM model: relaxed A-pose, procedural idle/locomotion, layered action poses,
## blinking, blendable facial expressions and head look-at. Used by the studio and by gameplay.

const EXPRESSIONS := ["happy", "angry", "sad", "relaxed", "surprised"]
## Parent-before-child order; layered poses are applied in this order.
const POSE_ORDER := ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"]

## Humanoid clip libraries (imported with a BoneMap + SkeletonProfileHumanoid so they target %GeneralSkeleton).
const ANIM_LIBRARIES := {
	"ual1": "res://assets/animations/ual1/UAL1_Standard.glb",
	"ual2": "res://assets/animations/ual2/UAL2_Standard.glb",
}
## [clip, natural ground speed in m/s] used to pick and time-scale locomotion.
const LOCOMOTION := [["ual1/Walk", 1.5], ["ual1/Jog_Fwd", 3.5], ["ual1/Sprint", 6.0]]
const IDLE_CLIP := "ual1/Idle"
const AIR_CLIP := "ual1/Jump"

@export var model_scene: PackedScene
@export var look_target: Node3D
@export var arm_drop := 0.94 ## How far the arms hang from T-pose (0 = T-pose, 1 = straight down).
@export var breathing := true

## Driven by the controller each frame.
var move_speed := 0.0
var grounded := true
## bone name -> Vector3(pitch, yaw, roll) in degrees, character space:
## pitch + swings hanging limbs forward / tilts upright bones back; yaw + turns toward the character's left;
## roll + moves hanging limbs toward the character's left / tilts upright bones toward the right.
var action_pose := {}
var action_weight := 0.0
## Extra model offset (e.g. crouching when knocked down).
var body_offset := Vector3.ZERO

var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
## True once retargeted clip libraries are loaded; otherwise the body is posed procedurally.
var has_clips := false
## Studio override: loops this clip instead of choosing locomotion.
var force_clip := ""
## Playback speed of `force_clip` (0 freezes it, e.g. lying still while prone).
var force_speed := 1.0
var _current_clip := ""
var _action_clip_until := 0.0
var _hold_clip := ""

var expression_targets := {}
var _expression_weights := {}
## expression name -> Array of [mesh: MeshInstance3D, shape_index: int, value: float]
var _expression_shapes := {}
var _touched_shapes := []

var _bones := {}
var _arm_targets := {}
var _forward := Vector3.FORWARD
var _right := Vector3.RIGHT
var _time := 0.0
var _stride := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _look := Vector2.ZERO


func _ready() -> void:
	if model_scene == null:
		push_warning("vrm_character: no model_scene set")
		return
	model = model_scene.instantiate()
	add_child(model)
	skeleton = model.get_node_or_null("%GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		var found := model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			skeleton = found[0] as Skeleton3D
	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_disable_face_self_shadow()
	_cache_bones()
	_cache_expressions()
	_load_clip_libraries()


## Anime faces are lit almost flat: no cast shadows from the bangs, and MToon's light/shade
## terminator pushed back and softened so the face doesn't split into hard lit/shaded blotches.
func _disable_face_self_shadow() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).contains("Face"):
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("_ReceiveShadowRate", 0.0)
				mat.set_shader_parameter("_ShadeShift", -0.4)
				mat.set_shader_parameter("_ShadeToony", 0.6)


func _load_clip_libraries() -> void:
	if anim_player == null:
		return
	for lib_name in ANIM_LIBRARIES:
		var path: String = ANIM_LIBRARIES[lib_name]
		if not ResourceLoader.exists(path):
			continue
		var lib := _extract_library(load(path))
		if lib == null:
			continue
		if not _is_retargeted(lib):
			push_warning("%s is not retargeted to SkeletonProfileHumanoid; using procedural animation. See assets/animations/IMPORT.md" % path)
			continue
		if not anim_player.has_animation_library(lib_name):
			anim_player.add_animation_library(lib_name, lib)
		has_clips = true
	if has_clips:
		# Advanced by hand in _update_pose so look-at/action layers apply after the clip.
		anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _extract_library(res: Resource) -> AnimationLibrary:
	if res is AnimationLibrary:
		return res
	if res is PackedScene:
		var inst := (res as PackedScene).instantiate()
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var lib: AnimationLibrary = null
		if ap != null and ap.has_animation_library(""):
			lib = ap.get_animation_library("")
		inst.free()
		return lib
	return null


func _is_retargeted(lib: AnimationLibrary) -> bool:
	for clip in lib.get_animation_list():
		var anim := lib.get_animation(clip)
		for t in anim.get_track_count():
			if String(anim.track_get_path(t)).contains("GeneralSkeleton"):
				return true
	return false


func clip_length(clip: String) -> float:
	return anim_player.get_animation(clip).length if has_clips and anim_player.has_animation(clip) else 0.0


## Plays a one-shot body clip (attack, roll, hit...). `then` is queued after it; `hold` freezes on the last frame.
func play_action_clip(clip: String, speed := 1.0, blend := 0.08, then := "", hold := false) -> bool:
	if not has_clips or not anim_player.has_animation(clip):
		return false
	anim_player.play(clip, blend)
	anim_player.speed_scale = speed
	_current_clip = clip
	var length := clip_length(clip) / speed
	if then != "" and anim_player.has_animation(then):
		anim_player.queue(then)
		length += clip_length(then) / speed
	_hold_clip = clip if hold else ""
	_action_clip_until = INF if hold else _time + length
	return true


func stop_action_clip() -> void:
	_action_clip_until = 0.0
	_hold_clip = ""


## The model's facing direction in this node's local space.
func forward_local() -> Vector3:
	if skeleton == null:
		return Vector3.BACK
	var rel := global_transform.basis.inverse() * skeleton.global_transform.basis
	return (rel * _forward).normalized()


func bone_world_position(bone_name: String) -> Vector3:
	if skeleton == null or not _bones.has(bone_name):
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones[bone_name]).origin


func _cache_bones() -> void:
	if skeleton == null:
		return
	for bone_name in POSE_ORDER:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			_bones[bone_name] = idx
	skeleton.reset_bone_poses()
	if _bones.has("LeftUpperArm") and _bones.has("RightUpperArm"):
		var l := skeleton.get_bone_global_rest(_bones["LeftUpperArm"]).origin
		var r := skeleton.get_bone_global_rest(_bones["RightUpperArm"]).origin
		_forward = (l - r).cross(Vector3.UP).normalized()
		_right = _forward.cross(Vector3.UP).normalized()
		# Arm hang direction: same side, mostly down, slightly forward.
		for side in ["Left", "Right"]:
			var upper: int = _bones[side + "UpperArm"]
			var lower: int = _bones.get(side + "LowerArm", -1)
			if lower < 0:
				continue
			var dir := (skeleton.get_bone_global_rest(lower).origin - skeleton.get_bone_global_rest(upper).origin).normalized()
			var hang := (Vector3(signf(dir.x) * 0.25, -1.0, 0.0) + _forward * 0.08).normalized()
			_arm_targets[upper] = Quaternion(dir, dir.slerp(hang, arm_drop).normalized())


func _cache_expressions() -> void:
	if anim_player == null:
		return
	var root := anim_player.get_node(anim_player.root_node)
	for expr in EXPRESSIONS + ["blink"]:
		if not anim_player.has_animation(expr):
			continue
		var anim := anim_player.get_animation(expr)
		var shapes := []
		for t in anim.get_track_count():
			if anim.track_get_key_count(t) == 0:
				continue
			var path := anim.track_get_path(t)
			var mesh := root.get_node_or_null(NodePath(path.get_concatenated_names())) as MeshInstance3D
			if mesh == null or mesh.mesh == null:
				continue
			var shape_name := ""
			if anim.track_get_type(t) == Animation.TYPE_BLEND_SHAPE:
				shape_name = path.get_concatenated_subnames()
			elif anim.track_get_type(t) == Animation.TYPE_VALUE and path.get_subname_count() == 2 and path.get_subname(0) == "blend_shapes":
				shape_name = path.get_subname(1)
			else:
				continue
			var idx := mesh.find_blend_shape_by_name(shape_name)
			if idx < 0:
				continue
			var value: float = anim.track_get_key_value(t, anim.track_get_key_count(t) - 1)
			shapes.append([mesh, idx, value])
			if not _touched_shapes.has([mesh, idx]):
				_touched_shapes.append([mesh, idx])
		if not shapes.is_empty():
			_expression_shapes[expr] = shapes
			_expression_weights[expr] = 0.0


func has_expression(expr: String) -> bool:
	return _expression_shapes.has(expr)


func set_expression(expr: String, weight := 1.0) -> void:
	for e in EXPRESSIONS:
		expression_targets[e] = weight if e == expr else 0.0


func _process(delta: float) -> void:
	if skeleton == null:
		return
	_time += delta
	_update_pose(delta)
	_update_face(delta)


func _update_pose(delta: float) -> void:
	skeleton.reset_bone_poses()
	if has_clips:
		_update_clips(delta)
		return
	if breathing:
		_rotate_global("Chest", Quaternion(_right, sin(_time * 1.6) * 0.025))
		_rotate_global("Spine", Quaternion(Vector3.UP, sin(_time * 0.7) * 0.03))
	for upper in _arm_targets:
		var sway := Quaternion(_right, sin(_time * 1.6 + 0.5) * 0.02)
		_rotate_global_idx(upper, sway * _arm_targets[upper])
	for side in ["Left", "Right"]:
		_rotate_global(side + "LowerArm", Quaternion(_right, 0.18))

	var loco := _locomotion_pose(delta)
	for bone_name in POSE_ORDER:
		if not _bones.has(bone_name):
			continue
		var e: Vector3 = loco.get(bone_name, Vector3.ZERO)
		if action_pose.has(bone_name):
			e = e.lerp(action_pose[bone_name], action_weight)
		if e != Vector3.ZERO:
			_rotate_global(bone_name, _char_quat(e))

	_update_look(delta)


## Clip-driven body: pick locomotion unless an action clip is running, advance, then layer overlays.
func _update_clips(delta: float) -> void:
	if force_clip != "":
		_play_loop(force_clip, 0.25, force_speed)
	elif _time >= _action_clip_until:
		if not grounded:
			_play_loop(AIR_CLIP, 0.2, 1.0)
		elif move_speed < 0.3:
			_play_loop(IDLE_CLIP, 0.25, 1.0)
		else:
			var pick: Array = LOCOMOTION[0]
			for entry in LOCOMOTION:
				if move_speed >= float(entry[1]) * 0.75:
					pick = entry
			_play_loop(pick[0], 0.2, clampf(move_speed / float(pick[1]), 0.7, 1.6))

	if anim_player.is_playing():
		anim_player.advance(delta)
	elif _hold_clip != "":
		# Finished one-shot that should stay on its last frame (e.g. knocked down).
		anim_player.play(_hold_clip)
		anim_player.seek(clip_length(_hold_clip), true)
	if model != null:
		model.position = body_offset

	for bone_name in POSE_ORDER:
		if action_weight > 0.001 and action_pose.has(bone_name) and _bones.has(bone_name):
			_rotate_global(bone_name, Quaternion.IDENTITY.slerp(_char_quat(action_pose[bone_name]), action_weight))
	_update_look(delta)


func _play_loop(clip: String, blend: float, speed: float) -> void:
	if not anim_player.has_animation(clip):
		return
	if clip != _current_clip or not anim_player.is_playing():
		anim_player.play(clip, blend)
		_current_clip = clip
	anim_player.speed_scale = speed


## Procedural walk/run cycle in the same pitch/yaw/roll convention as action_pose.
func _locomotion_pose(delta: float) -> Dictionary:
	var amp := clampf(move_speed / 6.0, 0.0, 1.0) * (1.0 - 0.8 * action_weight)
	if amp > 0.01:
		_stride += delta * lerpf(5.0, 11.0, clampf(move_speed / 8.0, 0.0, 1.0))
	var s := sin(_stride)
	var c := cos(_stride)
	var bob := -(0.5 - 0.5 * cos(_stride * 2.0)) * 0.04 * amp
	if model != null:
		model.position = model.position.lerp(Vector3(0, bob, 0) + body_offset, 1.0 - exp(-20.0 * delta))
	if not grounded:
		return {
			"LeftUpperLeg": Vector3(45, 0, 0), "LeftLowerLeg": Vector3(-80, 0, 0),
			"RightUpperLeg": Vector3(15, 0, 0), "RightLowerLeg": Vector3(-40, 0, 0),
			"LeftUpperArm": Vector3(-20, 0, 25), "RightUpperArm": Vector3(-20, 0, -25),
		}
	return {
		"Spine": Vector3(-8.0 * amp, s * 4.0 * amp, 0),
		"Chest": Vector3(0, s * 6.0 * amp, 0),
		"LeftUpperLeg": Vector3(s * 35.0 * amp, 0, 0),
		"RightUpperLeg": Vector3(-s * 35.0 * amp, 0, 0),
		"LeftLowerLeg": Vector3(-maxf(c, 0.0) * 60.0 * amp, 0, 0),
		"RightLowerLeg": Vector3(-maxf(-c, 0.0) * 60.0 * amp, 0, 0),
		"LeftUpperArm": Vector3(-s * 30.0 * amp, 0, 0),
		"RightUpperArm": Vector3(s * 30.0 * amp, 0, 0),
		"LeftLowerArm": Vector3(30.0 * amp, 0, 0),
		"RightLowerArm": Vector3(30.0 * amp, 0, 0),
	}


func _char_quat(e: Vector3) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(e.y)) * Quaternion(_right, deg_to_rad(e.x)) * Quaternion(_forward, deg_to_rad(e.z))


## Head look-at, split between neck and head, clamped to a natural range.
func _update_look(delta: float) -> void:
	var want := Vector2.ZERO
	if look_target != null and is_instance_valid(look_target) and _bones.has("Head"):
		var head_pos := skeleton.get_bone_global_pose(_bones["Head"]).origin
		# Characters are aimed at head height; cameras are already at eye level.
		var aim := look_target.global_position
		if not look_target is Camera3D:
			aim += Vector3.UP * 1.4
		var to_target := (skeleton.global_transform.affine_inverse() * aim - head_pos).normalized()
		var flat := Vector3(to_target.x, 0.0, to_target.z).normalized()
		var yaw := _forward.signed_angle_to(flat, Vector3.UP)
		if absf(yaw) < 1.6:
			want = Vector2(clampf(yaw, -0.7, 0.7), clampf(asin(to_target.y), -0.35, 0.35))
	_look = _look.lerp(want, 1.0 - exp(-4.0 * delta))
	# Pitch about the right axis tilts upright bones back, so +y (target above) looks up.
	var look_q := Quaternion(Vector3.UP, _look.x) * Quaternion(_right, _look.y)
	if _bones.has("Neck"):
		_rotate_global("Neck", Quaternion.IDENTITY.slerp(look_q, 0.4))
		_rotate_global("Head", Quaternion.IDENTITY.slerp(look_q, 0.6))
	else:
		_rotate_global("Head", look_q)


func _rotate_global(bone_name: String, q: Quaternion) -> void:
	if _bones.has(bone_name):
		_rotate_global_idx(_bones[bone_name], q)


## Applies a rotation expressed in skeleton space on top of the bone's current pose.
func _rotate_global_idx(bone: int, q: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_q := Quaternion.IDENTITY
	if parent >= 0:
		parent_q = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var global_q := parent_q * skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (parent_q.inverse() * q * global_q).normalized())


func _update_face(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.0)
	_blink = maxf(_blink - delta * 7.0, 0.0)
	# Triangle wave: close then open over ~0.15s.
	var blink_weight := 1.0 - absf(_blink * 2.0 - 1.0) if _blink > 0.0 else 0.0

	for expr in _expression_weights:
		var target: float = expression_targets.get(expr, 0.0)
		_expression_weights[expr] = lerpf(_expression_weights[expr], target, 1.0 - exp(-10.0 * delta))
	if _expression_weights.has("blink"):
		# Happy/relaxed faces already close the eyes into arcs; don't blink over them.
		var closed: float = _expression_weights.get("happy", 0.0) + _expression_weights.get("relaxed", 0.0)
		_expression_weights["blink"] = blink_weight * (1.0 - clampf(closed, 0.0, 1.0))

	for entry in _touched_shapes:
		(entry[0] as MeshInstance3D).set_blend_shape_value(entry[1], 0.0)
	for expr in _expression_shapes:
		var w: float = _expression_weights[expr]
		if w <= 0.001:
			continue
		for s in _expression_shapes[expr]:
			var mesh := s[0] as MeshInstance3D
			var idx: int = s[1]
			mesh.set_blend_shape_value(idx, clampf(mesh.get_blend_shape_value(idx) + s[2] * w, 0.0, 1.0))
