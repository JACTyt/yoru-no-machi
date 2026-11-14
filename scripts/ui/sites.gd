extends RefCounted
## In-game websites for the phone browser (BBCode). Links use [url=site_id]. Pages react to the
## heroine's deeds (stats) and story flags.

const PlayerState := preload("res://scripts/player_state.gd")
const Story := preload("res://scripts/story.gd")
const City := preload("res://scripts/city/city_builder.gd")

const SITES := {
	"home": ["Bookmarks", "phone://bookmarks"],
	"news": ["Hoshimachi Times", "hoshimachi-times.jp"],
	"forum": ["Urban Legends Board", "urbanlegends.board/hoshimachi"],
	"transit": ["Hoshimachi Transit", "transit.hoshimachi.jp"],
	"weather": ["Sky Watch", "skywatch.jp/hoshimachi"],
}
const ACCENT := "#7fb8ff"


static func title(id: String) -> String:
	return SITES.get(id, SITES["home"])[0]


static func url(id: String) -> String:
	return SITES.get(id, SITES["home"])[1]


static func page(id: String) -> String:
	match id:
		"news":
			return _news()
		"forum":
			return _forum()
		"transit":
			return _transit()
		"weather":
			return _weather()
	var out := "[b]Bookmarks[/b]\n\n"
	for site in ["news", "forum", "transit", "weather"]:
		out += "[url=%s][color=%s][b]%s[/b][/color][/url]\n[color=#9aa0b8]%s[/color]\n\n" % [site, ACCENT, SITES[site][0], SITES[site][1]]
	return out


static func _news() -> String:
	var fights := int(PlayerState.stats.get("thugs_defeated", 0))
	var cars := int(PlayerState.stats.get("cars_stolen", 0))
	var out := "[b][font_size=20]HOSHIMACHI TIMES[/font_size][/b]\n[color=#9aa0b8]Your city. Your news.[/color]\n\n"
	if fights > 0:
		out += "[b]Grin Masks on the run?[/b]\nPolice confirm %d gang members were found 'thoroughly beaten' near Central this month. Witnesses describe a young woman.\n\n" % fights
	if cars > 0:
		out += "[b]Car thefts rise[/b]\n%d vehicles reported stolen in broad daylight. Officer Natsume: 'We know who you are.'\n\n" % cars
	out += "[b]Summer festival returns[/b]\nFireworks over the harbour next week; trains run all night.\n\n"
	out += "[b]Cherry blossoms early in Sakuragaoka[/b]\nThe park benches are reportedly 'the best seats in the city'.\n\n"
	out += "[b]STARLIGHT surprise show[/b]\nThe idol group teases a live at Hoshimachi University.\n\n"
	out += "[url=home][color=%s]‹ Bookmarks[/color][/url]" % ACCENT
	return out


static func _forum() -> String:
	var out := "[b][font_size=20]urban legends board[/font_size][/b]\n[color=#9aa0b8]/hoshimachi — anonymous[/color]\n\n"
	if Story.has_flag("fanart"):
		out += "[color=#ff8fb3][b]▲ 2,341[/b][/color]  [b]i drew the red scarf girl[/b]\n[i](an illustration of a girl mid-spin-kick, scarf flying, five masked guys in the air)[/i]\n> she's real and she saved my brother\n> drawing is 10/10 the scarf physics\n\n"
	out += "[color=#ff8fb3][b]▲ 1,208[/b][/color]  [b]the girl in the red scarf (blurry pic)[/b]\n> five guys. FIVE. she didn't even look tired\n> it's an ad for a game, calm down\n> my cousin saw her buy melon pan at 24H Mart\n\n"
	out += "[color=#ff8fb3][b]▲ 640[/b][/color]  [b]the guardian of the night streets[/b]\n> old legend: a spirit protects anyone kind to strangers\n> help people on the street and see what happens\n\n"
	out += "[color=#ff8fb3][b]▲ 302[/b][/color]  [b]taxi driver says passenger 'teleported'[/b]\n> they literally always do that lol\n\n"
	out += "[url=home][color=%s]‹ Bookmarks[/color][/url]" % ACCENT
	return out


static func _transit() -> String:
	var out := "[b][font_size=20]HOSHIMACHI TRANSIT[/font_size][/b]\n\n[b]City bus[/b] — flat fare [color=#ffd479]¥210[/color]\nWait at any stop and choose a destination.\n\n"
	for stop in City.BUS_STOPS:
		out += "  • %s\n" % stop[0]
	out += "\n[b]Taxis[/b] — ¥300 + ¥4/m. Wave one down anywhere.\n\n[b]Fuel today[/b]\n  Petrol  [color=#ffd479]¥168 / L[/color]\n  EV charging  [color=#ffd479]¥45 / kWh[/color]\n"
	for id in City.STATIONS:
		out += "  • %s (%s)\n" % [City.STATIONS[id]["name"], "EV" if City.STATIONS[id]["kind"] == "ev" else "petrol"]
	out += "\n[url=home][color=%s]‹ Bookmarks[/color][/url]" % ACCENT
	return out


static func _weather() -> String:
	return ("[b][font_size=20]SKY WATCH[/font_size][/b]\n\n[b]Today[/b]  ☀ 24°C, clear, light breeze from the harbour.\n"
		+ "[b]Tonight[/b]  ☾ 18°C, perfect for a walk.\n[b]Tomorrow[/b]  ⛅ 22°C, scattered clouds.\n\n"
		+ "UV index moderate. Cherry blossom forecast: peak bloom in Sakuragaoka this weekend.\n\n[url=home][color=%s]‹ Bookmarks[/color][/url]" % ACCENT)
