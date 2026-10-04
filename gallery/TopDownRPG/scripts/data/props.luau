--[[
Props: things placed on the cells of a level. Plants, rocks, ruins, the camp, chests, characters...

Fields:
- `sprite`: from the "world" sheet. `frames` instead of `sprite` for animated props (frames per second: `fps`).
- `solid`: blocks characters. `flat`: drawn on the ground, below characters (a fern, a lily pad).
- `tall`: a sprite drawn on the cell above (the top of a column). `wide`: a sprite drawn on the cell to the right.
- `light`: radius of the light it gives, in tiles (see lighting in world_view.luau).
- `interact`: what [E] does near it (see interactions.luau), and `label` the word shown in the key prompts.
- `breakable`: hitting it breaks it (and it may drop something, see `drops`).
- `fruit`: it can be picked (`item`, `count`), and grows back after `regrow` seconds. `empty` is its sprite meanwhile.
- `openKind`: what it becomes once opened (a gate, a valve...). It opens when the flag "open:<id>" is set, where
  <id> is its `data.id`, or the `data.opens` of a sun eye (see switches.luau).
- `target`: an arrow that hits it opens what it guards (`data.opens`).
- `floor`: it carries the player over water (a lily pad). `sinks`: it sinks a moment after someone steps on it, and
  comes back up later (see swamp.luau).
- A prop with `data.showIf` only appears once that flag is set (the ferry, called by the bell).
- The frontier: `litKind` is what a brazier becomes once lit (the flag "lit:<key>" remembers it). `pushable` props
  (ice blocks) slide when the player walks into them (see blocks.luau). `plate`: a rune plate, pressed by an ice block
  resting on it. `dream`: only there for dreamers (dream bridges, dream writing, see dream.luau). `warmth`: radius of
  the heat it gives (fires, braziers, see frost.luau). `hides`: drawn above the player (a snowdrift hiding a passage).
]]
const loader = require("@vectarine/loader")

export type PropKind = {
	sprite: string?,
	frames: { string }?,
	fps: number?,
	solid: boolean,
	flat: boolean?,
	tall: string?,
	wide: string?,
	light: number?,
	interact: string?,
	label: string?,
	breakable: boolean?,
	drops: { { item: string, chance: number, count: number? } }?,
	fruit: { item: string, count: number, regrow: number, empty: string }?,
	openKind: string?,
	target: boolean?,
	floor: boolean?,
	sinks: boolean?,
	litKind: string?,
	pushable: boolean?,
	plate: boolean?,
	dream: boolean?,
	warmth: number?,
	hides: boolean?,
	--- The city: crates (`step`, pushed one cell at a time), mirrors that turn beams (see beams.luau)
	step: boolean?,
	mirror: boolean?,
	--- A prism: the beam goes through it, and a part of it turns like on a mirror (see beams.luau)
	split: boolean?,
	--- What [E] "look" says when the level gives no `data.text`
	text: string?,
}

const module = loader.init() or {}

