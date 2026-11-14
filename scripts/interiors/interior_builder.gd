extends RefCounted
## Builds the room behind a landmark door, far outside the city. Returns
## {"root": Node3D, "spawn": Vector3, "exit": Vector3, "spots": [{"pos", "label", "action"}]}.
## The exit door is always on the room's -Z wall; the heroine spawns just inside it facing +Z.

const Toon := preload("res://scripts/toon.gd")
const Civilian := preload("res://scripts/npc/civilian.gd")
const CarModels := preload("res://scripts/city/car_models.gd")
const Mannequin := preload("res://scripts/npc/mannequin.gd")

const ORIGIN := Vector3(2000, 0, 0)

var root: Node3D
var spots := []
var _static: StaticBody3D
var _rng := RandomNumberGenerator.new()


## `kind`: apartment, konbini, pharmacy, car_rental, school or university.
func build(kind: String, parent: Node3D) -> Dictionary:
	_rng.seed = hash(kind)
	root = Node3D.new()
	root.name = "Interior_" + kind
	root.position = ORIGIN
	parent.add_child(root)
	_static = StaticBody3D.new()
	root.add_child(_static)
	var size := Vector3(12, 3.2, 9)
	match kind:
		"apartment":
			size = Vector3(11, 3.0, 9)
			_room(size, Color(0.72, 0.55, 0.4), Color(0.97, 0.92, 0.86), Color(1.0, 0.85, 0.7))
			_home(size)
		"konbini":
			_room(size, Color(0.88, 0.9, 0.92), Color(0.98, 0.98, 1.0), Color(0.95, 0.97, 1.0))
			_store(size, true)
		"pharmacy":
			_room(size, Color(0.75, 0.9, 0.85), Color(0.97, 0.99, 0.98), Color(0.92, 1.0, 0.96))
			_store(size, false)
		"car_rental":
			size = Vector3(18, 4.5, 14)
			_room(size, Color(0.82, 0.82, 0.86), Color(0.94, 0.94, 0.97), Color(1.0, 0.95, 0.88))
			_showroom(size)
		"boutique":
			size = Vector3(14, 3.6, 11)
			_room(size, Color(0.9, 0.86, 0.84), Color(0.99, 0.95, 0.96), Color(1.0, 0.92, 0.95))
			_boutique(size)
		"school":
			size = Vector3(14, 3.4, 11)
			_room(size, Color(0.78, 0.62, 0.45), Color(0.93, 0.95, 0.88), Color(1.0, 0.97, 0.9))
			_classroom(size)
		"university":
			size = Vector3(18, 5.0, 15)
			_room(size, Color(0.55, 0.4, 0.35), Color(0.92, 0.88, 0.8), Color(1.0, 0.92, 0.8))
			_lecture_hall(size)
	var exit := Vector3(0, 0, -size.z * 0.5 + 1.0)
	return {"root": root, "spawn": root.position + exit + Vector3(0, 0.1, 0.8), "exit": root.position + exit, "spots": spots}


# --- Shell ------------------------------------------------------------------------------------

