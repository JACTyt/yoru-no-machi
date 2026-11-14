extends RefCounted
## Phone storyline: text threads with three friends. Each node is a burst of messages from one
## contact, optionally gated by a `wait` condition, with reply `choices` [text, next node, effects?]
## or an automatic `then`. Effects: {"waypoint": place id, "money": yen, "unlock": [node ids]}.
## Progress lives in PlayerState.story so it is saved with the slot.

const PlayerState := preload("res://scripts/player_state.gd")

const CONTACTS := {
	"mio": {"name": "Mio Asakura", "color": Color(1.0, 0.55, 0.72), "bio": "Best friend. Gamer. Talks in all lowercase."},
	"ren": {"name": "Ren Kirishima", "color": Color(0.45, 0.6, 1.0), "bio": "Informant. Knows everything that happens in Hoshimachi."},
	"natsume": {"name": "Officer Natsume", "color": Color(0.4, 0.85, 0.7), "bio": "Hoshimachi PD. Stern, fair, tired."},
}
const START := "mio_1"

const NODES := {
	"mio_1": {"wait": {"time": 20.0}, "msgs": ["heyyy you awake?", "did you see the urban legends board?? someone posted a blurry pic of 'the girl in the red scarf' beating up five guys in Kitano lol", "...that's not you, right? :/"],
		"choices": [["Of course not.", "mio_2a"], ["Maybe ;)", "mio_2b"]]},
	"mio_2a": {"wait": {"time": 3.0}, "msgs": ["phew. ok. anyway!!", "new melon pan batch at 24H Mart, you HAVE to try it. meet me there?"],
		"choices": [["On my way.", "mio_3", {"waypoint": "konbini"}]]},
	"mio_2b": {"wait": {"time": 3.0}, "msgs": ["WAIT WHAT", "ok we are talking about this in person. 24H Mart. melon pan. now."],
		"choices": [["Coming.", "mio_3", {"waypoint": "konbini"}]]},
	"mio_3": {"wait": {"visit": "konbini"}, "msgs": ["you're here?? ...wait. i'm at the OTHER 24H Mart lol", "whatever, sent you some cash. get the melon pan.", "also — Ren wants to talk to you. don't be weird. he's... intense."],
		"effects": {"money": 1000, "unlock": ["ren_1"]}, "choices": [["Who's Ren?", "mio_4"], ["Thanks, Mio.", "mio_4"]]},
	"mio_4": {"wait": {"time": 2.0}, "msgs": ["my cousin's friend. knows everything that happens in this city.", "be careful ok? <3"]},
	"mio_5": {"wait": {"time": 40.0}, "msgs": ["ok the red scarf thread has 2,000 replies now", "someone drew FAN ART of you?? it's actually really good", "...you're famous, idiot. be careful <3"],
		"choices": [["Send me the link.", "mio_6"], ["Delete it!!", "mio_6"]]},
	"mio_6": {"wait": {"time": 2.0}, "msgs": ["urban legends board, top post. not deleting anything lol. bye!!"], "effects": {"flag": "fanart"}},

	"ren_1": {"wait": {"time": 15.0}, "msgs": ["You're the courier Mio talks about.", "People in Kitano Heights keep getting hurt. A gang that calls itself the Grin Masks.", "We should talk. University library."],
		"choices": [["Why me?", "ren_2a", {"waypoint": "university"}], ["I'll be there.", "ren_2b", {"waypoint": "university"}]]},
	"ren_2a": {"wait": {"time": 2.0}, "msgs": ["Because you're the only one who fights back.", "I'll be waiting."], "then": "ren_3"},
	"ren_2b": {"wait": {"time": 2.0}, "msgs": ["Good. I'll be waiting."], "then": "ren_3"},
	"ren_3": {"wait": {"visit": "university"}, "msgs": ["You came. I'm watching from the roof — didn't want to be seen.", "The masks hang around the corners of Hoshimachi Central. Thin their numbers. Leave regular people out of it.", "Text me once you've dealt with three of them."],
		"choices": [["Leave it to me.", "ren_4"], ["What's in it for me?", "ren_4"]]},
	"ren_4": {"wait": {"stat": ["thugs_defeated", 3]}, "msgs": ["Three Grin Masks down. Word travels fast.", "Sent you something for the trouble.", "Someone from the police will contact you. Natsume. Be careful with her."],
		"effects": {"money": 3000, "unlock": ["natsume_1", "mio_5"]}},

	"natsume_1": {"wait": {"time": 20.0}, "msgs": ["This is Officer Natsume, Hoshimachi PD.", "I know what you've been doing on Central.", "Vigilantes make my job harder. ...But the Grin Masks have been quiet this week. Unofficially: thank you."],
		"choices": [["Just helping out.", "natsume_2a"], ["Arrest me, then.", "natsume_2b"]]},
	"natsume_2a": {"wait": {"time": 3.0}, "msgs": ["Keep it clean. No civilians hurt, no stolen cars.", "If you need patching up, Pharmacist Sato owes me a favour."], "then": "natsume_warn"},
	"natsume_2b": {"wait": {"time": 3.0}, "msgs": ["Ha. Don't tempt me.", "Keep it clean. No civilians hurt, no stolen cars."], "then": "natsume_warn"},
	"natsume_warn": {"wait": {"stat_more": "cars_stolen"}, "msgs": ["I just read a stolen car report. Witnesses mention a girl. Was that you?", "Last warning. I can only look the other way so many times."],
		"choices": [["Won't happen again.", "natsume_end"], ["It was an emergency.", "natsume_end"]]},
	"natsume_end": {"wait": {"time": 3.0}, "msgs": ["...Fine. Stay safe out there."]},
}


