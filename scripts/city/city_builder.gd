extends Node3D
## Procedural anime city: asphalt grid with lane markings and zebra crossings, paved sidewalks,
## glass towers downtown, offices, apartment blocks with balconies and small shops further out,
## street furniture (utility poles and sagging wires, lamps, trees, vending machines), parks and
## traffic signals that cycle per axis. Left-hand traffic.

const Toon := preload("res://scripts/toon.gd")
const PropBatch := preload("res://scripts/city/prop_batch.gd")
const Icons := preload("res://scripts/ui/icons.gd")

const BLOCKS := 6
const BLOCK_SIZE := 40.0
const ROAD_WIDTH := 14.0
const CELL := BLOCK_SIZE + ROAD_WIDTH
const HALF_ROAD := ROAD_WIDTH * 0.5
## Road lines run at k * CELL for |k| <= GRID; k = ±GRID is the ring road around the blocks.
const GRID := 3
const EXTENT := GRID * CELL + HALF_ROAD
const OUTER_WALK := 7.0
const WORLD_HALF := 230.0
const CURB_H := 0.15
const SIDEWALK := 3.5
## Lateral offsets from a road's centerline.
const LANE_OFFSET := 3.0
const PARK_OFFSET := 5.7
const EDGE_LINE := 4.7
const PROP_LINE := HALF_ROAD + 0.7
## Distance from an intersection center to its stop lines.
const STOP_LINE := 12.0
const GROUND_H := 3.8
const FLOOR_H := 3.5
## Width of the invisible collision ramp along every curb, so walking and driving over it is smooth.
const CURB_RAMP := 0.7

## Enterable places. "block" indexes the 6x6 grid, "lot" the block quarter ([0, 0] = whole block),
## "front" is the street side with the door.
const LANDMARKS := {
	"home": {"name": "Home", "block": [3, 3], "lot": [-1, -1], "front": Vector3(0, 0, -1), "kind": "apartment", "color": Color(1.0, 0.55, 0.72)},
	"konbini": {"name": "24H Mart", "block": [2, 3], "lot": [1, -1], "front": Vector3(0, 0, -1), "kind": "shop", "color": Color(0.35, 0.75, 1.0)},
	"boutique": {"name": "Lumiere Boutique", "block": [2, 3], "lot": [-1, -1], "front": Vector3(0, 0, -1), "kind": "shop", "color": Color(1.0, 0.55, 0.85)},
	"pharmacy": {"name": "Pharmacy", "block": [3, 2], "lot": [-1, 1], "front": Vector3(-1, 0, 0), "kind": "shop", "color": Color(0.35, 0.95, 0.55)},
	"car_rental": {"name": "Rent-a-Car", "block": [4, 3], "lot": [-1, -1], "front": Vector3(0, 0, -1), "kind": "shop", "color": Color(1.0, 0.68, 0.22)},
	"school": {"name": "Hoshimachi High", "block": [1, 4], "lot": [0, 0], "front": Vector3(1, 0, 0), "kind": "school", "color": Color(0.5, 0.68, 1.0)},
	"university": {"name": "Hoshimachi University", "block": [3, 0], "lot": [0, 0], "front": Vector3(0, 0, 1), "kind": "university", "color": Color(0.82, 0.55, 1.0)},
}

## [seconds, x-axis state, z-axis state]; 0 green, 1 yellow, 2 red.
const SIGNAL_PHASES := [[11.0, 0, 2], [2.5, 1, 2], [1.5, 2, 2], [11.0, 2, 0], [2.5, 2, 1], [1.5, 2, 2]]
const LAMP_COLORS := [Color(0.2, 1.0, 0.65), Color(1.0, 0.75, 0.15), Color(1.0, 0.2, 0.18)]

const OFFICE_COLORS := [Color(0.82, 0.84, 0.88), Color(0.75, 0.85, 1.0), Color(0.9, 0.86, 0.8), Color(0.7, 0.74, 0.82), Color(0.95, 0.95, 0.97)]
const APARTMENT_COLORS := [Color(0.97, 0.95, 0.9), Color(0.92, 0.88, 0.82), Color(0.85, 0.9, 0.95), Color(0.98, 0.86, 0.84), Color(0.9, 0.93, 0.86)]
const SHOP_COLORS := [Color(0.98, 0.78, 0.82), Color(1.0, 0.93, 0.75), Color(0.8, 0.95, 0.85), Color(0.88, 0.8, 1.0), Color(0.72, 0.55, 0.45), Color(0.95, 0.95, 0.97)]
const GLASS_TINTS := [Color(0.75, 0.9, 1.0), Color(0.7, 1.0, 0.95), Color(0.9, 0.9, 1.0), Color(1.0, 0.92, 0.85)]
const SIGN_COLORS := [Color(1.0, 0.35, 0.5), Color(0.25, 0.75, 1.0), Color(1.0, 0.8, 0.25), Color(0.4, 0.95, 0.6), Color(0.85, 0.45, 1.0), Color(1.0, 0.55, 0.25)]
const SHOP_SIGNS := ["RAMEN", "CAFE", "KARAOKE", "BOOKS", "24H MART", "BAKERY", "LAUNDRY", "SUSHI", "GAMES", "FLOWERS", "PHARMACY", "BAR", "IZAKAYA", "CURRY", "RECORDS", "DONUTS"]
const BILLBOARDS := ["SUMMER FEST", "IDOL LIVE", "NEW SINGLE", "SODA POP", "AURORA", "NIGHT RUN", "STARLIGHT"]
const VENDING_COLORS := [Color(0.9, 0.15, 0.2), Color(0.95, 0.95, 0.97), Color(0.15, 0.35, 0.85), Color(0.2, 0.6, 0.35)]

const MARK := Color(0.93, 0.92, 0.88)
const POLE := Color(0.62, 0.62, 0.6)
const METAL := Color(0.33, 0.36, 0.4)
const WIRE := Color(0.1, 0.1, 0.12)
const TRUNK := Color(0.45, 0.32, 0.25)
const SAKURA := Color(1.0, 0.74, 0.84)

## Petrol ("gas") and EV charging stations taking a block quarter, like LANDMARKS.
const STATIONS := {
	"gas_central": {"name": "Hoshi Petrol", "kind": "gas", "block": [2, 2], "lot": [1, 1], "front": Vector3(1, 0, 0)},
	"gas_kitano": {"name": "Kitano Fuel", "kind": "gas", "block": [5, 1], "lot": [-1, 1], "front": Vector3(0, 0, 1)},
	"ev_central": {"name": "Volt Charge", "kind": "ev", "block": [4, 2], "lot": [-1, 1], "front": Vector3(-1, 0, 0)},
	"ev_west": {"name": "Volt Charge West", "kind": "ev", "block": [0, 3], "lot": [1, -1], "front": Vector3(0, 0, -1)},
}
## [name, block, street side, offset along the block edge]
const BUS_STOPS := [
	["Central Station", [2, 2], Vector3(0, 0, 1), -12.0],
	["Kitano Heights", [4, 1], Vector3(0, 0, 1), 0.0],
	["Sakuragaoka", [1, 1], Vector3(0, 0, 1), 0.0],
	["Minatomachi", [4, 4], Vector3(0, 0, -1), 4.0],
	["Old Town", [1, 3], Vector3(1, 0, 0), 0.0],
	["Hoshimachi High", [2, 4], Vector3(-1, 0, 0), 0.0],
	["University Gate", [3, 1], Vector3(0, 0, -1), 0.0],
	["Harbor Ring", [5, 4], Vector3(1, 0, 0), 0.0],
]