func _room(size: Vector3, floor_color: Color, wall_color: Color, light_color: Color) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_box(Vector3(w, 0.2, d), Vector3(0, -0.1, 0), floor_color, true, false)
	# The ceiling sits on render layer 2, which the room lights skip: no hard light pools on it.
	var ceiling := _box(Vector3(w, 0.2, d), Vector3(0, h + 0.1, 0), wall_color.darkened(0.08), false, false)
	ceiling.layers = 2
	for s in [-1.0, 1.0]:
		_box(Vector3(0.3, h, d), Vector3(s * (w * 0.5 + 0.15), h * 0.5, 0), wall_color, true, false)
		_box(Vector3(w, h, 0.3), Vector3(0, h * 0.5, s * (d * 0.5 + 0.15)), wall_color, true, false)
	# Skirting board.
	for s in [-1.0, 1.0]:
		_box(Vector3(0.05, 0.12, d), Vector3(s * (w * 0.5 - 0.02), 0.06, 0), wall_color.darkened(0.35), false, false)
		_box(Vector3(w, 0.12, 0.05), Vector3(0, 0.06, s * (d * 0.5 - 0.02)), wall_color.darkened(0.35), false, false)
	# Exit door on the -Z wall.
	var door := Vector3(0, 0, -d * 0.5)
	_box(Vector3(1.6, 2.4, 0.08), door + Vector3(0, 1.2, 0.05), Color(0.35, 0.28, 0.24), false, false)
	_glow(Vector3(1.9, 0.12, 0.1), door + Vector3(0, 2.5, 0.06), Color(0.6, 0.85, 1.0))
	_text("EXIT", door + Vector3(0, 2.8, 0.1), Vector3.BACK, 40, Color(0.7, 0.9, 1.0))
	# Ceiling lights: glowing panels plus omnis for the cel lighting.
	for x in [-w * 0.25, w * 0.25]:
		for z in [-d * 0.25, d * 0.25]:
			_glow(Vector3(1.2, 0.06, 0.5), Vector3(x, h - 0.03, z), light_color)
			var omni := OmniLight3D.new()
			omni.position = Vector3(x, h - 0.6, z)
			omni.light_color = light_color
			omni.omni_range = maxf(w, d) * 0.6
			omni.light_energy = 1.1
			omni.light_cull_mask = 1
			root.add_child(omni)


func _box(size: Vector3, pos: Vector3, color: Color, collide := true, outline := true) -> MeshInstance3D:
	var mi := Toon.add_mesh(root, Toon.box(size), color, pos, outline, 0.02)
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = pos
		_static.add_child(shape)
	return mi


