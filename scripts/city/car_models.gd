extends RefCounted
## Procedural car bodies: cross-sections lofted along the car with wheel arches cut in, a glass
## greenhouse with a painted roof, and lights / plates / mirrors as trim. Car-local space: +Z is
## forward, y = 0 is the road surface.

const Toon := preload("res://scripts/toon.gd")

## body: [z, bottom_y, top_y, half_width] front to rear (interpolated, so a few keys suffice).
## cabin: [z, bottom_y, top_y, half_width_bottom, half_width_top]; segment indices in "roof" are
## painted, the others are glass. "base" inherits every key not overridden.
const MODELS := {
	"sedan": {
		"mass": 1200.0, "power": 3200.0, "top_speed": 45.0,
		"wheel_radius": 0.33, "wheelbase": 2.7, "track": 0.78,
		"body": [[2.3, 0.34, 0.6, 0.8], [2.22, 0.26, 0.74, 0.87], [1.9, 0.24, 0.8, 0.89], [1.05, 0.24, 0.9, 0.9],
			[-1.2, 0.24, 0.94, 0.9], [-1.95, 0.24, 0.95, 0.88], [-2.22, 0.27, 0.9, 0.85], [-2.3, 0.36, 0.78, 0.8]],
		"cabin": [[1.05, 0.88, 0.9, 0.84, 0.83], [0.2, 0.92, 1.4, 0.85, 0.7], [-0.85, 0.93, 1.4, 0.85, 0.7], [-1.75, 0.94, 0.96, 0.84, 0.82]],
		"roof": [1],
	},
	"compact": {
		"mass": 900.0, "power": 2500.0, "top_speed": 38.0, "electric": true,
		"wheel_radius": 0.29, "wheelbase": 2.3, "track": 0.66,
		"body": [[1.75, 0.34, 0.62, 0.7], [1.68, 0.26, 0.76, 0.76], [1.4, 0.25, 0.84, 0.77], [0.95, 0.25, 0.92, 0.78],
			[-1.55, 0.25, 0.98, 0.78], [-1.72, 0.3, 0.96, 0.76], [-1.75, 0.4, 0.9, 0.72]],
		"cabin": [[0.95, 0.9, 0.92, 0.74, 0.73], [0.15, 0.93, 1.55, 0.75, 0.66], [-1.45, 0.96, 1.55, 0.75, 0.66], [-1.7, 0.97, 1.0, 0.73, 0.7]],
		"roof": [1],
	},
	"coupe": {
		"mass": 1250.0, "power": 4400.0, "top_speed": 56.0,
		"wheel_radius": 0.33, "wheelbase": 2.6, "track": 0.8,
		"body": [[2.2, 0.3, 0.52, 0.82], [2.12, 0.22, 0.64, 0.9], [1.6, 0.21, 0.72, 0.92], [0.75, 0.21, 0.8, 0.93],
			[-1.3, 0.21, 0.84, 0.95], [-2.05, 0.22, 0.84, 0.92], [-2.2, 0.3, 0.76, 0.86]],
		"cabin": [[0.75, 0.78, 0.8, 0.88, 0.87], [-0.15, 0.82, 1.18, 0.88, 0.68], [-0.7, 0.83, 1.18, 0.88, 0.68], [-1.95, 0.84, 0.86, 0.88, 0.84]],
		"roof": [1],
	},
	"van": {
		"mass": 1600.0, "power": 3300.0, "top_speed": 38.0,
		"wheel_radius": 0.32, "wheelbase": 2.9, "track": 0.76,
		"body": [[2.35, 0.36, 0.7, 0.8], [2.28, 0.28, 0.95, 0.85], [2.05, 0.27, 1.05, 0.86], [-2.25, 0.27, 1.1, 0.86], [-2.35, 0.36, 1.05, 0.82]],
		"cabin": [[2.05, 1.03, 1.06, 0.83, 0.82], [1.35, 1.08, 1.92, 0.84, 0.76], [-2.2, 1.1, 1.92, 0.84, 0.76], [-2.32, 1.1, 1.85, 0.82, 0.76]],
		"roof": [1],
	},
	"taxi": {"base": "sedan", "taxi": true},
}

const GLASS := Color(0.05, 0.07, 0.12)
const TRIM := Color(0.09, 0.09, 0.11)
const ARCH_CLEARANCE := 0.09
const STATION_STEP := 0.08


static func spec(model: String) -> Dictionary:
	var s: Dictionary = MODELS.get(model, MODELS["sedan"]).duplicate()
	if s.has("base"):
		var merged: Dictionary = MODELS[s["base"]].duplicate()
		merged.merge(s, true)
		s = merged
	return s


