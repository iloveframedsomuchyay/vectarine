--[[
The guild hall of the Salt, the sailors who left. Their banners, their benches, and the vault behind its door of
bronze: it opens to the light of the lighthouse (the crystal by the door, outside). Inside: the grapnel of the Salt.
]]
const legend = require("../legend")

return {
	name = "The Guild of the Salt",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.4,
	foreground = "halls",
	legend = {
		v = { prop = "vault_door", data = { id = "salt_vault" } },
		s = { prop = "chest", data = { items = { { "salt_grapnel", 1 }, { "salt_hardtack", 2 }, { "smoke_vial", 1 } } } },
		t = { prop = "tablet", data = { lore = "salt_vault" } },
		I = { ground = "hall_floor", prop = "column" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "dry_harbor", entry = "guild" },
	},
	map = {
		"################",
		"#####WWWWWW#####",
		"#####..s...#####",
		"#####.t....#####",
		"#WWWWWWvWWWWWWW#",
		"#``````````````#",
		"#`I``T``h``T`I`#",
		"#``````````````#",
		"#`I```````h``I`#",
		"#``````````````#",
		"########11######",
	},
	decor = {
		"................",
		"................",
		"................",
		"................",
		"..p.....w....p..",
		"................",
		"................",
		"........r.......",
		"................",
		"................",
		"................",
	},
}
