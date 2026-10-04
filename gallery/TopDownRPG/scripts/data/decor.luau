--[[
Decorations: the second layer of a level map (`decor` in data/maps/, rows of the same size as `map`). They make places
feel alive and have no gameplay: nothing to pick up, nothing to use, no [E] prompt.

- `layer = "ground"`: drawn flat on the ground, under everything (flowers, tufts, pebbles, rubble...)
- `layer = "wall"`: drawn on the front of a wall (moss, roots, icicles; waterfalls are animated: `frames`)
- `prop`: a decoration that becomes a prop of the level: big ones block the way like rocks (a fallen trunk, a stump),
  glowing ones light the dark (glowing mushrooms). `partner` is the prop of the next cell to the right (the two
  halves of a fallen trunk).

"." is nothing. One sprite of `sprites` is picked for each cell, so that repeated decorations vary.
Decorations only show where they make sense when the level is built: things on the ground on walkable ground
(`water` ones on water instead: lilies), things on walls on walls. So when the canals of the desert fill with water,
or a bomb opens a cracked wall, what was on them goes away.
The decorations are drawn with the terrain (see terrain_view.luau): they cost nothing while playing.
]]
const loader = require("@vectarine/loader")

export type Decoration = {
	sprites: { string }?,
	frames: { string }?,
	layer: ("ground" | "wall")?,
	--- Lies on water (a water lily), instead of the ground
	water: boolean?,
	prop: string?,
	partner: string?,
	--- A decoration that joins its neighbors on the same row (pipes along a wall): the sprites of a lone one, of the
	--- left end, the middle and the right end of a run
	strip: { string }?,
}

const module = loader.init() or {}

local function ground(...: string): Decoration
	return { sprites = { ... }, layer = "ground" }
end

local function wall(...: string): Decoration
	return { sprites = { ... }, layer = "wall" }
end

module.characters = {
	-- On the ground
	r = ground("world/flowers_red"),
	y = ground("world/flowers_yellow"),
	w = ground("world/flowers_white"),
	t = ground("world/tuft_0", "world/tuft_1"),
	p = ground("world/pebbles_0", "world/pebbles_1"),
	l = ground("world/leaves"),
	c = ground("world/clover"),
	m = ground("world/mushrooms_small"),
	i = ground("world/twigs"),
	s = ground("world/ripples"),
	d = ground("world/desert_flower"),
	h = ground("world/shards"),
	j = ground("world/dry_twigs"),
	a = ground("world/cattails"),
	o = ground("world/moss"),
	u = { sprites = { "world/water_lily" }, layer = "ground", water = true },
	n = ground("world/snow_tuft"),
	e = ground("world/ice_shards"),
	f = ground("world/frost_flower"),
	b = ground("world/rubble"),
	k = ground("world/floor_crack"),
	g = ground("world/fern"),
	q = ground("world/tall_grass"),
	x = ground("world/mushrooms"),
	z = ground("world/reeds"),
	v = ground("world/dry_bush"),
	Y = ground("world/bones"),
	Z = ground("world/frozen_grass"),
	-- On the front of walls
	M = wall("world/moss_face"),
	R = wall("world/roots_face"),
	-- Pits worn into a wall (never a crack: cracked walls are the ones a bomb opens)
	C = wall("world/seep_face"),
	I = wall("world/icicles_face"),
	V = wall("world/ivy_face"),
	F = { frames = { "world/waterfall_0", "world/waterfall_1" }, layer = "wall" },
	-- Big decorations, solid
	L = { prop = "log_l", partner = "log_r" },
	G = { prop = "frozen_log_l", partner = "frozen_log_r" },
	H = { prop = "mossy_log_l", partner = "mossy_log_r" },
	S = { prop = "stump" },
	T = { prop = "dead_tree" },
	O = { prop = "snowy_rock" },
	-- Plants and rocks at the foot of the walls, solid
	U = { prop = "bush" },
	K = { prop = "rock" },
	Q = { prop = "boulder" },
	P = { prop = "cactus" },
	X = { prop = "snow_bush" },
	N = { prop = "willow" },
	E = { prop = "pine" },
	-- Things that glow: they light the dark caves (glowing mushrooms and moss are flat, crystals are solid)
	A = { prop = "glowcap" },
	B = { prop = "glowmoss" },
	W = { prop = "frost_crystal" },
	D = { prop = "sun_crystal" },
} :: { [string]: Decoration }