module.kinds = {
	-- Plants
	bush = { sprite = "world/bush", solid = true },
	fruit_bush = {
		sprite = "world/fruit_bush",
		solid = true,
		interact = "fruit",
		label = "Pick",
		fruit = { item = "fig", count = 2, regrow = 90, empty = "world/bush" },
	},
	fern = { sprite = "world/fern", solid = false, flat = true },
	tall_grass = { sprite = "world/tall_grass", solid = false, flat = true },
	glowcap = { sprite = "world/glowcap", solid = false, flat = true, light = 2.5 },
	-- Threads of glowworms hanging from the rock above (the Glowworm Grotto)
	glowworms = { frames = { "world/glowworms_0", "world/glowworms_1" }, fps = 1.5, solid = false, flat = true, light = 2.2 },
	mushrooms = { sprite = "world/mushrooms", solid = false, flat = true },
	lily_pad = { sprite = "world/lily_pad", solid = false, flat = true },
	reeds = { sprite = "world/reeds", solid = false, flat = true },
	-- Rocks and remains
	rock = { sprite = "world/rock", solid = true },
	boulder = { sprite = "world/boulder", solid = true },
	bones = { sprite = "world/bones", solid = false, flat = true },
	skull = { sprite = "world/skull", solid = false, flat = true },
	-- Ruins of the sea people
	column = { sprite = "world/column_base", tall = "world/column_top", solid = true },
	column_broken = { sprite = "world/column_broken", solid = true },
	statue_head = { sprite = "world/statue_head", solid = true },
	tablet = { sprite = "world/tablet", solid = true, interact = "read", label = "Read" },
	-- The altar of the eternal lantern (the Glowworm Grotto): empty once the player took it
	lantern_altar = {
		frames = { "world/lantern_altar_0", "world/lantern_altar_1" },
		fps = 3,
		solid = true,
		light = 4,
		interact = "lantern",
		label = "Take",
	},
	pot = {
		sprite = "world/pot",
		solid = true,
		breakable = true,
		drops = {
			{ item = "fig", chance = 0.3 },
			{ item = "arrows", chance = 0.2, count = 3 },
			{ item = "ancient_fragment", chance = 0.1 },
		},
	},
	-- The explorers' camp
	campfire = {
		frames = { "world/campfire_0", "world/campfire_1" },
		fps = 6,
		solid = true,
		light = 4.5,
		warmth = 4,
		interact = "campfire",
		label = "Rest",
	},
	tent = { sprite = "world/tent_l", wide = "world/tent_r", solid = true },
	bedroll = { sprite = "world/bedroll", solid = false, flat = true },
	crate = { sprite = "world/crate", solid = true, breakable = true, drops = { { item = "fig", chance = 0.5 } } },
	sign = { sprite = "world/sign", solid = true, interact = "read", label = "Read" },
	note = { sprite = "world/note", solid = false, flat = true, interact = "read", label = "Read" },
	-- Containers and machines
	chest = { sprite = "world/chest", solid = true, interact = "chest", label = "Open" },
	quantum_chest = { sprite = "world/quantum_chest", solid = true, light = 1.5, interact = "quantum", label = "Open" },
	teleporter = { sprite = "world/teleporter_off", solid = false, flat = true, interact = "teleporter", label = "Use" },
	stairs = { sprite = "world/stairs_down", solid = false, flat = true, interact = "stairs", label = "Go down" },
	-- The desert
	cactus = { sprite = "world/cactus", solid = true },
	cactus_fruit = {
		sprite = "world/cactus_fruit",
		solid = true,
		interact = "fruit",
		label = "Pick",
		fruit = { item = "prickly_pear", count = 1, regrow = 120, empty = "world/cactus" },
	},
	dry_bush = { sprite = "world/dry_bush", solid = false, flat = true },
	palm = { sprite = "world/palm", tall = "world/palm_top", solid = true },
	palm_dead = { sprite = "world/palm_dead", tall = "world/palm_dead_top", solid = true },
	sun_crystal = { sprite = "world/sun_crystal", solid = true, light = 3.2 },
	cistern = { sprite = "world/cistern", solid = true, interact = "cistern", label = "Look" },
	valve = { sprite = "world/valve", solid = true, interact = "valve", label = "Turn", openKind = "valve_open" },
	valve_open = { sprite = "world/valve_open", solid = true },
	sun_eye = { sprite = "world/sun_eye", solid = true, target = true, openKind = "sun_eye_open" },
	sun_eye_open = { sprite = "world/sun_eye_open", solid = true },
	gate = { sprite = "world/gate", solid = true, interact = "gate", label = "Look", openKind = "gate_open" },
	gate_open = { sprite = "world/gate_open", solid = false, flat = true },
	council_door = { sprite = "world/council_door", solid = true, interact = "council", label = "Open", openKind = "council_door_open" },
	council_door_open = { sprite = "world/council_door_open", solid = false, flat = true },
	stairs_up = { sprite = "world/stairs_up", solid = false, flat = true, interact = "stairs", label = "Go up" },
	-- The wetlands
	lily_big = { sprite = "world/lily_big", solid = false, flat = true, floor = true },
	lily_sink = { sprite = "world/lily_sink", solid = false, flat = true, floor = true, sinks = true },
	lily_sunk = { sprite = "world/lily_sunk", solid = false, flat = true },
	willow = { sprite = "world/willow", tall = "world/willow_top", solid = true },
	glowmoss = { sprite = "world/glowmoss", solid = false, flat = true, light = 2.6 },
	bell = { sprite = "world/bell", solid = true, interact = "bell", label = "Ring" },
	skiff = { sprite = "world/skiff", solid = false, flat = true, interact = "skiff", label = "Board" },
	cauldron = { frames = { "world/cauldron_0", "world/cauldron_1" }, fps = 3, solid = true, light = 2 },
	shelf = { sprite = "world/shelf", solid = true },
	bed = { sprite = "world/bed", solid = true },
	surgery_table = { sprite = "world/surgery_table", solid = true },
	cabinet = { sprite = "world/cabinet", solid = true },
	shrine = { sprite = "world/shrine", solid = true, interact = "shrine", label = "Look", openKind = "shrine_lit" },
	shrine_lit = { sprite = "world/shrine_lit", solid = true, light = 2 },
	sick_door = { sprite = "world/sick_door", solid = true, interact = "sick_door", label = "Open", openKind = "sick_door_open" },
	sick_door_open = { sprite = "world/sick_door_open", solid = false, flat = true },
	office_door = { sprite = "world/office_door", solid = true, interact = "office_door", label = "Open", openKind = "office_door_open" },
	office_door_open = { sprite = "world/office_door_open", solid = false, flat = true },
	--- A way down to a place below (the isle of the Frog King): it shows where an exit is, it does nothing itself
	passage = { sprite = "world/stairs_down", solid = false, flat = true },
	-- The frontier
	pine = { sprite = "world/pine", tall = "world/pine_top", solid = true },
	snow_bush = { sprite = "world/snow_bush", solid = true },
	frozen_grass = { sprite = "world/frozen_grass", solid = false, flat = true },
	frost_crystal = { sprite = "world/frost_crystal", solid = true, light = 3 },
	brazier = { sprite = "world/brazier", solid = true, interact = "brazier", label = "Light", litKind = "brazier_lit" },
	brazier_lit = { frames = { "world/brazier_lit_0", "world/brazier_lit_1" }, fps = 6, solid = true, light = 4, warmth = 3.5 },
	--- A hearth inside a house: a campfire against a wall
	hearth = {
		frames = { "world/hearth_0", "world/hearth_1" },
		fps = 5,
		solid = true,
		light = 4.5,
		warmth = 5,
		interact = "campfire",
		label = "Rest",
	},
	ice_block = { sprite = "world/ice_block", solid = true, pushable = true },
	--- A chest frozen in a block of ice: it slides like a block, and thaws next to a lit brazier
	frozen_chest = { sprite = "world/frozen_chest", solid = true, pushable = true },
	rune_plate = { sprite = "world/rune_plate", solid = false, flat = true, plate = true },
	watch_gate = { sprite = "world/watch_gate", solid = true, interact = "look", label = "Look", openKind = "watch_gate_open" },
	watch_gate_open = { sprite = "world/watch_gate_open", solid = false, flat = true },
	--- The Cold Lock, the gate to the city: it only melts before the ember of the Watch
	cold_lock = { sprite = "world/cold_lock", solid = true, interact = "cold_lock", label = "Look", openKind = "cold_lock_open" },
	cold_lock_open = { sprite = "world/watch_gate_open", solid = false, flat = true },
	dream_mirror = { sprite = "world/dream_mirror", solid = true, interact = "mirror", label = "Gaze" },
	dream_bridge = { sprite = "world/dream_bridge", solid = false, flat = true, floor = true, dream = true },
	dream_rune = { sprite = "world/dream_rune", solid = false, flat = true, dream = true, interact = "read", label = "Read" },
	frozen_soldier = { sprite = "world/frozen_soldier", tall = "world/frozen_soldier_top", solid = true },
	steam = { frames = { "world/steam_0", "world/steam_1" }, fps = 3, solid = false, flat = true },
	footprints = { sprite = "world/footprints", solid = false, flat = true },
	snowdrift = { sprite = "world/snowdrift", solid = false, hides = true },
	snowman = { sprite = "world/snowman", solid = true },
	weapon_rack = { sprite = "world/weapon_rack", solid = true },
	-- Big decorations (see data/decor.luau): they block the way like rocks
	log_l = { sprite = "world/log_l", solid = true },
	log_r = { sprite = "world/log_r", solid = true },
	frozen_log_l = { sprite = "world/frozen_log_l", solid = true },
	frozen_log_r = { sprite = "world/frozen_log_r", solid = true },
	mossy_log_l = { sprite = "world/mossy_log_l", solid = true },
	mossy_log_r = { sprite = "world/mossy_log_r", solid = true },
	stump = { sprite = "world/stump", solid = true },
	dead_tree = { sprite = "world/dead_tree", solid = true },
	snowy_rock = { sprite = "world/snowy_rock", solid = true },
	--- Where the snowball gallery puts its targets (see gallery.luau): invisible
	gallery_spot = { solid = false, flat = true },
	-- The city of the Tide: machines (see power.luau, beams.luau, cogs.luau, lenses.luau, ducts.luau, grapnel.luau)
	city_crate = { sprite = "world/city_crate", solid = true, pushable = true, step = true },
	mirror_crate = { sprite = "world/mirror_crate_slash", solid = true, pushable = true, step = true, mirror = true, interact = "turn_mirror", label = "Turn" },
	mirror = { sprite = "world/mirror_slash", solid = true, mirror = true, interact = "turn_mirror", label = "Turn" },
	splitter = { sprite = "world/splitter_slash", solid = true, split = true, interact = "turn_mirror", label = "Turn" },
	emitter = { sprite = "world/emitter_right", solid = true, light = 1.5 },
	crystal = { sprite = "world/crystal", solid = true },
	lens = { sprite = "world/lens_pole", tall = "world/lens_calm", solid = true },
	shutter = { sprite = "world/shutter", solid = true },
	shutter_open = { sprite = "world/shutter_open", solid = false, flat = true },
	hatch = { sprite = "world/hatch", solid = false, flat = true },
	breaker = { sprite = "world/breaker_on", solid = true, interact = "breaker", label = "Throw" },
	cog_drive = { sprite = "world/cog_drive_0", tall = "world/cog_motor", solid = true },
	cog_peg = { sprite = "world/cog_peg", solid = true, interact = "peg", label = "Cog" },
	cog_fixed = { sprite = "world/cog_peg", solid = true },
	cog_output = { sprite = "world/cog_output_cw", tall = "world/cog_dial_cw", solid = true },
	vent = { sprite = "world/vent", solid = false, flat = true, interact = "vent", label = "Crawl in" },
	mooring_ring = {
		sprite = "world/mooring_ring",
		solid = true,
		interact = "look",
		label = "Look",
		text = "A bronze mooring ring of the Salt, on a post at the edge of the void. A rope thrown from across could catch it.",
	},
	pressure_plate = { sprite = "world/pressure_plate", solid = false, flat = true, plate = true },
	--- The Seagate, the gate of the outer wall of the city: it opens with the winch next to it (cogs)
	seagate = { sprite = "world/seagate", solid = true, interact = "look", label = "Look", openKind = "seagate_open",
		text = "The Seagate of the city, a portcullis of bronze. Its winch is next to it, on the wall: a train of cogs with a gap." },
	seagate_open = { sprite = "world/seagate_open", solid = false, flat = true },
	--- A balustrade of bronze, along a balcony
	railing = { sprite = "world/railing", solid = true },
	--- A lever: pulled once, it opens what it is tied to for good (`data.id`, see switches.luau)
	lever = { sprite = "world/lever", solid = true, interact = "lever", label = "Pull", openKind = "lever_pulled" },
	lever_pulled = { sprite = "world/lever_pulled", solid = true },
	--- The great lantern of the lighthouse of the Salt: lit with [E] (Beacon's quest)
	great_lantern = { sprite = "world/great_lantern", solid = true, interact = "great_lantern", label = "Light", openKind = "great_lantern_lit" },
	great_lantern_lit = { frames = { "world/great_lantern_lit_0", "world/great_lantern_lit_1" }, fps = 4, solid = true, light = 9 },
	--- The gardens of the High Tide: the gate of the palace (three crystals open it), statues, the fountain (dry until the
	--- tide comes back)
	palace_gate = { sprite = "world/palace_gate", solid = true, interact = "look", label = "Look", openKind = "palace_gate_open",
		text = "The gate of the palace of the High Tide, white and gold. Three crystals are set in the paving before it, dark." },
	palace_gate_open = { sprite = "world/palace_gate_open", solid = false, flat = true },
	high_tide_statue = { sprite = "world/statue_base", tall = "world/statue_top", solid = true },
	fountain = { sprite = "world/fountain_dry", solid = true, openKind = "fountain_running" },
	--- A fountain running again (the gardens, once the great pump of the Foundry runs: `data.id`)
	fountain_running = { frames = { "world/fountain_0", "world/fountain_1" }, fps = 4, solid = true },
	--- The palace: the throne of the Tide, the door of the Great Archive and its dials of words
	throne = { sprite = "world/throne", tall = "world/throne_top", solid = true, interact = "throne", label = "Look" },
	word_dial = { sprite = "world/word_dial", solid = true, interact = "dial", label = "Turn" },
	archive_door = { sprite = "world/archive_door", solid = true, interact = "look", label = "Look", openKind = "archive_door_open",
		text = "The door of the Great Archive. Three dials of words are set in the wall next to it." },
	archive_door_open = { sprite = "world/archive_door_open", solid = false, flat = true },
	-- The great pump of the Foundry (see interactions.luau)
	pump_valve = { sprite = "world/valve", solid = true, interact = "great_pump", label = "Turn", openKind = "valve_open" },
	-- The furniture of the houses of the city
	bronze_cat = { sprite = "world/bronze_cat", solid = true, interact = "look", label = "Pet",
		text = "A cat of bronze, curled up on the rug. When you stroke its back, something inside it purrs, a little." },
	rubble_pile = { sprite = "world/rubble_pile", solid = true },
	clock_dial = { sprite = "world/word_dial", solid = true, interact = "clock", label = "Turn" },
	table = { sprite = "world/table", solid = true },
	chair = { sprite = "world/chair", solid = false, flat = true },
	stove = { frames = { "world/stove_0", "world/stove_1" }, fps = 3, solid = true, light = 2.5 },
	stove_cold = { sprite = "world/stove_0", solid = true, interact = "look", label = "Look",
		text = "The stove is cold. Ash, old ash, and a little bronze spoon in it." },
	cupboard = { sprite = "world/cupboard", solid = true },
	counter = { sprite = "world/counter", solid = true },
	desk = { sprite = "world/desk", solid = true },
	toy_chest = { sprite = "world/toy_chest", solid = true },
	crib = { sprite = "world/crib", solid = true },
	-- Coral's boat, floating in the basin of the canal of the Ward: her token is in it (see the Ebb house)
	coral_boat = { sprite = "world/coral_boat", solid = false, flat = true },
	toy_boat = { sprite = "world/toy_boat", solid = false, flat = true, interact = "look", label = "Look",
		text = "A little boat of painted wood, with a sail of cloth. A name is scratched on its hull: NERISSA." },
	--- The Engine: the great wheel (a machine of 5 by 5 cells, each one a part of it), the rod of a shaft over a pit
	great_wheel = { sprite = "world/wheel_0_0_0", solid = true },
	shaft_rod = { sprite = "world/shaft_rod", solid = false, flat = true },
	--- The heart: the throne of the Tidemother in the Engine, where its cables plug into her
	engine_throne_l = { sprite = "world/engine_throne_l", solid = true },
	engine_throne_r = { sprite = "world/engine_throne_r", solid = true },
	--- The surface: the edge of the hill, over the sea (the ending of the Tide Road)
	overlook = { sprite = "world/overlook", solid = false, flat = true, interact = "overlook", label = "Look at the sea" },
	-- The city: street furniture, only decoration (big decorations of data/decor.luau: solid, like rocks)
	bench = { sprite = "world/bench", solid = true },
	barrel = { sprite = "world/barrel", solid = true },
	sacks = { sprite = "world/sacks", solid = true },
	crate_stack = { sprite = "world/crate_stack", solid = true },
	planter = { sprite = "world/planter", solid = true },
	cart = { sprite = "world/cart", solid = true },
	notice_board = { sprite = "world/notice_board", solid = true },
	valve_pipe = { sprite = "world/valve_pipe", solid = true },
	chimney = { sprite = "world/chimney", solid = true },
	scrap_pile = { sprite = "world/scrap_pile", solid = true },
	anvil = { sprite = "world/anvil", solid = true },
	workbench = { sprite = "world/workbench", solid = true },
	coil = { sprite = "world/coil", solid = true, light = 1.5 },
	--- The last tablet of the Great Archive: blank, a stylus next to it
	blank_tablet = { sprite = "world/tablet", solid = true, interact = "look", label = "Look",
		text = "The last tablet of the Chronicle is smooth and blank. A stylus of bronze lies next to it, waiting." },
	--- The foundry: furnaces still burning, moulds of the servants of bronze
	furnace = { frames = { "world/furnace_0", "world/furnace_1" }, fps = 5, solid = true, light = 4, warmth = 3 },
	mould = { sprite = "world/mould", solid = true },
	--- Stacks of cargo on the quays: too heavy to push
	cargo = { sprite = "world/cargo", solid = true },
	--- The mast of a ship stranded on the seabed
	mast = { sprite = "world/mast", tall = "world/mast_top", solid = true },
	--- The vault of the Salt: it opens to the light of the lighthouse (a crystal)
	vault_door = { sprite = "world/vault_door", solid = true, interact = "look", label = "Look", openKind = "vault_door_open",
		text = "The vault of the Salt. No lock, no handle: a crystal set in the frame, and a lighthouse carved above it." },
	vault_door_open = { sprite = "world/vault_door_open", solid = false, flat = true },
	--- The gate of the Tide Road: sealed by the lock of the High Tide, until the Tidemother falls
	tide_road_gate = { sprite = "world/tide_road_gate", solid = true, interact = "look", label = "Look", openKind = "tide_road_gate_open",
		text = "A gate of bronze as tall as three men, sealed with the seal of the High Tide: a wave in a circle, under a crown. Cold air pours through its cracks... and it pulls upward." },
	tide_road_gate_open = { sprite = "world/tide_road_gate_open", solid = false, flat = true },
	--- A footbridge of planks over a channel: it carries the player over the water (and boats pass under it)
	footbridge = { sprite = "world/footbridge", solid = false, flat = true, floor = true },
	market_stall = { sprite = "world/market_stall", tall = "world/market_stall_top", solid = true },
	--- The Hall of Waters: the desks of the clerks, the doors of the four waters, and the bricked door of the Ebb
	registry_desk = { sprite = "world/registry_desk", solid = true },
	water_door = { sprite = "world/water_door_bronze", solid = true, interact = "water_door", label = "Look" },
	ebb_door = { sprite = "world/ebb_door", solid = true, interact = "look", label = "Look", openKind = "ebb_door_open",
		text = "A doorway bricked up, its bricks still black with soot. No name, no emblem: only a crystal, dark, next to it." },
	ebb_door_open = { sprite = "world/ebb_door_open", solid = false, flat = true },
	market_stall_fish = { sprite = "world/market_stall_cogs", tall = "world/market_stall_top", solid = true },
	--- A manhole on the street: an exit down (its cell is an entry of the level)
	sewer_hatch = { sprite = "world/sewer_hatch", solid = false, flat = true },
	--- A door of the city that only opens for citizens (the tide-mark)
	citizen_door = { sprite = "world/citizen_door", solid = true, interact = "citizen_door", label = "Open", openKind = "citizen_door_open" },
	citizen_door_open = { sprite = "world/citizen_door_open", solid = false, flat = true },
	lamp_post = { sprite = "world/lamp_post", tall = "world/lamp_top", solid = true, light = 3.5 },
	fig_tree = {
		sprite = "world/fig_tree",
		tall = "world/fig_tree_top",
		solid = true,
		interact = "fruit",
		label = "Pick",
		fruit = { item = "fig", count = 2, regrow = 90, empty = "world/fig_tree_bare" },
	},
	-- Characters (their sprite comes from data/npcs.luau)
	npc = { solid = true, interact = "talk", label = "Talk" },
} :: { [string]: PropKind }

return module
