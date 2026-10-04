--[[
The endings of the game: how the player's story ends, once the Tidemother has fallen.

- "throne": the player sits on the throne of the Tide with the crown (the palace): they rule the city.
- "surface": the player climbs the Tide Road and walks into the daylight (the surface): they escape.
- "archive": the player stays with Dr. Ilse in the Great Archive: they write the history of the Tide.

Each ending asks for confirmation (a choice in a dialog), then plays:
1. a cut-scene in the game's own rendering: shots of places of the Explorium, each with captions, the camera gliding
2. epilogue cards: what became of the people the player met, depending on what they did (the flags of the game)
3. the end: the name of the ending and a summary of the journey, then back to the title screen
The game is saved just before the ending starts: "Continue" brings the player back to the moment before their choice,
so they can see the other endings.
]]
const items = require("./data/items")
const level = require("./level")
const loader = require("@vectarine/loader")
const lore = require("./data/lore")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

--- A shot of the cut-scene: a level, the camera gliding from `from` to `to` (cells), captions shown one after the
--- other, and where the explorer stands in it (nil: not in the shot)
export type Shot = {
	level: string,
	from: { number },
	to: { number },
	captions: { string },
	explorer: { number }?,
	facing: types.Direction?,
}

export type Card = { title: string, text: string }

export type Ending = {
	name: string,
	--- The question asked before it starts, and the answers
	question: string,
	yes: string,
	no: string,
	shots: { Shot },
	--- The last card, after the epilogues of the people
	final: Card,
}

--- Seconds each caption stays on the screen
module.CAPTION_TIME = 4.2

module.endings = {
	throne = {
		name = "The New High Tide",
		question = "Sit on the throne of the Tide, the crown on your head, and stay underground forever? You will never see the sun again. (This is the end of your journey.)",
		yes = "Sit on the throne",
		no = "Not yet",
		shots = {
			{
				level = "palace",
				from = { 19, 8 },
				to = { 19, 5 },
				explorer = { 19, 3 },
				facing = "down",
				captions = {
					"You sit on the throne of the Tide. The crown is cold, and heavier than it looks.",
					"Somewhere below, the great wheel of the Engine shudders, as if it heard.",
				},
			},
			{
				level = "bronze_ward",
				from = { 8, 12 },
				to = { 36, 12 },
				captions = {
					"In the streets of the Ward, the drudges put down their tools and turn towards the palace.",
					"The lenses of the city open wide. Then, one by one, they bow.",
				},
			},
			{
				level = "hanging_gardens",
				from = { 16, 29 },
				to = { 20, 18 },
				captions = {
					"Among the figs, the Tidekeepers kneel. 'THE TIDE IS HIGH,' they say. 'THE TIDE IS HIGH AGAIN.'",
					"The Gardener keeps watering the trees. Some things don't change with a crown.",
				},
			},
		},
		final = {
			title = "The New High Tide",
			text = "You rule the city of the Tide, from its throne of marble. Below it, the Deep Tide rises again, a little more each year, and sings. Whether you let it rise, or let the Engine drink it, is another story. The bronze will do as you say. That was always the trouble with bronze.",
		},
	},
	surface = {
		name = "The Tide Road",
		question = "Walk out into the daylight, and leave the Explorium behind? (This is the end of your journey.)",
		yes = "Walk into the light",
		no = "Not yet",
		shots = {
			{
				level = "surface",
				from = { 20, 22 },
				to = { 20, 12 },
				explorer = { 20, 14 },
				facing = "up",
				captions = {
					"You climb out of the Tide Road into a light you had almost forgotten. It hurts. It's wonderful.",
					"The wind smells of grass, and of something else. Salt.",
				},
			},
			{
				level = "surface",
				from = { 20, 12 },
				to = { 34, 4 },
				captions = {
					"Far away, beyond the hills, something glitters. Green, and endless.",
					"The sea had not died. It had only moved. The Salt found it again. And now, so have you.",
				},
			},
			{
				level = "camp",
				from = { 14, 10 },
				to = { 14, 8 },
				captions = {
					"Far below, in the oasis, an old man looks up at the sinkhole, and smiles.",
				},
			},
		},
		final = {
			title = "The Tide Road",
			text = "You walked out of the Explorium by the road of the Salt, a thousand years after them. You told your story many times. Nobody believed the part about the frogs of copper. Some nights, you still put your ear to the ground, and listen for the water that sings.",
		},
	},
	archive = {
		name = "The Chronicle of the Tide",
		question = "Stay in the Great Archive with Dr. Ilse, and write the history of the sea people? (This is the end of your journey.)",
		yes = "Stay and write",
		no = "Not yet",
		shots = {
			{
				level = "archive",
				from = { 19, 13 },
				to = { 19, 10 },
				explorer = { 19, 9 },
				facing = "up",
				captions = {
					"You stay. Ilse unrolls the first scroll of the Great Archive, and reads aloud. You write.",
					"Days pass. Then years. The lamps of the Archive never go out.",
				},
			},
			{
				level = "hall_of_waters",
				from = { 10, 8 },
				to = { 10, 5 },
				captions = {
					"Unit-1 brings you the register of the waters. Together, you write back every name it struck.",
					"Tessa of the Salt. Doran of the Bronze. The Clay of the north gallery. Nerissa of the High Tide.",
				},
			},
			{
				level = "colonnade",
				from = { 16, 14 },
				to = { 28, 14 },
				captions = {
					"Copies of the Chronicle go up the stairs, to the oasis and beyond, carried by ants who like to read.",
				},
			},
		},
		final = {
			title = "The Chronicle of the Tide",
			text = "The Chronicle of the Tide fills forty volumes. It begins with the green sea, and ends with an explorer who fell through a sinkhole into a bush. Ilse says it's the best part. The sea people did not fall because the water left them. They fell because they would not let anything go. You wrote that on the first page.",
		},
	},
} :: { [string]: Ending }

