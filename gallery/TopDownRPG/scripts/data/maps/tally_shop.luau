--[[
Tally's shop, on the market square: a counter, shelves of wares, crates. Tally only trades with citizens.
]]
const legend = require("../legend")

return {
	name = "Tally's Shop",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.25,
	foreground = "interior",
	legend = {
		t = { npc = "tally" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "tally" },
	},
	map = {
		"##############",
		"#WWWWWWWWWWWW#",
		"#LL..LL..LLX.#",
		"#.....t......#",
		"#KKKKK.KKKKK.#",
		"#............#",
		"#X..........X#",
		"######11######",
	},
	decor = {
		"..............",
		"...w....p.....",
		"..............",
		"..............",
		"..............",
		"......r.......",
		".+..........&.",
		"..............",
	},
}
