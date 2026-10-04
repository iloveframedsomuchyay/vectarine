--[[
The guard post of the Ward: a crimson lens sweeps the room (it sees everyone, citizens too); the lever of the lift to
the Seagate is on the far wall. The orders of the High Tide on the desk. Hatches full of hounds. Ways: time the sweep
behind the desks and the crates, or push a crate onto a hatch first.
]]
const legend = require("../legend")

return {
	name = "The Guard Post",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.45,
	foreground = "interior",
	legend = {
		v = { prop = "lever", data = { id = "seagate", text = "You pull the lever. Far above, chains rattle: the lift of the Seagate comes down." } },
		k = { prop = "lens", data = { dir = "left", sweep = 160, range = 9, group = "guard", crimson = true } },
		h = { prop = "hatch", data = { group = "guard", spawn = "hound", count = 2 } },
		n = { prop = "note", data = { lore = "guard_orders" } },
		o = { prop = "chest", data = { items = { { "smoke_vial", 1 }, { "amber_salve", 1 }, { "bomb", 2 } } } },
		X = { prop = "city_crate" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "guard" },
	},
	map = {
		"################",
		"#WWWWWWWWWWWWWW#",
		"#v.........D..o#",
		"#....X.........#",
		"#.......k......#",
		"#..DD......X...#",
		"#.........h....#",
		"#.n...h........#",
		"#X.............#",
		"#######11#######",
	},
	decor = {
		"................",
		"....w......w....",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	},
}
