extends Node
## Single owner of Engine.time_scale. Effects request a scale until a real-time deadline (hit-stop,
## slow motion) or hold one until released (interaction wheel); the slowest active request wins and
## time returns to normal on its own when they expire, so it can never get stuck.

const SELF_PATH := "res://scripts/combat/time_scale.gd"

static var _requests := {} ## key → [scale, until_msec] (until -1 = held)
static var _node: Node


static func request(tree: SceneTree, key: String, scale: float, seconds: float) -> void:
	_ensure(tree)
	_requests[key] = [scale, Time.get_ticks_msec() + int(seconds * 1000.0)]
	_apply()


static func hold(tree: SceneTree, key: String, scale: float) -> void:
	_ensure(tree)
	_requests[key] = [scale, -1]
	_apply()


static func release(key: String) -> void:
	_requests.erase(key)
	_apply()


## Drops every request (leaving a scene, pausing to menus).
static func clear() -> void:
	_requests.clear()
	Engine.time_scale = 1.0


static func _apply() -> void:
	var now := Time.get_ticks_msec()
	var scale := 1.0
	for key in _requests.keys():
		var r: Array = _requests[key]
		if r[1] >= 0 and now >= r[1]:
			_requests.erase(key)
		else:
			scale = minf(scale, r[0])
	Engine.time_scale = scale


static func _ensure(tree: SceneTree) -> void:
	if _node != null and is_instance_valid(_node):
		return
	_node = (load(SELF_PATH) as GDScript).new()
	_node.name = "TimeScale"
	_node.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_node)


func _process(_delta: float) -> void:
	_apply()
