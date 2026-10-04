--[[
A house of the Ward, warm still: a stove, a bed, a table set for two. A cat of bronze sleeps on the rug (it purrs, a
little, when petted).
]]
const legend = require("../legend")

return {
	name = "A House of the Ward",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.3,
	foreground = "interior",
	legend = {
		c = { prop = "bronze_cat" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "home" },
	},
	map = {
		"############",
		"#WWWWWWWWWW#",
		"#UL......E.#",
		"#.........E#",
		"#...ThT....#",
		"#....c....S#",
		"#..........#",
		"####11######",
	},
	decor = {
		"............",
		"..w..p...w..",
		"............",
		"............",
		"............",
		"....rr......",
		"............",
		"............",
	},
}