--- What became of the people the player met: one card each, depending on what the player did
function module.epilogue(game: types.Game): { Card }
	local flags = game.flags
	local cards: { Card } = {}
	local function add(title: string, text: string)
		table.insert(cards, { title = title, text = text })
	end
	add("The Deep Tide", "With the Tidemother fallen, the Engine stopped drinking. Under the city, the Deep Tide rises again, a little more each year. The fountains of the gardens run. The water sings.")
	if flags.mortarColony == "done" then
		add("The Clay", "The ants of the Diggings went up to the dry halls. Queen Tikra met Old Mortar at the foot of the Howling Gorge. They didn't speak for a long time. Then they clicked, both at once.")
	else
		add("The Clay", "The ants of the Diggings stayed in their holes under the city. They still count the figs. One day, someone will tell them that the colony above is alive.")
	end
	if flags.wrenCity then
		add("Wren", "Wren saw the city of the sea people, from the balcony of the Seawall. He said it was more beautiful than he had dreamt. He went back to his fire in the oasis, and never complained about his knee again. Almost never.")
	else
		add("Wren", "Wren still sits by his fire in the oasis. He still wonders if the city of the sea people was as beautiful as he dreamt.")
	end
	if flags.maraHelped then
		add("Mara", "Mara reached the anthill, and the ants gave her water until she laughed. A year later, she climbed the Tide Road to see the sun once more. She stayed up there.")
	end
	if flags.unit7Armed then
		add("Unit-7", "Unit-7 guards the drowned colonnade with two good arms. It has begun to repair the columns the beetles ate. It no longer waits.")
	else
		add("Unit-7", "Unit-7 still waits in the colonnade, without arms, for the children of the Tide. They are not coming back. It waits anyway.")
	end
	if flags["killed:last_watchman"] then
		local vey = if flags.veyDone then " In the dream, Corporal Vey says the names of his men every night. Someone, now, answers." else ""
		add("The Frontier", `The Frostborn keep the braziers of the frontier lit. The Watch still sleeps in the ice, dreaming.{vey}`)
	end
	if flags.ilseArchive then
		add("Dr. Ilse", "Dr. Ilse read every tablet of the Great Archive. Then she wrote her own. Her university on the surface never heard of her again, and she never minded.")
	else
		add("Dr. Ilse", "Dr. Ilse kept studying the columns of the colonnade, and paying in experience for every fragment the ants brought her.")
	end
	add("Unit-9", "In the House of Healing, Unit-9 treats every patient who comes. It no longer asks for their water.")
	return cards
end

--- The summary of the journey, for the last screen
function module.summary(game: types.Game): { string }
	local seconds = math.floor(game.time)
	local creatures = 0
	for _, count in game.notebook.creatures do
		creatures += count
	end
	local tablets = 0
	for id in game.notebook.lore do
		local text = lore.texts[id]
		if text and text.ancient then
			tablets += 1
		end
	end
	local artefacts = 0
	for id in game.player.artefacts do
		if items.items[id] and items.items[id].kind == "artefact" then
			artefacts += 1
		end
	end
	return {
		string.format("Time in the Explorium: %dh %02dm", seconds // 3600, (seconds // 60) % 60),
		`Level {game.player.level}`,
		`Creatures defeated: {creatures}`,
		`Tablets read: {tablets}`,
		`Artefacts found: {artefacts}`,
	}
end

--- A game to draw a shot with: the level of the shot, the explorer standing in it (or out of view)
function module.shotGame(game: types.Game, shot: Shot): types.Game
	local view = table.clone(game) :: any
	-- In the shots, Wren is back home by his fire
	local flags = table.clone(game.flags)
	flags.wrenComing = nil
	view.flags = flags
	local lvl = level.load(shot.level, flags)
	view.level = lvl
	view.levelId = shot.level
	view.monsters = {}
	view.projectiles = {}
	view.bombs = {}
	view.pickups = {}
	view.events = {}
	local player = table.clone(game.player)
	player.invincible = 0
	player.moving = false
	if shot.explorer then
		player.pos = vec.V2(shot.explorer[1] + 0.5, shot.explorer[2] + 0.6)
		player.facing = shot.facing or "down"
	else
		player.pos = vec.V2(-50, -50)
	end
	view.player = player
	return view
end

return module