func _glow(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := Toon.add_mesh(root, Toon.box(size), color, pos, false)
	(mi.material_override as ShaderMaterial).set_shader_parameter("emission", color * 0.9)


func _text(text: String, pos: Vector3, facing: Vector3, size := 48, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 8
	l.modulate = color
	l.outline_modulate = Color(0.08, 0.05, 0.12)
	l.position = pos
	l.basis = Basis.looking_at(-facing, Vector3.UP)
	root.add_child(l)


## Bright panes on a wall suggesting the city outside.
func _windows(x_wall: float, count: int, depth: float, h: float) -> void:
	for i in count:
		var z := lerpf(-depth * 0.35, depth * 0.35, (i + 0.5) / count) if count > 1 else 0.0
		_glow(Vector3(0.05, 1.5, 1.6), Vector3(x_wall, h * 0.55, z), Color(0.75, 0.88, 1.0))
		_box(Vector3(0.08, 0.08, 1.7), Vector3(x_wall, h * 0.55 - 0.78, z), Color(0.95, 0.95, 0.95), false, false)


func _spot(pos: Vector3, label: String, action: String) -> void:
	spots.append({"pos": root.position + pos, "label": label, "action": action})


func _person(pos: Vector3, look_at: Vector3, sitting := false, person_name := "", personality := "calm") -> Node:
	var npc := Civilian.new()
	npc.stationary = true
	npc.seated = sitting
	npc.position = pos
	if not person_name.is_empty():
		npc.npc_name = person_name
		npc.personality = personality
		npc.mood = 55
	root.add_child(npc)
	npc.face(root.position + look_at)
	return npc


func _plant(pos: Vector3) -> void:
	_box(Vector3(0.45, 0.5, 0.45), pos + Vector3(0, 0.25, 0), Color(0.8, 0.5, 0.35))
	Toon.add_mesh(root, Toon.sphere(0.45), Color(0.45, 0.75, 0.45), pos + Vector3(0, 0.9, 0), true, 0.02)


# --- Rooms ------------------------------------------------------------------------------------

func _home(s: Vector3) -> void:
	var hw := s.x * 0.5
	var hd := s.z * 0.5
	_windows(hw, 2, s.z, s.y)
	_box(Vector3(3.2, 0.02, 2.2), Vector3(-1.0, 0.01, 0.5), Color(0.98, 0.72, 0.8), false, false)
	# Bed in the back-right corner.
	var bed := Vector3(hw - 1.3, 0, hd - 1.2)
	_box(Vector3(1.6, 0.4, 2.2), bed + Vector3(0, 0.2, 0), Color(0.6, 0.45, 0.35))
	_box(Vector3(1.5, 0.18, 2.1), bed + Vector3(0, 0.49, 0), Color(0.98, 0.97, 0.95), false)
	_box(Vector3(1.52, 0.1, 1.3), bed + Vector3(0, 0.62, -0.35), Color(1.0, 0.7, 0.8), false)
	_box(Vector3(0.9, 0.16, 0.45), bed + Vector3(0, 0.66, 0.75), Color(1.0, 1.0, 1.0), false)
	_spot(bed + Vector3(-1.3, 0, 0), "Sleep", "sleep")
	# Wardrobe back-left.
	var wardrobe := Vector3(-hw + 1.1, 0, hd - 0.4)
	_box(Vector3(1.8, 2.2, 0.6), wardrobe + Vector3(0, 1.1, 0), Color(0.82, 0.68, 0.52))
	_box(Vector3(0.04, 2.0, 0.02), wardrobe + Vector3(0, 1.1, -0.31), Color(0.5, 0.38, 0.3), false, false)
	_spot(wardrobe + Vector3(0, 0, -1.1), "Wardrobe", "wardrobe")
	# Sofa facing the TV on the left wall.
	var sofa := Vector3(-0.2, 0, 0.6)
	_box(Vector3(0.9, 0.45, 2.2), sofa + Vector3(0, 0.22, 0), Color(0.45, 0.55, 0.8))
	_box(Vector3(0.25, 0.5, 2.2), sofa + Vector3(0.4, 0.65, 0), Color(0.42, 0.5, 0.75))
	var tv := Vector3(-hw + 0.35, 0, 0.6)
	_box(Vector3(0.5, 0.5, 1.8), tv + Vector3(0, 0.25, 0), Color(0.35, 0.3, 0.3))
	_glow(Vector3(0.06, 0.8, 1.4), tv + Vector3(0.05, 1.0, 0), Color(0.45, 0.7, 1.0))
	_spot(sofa + Vector3(-0.9, 0, 0), "Watch TV", "tv")
	# Kitchenette by the door.
	var kitchen := Vector3(hw - 0.4, 0, -hd + 2.3)
	_box(Vector3(0.6, 0.9, 2.4), kitchen + Vector3(0, 0.45, 0), Color(0.95, 0.95, 0.95))
	_box(Vector3(0.7, 1.8, 0.7), kitchen + Vector3(-0.05, 0.9, 1.6), Color(0.85, 0.9, 0.95))
	_spot(kitchen + Vector3(-1.0, 0, 1.0), "Fridge", "fridge")
	_plant(Vector3(-hw + 0.6, 0, -hd + 0.6))
	_plant(Vector3(hw - 0.6, 0, 0.4))


func _store(s: Vector3, konbini: bool) -> void:
	var hw := s.x * 0.5
	var hd := s.z * 0.5
	var product := [Color(1.0, 0.5, 0.5), Color(0.5, 0.75, 1.0), Color(1.0, 0.85, 0.4), Color(0.6, 0.9, 0.6), Color(0.9, 0.6, 1.0)]
	for row in 2:
		var x := -2.0 + row * 3.0
		_box(Vector3(1.0, 1.5, 4.5), Vector3(x, 0.75, 0.8), Color(0.9, 0.9, 0.92))
		for level in 3:
			for k in 6:
				for side in [-1.0, 1.0]:
					_box(Vector3(0.12, 0.25, 0.5), Vector3(x + side * 0.53, 0.45 + level * 0.42, -1.1 + k * 0.75), product[(row + level + k) % product.size()], false, false)
	if konbini:
		# Glowing drinks fridge along the back wall.
		_glow(Vector3(6.0, 1.9, 0.1), Vector3(-1.0, 1.05, hd - 0.4), Color(0.75, 0.9, 1.0))
		_box(Vector3(6.2, 2.1, 0.5), Vector3(-1.0, 1.05, hd - 0.15), Color(0.85, 0.87, 0.9), true, false)
	else:
		_box(Vector3(0.4, 1.8, 5.0), Vector3(-hw + 0.25, 0.9, 0.6), Color(0.92, 0.96, 0.95))
		_glow(Vector3(0.05, 0.5, 0.5), Vector3(-hw + 0.48, 2.3, 0.6), Color(0.35, 0.95, 0.55))
	# Counter with register and clerk.
	var counter := Vector3(hw - 1.6, 0, -0.5)
	_box(Vector3(0.8, 1.0, 3.0), counter + Vector3(0, 0.5, 0), Color(0.55, 0.75, 0.95) if konbini else Color(0.5, 0.85, 0.7))
	_box(Vector3(0.4, 0.25, 0.4), counter + Vector3(0, 1.12, -0.6), Color(0.25, 0.25, 0.3), false)
	if konbini:
		_person(counter + Vector3(1.0, 0, 0), counter + Vector3(-3, 0, 0), false, "Clerk Mori", "cheerful")
		_spot(counter + Vector3(-1.1, 0, 0), "Counter", "shop_konbini")
	else:
		_person(counter + Vector3(1.0, 0, 0), counter + Vector3(-3, 0, 0), false, "Pharmacist Sato", "calm")
		_spot(counter + Vector3(-1.1, 0, 0), "Counter", "shop_pharmacy")
	_text("24H MART" if konbini else "PHARMACY", Vector3(0, s.y - 0.6, hd - 0.02), Vector3.FORWARD, 64,
			Color(0.3, 0.55, 0.95) if konbini else Color(0.2, 0.7, 0.45))


func _showroom(s: Vector3) -> void:
	var hw := s.x * 0.5
	var hd := s.z * 0.5
	_windows(-hw, 3, s.z, s.y)
	var display := [["coupe", Color(0.95, 0.3, 0.45)], ["sedan", Color(0.2, 0.4, 0.85)], ["van", Color(0.95, 0.95, 0.97)]]
	for i in display.size():
		var pad := Vector3(-4.5 + i * 4.5, 0, 2.0)
		Toon.add_mesh(root, Toon.cylinder(2.6, 0.12), Color(0.9, 0.9, 0.95), pad + Vector3(0, 0.06, 0), true, 0.02)
		var car := Node3D.new()
		car.position = pad + Vector3(0, 0.12, 0)
		car.rotation.y = 0.6 + i * 0.4
		root.add_child(car)
		var spec := CarModels.spec(display[i][0])
		CarModels.build(car, spec, display[i][1])
		for x in [-spec["track"], spec["track"]]:
			for z in [spec["wheelbase"] * 0.5, -spec["wheelbase"] * 0.5]:
				var tire := Toon.add_mesh(car, Toon.cylinder(spec["wheel_radius"], 0.22), Color(0.07, 0.07, 0.09), Vector3(x, spec["wheel_radius"], z), true, 0.02)
				tire.rotation.z = PI / 2.0
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 2.4
		cyl.height = 1.6
		shape.shape = cyl
		shape.position = pad + Vector3(0, 0.8, 0)
		_static.add_child(shape)
	var desk := Vector3(hw - 2.5, 0, -hd + 3.0)
	_box(Vector3(1.0, 1.0, 3.2), desk + Vector3(0, 0.5, 0), Color(1.0, 0.68, 0.22))
	_person(desk + Vector3(1.1, 0, 0), desk + Vector3(-3, 0, 0), false, "Agent Kudo", "cheerful")
	_spot(desk + Vector3(-1.2, 0, 0), "Rental desk", "rent")
	_text("RENT-A-CAR", Vector3(0, s.y - 0.8, hd - 0.02), Vector3.FORWARD, 80, Color(1.0, 0.6, 0.15))
	_plant(Vector3(-hw + 0.7, 0, -hd + 0.7))
	_plant(Vector3(hw - 0.7, 0, hd - 0.7))


func _classroom(s: Vector3) -> void:
	var hw := s.x * 0.5
	var hd := s.z * 0.5
	_windows(hw, 3, s.z, s.y)
	_box(Vector3(s.x, 1.0, 0.04), Vector3(0, 0.5, hd - 0.02), Color(0.7, 0.8, 0.65), false, false)
	# Blackboard on the far wall.
	_box(Vector3(6.0, 1.6, 0.06), Vector3(0, 1.7, hd - 0.05), Color(0.16, 0.3, 0.24), false, false)
	_text("Homeroom 2-B\nToday: The History of Hoshimachi", Vector3(0, 1.75, hd - 0.1), Vector3.BACK, 40, Color(0.95, 0.97, 0.95))
	_box(Vector3(1.6, 0.8, 0.7), Vector3(0, 0.4, hd - 1.3), Color(0.6, 0.45, 0.32))
	_person(Vector3(1.6, 0, hd - 1.2), Vector3(0, 0, -hd), false, "Ms. Ishida", "calm")
	var students := 0
	for row in 4:
		for col in 4:
			var p := Vector3(-3.6 + col * 2.4, 0, hd - 3.0 - row * 1.6)
			_box(Vector3(0.7, 0.72, 0.5), p + Vector3(0, 0.36, 0.25), Color(0.75, 0.6, 0.42))
			_box(Vector3(0.45, 0.42, 0.42), p + Vector3(0, 0.21, -0.3), Color(0.45, 0.48, 0.55), false)
			if (row * 4 + col) % 3 != 0 and students < 8:
				students += 1
				_person(p + Vector3(0, 0, -0.3), p + Vector3(0, 0, 3), true)
	_spot(Vector3(-3.6, 0, hd - 3.0 - 3 * 1.6 - 1.0), "Attend class", "class")


func _lecture_hall(s: Vector3) -> void:
	var hw := s.x * 0.5
	var hd := s.z * 0.5
	# Projection screen and lectern at the front (+Z).
	_glow(Vector3(7.0, 2.6, 0.05), Vector3(0, 2.6, hd - 0.05), Color(0.95, 0.96, 1.0))
	_text("URBAN FOLKLORE 101\nLecture 7: Legends of the Night Streets", Vector3(0, 2.7, hd - 0.1), Vector3.BACK, 44, Color(0.2, 0.22, 0.35))
	_box(Vector3(0.9, 1.1, 0.6), Vector3(-3.0, 0.55, hd - 1.8), Color(0.45, 0.32, 0.26))
	_person(Vector3(-3.0, 0, hd - 1.1), Vector3(0, 0, -hd), false, "Prof. Kanzaki", "calm")
	# Tiered rows rising toward the back; the walkway in front stays flat.
	var students := 0
	for tier in 4:
		var y := tier * 0.35
		var z := hd - 4.5 - tier * 1.8
		if tier > 0:
			_box(Vector3(s.x - 4.0, y, 1.8), Vector3(1.5, y * 0.5, z), Color(0.5, 0.36, 0.3), true, false)
		_box(Vector3(s.x - 5.0, 0.08, 0.5), Vector3(1.5, y + 0.75, z + 0.55), Color(0.62, 0.46, 0.36))
		for k in 5:
			if (tier + k) % 2 == 0 and students < 7:
				students += 1
				_person(Vector3(-3.5 + k * 2.4, y, z - 0.1), Vector3(0, y, hd), true)
	_spot(Vector3(-hw + 2.2, 0, hd - 4.5), "Attend lecture", "lecture")
	_box(Vector3(1.4, 1.8, 0.5), Vector3(-hw + 0.5, 0.9, -hd + 2.5), Color(0.55, 0.4, 0.3))
	_spot(Vector3(-hw + 1.6, 0, -hd + 2.5), "Library shelf", "library")
	_windows(hw, 3, s.z, s.y)


func _boutique(s: Vector3) -> void:
	var hw := s.x * 0.5
	var hd := s.z * 0.5
	var garments := [Color(0.95, 0.45, 0.6), Color(0.3, 0.35, 0.6), Color(0.98, 0.95, 0.9), Color(0.5, 0.85, 0.75),
		Color(0.8, 0.2, 0.3), Color(0.6, 0.5, 0.85), Color(0.95, 0.8, 0.45), Color(0.2, 0.2, 0.25)]
	# Clothing rails along both side walls.
	for side in [-1.0, 1.0]:
		var rail_x: float = side * (hw - 0.9)
		_box(Vector3(0.06, 0.06, 5.0), Vector3(rail_x, 1.75, 0.5), Color(0.75, 0.7, 0.6), false)
		for post in [-1.0, 1.0]:
			_box(Vector3(0.06, 1.75, 0.06), Vector3(rail_x, 0.88, 0.5 + post * 2.5), Color(0.75, 0.7, 0.6))
		for k in 12:
			var g: Color = garments[(k + (3 if side > 0 else 0)) % garments.size()]
			_box(Vector3(0.5, 0.95, 0.06), Vector3(rail_x, 1.22, -1.6 + k * 0.38), g, false)
	# Dressed mannequins on round plinths in the middle.
	for i in 3:
		var p := Vector3(-2.4 + i * 2.4, 0, 1.6)
		Toon.add_mesh(root, Toon.cylinder(0.55, 0.2), Color(0.95, 0.93, 0.95), p + Vector3(0, 0.1, 0), true, 0.02)
		var m := Mannequin.new()
		m.outfit = garments[i * 2 + 1]
		m.hair = Color(0.95, 0.95, 0.97)
		m.skin = Color(0.97, 0.96, 0.95)
		m.hair_style = ["bob", "long", "ponytail"][i]
		m.position = p + Vector3(0, 0.2, 0)
		m.rotation.y = PI + (i - 1) * 0.4
		root.add_child(m)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.55
		cyl.height = 2.0
		shape.shape = cyl
		shape.position = p + Vector3(0, 1.0, 0)
		_static.add_child(shape)
	# Fitting room with curtain and a tall mirror.
	var room := Vector3(hw - 1.4, 0, hd - 1.3)
	_box(Vector3(0.08, 2.4, 2.2), room + Vector3(-1.2, 1.2, 0), Color(0.95, 0.85, 0.9))
	_box(Vector3(2.0, 2.2, 0.06), room + Vector3(0, 1.2, -1.1), Color(0.9, 0.4, 0.55), false)
	_glow(Vector3(1.0, 2.0, 0.05), Vector3(-hw + 0.06, 1.2, hd - 2.0) + Vector3(0.0, 0, 0), Color(0.85, 0.92, 1.0))
	_spot(Vector3(-hw + 1.0, 0, hd - 2.0), "Mirror", "wardrobe")
	# Counter.
	var counter := Vector3(2.5, 0, hd - 1.4)
	_box(Vector3(3.0, 1.0, 0.8), counter + Vector3(0, 0.5, 0), Color(1.0, 0.75, 0.85))
	_person(counter + Vector3(0, 0, 0.9), counter + Vector3(0, 0, -3), false, "Stylist Rei", "flirty")
	_spot(counter + Vector3(0, 0, -1.1), "Counter", "shop_boutique")
	_text("LUMIERE", Vector3(0, s.y - 0.7, hd - 0.02), Vector3.FORWARD, 72, Color(0.9, 0.4, 0.65))
	_plant(Vector3(-hw + 0.6, 0, -hd + 0.6))
	_plant(Vector3(hw - 0.6, 0, -hd + 0.6))