## Story state: {"threads": {contact: {"log": [[from_me, text]], "choices": [...], "unread": n}},
##  "pending": [{"node", "since", "base"}], "flags": [], "time": seconds}
static func state() -> Dictionary:
	var s := PlayerState.story
	if not s.has("threads"):
		s["threads"] = {}
		s["pending"] = [{"node": START, "since": 0.0, "base": 0}]
		s["flags"] = []
		s["time"] = 0.0
	return s


static func contact_of(node: String) -> String:
	return node.get_slice("_", 0)


static func thread(contact: String) -> Dictionary:
	var threads: Dictionary = state()["threads"]
	if not threads.has(contact):
		threads[contact] = {"log": [], "choices": [], "unread": 0}
	return threads[contact]


static func unread_total() -> int:
	var n := 0
	for c in state()["threads"]:
		n += int(state()["threads"][c]["unread"])
	return n


static func has_flag(flag: String) -> bool:
	return state()["flags"].has(flag)


## Advances timers and delivers every pending node whose condition is met. `inside` is the place
## id the heroine is in ("" outdoors). Returns the delivered node ids (for notifications).
static func tick(delta: float, inside: String) -> Array:
	var s := state()
	s["time"] = float(s["time"]) + delta
	var delivered := []
	for p in s["pending"].duplicate():
		var node: Dictionary = NODES[p["node"]]
		var wait: Dictionary = node.get("wait", {})
		var ready := true
		if wait.has("time"):
			ready = float(s["time"]) - float(p["since"]) >= float(wait["time"])
		elif wait.has("visit"):
			ready = inside == wait["visit"]
		elif wait.has("stat"):
			ready = int(PlayerState.stats.get(wait["stat"][0], 0)) >= int(wait["stat"][1])
		elif wait.has("stat_more"):
			ready = int(PlayerState.stats.get(wait["stat_more"], 0)) > int(p["base"])
		if ready:
			s["pending"].erase(p)
			_deliver(p["node"])
			delivered.append(p["node"])
	return delivered


static func _deliver(id: String) -> void:
	var node: Dictionary = NODES[id]
	var t := thread(contact_of(id))
	for m in node["msgs"]:
		t["log"].append([false, m])
	t["unread"] = int(t["unread"]) + node["msgs"].size()
	t["choices"] = node.get("choices", [])
	var fx: Dictionary = node.get("effects", {})
	PlayerState.money += int(fx.get("money", 0))
	if fx.has("flag"):
		state()["flags"].append(fx["flag"])
	for u in fx.get("unlock", []):
		_schedule(u)
	if node.has("then"):
		_schedule(node["then"])


static func _schedule(id: String) -> void:
	var wait: Dictionary = NODES[id].get("wait", {})
	var base := int(PlayerState.stats.get(wait.get("stat_more", ""), 0))
	state()["pending"].append({"node": id, "since": state()["time"], "base": base})


## The heroine picks reply `index` in `contact`'s thread. Returns the choice's effects.
static func reply(contact: String, index: int) -> Dictionary:
	var t := thread(contact)
	var choice: Array = t["choices"][index]
	t["log"].append([true, choice[0]])
	t["choices"] = []
	_schedule(choice[1])
	return choice[2] if choice.size() > 2 else {}


## Node that delivered `id`'s money, for the notification text.
static func money_of(id: String) -> int:
	return int(NODES[id].get("effects", {}).get("money", 0))
