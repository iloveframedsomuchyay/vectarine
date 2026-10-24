--[[
The warehouse by the south street: crates, crates, crates. A crimson lens watches the floor, two hatches wait under
it, and the crates can be pushed. The chest of the dockers is in the back.
]]
const legend = require("../legend")

return {
	name = "The Warehouse",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.5,
	foreground = "interior",
	legend = {
		k = { prop = "lens", data = { dir = "up", sweep = 140, range = 8, group = "store", crimson = true } },
		h = { prop = "hatch", data = { group = "store", spawn = "drudge", count = 2 } },
		c = { prop = "chest", data = { items = { { "iron_draught", 2 }, { "voltaic_charge", 12 }, { "fig", 8 } } } },
		X = { prop = "city_crate" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "warehouse" },
	},
	map = {
		"##################",
		"#WWWWWWWWWWWWWWWW#",
		"#X.X.......XX..c.#",
		"#...X..X.........#",
		"#..X..h.....X.X..#",
		"#......X.........#",
		"#..X......k...h..#",
		"#.....X.....X....#",
		"#X..........X..X.#",
		"#######11#########",
	},
}
