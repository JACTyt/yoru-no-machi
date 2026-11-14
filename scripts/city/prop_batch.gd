extends RefCounted
## Collects many copies of a few unit meshes and emits one MultiMesh per group, so thousands of
## street props cost a handful of draw calls. Instance colors tint materials with `vertex_color`.

const Toon := preload("res://scripts/toon.gd")

var _groups := {}


## Registers a group once; later `add` calls refer to it by key.
func define(key: String, mesh: Mesh, material: Material, cast_shadow := true) -> void:
	_groups[key] = {"mesh": mesh, "material": material, "shadow": cast_shadow,
		"xforms": [], "colors": PackedColorArray()}


func add(key: String, xform: Transform3D, color := Color.WHITE) -> void:
	var g: Dictionary = _groups[key]
	g["xforms"].append(xform)
	g["colors"].append(color)


## Unit mesh scaled to `size`, rotated by `yaw` and centered at `center`.
func box(key: String, center: Vector3, size: Vector3, color := Color.WHITE, yaw := 0.0) -> void:
	add(key, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center), color)


## Unit cylinder (or any Y-aligned unit mesh) stretched between two points.
func segment(key: String, a: Vector3, b: Vector3, radius: float, color := Color.WHITE) -> void:
	var axis := b - a
	var side := axis.cross(Vector3.UP if absf(axis.normalized().y) < 0.9 else Vector3.RIGHT).normalized()
	var other := side.cross(axis).normalized()
	add(key, Transform3D(Basis(side * radius * 2.0, axis, other * radius * 2.0), (a + b) * 0.5), color)


func build(parent: Node3D) -> Dictionary:
	var out := {}
	for key in _groups:
		var g: Dictionary = _groups[key]
		var xforms: Array = g["xforms"]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = g["mesh"]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, g["colors"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key
		mmi.multimesh = mm
		mmi.material_override = g["material"]
		if not g["shadow"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		out[key] = mmi
	_groups.clear()
	return out


## Toon material tinted per instance.
static func tinted(emission := 0.0) -> ShaderMaterial:
	var mat := Toon.material(Color.WHITE, false)
	mat.set_shader_parameter("vertex_color", true)
	mat.set_shader_parameter("color_emission", emission)
	return mat
