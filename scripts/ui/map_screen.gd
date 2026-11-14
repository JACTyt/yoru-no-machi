extends CanvasLayer
## Full-screen city map (M): pauses the game. Click to set a waypoint, right-click to clear it,
## click a place in the legend to route there, mouse wheel to zoom, M / Esc to close.

signal closed

const MapView := preload("res://scripts/ui/map_view.gd")
const City := preload("res://scripts/city/city_builder.gd")
const PlayerState := preload("res://scripts/player_state.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const Icons := preload("res://scripts/ui/icons.gd")

var city
var is_open := false
var _root: Control
var _view: Control
var _fit_zoom := 1.0
var _legend: VBoxContainer
var _font: Font


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = MenuStyle.font()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var clip := Control.new()
	clip.clip_contents = true
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = 60
	clip.offset_top = 90
	clip.offset_right = -380
	clip.offset_bottom = -60
	clip.mouse_filter = Control.MOUSE_FILTER_STOP
	clip.gui_input.connect(_on_map_input)
	_root.add_child(clip)
	_view = MapView.new()
	_view.city = city
	_view.labels = true
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_view)

	var title := Label.new()
	title.text = "HOSHIMACHI"
	title.label_settings = MenuStyle.label_settings(_font, 44, Color(0.88, 0.92, 1.0), 0.35)
	title.position = Vector2(60, 24)
	_root.add_child(title)

	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -340
	side.offset_right = -40
	side.offset_top = 100
	side.add_theme_constant_override("separation", 12)
	_root.add_child(side)
	var head := Label.new()
	head.text = "Places"
	head.label_settings = MenuStyle.label_settings(_font, 26, MenuStyle.TEXT_LIT, 0.3)
	side.add_child(head)
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 8)
	side.add_child(_legend)
	var help := Label.new()
	help.text = "\nLMB  set waypoint\nRMB  clear waypoint\nWheel  zoom\nM / Esc  close"
	help.label_settings = MenuStyle.label_settings(_font, 17, MenuStyle.TEXT_DIM, 0.0)
	side.add_child(help)


func open(player_pos: Vector3, player_dir: Vector3) -> void:
	is_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var extent := (City.EXTENT + City.OUTER_WALK) * 2.0
	await get_tree().process_frame
	_fit_zoom = minf(_view.size.x, _view.size.y) / extent
	_view.zoom = _fit_zoom
	_view.center = Vector2.ZERO
	_view.player_pos = Vector2(player_pos.x, player_pos.z)
	_view.player_dir = Vector2(player_dir.x, player_dir.z)
	_build_legend()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _build_legend() -> void:
	for c in _legend.get_children():
		c.queue_free()
	for id in city.places:
		var place: Dictionary = city.places[id]
		var row := Label.new()
		row.text = "     %s" % place["name"]
		var icon_id: String = id
		row.draw.connect(func():
			row.draw_circle(Vector2(12, row.size.y * 0.5), 11, place["color"])
			Icons.draw(row, icon_id, Vector2(12, row.size.y * 0.5), 7.0, Color(0.05, 0.04, 0.1)))
		row.label_settings = MenuStyle.label_settings(_font, 20, place["color"].lightened(0.3), 0.0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(func(): row.label_settings.font_color = Color.WHITE)
		row.mouse_exited.connect(func(): row.label_settings.font_color = place["color"].lightened(0.3))
		row.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.is_pressed() and e.button_index == MOUSE_BUTTON_LEFT:
				PlayerState.set_waypoint(place["door"]))
		_legend.add_child(row)


func _on_map_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.is_pressed()):
		return
	var mb := event as InputEventMouseButton
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			var w: Vector2 = _view.to_world(mb.position)
			var lim := City.EXTENT + City.OUTER_WALK
			if absf(w.x) <= lim and absf(w.y) <= lim:
				PlayerState.set_waypoint(Vector3(w.x, 0, w.y))
		MOUSE_BUTTON_RIGHT:
			PlayerState.clear_waypoint()
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.2)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.2)


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before: Vector2 = _view.to_world(screen)
	_view.zoom = clampf(_view.zoom * factor, _fit_zoom, _fit_zoom * 6.0)
	_view.center += before - _view.to_world(screen)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
