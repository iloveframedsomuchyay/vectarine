--[[
The levels of the Explorium, by id. Each level is a module of data/maps/ (see level.luau for the format).

The first floor, the Oasis:
- sinkhole: where the explorer falls
- camp: Wren's camp, the safe place of the oasis
- fern_hollow: a lush cave with water, snakes and Click the ant
- lantern_grotto: the Glowworm Grotto, behind the roots of the Fern Hollow, where the eternal lantern burns
- dark_hollow: a maze of ledges over a chasm, pitch black without the eternal lantern
- colonnade: the first ruins of the sea people, with Dr. Ilse and Unit-7
- mole_den: the den of the Great Mole, and the stairs down

The second floor, the Desert:
- sunken_steps: the bottom of the stairs, a dead camp
- anthill: the colony of the ants, the safe place of the desert
- dry_canals: the dry irrigation of the sea people, and the gate of the Great Pump
- bazaar: a ruined market, Mara, and the council chamber
- pumping_station: inside the Great Pump, its three valves
- storm_dunes: dunes swept by sandstorms, and a hidden spring
- warden_hall: the hall of the Sun Warden, boss of the desert
- howling_gorge: an endless storm, and the stairs down

The third floor, the Wetlands:
- mire_edge: the bottom of the stairs: lily pads, a bog, a green pool
- nettle_clearing: the safe place of the wetlands, and Nettle's hut (nettle_hut, inside)
- hospital_grounds, house_of_healing: the gardens and the rooms of the hospital of the sea people
- drowned_docks: the harbor, the bell of the ferry, the storeroom of the smugglers
- great_mire: a lake of islands; frog_isle: the island of the Frog King, boss of the wetlands
- toxic_fen: the green lake, and the stairs down

The fourth floor, the Frosted Frontier:
- frozen_stair: the bottom of the stairs, the first braziers, the first ice
- rimehold: the village of the Frostborn, the safe place of the frontier, and the elder's lodge (elder_lodge, inside)
- the_glare: a frozen lake, and the icefall up to the fort
- ice_caves: the puzzles of the ice blocks, Tamsin, the hot spring
- old_watch, sleepers_barracks: the fort of the Watch, and its barracks
- watch_hall: the hall of the Last Watchman, boss of the frontier
- whiteout: a field of killing frost, the Cold Lock, and the stairs down

The fifth floor, the City of the Tide:
- seawall: the Seagate, the gatehouse on the seawall: the first view of the city, a crimson lens, the drain into the city
- bronze_ward: the Ward, the town of the lower city: houses (their insides: water_tower, ward_home, tally_shop,
  hall_of_waters (the Registry) and ebb_register, clock_tower, pump_house, ebb_house, ward_ruin, guard_post, warehouse),
  the canal and its old bridge, the Water Gate to the harbor, the Foundry gate
- diggings: the warren of the Clay under the Ward, the safe place of the city
- dry_harbor: the harbor of the Salt, dry: the lighthouse, the guild hall and its vault (the grapnel), the gate of the
  Tide Road (insides: harbor_office, lighthouse, salt_guild, ship_cabin)
- hanging_gardens: the Heights, the terraces of the High Tide, the Gardener (gardener_shed), the water lock of the palace
  gate
- palace: the halls of the High Tide, the hall of mirrors, the Tidemother's chambers, the throne, the door of the archive
- engine: the great machine under the palace: live plates, the great wheel, the cogs of the sluice
- heart: the heart of the Engine, and the Tidemother, the last boss
- archive: the Great Archive, the Chronicle of the Tide, Dr. Ilse (the ending of the Archive)
- foundry: where the servants of bronze were cast: the Foreman, the arms of Unit-7, the vault of the shafts
- tide_road: the shaft of the Salt, up to the surface, its gravity upside down (the ending of the Tide Road)
- surface: the daylight, and the sea
]]
const loader = require("@vectarine/loader")

