--[[
Inside the clock tower: the works of the clock, stopped. Its dial can be turned hour by hour. The clock stopped when
the collectors came, at the eighth bell (Coral's mother's letter, in the Ebb house): set it to the eighth hour, and
the clockmaker's hiding place opens.
]]
const legend = require("../legend")

return {
	name = "The Clock Tower",
	subtitle = "The City of the Tide",
	depth = 5,
	style = "room",
	floor = "boards",
	darkness = 0.45,
	foreground = "interior",
	legend = {
		d = { prop = "clock_dial", data = { id = "ward_clock", hour = 8 } },
		o = { prop = "cog_fixed" },
		n = { prop = "note", data = { lore = "clockmaker_note" } },
		c = { prop = "chest", data = { items = { { "energy_core", 1 }, { "salt_fury", 2 } }, showIf = "open:ward_clock" } },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "bronze_ward", entry = "clock" },
	},
	map = {
		"############",
		"#WWWWWWWWWW#",
		"#.oo....oo.#",
		"#.oo.d..oo.#",
		"#..........#",
		"#.n......c.#",
		"#..........#",
		"####11######",
	},
	decor = {
		"............",
		"..........w.",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
	},
}