## id -> {name, kind, color, door (street point outside), front, park (Transform3D for a car)}
var places := {}
## Footprints for the map: [{"rect": Rect2 (world x/z), "kind": "building" | "park" | "yard"}].
var map_features := []
## id -> {name, kind ("gas" | "ev"), color, center (refuel zone), front}
var stations := {}
## [{"name", "pos" (waiting spot), "front"}]
var bus_stops := []
## Benches the heroine can sit on: [{"pos", "yaw"}]
var seats := []
## Vending machines: [{"pos" (standing spot), "front"}]
var vending_machines := []
var _icon_textures := {}

var _static: StaticBody3D
var _props := PropBatch.new()
var _mats := {}
var _lamp_mats := {}
var _phase := 0
var _phase_t := 0.0
var _rng := RandomNumberGenerator.new()


static func lane_left(dir: Vector3) -> Vector3:
	return Vector3(dir.z, 0, -dir.x)


static func in_grid(node: Vector3) -> bool:
	var limit := GRID * CELL + 1.0
	return absf(node.x) <= limit and absf(node.z) <= limit


static func district_name(pos: Vector3) -> String:
	if Vector2(pos.x, pos.z).length() < 70.0:
		return "Hoshimachi Central"
	if maxf(absf(pos.x), absf(pos.z)) > GRID * CELL - HALF_ROAD:
		return "Ring Road"
	if pos.z < 0.0:
		return "Kitano Heights" if pos.x >= 0.0 else "Sakuragaoka"
	return "Minatomachi" if pos.x >= 0.0 else "Old Town"


## 0 green, 1 yellow, 2 red for traffic travelling along `dir`.
func signal_state(dir: Vector3) -> int:
	return SIGNAL_PHASES[_phase][1 if absf(dir.x) > 0.5 else 2]


func _ready() -> void:
	_rng.seed = 1337
	_static = StaticBody3D.new()
	_static.name = "Collision"
	add_child(_static)
	_define_batches()
	_build_ground()
	for ix in BLOCKS:
		for iz in BLOCKS:
			_build_block(Vector3((ix - (BLOCKS - 1) / 2.0) * CELL, 0, (iz - (BLOCKS - 1) / 2.0) * CELL))
	_build_outskirts()
	_build_roads()
	_build_signals()
	for stop in BUS_STOPS:
		_bus_stop(stop)
	_props.build(self)
	_apply_signals()


func _process(delta: float) -> void:
	_phase_t += delta
	if _phase_t >= SIGNAL_PHASES[_phase][0]:
		_phase_t = 0.0
		_phase = (_phase + 1) % SIGNAL_PHASES.size()
		_apply_signals()


func _apply_signals() -> void:
	for axis in ["x", "z"]:
		var state: int = SIGNAL_PHASES[_phase][1 if axis == "x" else 2]
		for c in 3:
			var m: ShaderMaterial = _lamp_mats["sig_%s%d" % [axis, c]]
			var on := state == c
			m.set_shader_parameter("albedo", LAMP_COLORS[c] if on else LAMP_COLORS[c].darkened(0.8))
			m.set_shader_parameter("emission", LAMP_COLORS[c] * 2.5 if on else Color.BLACK)


# --- Shared resources -------------------------------------------------------------------------

func _define_batches() -> void:
	var cube := BoxMesh.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	var thin := CylinderMesh.new()
	thin.top_radius = 0.5
	thin.bottom_radius = 0.5
	thin.height = 1.0
	thin.radial_segments = 4
	thin.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 6
	_props.define("box", cube, PropBatch.tinted())
	_props.define("glow", cube, PropBatch.tinted(0.9))
	_props.define("paint", cube, PropBatch.tinted(0.15), false)
	_props.define("cyl", cyl, PropBatch.tinted())
	_props.define("wire", thin, PropBatch.tinted(), false)
	_props.define("leaves", ball, PropBatch.tinted(0.05))
	for axis in ["x", "z"]:
		for c in 3:
			var key := "sig_%s%d" % [axis, c]
			_lamp_mats[key] = Toon.material(LAMP_COLORS[c], false)
			_props.define(key, cyl, _lamp_mats[key], false)


func _mat(key: String, color: Color, surface := 0) -> ShaderMaterial:
	if not _mats.has(key):
		var m := Toon.material(color, false)
		m.set_shader_parameter("surface", surface)
		_mats[key] = m
	return _mats[key]


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _collider(center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	_static.add_child(shape)


## Raised slab (sidewalk, grass, path) with collision; `top` is its upper surface height.
## Collision is a frustum whose edges ramp up over CURB_RAMP, so the step is never felt.
func _slab(center: Vector3, size: Vector2, top: float, mat: Material) -> void:
	_mesh(Toon.box(Vector3(size.x, top, size.y)), mat, center + Vector3(0, top * 0.5, 0))
	var r := minf(CURB_RAMP, minf(size.x, size.y) * 0.25)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array([
		Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz),
		Vector3(-hx + r, top, -hz + r), Vector3(hx - r, top, -hz + r), Vector3(hx - r, top, hz - r), Vector3(-hx + r, top, hz - r)])
	var shape := CollisionShape3D.new()
	shape.shape = hull
	shape.position = center
	_static.add_child(shape)


func _label(text: String, pos: Vector3, facing: Vector3, size := 64, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.08, 0.04, 0.12)
	l.position = pos
	l.basis = Basis.looking_at(-facing, Vector3.UP)
	add_child(l)


# --- Ground, blocks, buildings ----------------------------------------------------------------

func _build_ground() -> void:
	_collider(Vector3(0, -0.5, 0), Vector3(WORLD_HALF * 2.0, 1.0, WORLD_HALF * 2.0))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (EXTENT + OUTER_WALK + 1.0) * 2.0
	_mesh(plane, _mat("asphalt", Color(0.3, 0.3, 0.35), 1), Vector3.ZERO)


