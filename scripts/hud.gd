extends CanvasLayer
## Player HUD: heroine name, an HP bar whose white "chip" drains after the red fill, money, and
## short toast notifications at the top of the screen.

const PlayerState := preload("res://scripts/player_state.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const Items := preload("res://scripts/items.gd")
const STAMINA_SIZE := Vector2(240, 6)
const STAMINA := Color(0.55, 0.95, 0.55)
const STAMINA_LOW := Color(1.0, 0.75, 0.3)
const FONT_PATH := "res://fonts/Cinzel.ttf"
const BAR_SIZE := Vector2(340, 14)
const FILL := Color(0.95, 0.28, 0.42)
const FILL_LOW := Color(1.0, 0.12, 0.2)
const CHIP := Color(1.0, 0.96, 0.92)
const FRAME := Color(0.78, 0.86, 1.0, 0.85)

var _fill: ColorRect
var _chip: ColorRect
var _label: Label
var _ratio := 1.0
var _chip_ratio := 1.0
var _chip_delay := 0.0
var _flash := 0.0
var _money: Label
var _hero
var _stamina_frame: Panel
var _stamina_fill: ColorRect
var _stamina_alpha := 0.0
var _gauge: Control
var _hotbar: Control
## Car fuel 0..1 shown while driving; negative hides the gauge.
var fuel := -1.0
var fuel_electric := false
var _shown_money := -1.0
var _toasts: VBoxContainer
var _font: Font


func _ready() -> void:
	layer = 5
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var root := Control.new()
	root.position = Vector2(28, 26)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	var s := LabelSettings.new()
	s.font = font
	s.font_size = 20
	s.font_color = Color(0.9, 0.93, 1.0)
	s.outline_size = 5
	s.outline_color = Color(0.06, 0.03, 0.1)
	_label.label_settings = s
	root.add_child(_label)

	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.75)
	style.border_color = FRAME
	style.set_border_width_all(1)
	style.skew = Vector2(-0.35, 0)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(0, 30)
	frame.size = BAR_SIZE + Vector2(6, 6)
	root.add_child(frame)

	_chip = _bar(frame, CHIP)
	_fill = _bar(frame, FILL)
	_font = font

	_money = Label.new()
	var ms := LabelSettings.new()
	ms.font = font
	ms.font_size = 22
	ms.font_color = Color(1.0, 0.9, 0.6)
	ms.outline_size = 5
	ms.outline_color = Color(0.06, 0.03, 0.1)
	_money.label_settings = ms
	_money.position = Vector2(2, 66)
	root.add_child(_money)

	_stamina_frame = Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.04, 0.03, 0.08, 0.7)
	ss.skew = Vector2(-0.35, 0)
	_stamina_frame.add_theme_stylebox_override("panel", ss)
	_stamina_frame.position = Vector2(4, 54)
	_stamina_frame.size = STAMINA_SIZE + Vector2(4, 4)
	root.add_child(_stamina_frame)
	_stamina_fill = ColorRect.new()
	_stamina_fill.position = Vector2(2, 2)
	_stamina_fill.size = STAMINA_SIZE
	_stamina_fill.color = STAMINA
	_stamina_frame.add_child(_stamina_fill)

	_gauge = Control.new()
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_gauge.offset_left = -300
	_gauge.offset_top = -90
	_gauge.offset_right = -30
	_gauge.offset_bottom = -30
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)

	_hotbar = Control.new()
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -150
	_hotbar.offset_right = 150
	_hotbar.offset_top = -86
	_hotbar.offset_bottom = -14
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar.draw.connect(_draw_hotbar)
	add_child(_hotbar)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 70
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