export type LevelData = {
	name: string,
	subtitle: string?,
	--- The ground of "." cells (a terrain of data/terrain.luau), dirt by default
	floor: string?,
	darkness: number?,
	lights: { { number } }?,
	--- A beam of daylight falling from a hole in the ceiling: x, y of the cell it lights
	sunbeam: { number }?,
	--- Thin beams of daylight through cracks of the ceiling: x, y and their size (0.6 when not given). Their light is
	--- in `lights`.
	sunbeams: { { number } }?,
	legend: { [string]: any }?,
	links: { [string]: { level: string, entry: string } }?,
	map: { string },
	heights: { string }?,
	--- The floor of the Explorium the level is on (1 when not set)
	depth: number?,
	--- A style of data/legend.luau, that changes the meaning of some symbols ("desert")
	style: string?,
	--- How fast the player gets thirsty, compared to the oasis (1 when not set)
	heat: number?,
	--- Sandstorms: `calm` and `duration` in seconds (or `always`), `wind` the direction, `strength` its push
	storm: { calm: number?, duration: number?, always: boolean?, wind: { number }, strength: number }?,
	--- Snow falling over the level, from 0 (none) to 1 (a blizzard): only drawn, the cold comes from the ground
	snowfall: number?,
	--- The silhouettes framing the screen (see foreground.luau): "interior" indoors, the style of the level otherwise
	foreground: string?,
	--- Decorations, rows of the same size as `map` (see data/decor.luau)
	decor: { string }?,
	--- Parts of the level without light: x1, y1, x2, y2 (cells, included) and their darkness (see lighting.luau)
	darkAreas: { { number } }?,
	--- Pitch black: the dark swallows the flashlight, only the eternal lantern lights it (see lighting.luau)
	lightless: boolean?,
	--- Life in the air (see ambient.luau): fireflies, butterflies and leaves (densities), glints on the water
	ambient: { fireflies: number?, motes: number?, butterflies: number?, glints: boolean? }?,
	--- The city: electrified floors, the circuits that feed the copper plates (see power.luau)
	power: { { area: { number }, mode: string, period: number?, on: number?, offset: number?, breaker: string?, needs: string? } }?,
	--- Ducts under the level, rows of the same size as `map`: any character but "." is a duct (see ducts.luau)
	ducts: { string }?,
	--- The Tide Road: the pull of the tide draws everything that way (tiles per second), and the world grows upside down
	pull: { number }?,
	--- Buildings of the city drawn as whole objects (see data/building_kinds.luau): the top-left cell of their footprint,
	--- and the entry their door is (an exit like a digit of the map, linked in `links`). A building without `door`
	--- shows a door nobody can reach (in the background).
	buildings: { { kind: string, x: number, y: number, door: string?, alt: string?, altIf: string? } }?,
	--- The music and the ambience of the level, instead of its floor's (data/sounds.luau); "none" for silence
	music: string?,
	ambience: string?,
}

const module = loader.init() or {}

