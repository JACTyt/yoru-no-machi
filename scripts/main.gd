extends Node3D
## The city sandbox: sky, procedural city with traffic and pedestrians, the heroine, enterable
## places, vehicles (jacking, taxis as fast travel), map and waypoints, HUD and the save slot.
## Also the `world` that interactions.gd talks to.

const InputSetup := preload("res://scripts/input_setup.gd")
const PlayerScript := preload("res://scripts/combat/heroine.gd")
const ThugScript := preload("res://scripts/combat/thug.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Hud := preload("res://scripts/hud.gd")
const InteractionWheel := preload("res://scripts/interaction_wheel.gd")
const Interactions := preload("res://scripts/interactions.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const SaveSystem := preload("res://scripts/save_system.gd")
const SaveIndicator := preload("res://scripts/save_indicator.gd")
const PlayerState := preload("res://scripts/player_state.gd")
const CarScript := preload("res://scripts/car.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const City := preload("res://scripts/city/city_builder.gd")
const Traffic := preload("res://scripts/city/traffic.gd")
const Pedestrians := preload("res://scripts/npc/pedestrians.gd")
const Civilian := preload("res://scripts/npc/civilian.gd")
const Pickup := preload("res://scripts/npc/pickup.gd")
const InteriorBuilder := preload("res://scripts/interiors/interior_builder.gd")
const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const MapScreen := preload("res://scripts/ui/map_screen.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const Phone := preload("res://scripts/ui/phone.gd")
const BusMenu := preload("res://scripts/ui/bus_menu.gd")
const Story := preload("res://scripts/story.gd")
const Items := preload("res://scripts/items.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Settings := preload("res://scripts/settings.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const SKY_SHADER := preload("res://shaders/anime_sky.gdshader")

const ENTER_DISTANCE := 4.0
const DOOR_DISTANCE := 2.2
const SPOT_DISTANCE := 1.5
const PICKUP_DISTANCE := 1.3
const WAYPOINT_ARRIVE := 9.0
const JACK_MAX_SPEED := 2.5
const AUTOSAVE_INTERVAL := 60.0
const AUTOSAVE_RETRY := 5.0
const TAXI_BASE_FARE := 300
const TAXI_PER_METER := 4
## Parked cars around the start: [lane position, travel direction, model, color].
const PARKED := [
	[Vector3(City.PARK_OFFSET, 0, 14), Vector3.BACK, "coupe", Color(0.95, 0.3, 0.45)],
	[Vector3(-City.PARK_OFFSET, 0, -16), Vector3.FORWARD, "sedan", Color(0.3, 0.75, 0.95)],
	[Vector3(16, 0, -City.PARK_OFFSET), Vector3.RIGHT, "compact", Color(1.0, 0.82, 0.25)],
	[Vector3(City.CELL - City.PARK_OFFSET, 0, 20), Vector3.FORWARD, "van", Color(0.6, 0.4, 0.95)],
]
## [model, price, display name, blurb]
const RENTALS := [
	["compact", 1500, "Kei EV", "Tiny electric runabout. Charge it at a Volt Charge station."],
	["sedan", 2500, "City Sedan", "Comfortable four-door with a big petrol tank."],
	["van", 3000, "Family Van", "Room for everyone. Slow, steady, petrol."],
	["coupe", 5000, "Sport Coupe", "Low, loud and fast. Drinks petrol like water."],
]
const BUS_FARE := 210
const BUS_DISTANCE := 3.0
const SEAT_DISTANCE := 1.3
const VENDING_DISTANCE := 1.5
const STATION_RADIUS := 8.0
## Full tank / battery price.
const FUEL_PRICE := {"gas": 3500, "ev": 1800}
const THUG_RESPAWN := 40.0
const THUG_SPOTS := [Vector3(9.2, 0.3, -20), Vector3(-9.2, 0.3, -24), Vector3(22, 0.3, -9.2), Vector3(-20, 0.3, 9.2),
	Vector3(36, 0.3, 9.2), Vector3(-36, 0.3, -9.2), Vector3(9.2, 0.3, 40), Vector3(-9.2, 0.3, 36)]
const SITTING_CLIP := "ual1/Sitting_Idle"
const SIT_FORWARD := 0.42
const DELIVERY_FEE := 200
## Boutique outfit sets: colour presets (GameSettings.PRESETS indices) for each clothing part.
const STYLES := [
	{"id": "night_courier", "name": "Night Courier", "price": 2800, "rarity": 1, "parts": {"tops": 1, "bottoms": 1, "shoes": 4},
		"desc": "All-black street look with crimson boots. Built for long nights on the bike."},
	{"id": "sakura_spring", "name": "Sakura Spring", "price": 2400, "rarity": 0, "parts": {"tops": 9, "bottoms": 3, "shoes": 9},
		"desc": "Ivory top, sakura-pink bottom. Soft, bright, very Sakuragaoka."},
	{"id": "ocean_breeze", "name": "Ocean Breeze", "price": 2400, "rarity": 0, "parts": {"tops": 8, "bottoms": 9, "shoes": 8},
		"desc": "Harbour blues with crisp ivory. Smells like summer, apparently."},
	{"id": "neon_mint", "name": "Neon Mint", "price": 3200, "rarity": 1, "parts": {"tops": 5, "bottoms": 1, "shoes": 5},
		"desc": "Mint over midnight. Glows nicely under the Kitano signs."},
	{"id": "honey_cafe", "name": "Honey Cafe", "price": 2000, "rarity": 0, "parts": {"tops": 6, "bottoms": 2, "shoes": 6},
		"desc": "Warm honey tones with ash-silver. Weekend cafe energy."},
	{"id": "royal_violet", "name": "Royal Violet", "price": 3600, "rarity": 2, "parts": {"tops": 7, "bottoms": 1, "shoes": 7},
		"desc": "Deep violet statement piece. Stylist Rei's personal favourite."},
]
const TV_NEWS := [
	"...and the Hoshimachi summer festival returns next week, with fireworks over the harbor.",
	"Police report a string of street fights in Kitano Heights. Witnesses describe 'a girl with a red scarf'.",
	"Weather: clear skies all week. Perfect for cherry blossom viewing in Sakuragaoka.",
	"Breaking: a taxi driver claims his passenger 'teleported' across the city. Experts are baffled.",
	"Idol group STARLIGHT announces a surprise live show at the university.",
]
const LORE := [
	"Hoshimachi was a fishing village until the rail line arrived. The old shrine still stands in Old Town.",
	"Legend says a guardian spirit walks the night streets, protecting anyone who is kind to strangers.",
	"The Ring Road was built in a single summer. Locals call it 'the halo'.",
	"Kitano Heights was the first district with electric streetlights — the poles are still there.",
]

var player
var rig
var city
var traffic
var pedestrians
var dialogue
var carrying := {} ## {"npc": Civilian, "item": String} while holding a lost item.
var driving = null
var inside := "" ## Place id while in an interior.
var interior := {}

var hud
var minimap
var map_screen
var wheel
var save_indicator
var hint: Label
var prompt: Label
var sun: DirectionalLight3D
var env: Environment

var _autosave_t := AUTOSAVE_INTERVAL
var _lock_t := 0.0
var _busy := false
var _fade: ColorRect
var _beacon: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var shop
var phone
var bus_menu
var _thug_t := THUG_RESPAWN
var settings_menu
var _bought := false
var _owned_cars := {} ## owned-car index → spawned car
var _ambience: AudioStreamPlayer


func _enter_tree() -> void:
	InputSetup.ensure()
	GameSettings.load_profile()


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	city = City.new()
	add_child(city)

	rig = CameraRigScript.new()
	add_child(rig)
	player = PlayerScript.new()
	player.rig = rig
	player.position = player.spawn_point
	add_child(player)
	rig.set_target(player, 4.2, 1.4)

	# Street thugs hanging around the starting intersection; they leave you alone unless provoked.
	for i in 4:
		_spawn_thug(THUG_SPOTS[i])
	for p in PARKED:
		_spawn_car(p[2], p[3], Transform3D(Basis(Vector3.UP, atan2(p[1].x, p[1].z)), p[0] + Vector3.UP * 0.3))

	traffic = Traffic.new()
	traffic.city = city
	traffic.player = player
	add_child(traffic)
	pedestrians = Pedestrians.new()
	pedestrians.city = city
	pedestrians.player = player
	add_child(pedestrians)
	_build_waypoint_beacon()

	_build_ui()
	_apply_save()


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.1
	env.fog_light_color = Color(0.86, 0.88, 0.97)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	# One orthogonal shadow map instead of cascades: with the cel shader's hard light/shadow step,
	# building shadows vanished past the first cascade, leaving a dark ring around the camera.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	add_child(sun)
	_set_outdoors(true)


## Daylight and fog outside; warm ambient, no sun inside rooms.
func _set_outdoors(outdoors: bool) -> void:
	sun.visible = outdoors
	env.fog_enabled = outdoors
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.56, 0.85) if outdoors else Color(0.82, 0.76, 0.8)
	env.ambient_light_energy = 0.65 if outdoors else 0.55
	if pedestrians != null:
		pedestrians.enabled = outdoors
	if _beacon != null:
		_beacon.visible = outdoors and PlayerState.has_waypoint


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hint = _ui_label(16, Color(0.9, 0.92, 1.0))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_left = 20
	hint.offset_bottom = -16
	layer.add_child(hint)
	prompt = _ui_label(24, Color(1.0, 0.95, 0.8))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.offset_bottom = -120
	layer.add_child(prompt)

	hud = Hud.new()
	add_child(hud)
	hud.bind(player, GameSettings.heroine_name())
	minimap = Minimap.new()
	minimap.city = city
	add_child(minimap)
	wheel = InteractionWheel.new()
	wheel.options_provider = _wheel_options
	add_child(wheel)
	dialogue = DialogueBox.new()
	dialogue.closed.connect(func():
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(dialogue)
	save_indicator = SaveIndicator.new()
	add_child(save_indicator)
	var pause_menu := PauseMenu.new()
	pause_menu.before_leave = func(): autosave(true)
	add_child(pause_menu)
	# After the pause menu so it sees M / Esc first while open.
	shop = ShopScreen.new()
	add_child(shop)
	bus_menu = BusMenu.new()
	bus_menu.city = city
	bus_menu.chosen.connect(_ride_bus)
	add_child(bus_menu)
	phone = Phone.new()
	phone.world = self
	add_child(phone)
	settings_menu = SettingsMenu.new()
	add_child(settings_menu)
	shop.closed.connect(func():
		if _bought:
			_bought = false
			player.perform("ual1/Interact"))
	Settings.ensure_loaded()
	Sfx.music(self, "music_city", -16.0)
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = Sfx.stream("ambience")
	_ambience.bus = "SFX"
	_ambience.volume_db = -16.0
	add_child(_ambience)
	_ambience.play()
	map_screen = MapScreen.new()
	map_screen.city = city
	add_child(map_screen)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)


func _ui_label(size: int, color: Color) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = color
	s.outline_size = 6
	s.outline_color = Color(0.08, 0.04, 0.14)
	l.label_settings = s
	return l


func _build_waypoint_beacon() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.9
	mesh.height = 70.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.4, 0.7, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon = MeshInstance3D.new()
	_beacon.mesh = mesh
	_beacon.material_override = mat
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.visible = false
	add_child(_beacon)


# --- World API (used by interactions.gd) ------------------------------------------------------

func notify(text: String, color := Color(0.95, 0.97, 1.0)) -> void:
	hud.toast(text, color)


## Spends `amount` (negative earns). Returns false, with a message, if she can't afford it.
func pay(amount: int) -> bool:
	if amount > PlayerState.money:
		notify("Not enough money (%s)" % PlayerState.format_money(amount), Color(1.0, 0.5, 0.5))
		return false
	PlayerState.money -= amount
	if amount < 0:
		notify("+" + PlayerState.format_money(-amount), Color(1.0, 0.9, 0.5))
	elif amount > 0:
		notify("-" + PlayerState.format_money(amount), Color(1.0, 0.75, 0.6))
	return true


func lock_player(seconds: float) -> void:
	_lock_t = maxf(_lock_t, seconds)


func set_waypoint(pos: Vector3, label := "") -> void:
	PlayerState.set_waypoint(pos)
	notify("Waypoint: %s" % label if not label.is_empty() else "Waypoint set", Color(1.0, 0.6, 0.8))


func clear_waypoint() -> void:
	PlayerState.clear_waypoint()


func spawn_pickup(npc) -> void:
	var item := Pickup.new()
	item.item = npc.request["item"]
	item.owner_npc = npc
	# Somewhere on a nearby sidewalk loop, 15-35 m away.
	var angle := _rng.randf() * TAU
	var spot: Vector3 = npc.global_position + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(15.0, 35.0)
	item.position = _sidewalk_point(spot)
	add_child(item)
	set_waypoint(item.position, item.item.capitalize())


func hearts(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _heart_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1.0, 0.45, 0.65)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = mat
	p.one_shot = true
	p.amount = 9
	p.lifetime = 1.4
	p.explosiveness = 0.75
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


static func _heart_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in 24:
		var t := TAU * i / 24.0
		pts.append(Vector3(16.0 * pow(sin(t), 3), 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t), 0) / 17.0)
	for i in pts.size():
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[i])
		st.add_vertex(pts[(i + 1) % pts.size()])
	return st.commit()


# --- Saving -----------------------------------------------------------------------------------

## Restores position, health, money and waypoint; a new game starts at home.
func _apply_save() -> void:
	var data := SaveSystem.load_current()
	if data.is_empty():
		PlayerState.reset()
		if city.places.has("home"):
			player.position = city.places["home"]["door"] + Vector3.UP * 0.2
			player.spawn_point = player.position
		if SaveSystem.slot >= 0:
			notify("Welcome home, %s." % GameSettings.heroine_name().get_slice(" ", 0), Color(1.0, 0.75, 0.85))
			autosave.call_deferred(true)
		return
	PlayerState.from_dict(data)
	var p = data.get("position")
	if p is Array and p.size() == 3:
		player.position = Vector3(p[0], p[1], p[2]) + Vector3.UP * 0.2
		player.spawn_point = player.position
	player.hp = clampf(float(data.get("hp", player.max_hp)), 1.0, player.max_hp)
	player.health_changed.emit(player.hp, player.max_hp)


## Writes the current slot. Unless forced, only saves when it is safe to resume from here.
func autosave(force := false) -> bool:
	if SaveSystem.slot < 0 or not player.is_alive():
		return false
	if not force and not _safe_to_save():
		return false
	var pos: Vector3 = player.global_position
	if not inside.is_empty():
		pos = city.places[inside]["door"]
	elif driving != null:
		pos = driving.global_position + driving.global_basis.x * 2.2 + Vector3.UP
	var data := {"position": [pos.x, pos.y, pos.z], "hp": player.hp, "district": inside_name() if not inside.is_empty() else City.district_name(pos)}
	data.merge(PlayerState.to_dict())
	var ok := SaveSystem.save(data)
	if ok:
		save_indicator.flash()
	return ok


func _safe_to_save() -> bool:
	if _busy or driving != null or not player.is_on_floor() or Engine.time_scale < 1.0 or dialogue.is_open:
		return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.hostile and enemy.is_alive():
			return false
	return true


func inside_name() -> String:
	return city.places[inside]["name"] if not inside.is_empty() else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		autosave(true)


# --- Context action (F) -----------------------------------------------------------------------

## The best thing to do with F right now: {"label", "action"} or {}.
func _context() -> Dictionary:
	if _busy or player == null:
		return {}
	if driving != null:
		var st := _station_at(driving.global_position)
		if not st.is_empty() and driving.linear_velocity.length() < 1.5 and driving.fuel < 0.99:
			var verb := "Recharge" if st["kind"] == "ev" else "Refuel"
			return {"label": "%s  %s" % [verb, PlayerState.format_money(_fuel_cost(st))], "action": _refuel.bind(st)}
		return {"label": "Exit vehicle", "action": _exit_car}
	var pos: Vector3 = player.global_position
	if not inside.is_empty():
		if pos.distance_to(interior["exit"]) < DOOR_DISTANCE:
			return {"label": "Exit to street", "action": exit_place}
		for spot in interior["spots"]:
			if pos.distance_to(spot["pos"]) < SPOT_DISTANCE:
				return {"label": spot["label"], "action": _spot_action.bind(spot["action"])}
		return {}
	for id in city.places:
		if pos.distance_to(city.places[id]["door"]) < DOOR_DISTANCE:
			return {"label": "Enter %s" % city.places[id]["name"], "action": enter_place.bind(id)}
	if player.visual.force_clip == SITTING_CLIP:
		return {"label": "Stand up", "action": _stand}
	for i in city.bus_stops.size():
		if pos.distance_to(city.bus_stops[i]["pos"]) < BUS_DISTANCE:
			return {"label": "Take the bus  (%s)" % city.bus_stops[i]["name"], "action": func(): bus_menu.open(city.bus_stops, i, BUS_FARE)}
	for v in city.vending_machines:
		if pos.distance_to(v["pos"]) < VENDING_DISTANCE:
			return {"label": "Vending machine", "action": _open_shop.bind("vending")}
	for seat in city.seats:
		if pos.distance_to(seat["pos"]) < SEAT_DISTANCE:
			return {"label": "Sit down", "action": _sit.bind(seat)}
	var car = _nearest_car()
	if car != null:
		if car.has_driver and car.model == "taxi":
			return {"label": "Take a taxi", "action": _hail_taxi.bind(car)}
		if car.has_driver:
			return {"label": "Pull out the driver", "action": _jack.bind(car)}
		return {"label": "Get in", "action": _enter_car.bind(car)}
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if dialogue.is_open or wheel.is_open or phone.is_open:
		return
	for k in 4:
		if event.is_action_pressed("item_%d" % (k + 1)):
			var id: String = PlayerState.hotbar[k]
			if id.is_empty() or int(PlayerState.inventory.get(id, 0)) <= 0:
				notify("Slot %d is empty — assign items in Phone → Bag" % (k + 1), Color(1.0, 0.75, 0.6))
			else:
				use_item(id)
			return
	if event.is_action_pressed("interact"):
		var ctx := _context()
		if not ctx.is_empty():
			ctx["action"].call()
	elif event.is_action_pressed("map") and not map_screen.is_open:
		map_screen.open(_map_position(), _map_heading())


func _wheel_options() -> Array:
	var opts := []
	var ctx := _context()
	if not ctx.is_empty():
		opts.append({"label": ctx["label"], "enabled": true, "action": ctx["action"]})
	if driving == null:
		opts.append_array(Interactions.options(self, player))
	return opts


# --- Places -----------------------------------------------------------------------------------

func _fade_to(alpha: float, seconds := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, seconds)
	await tw.finished


## Puts the camera straight behind the heroine looking along `dir`.
func _snap_camera(dir: Vector3) -> void:
	rig.yaw = atan2(-dir.x, -dir.z)
	rig.global_position = player.global_position + Vector3.UP * rig.height


func enter_place(id: String, fade := true) -> void:
	if _busy or not inside.is_empty():
		return
	_busy = true
	if fade:
		await _fade_to(1.0)
	Sfx.play(self, "door")
	var kind: String = {"home": "apartment"}.get(id, id)
	interior = InteriorBuilder.new().build(kind, self)
	inside = id
	player.global_position = interior["spawn"]
	player.velocity = Vector3.ZERO
	player.face_towards(interior["spawn"] + Vector3.BACK)
	_snap_camera(Vector3.BACK)
	_set_outdoors(false)
	if fade:
		await _fade_to(0.0)
	_busy = false
	notify(city.places[id]["name"], city.places[id]["color"].lightened(0.3))


func exit_place() -> void:
	if _busy or inside.is_empty():
		return
	_busy = true
	Sfx.play(self, "door")
	await _fade_to(1.0)
	var place: Dictionary = city.places[inside]
	interior["root"].queue_free()
	interior = {}
	inside = ""
	player.global_position = place["door"] + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	player.face_towards(place["door"] + place["front"])
	_snap_camera(place["front"])
	_set_outdoors(true)
	await _fade_to(0.0)
	_busy = false


func _spot_action(action: String) -> void:
	match action:
		"sleep":
			_busy = true
			await _fade_to(1.0, 0.8)
			player.hp = player.max_hp
			player.health_changed.emit(player.hp, player.max_hp)
			await get_tree().create_timer(0.8).timeout
			_busy = false
			autosave(true)
			await _fade_to(0.0, 0.8)
			notify("Well rested. Game saved.", Color(0.8, 0.9, 1.0))
		"wardrobe":
			_wardrobe()
		"fridge":
			player.perform("ual2/Consume")
			_heal(25.0, "A snack from the fridge")
		"tv":
			_tv()
		"shop_konbini":
			_open_shop("konbini")
		"shop_boutique":
			_open_shop("boutique")
		"shop_pharmacy":
			_open_shop("pharmacy")
		"rent":
			_open_shop("rent")
		"class", "lecture":
			_busy = true
			await _fade_to(1.0, 0.8)
			await get_tree().create_timer(1.0).timeout
			await _fade_to(0.0, 0.8)
			_busy = false
			dialogue.open("Ms. Ishida" if action == "class" else "Prof. Kanzaki", LORE[_rng.randi() % LORE.size()] + "\n\n...and that's all for today.", [], Color(0.6, 0.8, 1.0))
		"library":
			dialogue.open("Library", "You pull an old book from the shelf.\n\n" + LORE[_rng.randi() % LORE.size()], [], Color(0.85, 0.7, 0.5))


func _heal(amount: float, what: String) -> void:
	player.hp = minf(player.hp + amount, player.max_hp)
	player.health_changed.emit(player.hp, player.max_hp)
	notify("%s  +%d HP" % [what, int(amount)] if amount > 0.0 else what, Color(0.6, 1.0, 0.7))


# --- Shops, items, fuel ------------------------------------------------------------------------

func _item_entry(id: String) -> Dictionary:
	var it: Dictionary = Items.ITEMS[id]
	var fx := []
	if it["heal"] > 0:
		fx.append("+%d HP" % it["heal"])
	if it["stamina"] > 0:
		fx.append("+%d stamina" % it["stamina"])
	return {"id": id, "name": it["name"], "icon": it["icon"], "price": it["price"], "desc": it["desc"],
		"effect": "   ".join(fx), "rarity": it["rarity"], "tint": Color(0.35, 0.75, 1.0) if id == "drink" else Color(0.95, 0.95, 1.0)}


func _open_shop(kind: String) -> void:
	var def := {}
	match kind:
		"konbini":
			def = {"title": "24H MART", "subtitle": "Clerk Mori  ·  open all night", "accent": Color(0.4, 0.75, 1.0),
				"categories": [{"name": "Food", "items": ["onigiri", "melonpan", "bento"].map(_item_entry)},
					{"name": "Drinks", "items": ["coffee", "drink", "energy"].map(_item_entry)}]}
		"pharmacy":
			def = {"title": "PHARMACY", "subtitle": "Pharmacist Sato  ·  Hoshimachi Central", "accent": Color(0.4, 0.95, 0.6),
				"categories": [{"name": "Medicine", "items": ["bandage", "pills", "medkit"].map(_item_entry)},
					{"name": "Tonics", "items": ["energy", "coffee"].map(_item_entry)}]}
		"vending":
			def = {"title": "VENDING MACHINE", "subtitle": "Ice cold. Probably.", "accent": Color(1.0, 0.4, 0.45),
				"categories": [{"name": "Drinks", "items": ["drink", "coffee", "energy"].map(_item_entry)}]}
		"rent":
			var cars := []
			for r in RENTALS:
				var spec := CarScript.CarModels.spec(r[0])
				cars.append({"id": "rent_" + r[0], "name": r[2], "icon": "car_" + r[0], "price": r[1], "desc": r[3], "max": 1,
					"tint": Color.from_hsv(0.08 * cars.size() + 0.55, 0.5, 0.95), "rarity": mini(cars.size(), 2),
					"effect": "%s  ·  top speed %d km/h" % ["Electric" if spec.get("electric", false) else "Petrol", int(spec["top_speed"] * 3.6)]})
			def = {"title": "RENT-A-CAR", "subtitle": "Agent Kudo  ·  cars wait outside the door", "accent": Color(1.0, 0.7, 0.3),
				"categories": [{"name": "Cars", "items": cars}]}
		"boutique":
			var sets := []
			for st in STYLES:
				var owned: bool = PlayerState.styles.has(st["id"])
				sets.append({"id": "style_" + st["id"], "name": st["name"], "icon": "dress", "tint": Color(GameSettings.PRESETS[st["parts"]["tops"]][1]),
					"price": 0 if owned else st["price"], "desc": st["desc"], "rarity": st["rarity"], "max": 1, "owned": 1 if owned else 0,
					"effect": "Owned — wear it again for free" if owned else "Top, bottom and shoes recoloured"})
			var cats := [{"name": "Outfit sets", "items": sets}]
			var variants := GameSettings.outfit_list()
			if variants.size() > 1:
				var outfits := []
				for v in variants.slice(1):
					outfits.append({"id": "outfit_" + v[1], "name": v[0], "icon": "dress", "tint": Color(0.95, 0.75, 0.9), "price": 0, "max": 1,
						"desc": "A complete outfit for %s." % GameSettings.heroine_name(), "rarity": 2, "effect": "Changes the whole outfit"})
				cats.append({"name": "Outfits", "items": outfits})
			def = {"title": "LUMIERE BOUTIQUE", "subtitle": "Stylist Rei  ·  try anything on", "accent": Color(1.0, 0.55, 0.8), "categories": cats}
	def["on_buy"] = _shop_buy
	shop.open(def)


func _shop_buy(entry: Dictionary, qty: int) -> bool:
	var total: int = int(entry["price"]) * qty
	if not pay(total):
		return false
	var id: String = entry["id"]
	_bought = true
	Sfx.play(self, "purchase")
	if id.begins_with("style_"):
		var st: Dictionary = STYLES.filter(func(x): return x["id"] == id.trim_prefix("style_"))[0]
		if not PlayerState.styles.has(st["id"]):
			PlayerState.styles.append(st["id"])
		for part in st["parts"]:
			GameSettings.look()[part] = st["parts"][part]
		GameSettings.apply_look(player.visual)
		GameSettings.save_profile()
		notify("Wearing %s" % st["name"], Color(1.0, 0.7, 0.9))
		return true
	if id.begins_with("outfit_"):
		GameSettings.outfits[GameSettings.heroine] = id.trim_prefix("outfit_")
		player.reload_visual()
		GameSettings.save_profile()
		return true
	if id.begins_with("rent_"):
		_spawn_car(id.trim_prefix("rent_"), entry["tint"], city.places["car_rental"]["park"])
		notify("Your %s is parked outside" % entry["name"], Color(1.0, 0.8, 0.45))
	else:
		PlayerState.add_item(id, qty)
		notify("%s x%d added to your bag  (P → Bag)" % [entry["name"], qty], Color(1.0, 0.8, 0.9))
	return true


## Eats / drinks / applies an item from the bag.
func use_item(id: String) -> void:
	if int(PlayerState.inventory.get(id, 0)) <= 0:
		return
	var it: Dictionary = Items.ITEMS[id]
	PlayerState.add_item(id, -1)
	player.restore_stamina(float(it["stamina"]))
	Sfx.play(self, "heal")
	if driving == null:
		player.perform("ual2/Consume")
	_heal(float(it["heal"]), it["name"])


func _station_at(pos: Vector3) -> Dictionary:
	for id in city.stations:
		var st: Dictionary = city.stations[id]
		if Vector2(pos.x, pos.z).distance_to(Vector2(st["center"].x, st["center"].z)) < STATION_RADIUS:
			return st
	return {}


func _fuel_cost(st: Dictionary) -> int:
	return snappedi(int((1.0 - driving.fuel) * FUEL_PRICE[st["kind"]]), 10)


func _refuel(st: Dictionary) -> void:
	if driving.electric != (st["kind"] == "ev"):
		notify("This car runs on %s — find a %s" % ["electricity" if driving.electric else "petrol", "Volt Charge station" if driving.electric else "petrol station"], Color(1.0, 0.7, 0.5))
		return
	if not pay(_fuel_cost(st)):
		return
	_busy = true
	var car = driving
	var tw := create_tween()
	tw.tween_property(car, "fuel", 1.0, 1.5)
	await tw.finished
	_busy = false
	notify("Fully charged" if car.electric else "Tank full", Color(0.6, 1.0, 0.7))


# --- Benches, buses ---------------------------------------------------------------------------

func _sit(seat: Dictionary) -> void:
	var facing := Vector3(sin(seat["yaw"]), 0, cos(seat["yaw"]))
	# The sitting clip lowers the hips backwards; start forward so she lands on the seat.
	player.global_position = seat["pos"] + facing * SIT_FORWARD + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.face_towards(player.global_position + facing)
	player.play_emote(SITTING_CLIP)


func _stand() -> void:
	player.visual.force_clip = ""
	player.global_position += player.forward_dir() * 0.5


func _ride_bus(index: int) -> void:
	if not pay(BUS_FARE):
		return
	var stop: Dictionary = city.bus_stops[index]
	_busy = true
	await _fade_to(1.0, 0.5)
	notify("Riding the bus...", Color(0.6, 0.85, 1.0))
	await get_tree().create_timer(1.0).timeout
	player.global_position = stop["pos"] + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	player.face_towards(stop["pos"] + stop["front"])
	_snap_camera(-stop["front"])
	await _fade_to(0.0, 0.5)
	_busy = false
	notify(stop["name"], Color(0.6, 0.85, 1.0))


# --- Phone, story, thugs ----------------------------------------------------------------------

func open_map() -> void:
	map_screen.open(_map_position(), _map_heading())


func story_reply(contact: String, index: int) -> void:
	var fx := Story.reply(contact, index)
	if fx.has("waypoint") and city.places.has(fx["waypoint"]):
		var place: Dictionary = city.places[fx["waypoint"]]
		set_waypoint(place["door"], place["name"])


func _story_tick(delta: float) -> void:
	var delivered := Story.tick(delta, inside)
	for id in delivered:
		var info: Dictionary = Story.CONTACTS[Story.contact_of(id)]
		notify("New message from %s  (P)" % info["name"], info["color"].lightened(0.3))
		Sfx.play(self, "notify")
		var money := Story.money_of(id)
		if money > 0:
			notify("+" + PlayerState.format_money(money), Color(1.0, 0.9, 0.5))
	if not delivered.is_empty():
		phone.refresh()


func _spawn_thug(pos: Vector3) -> void:
	var thug = ThugScript.new()
	thug.position = pos
	thug.target = player
	thug.hostile = false
	thug.calm_down = true
	thug.died.connect(func(_t): PlayerState.bump("thugs_defeated"))
	add_child(thug)


## Grin Masks drift back onto the streets over time, out of the heroine's sight.
func _respawn_thugs(delta: float) -> void:
	_thug_t -= delta
	if _thug_t > 0.0:
		return
	_thug_t = THUG_RESPAWN
	if get_tree().get_nodes_in_group("enemies").size() >= 4 or not inside.is_empty():
		return
	var spots := THUG_SPOTS.filter(func(p): return p.distance_to(player.global_position) > 35.0)
	if not spots.is_empty():
		_spawn_thug(spots[_rng.randi() % spots.size()])


func _wardrobe() -> void:
	var look := GameSettings.look()
	var choices := []
	for part in GameSettings.PARTS:
		var idx := int(look.get(part, 0))
		choices.append({"label": "%s:  ‹ %s ›" % [GameSettings.PARTS[part][0], GameSettings.PRESETS[idx][0]], "action": func():
			look[part] = (idx + 1) % GameSettings.PRESETS.size()
			GameSettings.apply_look(player.visual)
			_wardrobe()})
	var outfits := GameSettings.outfit_list()
	if outfits.size() > 1:
		choices.insert(0, {"label": "Outfit:  ‹ %s ›" % outfits[GameSettings.outfit_index()][0], "action": func():
			GameSettings.cycle_outfit()
			player.reload_visual()
			_wardrobe()})
	choices.append({"label": "Done", "action": GameSettings.save_profile})
	dialogue.open("Wardrobe", "Pick an outfit, or a part to change its colour.", choices, Color(1.0, 0.6, 0.78))


func _tv() -> void:
	dialogue.open("TV", TV_NEWS[_rng.randi() % TV_NEWS.size()], [
		{"label": "Keep watching", "action": _tv},
		{"label": "Turn it off", "action": Callable()},
	], Color(0.5, 0.75, 1.0))


# --- Vehicles ---------------------------------------------------------------------------------

func _spawn_car(model: String, color: Color, xform: Transform3D):
	var car = CarScript.new()
	car.model = model
	car.color = color
	car.transform = xform
	add_child(car)
	return car


func _nearest_car():
	var best = null
	var best_dist := ENTER_DISTANCE
	for car in get_tree().get_nodes_in_group("cars"):
		var dist: float = car.global_position.distance_to(player.global_position)
		if dist < best_dist:
			best = car
			best_dist = dist
	return best


func _enter_car(car) -> void:
	if car.has_driver:
		return
	Sfx.play(self, "door", car.global_position)
	driving = car
	car.autopilot = false
	car.active = true
	player.set_driving(true)
	rig.set_target(car, 7.0, 1.8)


func _exit_car() -> void:
	var car = driving
	driving = null
	car.active = false
	player.global_position = car.global_position + car.global_basis.x * 2.2 + Vector3.UP
	player.set_driving(false)
	rig.set_target(player, 4.2, 1.4)
	_autosave_t = minf(_autosave_t, 2.0)


## Drags the driver out (right-hand drive: the driver sits on the car's right, local -X), then
## takes the wheel.
func _jack(car) -> void:
	if absf(car.forward_speed()) > JACK_MAX_SPEED:
		notify("Wait until the car stops", Color(1.0, 0.8, 0.6))
		return
	_busy = true
	car.autopilot = false
	car.has_driver = false
	PlayerState.bump("cars_stolen")
	var side: Vector3 = -car.global_basis.x
	side.y = 0.0
	side = side.normalized()
	var door: Vector3 = car.global_position + side * 1.4
	player.global_position = Vector3(door.x, player.global_position.y, door.z)
	player.face_towards(car.global_position)
	player.perform("ual1/Push", 1.2)
	await get_tree().create_timer(0.35).timeout
	var driver := Civilian.new()
	driver.block_center = _nearest_block(door)
	driver.position = door + side * 0.6 + Vector3.UP * 0.3
	pedestrians.add_child(driver)
	driver.eject(side * 4.0)
	get_tree().call_group("civilians", "witness", door, driver)
	await get_tree().create_timer(0.7).timeout
	_busy = false
	_enter_car(car)


func _hail_taxi(car) -> void:
	car.hold = true
	var choices := []
	for id in city.places:
		var place: Dictionary = city.places[id]
		choices.append({"label": "%s  %s" % [place["name"], PlayerState.format_money(_fare(place["door"]))],
			"action": _ride.bind(car, place["door"], place["name"])})
	if PlayerState.has_waypoint:
		var w := _sidewalk_point(PlayerState.waypoint)
		choices.append({"label": "My waypoint  %s" % PlayerState.format_money(_fare(w)), "action": _ride.bind(car, w, "your waypoint")})
	choices.append({"label": "Never mind", "action": func(): car.hold = false})
	dialogue.open("Taxi driver", "Hop in! Where to?", choices, Color(1.0, 0.75, 0.25))
	dialogue.closed.connect(func():
		if is_instance_valid(car) and not _busy:
			car.hold = false, CONNECT_ONE_SHOT)


func _fare(dest: Vector3) -> int:
	return snappedi(int(TAXI_BASE_FARE + player.global_position.distance_to(dest) * TAXI_PER_METER), 10)


## The taxi "arrives" with her: it is moved to the curb by the destination and drops her off on the
## sidewalk side, then drives away.
func _ride(car, dest: Vector3, label: String) -> void:
	if not pay(_fare(dest)):
		car.hold = false
		return
	_busy = true
	Sfx.play(self, "door", car.global_position)
	await _fade_to(1.0, 0.5)
	var spot := _curb_spot(dest)
	if is_instance_valid(car):
		traffic.place_on_road(car, spot["pos"], spot["dir"])
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(car):
				car.hold = false)
	var out: Vector3 = spot["pos"] + spot["side"] * 2.2
	player.global_position = Vector3(out.x, City.CURB_H + 0.3, out.z)
	player.velocity = Vector3.ZERO
	player.face_towards(player.global_position + spot["side"])
	_snap_camera(spot["side"])
	await get_tree().create_timer(0.4).timeout
	await _fade_to(0.0, 0.5)
	_busy = false
	notify("Arrived at %s" % label, Color(1.0, 0.85, 0.4))


# --- CarGo (phone) ----------------------------------------------------------------------------

## Curb parking spot on the road nearest to `p`: {"pos", "dir" (travel), "side" (toward p's sidewalk)}.
func _curb_spot(p: Vector3) -> Dictionary:
	var lim := City.GRID * City.CELL
	var kx := clampf(roundf(p.x / City.CELL), -City.GRID, City.GRID) * City.CELL
	var kz := clampf(roundf(p.z / City.CELL), -City.GRID, City.GRID) * City.CELL
	var vertical := absf(p.x - kx) < absf(p.z - kz)
	var across := Vector3.RIGHT if vertical else Vector3.BACK
	var t := clampf(p.z if vertical else p.x, -lim + 14.0, lim - 14.0)
	# Keep clear of the intersection boxes and crossings.
	var node_t := roundf(t / City.CELL) * City.CELL
	if absf(t - node_t) < 14.0:
		t = node_t + (14.0 if t >= node_t else -14.0)
	var road := Vector3(kx, 0, t) if vertical else Vector3(t, 0, kz)
	var side := signf((p - road).dot(across))
	if side == 0.0:
		side = 1.0
	var dir := Vector3(0, 0, side) if vertical else Vector3(-side, 0, 0)
	return {"pos": road + across * side * City.PARK_OFFSET, "dir": dir, "side": across * side}


func _deliver(model: String, color: Color):
	var spot := _curb_spot(player.global_position if driving == null else driving.global_position)
	var car = _spawn_car(model, color, Transform3D(Basis(Vector3.UP, atan2(spot["dir"].x, spot["dir"].z)), spot["pos"] + Vector3.UP * 0.4))
	Sfx.play(self, "horn", spot["pos"])
	set_waypoint(spot["pos"], "your car")
	return car


func deliver_owned_car(index: int) -> void:
	if not pay(DELIVERY_FEE):
		return
	if _owned_cars.has(index) and is_instance_valid(_owned_cars[index]) and _owned_cars[index] != driving:
		_owned_cars[index].queue_free()
	var c: Dictionary = PlayerState.cars[index]
	_owned_cars[index] = _deliver(c["model"], Color(c["color"]))
	notify("Your car has been delivered", Color(1.0, 0.8, 0.45))


func rent_car(model: String, price: int) -> void:
	if pay(price):
		_deliver(model, Color.from_hsv(_rng.randf(), 0.55, 0.9))
		notify("Rental delivered — enjoy the ride", Color(1.0, 0.8, 0.45))


func buy_car(model: String, price: int) -> void:
	if not pay(price):
		return
	var color := Color.from_hsv(_rng.randf(), 0.6, 0.92)
	PlayerState.cars.append({"model": model, "color": color.to_html(false)})
	_owned_cars[PlayerState.cars.size() - 1] = _deliver(model, color)
	Sfx.play(self, "purchase")
	notify("You bought a %s! It's waiting at the curb" % model.capitalize(), Color(1.0, 0.85, 0.4))


func call_taxi() -> void:
	var spot := _curb_spot(player.global_position)
	var taxi = traffic.spawn_taxi(spot["pos"], spot["dir"])
	Sfx.play(self, "horn", spot["pos"])
	notify("Your taxi is here", Color(1.0, 0.8, 0.3))
	# Leaves again if nobody gets in.
	get_tree().create_timer(60.0).timeout.connect(func():
		if is_instance_valid(taxi) and not _busy:
			taxi.hold = false)


func open_settings() -> void:
	settings_menu.open()


# --- Helpers ----------------------------------------------------------------------------------

static func _nearest_block(p: Vector3) -> Vector3:
	var half := (City.BLOCKS - 1) / 2.0
	var ix := clampf(roundf(p.x / City.CELL + half), 0, City.BLOCKS - 1)
	var iz := clampf(roundf(p.z / City.CELL + half), 0, City.BLOCKS - 1)
	return Vector3((ix - half) * City.CELL, 0, (iz - half) * City.CELL)


## Closest point on the nearest block's sidewalk loop.
static func _sidewalk_point(p: Vector3) -> Vector3:
	var c := _nearest_block(p)
	var local := p - c
	var r := Civilian.RING
	if absf(local.x) > absf(local.z):
		local = Vector3(signf(local.x) * r, 0, clampf(local.z, -r, r))
	else:
		local = Vector3(clampf(local.x, -r, r), 0, signf(local.z) * r if local.z != 0.0 else r)
	return c + local + Vector3.UP * City.CURB_H


## Where the heroine is for maps and waypoints: the building she is in, the car she drives, or her.
func _map_position() -> Vector3:
	if not inside.is_empty():
		return city.places[inside]["door"]
	return driving.global_position if driving != null else player.global_position


func _map_heading() -> Vector3:
	return driving.global_basis.z if driving != null else player.forward_dir()


func _process(delta: float) -> void:
	SaveSystem.play_time += delta
	_autosave_t -= delta
	if _autosave_t <= 0.0:
		_autosave_t = AUTOSAVE_INTERVAL if autosave() else AUTOSAVE_RETRY
	_lock_t = maxf(_lock_t - delta, 0.0)
	player.input_locked = wheel.is_open or dialogue.is_open or phone.is_open or settings_menu.is_open or _busy or _lock_t > 0.0
	hint.visible = Settings.get_value("show_hints")
	_ambience.stream_paused = not inside.is_empty()
	minimap.visible = not phone.is_open
	_story_tick(delta)
	_respawn_thugs(delta)
	hud.fuel = driving.fuel if driving != null else -1.0
	hud.fuel_electric = driving != null and driving.electric

	# Lost items are picked up by walking over them.
	for item in get_tree().get_nodes_in_group("pickups"):
		if item.global_position.distance_to(player.global_position) < PICKUP_DISTANCE and driving == null:
			if is_instance_valid(item.owner_npc):
				carrying = {"npc": item.owner_npc, "item": item.item}
				set_waypoint(item.owner_npc.global_position, item.owner_npc.npc_name)
			player.perform("ual1/PickUp_Table", 1.3)
			Sfx.play(self, "pickup")
			notify("Found the %s!" % item.item, Color(1.0, 0.9, 0.5))
			item.queue_free()

	if PlayerState.has_waypoint:
		if not carrying.is_empty() and is_instance_valid(carrying["npc"]):
			PlayerState.waypoint = carrying["npc"].global_position
		var here := _map_position()
		if inside.is_empty() and Vector2(here.x, here.z).distance_to(Vector2(PlayerState.waypoint.x, PlayerState.waypoint.z)) < WAYPOINT_ARRIVE and carrying.is_empty():
			PlayerState.clear_waypoint()
			notify("You have arrived", Color(1.0, 0.6, 0.8))
	_beacon.visible = PlayerState.has_waypoint and inside.is_empty()
	if _beacon.visible:
		_beacon.global_position = PlayerState.waypoint + Vector3.UP * 35.0

	var cam_yaw: float = rig.yaw
	minimap.track(_map_position(), _map_heading(), cam_yaw, inside_name())

	var ctx := _context()
	prompt.text = "[F]  %s" % ctx["label"] if not ctx.is_empty() and not dialogue.is_open and not wheel.is_open else ""
	var controls := "WASD move · Shift run · Space jump\nLMB / RMB / E attack · C block · R parry · X crouch · Z prone · Q lock-on\n1-4 items · Tab interact · F use · P phone · M map · Esc pause"
	if driving != null:
		hint.text = "%d km/h\n%s" % [int(driving.linear_velocity.length() * 3.6), controls]
	else:
		hint.text = controls
