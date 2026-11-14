extends CanvasLayer
## Settings overlay (from the title screen, pause menu or phone): audio, controls, camera, display.
## Changes apply immediately and are saved on close.

signal closed

const Settings := preload("res://scripts/settings.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

## [key, label, kind, extra]: kind slider → [min, max, step, format], toggle, choice → options.
const ROWS := [
	["", "Audio", "header", null],
	["master_volume", "Master volume", "slider", [0.0, 1.0, 0.05, "%d%%"]],
	["music_volume", "Music", "slider", [0.0, 1.0, 0.05, "%d%%"]],
	["sfx_volume", "Sound effects", "slider", [0.0, 1.0, 0.05, "%d%%"]],
	["", "Controls & camera", "header", null],
	["mouse_sensitivity", "Mouse sensitivity", "slider", [0.3, 2.5, 0.05, "%.2fx"]],
	["invert_y", "Invert camera Y", "toggle", null],
	["camera_shake", "Camera shake", "toggle", null],
	["fov", "Field of view", "slider", [55.0, 95.0, 1.0, "%d°"]],
	["", "Display", "header", null],
	["fullscreen", "Fullscreen", "toggle", null],
	["vsync", "V-Sync", "toggle", null],
	["shadows", "Shadow quality", "choice", ["Low", "High"]],
	["show_hints", "Show control hints", "toggle", null],
]

var is_open := false
var _root: Control
var _font: Font


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = MenuStyle.font()
	Settings.ensure_loaded()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var title := Label.new()
	title.text = "SETTINGS"
	title.label_settings = MenuStyle.label_settings(_font, 52, Color(0.88, 0.92, 1.0), 0.35)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 110
	scroll.offset_bottom = -90
	scroll.offset_left = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	center.add_child(grid)
	for row in ROWS:
		_add_row(grid, row)

	var back := Button.new()
	back.text = "Back"
	back.flat = true
	back.add_theme_font_override("font", _font)
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_color_override("font_color", MenuStyle.TEXT_DIM)
	back.add_theme_color_override("font_hover_color", Color.WHITE)
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back.grow_horizontal = Control.GROW_DIRECTION_BOTH
	back.offset_top = -80
	back.offset_bottom = -30
	back.pressed.connect(close)
	_root.add_child(back)


func _add_row(grid: GridContainer, row: Array) -> void:
	var key: String = row[0]
	var label := Label.new()
	label.text = row[1]
	var header: bool = row[2] == "header"
	label.label_settings = MenuStyle.label_settings(_font, 26 if header else 20, Color(0.75, 0.85, 1.0) if header else MenuStyle.TEXT_LIT, 0.0)
	label.custom_minimum_size = Vector2(320, 40)
	grid.add_child(label)
	match row[2]:
		"header":
			grid.add_child(Control.new())
		"slider":
			var box := HBoxContainer.new()
			box.custom_minimum_size.x = 380
			var slider := HSlider.new()
			slider.min_value = row[3][0]
			slider.max_value = row[3][1]
			slider.step = row[3][2]
			slider.value = Settings.get_value(key)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var value := Label.new()
			value.custom_minimum_size.x = 80
			value.label_settings = MenuStyle.label_settings(_font, 18, MenuStyle.TEXT_DIM, 0.0)
			var fmt: String = row[3][3]
			var show := func(v: float): value.text = fmt % (v * 100.0 if fmt == "%d%%" else v)
			show.call(slider.value)
			slider.value_changed.connect(func(v: float):
				Settings.set_value(key, v)
				show.call(v))
			slider.drag_ended.connect(func(_changed): Sfx.play(self, "ui_move"))
			box.add_child(slider)
			box.add_child(value)
			grid.add_child(box)
		"toggle":
			var check := CheckButton.new()
			check.button_pressed = Settings.get_value(key)
			check.toggled.connect(func(on: bool):
				Settings.set_value(key, on)
				Sfx.play(self, "ui_move"))
			grid.add_child(check)
		"choice":
			var opt := OptionButton.new()
			for o in row[3]:
				opt.add_item(o)
			opt.selected = maxi(row[3].find(Settings.get_value(key)), 0)
			opt.item_selected.connect(func(i: int): Settings.set_value(key, row[3][i]))
			grid.add_child(opt)


func open() -> void:
	is_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play(self, "ui_confirm")


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	Settings.save()
	Sfx.play(self, "ui_back")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or (InputMap.has_action("pause") and event.is_action_pressed("pause"))):
		close()
		get_viewport().set_input_as_handled()
