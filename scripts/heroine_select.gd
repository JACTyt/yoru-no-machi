extends Node3D
## Title-screen heroine selection and customisation: the heroine on a lit turntable, a side panel
## to switch heroine and recolour hair, top, bottom and eyes. Saved to the profile on Confirm.

const VrmCharacter := preload("res://scripts/vrm_character.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const AnimePost := preload("res://scripts/anime_post.gd")
const Toon := preload("res://scripts/toon.gd")

const MENU_SCENE := "res://scenes/main_menu.tscn"
const BIOS := {
	"hana": "17 · Second-year at Hoshimachi High.\nQuiet and sharp-eyed; fights like she has something to prove.",
	"saki": "24 · Night courier.\nCool head, fast hands, knows every back street in the city.",
}
## Rows: "heroine", the customisable parts, then actions.
const ROWS := ["heroine", "outfit", "hair", "tops", "bottoms", "shoes", "eyes", "confirm", "back"]
## Camera distance range for mouse-wheel zoom.
const ZOOM_NEAR := 1.2
const ZOOM_FAR := 6.0

var character
var camera: Camera3D
var _rows: Array[Label] = []
var _swatches: Array[ColorRect] = []
var _bio: Label
var _selected := 0
var _yaw := 0.0
var _busy := false
var _fade: ColorRect
var _panel: Control
var _font: Font
var _saved_heroine := ""
var _saved_looks := {}
var _saved_outfits := {}
var _distance := 3.8


func _ready() -> void:
	GameSettings.load_profile()
	_saved_heroine = GameSettings.heroine
	_saved_looks = GameSettings.looks.duplicate(true)
	_saved_outfits = GameSettings.outfits.duplicate(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = MenuStyle.font()
	_build_stage()
	_spawn()
	_build_ui()
	_refresh()


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.9)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.12
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 0.8
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.7
	add_child(rim)
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	Toon.add_mesh(floor_body, Toon.cylinder(1.4, 0.1), Color(0.75, 0.8, 0.95), Vector3(0, -0.05, 0), true, 0.02)
	var ring := Toon.add_mesh(floor_body, Toon.cylinder(1.5, 0.02), Color(0.6, 0.75, 1.0), Vector3(0, -0.02, 0), false)
	(ring.material_override as ShaderMaterial).set_shader_parameter("emission", Color(0.4, 0.55, 1.0) * 0.8)
	camera = Camera3D.new()
	camera.fov = 32.0
	add_child(camera)
	_place_camera()
	camera.make_current()
	AnimePost.attach(camera)


func _spawn() -> void:
	if character != null:
		character.queue_free()
	character = VrmCharacter.new()
	character.model_scene = load(GameSettings.heroine_path())
	character.look_target = camera
	add_child(character)
	character.rotation.y = _yaw
	GameSettings.apply_look(character)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -560
	_panel.draw.connect(_draw_panel)
	layer.add_child(_panel)
	var title := Label.new()
	title.text = "HEROINE"
	title.label_settings = MenuStyle.label_settings(_font, 56, Color(0.88, 0.92, 1.0), 0.35)
	title.position = Vector2(60, 70)
	_panel.add_child(title)
	_bio = Label.new()
	_bio.label_settings = MenuStyle.label_settings(_font, 17, MenuStyle.TEXT_DIM, 0.0)
	_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio.position = Vector2(62, 210)
	_bio.size = Vector2(440, 90)
	_panel.add_child(_bio)
	var y := 150.0
	for i in ROWS.size():
		var l := Label.new()
		l.label_settings = MenuStyle.label_settings(_font, 34 if i == 0 else 24, MenuStyle.TEXT_DIM, 0.0)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_row_input.bind(i))
		l.position = Vector2(60, y)
		l.size = Vector2(440, 40)
		_panel.add_child(l)
		_rows.append(l)
		var sw := ColorRect.new()
		sw.size = Vector2(22, 22)
		sw.position = Vector2(470, y + 8)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(sw)
		_swatches.append(sw)
		y += 140.0 if i == 0 else (55.0 if ROWS[i] == "eyes" else 40.0)
	var help := Label.new()
	help.text = "↑↓ select · ←→ change · drag to rotate · wheel to zoom · Esc back"
	help.label_settings = MenuStyle.label_settings(_font, 15, MenuStyle.TEXT_DIM, 0.0)
	help.position = Vector2(62, y + 16)
	_panel.add_child(help)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 10
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)