## Adds the body meshes under `car` and returns {"brake": material, "size": Vector3, "top": float}.
static func build(car: Node3D, s: Dictionary, color: Color) -> Dictionary:
	var paint := Toon.material(color, false)
	paint.set_shader_parameter("surface", 4)
	paint.set_shader_parameter("gloss", 0.8)
	paint.set_shader_parameter("rim_strength", 0.35)
	var glass := Toon.material(GLASS, false)
	glass.set_shader_parameter("surface", 5)
	glass.set_shader_parameter("gloss", 1.0)
	var trim := Toon.material(TRIM, false)

	var body_st := _tool()
	_loft([body_st], _body_rings(s), true, func(_i, _k): return 0)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_st.commit()
	body.material_override = paint
	car.add_child(body)

	var glass_st := _tool()
	var roof_st := _tool()
	var cabin: Array = s["cabin"]
	var rings := []
	for c in cabin:
		rings.append(PackedVector3Array([Vector3(-c[3], c[1], c[0]), Vector3(-c[4], c[2], c[0]), Vector3(c[4], c[2], c[0]), Vector3(c[3], c[1], c[0])]))
	var roof: Array = s["roof"]
	# Strip 1 is the top of the trapezoid; strip 3 (the bottom) is hidden inside the body.
	_loft([glass_st, roof_st], rings, false, func(i, k): return -1 if k == 3 else (1 if k == 1 and roof.has(i) else 0))
	var mesh: ArrayMesh = glass_st.commit()
	roof_st.commit(mesh)
	var greenhouse := MeshInstance3D.new()
	greenhouse.name = "Cabin"
	greenhouse.mesh = mesh
	greenhouse.set_surface_override_material(0, glass)
	greenhouse.set_surface_override_material(1, paint)
	car.add_child(greenhouse)

	var keys: Array = s["body"]
	var nose: Array = keys[0]
	var front: Array = keys[1]
	var rear: Array = keys[keys.size() - 2]
	var tail: Array = keys[keys.size() - 1]

	var head := Toon.material(Color(1.0, 0.98, 0.9), false)
	head.set_shader_parameter("emission", Color(1.0, 0.95, 0.8) * 0.7)
	var brake := Toon.material(Color(0.75, 0.08, 0.12), false)
	brake.set_shader_parameter("emission", Color(0.6, 0.04, 0.08) * 0.5)
	var plate := Toon.material(Color(0.95, 0.95, 0.88), false)
	for sx in [-1.0, 1.0]:
		_trim(car, Vector3(0.36, 0.11, 0.12), Vector3(sx * (front[3] - 0.24), front[2] - 0.1, front[0] - 0.02), head)
		_trim(car, Vector3(0.4, 0.13, 0.1), Vector3(sx * (rear[3] - 0.24), rear[2] - 0.1, rear[0] + 0.02), brake)
		var c0: Array = cabin[0]
		_trim(car, Vector3(0.16, 0.1, 0.12), Vector3(sx * (c0[3] + 0.08), c0[1] + 0.06, c0[0] - 0.25), paint)
	_trim(car, Vector3(nose[3] * 0.9, 0.14, 0.06), Vector3(0, (nose[1] + nose[2]) * 0.5 - 0.02, nose[0]), trim)
	_trim(car, Vector3(0.42, 0.12, 0.03), Vector3(0, nose[1] + 0.03, nose[0] + 0.02), plate)
	_trim(car, Vector3(0.42, 0.12, 0.03), Vector3(0, tail[1] + 0.12, tail[0] - 0.02), plate)

	var top := 0.0
	var half_width := 0.0
	for c in cabin:
		top = maxf(top, c[2])
	for k in keys:
		half_width = maxf(half_width, k[3])
	if s.get("taxi", false):
		var lamp := Toon.material(Color(1.0, 0.7, 0.2), false)
		lamp.set_shader_parameter("emission", Color(1.0, 0.6, 0.15) * 0.8)
		var z: float = (cabin[1][0] + cabin[2][0]) * 0.5
		_trim(car, Vector3(0.55, 0.2, 0.24), Vector3(0, top + 0.1, z), lamp)
		for dir in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = "TAXI"
			label.font_size = 28
			label.pixel_size = 0.005
			label.outline_size = 6
			label.modulate = Color(0.15, 0.08, 0.02)
			label.outline_modulate = Color(1.0, 0.85, 0.5)
			label.position = Vector3(0, top + 0.1, z + dir * 0.125)
			label.rotation.y = 0.0 if dir > 0.0 else PI
			car.add_child(label)
		top += 0.2
	return {"brake": brake, "size": Vector3(half_width * 2.0, top, nose[0] - tail[0]), "top": top}


