extends CanvasLayer
## In-game pause menu (Esc): freezes the tree, blurs the frame, title-screen styling.

const FONT_PATH := "res://fonts/Cinzel.ttf"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const BLUR_SHADER := preload("res://shaders/pause_blur.gdshader")
const TimeScale := preload("res://scripts/combat/time_scale.gd")

const ITEMS := ["Resume", "Restart", "Settings", "Main Menu", "Quit"]
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const TEXT_DIM := Color(0.55, 0.6, 0.7)
const TEXT_LIT := Color(0.95, 0.97, 1.0)
const ORNAMENT := Color(0.8, 0.88, 1.0)

## Gameplay scenes recapture the mouse on resume; the character studio keeps it free.
var capture_mouse_on_resume := true
## Called before going to the main menu or quitting (the city autosaves here).
var before_leave: Callable

var is_open := false
var _root: Control
var _backdrop_mat: ShaderMaterial
var _title: Label
var _labels: Array[Label] = []
var _selected := 0
var _busy := false
var _time := 0.0
var _settings


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	_root = Ornaments.new()
	_root.menu = self
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = BLUR_SHADER
	backdrop.material = _backdrop_mat
	backdrop.show_behind_parent = true
	_root.add_child(backdrop)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(box)

	_settings = SettingsMenu.new()
	_settings.closed.connect(func(): _root.visible = true)
	add_child(_settings)

	_title = _make_label(font, 64, Color(0.88, 0.92, 1.0), 0.35)
	_title.text = "PAUSED"
	box.add_child(_title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36
	box.add_child(spacer)
	for i in ITEMS.size():
		var l := _make_label(font, 28, TEXT_DIM, 0.0)
		l.text = ITEMS[i]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_item_input.bind(i))
		box.add_child(l)
		_labels.append(l)


func _make_label(font: Font, size: int, color: Color, glow: float) -> Label:
	var s := LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = color
	s.shadow_color = Color(0.5, 0.7, 1.0, glow)
	s.shadow_size = int(size * 0.35)
	s.shadow_offset = Vector2.ZERO
	var l := Label.new()
	l.label_settings = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	# Another overlay (map, travel) already paused the game and owns Esc.
	if not is_open and get_tree().paused:
		return
	if _settings.is_open:
		return
	if event.is_action_pressed("pause"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open:
		if event.is_action_pressed("ui_down"):
			_select((_selected + 1) % _labels.size())
		elif event.is_action_pressed("ui_up"):
			_select((_selected - 1 + _labels.size()) % _labels.size())
		elif event.is_action_pressed("ui_accept"):
			_activate(_selected)
		else:
			return
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_select(0)
	_root.modulate.a = 0.0
	_backdrop_mat.set_shader_parameter("fade", 0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 1.0, 0.18)
	tw.tween_method(func(v: float): _backdrop_mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.25)


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false
	if capture_mouse_on_resume:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_item_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_activate(i)


func _select(i: int) -> void:
	if i != _selected and is_open:
		Sfx.play(self, "ui_move")
	_selected = i
	for j in _labels.size():
		var lit := j == i
		_labels[j].label_settings.font_color = TEXT_LIT if lit else TEXT_DIM
		_labels[j].label_settings.shadow_color.a = 0.45 if lit else 0.0


func _activate(i: int) -> void:
	match ITEMS[i]:
		"Resume":
			close()
		"Settings":
			_root.visible = false
			_settings.open()
		"Restart":
			_leave(func(): get_tree().reload_current_scene())
		"Main Menu":
			if before_leave.is_valid():
				before_leave.call()
			_leave(func(): get_tree().change_scene_to_file(MENU_SCENE))
		"Quit":
			if before_leave.is_valid():
				before_leave.call()
			_leave(func(): get_tree().quit())


## Fades to black, then unpauses, resets slow motion and runs `action`.
func _leave(action: Callable) -> void:
	_busy = true
	_select(_selected)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		get_tree().paused = false
		TimeScale.clear()
		action.call())


func _process(delta: float) -> void:
	_time += delta
	if is_open:
		_root.queue_redraw()


## Draws the title divider and the breathing selection diamonds, as on the title screen.
class Ornaments extends Control:
	var menu

	func _draw() -> void:
		var title: Label = menu._title
		var center_x := size.x * 0.5
		var div_y := title.global_position.y - global_position.y + title.size.y + 6.0
		_flourish(Vector2(center_x, div_y), 200.0, 1.0, Color(ORNAMENT, 0.7))
		_flourish(Vector2(center_x, div_y), 200.0, -1.0, Color(ORNAMENT, 0.7))
		_diamond(Vector2(center_x, div_y), 6.0, ORNAMENT)

		var l: Label = menu._labels[menu._selected]
		var mid := l.global_position + l.size * 0.5 - global_position
		var text_w: float = l.label_settings.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.label_settings.font_size).x if l.label_settings.font != null else 160.0
		var pulse := 0.75 + 0.25 * sin(menu._time * 3.0)
		for side in [-1.0, 1.0]:
			var p := mid + Vector2(side * (text_w * 0.5 + 30.0), 0)
			_diamond(p, 5.0, Color(ORNAMENT, pulse))
			_flourish(p + Vector2(side * 8.0, 0), 36.0, side, Color(ORNAMENT, 0.6 * pulse))

	func _diamond(c: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)

	func _flourish(from: Vector2, length: float, dir: float, color: Color) -> void:
		var steps := 12
		for s in steps:
			var t0 := float(s) / steps
			var t1 := float(s + 1) / steps
			draw_line(from + Vector2(dir * length * t0, 0), from + Vector2(dir * length * t1, 0),
					Color(color, color.a * (1.0 - t0)), lerpf(2.0, 0.5, t0), true)
