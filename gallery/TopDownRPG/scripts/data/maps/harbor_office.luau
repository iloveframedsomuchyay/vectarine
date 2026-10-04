--[[
The office of the harbor master: the waystation of the Salt. A hearth to rest by, a teleporter, the quantum chest, and
the log of the last day of the harbor.
]]
const legend = require("../legend")

return {
	name = "The Harbor Office",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.35,
	foreground = "interior",
	legend = {
		f = { prop = "hearth" },
		P = { prop = "teleporter" },
		n = { prop = "note", data = { lore = "harbor_log" } },
		["+"] = { prop = "barrel" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "dry_harbor", entry = "office" },
	},
	map = {
		"##############",
		"#WWWWWWWWWWWW#",
		"#LL..f....D..#",
		"#..........n.#",
		"#.P.......Q..#",
		"#............#",
		"#X.........+.#",
		"######11######",
	},
	decor = {
		"..............",
		"..w.......w...",
		"..............",
		"..............",
		"..............",
		"......r.......",
		"..............",
		"..............",
	},
}
