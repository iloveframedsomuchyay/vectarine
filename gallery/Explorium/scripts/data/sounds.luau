--[[
The music and the ambiences of the Explorium, and which ones play where. The sound effects themselves are listed in
data/sound_effects.luau (generated with their files by tools/sound/sfx.py).

Every floor has its music and its ambience; a level can choose others (`music` and `ambience` in its map, "none" for
silence). Tracks are loaded the first time they play: decoded sounds take a lot of memory (see audio.luau).
Files: audio/music/<name>.mp3 and audio/ambience/<name>.mp3, made by tools/sound/music.py and ambience.py. A track
that is not listed here yet is silence.
]]
const module = {}

export type Track = {
	--- How loud the track plays, before the volume of the settings (0 to 1)
	volume: number,
}

module.music = {
	oasis = { volume = 0.55 },
	desert = { volume = 0.55 },
	wetlands = { volume = 0.55 },
	frontier = { volume = 0.55 },
	city = { volume = 0.55 },
} :: { [string]: Track }

module.ambience = {
	--- Caves: a low hum of the rock, drops of water falling in pools
	cave = { volume = 0.5 },
	--- The desert: a dry wind in gusts, sand hissing, a far whistle in the ruins
	desert = { volume = 0.5 },
	--- The wetlands: insects, frogs answering each other, water lapping at the reeds
	marsh = { volume = 0.5 },
	--- The frontier: a cold wind with a thin edge, ice groaning far away, crystals tinkling
	frost = { volume = 0.5 },
	--- The city: the hum of the machines under the streets, steam from the vents, far clanks, the clocks of the Ward
	city = { volume = 0.5 },
} :: { [string]: Track }

--- The music and the ambience of each floor, by depth
module.floors = {
	[1] = { music = "oasis", ambience = "cave" },
	[2] = { music = "desert", ambience = "desert" },
	[3] = { music = "wetlands", ambience = "marsh" },
	[4] = { music = "frontier", ambience = "frost" },
	[5] = { music = "city", ambience = "city" },
} :: { [number]: { music: string?, ambience: string? } }

--- The sound of the footsteps on each ground (terrain names); the others sound like dirt
module.footsteps = {
	grass = "grass",
	sand = "sand",
	dune = "sand",
	canal_bed = "sand",
	seabed = "sand",
	mud = "mud",
	bog = "mud",
	miasma = "mud",
	snow = "snow",
	frost = "snow",
	rime_floor = "snow",
	ice = "ice",
	thin_ice = "ice",
	planks = "wood",
	boards = "wood",
	hut_door = "wood",
	ruin_floor = "stone",
	ruin_door = "stone",
	clinic_floor = "stone",
	paving = "stone",
	marble_floor = "stone",
	cobbles = "stone",
	sidewalk = "stone",
	plaza = "stone",
	stone_bridge = "stone",
	hall_floor = "stone",
	carpet = "carpet",
	bronze_floor = "metal",
	copper_plate = "metal",
	grate = "metal",
	conveyor = "metal",
} :: { [string]: string }

return module
