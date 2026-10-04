--[[
The water tower of the Ward: where the drain of the Seagate comes out (the player arrives through the grate). Pipes,
the tank above. A smuggler hid smoke vials here, with a note: the lenses can't see through smoke.
]]
const legend = require("../legend")

return {
	name = "The Water Tower",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.4,
	foreground = "interior",
	legend = {
		g = { prop = "sewer_hatch", entry = "2" },
		c = { prop = "chest", data = { items = { { "smoke_vial", 2 }, { "salt_hardtack", 2 } } } },
		n = { prop = "note", data = { lore = "dex_note" } },
		["|"] = { prop = "valve_pipe" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "tower" },
		["2"] = { level = "seawall", entry = "2" },
	},
	map = {
		"##############",
		"#WWWWWWWWWWWW#",
		"#............#",
		"#..|......|..#",
		"#.....g......#",
		"#............#",
		"#.X.......Xc.#",
		"#........XXn.#",
		"#............#",
		"######11######",
	},
	decor = {
		"..............",
		"..w.......w...",
		"..............",
		"..............",
		"..............",
		"....n.........",
		"..............",
		"..............",
		"..............",
		"..............",
	},
}
