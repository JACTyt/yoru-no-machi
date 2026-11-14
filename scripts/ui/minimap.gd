extends CanvasLayer
## Top-right minimap: heading-up city map around the player inside an ornamented frame, with a
## north marker, the district name and the distance to the waypoint.

const MapView := preload("res://scripts/ui/map_view.gd")
const City := preload("res://scripts/city/city_builder.gd")
const PlayerState := preload("res://scripts/player_state.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")

const SIZE := 230.0
const ZOOM := 1.5

var city
var view: Control
var _frame: Control
var _caption: Label
var _pos := Vector3.ZERO
var _facing := Vector3.FORWARD
var _yaw := 0.0
var _place := ""


func _ready() -> void:
	layer = 5
	var clip := Control.new()
	clip.clip_contents = true
	clip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clip.offset_left = -SIZE - 28
	clip.offset_right = -28
	clip.offset_top = 26
	clip.offset_bottom = 26 + SIZE
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	view = MapView.new()
	view.city = city
	view.zoom = ZOOM
	view.rotate_map = true
	view.size = Vector2.ONE * SIZE
	clip.add_child(view)

	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_frame.offset_left = clip.offset_left
	_frame.offset_right = clip.offset_right
	_frame.offset_top = clip.offset_top
	_frame.offset_bottom = clip.offset_bottom
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)

	_caption = Label.new()
	_caption.label_settings = MenuStyle.label_settings(MenuStyle.font(), 17, Color(0.92, 0.94, 1.0), 0.0)
	_caption.label_settings.outline_size = 5
	_caption.label_settings.outline_color = Color(0.05, 0.03, 0.1)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_caption.offset_left = -SIZE - 200
	_caption.offset_right = -28
	_caption.offset_top = SIZE + 34
	add_child(_caption)


## `place` names the building the player is inside ("" outdoors).
func track(pos: Vector3, facing: Vector3, camera_yaw: float, place := "") -> void:
	_pos = pos
	_facing = facing
	_yaw = camera_yaw
	_place = place


func _process(_delta: float) -> void:
	view.center = Vector2(_pos.x, _pos.z)
	view.player_pos = view.center
	view.player_dir = Vector2(_facing.x, _facing.z)
	view.heading = _yaw
	var text := _place if not _place.is_empty() else City.district_name(_pos)
	if PlayerState.has_waypoint:
		text += "\nWaypoint  %d m" % int(Vector2(_pos.x, _pos.z).distance_to(Vector2(PlayerState.waypoint.x, PlayerState.waypoint.z)))
	_caption.text = text
	_frame.queue_redraw()


func _draw_frame() -> void:
	var s := _frame.size
	var c := MenuStyle.ORNAMENT
	_frame.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.03, 0.1), false, 3.0)
	_frame.draw_rect(Rect2(Vector2(-4, -4), s + Vector2(8, 8)), Color(c, 0.8), false, 1.5)
	for corner in [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]:
		MenuStyle.diamond(_frame, corner, 6.0, c)
	# North marker on the frame edge, rotating with the map.
	var north := Vector2(0, -1).rotated(_yaw)
	var half := s * 0.5
	var t := minf(absf(half.x / north.x) if absf(north.x) > 0.001 else INF, absf(half.y / north.y) if absf(north.y) > 0.001 else INF)
	var p := half + north * (t - 2.0)
	_frame.draw_circle(p, 10.0, Color(0.9, 0.25, 0.4))
	var font := MenuStyle.font()
	_frame.draw_string(font, p + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
