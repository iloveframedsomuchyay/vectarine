--[[
The Glowworm Grotto: behind a curtain of roots on the east wall of the Fern Hollow, a hidden grotto where threads of
glowworms hang from the rock. Wren knows it (it is on his map, see npcs.luau) but his knee can't take the crawl.

The crawl opens on the pool of the glowworms. A tunnel goes north to a nook where someone hid a chest; a passage
goes east to a crossing, then a dead end with a second pool in the south-east. North of the crossing, the shrine of
the sea people: the altar where the eternal lantern burns, and a tablet. Taking the lantern lights the way through
the Dark Hollow.
]]
const legend = require("../legend")

return {
	name = "The Glowworm Grotto",
	subtitle = "The Oasis",
	darkness = 0.88,
	ambient = { motes = 9 },
	legend = {
		a = { prop = "lantern_altar" },
		j = { prop = "glowworms" },
		t = { prop = "tablet", data = { lore = "first_flame" } },
		c = { prop = "chest", data = { items = { { "fig", 4 }, { "bandage", 1 }, { "ancient_fragment", 1 } } } },
		r = { monster = "rat" },
		b = { monster = "bat_brown" },
	} :: { [string]: legend.LegendEntry },
	links = {
		["3"] = { level = "fern_hollow", entry = "3" },
	},
	map = {
		"####################RRRRRRRRRRRRRRRRRR##",
		"####################RBBBBBBBBBBBBBBBBR##",
		"#################WWWRU:::t::::::::::UR##",
		"#########WWWWWWWW.j.R:::I::a::I::::::R##",
		"#########......j...cR::::::::::::::::R##",
		"#########.....r.....R:::J:::::I::::::R##",
		"#########j.######+.^RU:::::::::::::S:R##",
		"#########..#########RRRRRR::RRRRRRRRRR##",
		"#########..#########BBBBBB::BBBBBBBBBB##",
		"########W..WWWWW##########..############",
		"#######Wj...j..jW#########j.############",
		"#######.......b..W########..############",
		"######W...~~~~.%j.#####WWW..W###########",
		"NNNNNN.j.~~~~~~...####W.j....W##########",
		"3.j..j...~~~~~~...####.^....j.##WWWWW###",
		"3.......%.~~~~~...WWWW........##.j..rW##",
		"######.^...~~~...........O.r..##^...j.##",
		"#######...^.....O.............WW..~~..##",
		"#######.j.....j..#####.j....%....~~~~.##",
		"########........#######...........~~~.##",
		"################################..j.U###",
		"#################################K...###",
		"########################################",
		"########################################",
	},
	decor = {
		"........................................",
		".....................MC......M..M.......",
		"...................R..k......b.b........",
		".........M..M.RC.....k...kb.k.....kbb...",
		".............t..............b....b......",
		"...........tt......m...b............k...",
		"......................k......kk.........",
		"........................................",
		"........................C.b....MMMC..C..",
		"..............M.........................",
		"........................................",
		"...............t........................",
		".........o..................M...........",
		".........................moto...........",
		".x..x..m...................m....CM......",
		"..p................M....o....t.......R..",
		"..............x.ot........p.......m.....",
		"........o...tot.......p..o.....M....o...",
		"........................m....t..........",
		"...............m.......tt....p..t.......",
		"................................p.......",
		"........................................",
		"........................................",
		"........................................",
	},
}
