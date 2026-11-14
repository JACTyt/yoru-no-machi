extends CanvasLayer
## Full-screen shop: category tabs on the left, a grid of illustrated item cards, and a detail panel
## with a large picture, description, quantity selector and purchase button. Pauses the game.
## open({"title", "subtitle", "accent": Color, "categories": [{"name", "items": [entry]}],
##       "on_buy": Callable(entry, qty) -> bool})
## entry: {"id", "name", "icon", "tint"?, "price", "desc", "effect", "rarity" 0-2, "max"?, "owned"?}

signal closed

const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const PlayerState := preload("res://scripts/player_state.gd")
const Items := preload("res://scripts/items.gd")

const CARD := Vector2(168, 206)
const GAP := 16.0
const COLUMNS := 4
const TAB_W := 190.0
const DETAIL_W := 380.0

var is_open := false
var _def := {}
var _cat := 0
var _sel := 0
var _qty := 1
var _flash := 0.0
var _flash_text := ""
var _ui: Control
var _desc: Label
var _font: Font
var _body_font: Font
var _rects := {} ## hit areas: key → Rect2
var _hover := ""


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = MenuStyle.font()
	_body_font = ThemeDB.fallback_font
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.visible = false
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.draw.connect(_draw_ui)
	_ui.gui_input.connect(_on_input)
	add_child(_ui)
	_desc = Label.new()
	var ds := LabelSettings.new()
	ds.font_size = 17
	ds.font_color = Color(0.82, 0.85, 0.95)
	ds.line_spacing = 4
	_desc.label_settings = ds
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(_desc)


