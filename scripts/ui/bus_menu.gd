extends CanvasLayer
## Bus fast travel: a city map with every stop, a list of destinations and a ride button.
## Pauses the game. open(stops, current_index, fare); emits `chosen(index)` or `closed`.

signal chosen(index: int)
signal closed

const MapView := preload("res://scripts/ui/map_view.gd")
const City := preload("res://scripts/city/city_builder.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const PlayerState := preload("res://scripts/player_state.gd")

const LINE := Color(0.3, 0.75, 1.0)

var city
var is_open := false
var _stops := []
var _current := 0
var _sel := -1
var _fare := 0
var _root: Control
var _view: Control
var _overlay: Control
var _list: VBoxContainer
var _info: Label
var _ride: Button
var _font: Font


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = MenuStyle.font()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var title := Label.new()
	title.text = "CITY BUS"
	title.label_settings = MenuStyle.label_settings(_font, 44, Color(0.88, 0.94, 1.0), 0.35)
	title.position = Vector2(60, 24)
	_root.add_child(title)

	var clip := Control.new()
	clip.clip_contents = true
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = 60
	clip.offset_top = 100
	clip.offset_right = -420
	clip.offset_bottom = -50
	_root.add_child(clip)
	_view = MapView.new()
	_view.labels = false
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_view)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_on_map_input)
	clip.add_child(_overlay)

	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -380
	side.offset_right = -40
	side.offset_top = 100
	side.add_theme_constant_override("separation", 10)
	_root.add_child(side)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	side.add_child(_list)
	_info = Label.new()
	_info.label_settings = MenuStyle.label_settings(_font, 18, MenuStyle.TEXT_LIT, 0.0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(340, 70)
	side.add_child(_info)
	_ride = Button.new()
	_ride.custom_minimum_size = Vector2(340, 50)
	_ride.add_theme_font_override("font", _font)
	_ride.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = LINE.lightened(0.15) if state == "hover" else (Color(0.3, 0.32, 0.38) if state == "disabled" else LINE)
		_ride.add_theme_stylebox_override(state, sb)
	_ride.add_theme_color_override("font_color", Color(0.05, 0.04, 0.1))
	_ride.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.1))
	_ride.pressed.connect(_confirm)
	side.add_child(_ride)
	var cancel := Button.new()
	cancel.text = "Not now  (Esc)"
	cancel.flat = true
	cancel.add_theme_font_override("font", _font)
	cancel.pressed.connect(close)
	side.add_child(cancel)


func open(stops: Array, current: int, fare: int) -> void:
	_stops = stops
	_current = current
	_fare = fare
	_sel = -1
	_view.city = city
	is_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in _list.get_children():
		c.queue_free()
	for i in stops.size():
		var b := Button.new()
		b.text = ("●  " if i == current else "○  ") + stops[i]["name"] + ("   (you are here)" if i == current else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.disabled = i == current
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_color_override("font_color", MenuStyle.TEXT_DIM)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
	_select(-1)
	await get_tree().process_frame
	var extent := (City.EXTENT + City.OUTER_WALK) * 2.0
	_view.zoom = minf(_view.size.x, _view.size.y) / extent
	_view.center = Vector2.ZERO
	var here: Vector3 = stops[current]["pos"]
	_view.player_pos = Vector2(here.x, here.z)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _select(i: int) -> void:
	_sel = i
	for k in _list.get_child_count():
		_list.get_child(k).add_theme_color_override("font_color", Color.WHITE if k == i else MenuStyle.TEXT_DIM)
	if i < 0:
		_info.text = "Pick a stop on the map or in the list.\nFlat fare %s." % PlayerState.format_money(_fare)
		_ride.text = "RIDE"
		_ride.disabled = true
	else:
		_info.text = "%s\nFare %s  ·  wallet %s" % [_stops[i]["name"], PlayerState.format_money(_fare), PlayerState.format_money(PlayerState.money)]
		_ride.text = "RIDE  —  %s" % PlayerState.format_money(_fare)
		_ride.disabled = _fare > PlayerState.money
	_overlay.queue_redraw()


func _confirm() -> void:
	if _sel < 0:
		return
	var i := _sel
	close()
	chosen.emit(i)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		var best := -1
		var best_d := 30.0
		for i in _stops.size():
			var p: Vector3 = _stops[i]["pos"]
			var d: float = _view.to_screen(Vector2(p.x, p.z)).distance_to(event.position)
			if d < best_d and i != _current:
				best = i
				best_d = d
		if best >= 0:
			_select(best)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_open:
		_overlay.queue_redraw()


## Bus line through the stops plus stop badges; the selected one pulses.
func _draw_overlay() -> void:
	if _stops.is_empty():
		return
	var pts := PackedVector2Array()
	for s in _stops:
		pts.append(_view.to_screen(Vector2(s["pos"].x, s["pos"].z)))
	# The line loops around the city: connect stops in order of angle around the center.
	var order := range(_stops.size())
	order.sort_custom(func(a, b): return atan2(_stops[a]["pos"].z, _stops[a]["pos"].x) < atan2(_stops[b]["pos"].z, _stops[b]["pos"].x))
	var loop := PackedVector2Array()
	for i in order:
		loop.append(pts[i])
	loop.append(loop[0])
	_overlay.draw_polyline(loop, Color(0.05, 0.04, 0.1, 0.7), 9.0, true)
	_overlay.draw_polyline(loop, LINE, 5.0, true)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	for i in _stops.size():
		var p := pts[i]
		var r := 15.0 + (4.0 * pulse if i == _sel else 0.0)
		_overlay.draw_circle(p, r + 3.0, Color(0.05, 0.04, 0.1))
		_overlay.draw_circle(p, r, Color(1.0, 0.45, 0.65) if i == _current else (Color.WHITE if i == _sel else LINE))
		Icons.draw(_overlay, "bus", p, 8.0, Color(0.05, 0.04, 0.1))
		_overlay.draw_string_outline(_font, p + Vector2(20, 6), _stops[i]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.05, 0.04, 0.1))
		_overlay.draw_string(_font, p + Vector2(20, 6), _stops[i]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
