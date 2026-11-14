extends Control
## Save-file selection after Start Game: three slots in the title-screen style. Empty slots start a
## new game with the heroine chosen on the title screen; filled ones continue. Del / X clears a
## slot after confirmation, Esc goes back.

const SaveSystem := preload("res://scripts/save_system.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const MenuStyle := preload("res://scripts/ui/menu_style.gd")
const BG_SHADER := preload("res://shaders/menu_background.gdshader")

const GAME_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const ROW_SIZE := Vector2(820, 116)
## Selection index of the Back item, after the slots.
const BACK := SaveSystem.SLOTS

var font: Font
var title: Label
var rows: Array[SlotRow] = []
var back: Label
var selected := 0
var confirming := -1 ## Slot awaiting clear confirmation, or -1.
var confirm_yes := false
var fade: ColorRect
var busy := false
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	font = MenuStyle.font()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = BG_SHADER
	bg.material = bg_mat
	bg.show_behind_parent = true
	add_child(bg)
	MenuStyle.add_motes(self, 70, Vector2(0.08, 0.3), 0.45)

	title = Label.new()
	title.text = "SELECT FILE"
	title.label_settings = MenuStyle.label_settings(font, 64, Color(0.88, 0.92, 1.0), 0.35)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position.y = get_viewport_rect().size.y * 0.1

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.position.y += 40
	add_child(box)
	for i in SaveSystem.SLOTS:
		var row := _make_row(i)
		box.add_child(row)
		rows.append(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	box.add_child(spacer)
	back = _label(28, MenuStyle.TEXT_DIM)
	back.text = "Back"
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.mouse_entered.connect(_select.bind(BACK))
	back.gui_input.connect(_on_click.bind(_activate.bind(BACK)))
	box.add_child(back)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)
	_select(0)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.label_settings = MenuStyle.label_settings(font, size, color, 0.0)
	return l


func _make_row(i: int) -> SlotRow:
	var row := SlotRow.new()
	row.screen = self
	row.index = i
	row.custom_minimum_size = ROW_SIZE
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_entered.connect(_select.bind(i))
	row.gui_input.connect(_on_click.bind(_activate.bind(i)))

	row.number = _label(56, MenuStyle.TEXT_DIM)
	row.number.text = str(i + 1)
	row.number.position = Vector2(40, 18)
	row.heading = _label(30, MenuStyle.TEXT_DIM)
	row.heading.position = Vector2(124, 20)
	row.detail = _label(18, MenuStyle.TEXT_DIM)
	row.detail.position = Vector2(126, 66)
	row.date = _label(16, MenuStyle.TEXT_DIM)
	row.date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.date.position = Vector2(ROW_SIZE.x - 300, 26)
	row.date.size = Vector2(260, 24)
	for l in [row.number, row.heading, row.detail, row.date]:
		row.add_child(l)
	row.clear = _action(row, "Clear", Vector2(ROW_SIZE.x - 140, 64), _ask_clear.bind(i))
	row.yes = _action(row, "Yes", Vector2(ROW_SIZE.x - 250, 40), _resolve_clear.bind(true))
	row.no = _action(row, "No", Vector2(ROW_SIZE.x - 140, 40), _resolve_clear.bind(false))
	return row


## Small clickable word inside a slot row.
func _action(row: Control, text: String, pos: Vector2, action: Callable) -> Label:
	var l := _label(20, MenuStyle.TEXT_DIM)
	l.text = text
	l.position = pos
	l.size = Vector2(100, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_entered.connect(func(): l.label_settings.font_color = MenuStyle.TEXT_LIT)
	l.mouse_exited.connect(_refresh)
	l.gui_input.connect(_on_click.bind(action))
	row.add_child(l)
	return l


func _on_click(event: InputEvent, action: Callable) -> void:
	if busy:
		return
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		action.call()


func _select(i: int) -> void:
	if busy or confirming >= 0:
		return
	selected = i
	_refresh()


func _refresh() -> void:
	for row in rows:
		var i := row.index
		var lit := selected == i
		var text_color := MenuStyle.TEXT_LIT if lit else MenuStyle.TEXT_DIM
		var data := SaveSystem.read(i)
		row.has_data = not data.is_empty()
		row.number.label_settings.font_color = text_color
		row.number.label_settings.shadow_color.a = 0.45 if lit else 0.0
		row.heading.label_settings.font_color = text_color
		row.date.visible = false
		row.clear.visible = false
		row.yes.visible = false
		row.no.visible = false
		if confirming == i:
			row.heading.text = "Clear this file?"
			row.detail.text = "This cannot be undone."
			row.yes.visible = true
			row.no.visible = true
			row.yes.label_settings.font_color = MenuStyle.TEXT_LIT if confirm_yes else MenuStyle.TEXT_DIM
			row.no.label_settings.font_color = MenuStyle.TEXT_DIM if confirm_yes else MenuStyle.TEXT_LIT
		elif data.is_empty():
			row.heading.text = "New Game"
			row.detail.text = "as %s" % GameSettings.heroine_name()
		else:
			var hero: Dictionary = GameSettings.HEROINES.get(data.get("heroine", ""), {})
			row.heading.text = hero.get("name", "Unknown")
			row.detail.text = "%s   ·   %s" % [data.get("district", "Hoshimachi"), SaveSystem.format_play_time(float(data.get("play_time", 0.0)))]
			row.date.text = SaveSystem.format_date(int(data.get("saved_at", 0)))
			row.date.visible = true
			row.clear.visible = lit
			row.clear.label_settings.font_color = MenuStyle.TEXT_DIM
	back.label_settings.font_color = MenuStyle.TEXT_LIT if selected == BACK else MenuStyle.TEXT_DIM
	back.label_settings.shadow_color.a = 0.45 if selected == BACK else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if confirming >= 0:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			confirm_yes = not confirm_yes
			_refresh()
		elif event.is_action_pressed("ui_accept"):
			_resolve_clear(confirm_yes)
		elif event.is_action_pressed("ui_cancel"):
			_resolve_clear(false)
		return
	if event.is_action_pressed("ui_down"):
		_select((selected + 1) % (BACK + 1))
	elif event.is_action_pressed("ui_up"):
		_select((selected + BACK) % (BACK + 1))
	elif event.is_action_pressed("ui_accept"):
		_activate(selected)
	elif event.is_action_pressed("ui_cancel"):
		_activate(BACK)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event.keycode == KEY_DELETE or event.keycode == KEY_X) and selected < BACK:
		_ask_clear(selected)


func _ask_clear(i: int) -> void:
	if not rows[i].has_data:
		return
	selected = i
	confirming = i
	confirm_yes = false
	_refresh()


func _resolve_clear(yes: bool) -> void:
	if confirming < 0:
		return
	if yes:
		SaveSystem.erase(confirming)
	confirming = -1
	_refresh()


func _activate(i: int) -> void:
	if busy or confirming >= 0:
		return
	selected = i
	_refresh()
	busy = true
	var target := MENU_SCENE
	if i < BACK:
		SaveSystem.begin(i)
		target = GAME_SCENE
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(get_tree().change_scene_to_file.bind(target))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	for row in rows:
		row.queue_redraw()


func _draw() -> void:
	var center_x := size.x * 0.5
	var div_y := title.position.y + title.get_minimum_size().y + 8.0
	MenuStyle.flourish(self, Vector2(center_x, div_y), 220.0, 1.0, Color(MenuStyle.ORNAMENT, 0.7))
	MenuStyle.flourish(self, Vector2(center_x, div_y), 220.0, -1.0, Color(MenuStyle.ORNAMENT, 0.7))
	MenuStyle.diamond(self, Vector2(center_x, div_y), 6.0, MenuStyle.ORNAMENT)
	if selected == BACK:
		var mid := back.global_position + back.size * 0.5 - global_position
		var pulse := 0.75 + 0.25 * sin(_time * 3.0)
		for side in [-1.0, 1.0]:
			var p := mid + Vector2(side * 70.0, 0)
			MenuStyle.diamond(self, p, 5.0, Color(MenuStyle.ORNAMENT, pulse))
			MenuStyle.flourish(self, p + Vector2(side * 8.0, 0), 36.0, side, Color(MenuStyle.ORNAMENT, 0.6 * pulse))


## One save slot: hairline frame that brightens when selected, with breathing side diamonds.
class SlotRow extends Control:
	var screen
	var index := 0
	var has_data := false
	var number: Label
	var heading: Label
	var detail: Label
	var date: Label
	var clear: Label
	var yes: Label
	var no: Label

	func _draw() -> void:
		var lit: bool = screen.selected == index
		var a := 1.0 if lit else 0.3
		var line := Color(MenuStyle.ORNAMENT, 0.75 * a)
		if lit:
			draw_rect(Rect2(Vector2(size.x * 0.1, 0), Vector2(size.x * 0.8, size.y)), Color(0.55, 0.7, 1.0, 0.05))
		for y in [0.0, size.y]:
			MenuStyle.flourish(self, Vector2(size.x * 0.5, y), size.x * 0.5, 1.0, line)
			MenuStyle.flourish(self, Vector2(size.x * 0.5, y), size.x * 0.5, -1.0, line)
			MenuStyle.diamond(self, Vector2(size.x * 0.5, y), 4.0, line)
		# Divider between the slot number and its contents.
		draw_line(Vector2(104, size.y * 0.22), Vector2(104, size.y * 0.78), Color(MenuStyle.ORNAMENT, 0.4 * a), 1.0, true)
		if lit:
			var pulse := 0.75 + 0.25 * sin(screen._time * 3.0)
			for side in [-1.0, 1.0]:
				var p := Vector2(size.x * 0.5 + side * (size.x * 0.5 + 18.0), size.y * 0.5)
				MenuStyle.diamond(self, p, 5.0, Color(MenuStyle.ORNAMENT, pulse))