module.levels = {
	sinkhole = require("./maps/sinkhole"),
	camp = require("./maps/camp"),
	fern_hollow = require("./maps/fern_hollow"),
	lantern_grotto = require("./maps/lantern_grotto"),
	dark_hollow = require("./maps/dark_hollow"),
	colonnade = require("./maps/colonnade"),
	mole_den = require("./maps/mole_den"),
	sunken_steps = require("./maps/sunken_steps"),
	anthill = require("./maps/anthill"),
	dry_canals = require("./maps/dry_canals"),
	bazaar = require("./maps/bazaar"),
	pumping_station = require("./maps/pumping_station"),
	storm_dunes = require("./maps/storm_dunes"),
	warden_hall = require("./maps/warden_hall"),
	howling_gorge = require("./maps/howling_gorge"),
	mire_edge = require("./maps/mire_edge"),
	nettle_clearing = require("./maps/nettle_clearing"),
	nettle_hut = require("./maps/nettle_hut"),
	hospital_grounds = require("./maps/hospital_grounds"),
	house_of_healing = require("./maps/house_of_healing"),
	drowned_docks = require("./maps/drowned_docks"),
	great_mire = require("./maps/great_mire"),
	frog_isle = require("./maps/frog_isle"),
	toxic_fen = require("./maps/toxic_fen"),
	frozen_stair = require("./maps/frozen_stair"),
	rimehold = require("./maps/rimehold"),
	elder_lodge = require("./maps/elder_lodge"),
	the_glare = require("./maps/the_glare"),
	ice_caves = require("./maps/ice_caves"),
	old_watch = require("./maps/old_watch"),
	sleepers_barracks = require("./maps/sleepers_barracks"),
	watch_hall = require("./maps/watch_hall"),
	whiteout = require("./maps/whiteout"),
	seawall = require("./maps/seawall"),
	bronze_ward = require("./maps/bronze_ward"),
	diggings = require("./maps/diggings"),
	hall_of_waters = require("./maps/hall_of_waters"),
	water_tower = require("./maps/water_tower"),
	ward_home = require("./maps/ward_home"),
	tally_shop = require("./maps/tally_shop"),
	ebb_register = require("./maps/ebb_register"),
	clock_tower = require("./maps/clock_tower"),
	pump_house = require("./maps/pump_house"),
	ebb_house = require("./maps/ebb_house"),
	ward_ruin = require("./maps/ward_ruin"),
	guard_post = require("./maps/guard_post"),
	warehouse = require("./maps/warehouse"),
	dry_harbor = require("./maps/dry_harbor"),
	harbor_office = require("./maps/harbor_office"),
	lighthouse = require("./maps/lighthouse"),
	salt_guild = require("./maps/salt_guild"),
	ship_cabin = require("./maps/ship_cabin"),
	hanging_gardens = require("./maps/hanging_gardens"),
	gardener_shed = require("./maps/gardener_shed"),
	palace = require("./maps/palace"),
	engine = require("./maps/engine"),
	heart = require("./maps/heart"),
	archive = require("./maps/archive"),
	foundry = require("./maps/foundry"),
	tide_road = require("./maps/tide_road"),
	surface = require("./maps/surface"),
} :: { [string]: LevelData }

--- The names of the floors of the Explorium, from the top
module.floorNames = { "The Oasis", "The Desert", "The Wetlands", "The Frosted Frontier", "The City of the Tide", "The Depth" }

--- The levels in the order of the journey, for the maps of the notebook
module.order = {
	"sinkhole",
	"camp",
	"fern_hollow",
	"lantern_grotto",
	"dark_hollow",
	"colonnade",
	"mole_den",
	"sunken_steps",
	"anthill",
	"dry_canals",
	"bazaar",
	"pumping_station",
	"storm_dunes",
	"warden_hall",
	"howling_gorge",
	"mire_edge",
	"nettle_clearing",
	"nettle_hut",
	"hospital_grounds",
	"house_of_healing",
	"drowned_docks",
	"great_mire",
	"frog_isle",
	"toxic_fen",
	"frozen_stair",
	"rimehold",
	"elder_lodge",
	"the_glare",
	"ice_caves",
	"old_watch",
	"sleepers_barracks",
	"watch_hall",
	"whiteout",
	"seawall",
	"bronze_ward",
	"water_tower",
	"ward_home",
	"tally_shop",
	"ebb_register",
	"clock_tower",
	"pump_house",
	"ebb_house",
	"ward_ruin",
	"guard_post",
	"warehouse",
	"diggings",
	"hall_of_waters",
	"foundry",
	"dry_harbor",
	"harbor_office",
	"lighthouse",
	"salt_guild",
	"ship_cabin",
	"hanging_gardens",
	"gardener_shed",
	"palace",
	"engine",
	"heart",
	"archive",
	"tide_road",
	"surface",
}

return module
