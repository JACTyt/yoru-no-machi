extends Node3D
## Character style test stage: orbit camera, lighting presets, expressions, post-process toggle.

const Toon := preload("res://scripts/toon.gd")
const AnimePost := preload("res://scripts/anime_post.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const VrmCharacter := preload("res://scripts/vrm_character.gd")

const GameSettings := preload("res://scripts/game_settings.gd")

const LIGHTING := ["Day", "Golden hour", "Night neon"]
## Clips previewed with the A key ("" = automatic idle).
const STUDIO_CLIPS := ["", "ual2/Idle_FoldArms", "ual1/Walk", "ual1/Jog_Fwd", "ual1/Sprint", "ual1/Dance", "ual2/Idle_TalkingPhone"]

var character
var camera: Camera3D
var post: Dictionary ## {"lines": MeshInstance3D, "grade": ColorRect} from AnimePost.attach
var env: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var neon: Array[OmniLight3D] = []
var info: Label

var orbit_yaw := 0.0
var orbit_pitch := -0.1
var distance := 2.6
var focus_height := 1.0
var turntable := false
var lighting := 0
var expression := 0
var clip_index := 0
var _dragging := false


func _ready() -> void:
	InputSetup.ensure()
	GameSettings.load_profile()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_stage()
	_build_camera()
	_spawn_character()
	_build_hud()
	var pause_menu := PauseMenu.new()
	pause_menu.capture_mouse_on_resume = false
	add_child(pause_menu)
	_apply_lighting()


func _build_stage() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	rim = DirectionalLight3D.new()
	add_child(rim)
	for c in [Color(1.0, 0.3, 0.7), Color(0.2, 0.8, 1.0)]:
		var omni := OmniLight3D.new()
		omni.light_color = c
		omni.omni_range = 6.0
		add_child(omni)
		neon.append(omni)
	neon[0].position = Vector3(-2.0, 2.0, -1.0)
	neon[1].position = Vector3(2.0, 1.5, 1.5)

	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	Toon.add_mesh(floor_body, Toon.cylinder(3.0, 0.1), Color(0.85, 0.82, 0.9), Vector3(0, -0.05, 0), false)
	var ground := PlaneMesh.new()
	ground.size = Vector2(60, 60)
	Toon.add_mesh(floor_body, ground, Color(0.55, 0.52, 0.65), Vector3(0, -0.1, 0), false)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.position = Vector3(0, 1.0, 2.6)
	add_child(camera)
	camera.make_current()
	post = AnimePost.attach(camera)


func _spawn_character() -> void:
	var path := GameSettings.heroine_path()
	character = VrmCharacter.new()
	character.model_scene = load(path)
	character.look_target = camera
	add_child(character)
	GameSettings.apply_look(character)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	info = Label.new()
	info.position = Vector2(20, 16)
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_constant_override("outline_size", 6)
	info.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	layer.add_child(info)


func _apply_lighting() -> void:
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	for omni in neon:
		omni.visible = lighting == 2
	match lighting:
		0:
			sky_mat.sky_top_color = Color(0.3, 0.55, 0.95)
			sky_mat.sky_horizon_color = Color(0.85, 0.9, 1.0)
			sun.light_color = Color(1.0, 0.97, 0.92)
			sun.light_energy = 0.75
			sun.rotation_degrees = Vector3(-40, 30, 0)
			rim.light_color = Color(0.85, 0.9, 1.0)
			rim.light_energy = 0.4
			env.ambient_light_color = Color(0.7, 0.72, 0.9)
			env.ambient_light_energy = 0.45
		1:
			sky_mat.sky_top_color = Color(0.35, 0.35, 0.75)
			sky_mat.sky_horizon_color = Color(1.0, 0.6, 0.45)
			sun.light_color = Color(1.0, 0.72, 0.45)
			sun.light_energy = 1.2
			sun.rotation_degrees = Vector3(-12, 70, 0)
			rim.light_color = Color(1.0, 0.55, 0.6)
			rim.light_energy = 0.9
			env.ambient_light_color = Color(0.6, 0.5, 0.8)
			env.ambient_light_energy = 0.55
		2:
			sky_mat.sky_top_color = Color(0.04, 0.04, 0.12)
			sky_mat.sky_horizon_color = Color(0.2, 0.1, 0.3)
			sun.light_color = Color(0.5, 0.6, 1.0)
			sun.light_energy = 0.35
			sun.rotation_degrees = Vector3(-50, -30, 0)
			rim.light_color = Color(1.0, 0.3, 0.8)
			rim.light_energy = 0.8
			env.ambient_light_color = Color(0.25, 0.22, 0.45)
			env.ambient_light_energy = 0.5
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	# Rim light comes from behind the character relative to the key light.
	rim.rotation_degrees = Vector3(-20, sun.rotation_degrees.y + 180.0, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = maxf(distance * 0.9, 0.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = minf(distance * 1.1, 8.0)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		orbit_yaw -= mm.relative.x * 0.006
		orbit_pitch = clampf(orbit_pitch - mm.relative.y * 0.004, -1.2, 0.6)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_E:
				expression = (expression + 1) % (VrmCharacter.EXPRESSIONS.size() + 1)
				character.set_expression(_expression_name(), 1.0)
			KEY_A:
				clip_index = (clip_index + 1) % STUDIO_CLIPS.size()
				character.force_clip = STUDIO_CLIPS[clip_index]
			KEY_L:
				lighting = (lighting + 1) % LIGHTING.size()
				_apply_lighting()
			KEY_P:
				post.grade.visible = not post.grade.visible
				post.lines.visible = post.grade.visible
			KEY_O:
				post.lines.visible = not post.lines.visible
			KEY_T:
				turntable = not turntable
			KEY_F:
				# Toggle between full body and face close-up.
				var face := focus_height < 1.2
				focus_height = 1.4 if face else 1.0
				distance = 0.9 if face else 2.6


func _expression_name() -> String:
	return "neutral" if expression == 0 else VrmCharacter.EXPRESSIONS[expression - 1]


func _process(delta: float) -> void:
	if turntable:
		orbit_yaw += delta * 0.5
	var offset := Basis.from_euler(Vector3(orbit_pitch, orbit_yaw, 0)) * Vector3(0, 0, distance)
	var focus := Vector3(0, focus_height, 0)
	camera.global_position = camera.global_position.lerp(focus + offset, 1.0 - exp(-10.0 * delta))
	camera.look_at(focus)

	var missing := "  — %s" % GameSettings.heroine_name()
	if GameSettings.heroine_path() != GameSettings.HEROINES[GameSettings.heroine]["path"]:
		missing += " (not exported yet — showing a fallback model)"
	var expr_label := _expression_name()
	if expression > 0 and not character.has_expression(expr_label):
		expr_label += " (not in model)"
	var clip_label: String = "clips not imported" if not character.has_clips else (STUDIO_CLIPS[clip_index] if clip_index > 0 else "idle")
	info.text = "Character style test%s\nDrag: orbit · Wheel: zoom · F: face/body · T: turntable\nE: expression [%s] · A: animation [%s] · L: lighting [%s] · P: post-process [%s] · O: ink lines · Esc: menu" % [
		missing, expr_label, clip_label, LIGHTING[lighting], "on" if post.grade.visible else "off"]