static func _tool() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _trim(car: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Toon.box(size)
	mi.material_override = mat
	mi.position = pos
	car.add_child(mi)


## Samples the body keys every few centimetres and raises the bottom edge into wheel arches.
static func _body_rings(s: Dictionary) -> Array:
	var keys: Array = s["body"]
	var r: float = s["wheel_radius"]
	var arch_r := r + ARCH_CLEARANCE
	var arch_y := r + 0.04
	var z_front: float = keys[0][0]
	var z_rear: float = keys[keys.size() - 1][0]
	var steps := int((z_front - z_rear) / STATION_STEP)
	var rings := []
	for i in steps + 1:
		var z := lerpf(z_front, z_rear, float(i) / steps)
		var k := _interp(keys, z)
		var bottom := k[0]
		for wz in [s["wheelbase"] * 0.5, -s["wheelbase"] * 0.5]:
			var dz: float = z - wz
			if absf(dz) < arch_r:
				bottom = maxf(bottom, arch_y + sqrt(arch_r * arch_r - dz * dz))
		bottom = minf(bottom, k[1] - 0.06)
		rings.append(_section(z, bottom, k[1], k[2]))
	return rings


## Linear interpolation of [bottom, top, half_width] between the keys bracketing z.
static func _interp(keys: Array, z: float) -> PackedFloat32Array:
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if z <= a[0] and z >= b[0]:
			var t: float = (a[0] - z) / maxf(a[0] - b[0], 0.0001)
			return PackedFloat32Array([lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)])
	var last: Array = keys[keys.size() - 1]
	return PackedFloat32Array([last[1], last[2], last[3]])


## Octagonal cross-section: tucked-in sill, vertical flanks, rounded shoulders, flat top.
static func _section(z: float, b: float, t: float, hw: float) -> PackedVector3Array:
	var h := t - b
	var rr := minf(0.14, h * 0.35)
	return PackedVector3Array([
		Vector3(-hw * 0.93, b, z), Vector3(-hw, b + h * 0.3, z), Vector3(-hw, t - rr, z), Vector3(-hw + rr * 1.5, t, z),
		Vector3(hw - rr * 1.5, t, z), Vector3(hw, t - rr, z), Vector3(hw, b + h * 0.3, z), Vector3(hw * 0.93, b, z)])


## Skins consecutive rings. `pick(segment, strip)` returns the SurfaceTool index or -1 to skip.
## Normals are hard across strips (crisp shoulders) and smoothed along the car.
static func _loft(tools: Array, rings: Array, smooth: bool, pick: Callable) -> void:
	var n: int = rings[0].size()
	var last := rings.size() - 2
	for k in n:
		var k2 := (k + 1) % n
		var faces: Array[Vector3] = []
		for i in rings.size() - 1:
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][k2]
			var nrm := (d - a).cross(b - c)
			var mid := (a + b + c + d) * 0.25
			var center := _center(rings[i])
			center.z = mid.z
			if nrm.dot(mid - center) < 0.0:
				nrm = -nrm
			faces.append(nrm.normalized())
		for i in rings.size() - 1:
			var tool_i: int = pick.call(i, k)
			if tool_i < 0:
				continue
			var n0 := faces[i]
			var n1 := faces[i]
			if smooth:
				n0 = (faces[maxi(i - 1, 0)] + faces[i]).normalized()
				n1 = (faces[i] + faces[mini(i + 1, last)]).normalized()
			var st: SurfaceTool = tools[tool_i]
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][k2]
			_tri(st, a, b, c, n0, n0, n1, faces[i])
			_tri(st, b, d, c, n0, n1, n1, faces[i])
	# End caps (fans), using the first tool.
	var st0: SurfaceTool = tools[0]
	for end in [0, rings.size() - 1]:
		var ring: PackedVector3Array = rings[end]
		var c := _center(ring)
		var outward := Vector3(0, 0, 1) if end == 0 else Vector3(0, 0, -1)
		for k in n:
			_tri(st0, c, ring[k], ring[(k + 1) % n], outward, outward, outward, outward)


static func _center(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / ring.size()


## Emits a triangle wound clockwise as seen from the `outward` side (Godot's front face).
static func _tri(st: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, np: Vector3, nq: Vector3, nr: Vector3, outward: Vector3) -> void:
	if (q - p).cross(r - p).dot(outward) > 0.0:
		var t := q
		q = r
		r = t
		var tn := nq
		nq = nr
		nr = tn
	st.set_normal(np)
	st.add_vertex(p)
	st.set_normal(nq)
	st.add_vertex(q)
	st.set_normal(nr)
	st.add_vertex(r)