func _refresh() -> void:
	var look := GameSettings.look()
	for i in ROWS.size():
		var row: String = ROWS[i]
		var lit := i == _selected
		var l := _rows[i]
		l.label_settings.font_color = MenuStyle.TEXT_LIT if lit else MenuStyle.TEXT_DIM
		l.label_settings.shadow_color.a = 0.45 if lit else 0.0
		_swatches[i].visible = false
		match row:
			"heroine":
				l.text = "‹  %s  ›" % GameSettings.heroine_name()
			"confirm":
				l.text = "Confirm"
			"back":
				l.text = "Back"
			"outfit":
				var outfits := GameSettings.outfit_list()
				l.text = "Outfit:   ‹ %s ›" % outfits[GameSettings.outfit_index()][0]
				if outfits.size() == 1:
					l.text += "   (no variants)"
			_:
				var idx := int(look.get(row, 0))
				l.text = "%s:   ‹ %s ›" % [GameSettings.PARTS[row][0], GameSettings.PRESETS[idx][0]]
				if idx > 0:
					_swatches[i].visible = true
					_swatches[i].color = Color(GameSettings.PRESETS[idx][1])
	_bio.text = BIOS.get(GameSettings.heroine, "")
	_panel.queue_redraw()


func _select(i: int) -> void:
	_selected = i
	_refresh()


func _change(i: int, step: int) -> void:
	var row: String = ROWS[i]
	if row == "heroine":
		GameSettings.cycle_heroine(step)
		_spawn()
	elif row == "outfit":
		GameSettings.cycle_outfit(step)
		_spawn()
	elif GameSettings.PARTS.has(row):
		var look := GameSettings.look()
		look[row] = posmod(int(look.get(row, 0)) + step, GameSettings.PRESETS.size())
		GameSettings.apply_look(character)
	_refresh()


func _activate(i: int) -> void:
	match ROWS[i]:
		"confirm":
			GameSettings.save_profile()
			_leave()
		"back":
			GameSettings.heroine = _saved_heroine
			GameSettings.looks = _saved_looks
			GameSettings.outfits = _saved_outfits
			_leave()
		_:
			_change(i, 1)


func _leave() -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	tw.tween_callback(get_tree().change_scene_to_file.bind(MENU_SCENE))


func _on_row_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# Left half of an option row steps back, right half forward.
			if ROWS[i] in ["confirm", "back"]:
				_activate(i)
			else:
				_change(i, -1 if mb.position.x < _rows[i].size.x * 0.35 else 1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_change(i, -1)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw += (event as InputEventMouseMotion).relative.x * 0.01
	elif event is InputEventMouseButton and event.is_pressed() and 			(event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), ZOOM_NEAR, ZOOM_FAR)
	elif event.is_action_pressed("ui_down"):
		_select((_selected + 1) % ROWS.size())
	elif event.is_action_pressed("ui_up"):
		_select((_selected - 1 + ROWS.size()) % ROWS.size())
	elif event.is_action_pressed("ui_left"):
		_change(_selected, -1)
	elif event.is_action_pressed("ui_right"):
		_change(_selected, 1)
	elif event.is_action_pressed("ui_accept"):
		_activate(_selected)
	elif event.is_action_pressed("ui_cancel"):
		_activate(ROWS.find("back"))


## Closer zoom frames the face; the offset keeps her clear of the side panel.
func _place_camera(delta := 1.0) -> void:
	var t := inverse_lerp(ZOOM_FAR, ZOOM_NEAR, _distance)
	var focus := Vector3(0.75 * lerpf(1.0, 0.3, t), lerpf(0.9, 1.4, t), 0)
	var goal := Vector3(focus.x, focus.y + 0.1, _distance)
	camera.position = camera.position.lerp(goal, 1.0 - exp(-10.0 * delta)) if delta < 1.0 else goal
	camera.look_at(Vector3(focus.x, focus.y, 0))


func _process(delta: float) -> void:
	_place_camera(delta)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw += delta * 0.25
	if character != null:
		character.rotation.y = _yaw


func _draw_panel() -> void:
	var s := _panel.size
	_panel.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.08, 0.72))
	_panel.draw_line(Vector2(0, 0), Vector2(0, s.y), Color(MenuStyle.ORNAMENT, 0.5), 1.5, true)
	MenuStyle.flourish(_panel, Vector2(60, 140), 300.0, 1.0, Color(MenuStyle.ORNAMENT, 0.7))
	MenuStyle.diamond(_panel, Vector2(60, 140), 5.0, MenuStyle.ORNAMENT)
	if _selected < _rows.size():
		var l := _rows[_selected]
		MenuStyle.diamond(_panel, l.position + Vector2(-20, l.size.y * 0.5), 5.0, MenuStyle.ORNAMENT)