func _build_block(center: Vector3) -> void:
	var dist := Vector2(center.x, center.z).length()
	_slab(center, Vector2.ONE * BLOCK_SIZE, CURB_H, _mat("paving", Color(0.76, 0.74, 0.78), 2))
	var base := center + Vector3(0, CURB_H, 0)
	var inner := BLOCK_SIZE * 0.5 - SIDEWALK
	var block := [roundi(center.x / CELL + (BLOCKS - 1) / 2.0), roundi(center.z / CELL + (BLOCKS - 1) / 2.0)]
	var lot_marks := {}
	for id in LANDMARKS:
		var lm: Dictionary = LANDMARKS[id]
		if lm["block"] != block:
			continue
		if lm["lot"] == [0, 0]:
			_landmark_block(id, center, base, inner)
			return
		lot_marks[lm["lot"]] = id
	for id in STATIONS:
		if STATIONS[id]["block"] == block:
			lot_marks[STATIONS[id]["lot"]] = id
	if lot_marks.is_empty() and dist < 80.0 and _rng.randf() < 0.5:
		_tower(base, inner * 2.0 - _rng.randf_range(1.0, 5.0))
		return
	if dist > 60.0 and _rng.randf() < 0.08:
		_park(base, inner * 2.0)
		return
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			var lot := base + Vector3(lx, 0, lz) * inner * 0.5
			if lot_marks.has([int(lx), int(lz)]):
				var id: String = lot_marks[[int(lx), int(lz)]]
				if STATIONS.has(id):
					_station(id, base, inner, lx, lz)
				else:
					_landmark_lot(id, center, base, inner, lx, lz)
				continue
			var r := _rng.randf()
			if dist > 50.0 and r < 0.08:
				_park(lot, inner)
				continue
			var front := Vector3(lx, 0, 0) if _rng.randf() < 0.5 else Vector3(0, 0, lz)
			var w := inner * _rng.randf_range(0.74, 0.95)
			var d := inner * _rng.randf_range(0.74, 0.95)
			# Flush with the sidewalk so streets read as continuous facades.
			var pos := base + Vector3(lx * (inner - w * 0.5), 0, lz * (inner - d * 0.5))
			var kind := ""
			if dist < 80.0:
				kind = "office" if r < 0.75 else "shop"
			elif dist < 125.0:
				kind = ["office", "apartment", "apartment", "shop", "shop"][_rng.randi() % 5]
			else:
				kind = ["apartment", "apartment", "shop", "shop", "shop"][_rng.randi() % 5]
			match kind:
				"office":
					_office(pos, Vector2(w, d), dist, front)
				"apartment":
					_apartment(pos, Vector2(w, d), front)
				"shop":
					_shop(pos, Vector2(w, d), front)


## Box building with the facade window shader; returns the wall material.
func _body(pos: Vector3, size: Vector3, color: Color, window_color: Color, store: Color) -> ShaderMaterial:
	var walls := Toon.add_mesh(self, Toon.box(size), color, pos + Vector3(0, size.y * 0.5, 0), true, 0.035)
	var mat := walls.material_override as ShaderMaterial
	mat.set_shader_parameter("windows", true)
	mat.set_shader_parameter("building_size", size)
	mat.set_shader_parameter("seed", _rng.randf() * 100.0)
	mat.set_shader_parameter("window_color", window_color)
	mat.set_shader_parameter("store_color", store)
	_collider(pos + Vector3(0, size.y * 0.5, 0), size)
	map_features.append({"rect": Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z), "kind": "building"})
	return mat


func _office(pos: Vector3, fp: Vector2, dist: float, front: Vector3) -> void:
	var h := _rng.randf_range(14.0, 40.0) * lerpf(1.4, 0.7, clampf(dist / 170.0, 0.0, 1.0))
	h = GROUND_H + maxf(2.0, floorf((h - GROUND_H) / FLOOR_H)) * FLOOR_H + 0.6
	var color: Color = OFFICE_COLORS[_rng.randi() % OFFICE_COLORS.size()]
	_body(pos, Vector3(fp.x, h, fp.y), color, GLASS_TINTS[_rng.randi() % GLASS_TINTS.size()], Color.from_hsv(_rng.randf(), 0.3, 0.95))
	Toon.add_mesh(self, Toon.box(Vector3(fp.x + 0.6, 0.6, fp.y + 0.6)), color.darkened(0.25), pos + Vector3(0, h + 0.3, 0), true, 0.03)
	var top := pos + Vector3(0, h + 0.6, 0)
	if h > 18.0 and _rng.randf() < 0.3:
		_billboard(top, fp, front)
	else:
		_roof(top, fp, false)


func _apartment(pos: Vector3, fp: Vector2, front: Vector3) -> void:
	var floors := _rng.randi_range(4, 11)
	var h := GROUND_H + floors * FLOOR_H + 0.4
	var color: Color = APARTMENT_COLORS[_rng.randi() % APARTMENT_COLORS.size()]
	_body(pos, Vector3(fp.x, h, fp.y), color, Color(0.62, 0.74, 0.9), color.darkened(0.15))
	# One balcony slab and railing per floor along the street face, with dividers per unit.
	var depth := absf(front.dot(Vector3(fp.x, 0, fp.y)))
	var width := absf(lane_left(front).dot(Vector3(fp.x, 0, fp.y)))
	var side := lane_left(front).abs()
	var rail_color := Color(0.85, 0.92, 0.96) if _rng.randf() < 0.5 else color.lightened(0.3)
	var units := maxi(1, int(width / 4.5))
	for f in floors:
		var y := pos.y + GROUND_H + f * FLOOR_H
		var face := pos + front * (depth * 0.5 + 0.6)
		_props.box("box", face + Vector3(0, y - pos.y, 0), side * (width - 0.8) + Vector3(0, 0.18, 0) + front.abs() * 1.2, color.darkened(0.1))
		_props.box("box", face + front * 0.63 + Vector3(0, y - pos.y + 0.55, 0), side * (width - 0.8) + Vector3(0, 1.0, 0) + front.abs() * 0.06, rail_color)
		for u in range(1, units):
			var offset := (u / float(units) - 0.5) * (width - 0.8)
			_props.box("box", face + lane_left(front) * offset + Vector3(0, y - pos.y + 1.3, 0), side * 0.08 + Vector3(0, 2.6, 0) + front.abs() * 1.1, color.darkened(0.05))
	_roof(pos + Vector3(0, h, 0), fp, true)


