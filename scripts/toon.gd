extends RefCounted
## Helpers for building cel-shaded, outlined meshes in code.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")


static func material(color: Color, outline := true, thickness := 0.03, box_hull := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", color)
	if outline:
		var line := ShaderMaterial.new()
		line.shader = OUTLINE_SHADER
		line.set_shader_parameter("thickness", thickness)
		line.set_shader_parameter("box_hull", 1.0 if box_hull else 0.0)
		mat.next_pass = line
	return mat


static func add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, outline := true, thickness := 0.03) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, outline, thickness, mesh is BoxMesh)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return m
