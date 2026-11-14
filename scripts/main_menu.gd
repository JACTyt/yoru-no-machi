extends Control
## Title screen: atmospheric backdrop, drifting light motes, serif title, ornamented menu.

const TITLE := "ANIME CITY"
const SUBTITLE := "~ working title ~"
const BG_SHADER := preload("res://shaders/menu_background.gdshader")

const GameSettings := preload("res://scripts/game_settings.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const Settings := preload("res://scripts/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
## [label, scene path]
const ITEMS := [
	["Start Game", "res://scenes/save_select.tscn"],
	["Heroine", "res://scenes/heroine_select.tscn"],
	["Combat Arena", "res://scenes/test_combat.tscn"],
	["Character Studio", "res://scenes/test_character.tscn"],
	["Settings", "settings"],
	["Quit", ""],
]

var font: Font
var title: Label
var labels: Array[Label] = []
var selected := 0
var fade: ColorRect
var busy := false
var _time := 0.0
var _marker_x := 0.0
var _settings


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.load_profile()
	Settings.ensure_loaded()
	Sfx.music(self, "music_menu")
	font = MenuStyle.font()
	_settings = SettingsMenu.new()
	add_child(_settings)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = BG_SHADER
	bg.material = bg_mat
	add_child(bg)
	# Draw ornaments above the background but below the text.
	bg.show_behind_parent = true

	MenuStyle.add_motes(self, 90, Vector2(0.08, 0.3), 0.55)
	MenuStyle.add_motes(self, 18, Vector2(0.5, 1.0), 0.25)
	_build_title()
	_build_items()

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 2.0).set_ease(Tween.EASE_OUT)
	title.modulate.a = 0.0
	create_tween().tween_property(title, "modulate:a", 1.0, 3.0).set_delay(0.5)
	_select(0)


func _build_title() -> void:
	title = Label.new()
	title.text = TITLE
	title.label_settings = MenuStyle.label_settings(font, 104, Color(0.88, 0.92, 1.0), 0.35)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position.y = get_viewport_rect().size.y * 0.16

	# Subtitle sits under the divider drawn in _draw().
	var sub := Label.new()
	sub.text = SUBTITLE
	sub.label_settings = MenuStyle.label_settings(font, 20, Color(0.6, 0.68, 0.8), 0.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(sub)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.position.y = title.get_minimum_size().y + 26.0


func _build_items() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.position.y += 120
	add_child(box)
	for i in ITEMS.size():
		var l := Label.new()
		l.text = _item_text(i)
		l.label_settings = MenuStyle.label_settings(font, 30, MenuStyle.TEXT_DIM, 0.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_item_input.bind(i))
		box.add_child(l)
		labels.append(l)


func _on_item_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_activate(i)


func _select(i: int) -> void:
	if busy:
		return
	if i != selected:
		Sfx.play(self, "ui_move")
	selected = i
	for j in labels.size():
		var lit := j == i
		labels[j].label_settings.font_color = MenuStyle.TEXT_LIT if lit else MenuStyle.TEXT_DIM
		labels[j].label_settings.shadow_color.a = 0.45 if lit else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if busy or _settings.is_open:
		return
	if event.is_action_pressed("ui_down"):
		_select((selected + 1) % labels.size())
	elif event.is_action_pressed("ui_up"):
		_select((selected - 1 + labels.size()) % labels.size())
	elif event.is_action_pressed("ui_accept"):
		_activate(selected)


func _item_text(i: int) -> String:
	return ITEMS[i][0]


func _activate(i: int) -> void:
	if busy:
		return
	if ITEMS[i][1] == "settings":
		_settings.open()
		return
	Sfx.play(self, "ui_confirm")
	_select(i)
	busy = true
	var target: String = ITEMS[i][1]
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0).set_ease(Tween.EASE_IN)
	if target.is_empty():
		tween.tween_callback(get_tree().quit)
	else:
		tween.tween_callback(get_tree().change_scene_to_file.bind(target))


func _process(delta: float) -> void:
	_time += delta
	if not labels.is_empty():
		var l := labels[selected]
		_marker_x = lerpf(_marker_x, l.size.x * 0.5 + 34.0, 1.0 - exp(-12.0 * delta))
	queue_redraw()


func _draw() -> void:
	# Divider under the title: tapering lines meeting at a diamond.
	var center_x := size.x * 0.5
	var div_y := title.position.y + title.get_minimum_size().y + 12.0
	var a := title.modulate.a
	MenuStyle.flourish(self, Vector2(center_x, div_y), 260.0, 1.0, Color(MenuStyle.ORNAMENT, 0.7 * a))
	MenuStyle.flourish(self, Vector2(center_x, div_y), 260.0, -1.0, Color(MenuStyle.ORNAMENT, 0.7 * a))
	MenuStyle.diamond(self, Vector2(center_x, div_y), 7.0, Color(MenuStyle.ORNAMENT, a))

	if labels.is_empty():
		return
	# Selection marks either side of the highlighted item, gently breathing.
	var l := labels[selected]
	var mid := l.global_position + l.size * 0.5 - global_position
	var pulse := 0.75 + 0.25 * sin(_time * 3.0)
	for side in [-1.0, 1.0]:
		var p := mid + Vector2(side * _marker_x, 0)
		MenuStyle.diamond(self, p, 5.0, Color(MenuStyle.ORNAMENT, pulse))
		MenuStyle.flourish(self, p + Vector2(side * 8.0, 0), 40.0, side, Color(MenuStyle.ORNAMENT, 0.6 * pulse))