## `word` / `accent` override the random sign (landmark shops); `vending` false keeps the door clear.
func _shop(pos: Vector3, fp: Vector2, front: Vector3, word := "", accent := Color.TRANSPARENT, vending := true) -> void:
	var floors := _rng.randi_range(1, 2)
	var h := GROUND_H + floors * FLOOR_H + 0.3
	var color: Color = SHOP_COLORS[_rng.randi() % SHOP_COLORS.size()]
	if accent.a == 0.0:
		accent = SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()]
	_body(pos, Vector3(fp.x, h, fp.y), color, Color(0.7, 0.8, 0.92), accent.lightened(0.35))
	var depth := absf(front.dot(Vector3(fp.x, 0, fp.y)))
	var width := absf(lane_left(front).dot(Vector3(fp.x, 0, fp.y)))
	var along := lane_left(front)
	var face := pos + front * depth * 0.5
	var yaw := atan2(front.x, front.z)

	# Awning tilted down toward the street.
	var awning := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.28) * Basis.from_scale(Vector3(width - 0.6, 0.1, 1.6))
	_props.add("box", Transform3D(awning, face + front * 0.75 + Vector3(0, 3.35, 0)), accent)
	# Shop sign above the awning.
	if word.is_empty():
		word = SHOP_SIGNS[_rng.randi() % SHOP_SIGNS.size()]
	var sign_w := minf(width * 0.7, 1.2 + word.length() * 0.62)
	_props.box("box", face + front * 0.08 + Vector3(0, 4.45, 0), along.abs() * sign_w + Vector3(0, 0.9, 0) + front.abs() * 0.14, Color(0.1, 0.08, 0.14))
	_label(word, face + front * 0.17 + Vector3(0, 4.45, 0), front, 64, accent.lightened(0.5))
	# Vertical blade sign at one corner, readable from both directions along the street.
	if _rng.randf() < 0.55:
		var blade := face + along * (width * 0.5 - 0.6) * (1.0 if _rng.randf() < 0.5 else -1.0) + front * 0.65 + Vector3(0, h - 2.4, 0)
		var tag: String = SHOP_SIGNS[_rng.randi() % SHOP_SIGNS.size()]
		var blade_h := minf(0.75 * tag.length() + 0.4, h - 1.0)
		_props.box("glow", blade, along.abs() * 0.18 + Vector3(0, blade_h, 0) + front.abs() * 0.95, accent)
		var stacked := "\n".join(tag.replace(" ", "").split(""))
		for s in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = stacked
			l.font_size = 48
			l.pixel_size = 0.012
			l.line_spacing = -18.0
			l.outline_size = 10
			l.outline_modulate = Color(0.08, 0.04, 0.12)
			l.position = blade + along * 0.1 * s
			l.basis = Basis.looking_at(-along * s, Vector3.UP)
			l.scale = Vector3.ONE * minf(1.0, blade_h / (0.62 * tag.length()))
			add_child(l)
	# Vending machines beside the entrance.
	if vending and _rng.randf() < 0.5:
		for n in _rng.randi_range(1, 2):
			var spot := face + along * (width * 0.5 - 1.2 - n * 1.05) + front * 0.42
			var vc: Color = VENDING_COLORS[_rng.randi() % VENDING_COLORS.size()]
			_props.box("box", spot + Vector3(0, 0.92, 0), along.abs() * 0.95 + Vector3(0, 1.85, 0) + front.abs() * 0.8, vc)
			_props.box("glow", spot + front * 0.41 + Vector3(0, 1.2, 0), along.abs() * 0.8 + Vector3(0, 0.95, 0) + front.abs() * 0.03, Color(0.85, 0.95, 1.0))
			_collider(spot + Vector3(0, 0.92, 0), along.abs() * 0.95 + Vector3(0, 1.85, 0) + front.abs() * 0.8)
			vending_machines.append({"pos": Vector3(spot.x, CURB_H, spot.z) + front * 1.3, "front": front})
	_roof(pos + Vector3(0, h, 0), fp, _rng.randf() < 0.4)


func _tower(base: Vector3, size: float) -> void:
	var podium_h := GROUND_H + FLOOR_H * 2.0 + 0.4
	var stone: Color = OFFICE_COLORS[_rng.randi() % OFFICE_COLORS.size()]
	_body(base, Vector3(size, podium_h, size), stone, Color(0.75, 0.85, 1.0), Color(0.8, 0.92, 1.0))
	var tint: Color = GLASS_TINTS[_rng.randi() % GLASS_TINTS.size()]
	var w := size - _rng.randf_range(4.0, 8.0)
	var h := _rng.randf_range(50.0, 110.0)
	var y := base.y + podium_h
	var sections := [[w, h]]
	if _rng.randf() < 0.5:
		sections = [[w, h * 0.7], [w * 0.68, h * 0.3]]
	for s in sections:
		var sw: float = s[0]
		var sh: float = s[1]
		var glass := Toon.material(Color(0.5, 0.56, 0.66), true, 0.035, true)
		glass.set_shader_parameter("surface", 3)
		glass.set_shader_parameter("building_size", Vector3(sw, sh, sw))
		glass.set_shader_parameter("seed", _rng.randf() * 100.0)
		glass.set_shader_parameter("window_color", tint)
		var center := Vector3(base.x, y + sh * 0.5, base.z)
		_mesh(Toon.box(Vector3(sw, sh, sw)), glass, center)
		_collider(center, Vector3(sw, sh, sw))
		y += sh
		Toon.add_mesh(self, Toon.box(Vector3(sw + 0.5, 1.0, sw + 0.5)), stone.darkened(0.3), Vector3(base.x, y + 0.5, base.z), true, 0.03)
		y += 1.0
	var top_w: float = sections[sections.size() - 1][0]
	var top := Vector3(base.x, y, base.z)
	_roof(top, Vector2(top_w, top_w), true)
	_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.3, 10.0, 0.3)), top + Vector3(0, 5.0, 0)), METAL)
	_props.box("glow", top + Vector3(0, 10.2, 0), Vector3.ONE * 0.45, Color(1.0, 0.15, 0.15))


func _roof(top: Vector3, fp: Vector2, railing: bool) -> void:
	var mx := maxf(fp.x * 0.5 - 1.4, 0.5)
	var mz := maxf(fp.y * 0.5 - 1.4, 0.5)
	for i in _rng.randi_range(2, 5):
		var p := top + Vector3(_rng.randf_range(-mx, mx), 0.45, _rng.randf_range(-mz, mz))
		_props.box("box", p, Vector3(1.3, 0.9, 1.0), Color(0.8, 0.82, 0.86))
	if _rng.randf() < 0.4:
		var p := top + Vector3(_rng.randf_range(-mx, mx), 0, _rng.randf_range(-mz, mz))
		for leg in [Vector3(-0.6, 0, -0.6), Vector3(0.6, 0, -0.6), Vector3(-0.6, 0, 0.6), Vector3(0.6, 0, 0.6)]:
			_props.box("box", p + leg + Vector3(0, 0.5, 0), Vector3(0.1, 1.0, 0.1), METAL)
		_props.add("cyl", Transform3D(Basis.from_scale(Vector3(1.9, 1.6, 1.9)), p + Vector3(0, 1.8, 0)), Color(0.55, 0.75, 0.9))
	if _rng.randf() < 0.5:
		_props.box("box", top + Vector3(_rng.randf_range(-mx, mx) * 0.5, 1.3, _rng.randf_range(-mz, mz) * 0.5), Vector3(2.4, 2.6, 3.0), Color(0.72, 0.72, 0.75))
	if railing:
		for s in [-1.0, 1.0]:
			_props.box("box", top + Vector3(s * fp.x * 0.5, 0.55, 0), Vector3(0.06, 1.1, fp.y), Color(0.85, 0.88, 0.9))
			_props.box("box", top + Vector3(0, 0.55, s * fp.y * 0.5), Vector3(fp.x, 1.1, 0.06), Color(0.85, 0.88, 0.9))


