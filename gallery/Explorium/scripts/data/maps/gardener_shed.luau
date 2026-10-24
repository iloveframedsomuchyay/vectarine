--[[
The Gardener's shed, under the fig trees: sacks of soil, shears, baskets of figs. Carved low on the wall, at the
height of a child: Nerissa's name, from the days she hid here from her mother.
]]
const legend = require("../legend")

return {
	name = "The Gardener's Shed",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.35,
	foreground = "interior",
	legend = {
		c = { prop = "chest", data = { items = { { "fig", 12 }, { "salt_hardtack", 2 }, { "energy_core", 1 } } } },
		n = { prop = "sign", data = { lore = "nerissa_carving" } },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "hanging_gardens", entry = "shed" },
	},
	map = {
		"############",
		"#WWWWWWWWWW#",
		"#.......c..#",
		"#..T.......#",
		"#........n.#",
		"#..........#",
		"####11######",
	},
	decor = {
		"............",
		"............",
		".&&......+..",
		".......>....",
		".&..........",
		"............",
		"............",
	},
}