## Brief centered message ("+¥800", "Waypoint set", ...).
func toast(text: String, color := Color(0.95, 0.97, 1.0)) -> void:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font = _font
	s.font_size = 26
	s.font_color = color
	s.outline_size = 7
	s.outline_color = Color(0.06, 0.03, 0.1)
	l.label_settings = s
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _bar(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = Vector2(3, 3)
	r.size = BAR_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Connects to a heroine node (health_changed signal, max_hp/hp).
func bind(heroine, display_name: String) -> void:
	_hero = heroine
	_label.text = display_name
	heroine.health_changed.connect(_on_health)
	_on_health(heroine.hp, heroine.max_hp)
	_chip_ratio = _ratio


func _on_health(hp: float, max_hp: float) -> void:
	var r := clampf(hp / max_hp, 0.0, 1.0)
	if r < _ratio:
		_chip_delay = 0.45
		_flash = 1.0
	else:
		_chip_ratio = r
	_ratio = r


func _process(delta: float) -> void:
	# Real time so the bar keeps moving during hit-stop / slow motion.
	var dt := delta / maxf(Engine.time_scale, 0.01)
	_chip_delay -= dt
	if _chip_delay <= 0.0:
		_chip_ratio = move_toward(_chip_ratio, _ratio, dt * 0.6)
	_flash = move_toward(_flash, 0.0, dt * 4.0)
	_fill.size.x = BAR_SIZE.x * _ratio
	_chip.size.x = BAR_SIZE.x * _chip_ratio
	var base := FILL_LOW if _ratio < 0.3 else FILL
	if _ratio < 0.3:
		base = base.lerp(FILL, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	_fill.color = base.lerp(Color.WHITE, _flash * 0.6)
	# Stamina bar: visible while used, fades out once full.
	if _hero != null and "stamina" in _hero:
		var r: float = _hero.stamina / _hero.MAX_STAMINA
		_stamina_fill.size.x = STAMINA_SIZE.x * r
		_stamina_fill.color = STAMINA_LOW if r < 0.3 else STAMINA
		_stamina_alpha = move_toward(_stamina_alpha, 1.0 if r < 0.999 else 0.0, dt * (4.0 if r < 0.999 else 1.0))
		_stamina_frame.modulate.a = _stamina_alpha
	_hotbar.visible = fuel < 0.0
	_hotbar.queue_redraw()
	_gauge.visible = fuel >= 0.0
	if _gauge.visible:
		_gauge.queue_redraw()
	# Money counts up/down toward the real value.
	if _shown_money < 0.0:
		_shown_money = PlayerState.money
	_shown_money = move_toward(_shown_money, PlayerState.money, maxf(absf(PlayerState.money - _shown_money) * dt * 6.0, dt * 50.0))
	_money.text = PlayerState.format_money(roundi(_shown_money))


## Fuel (pump) or battery (bolt) gauge for the car being driven.
func _draw_gauge() -> void:
	var low := fuel < 0.2
	var col := Color(1.0, 0.4, 0.4) if low else (Color(0.45, 0.85, 1.0) if fuel_electric else Color(1.0, 0.82, 0.4))
	if low and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0:
		col = col.lightened(0.4)
	Icons.draw(_gauge, "ev" if fuel_electric else "gas", Vector2(22, 30), 16.0, col)
	var bar := Rect2(Vector2(50, 22), Vector2(200, 14))
	_gauge.draw_rect(bar.grow(3), Color(0.04, 0.03, 0.08, 0.75))
	_gauge.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fuel, 0.0, 1.0), bar.size.y)), col)
	for k in range(1, 4):
		var x := bar.position.x + bar.size.x * k / 4.0
		_gauge.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0.04, 0.03, 0.08, 0.6), 1.0)
	_gauge.draw_string(_font, Vector2(50, 14), ("BATTERY" if fuel_electric else "FUEL") + "  %d%%" % roundi(fuel * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.94, 1.0))


## Quick-use slots 1-4 with item pictures and counts.
func _draw_hotbar() -> void:
	for i in 4:
		var r := Rect2(Vector2(i * 76, 0), Vector2(66, 66))
		var id: String = PlayerState.hotbar[i]
		var count := int(PlayerState.inventory.get(id, 0))
		var item: Dictionary = Items.ITEMS.get(id, {})
		_hotbar.draw_rect(r, Color(0.04, 0.03, 0.08, 0.7))
		if not item.is_empty():
			_hotbar.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4), Vector2(r.size.x, 4)), Items.RARITY_COLORS[item["rarity"]])
			_hotbar.modulate.a = 1.0
			var tint := Color(0.95, 0.95, 1.0) if count > 0 else Color(0.5, 0.5, 0.55)
			Icons.draw(_hotbar, item["icon"], r.get_center(), 20.0, tint)
			_hotbar.draw_string(_font, r.position + Vector2(r.size.x - 26, r.size.y - 8), "x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, 22, 14, Color.WHITE if count > 0 else Color(1, 0.5, 0.5))
		_hotbar.draw_rect(r, Color(0.78, 0.86, 1.0, 0.5), false, 1.0)
		_hotbar.draw_string(_font, r.position + Vector2(5, 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.6))