func _billboard(top: Vector3, fp: Vector2, front: Vector3) -> void:
	var along := lane_left(front)
	var width := absf(along.dot(Vector3(fp.x, 0, fp.y))) * 0.75
	var center := top + front * (absf(front.dot(Vector3(fp.x, 0, fp.y))) * 0.5 - 1.0) + Vector3(0, 4.2, 0)
	for s in [-1.0, 1.0]:
		_props.box("box", center + along * s * width * 0.4 - Vector3(0, 2.1, 0) - front * 0.3, Vector3(0.25, 4.2, 0.25), METAL)
	var c: Color = SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()]
	_props.box("glow", center, along.abs() * width + Vector3(0, 4.0, 0) + front.abs() * 0.3, c)
	_label(BILLBOARDS[_rng.randi() % BILLBOARDS.size()], center + front * 0.17, front, 220, Color.WHITE)


func _park(center: Vector3, size: float) -> void:
	_slab(center, Vector2.ONE * size, 0.12, _mat("grass", Color(0.5, 0.8, 0.45)))
	map_features.append({"rect": Rect2(center.x - size * 0.5, center.z - size * 0.5, size, size), "kind": "park"})
	var path := _mat("path", Color(0.85, 0.8, 0.7), 2)
	_mesh(Toon.box(Vector3(size, 0.13, 2.2)), path, center + Vector3(0, 0.065, 0))
	_mesh(Toon.box(Vector3(2.2, 0.13, size)), path, center + Vector3(0, 0.065, 0))
	var half := size * 0.5 - 1.5
	for i in int(size * size / 30.0):
		var p := Vector3(_rng.randf_range(-half, half), 0.12, _rng.randf_range(-half, half))
		if absf(p.x) < 2.2 or absf(p.z) < 2.2:
			continue
		_tree(center + p, _rng.randf() < 0.5)
	for s in [-1.0, 1.0]:
		var bench := center + Vector3(s * size * 0.25, 0.12, 1.6)
		_props.box("box", bench + Vector3(0, 0.45, 0), Vector3(1.8, 0.1, 0.5), Color(0.6, 0.42, 0.3))
		_props.box("box", bench + Vector3(0, 0.75, 0.22), Vector3(1.8, 0.5, 0.08), Color(0.6, 0.42, 0.3))
		for k in [-0.5, 0.5]:
			seats.append({"pos": bench + Vector3(k, 0, -0.05), "yaw": PI})


func _tree(pos: Vector3, sakura := false) -> void:
	var h := _rng.randf_range(2.6, 3.4)
	_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.34, h, 0.34)), pos + Vector3(0, h * 0.5, 0)), TRUNK)
	var leaf := SAKURA if sakura else Color.from_hsv(_rng.randf_range(0.24, 0.32), 0.55, 0.72)
	leaf = leaf.lerp(Color.WHITE, _rng.randf() * 0.1)
	_props.add("leaves", Transform3D(Basis.from_scale(Vector3.ONE * _rng.randf_range(3.0, 3.6)), pos + Vector3(0, h + 1.0, 0)), leaf)
	for k in 2:
		var off := Vector3(_rng.randf_range(-1.1, 1.1), _rng.randf_range(0.2, 0.9), _rng.randf_range(-1.1, 1.1))
		_props.add("leaves", Transform3D(Basis.from_scale(Vector3.ONE * _rng.randf_range(1.8, 2.4)), pos + Vector3(0, h, 0) + off), leaf.darkened(0.06))
	_collider(pos + Vector3(0, h * 0.5, 0), Vector3(0.4, h, 0.4))


# --- Landmarks --------------------------------------------------------------------------------

func _landmark_lot(id: String, center: Vector3, base: Vector3, inner: float, lx: float, lz: float) -> void:
	var lm: Dictionary = LANDMARKS[id]
	var front: Vector3 = lm["front"]
	var w := inner * 0.92
	var pos := base + Vector3(lx * (inner - w * 0.5), 0, lz * (inner - w * 0.5))
	var color: Color = lm["color"]
	match lm["kind"]:
		"apartment":
			_apartment(pos, Vector2(w, w), front)
		"shop":
			_shop(pos, Vector2(w, w), front, String(lm["name"]).to_upper(), color, false)
	var face := pos + front * w * 0.5
	if id == "pharmacy":
		# Glowing green cross on the facade, above the awning.
		var cross := face + front * 0.25 + lane_left(front) * (w * 0.5 - 1.5) + Vector3(0, 6.4, 0)
		_props.box("glow", cross, Vector3(0, 1.6, 0) + lane_left(front).abs() * 0.5 + front.abs() * 0.2, color)
		_props.box("glow", cross, Vector3(0, 0.5, 0) + lane_left(front).abs() * 1.6 + front.abs() * 0.2, color)
	_door(id, face, front, center)


