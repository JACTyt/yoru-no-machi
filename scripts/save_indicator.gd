extends CanvasLayer
## Bottom-right autosave notice: a spinning diamond and "Saving", fading out after each save.

const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const SHOW_TIME := 1.6

var _root: Control
var _label: Label
var _t := 0.0
var _spin := 0.0


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_root.position -= Vector2(190, 70)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	_root.draw.connect(_draw_icon)
	add_child(_root)
	_label = Label.new()
	_label.text = "Saving"
	_label.label_settings = MenuStyle.label_settings(MenuStyle.font(), 20, MenuStyle.TEXT_LIT, 0.35)
	_label.position = Vector2(34, 2)
	_root.add_child(_label)


func flash() -> void:
	_t = SHOW_TIME


func _process(delta: float) -> void:
	var dt := delta / maxf(Engine.time_scale, 0.01)
	_t = maxf(_t - dt, 0.0)
	_spin += dt * 4.0
	_root.modulate.a = clampf(_t / 0.4, 0.0, 1.0)
	if _root.modulate.a > 0.0:
		_root.queue_redraw()


func _draw_icon() -> void:
	var c := Vector2(14, 16)
	var pts := PackedVector2Array()
	for k in 4:
		pts.append(c + Vector2.from_angle(_spin + k * PI * 0.5) * Vector2(9, 9))
	_root.draw_colored_polygon(pts, Color(MenuStyle.ORNAMENT, 0.9))
	_root.draw_arc(c, 13.0, _spin * 0.5, _spin * 0.5 + PI * 1.3, 24, Color(MenuStyle.ORNAMENT, 0.6), 1.5, true)