func open(def: Dictionary) -> void:
	_def = def
	_cat = 0
	_sel = 0
	_qty = 1
	is_open = true
	_ui.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui.modulate.a = 0.0
	create_tween().tween_property(_ui, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_ui.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _items() -> Array:
	var cats: Array = _def.get("categories", [])
	return cats[_cat]["items"] if not cats.is_empty() else []


func _entry() -> Dictionary:
	var items := _items()
	return items[clampi(_sel, 0, items.size() - 1)] if not items.is_empty() else {}


func _owned(e: Dictionary) -> int:
	return int(e["owned"]) if e.has("owned") else int(PlayerState.inventory.get(e.get("id", ""), 0))


func _max_qty(e: Dictionary) -> int:
	return int(e.get("max", 9))


func _buy() -> void:
	var e := _entry()
	if e.is_empty():
		return
	var total: int = int(e["price"]) * _qty
	if total > PlayerState.money:
		_flash_text = "Not enough money"
		_flash = 1.5
		return
	if _def["on_buy"].call(e, _qty):
		_flash_text = "Purchased!" if _qty == 1 else "Purchased x%d!" % _qty
		_flash = 1.5
		_qty = 1


func _process(delta: float) -> void:
	if not is_open:
		return
	_flash = maxf(_flash - delta, 0.0)
	_ui.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var items := _items()
	var handled := true
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_right"):
		_sel = mini(_sel + 1, items.size() - 1)
		_qty = 1
	elif event.is_action_pressed("ui_left"):
		_sel = maxi(_sel - 1, 0)
		_qty = 1
	elif event.is_action_pressed("ui_down"):
		_sel = mini(_sel + COLUMNS, items.size() - 1)
		_qty = 1
	elif event.is_action_pressed("ui_up"):
		_sel = maxi(_sel - COLUMNS, 0)
		_qty = 1
	elif event.is_action_pressed("ui_accept"):
		_buy()
	elif event.is_action_pressed("ui_focus_next"):
		_cat = (_cat + 1) % _def["categories"].size()
		_sel = 0
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = ""
		for key in _rects:
			if _rects[key].has_point(event.position):
				_hover = key
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		for key in _rects:
			if not _rects[key].has_point(event.position):
				continue
			var k: String = key
			if k.begins_with("tab"):
				_cat = int(k.substr(3))
				_sel = 0
				_qty = 1
			elif k.begins_with("card"):
				_sel = int(k.substr(4))
				_qty = 1
			elif k == "minus":
				_qty = maxi(_qty - 1, 1)
			elif k == "plus":
				_qty = mini(_qty + 1, _max_qty(_entry()))
			elif k == "buy":
				_buy()
			elif k == "close":
				close()
			return
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_qty = maxi(_qty - 1, 1)
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_qty = mini(_qty + 1, _max_qty(_entry()))


# --- Drawing ----------------------------------------------------------------------------------

func _text(text: String, pos: Vector2, size: int, color: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_ui.draw_string(font if font != null else _font, pos, text, align, width, size, color)


func _draw_ui() -> void:
	_rects.clear()
	var s := _ui.size
	var accent: Color = _def.get("accent", Color(0.6, 0.8, 1.0))
	# Backdrop: deep blue-black with soft diagonal light bands.
	_ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.07, 0.94))
	for i in 6:
		var x := s.x * (0.1 + i * 0.18)
		_ui.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 120, 0), Vector2(x - 180, s.y), Vector2(x - 300, s.y)]), Color(accent, 0.025))

	# Header.
	_text(_def.get("title", "SHOP"), Vector2(56, 74), 44, Color(0.92, 0.95, 1.0))
	_text(_def.get("subtitle", ""), Vector2(60, 104), 18, MenuStyle.TEXT_DIM)
	MenuStyle.flourish(_ui, Vector2(56, 118), 420.0, 1.0, Color(accent, 0.8))
	var wallet := PlayerState.format_money(PlayerState.money)
	var ww := _font.get_string_size(wallet, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var chip := Rect2(Vector2(s.x - ww - 140, 44), Vector2(ww + 80, 44))
	_ui.draw_rect(chip, Color(0.08, 0.08, 0.14, 0.9))
	_ui.draw_rect(chip, Color(accent, 0.6), false, 1.5)
	_ui.draw_circle(chip.position + Vector2(24, 22), 12.0, Color(1.0, 0.82, 0.35))
	_text("¥", chip.position + Vector2(18, 29), 16, Color(0.4, 0.25, 0.05), _body_font)
	_text(wallet, chip.position + Vector2(46, 32), 26, Color(1.0, 0.9, 0.6))
	var close_r := Rect2(Vector2(s.x - 50, 50), Vector2(32, 32))
	_rects["close"] = close_r
	var xc := close_r.get_center()
	var cc := Color.WHITE if _hover == "close" else MenuStyle.TEXT_DIM
	_ui.draw_line(xc + Vector2(-9, -9), xc + Vector2(9, 9), cc, 2.0, true)
	_ui.draw_line(xc + Vector2(9, -9), xc + Vector2(-9, 9), cc, 2.0, true)

	# Category tabs.
	var cats: Array = _def.get("categories", [])
	for i in cats.size():
		var r := Rect2(Vector2(40, 160 + i * 58), Vector2(TAB_W, 48))
		_rects["tab%d" % i] = r
		var on := i == _cat
		_ui.draw_rect(r, Color(accent, 0.22) if on else (Color(1, 1, 1, 0.06) if _hover == "tab%d" % i else Color(1, 1, 1, 0.02)))
		if on:
			_ui.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), accent)
		_text(cats[i]["name"], r.position + Vector2(22, 31), 20, MenuStyle.TEXT_LIT if on else MenuStyle.TEXT_DIM)

	# Item grid.
	var items := _items()
	var origin := Vector2(40 + TAB_W + 40, 160)
	for i in items.size():
		var e: Dictionary = items[i]
		var r := Rect2(origin + Vector2(i % COLUMNS, i / COLUMNS) * (CARD + Vector2(GAP, GAP)), CARD)
		_rects["card%d" % i] = r
		_card(r, e, i == _sel, _hover == "card%d" % i, accent)

	_detail(Rect2(Vector2(s.x - DETAIL_W - 40, 160), Vector2(DETAIL_W, s.y - 220)), accent)
	_text("Esc close   ·   arrows select   ·   Enter / click Purchase   ·   wheel quantity   ·   Tab category",
			Vector2(40, s.y - 26), 14, MenuStyle.TEXT_DIM, _body_font)


