--[[
The Registry of the Ward (once the Hall of Waters): Unit-1 writes the citizens of the Tide. Four doors for the four
waters; the fifth, bricked, is the door of the Ebb: the register of the struck names. It opens for one of the Ebb
(Coral, see npcs.luau).
]]
const legend = require("../legend")

return {
	name = "The Registry",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.3,
	foreground = "halls",
	legend = {
		u = { npc = "unit1" },
		R = { prop = "registry_desk" },
		a = { prop = "water_door", data = { water = "high_tide" } },
		b = { prop = "water_door", data = { water = "bronze" } },
		c = { prop = "water_door", data = { water = "salt" } },
		d = { prop = "water_door", data = { water = "clay" } },
		e = { prop = "ebb_door", data = { id = "ebb_register" } },
		I = { ground = "hall_floor", prop = "column" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "registry" },
		["2"] = { level = "ebb_register", entry = "1" },
	},
	map = {
		"####################",
		"#WWWWWWW2WWWWWWWWWW#",
		"#`a``b``e``c``d````#",
		"#``````````````````#",
		"#`I`````RuR`````I``#",
		"#``````````````````#",
		"#``````````````````#",
		"#`I``````````````I`#",
		"#``````````````````#",
		"#########11#########",
	},
}
