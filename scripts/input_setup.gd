extends RefCounted
## Registers the game's input actions in code (keyboard + mouse). Safe to call more than once.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_F],
	"lock_on": [KEY_Q],
	"pause": [KEY_ESCAPE],
	"wheel": [KEY_TAB],
	"map": [KEY_M],
	"attack_strong": [KEY_E],
	"phone": [KEY_P],
	"block": [KEY_C, KEY_CTRL],
	"parry": [KEY_R],
	"crouch": [KEY_X],
	"prone": [KEY_Z],
	"item_1": [KEY_1],
	"item_2": [KEY_2],
	"item_3": [KEY_3],
	"item_4": [KEY_4],
}
const MOUSE := {
	"attack_light": [MOUSE_BUTTON_LEFT],
	"attack_heavy": [MOUSE_BUTTON_RIGHT],
	"lock_on": [MOUSE_BUTTON_MIDDLE],
	"block": [MOUSE_BUTTON_XBUTTON1],
	"parry": [MOUSE_BUTTON_XBUTTON2],
}


## Actions can have both keys and mouse buttons (lock-on: Q + middle mouse), so each action is
## cleared once and then gets every binding.
static func ensure() -> void:
	for action in KEYS.keys() + MOUSE.keys():
		_add(action)
	for action in KEYS:
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		for button in MOUSE[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


static func _add(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
