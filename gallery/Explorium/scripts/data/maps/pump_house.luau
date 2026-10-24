--[[
The pump house of the Ward: a cog turning, pipes, the hatch down to the sewer and the Diggings of the Clay.
]]
const legend = require("../legend")

return {
	name = "The Pump House",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.5,
	foreground = "interior",
	legend = {
		o = { prop = "cog_fixed" },
		h = { prop = "sewer_hatch", entry = "2" },
		["|"] = { prop = "valve_pipe" },
		["+"] = { prop = "barrel" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "pump" },
		["2"] = { level = "diggings", entry = "1" },
	},
	map = {
		"############",
		"#WWWWWWWWWW#",
		"#|.oo..|...#",
		"#..oo......#",
		"#......h...#",
		"#X.........#",
		"#XX.......+#",
		"####11######",
	},
}
