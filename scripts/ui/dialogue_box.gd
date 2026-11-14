extends CanvasLayer
## Visual-novel style dialogue: skewed name plate, typewriter text, numbered choices on the right.
## Choose with the mouse, 1-9, or Up/Down + Enter/F. A choice whose action does not open a new
## line closes the box.

signal opened
signal closed

const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const CHARS_PER_SEC := 60.0
const PANEL_H := 230.0

var is_open := false

var _panel: Control
var _name: Label
var _text: Label
var _choice_labels: Array[Label] = []
var _choices: Array = []
var _selected := 0
var _shown := 0.0
var _accent := Color(0.6, 0.8, 1.0)
var _generation := 0
var _font: Font


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = MenuStyle.font()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 70
	_panel.offset_right = -70
	_panel.offset_top = -PANEL_H - 34
	_panel.offset_bottom = -34
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	_panel.visible = false
	add_child(_panel)

	_name = Label.new()
	_name.label_settings = MenuStyle.label_settings(_font, 26, Color(0.06, 0.04, 0.1), 0.0)
	_name.position = Vector2(38, -22)
	_panel.add_child(_name)

	_text = Label.new()
	var ts := LabelSettings.new()
	ts.font_size = 24
	ts.font_color = Color(0.94, 0.95, 1.0)
	ts.outline_size = 4
	ts.outline_color = Color(0.04, 0.02, 0.08)
	ts.line_spacing = 6
	_text.label_settings = ts
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(40, 34)
	_panel.add_child(_text)


## `choices`: [{"label": String, "action": Callable}]; none means a single "Continue".
func open(speaker: String, text: String, choices: Array = [], accent := Color(0.6, 0.8, 1.0)) -> void:
	_generation += 1
	var was_open := is_open
	is_open = true
	_accent = accent
	_name.text = speaker
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_choices = choices if not choices.is_empty() else [{"label": "Continue", "action": Callable()}]
	for l in _choice_labels:
		l.queue_free()
	_choice_labels.clear()
	for i in _choices.size():
		var l := Label.new()
		l.text = "%d.  %s" % [i + 1, _choices[i]["label"]]
		l.label_settings = MenuStyle.label_settings(_font, 21, MenuStyle.TEXT_DIM, 0.0)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_choice_input.bind(i))
		_panel.add_child(l)
		_choice_labels.append(l)
	# Grow the panel when there are many choices.
	_panel.offset_top = -maxf(PANEL_H, _choices.size() * 34.0 + 50.0) - 34.0
	_layout()
	_select(0)
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not was_open:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)
		opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	closed.emit()


func _layout() -> void:
	var w := _panel.size.x
	var h := _panel.size.y
	var choice_w := 420.0
	_text.size = Vector2(w - choice_w - 90, h - 50)
	var y := h * 0.5 - _choices.size() * 17.0
	for l in _choice_labels:
		l.position = Vector2(w - choice_w, y)
		l.size = Vector2(choice_w - 30, 30)
		y += 34.0


func _select(i: int) -> void:
	_selected = i
	for j in _choice_labels.size():
		_choice_labels[j].label_settings.font_color = MenuStyle.TEXT_LIT if j == i else MenuStyle.TEXT_DIM
		_choice_labels[j].label_settings.shadow_color.a = 0.4 if j == i else 0.0
	_panel.queue_redraw()


func _on_choice_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_choose(i)


func _input(event: InputEvent) -> void:
	if not is_open or get_tree().paused:
		return
	var handled := true
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_select((_selected + 1) % _choices.size())
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_select((_selected - 1 + _choices.size()) % _choices.size())
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_choose(_selected)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and event.keycode >= KEY_1 and event.keycode < KEY_1 + _choices.size():
		_choose(event.keycode - KEY_1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _choose(i: int) -> void:
	# The first press only finishes the typewriter.
	if _text.visible_ratio < 1.0:
		_shown = _text.text.length()
		_text.visible_characters = -1
		return
	var action: Callable = _choices[i]["action"]
	var gen := _generation
	if action.is_valid():
		action.call()
	if gen == _generation:
		close()


func _process(delta: float) -> void:
	if not is_open:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)
	if _text.visible_ratio < 1.0:
		_shown += dt * CHARS_PER_SEC
		_text.visible_characters = int(_shown)
		if _shown >= _text.text.length():
			_text.visible_characters = -1
	_layout()
	_panel.queue_redraw()


func _draw_panel() -> void:
	var s := _panel.size
	# Body: dark glass with a soft accent wash on the left.
	_panel.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.08, 0.86))
	_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(s.x * 0.4, s.y)), Color(_accent, 0.06))
	MenuStyle.flourish(_panel, Vector2(s.x * 0.5, 0), s.x * 0.5, 1.0, Color(_accent, 0.85))
	MenuStyle.flourish(_panel, Vector2(s.x * 0.5, 0), s.x * 0.5, -1.0, Color(_accent, 0.85))
	MenuStyle.diamond(_panel, Vector2(s.x * 0.5, 0), 5.0, _accent)
	_panel.draw_line(Vector2(s.x - 450, 24), Vector2(s.x - 450, s.y - 24), Color(MenuStyle.ORNAMENT, 0.25), 1.0, true)
	# Skewed name plate.
	var w := maxf(_name.get_minimum_size().x + 56.0, 160.0)
	var plate := PackedVector2Array([Vector2(24, -26), Vector2(24 + w, -26), Vector2(10 + w, 12), Vector2(10, 12)])
	_panel.draw_colored_polygon(plate, _accent)
	# Selection marker and "more" blink when the text is done.
	if _selected < _choice_labels.size():
		var l := _choice_labels[_selected]
		MenuStyle.diamond(_panel, l.position + Vector2(-16, 15), 5.0, MenuStyle.ORNAMENT)
	if _text.visible_ratio >= 1.0 and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0:
		MenuStyle.diamond(_panel, Vector2(s.x - 470, s.y - 26), 4.0, Color(MenuStyle.ORNAMENT, 0.7))