func _landmark_block(id: String, center: Vector3, base: Vector3, inner: float) -> void:
	var lm: Dictionary = LANDMARKS[id]
	var front: Vector3 = lm["front"]
	var along := lane_left(front)
	var width := inner * 2.0 - 2.0
	if lm["kind"] == "school":
		# Three-storey white school at the back of the lot, sports ground in front, fence with a gate.
		var depth := 12.0
		var h := GROUND_H + 2.0 * FLOOR_H + 0.4
		var pos := base - front * (inner - depth * 0.5 - 0.5)
		var size := along.abs() * width + front.abs() * depth
		_body(pos, Vector3(size.x, h, size.z), Color(0.95, 0.95, 0.93), Color(0.7, 0.82, 0.95), Color(0.75, 0.88, 1.0))
		Toon.add_mesh(self, Toon.box(Vector3(size.x + 0.5, 0.5, size.z + 0.5)), Color(0.55, 0.62, 0.7), pos + Vector3(0, h + 0.25, 0), true, 0.03)
		var face := pos + front * depth * 0.5
		# Clock above the entrance.
		_props.add("cyl", Transform3D(Basis(Vector3.UP, atan2(front.x, front.z)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(2.2, 0.2, 2.2)), face + front * 0.1 + Vector3(0, h - 1.6, 0)), Color(0.96, 0.96, 0.92))
		_label("12:00", face + front * 0.25 + Vector3(0, h - 1.6, 0), front, 64, Color(0.2, 0.2, 0.3))
		var yard_depth := inner * 2.0 - depth - 2.0
		var yard := base + front * (inner - yard_depth * 0.5 - 0.5) + Vector3(0, 0.01, 0)
		var yard_size := along.abs() * width + front.abs() * yard_depth
		_mesh(Toon.box(Vector3(yard_size.x, 0.02, yard_size.z)), _mat("dirt", Color(0.85, 0.72, 0.55)), yard)
		map_features.append({"rect": Rect2(yard.x - yard_size.x * 0.5, yard.z - yard_size.z * 0.5, yard_size.x, yard_size.z), "kind": "yard"})
		var fence_line := base + front * (inner - 0.1)
		for s: float in [-1.0, 1.0]:
			var seg := fence_line + along * s * (width * 0.25 + 1.5)
			var fence := along.abs() * (width * 0.5 - 3.0) + Vector3(0, 1.8, 0) + front.abs() * 0.08
			_props.box("box", seg + Vector3(0, 0.9, 0), fence, Color(0.3, 0.55, 0.45))
			_collider(seg + Vector3(0, 0.9, 0), fence)
			_tree(base + front * (inner - 2.5) + along * s * (width * 0.5 - 2.0), true)
		_label(String(lm["name"]).to_upper(), fence_line + along * 5.5 + front * 0.1 + Vector3(0, 2.3, 0), front, 64, Color(0.95, 0.97, 1.0))
		_door(id, face, front, center)
	else:
		# University hall: warm brick block with a colonnade, lawns and trees.
		var depth := 16.0
		var h := GROUND_H + 3.0 * FLOOR_H + 0.4
		var pos := base - front * (inner - depth * 0.5 - 0.5)
		var size := along.abs() * width + front.abs() * depth
		_body(pos, Vector3(size.x, h, size.z), Color(0.78, 0.45, 0.36), Color(0.75, 0.85, 1.0), Color(0.95, 0.85, 0.7))
		Toon.add_mesh(self, Toon.box(Vector3(size.x + 0.8, 0.9, size.z + 0.8)), Color(0.9, 0.86, 0.78), pos + Vector3(0, h + 0.45, 0), true, 0.03)
		var face := pos + front * depth * 0.5
		for i in 6:
			var col := face + front * 1.6 + along * (-6.25 + i * 2.5)
			_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.6, 7.0, 0.6)), col + Vector3(0, 3.5, 0)), Color(0.95, 0.93, 0.88))
			_collider(col + Vector3(0, 3.5, 0), Vector3(0.6, 7.0, 0.6))
		_props.box("box", face + front * 1.6 + Vector3(0, 7.3, 0), along.abs() * 16.0 + Vector3(0, 0.6, 0) + front.abs() * 3.4, Color(0.95, 0.93, 0.88))
		var lawn_depth := inner * 2.0 - depth - 5.0
		var lawn := base + front * (inner - lawn_depth * 0.5 - 0.5)
		for s: float in [-1.0, 1.0]:
			var half := lawn + along * s * (width * 0.25 + 1.0)
			var lawn_size := along.abs() * (width * 0.5 - 2.0) + front.abs() * lawn_depth
			_mesh(Toon.box(lawn_size + Vector3(0, 0.02, 0)), _mat("grass", Color(0.5, 0.8, 0.45)), half + Vector3(0, 0.01, 0))
			map_features.append({"rect": Rect2(half.x - lawn_size.x * 0.5, half.z - lawn_size.z * 0.5, lawn_size.x, lawn_size.z), "kind": "park"})
			for t in 3:
				_tree(half + along * s * (-3.0 + t * 4.0) + front * (lawn_depth * 0.5 - 2.0), t == 1)
		_label(String(lm["name"]).to_upper(), face + front * 3.35 + Vector3(0, 7.3, 0), front, 72, Color(0.25, 0.18, 0.15))
		_door(id, face + front * 0.02, front, center)


## Entrance with glass doors, a glowing frame and the place name; registers the place.
func _door(id: String, face: Vector3, front: Vector3, block_center: Vector3) -> void:
	var lm: Dictionary = LANDMARKS[id]
	var color: Color = lm["color"]
	var along := lane_left(front).abs()
	var ground := Vector3(face.x, CURB_H, face.z)
	_props.box("box", ground + front * 0.06 + Vector3(0, 1.3, 0), along * 1.9 + Vector3(0, 2.6, 0) + front.abs() * 0.12, Color(0.12, 0.16, 0.24))
	_props.box("glow", ground + front * 0.1 + Vector3(0, 2.72, 0), along * 2.2 + Vector3(0, 0.14, 0) + front.abs() * 0.16, color)
	_props.box("glow", ground + front * 0.1 + Vector3(0, 1.3, 0), along * 0.05 + Vector3(0, 2.6, 0) + front.abs() * 0.14, color.lightened(0.4))
	_label(lm["name"], ground + front * 0.2 + Vector3(0, 3.2, 0), front, 40, color.lightened(0.5))
	_marker(ground + front * 1.0 + Vector3(0, 4.4, 0), id, color)
	# Parking spot on the near side of the street, facing along left-hand traffic.
	var road := block_center.dot(front) + CELL * 0.5
	var park := ground + front * (road - PARK_OFFSET - ground.dot(front))
	var dir := Vector3(front.z, 0, -front.x)
	places[id] = {
		"name": lm["name"], "kind": lm["kind"], "color": color, "front": front,
		"door": ground + front * 1.4,
		"park": Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(park.x, 0.3, park.z)),
	}


# --- Fuel stations, bus stops, markers ---------------------------------------------------------