func _card(r: Rect2, e: Dictionary, selected: bool, hover: bool, accent: Color) -> void:
	var rarity: Color = Items.RARITY_COLORS[clampi(int(e.get("rarity", 0)), 0, 2)]
	# Gradient body from the rarity color into the dark card base.
	var steps := 12
	for k in steps:
		var t := float(k) / steps
		var band := Rect2(r.position + Vector2(0, r.size.y * 0.72 * t), Vector2(r.size.x, r.size.y * 0.72 / steps + 1.0))
		_ui.draw_rect(band, Color(0.1, 0.1, 0.16).lerp(rarity, 0.55 * (1.0 - t)))
	_ui.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.72), Vector2(r.size.x, r.size.y * 0.28)), Color(0.07, 0.07, 0.12))
	_ui.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), rarity.lightened(0.3))
	# Picture.
	_ui.draw_circle(r.position + Vector2(r.size.x * 0.5, 72), 46.0, Color(1, 1, 1, 0.07))
	Icons.draw(_ui, e.get("icon", ""), r.position + Vector2(r.size.x * 0.5, 72), 38.0, e.get("tint", Color(0.95, 0.95, 1.0)))
	_text(e["name"], r.position + Vector2(0, 142), 17, Color(0.95, 0.96, 1.0), _body_font, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var price := PlayerState.format_money(int(e["price"]))
	_text(price, r.position + Vector2(0, r.size.y - 18), 20, Color(1.0, 0.86, 0.5), _font, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var owned := _owned(e)
	if owned > 0:
		var badge := "x%d" % owned if not e.has("owned") else "OWNED"
		var bw := _body_font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
		_ui.draw_rect(Rect2(r.position + Vector2(r.size.x - bw - 8, 12), Vector2(bw, 20)), Color(0, 0, 0, 0.55))
		_text(badge, r.position + Vector2(r.size.x - bw - 1, 27), 13, Color.WHITE, _body_font)
	if selected or hover:
		_ui.draw_rect(r.grow(2), Color(accent if selected else Color.WHITE, 0.9 if selected else 0.35), false, 2.0)
	if selected:
		MenuStyle.diamond(_ui, r.position + Vector2(r.size.x * 0.5, -2), 6.0, accent)


func _detail(r: Rect2, accent: Color) -> void:
	_ui.draw_rect(r, Color(0.06, 0.06, 0.11, 0.92))
	_ui.draw_rect(r, Color(accent, 0.35), false, 1.0)
	var e := _entry()
	if e.is_empty():
		_desc.text = ""
		return
	var rarity: Color = Items.RARITY_COLORS[clampi(int(e.get("rarity", 0)), 0, 2)]
	var pic := Rect2(r.position + Vector2(20, 20), Vector2(r.size.x - 40, 190))
	for k in 10:
		var t := float(k) / 10
		_ui.draw_rect(Rect2(pic.position + Vector2(0, pic.size.y * t), Vector2(pic.size.x, pic.size.y / 10 + 1)), Color(0.08, 0.08, 0.14).lerp(rarity, 0.5 * (1.0 - t)))
	Icons.draw(_ui, e.get("icon", ""), pic.get_center(), 70.0, e.get("tint", Color(0.95, 0.95, 1.0)))
	var y := pic.end.y + 40
	_text(e["name"], Vector2(r.position.x + 24, y), 28, Color(0.95, 0.96, 1.0))
	for k in int(e.get("rarity", 0)) + 1:
		MenuStyle.diamond(_ui, Vector2(r.position.x + 30 + k * 18, y + 18), 5.0, rarity.lightened(0.3))
	_desc.position = Vector2(r.position.x + 24, y + 32)
	_desc.size = Vector2(r.size.x - 48, 90)
	_desc.text = e.get("desc", "")
	if not String(e.get("effect", "")).is_empty():
		_text(e["effect"], Vector2(r.position.x + 24, y + 140), 18, Color(0.55, 1.0, 0.7), _body_font)

	# Quantity, total and purchase.
	var by := r.end.y - 130
	var can_qty := _max_qty(e) > 1
	if can_qty:
		var minus := Rect2(Vector2(r.position.x + 24, by), Vector2(40, 40))
		var plus := Rect2(Vector2(r.position.x + 150, by), Vector2(40, 40))
		_rects["minus"] = minus
		_rects["plus"] = plus
		for b in [[minus, "-"], [plus, "+"]]:
			_ui.draw_rect(b[0], Color(1, 1, 1, 0.12 if _hover == ("minus" if b[1] == "-" else "plus") else 0.06))
			_text(b[1], b[0].position + Vector2(0, 29), 24, Color.WHITE, _body_font, HORIZONTAL_ALIGNMENT_CENTER, 40)
		_text(str(_qty), Vector2(r.position.x + 64, by + 30), 24, Color.WHITE, _font, HORIZONTAL_ALIGNMENT_CENTER, 86)
	var total: int = int(e["price"]) * _qty
	var afford := total <= PlayerState.money
	_text(PlayerState.format_money(total), Vector2(r.end.x - 24 - 200, by + 30), 26, Color(1.0, 0.86, 0.5) if afford else Color(1.0, 0.45, 0.45), _font, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	var buy := Rect2(Vector2(r.position.x + 24, r.end.y - 72), Vector2(r.size.x - 48, 52))
	_rects["buy"] = buy
	var col := accent if afford else Color(0.35, 0.35, 0.4)
	_ui.draw_rect(buy, col.lightened(0.15) if _hover == "buy" and afford else col)
	_text("PURCHASE", buy.position + Vector2(0, 35), 24, Color(0.05, 0.04, 0.1), _font, HORIZONTAL_ALIGNMENT_CENTER, buy.size.x)
	if _flash > 0.0:
		var good := _flash_text.begins_with("Purchased")
		_text(_flash_text, Vector2(r.position.x, r.end.y - 84), 18, Color(0.55, 1.0, 0.7, minf(_flash, 1.0)) if good else Color(1.0, 0.5, 0.5, minf(_flash, 1.0)), _font, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
