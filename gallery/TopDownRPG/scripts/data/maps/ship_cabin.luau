--[[
The cabin of a ship of the Salt, stranded on the seabed: the captain's desk, his log, his bunk. A crack in the planks
of the bulkhead.
]]
const legend = require("../legend")

return {
	name = "A Captain's Cabin",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.55,
	foreground = "interior",
	legend = {
		n = { prop = "note", data = { lore = "captain_log" } },
		["?"] = { wall = "room_face_cracked", opens = "cabin_cache" },
		v = { secret = "cabin_cache" },
		c = { secret = "cabin_cache", prop = "chest", data = { items = { { "energy_core", 1 }, { "salt_fury", 2 }, { "fig", 5 } } } },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "dry_harbor", entry = "ship" },
	},
	map = {
		"############",
		"#####vvv####",
		"#####vcv####",
		"#WWWWW?WWWW#",
		"#D..n....E.#",
		"#.........E#",
		"#X.....T.h.#",
		"####11######",
	},
}