## Petrol or EV charging forecourt filling a lot: canopy over pumps / chargers, kiosk at the back,
## price sign by the street. Cars refuel anywhere under the canopy.
func _station(id: String, base: Vector3, inner: float, lx: float, lz: float) -> void:
	var st: Dictionary = STATIONS[id]
	var front: Vector3 = st["front"]
	var along := lane_left(front)
	var ev: bool = st["kind"] == "ev"
	var color: Color = Color(0.35, 0.85, 1.0) if ev else Color(1.0, 0.45, 0.3)
	var w := inner * 0.95
	var pos := base + Vector3(lx * (inner - w * 0.5), 0, lz * (inner - w * 0.5))
	_mesh(Toon.box(Vector3(w, 0.02, w)), _mat("forecourt", Color(0.62, 0.62, 0.66)), pos + Vector3(0, 0.01, 0))
	# Kiosk at the back of the lot.
	var kiosk := pos - front * (w * 0.5 - 2.5)
	_body(kiosk, along.abs() * (w * 0.45) + Vector3(0, 3.6, 0) + front.abs() * 4.5, Color(0.95, 0.95, 0.97), Color(0.7, 0.85, 1.0), color.lightened(0.4))
	_label("CHARGE" if ev else "MART", kiosk + front * 2.3 + Vector3(0, 3.0, 0), front, 48, color)
	# Canopy on four pillars, brand stripe around the edge.
	var c := pos + front * 2.0
	var cw := w * 0.72
	var cd := w * 0.42
	var canopy := along.abs() * cw + front.abs() * cd
	_props.box("box", c + Vector3(0, 5.2, 0), canopy + Vector3(0, 0.45, 0), Color(0.97, 0.97, 0.98))
	_props.box("glow", c + Vector3(0, 4.92, 0), canopy + Vector3(0.1, 0.12, 0.1), color)
	for sa: float in [-1.0, 1.0]:
		for sf: float in [-1.0, 1.0]:
			var p := c + along * sa * cw * 0.38 + front * sf * cd * 0.3
			_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.35, 5.0, 0.35)), p + Vector3(0, 2.5, 0)), Color(0.85, 0.86, 0.9))
			_collider(p + Vector3(0, 2.5, 0), Vector3(0.35, 5.0, 0.35))
	# Two islands of pumps / chargers.
	for sa: float in [-1.0, 1.0]:
		var island := c + along * sa * cw * 0.2
		_props.box("box", island + Vector3(0, 0.12, 0), along.abs() * 0.9 + Vector3(0, 0.25, 0) + front.abs() * 3.4, Color(0.75, 0.75, 0.78))
		for sf: float in [-1.0, 1.0]:
			var unit := island + front * sf * 0.9
			if ev:
				_props.box("box", unit + Vector3(0, 1.05, 0), along.abs() * 0.4 + Vector3(0, 1.8, 0) + front.abs() * 0.35, Color(0.95, 0.96, 0.98))
				_props.box("glow", unit + Vector3(0, 1.5, 0), along.abs() * 0.42 + Vector3(0, 0.12, 0) + front.abs() * 0.37, color)
			else:
				_props.box("box", unit + Vector3(0, 0.95, 0), along.abs() * 0.6 + Vector3(0, 1.6, 0) + front.abs() * 0.45, Color(0.9, 0.3, 0.25))
				_props.box("glow", unit + Vector3(0, 1.35, 0), along.abs() * 0.62 + Vector3(0, 0.35, 0) + front.abs() * 0.3, Color(0.85, 0.95, 1.0))
			_collider(unit + Vector3(0, 0.9, 0), along.abs() * 0.6 + Vector3(0, 1.8, 0) + front.abs() * 0.45)
	# Price sign at the street corner.
	var sign_pos := pos + front * (w * 0.5 - 0.8) + along * (w * 0.5 - 1.0)
	_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.25, 6.0, 0.25)), sign_pos + Vector3(0, 3.0, 0)), METAL)
	_props.box("box", sign_pos + Vector3(0, 6.4, 0), along.abs() * 2.4 + Vector3(0, 1.6, 0) + front.abs() * 0.3, Color(0.1, 0.1, 0.15))
	_label(st["name"], sign_pos + front * 0.16 + Vector3(0, 6.85, 0), front, 36, color)
	_label("¥45 / kWh" if ev else "¥168 / L", sign_pos + front * 0.16 + Vector3(0, 6.15, 0), front, 44, Color(1.0, 0.95, 0.7))
	stations[id] = {"name": st["name"], "kind": st["kind"], "color": color, "center": Vector3(c.x, 0, c.z), "front": front}
	map_features.append({"rect": Rect2(pos.x - w * 0.5, pos.z - w * 0.5, w, w), "kind": "yard"})
	_marker(c + Vector3(0, 7.2, 0), "ev" if ev else "gas", color)


## Bus shelter on a block's sidewalk facing the street: roof, glass back, bench, stop sign.
func _bus_stop(stop: Array) -> void:
	var stop_name: String = stop[0]
	var center := Vector3((stop[1][0] - (BLOCKS - 1) / 2.0) * CELL, CURB_H, (stop[1][1] - (BLOCKS - 1) / 2.0) * CELL)
	var front: Vector3 = stop[2]
	var along := lane_left(front)
	var p := center + front * (BLOCK_SIZE * 0.5 - 2.1) + along * float(stop[3])
	var back := p - front * 0.75
	_props.box("box", back + Vector3(0, 1.3, 0), along.abs() * 3.6 + Vector3(0, 2.2, 0) + front.abs() * 0.06, Color(0.7, 0.85, 0.95))
	_props.box("box", p + Vector3(0, 2.5, 0), along.abs() * 4.0 + Vector3(0, 0.12, 0) + front.abs() * 1.8, Color(0.25, 0.4, 0.6))
	for s in [-1.0, 1.0]:
		_props.box("box", back + along * s * 1.8 + Vector3(0, 1.25, 0), Vector3(0.1, 2.5, 0.1), METAL)
	var seat := back + front * 0.35
	_props.box("box", seat + Vector3(0, 0.45, 0), along.abs() * 2.4 + Vector3(0, 0.08, 0) + front.abs() * 0.45, Color(0.6, 0.42, 0.3))
	_collider(back + Vector3(0, 1.3, 0), along.abs() * 3.6 + Vector3(0, 2.2, 0) + front.abs() * 0.1)
	var pole := p + front * 0.85 + along * 2.3
	_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.12, 3.2, 0.12)), pole + Vector3(0, 1.6, 0)), METAL)
	_props.box("glow", pole + Vector3(0, 3.2, 0), along.abs() * 0.08 + Vector3(0, 0.7, 0) + front.abs() * 0.7, Color(0.3, 0.75, 1.0))
	_label(stop_name, back + front * 0.05 + Vector3(0, 2.15, 0), front, 30, Color(0.1, 0.18, 0.3))
	var yaw := atan2(front.x, front.z)
	for k in [-0.7, 0.7]:
		seats.append({"pos": seat + along * k + front * 0.1, "yaw": yaw})
	bus_stops.append({"name": stop_name, "pos": p + front * 0.4, "front": front})
	_marker(pole + Vector3(0, 4.3, 0), "bus", Color(0.3, 0.75, 1.0))


## Floating map-style badge above a place: icon drawn once into a small viewport, shown as a
## billboard sprite.
func _marker(pos: Vector3, icon: String, color: Color) -> void:
	var key := "%s_%s" % [icon, color.to_html()]
	if not _icon_textures.has(key):
		var vp := SubViewport.new()
		vp.size = Vector2i(128, 128)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var badge := Control.new()
		badge.size = Vector2(128, 128)
		badge.draw.connect(func():
			badge.draw_circle(Vector2(64, 64), 58, Color(0.06, 0.04, 0.12))
			badge.draw_circle(Vector2(64, 64), 52, color)
			Icons.draw(badge, icon, Vector2(64, 64), 30.0, Color(0.06, 0.04, 0.12)))
		vp.add_child(badge)
		add_child(vp)
		_icon_textures[key] = vp.get_texture()
	var sprite := Sprite3D.new()
	sprite.texture = _icon_textures[key]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.009
	sprite.shaded = false
	sprite.position = pos
	add_child(sprite)


