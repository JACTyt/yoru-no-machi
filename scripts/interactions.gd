extends RefCounted
## Interaction-wheel options and the little scripted scenes behind them: talk (with dialogue
## choices), shake hands, kiss, kick and help out — for civilians and street thugs alike — plus
## emotes. `world` is the gameplay scene; it provides dialogue, player, city, notify(), pay(),
## lock_player(), set_waypoint(), spawn_pickup(), carrying and hearts().

const Lines := preload("res://scripts/npc/dialogue_lines.gd")
const City := preload("res://scripts/city/city_builder.gd")
const GameSettings := preload("res://scripts/game_settings.gd")

const RANGE := 3.0
const EMOTES := [["Dance", "ual1/Dance"], ["Phone", "ual2/Idle_TalkingPhone"], ["Fold arms", "ual2/Idle_FoldArms"], ["Lie down", "ual2/LayToIdle"]]
const THUG_ACCENT := Color(1.0, 0.35, 0.4)
const CIVILIAN_ACCENT := Color(0.6, 0.82, 1.0)


static func nearest_npc(player, max_dist := RANGE):
	var best = null
	var best_dist := max_dist
	for npc in player.get_tree().get_nodes_in_group("npcs") + player.get_tree().get_nodes_in_group("enemies"):
		if not npc.is_alive() or npc.hostile:
			continue
		var dist: float = npc.global_position.distance_to(player.global_position)
		if dist < best_dist:
			best = npc
			best_dist = dist
	return best


static func options(world, player) -> Array:
	var npc = nearest_npc(player)
	var has := npc != null
	var opts := [
		{"label": "Talk", "enabled": has, "action": func(): talk(world, player, npc)},
		{"label": "Shake hands", "enabled": has, "action": func(): shake_hands(world, player, npc)},
		{"label": "Kiss", "enabled": has, "action": func(): kiss(world, player, npc)},
		{"label": "Kick", "enabled": has, "action": func(): kick(world, player, npc)},
		{"label": "Help out", "enabled": has and not npc.request.is_empty(), "action": func(): help_out(world, player, npc)},
	]
	opts.append_array(emotes(player))
	return opts


static func emotes(player) -> Array:
	var opts := []
	for emote in EMOTES:
		opts.append({"label": emote[0], "enabled": player.visual.has_clips, "action": player.play_emote.bind(emote[1])})
	return opts


# --- Talk -------------------------------------------------------------------------------------

static func talk(world, player, npc) -> void:
	_line_up(player, npc, 1.3)
	npc.begin_talk(player.global_position)
	if not world.dialogue.closed.is_connected(npc.end_talk):
		world.dialogue.closed.connect(npc.end_talk, CONNECT_ONE_SHOT)
	var line: String
	if not String(npc.get("greeting") if npc.get("greeting") != null else "").is_empty():
		line = npc.greeting
	elif npc.mood >= 75:
		line = Lines.pick(Lines.GREET_FRIEND, {"name": GameSettings.heroine_name().get_slice(" ", 0)})
	elif npc.mood <= 15:
		line = Lines.pick(Lines.GREET_ENEMY)
	else:
		line = Lines.by(Lines.GREET, npc.personality)
	_say(world, npc, line, _root_choices(world, player, npc))


static func _say(world, npc, text: String, choices := []) -> void:
	world.dialogue.open(npc.npc_name, text, choices, THUG_ACCENT if npc.personality == "thug" else CIVILIAN_ACCENT)


## Reply followed by "Continue" (back to the topic list) or "Goodbye".
static func _reply(world, player, npc, text: String) -> void:
	_say(world, npc, text, [
		{"label": "Continue", "action": func(): _say(world, npc, "Anything else?", _root_choices(world, player, npc))},
		{"label": "Goodbye", "action": func(): npc.say(Lines.pick(Lines.GOODBYE))},
	])


static func _root_choices(world, player, npc) -> Array:
	var choices := [
		{"label": "Ask about the city", "action": func(): _tip(world, player, npc)},
		{"label": "Compliment", "action": func():
			npc.change_mood(4 if npc.personality == "grumpy" else 10)
			npc.react("ual2/Yes")
			_reply(world, player, npc, Lines.by(Lines.COMPLIMENT, npc.personality))},
		{"label": "Flirt", "action": func(): _flirt(world, player, npc)},
		{"label": "Insult", "action": func(): _insult(world, player, npc)},
	]
	if not npc.request.is_empty():
		choices.append({"label": "Need any help?", "action": func(): help_out(world, player, npc)})
	choices.append({"label": "Goodbye", "action": func(): npc.say(Lines.pick(Lines.GOODBYE))})
	return choices


static func _tip(world, player, npc) -> void:
	if world.city == null or world.city.places.is_empty() or randf() < 0.3:
		_reply(world, player, npc, Lines.pick(Lines.SMALL_TALK))
		return
	var ids: Array = world.city.places.keys()
	var place: Dictionary = world.city.places[ids[randi() % ids.size()]]
	var text := Lines.pick(Lines.TIP, {"place": place["name"], "district": City.district_name(place["door"])})
	_say(world, npc, text, [
		{"label": "Mark it on my map", "action": func():
			world.set_waypoint(place["door"], place["name"])
			_reply(world, player, npc, "There you go. Don't get lost!")},
		{"label": "Thanks", "action": func(): _say(world, npc, "Anything else?", _root_choices(world, player, npc))},
	])


