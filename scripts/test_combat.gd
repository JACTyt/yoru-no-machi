extends Node3D
## Combat arena: neon night courtyard, waves of thugs, HUD with health, hit counter and dodge callouts.

const Toon := preload("res://scripts/toon.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const Heroine := preload("res://scripts/combat/heroine.gd")
const Thug := preload("res://scripts/combat/thug.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Hud := preload("res://scripts/hud.gd")
const InteractionWheel := preload("res://scripts/interaction_wheel.gd")
const Interactions := preload("res://scripts/interactions.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const FONT_PATH := "res://fonts/Cinzel.ttf"

var heroine
var rig
var wave := 0
var alive := 0
var combo_label: Label
var callout: Label
var info: Label


func _ready() -> void:
	InputSetup.ensure()
	_build_arena()
	rig = CameraRig.new()
	add_child(rig)
	heroine = Heroine.new()
	heroine.rig = rig
	heroine.spawn_point = Vector3(0, 0.2, 0)
	heroine.position = heroine.spawn_point
	add_child(heroine)
	rig.set_target(heroine, 4.2, 1.4)
	heroine.hit_landed.connect(_on_hit)
	heroine.perfect_dodge.connect(func(): _callout("PERFECT DODGE", Color(0.6, 0.9, 1.0)))
	heroine.died.connect(func(): _callout("K.O.", Color(1.0, 0.3, 0.4)))
	heroine.parried.connect(func(): _callout("PARRY!", Color(1.0, 0.85, 0.35)))
	heroine.guard_broken.connect(func(): _callout("GUARD BREAK", Color(1.0, 0.45, 0.4)))
	Sfx.music(self, "music_city", -14.0)
	_build_hud()
	var hud := Hud.new()
	add_child(hud)
	hud.bind(heroine, GameSettings.heroine_name())
	var wheel := InteractionWheel.new()
	wheel.options_provider = func(): return Interactions.emotes(heroine)
	wheel.opened.connect(func(): heroine.input_locked = true)
	wheel.closed.connect(func(): heroine.input_locked = false)
	add_child(wheel)
	add_child(PauseMenu.new())
	_next_wave()


func _build_arena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.04, 0.12)
	sky_mat.sky_horizon_color = Color(0.25, 0.12, 0.32)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.05, 0.04, 0.08)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.28, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.18, 0.4)
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	add_child(moon)

	var ground := StaticBody3D.new()
	add_child(ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	Toon.add_mesh(ground, plane, Color(0.2, 0.19, 0.26), Vector3.ZERO, false)
	Toon.add_mesh(ground, Toon.cylinder(12.0, 0.04), Color(0.3, 0.27, 0.38), Vector3(0, 0.02, 0), false)

	# Ring of pillars with neon caps; they double as cover and light sources.
	for i in 8:
		var a := TAU * i / 8.0
		var pos := Vector3(sin(a), 0, cos(a)) * 14.0
		var pillar := StaticBody3D.new()
		pillar.position = pos
		add_child(pillar)
		var col := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = Vector3(1.4, 6, 1.4)
		col.shape = pbox
		col.position.y = 3
		pillar.add_child(col)
		Toon.add_mesh(pillar, Toon.box(Vector3(1.4, 6, 1.4)), Color(0.35, 0.33, 0.45), Vector3(0, 3, 0), true, 0.06)
		var neon := Color(1.0, 0.3, 0.7) if i % 2 == 0 else Color(0.25, 0.85, 1.0)
		var cap := Toon.add_mesh(pillar, Toon.box(Vector3(1.6, 0.3, 1.6)), neon, Vector3(0, 6.15, 0), false)
		(cap.material_override as ShaderMaterial).set_shader_parameter("emission", neon * 1.5)
		var omni := OmniLight3D.new()
		omni.light_color = neon
		omni.omni_range = 9.0
		omni.light_energy = 1.4
		omni.position = Vector3(0, 5.5, 0)
		pillar.add_child(omni)


func _build_hud() -> void:
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var layer := CanvasLayer.new()
	add_child(layer)

	info = _label(font, 16, Color(0.85, 0.88, 1.0))
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.offset_left = 24
	info.offset_bottom = -16
	layer.add_child(info)

	combo_label = _label(font, 54, Color(1.0, 0.85, 0.4))
	combo_label.anchor_left = 1.0
	combo_label.anchor_right = 1.0
	combo_label.offset_left = -420
	combo_label.offset_right = -40
	combo_label.offset_top = 160
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.pivot_offset = Vector2(380, 40)
	layer.add_child(combo_label)

	callout = _label(font, 44, Color.WHITE)
	callout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	callout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	callout.offset_top = 120
	callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout.modulate.a = 0.0
	layer.add_child(callout)


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = color
	s.outline_size = maxi(size / 6, 4)
	s.outline_color = Color(0.08, 0.03, 0.12)
	l.label_settings = s
	return l


func _next_wave() -> void:
	wave += 1
	var count := 2 + wave
	alive = count
	for i in count:
		var thug = Thug.new()
		var a := TAU * i / count + randf() * 0.3
		thug.position = Vector3(sin(a), 0.1, cos(a)) * 9.0
		thug.target = heroine
		thug.max_hp = 50.0 + wave * 10.0
		thug.hp = thug.max_hp
		thug.color = Color.from_hsv(randf_range(0.6, 0.8), 0.35, 0.35)
		thug.died.connect(_on_thug_died)
		add_child(thug)
	_callout("WAVE %d" % wave, Color(1.0, 0.85, 0.4))


func _on_thug_died(_thug) -> void:
	alive -= 1
	if alive <= 0:
		get_tree().create_timer(1.5).timeout.connect(_next_wave)


func _on_hit(count: int) -> void:
	combo_label.text = "%d HITS" % count if count > 1 else ""
	combo_label.scale = Vector2.ONE * 1.35
	create_tween().tween_property(combo_label, "scale", Vector2.ONE, 0.15)


func _callout(text: String, color: Color) -> void:
	callout.text = text
	callout.label_settings.font_color = color
	callout.modulate.a = 1.0
	callout.scale = Vector2.ONE * 1.2
	var tw := create_tween()
	tw.tween_property(callout, "scale", Vector2.ONE, 0.2)
	tw.tween_interval(0.9)
	tw.tween_property(callout, "modulate:a", 0.0, 0.4)


func _process(_delta: float) -> void:
	var lock := "on" if heroine.lock_target != null else "off"
	info.text = "Wave %d · enemies %d · lock-on %s\nWASD move · Shift run · LMB combo · RMB spin kick · E strong · C block · R parry · X crouch · Z prone · Q lock-on · Tab interact · Space jump · Esc pause" % [wave, alive, lock]
	if heroine._hit_count == 0:
		combo_label.text = ""
