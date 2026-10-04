--[[
Behind the bricked door of the Registry: the register of the Ebb, the struck names. Shelves of tablets, each name
crossed out. Coral's is there too. An energy core, left on the clerk's desk.
]]
const legend = require("../legend")

return {
	name = "The Register of the Ebb",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.6,
	foreground = "halls",
	legend = {
		t = { prop = "tablet", data = { lore = "struck_register" } },
		c = { prop = "chest", data = { items = { { "energy_core", 1 }, { "iron_draught", 1 } } } },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "hall_of_waters", entry = "2" },
	},
	map = {
		"############",
		"#WWWWWWWWWW#",
		"#LL.LL.LL.L#",
		"#..........#",
		"#...t..D.c.#",
		"#..........#",
		"#####11#####",
	},
}