local function vista(name: string): Decoration
	return { sprites = { `world/vista_{name}` }, layer = "ground", water = true }
end

--- Decorations that mean something else in a style of level (data/legend.luau): the city reuses letters
module.styles = {
	--- The insides of the buildings of the city
	room = {
		r = ground("world/rug"),
		w = wall("world/window_face"),
		p = wall("world/painting_face"),
		L = wall("world/sconce_face"),
		S = wall("world/banner_face"),
		n = ground("world/papers"),
		b = ground("world/rubble"),
		k = ground("world/floor_crack"),
		c = ground("world/bolts"),
		["+"] = { prop = "barrel" },
		["&"] = { prop = "sacks" },
		["#"] = { prop = "crate_stack" },
		["%"] = { prop = "planter" },
		["<"] = { prop = "anvil" },
		[">"] = { prop = "workbench" },
	},
	city = {
		-- Pipes on the ground (symbols, so that the letters keep their meaning): straight ("-" across, "'" along), bends
		-- ("/" south-east, "\\" south-west, "`" north-east, "," north-west). They always run from water to somewhere water
		-- is used.
		["-"] = ground("world/pipe_h"),
		["'"] = ground("world/pipe_v"),
		["/"] = ground("world/pipe_se"),
		["\\"] = ground("world/pipe_sw"),
		["`"] = ground("world/pipe_ne"),
		[","] = ground("world/pipe_nw"),
		-- On the ground of the streets
		o = ground("world/oil_stain"),
		c = ground("world/bolts"),
		n = ground("world/papers"),
		u = ground("world/puddle"),
		w = ground("world/weeds"),
		-- On the walls
		P = { layer = "wall", strip = { "world/pipes_face_single", "world/pipes_face_left", "world/pipes_face", "world/pipes_face_right" } },
		-- A pipe running down the face of a wall (the great pipe of the Heights)
		J = wall("world/pipe_face_v"),
		G = wall("world/gauge_face"),
		S = wall("world/banner_face"),
		L = wall("world/sconce_face"),
		X = wall("world/grille_face"),
		-- Street furniture (solid, like rocks): placed by hand where it can't block a way, a beam or a crate
		["="] = { prop = "bench" },
		["+"] = { prop = "barrel" },
		["&"] = { prop = "sacks" },
		["#"] = { prop = "crate_stack" },
		["%"] = { prop = "planter" },
		["$"] = { prop = "cart" },
		["@"] = { prop = "notice_board" },
		["|"] = { prop = "valve_pipe" },
		["^"] = { prop = "chimney" },
		["~"] = { prop = "scrap_pile" },
		["<"] = { prop = "anvil" },
		[">"] = { prop = "workbench" },
		["{"] = { prop = "coil" },
		[":"] = { prop = "bush" },
		[";"] = { prop = "high_tide_statue" },
		-- The hanging gardens: flowers
		["!"] = ground("world/flowers_red"),
		["?"] = ground("world/flowers_yellow"),
		["*"] = ground("world/flowers_white"),
		-- The dry harbor: shells, dry kelp, nets and rope on the seabed and the quays
		e = ground("world/shells"),
		a = ground("world/dry_kelp"),
		y = ground("world/net"),
		r = ground("world/rope_coil"),
		-- The city far below, drawn over the void of the basin (from the balcony of the Seawall)
		["1"] = vista("mist"),
		["2"] = vista("roofs"),
		["3"] = vista("wall"),
		["4"] = vista("tower"),
		["5"] = vista("tower_top"),
		["6"] = vista("dome_l"),
		["7"] = vista("dome_r"),
		["8"] = vista("chimney"),
		["9"] = vista("spire"),
		["0"] = vista("spire_top"),
		["("] = vista("wheel_tl"),
		[")"] = vista("wheel_tr"),
		["["] = vista("wheel_bl"),
		["]"] = vista("wheel_br"),
	},
} :: { [string]: { [string]: Decoration } }

return module