## Sidewalk ring and grass outside the ring road, with a row of trees.
func _build_outskirts() -> void:
	var walk := _mat("paving", Color(0.76, 0.74, 0.78), 2)
	var mid := EXTENT + OUTER_WALK * 0.5
	var span := (EXTENT + OUTER_WALK) * 2.0
	for s in [-1.0, 1.0]:
		_slab(Vector3(0, 0, s * mid), Vector2(span, OUTER_WALK), CURB_H, walk)
		_slab(Vector3(s * mid, 0, 0), Vector2(OUTER_WALK, EXTENT * 2.0), CURB_H, walk)
	var grass := _mat("grass", Color(0.5, 0.8, 0.45))
	var g_mid := (EXTENT + OUTER_WALK + WORLD_HALF) * 0.5
	var g_w := WORLD_HALF - EXTENT - OUTER_WALK
	for s in [-1.0, 1.0]:
		_slab(Vector3(0, 0, s * g_mid), Vector2(WORLD_HALF * 2.0, g_w), 0.2, grass)
		_slab(Vector3(s * g_mid, 0, 0), Vector2(g_w, (EXTENT + OUTER_WALK) * 2.0), 0.2, grass)
	var row := EXTENT + OUTER_WALK + 4.0
	var t := -row
	while t <= row:
		for p in [Vector3(t, 0.2, row), Vector3(t, 0.2, -row), Vector3(row, 0.2, t), Vector3(-row, 0.2, t)]:
			_tree(p, _rng.randf() < 0.3)
		t += 11.0


# --- Roads and street furniture ---------------------------------------------------------------

func _build_roads() -> void:
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var across := Vector3(axis.z, 0, axis.x)
		for k in range(-GRID, GRID + 1):
			var origin := across * k * CELL
			var poles := []
			for n in range(-GRID, GRID):
				var t0 := n * CELL + HALF_ROAD
				var t1 := (n + 1) * CELL - HALF_ROAD
				_markings(origin, axis, across, t0, t1)
				for t in [t0 + 6.5, t0 + 20.0, t0 + 33.5]:
					poles.append(origin + axis * t + across * PROP_LINE + Vector3(0, CURB_H, 0))
				for t in [t0 + 10.0, t0 + 30.0]:
					_lamp(origin + axis * t - across * PROP_LINE + Vector3(0, CURB_H, 0), across)
				for t in [t0 + 4.0, t0 + 20.0, t0 + 36.0]:
					if _rng.randf() < 0.8:
						_tree(origin + axis * t - across * (PROP_LINE + 0.3) + Vector3(0, CURB_H, 0))
			_utility_line(poles, across)


func _markings(origin: Vector3, axis: Vector3, across: Vector3, t0: float, t1: float) -> void:
	var yaw := atan2(axis.x, axis.z)
	var up := Vector3.UP * 0.006
	var t := t0 + 6.0
	while t + 3.0 <= t1 - 6.0:
		_props.box("paint", origin + axis * (t + 1.5) + up, Vector3(0.15, 0.008, 3.0), MARK, yaw)
		t += 6.0
	for s in [-1.0, 1.0]:
		_props.box("paint", origin + axis * (t0 + t1) * 0.5 + across * s * EDGE_LINE + up, Vector3(0.15, 0.008, t1 - t0 - 10.6), MARK, yaw)
	for end in [[t0, 1.0], [t1, -1.0]]:
		var edge: float = end[0]
		var inward: float = end[1]
		for i in 13:
			_props.box("paint", origin + axis * (edge + inward * 2.5) + across * (-6.0 + i) + up, Vector3(0.5, 0.008, 3.6), MARK, yaw)
		# Stop line on the lane that drives toward this end's intersection.
		var lane_side := lane_left(axis * -inward).dot(across)
		_props.box("paint", origin + axis * (edge + inward * (STOP_LINE - HALF_ROAD)) + across * lane_side * (EDGE_LINE * 0.5 + 0.1) + up,
				Vector3(EDGE_LINE - 0.2, 0.008, 0.45), MARK, yaw)


func _lamp(base: Vector3, toward_road: Vector3) -> void:
	_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.18, 6.2, 0.18)), base + Vector3(0, 3.1, 0)), METAL)
	_props.segment("cyl", base + Vector3(0, 6.0, 0), base + toward_road * 1.6 + Vector3(0, 6.3, 0), 0.05, METAL)
	_props.box("glow", base + toward_road * 1.75 + Vector3(0, 6.22, 0), Vector3(0.6, 0.12, 0.6), Color(1.0, 0.94, 0.8))
	_collider(base + Vector3(0, 3.1, 0), Vector3(0.2, 6.2, 0.2))


## Concrete utility poles with crossarms, joined by sagging power and telecom lines.
func _utility_line(poles: Array, across: Vector3) -> void:
	for p in poles:
		_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.32, 9.0, 0.32)), p + Vector3(0, 4.5, 0)), POLE)
		_props.box("box", p + Vector3(0, 8.6, 0), Vector3.ONE * 0.12 + across.abs() * 1.5, METAL)
		if _rng.randf() < 0.3:
			_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.5, 0.75, 0.5)), p - across * 0.4 + Vector3(0, 7.3, 0)), Color(0.55, 0.58, 0.6))
		_collider(p + Vector3(0, 4.5, 0), Vector3(0.32, 9.0, 0.32))
	for i in poles.size() - 1:
		var a: Vector3 = poles[i]
		var b: Vector3 = poles[i + 1]
		for w in [-0.65, 0.0, 0.65]:
			_wire(a + across * w + Vector3(0, 8.66, 0), b + across * w + Vector3(0, 8.66, 0), 0.55)
		_wire(a + Vector3(0, 7.6, 0), b + Vector3(0, 7.6, 0), 0.4)


func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var prev := a
	for s in range(1, 5):
		var t := s / 4.0
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		_props.segment("wire", prev, p, 0.022, WIRE)
		prev = p


## One signal per approach, on the near-left corner, arm reaching over the approaching lane.
func _build_signals() -> void:
	for i in range(-GRID, GRID + 1):
		for j in range(-GRID, GRID + 1):
			var node := Vector3(i, 0, j) * CELL
			for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				if not in_grid(node - d * CELL):
					continue
				var left := lane_left(d)
				var corner := node - d * (HALF_ROAD + 0.6) + left * (HALF_ROAD + 0.6) + Vector3(0, CURB_H, 0)
				_props.add("cyl", Transform3D(Basis.from_scale(Vector3(0.2, 5.8, 0.2)), corner + Vector3(0, 2.9, 0)), METAL)
				_props.segment("cyl", corner + Vector3(0, 5.6, 0), corner - left * 4.9 + Vector3(0, 5.6, 0), 0.07, METAL)
				_collider(corner + Vector3(0, 2.9, 0), Vector3(0.22, 5.8, 0.22))
				var head := corner - left * 4.4 + Vector3(0, 5.6, 0)
				_props.box("box", head, left.abs() * 1.3 + Vector3(0, 0.44, 0) + d.abs() * 0.3, Color(0.2, 0.22, 0.25))
				var axis := "x" if absf(d.x) > 0.5 else "z"
				for c in 3:
					var lamp := head - d * 0.15 + left * (0.42 - 0.42 * c)
					_props.segment("sig_%s%d" % [axis, c], lamp, lamp - d * 0.06, 0.14)
