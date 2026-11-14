extends Node3D
## Animated pedestrian body: the animation pack's rigged mannequin with both clip libraries,
## cel-shaded clothes / skin colors and a simple anime hairdo attached to the head bone.
## Faces +Z.

const Toon := preload("res://scripts/toon.gd")
const UAL1 := preload("res://assets/animations/ual1/UAL1_Standard.glb")
const UAL2 := preload("res://assets/animations/ual2/UAL2_Standard.glb")

const HAIR_STYLES := ["short", "bob", "ponytail", "long"]
## Middle of the mannequin's head in model space (tuned against a close-up render).
const HEAD_CENTER := Vector3(0, 1.71, 0.0)

var outfit := Color(0.4, 0.5, 0.8)
var skin := Color(0.98, 0.85, 0.76)
var hair := Color(0.2, 0.16, 0.18)
var hair_style := "short"

var anim: AnimationPlayer
var _current := ""
var _once_until := 0.0
var _after := ""
var _time := 0.0


func _ready() -> void:
	var body: Node3D = UAL1.instantiate()
	add_child(body)
	anim = body.find_children("*", "AnimationPlayer", true, false)[0]
	var other: Node = UAL2.instantiate()
	var other_anim: AnimationPlayer = other.find_children("*", "AnimationPlayer", true, false)[0]
	anim.add_animation_library("ual2", other_anim.get_animation_library(""))
	other.free()
	for clip in ["ual1/Idle", "ual1/Walk", "ual1/Jog_Fwd", "ual1/Sprint", "ual1/Idle_Talking", "ual1/Sitting_Idle", "ual1/Crouch_Idle", "ual2/Idle_TalkingPhone"]:
		if anim.has_animation(_name(clip)):
			anim.get_animation(_name(clip)).loop_mode = Animation.LOOP_LINEAR

	var mesh: MeshInstance3D = body.find_children("*", "MeshInstance3D", true, false)[0]
	mesh.set_surface_override_material(0, Toon.material(outfit, false))
	if mesh.mesh.get_surface_count() > 1:
		mesh.set_surface_override_material(1, Toon.material(skin, false))
	_build_hair(body.find_children("*", "Skeleton3D", true, false)[0])
	play("ual1/Idle")


## Hair and eyes are laid out in model space (+Z forward) around the head, then converted into the
## head bone's space so they follow the animation whatever the bone's axes are.
func _build_hair(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone("Head")
	if bone < 0:
		return
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	skeleton.add_child(head)
	var rest := global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(bone)
	var to_bone := Transform3D(rest.basis.orthonormalized(), rest.origin).affine_inverse()
	var c := HEAD_CENTER
	# Skin-toned face over the mannequin's own (outfit-coloured) head, hair cap set back over it.
	_part(head, to_bone, Toon.sphere(0.118), skin, c, Vector3(0.98, 1.5, 1.16))
	_part(head, to_bone, Toon.sphere(0.13), hair, c + Vector3(0, 0.085, -0.035), Vector3(1.04, 1.0, 1.05))
	match hair_style:
		"bob":
			_part(head, to_bone, Toon.sphere(0.14), hair, c + Vector3(0, 0.025, -0.045), Vector3(1.1, 1.05, 1.0))
		"ponytail":
			_part(head, to_bone, Toon.capsule(0.05, 0.34), hair, c + Vector3(0, -0.025, -0.17), Vector3.ONE, Vector3(0.35, 0, 0))
		"long":
			_part(head, to_bone, Toon.box(Vector3(0.25, 0.4, 0.08)), hair, c + Vector3(0, -0.075, -0.1), Vector3.ONE, Vector3(0.1, 0, 0))
	_part(head, to_bone, Toon.box(Vector3(0.21, 0.05, 0.05)), hair, c + Vector3(0, 0.115, 0.105), Vector3.ONE, Vector3(-0.5, 0, 0))
	for side in [-1.0, 1.0]:
		_part(head, to_bone, Toon.sphere(0.02), Color(0.08, 0.06, 0.1), c + Vector3(side * 0.042, 0.015, 0.125), Vector3(0.8, 1.35, 0.4))
		_part(head, to_bone, Toon.sphere(0.007), Color.WHITE, c + Vector3(side * 0.042 + 0.006, 0.029, 0.133), Vector3.ONE)


func _part(head: Node3D, to_bone: Transform3D, mesh: Mesh, color: Color, pos: Vector3, scale_by: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(color, false)
	mi.transform = to_bone * Transform3D(Basis.from_euler(rot).scaled(scale_by), pos)
	head.add_child(mi)


## Clips use the heroine's "ual1/..." / "ual2/..." names; UAL1 is this player's default library.
static func _name(clip: String) -> String:
	return clip.substr(5) if clip.begins_with("ual1/") else clip


## Loops `clip` (crossfading); ignored while a one-shot is playing unless `force`.
func play(clip: String, speed := 1.0, force := false) -> void:
	if (not force and _time < _once_until) or not anim.has_animation(_name(clip)):
		return
	if clip != _current or force:
		anim.play(_name(clip), 0.2)
		_current = clip
	anim.speed_scale = speed


## Plays `clip` once, then loops `after`; returns the clip's duration.
func play_once(clip: String, after := "ual1/Idle", speed := 1.0, hold := false) -> float:
	if not anim.has_animation(_name(clip)):
		return 0.0
	anim.play(_name(clip), 0.12)
	anim.speed_scale = speed
	_current = clip
	var length := anim.get_animation(_name(clip)).length / speed
	_once_until = INF if hold else _time + length
	_after = after
	return length


func release() -> void:
	_once_until = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _once_until != INF and _once_until > 0.0 and _time >= _once_until:
		_once_until = 0.0
		play(_after, 1.0, true)
