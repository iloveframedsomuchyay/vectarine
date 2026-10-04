--[[
Wren's camp: the only safe place of the oasis. A fire to rest by, Wren to talk to, a quantum chest to store items,
and a teleporter waiting for an energy core. Three ways out: the sinkhole (west), the Fern Hollow (south)
and the Dark Hollow (east).
]]
const legend = require("../legend")

return {
	name = "Wren's Camp",
	subtitle = "The Oasis",
	darkness = 0.55,
	ambient = { fireflies = 2.5, butterflies = 1.5, glints = true },
	legend = {
		w = { npc = "wren", data = { hideIf = "wrenComing" } },
		n = { prop = "sign", data = { lore = "camp_sign" } },
	} :: { [string]: legend.LegendEntry },
	links = {
		["1"] = { level = "sinkhole", entry = "1" },
		["2"] = { level = "fern_hollow", entry = "2" },
		["3"] = { level = "dark_hollow", entry = "3" },
	},
	map = {
		"################################",
		"################################",
		"##############WWWWWW############",
		"#########WWWWWWWWWWWWWW#########",
		"#######WWWWWWW......WWWWW#######",
		"######WWW...........!,.WWWW#####",
		"#####WW!.....X.....,,,,,,WWW####",
		"WWWWWW....XY..Q...,,,,%,,..WWWWW",
		"WWWWW0...X.....E..,,,,,,,&.OWWWW",
		"1........^..........,..........3",
		"1.....n.........F..............3",
		"1.............w...E.....%......3",
		"####!...,,,,,,.............!####",
		"#####..,&,,,:::....%..~~~M..####",
		"#####..,,,,,:P:.....M~~~~~~M####",
		"#######.,%,,:::......~~L~~######",
		"#########...........OM~~~~######",
		"############........############",
		"###############...##############",
		"###############222##############",
	},
	decor = {
		"................................",
		"................................",
		"..............R.R.VM............",
		".........MV.R.......R...........",
		".......VM.....t.U......R........",
		"..........ptp......t..c.VCC.....",
		".....RR..l.........c..t....M....",
		".R....xl.......kt......c.t.R.R.R",
		"R......t.....t...p.A..r...p...CV",
		"...t..........lk................",
		".t..l..t.............llti....t..",
		"....llg.g..i.i.t.....g...t......",
		".........c..t.l....gl..ptl......",
		"......lt.w.y...t.....itaz.oc....",
		".....l.wry..k.bm.g..t...........",
		"..........rt....l...............",
		".........g.t.iltic..............",
		"............ptt.t...............",
		"................................",
		"................................",
	},




}
