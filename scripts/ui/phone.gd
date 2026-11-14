extends CanvasLayer
## Smartphone (P): slides up in the corner. Apps: Messages (story threads with reply choices),
## Browser (in-game sites), Map, Bag (use items, assign quick slots 1-4), CarGo (deliver owned cars,
## rent, buy, call a taxi) and Settings. The game keeps running; the heroine stands still while it is
## out. `world` provides use_item, open_map, story_reply, open_settings and the CarGo calls.

signal opened
signal closed

const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const Story := preload("res://scripts/story.gd")
const PlayerState := preload("res://scripts/player_state.gd")
const Items := preload("res://scripts/items.gd")
const Sites := preload("res://scripts/ui/sites.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const CarModels := preload("res://scripts/city/car_models.gd")
## [model, price to buy]
const DEALER := [["compact", 12000], ["sedan", 20000], ["van", 24000], ["coupe", 45000]]
const DELIVERY_FEE := 200

const SIZE := Vector2(360, 660)
const SCREEN_MARGIN := Vector2(16, 44)
const BG := Color(0.07, 0.07, 0.12)
const PANEL := Color(0.12, 0.12, 0.2)
const ME := Color(1.0, 0.5, 0.68)

var world
var is_open := false

var _body: Control
var _screen: Control
var _page := "home"
var _contact := ""
var _site := "home"
var _cargo_tab := "mine"
var _font: Font


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = MenuStyle.font()
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_body.offset_left = -SIZE.x - 40
	_body.offset_right = -40
	_body.offset_top = -SIZE.y - 30
	_body.offset_bottom = -30
	_body.draw.connect(_draw_body)
	_body.visible = false
	add_child(_body)
	_screen = Control.new()
	_screen.position = SCREEN_MARGIN
	_screen.size = SIZE - SCREEN_MARGIN * Vector2(2, 1) - Vector2(0, 30)
	_screen.clip_contents = true
	_body.add_child(_screen)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open(page := "home") -> void:
	is_open = true
	_body.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play(self, "ui_confirm")
	_show(page)
	var top := _body.offset_top
	_body.offset_top = top + 400
	_body.offset_bottom += 400
	var tw := create_tween().set_parallel()
	tw.tween_property(_body, "offset_top", top, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "offset_bottom", top + SIZE.y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_body.visible = false
	Sfx.play(self, "ui_back")
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and not is_open:
		return
	if event.is_action_pressed("phone"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		if _page == "home":
			close()
		else:
			_back()
		get_viewport().set_input_as_handled()


func _back() -> void:
	match _page:
		"thread":
			_show("messages")
		"browser":
			if _site != "home":
				_site = "home"
				_show("browser")
			else:
				_show("home")
		_:
			_show("home")


## Rebuilds the screen if the current page shows live data (new messages, inventory).
func refresh() -> void:
	if is_open and _page in ["home", "messages", "thread", "bag"]:
		_show(_page)


func _process(_delta: float) -> void:
	if is_open:
		_body.queue_redraw()


# --- Pages ------------------------------------------------------------------------------------

func _show(page: String) -> void:
	_page = page
	for c in _screen.get_children():
		c.queue_free()
	match page:
		"home":
			_home()
		"messages":
			_messages()
		"thread":
			_thread()
		"browser":
			_browser()
		"bag":
			_bag()
		"cargo":
			_cargo()


func _home() -> void:
	var clock := _label(Time.get_time_string_from_system().substr(0, 5), 64, Color.WHITE, _font)
	clock.position = Vector2(0, 40)
	clock.size.x = _screen.size.x
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(clock)
	var date := _label(Time.get_date_string_from_system(), 16, Color(0.85, 0.88, 1.0))
	date.position = Vector2(0, 120)
	date.size.x = _screen.size.x
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(date)
	var apps := [["Messages", "message", Color(0.45, 0.9, 0.6), "messages"], ["Browser", "globe", Color(0.45, 0.7, 1.0), "browser"],
		["Map", "map", Color(1.0, 0.85, 0.45), "map"], ["Bag", "bag", Color(1.0, 0.6, 0.7), "bag"],
		["CarGo", "car", Color(1.0, 0.72, 0.35), "cargo"], ["Settings", "gear", Color(0.75, 0.75, 0.85), "settings"]]
	for i in apps.size():
		var a: Array = apps[i]
		var tile := _tile(a[1], a[2])
		tile.position = Vector2(22 + (i % 3) * 100, 190 + (i / 3) * 130)
		_screen.add_child(tile)
		var caption := _label(a[0], 14, Color.WHITE)
		caption.position = tile.position + Vector2(-12, 86)
		caption.size.x = 104
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_screen.add_child(caption)
		var target: String = a[3]
		tile.gui_input.connect(_on_click.bind(func():
			Sfx.play(self, "ui_move")
			if target == "map":
				close()
				world.open_map()
			elif target == "settings":
				close()
				world.open_settings()
			else:
				_site = "home"
				_show(target)))
		if target == "messages" and Story.unread_total() > 0:
			var badge := _label(str(Story.unread_total()), 14, Color.WHITE)
			badge.position = tile.position + Vector2(64, -6)
			badge.size = Vector2(26, 26)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var bg := ColorRect.new()
			bg.color = Color(1.0, 0.25, 0.35)
			bg.position = badge.position
			bg.size = badge.size
			_screen.add_child(bg)
			_screen.add_child(badge)


func _messages() -> void:
	_header("Messages", Color(0.45, 0.9, 0.6))
	var y := 60.0
	var threads: Dictionary = Story.state()["threads"]
	if threads.is_empty():
		var none := _label("No messages yet.", 16, MenuStyle.TEXT_DIM)
		none.position = Vector2(20, y + 10)
		_screen.add_child(none)
	for contact in threads:
		var info: Dictionary = Story.CONTACTS[contact]
		var t: Dictionary = threads[contact]
		var row := Control.new()
		row.position = Vector2(8, y)
		row.size = Vector2(_screen.size.x - 16, 72)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.draw.connect(func():
			row.draw_rect(Rect2(Vector2.ZERO, row.size), PANEL)
			row.draw_circle(Vector2(36, 36), 24, info["color"])
			row.draw_string(_font, Vector2(26, 45), String(info["name"]).left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.06, 0.04, 0.12))
			if int(t["unread"]) > 0:
				row.draw_circle(Vector2(row.size.x - 20, 36), 7, Color(1.0, 0.3, 0.4)))
		_screen.add_child(row)
		var caption := _label(info["name"], 17, Color.WHITE, _font)
		caption.position = Vector2(70, 10)
		row.add_child(caption)
		var last: String = t["log"][-1][1] if not t["log"].is_empty() else ""
		var preview := _label(last.left(30) + ("…" if last.length() > 30 else ""), 14, MenuStyle.TEXT_DIM)
		preview.position = Vector2(70, 40)
		row.add_child(preview)
		row.gui_input.connect(_on_click.bind(func():
			_contact = contact
			_show("thread")))
		y += 80.0


func _thread() -> void:
	var info: Dictionary = Story.CONTACTS[_contact]
	var t := Story.thread(_contact)
	t["unread"] = 0
	_header(info["name"], info["color"])
	var choices: Array = t["choices"]
	var reply_h := choices.size() * 46.0 + (10.0 if not choices.is_empty() else 0.0)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 56)
	scroll.size = Vector2(_screen.size.x, _screen.size.y - 56 - reply_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_screen.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = _screen.size.x - 12
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for entry in t["log"]:
		var mine: bool = entry[0]
		var holder := HBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ME if mine else PANEL.lightened(0.08)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		bubble.add_theme_stylebox_override("panel", sb)
		var text := _label(entry[1], 15, Color(0.08, 0.04, 0.1) if mine else Color.WHITE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = minf(_text_width(entry[1], 15) + 4, 230)
		bubble.add_child(text)
		holder.add_child(bubble)
		list.add_child(holder)
	scroll.get_v_scroll_bar().changed.connect(func(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value), CONNECT_ONE_SHOT)
	for i in choices.size():
		var b := _button(choices[i][0], ME)
		b.position = Vector2(10, _screen.size.y - reply_h + i * 46.0)
		b.size = Vector2(_screen.size.x - 20, 38)
		var idx := i
		b.pressed.connect(func():
			world.story_reply(_contact, idx)
			_show("thread"))
		_screen.add_child(b)


func _browser() -> void:
	_header(Sites.title(_site), Color(0.45, 0.7, 1.0))
	var url := _label(Sites.url(_site), 13, MenuStyle.TEXT_DIM)
	url.position = Vector2(14, 44)
	_screen.add_child(url)
	var page := RichTextLabel.new()
	page.bbcode_enabled = true
	page.position = Vector2(10, 70)
	page.size = Vector2(_screen.size.x - 20, _screen.size.y - 76)
	page.add_theme_font_size_override("normal_font_size", 15)
	page.add_theme_font_size_override("bold_font_size", 17)
	page.add_theme_color_override("default_color", Color(0.9, 0.92, 1.0))
	page.text = Sites.page(_site)
	page.meta_clicked.connect(func(meta):
		_site = str(meta)
		_show("browser"))
	_screen.add_child(page)


func _bag() -> void:
	_header("Bag", Color(1.0, 0.6, 0.7))
	var money := _label("Wallet  " + PlayerState.format_money(PlayerState.money), 16, Color(1.0, 0.88, 0.55), _font)
	money.position = Vector2(14, 48)
	_screen.add_child(money)
	var y := 82.0
	if PlayerState.inventory.is_empty():
		var none := _label("Your bag is empty.\nShops and vending machines sell food and medicine.", 15, MenuStyle.TEXT_DIM)
		none.position = Vector2(14, y)
		none.size.x = _screen.size.x - 28
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_screen.add_child(none)
	for id in PlayerState.inventory:
		var item: Dictionary = Items.ITEMS.get(id, {})
		if item.is_empty():
			continue
		var row := Control.new()
		row.position = Vector2(8, y)
		row.size = Vector2(_screen.size.x - 16, 64)
		var icon_id: String = item["icon"]
		row.draw.connect(func():
			row.draw_rect(Rect2(Vector2.ZERO, row.size), PANEL)
			row.draw_rect(Rect2(Vector2(6, 6), Vector2(52, 52)), Items.RARITY_COLORS[item["rarity"]].darkened(0.3))
			Icons.draw(row, icon_id, Vector2(32, 32), 20.0, Color(0.95, 0.95, 1.0)))
		_screen.add_child(row)
		var caption := _label("%s  x%d" % [item["name"], PlayerState.inventory[id]], 15, Color.WHITE)
		caption.position = Vector2(68, 8)
		row.add_child(caption)
		var fx := []
		if item["heal"] > 0:
			fx.append("+%d HP" % item["heal"])
		if item["stamina"] > 0:
			fx.append("+%d stamina" % item["stamina"])
		var eff := _label("  ".join(fx), 12, Color(0.55, 1.0, 0.7))
		eff.position = Vector2(68, 30)
		row.add_child(eff)
		var use := _button("Use", Color(1.0, 0.6, 0.7))
		use.position = Vector2(row.size.x - 70, 4)
		use.size = Vector2(60, 30)
		for k in 4:
			var assigned: bool = PlayerState.hotbar[k] == id
			var slot := _button(str(k + 1), Color(1.0, 0.85, 0.45) if assigned else Color(0.35, 0.35, 0.45))
			slot.position = Vector2(row.size.x - 128 + k * 30, 38)
			slot.size = Vector2(26, 22)
			slot.add_theme_font_size_override("font_size", 12)
			var slot_i := k
			var slot_id: String = id
			slot.pressed.connect(func():
				# Toggle this item in quick slot k (one slot per item).
				var was: bool = PlayerState.hotbar[slot_i] == slot_id
				for j in 4:
					if PlayerState.hotbar[j] == slot_id:
						PlayerState.hotbar[j] = ""
				if not was:
					PlayerState.hotbar[slot_i] = slot_id
				_show("bag"))
			row.add_child(slot)
		var item_id: String = id
		use.pressed.connect(func():
			world.use_item(item_id)
			_show("bag"))
		row.add_child(use)
		y += 72.0


## CarGo: deliver owned cars, rent, buy, or call a taxi to where the heroine stands.
func _cargo() -> void:
	_header("CarGo", Color(1.0, 0.72, 0.35))
	var tabs := [["mine", "My cars"], ["rent", "Rent"], ["buy", "Buy"], ["taxi", "Taxi"]]
	for i in tabs.size():
		var on: bool = tabs[i][0] == _cargo_tab
		var b := _button(tabs[i][1], Color(1.0, 0.72, 0.35) if on else Color(0.3, 0.3, 0.4))
		b.position = Vector2(8 + i * 80, 48)
		b.size = Vector2(74, 30)
		b.add_theme_font_size_override("font_size", 13)
		var tab: String = tabs[i][0]
		b.pressed.connect(func():
			_cargo_tab = tab
			_show("cargo"))
		_screen.add_child(b)
	var y := 90.0
	match _cargo_tab:
		"mine":
			if PlayerState.cars.is_empty():
				_note("You don't own a car yet.\nBuy one in the Buy tab and it is yours to summon anywhere.", y)
			for i in PlayerState.cars.size():
				var car: Dictionary = PlayerState.cars[i]
				var idx := i
				_car_row(car["model"], Color(car["color"]), "Deliver  " + PlayerState.format_money(DELIVERY_FEE), y,
					func(): world.deliver_owned_car(idx))
				y += 70.0
		"rent":
			for r in world.RENTALS:
				var model: String = r[0]
				_car_row(model, Color(0.9, 0.9, 1.0), "Rent  " + PlayerState.format_money(r[1] + DELIVERY_FEE), y,
					func(): world.rent_car(model, r[1] + DELIVERY_FEE), r[2])
				y += 70.0
		"buy":
			for d in DEALER:
				var model: String = d[0]
				var owned := PlayerState.cars.any(func(c): return c["model"] == model)
				_car_row(model, Color(1.0, 0.85, 0.5), "Owned" if owned else "Buy  " + PlayerState.format_money(d[1]), y,
					(func(): pass) if owned else func(): world.buy_car(model, d[1]))
				y += 70.0
		"taxi":
			_note("A taxi pulls up right next to you.\nFare is paid when you pick a destination.", y)
			var b := _button("Call a taxi", Color(1.0, 0.75, 0.25))
			b.position = Vector2(20, y + 70)
			b.size = Vector2(_screen.size.x - 40, 44)
			b.pressed.connect(func():
				close()
				world.call_taxi())
			_screen.add_child(b)


func _car_row(model: String, tint: Color, action_text: String, y: float, action: Callable, title := "") -> void:
	var spec := CarModels.spec(model)
	var row := Control.new()
	row.position = Vector2(8, y)
	row.size = Vector2(_screen.size.x - 16, 62)
	row.draw.connect(func():
		row.draw_rect(Rect2(Vector2.ZERO, row.size), PANEL)
		Icons.draw(row, "car_" + model, Vector2(36, 31), 22.0, tint))
	_screen.add_child(row)
	var name_label := _label(title if not title.is_empty() else model.capitalize(), 15, Color.WHITE)
	name_label.position = Vector2(70, 8)
	row.add_child(name_label)
	var info := _label("%s · %d km/h" % ["EV" if spec.get("electric", false) else "Petrol", int(spec["top_speed"] * 3.6)], 12, MenuStyle.TEXT_DIM)
	info.position = Vector2(70, 34)
	row.add_child(info)
	var b := _button(action_text, Color(1.0, 0.72, 0.35))
	b.position = Vector2(row.size.x - 128, 14)
	b.size = Vector2(120, 34)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func():
		action.call()
		_show("cargo"))
	row.add_child(b)


func _note(text: String, y: float) -> void:
	var l := _label(text, 14, MenuStyle.TEXT_DIM)
	l.position = Vector2(14, y)
	l.size.x = _screen.size.x - 28
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen.add_child(l)


# --- Widgets ----------------------------------------------------------------------------------

func _header(title: String, color: Color) -> void:
	var bar := ColorRect.new()
	bar.color = Color(color, 0.25)
	bar.size = Vector2(_screen.size.x, 40)
	_screen.add_child(bar)
	var back := _label("‹", 30, Color.WHITE)
	back.position = Vector2(8, -2)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(_on_click.bind(_back))
	_screen.add_child(back)
	var t := _label(title, 18, Color.WHITE, _font)
	t.position = Vector2(36, 8)
	_screen.add_child(t)


func _tile(icon: String, color: Color) -> Control:
	var tile := Control.new()
	tile.size = Vector2(80, 80)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.draw.connect(func():
		tile.draw_rect(Rect2(Vector2.ZERO, tile.size), color.darkened(0.15))
		tile.draw_rect(Rect2(Vector2.ZERO, Vector2(tile.size.x, tile.size.y * 0.5)), Color(1, 1, 1, 0.12))
		Icons.draw(tile, icon, tile.size * 0.5, 26.0, Color(0.06, 0.04, 0.12)))
	return tile


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = color
	l.label_settings = s
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.15) if state == "hover" else (color.darkened(0.15) if state == "pressed" else color)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.08, 0.04, 0.1))
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.04, 0.1))
	b.add_theme_font_size_override("font_size", 15)
	return b


