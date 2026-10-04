--[[
A house of the Ward, fallen in: its roof is open to the dark, rust rats nest in the rubble. A crack in the back wall
hides the cache of a thief.
]]
const legend = require("../legend")

return {
	name = "A Ruined House",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.7,
	foreground = "interior",
	legend = {
		r = { monster = "rust_rat" },
		_ = { ground = "chasm" },
		["?"] = { wall = "room_face_cracked", opens = "ruin_cache" },
		v = { secret = "ruin_cache" },
		c = { secret = "ruin_cache", prop = "chest", data = { items = { { "bomb", 3 }, { "quicksilver", 1 }, { "fig", 6 } } } },
		b = { prop = "rubble_pile" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "ruin" },
	},
	map = {
		"##############",
		"######vvv#####",
		"######vcv#####",
		"#WWWWWW?WWWWW#",
		"#...b..b...rb#",
		"#.r...__.....#",
		"#....___..r..#",
		"#.b..........#",
		"#...r....b..X#",
		"######11######",
	},
	decor = {
		"..............",
		"..............",
		"..............",
		"..............",
		"..........b...",
		"....b.........",
		"..b........b..",
		"......b.......",
		"..............",
		"..............",
	},
}
