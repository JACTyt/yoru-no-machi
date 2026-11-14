extends CanvasLayer
## Radial interaction menu: hold the "wheel" action (Tab), point with the mouse, release to choose.
## Time slows while open. The owner supplies options via `options_provider`, a Callable returning
## an Array of {"label": String, "action": Callable, "enabled": bool}.

signal opened
signal closed

const FONT_PATH := "res://fonts/Cinzel.ttf"
const RADIUS := 170.0
const INNER := 70.0
const SLOW_MO := 0.2
const ACCENT := Color(0.5, 0.9, 0.82)
const TimeScale := preload("res://scripts/combat/time_scale.gd")

var options_provider: Callable
var is_open := false

var _options: Array = []
var _hover := -1
var _was_down := false
var _ring: Control
var _font: Font


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_STOP
	_ring.visible = false
	_ring.draw.connect(_draw_wheel)
	add_child(_ring)


func _process(_delta: float) -> void:
	if get_tree().paused:
		if is_open:
			_close(false)
		return
	# Edge-detect the hold ourselves so presses landing between frames aren't missed.
	var down := Input.is_action_pressed("wheel")
	if down and not _was_down and not is_open and options_provider.is_valid():
		_open()
	elif is_open and not down:
		_close(true)
	_was_down = down
	if is_open:
		_update_hover()
		_ring.queue_redraw()


func _open() -> void:
	_options = options_provider.call()
	if _options.is_empty():
		return
	is_open = true
	_hover = -1
	_ring.visible = true
	TimeScale.hold(get_tree(), "wheel", SLOW_MO)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(_ring.size * 0.5)
	opened.emit()


func _close(execute: bool) -> void:
	is_open = false
	_ring.visible = false
	TimeScale.release("wheel")
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	if execute and _hover >= 0 and _options[_hover].get("enabled", true):
		(_options[_hover]["action"] as Callable).call()


func _update_hover() -> void:
	var d := _ring.get_local_mouse_position() - _ring.size * 0.5
	if d.length() < INNER * 0.6:
		_hover = -1
		return
	var n := _options.size()
	# Slot 0 sits at the top; slots go clockwise.
	var a := fposmod(atan2(d.x, -d.y) + PI / n, TAU)
	_hover = int(a / (TAU / n)) % n


func _draw_wheel() -> void:
	var c := _ring.size * 0.5
	var n := _options.size()
	_ring.draw_rect(Rect2(Vector2.ZERO, _ring.size), Color(0.02, 0.02, 0.06, 0.35))
	_ring.draw_circle(c, RADIUS + 6.0, Color(0.03, 0.03, 0.08, 0.82))
	var seg := TAU / n
	for i in n:
		var mid := i * seg - PI * 0.5
		var lit := i == _hover
		var enabled: bool = _options[i].get("enabled", true)
		if lit and enabled:
			var pts := PackedVector2Array([c + Vector2.from_angle(mid - seg * 0.5) * INNER])
			for k in 13:
				pts.append(c + Vector2.from_angle(mid - seg * 0.5 + seg * k / 12.0) * RADIUS)
			pts.append(c + Vector2.from_angle(mid + seg * 0.5) * INNER)
			_ring.draw_colored_polygon(pts, Color(ACCENT, 0.28))
		# Divider spokes.
		var edge := mid - seg * 0.5
		_ring.draw_line(c + Vector2.from_angle(edge) * INNER, c + Vector2.from_angle(edge) * RADIUS, Color(0.8, 0.88, 1.0, 0.25), 1.0, true)
		var label: String = _options[i]["label"]
		var color := ACCENT.lightened(0.4) if lit and enabled else (Color(0.85, 0.88, 0.95) if enabled else Color(0.45, 0.47, 0.55))
		var pos := c + Vector2.from_angle(mid) * (INNER + RADIUS) * 0.5
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_ring.draw_string(_font, pos + Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	_ring.draw_arc(c, RADIUS, 0, TAU, 96, Color(0.8, 0.88, 1.0, 0.7), 1.5, true)
	_ring.draw_arc(c, INNER, 0, TAU, 64, Color(0.8, 0.88, 1.0, 0.5), 1.0, true)
	var title := "Interact" if _hover < 0 else String(_options[_hover]["label"])
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_ring.draw_string(_font, c + Vector2(-tw * 0.5, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.93, 1.0, 0.9))