func _text_width(text: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _on_click(event: InputEvent, action: Callable) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		action.call()


func _draw_body() -> void:
	var s := _body.size
	# Rounded phone shell with a soft pastel wallpaper.
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.02, 0.02, 0.04)
	shell.set_corner_radius_all(34)
	shell.border_color = Color(0.85, 0.75, 0.95)
	shell.set_border_width_all(3)
	_body.draw_style_box(shell, Rect2(Vector2.ZERO, s))
	var screen := Rect2(SCREEN_MARGIN - Vector2(4, 4), _screen.size + Vector2(8, 8))
	var steps := 16
	for k in steps:
		var t := float(k) / steps
		_body.draw_rect(Rect2(screen.position + Vector2(0, screen.size.y * t), Vector2(screen.size.x, screen.size.y / steps + 1)),
				Color(0.22, 0.16, 0.38).lerp(Color(0.95, 0.55, 0.7), t * t) if _page == "home" else BG)
	# Status bar and notch.
	_body.draw_rect(Rect2(Vector2(s.x * 0.5 - 50, 12), Vector2(100, 18)), Color(0.02, 0.02, 0.04))
	_body.draw_string(_font, Vector2(30, 32), Time.get_time_string_from_system().substr(0, 5), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	_body.draw_rect(Rect2(Vector2(s.x - 58, 20), Vector2(26, 11)), Color.WHITE, false, 1.5)
	_body.draw_rect(Rect2(Vector2(s.x - 56, 22), Vector2(18, 7)), Color(0.55, 1.0, 0.6))
	_body.draw_rect(Rect2(Vector2(s.x * 0.5 - 50, s.y - 18), Vector2(100, 5)), Color(1, 1, 1, 0.6))
