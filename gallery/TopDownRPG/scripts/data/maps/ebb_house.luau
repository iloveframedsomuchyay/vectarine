--[[
Coral's house: a house of the Ebb, its door struck with chalk. Cold. A crib, a toy chest, the table. Her mother's
letter (where she hid Coral's token: in her boat, in the basin by the old bridge) and Coral's drawing of it. A crack
in the wall of the larder: the neighbors' cellar, where they hid what the collectors didn't take.
]]
const legend = require("../legend")

return {
	name = "Coral's House",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.55,
	foreground = "interior",
	legend = {
		s = { prop = "stove_cold" },
		b = { prop = "crib" },
		m = { prop = "note", data = { lore = "coral_drawing" } },
		n = { prop = "note", data = { lore = "coral_letter" } },
		["?"] = { wall = "room_face_cracked", opens = "ebb_cellar" },
		v = { secret = "ebb_cellar" },
		c = { secret = "ebb_cellar", prop = "chest", data = { items = { { "energy_core", 1 }, { "salt_hardtack", 3 } } } },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "ebb" },
	},
	map = {
		"############",
		"####vvv#####",
		"####vcv#####",
		"#WWWW?WWWWW#",
		"#U....s..b.#",
		"#.........E#",
		"#..ThT.....#",
		"#...n...m..#",
		"#..........#",
		"####11######",
	},
	decor = {
		"............",
		"............",
		"............",
		"..........w.",
		"............",
		"........r...",
		"............",
		"............",
		"............",
		"............",
	},
}
