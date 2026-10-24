--[[
Inside the lighthouse of the Salt: ladders up three floors, past the dart slits and the bats that nest in the tower,
to the great lantern. It can only be lit with a real flame: the ember of the Watch.
]]
const legend = require("../legend")

return {
	name = "The Lighthouse",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.6,
	foreground = "interior",
	heights = {
		"222222222222",
		"222222222222",
		"222222222222",
		"222222222222",
		"111111111111",
		"111111111111",
		"111111111111",
		"111111111111",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
	},
	legend = {
		k = { prop = "great_lantern", data = { id = "great_lantern" } },
		u = { prop = "tablet", data = { lore = "lighthouse" } },
		b = { monster = "brass_bat" },
		[">"] = { monster = "dart_left" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "dry_harbor", entry = "lighthouse" },
	},
	map = {
		"############",
		"#WWWWWWWWWW#",
		"#..k....u..#",
		"#..........#",
		"#WWWWWWWHWW#",
		"#.........##",
		"#.b.......>#",
		"#..........#",
		"#WHWWWWWWWW#",
		"#.........##",
		"#.........>#",
		"#....b.....#",
		"#..........#",
		"#####11#####",
	},
}
