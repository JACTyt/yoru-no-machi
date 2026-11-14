extends Control
## Draws the city map: streets, sidewalks, buildings, parks, landmark icons, the waypoint with a
## GPS route along the road grid, and the player arrow. Map x = world x, map y = world z.
## Used by the minimap (heading-up, follows the player) and the full-screen map (north-up).

const City := preload("res://scripts/city/city_builder.gd")
const PlayerState := preload("res://scripts/player_state.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const Icons := preload("res://scripts/ui/icons.gd")

const GROUND := Color(0.42, 0.62, 0.42)
const ROAD := Color(0.2, 0.2, 0.27)
const WALK := Color(0.62, 0.6, 0.68)
const BUILDING := Color(0.86, 0.84, 0.9)
const PARK := Color(0.5, 0.76, 0.48)
const YARD := Color(0.82, 0.7, 0.55)
const ROUTE := Color(1.0, 0.45, 0.7)

var city
var center := Vector2.ZERO ## World x/z shown at the middle of the control.
var zoom := 1.0 ## Pixels per meter.
var heading := 0.0 ## Camera yaw; rotates the map when `rotate_map`.
var rotate_map := false
var labels := false
var player_pos := Vector2.ZERO
var player_dir := Vector2(0, 1)
var _font: Font


func _ready() -> void:
	_font = MenuStyle.font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func to_screen(p: Vector2) -> Vector2:
	var d := (p - center) * zoom
	if rotate_map:
		d = d.rotated(heading)
	return size * 0.5 + d


func to_world(screen: Vector2) -> Vector2:
	var d := screen - size * 0.5
	if rotate_map:
		d = d.rotated(-heading)
	return center + d / zoom


func _rect(r: Rect2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([to_screen(r.position), to_screen(Vector2(r.end.x, r.position.y)), to_screen(r.end), to_screen(Vector2(r.position.x, r.end.y))]), color)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if city == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	var extent := City.EXTENT + City.OUTER_WALK
	_rect(Rect2(-extent, -extent, extent * 2.0, extent * 2.0), WALK)
	_rect(Rect2(-City.EXTENT, -City.EXTENT, City.EXTENT * 2.0, City.EXTENT * 2.0), ROAD)
	for ix in City.BLOCKS:
		for iz in City.BLOCKS:
			var c := Vector2((ix - (City.BLOCKS - 1) / 2.0) * City.CELL, (iz - (City.BLOCKS - 1) / 2.0) * City.CELL)
			_rect(Rect2(c - Vector2.ONE * City.BLOCK_SIZE * 0.5, Vector2.ONE * City.BLOCK_SIZE), WALK)
	for f in city.map_features:
		_rect(f["rect"], PARK if f["kind"] == "park" else (YARD if f["kind"] == "yard" else BUILDING))
	if PlayerState.has_waypoint:
		_draw_route()
	for stop in city.bus_stops:
		var b: Vector3 = stop["pos"]
		_icon(to_screen(Vector2(b.x, b.z)), Color(0.3, 0.75, 1.0), "bus", "", 0.7)
	for id in city.stations:
		var st: Dictionary = city.stations[id]
		var c: Vector3 = st["center"]
		_icon(to_screen(Vector2(c.x, c.z)), st["color"], st["kind"], st["name"] if labels else "", 0.85)
	for id in city.places:
		var place: Dictionary = city.places[id]
		var d: Vector3 = place["door"]
		_icon(to_screen(Vector2(d.x, d.z)), place["color"], id, place["name"] if labels else "")
	if PlayerState.has_waypoint:
		var w := to_screen(Vector2(PlayerState.waypoint.x, PlayerState.waypoint.z))
		draw_circle(w + Vector2(0, -9), 7.0, ROUTE)
		draw_colored_polygon(PackedVector2Array([w, w + Vector2(-6, -10), w + Vector2(6, -10)]), ROUTE)
		draw_circle(w + Vector2(0, -9), 2.5, Color.WHITE)
	_draw_player()


## Round badge with a pictogram (see icons.gd).
func _icon(p: Vector2, color: Color, icon: String, caption: String, scale_by := 1.0) -> void:
	var r := (10.0 if not labels else 13.0) * scale_by
	draw_circle(p, r + 2.0, Color(0.05, 0.04, 0.1))
	draw_circle(p, r, color)
	Icons.draw(self, icon, p, r * 0.6, Color(0.05, 0.04, 0.1))
	if not caption.is_empty():
		var cw := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(_font, p + Vector2(-cw * 0.5, r + 18), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(0.05, 0.04, 0.1))
		draw_string(_font, p + Vector2(-cw * 0.5, r + 18), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_player() -> void:
	var p := to_screen(player_pos)
	var dir := player_dir.rotated(heading) if rotate_map else player_dir
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var tip := p + dir * 11.0
	var pts := PackedVector2Array([tip, p - dir * 7.0 + side * 7.0, p - dir * 3.0, p - dir * 7.0 - side * 7.0])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.9, 0.2, 0.45), 2.0, true)


func _draw_route() -> void:
	var path := route(player_pos, Vector2(PlayerState.waypoint.x, PlayerState.waypoint.z))
	var pts := PackedVector2Array()
	for q in path:
		pts.append(to_screen(q))
	draw_polyline(pts, Color(0.05, 0.04, 0.1, 0.6), 7.0, true)
	draw_polyline(pts, ROUTE, 4.0, true)


## Road route between two points: onto the nearest road, along the grid (x first), off the road.
static func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _snap(from)
	var b := _snap(to)
	var na := _exit_node(a, b)
	var nb := _exit_node(b, a)
	return PackedVector2Array([from, a, na, Vector2(nb.x, na.y), nb, b, to])


## Nearest point on any road centerline.
static func _snap(p: Vector2) -> Vector2:
	var lim := City.GRID * City.CELL
	var on_x := Vector2(clampf(roundf(p.x / City.CELL), -City.GRID, City.GRID) * City.CELL, clampf(p.y, -lim, lim))
	var on_z := Vector2(clampf(p.x, -lim, lim), clampf(roundf(p.y / City.CELL), -City.GRID, City.GRID) * City.CELL)
	return on_x if on_x.distance_to(p) < on_z.distance_to(p) else on_z


## The intersection at the end of a's road segment that lies toward `toward`.
static func _exit_node(a: Vector2, toward: Vector2) -> Vector2:
	var on_vertical := is_equal_approx(fposmod(a.x + 1.0, City.CELL), 1.0)
	var on_horizontal := is_equal_approx(fposmod(a.y + 1.0, City.CELL), 1.0)
	if on_vertical and on_horizontal:
		return a
	if on_vertical:
		var z := floorf(a.y / City.CELL) * City.CELL
		if toward.y > a.y:
			z += City.CELL
		return Vector2(a.x, clampf(z, -City.GRID * City.CELL, City.GRID * City.CELL))
	var x := floorf(a.x / City.CELL) * City.CELL
	if toward.x > a.x:
		x += City.CELL
	return Vector2(clampf(x, -City.GRID * City.CELL, City.GRID * City.CELL), a.y)
