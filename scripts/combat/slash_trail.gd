extends MeshInstance3D
## Ribbon trail swept by a limb: a fading triangle strip from the limb out along its direction.

const LIFETIME := 0.16
const MAX_POINTS := 28

var skel: Skeleton3D
var color := Color(0.6, 0.85, 1.0)
var length := 0.4
var emitting := false

var _bone := -1
var _parent_bone := -1
var _points: Array = [] ## [base: Vector3, tip: Vector3, age: float]
var _mesh: ImmediateMesh


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	material_override = mat


func attach(skel_in: Skeleton3D, bone_name: String, trail_color: Color) -> void:
	skel = skel_in
	color = trail_color
	_bone = skel_in.find_bone(bone_name) if skel_in != null else -1
	_parent_bone = skel_in.get_bone_parent(_bone) if _bone >= 0 else -1


func _process(delta: float) -> void:
	for p in _points:
		p[2] += delta
	while not _points.is_empty() and _points[0][2] > LIFETIME:
		_points.pop_front()

	if emitting and _bone >= 0 and _parent_bone >= 0:
		var xf := skel.global_transform
		var a := xf * skel.get_bone_global_pose(_bone).origin
		var b := xf * skel.get_bone_global_pose(_parent_bone).origin
		var dir := (a - b).normalized()
		_points.append([a - dir * 0.1, a + dir * length, 0.0])
		if _points.size() > MAX_POINTS:
			_points.pop_front()

	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _points:
		var f: float = 1.0 - p[2] / LIFETIME
		_mesh.surface_set_color(Color(color, f * 0.5))
		_mesh.surface_add_vertex(p[0])
		_mesh.surface_set_color(Color(color.lightened(0.6), f))
		_mesh.surface_add_vertex(p[1])
	_mesh.surface_end()