static func _flirt(world, player, npc) -> void:
	var into_it: bool = npc.mood >= 55 or (npc.personality == "flirty" and npc.mood >= 35)
	if into_it:
		npc.change_mood(10)
		player.visual.set_expression("happy", 0.9)
		world.hearts(npc.global_position + Vector3.UP * 1.9)
		_reply(world, player, npc, Lines.by(Lines.FLIRT_OK, npc.personality))
	else:
		npc.change_mood(-8)
		npc.react("ual2/Idle_No")
		_reply(world, player, npc, Lines.by(Lines.FLIRT_NO, npc.personality))


static func _insult(world, player, npc) -> void:
	npc.change_mood(-25)
	player.visual.set_expression("angry", 0.8)
	_say(world, npc, Lines.by(Lines.INSULT, npc.personality), [{"label": "Leave", "action": func():
		if npc.personality == "thug":
			npc.provoke()
		elif npc.has_method("flee") and npc.mood < 20:
			npc.flee(player.global_position)}])


# --- Physical interactions --------------------------------------------------------------------

static func shake_hands(world, player, npc) -> void:
	if npc.mood < 15:
		npc.react("ual2/Idle_No")
		npc.say(Lines.pick(Lines.HANDSHAKE_NO))
		return
	_line_up(player, npc, 0.95)
	world.lock_player(1.5)
	player.perform("ual1/Interact", 1.2)
	npc.react("ual1/Interact", 1.2)
	player.visual.set_expression("happy", 0.6)
	await player.get_tree().create_timer(0.6).timeout
	if is_instance_valid(npc):
		npc.change_mood(6)
		npc.say(Lines.pick(Lines.HANDSHAKE))


static func kiss(world, player, npc) -> void:
	var willing: bool = npc.mood >= 65 or (npc.personality == "flirty" and npc.mood >= 45)
	_line_up(player, npc, 0.7)
	world.lock_player(1.8)
	player.perform("ual1/Interact", 0.8)
	player.visual.set_expression("happy", 1.0)
	await player.get_tree().create_timer(0.45).timeout
	if not is_instance_valid(npc):
		return
	if willing:
		npc.change_mood(10)
		npc.react("ual2/Yes")
		world.hearts(npc.global_position.lerp(player.global_position, 0.5) + Vector3.UP * 1.7)
		npc.say(Lines.pick(Lines.KISS_OK))
		if npc.personality == "thug":
			npc.hostile = false
	else:
		npc.change_mood(-15)
		npc.react("ual1/Punch_Jab", 1.4)
		await player.get_tree().create_timer(0.2).timeout
		if is_instance_valid(npc):
			npc.say(Lines.pick(Lines.KISS_NO))
			player.take_hit(2.0, (player.global_position - npc.global_position).normalized() * 1.5)
			player.visual.set_expression("sad", 0.8)


static func kick(_world, player, npc) -> void:
	_line_up(player, npc, 1.2)
	player.attack_target("heavy", npc)


# --- Help out ---------------------------------------------------------------------------------

static func help_out(world, player, npc) -> void:
	var r: Dictionary = npc.request
	if r.is_empty():
		return
	_line_up(player, npc, 1.3)
	npc.begin_talk(player.global_position)
	if not world.dialogue.closed.is_connected(npc.end_talk):
		world.dialogue.closed.connect(npc.end_talk, CONNECT_ONE_SHOT)
	if r["type"] == "lost_item":
		if world.carrying.get("npc") == npc:
			world.carrying = {}
			world.clear_waypoint()
			npc.request = {}
			npc.keep = false
			npc.change_mood(25)
			npc.react("ual2/Yes")
			world.pay(-int(r["reward"]))
			_say(world, npc, Lines.pick(Lines.LOST_THANKS, {"item": r["item"]}))
		elif r.get("accepted", false):
			_say(world, npc, "Any luck finding my %s? It should be close by." % r["item"])
		else:
			_say(world, npc, Lines.pick(Lines.LOST_ITEM, {"item": r["item"]}), [
				{"label": "I'll find it", "action": func():
					r["accepted"] = true
					npc.keep = true
					world.spawn_pickup(npc)
					_say(world, npc, "Really? Thank you! I'll wait right here.")},
				{"label": "Sorry, I'm busy", "action": func(): npc.change_mood(-3)},
			])
	elif r["type"] == "directions":
		var place: Dictionary = world.city.places[r["place"]]
		var answer := City.district_name(place["door"])
		var districts := ["Hoshimachi Central", "Kitano Heights", "Sakuragaoka", "Minatomachi", "Old Town", "Ring Road"]
		districts.erase(answer)
		districts.shuffle()
		var picks := [answer, districts[0], districts[1]]
		picks.shuffle()
		var choices := []
		for d in picks:
			choices.append({"label": d, "action": func():
				npc.request = {}
				if d == answer:
					npc.change_mood(15)
					npc.react("ual2/Yes")
					world.pay(-300)
					_say(world, npc, Lines.pick(Lines.DIRECTIONS_OK))
				else:
					npc.change_mood(-5)
					_say(world, npc, Lines.pick(Lines.DIRECTIONS_NO))})
		choices.append({"label": "No idea, sorry", "action": func(): npc.request = {}})
		_say(world, npc, Lines.pick(Lines.DIRECTIONS, {"place": place["name"]}), choices)


## Steps the heroine to `dist` from the NPC and turns them toward each other.
static func _line_up(player, npc, dist: float) -> void:
	var away: Vector3 = player.global_position - npc.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.FORWARD
	if player.is_on_floor():
		var spot: Vector3 = npc.global_position + away.normalized() * dist
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
	player.face_towards(npc.global_position)
	npc.face(player.global_position)
