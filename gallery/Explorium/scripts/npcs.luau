--[[
Friendly characters: what they say, what they trade and the quests they give.
(This file is with the rules rather than in data/ because the dialogs give items and experience.)

`talk(game)` returns the lines of the dialog (see dialog.luau). It reads and changes `game.flags` to remember where the
story is: a line can be a function that gives an item or starts a quest, and returns a line of narration.

`shop` lists what a trader sells: `price` is paid with `currency` (an item id).
]]
const gallery = require("./gallery")
const inventory = require("./inventory")
const items = require("./data/items")
const level = require("./level")
const levels = require("./data/levels")
const loader = require("@vectarine/loader")
const player_rules = require("./player")
const types = require("./types")

export type Offer = { item: string, count: number, price: number, currency: string }

export type Npc = {
	name: string,
	--- Prefix of the frames in the "characters" sheet (wren_0, wren_1)
	sprite: string,
	talk: (game: types.Game) -> { types.DialogStep },
	shop: { Offer }?,
	--- Only there for a dreaming player (a phantom, see dream.luau)
	dream: boolean?,
	--- Does the character trade right now? (Tally only trades with citizens.) Always, when not set.
	trades: ((game: types.Game) -> boolean)?,
}

const module = loader.init() or {}

--- The maps Wren copies into the notebook when he gets his pack back
const WREN_MAPS = { "fern_hollow", "dark_hollow", "lantern_grotto" }

--- Wren's map of a level, copied into the notebook: every cell that isn't solid rock is explored (the walls around them
--- are drawn with them, see map_view.luau). What the player explored already stays explored.
local function copyMap(game: types.Game, id: string)
	local lvl = level.load(id, game.flags)
	local old = game.notebook.explored[id] or {}
	local rows: { string } = {}
	for y = 0, lvl.height - 1 do
		local row = table.create(lvl.width, "0")
		local oldRow = old[y + 1] or ""
		for x = 0, lvl.width - 1 do
			local wall = level.wallAt(lvl, x, y)
			if string.sub(oldRow, x + 1, x + 1) == "1" or not (wall and not wall.walkable) then
				row[x + 1] = "1"
			end
		end
		rows[y + 1] = table.concat(row)
	end
	game.notebook.explored[id] = rows
end

--- A dialog step that gives an item and tells the player
local function give(itemId: string, count: number?): types.DialogStep
	return function(game: types.Game): string?
		local left = inventory.give(game.player, itemId, count or 1)
		local name = items.items[itemId].name
		if items.items[itemId].kind == "artefact" then
			game.events[#game.events + 1] = { kind = "artefact", item = itemId }
		end
		if left > 0 then
			table.insert(game.pickups, { pos = game.player.pos, item = itemId, count = left, age = 0, dead = false })
			return `Your bag is full: the {string.lower(name)} is on the ground.`
		end
		return if (count or 1) > 1 then `You got {count} × {name}!` else `You got: {name}!`
	end
end

local function xp(amount: number): types.DialogStep
	return function(game: types.Game): string?
		player_rules.gainXp(game, amount)
		return `+{amount} experience`
	end
end

local function setFlag(name: string, value: any): types.DialogStep
	return function(game: types.Game): string?
		game.flags[name] = value
		return nil
	end
end

--- The dream runes where the squad of Corporal Vey carved their names (data/lore.luau)
module.WATCH_NAMES = { "watch_name_orren", "watch_name_maelis", "watch_name_tobin", "watch_name_astra" }

--- Where each of them stood guard (Corporal Vey tells the player)
module.WATCH_POSTS = { "at the frozen stair", "on the frozen lake", "in the ice caves", "on the walls of the Watch" }

--- The places of the frontier where a brazier is still dark (for Brann the lamplighter)
function module.darkPlaces(game: types.Game): { string }
	local places = {}
	for _, id in levels.order do
		local data = levels.levels[id]
		if data.depth == 4 then
			for _, prop in level.load(id, {}).props do
				if prop.kind == "brazier" and not game.flags[`lit:{prop.key}`] then
					table.insert(places, data.name)
					break
				end
			end
		end
	end
	return places
end

--- The braziers of the frontier: how many are lit, and how many there are (for Brann the lamplighter)
function module.braziers(game: types.Game): (number, number)
	local lit, total = 0, 0
	for id, data in levels.levels do
		if data.depth == 4 then
			for _, prop in level.load(id, {}).props do
				if prop.kind == "brazier" then
					total += 1
					if game.flags[`lit:{prop.key}`] then
						lit += 1
					end
				end
			end
		end
	end
	return lit, total
end

module.npcs = {
	wren = {
		name = "Wren",
		sprite = "wren",
		talk = function(game)
			local flags = game.flags
			if not flags.wrenMet then
				local hollow = if flags.tutorialDark
					then "You went into the Dark Hollow already? And you came back! Smart. Nobody crosses that one with a flashlight."
					else "East of here is the Dark Hollow. Don't bother with your flashlight in there: the dark eats it."
				return {
					"Well, well. Another one fell through the sinkhole? Don't look up, it only makes it worse.",
					"I'm Wren. I came down here forty years ago, looking for the city of the sea people.",
					"I found a fig tree, a bad knee and a lot of rats. Welcome to the Explorium.",
					"Keep your bottle full: the pools are clean. Rest by my fire when you're hurt, it's the only safe place around.",
					"The way out? Up is too far. The only way is down: through the Dark Hollow, and on to the den of the Great Mole. She doesn't like visitors.",
					hollow,
					"It's a maze of chasms, black as the inside of a boot. You need a real light to cross it, and a map. I can help you with both.",
					"But first... I lost my pack in the Fern Hollow, south of here. My maps are in it. Bring it back?",
					setFlag("wrenMet", true),
					setFlag("questPack", "started"),
				}
			end
			if flags.questPack == "started" and inventory.count(game.player, "wren_pack") > 0 then
				return {
					"My pack! And the maps are dry. You're a good one.",
					function(g: types.Game): string?
						inventory.take(g.player, "wren_pack", 1)
						g.flags.questPack = "done"
						return nil
					end,
					"Here, the best thing in it: my lens. Sea people work, found it in the ruins east of here.",
					"Look through it while you walk, and the places you've seen draw themselves. That's how I made my maps.",
					give("cartographer_lens"),
					"And let me copy my old maps into your notebook. There. The Fern Hollow, the Dark Hollow... and a little grotto you'd never find alone.",
					function(g: types.Game): string?
						for _, id in WREN_MAPS do
							copyMap(g, id)
						end
						return "Wren's maps are in your notebook: the Fern Hollow, the Dark Hollow and the Glowworm Grotto."
					end,
					"Now, the light. On the east side of the Fern Hollow, behind the ferns, there's a crawl under the roots of the wall. It leads to the Glowworm Grotto.",
					"At the end of it, on an altar of the sea people, burns a lantern. Forty years I've seen it burn, and never a drop of oil. The sea people made things to last.",
					"Why didn't I take it? The crawl, friend. With my knee? They'd find my bones in there, still complaining.",
					"Take it. With that lantern, the Dark Hollow is just a dark cave. And with my map, it's just a cave. Open your notebook, turn to the map: the way is marked.",
					"Oh, and take my old vest too. It stopped a lot of teeth. It'll stop more.",
					give("leather_vest"),
					xp(25),
				}
			end
			-- Saves from before the lens was Wren's reward
			if flags.questPack == "done" and not game.player.artefacts.cartographer_lens then
				return {
					"Wait, I almost forgot! The best thing in my pack: this lens. It draws the places you've seen.",
					give("cartographer_lens"),
				}
			end
			-- Until the player carries the lantern of the grotto
			if flags.questPack == "done" and not game.player.artefacts.eternal_lantern and (flags.deepestFloor or 1) <= 1 then
				return {
					-- Saves from before Wren copied his maps
					function(g: types.Game): string?
						if g.notebook.explored.lantern_grotto == nil then
							for _, id in WREN_MAPS do
								copyMap(g, id)
							end
						end
						return nil
					end,
					"The lantern? In the Glowworm Grotto. East side of the Fern Hollow, behind the ferns: a crawl under the roots of the wall. It's on your map, in your notebook.",
					"Don't try the Dark Hollow without it. I did, once, with a torch. The dark ate the torch. I nearly followed it.",
				}
			end
			if flags.questPack == "started" then
				local steps: { types.DialogStep } = {}
				if not flags.wrenToldLens then
					flags.wrenToldLens = true
					table.insert(steps, "Why do I fuss so much over an old pack? Because my cartographer's lens is in it. Sea people work.")
					table.insert(steps, "Look through it, and every place you walk draws itself on paper. Forty years of maps came out of that lens. Without it, I'm an old man who forgets which cave is which.")
					table.insert(steps, "And without a map, you'll never get through the Dark Hollow. So you see, we both need that pack.")
				end
				table.insert(steps, "My pack is in the Fern Hollow, south of the camp. Cross the stream at the ford, then go to the far south-east corner, past the tall grass.")
				table.insert(steps, "That's where a snake chased me and I dropped it. Mind the snakes: they hide in the tall grass, and they coil before they strike.")
				return steps
			end
			-- In the city: on the balcony of the Seawall, at last
			if game.level.id == "seawall" then
				if not flags.wrenCity then
					return {
						"*puff* *puff* ...Your teleporters make my knee feel every year of its age. Now. Let me see.",
						"...",
						"Look at it. LOOK at it. The roofs, the lamps, the wheel... Forty years, I looked for this.",
						"It's more beautiful than I dreamt. I didn't think that was possible. I've had good dreams.",
						"Here. My compass. It never pointed north down here, but it pointed me here, in the end. Take it.",
						setFlag("wrenCity", true),
						give("wrens_compass"),
						xp(60),
					}
				end
				return { "I'll stay a while. Go on, finish what you started. I'm fine. I'm better than fine." }
			end
			if (flags.deepestFloor or 1) >= 5 and not flags.wrenComing then
				return {
					"You found it. The city. I can see it in your face, don't deny it.",
					"Is it beautiful? No. Don't tell me. Show me.",
					"The teleporters, you said? Ha. My knee hates you already. I'll be at the first big wall you saw down there. The one with a view.",
					setFlag("wrenComing", true),
				}
			end
			if game.flags["killed:great_mole"] then
				return {
					"You beat the Great Mole? Ha! Forty years I've been hiding from her.",
					"Go on, then. Go down. And if you find the city... tell me if it's as beautiful as I dreamt.",
				}
			end
			return {
				"Ilse, the scientist, camps in the old colonnade to the east. She pays well for fragments of the ruins.",
				"And the ant, Click? Trades anything for figs. I don't ask what an ant does with that many figs.",
			}
		end,
	},

	click = {
		name = "Click",
		sprite = "click",
		talk = function(game)
			if not game.flags.clickMet then
				game.flags.clickMet = true
				return {
					"*click click* ... You. Two legs. Smell of figs? *click*",
					"Click trades. Figs for things. Things for figs. *happy clicking*",
				}
			end
			return {
				"*click* Figs? Figs! Click has things. *click click*",
				"Cousin Clack trades in the dry halls, down below. Clack sells boom-booms! Click doesn't like boom-booms.",
			}
		end,
		shop = {
			{ item = "bandage", count = 1, price = 2, currency = "fig" },
			{ item = "herb_tea", count = 1, price = 3, currency = "fig" },
			{ item = "arrows", count = 5, price = 2, currency = "fig" },
			{ item = "firefly_jar", count = 1, price = 6, currency = "fig" },
			{ item = "vigor_ring", count = 1, price = 10, currency = "fig" },
			{ item = "bone_bow", count = 1, price = 12, currency = "fig" },
		},
	},

	ilse = {
		name = "Dr. Ilse",
		sprite = "ilse",
		talk = function(game)
			local flags = game.flags
			local steps: { types.DialogStep } = {}
			-- The city of the sea people (floor 5): she comes down, then waits for the player in the Great Archive
			if game.level.id == "archive" then
				if not flags.ilseArchive then
					return {
						"We're in. We're IN. Look at this place! Shelves to the ceiling, and on the desks... the Chronicle of the Tide.",
						"The whole story of the sea people, from the green sea to the end. Three years of my life were for this moment. Thank you. Truly.",
						setFlag("ilseArchive", true),
						xp(100),
						"Read the four tablets of the Chronicle, all of them. Then go and finish their story: the Tidemother is still below the palace.",
					}
				end
				if flags["killed:tidemother"] then
					return {
						"Do you hear it, through the floor? The water sings. After a thousand years. You did that.",
						"The last tablet of the Chronicle is blank. Someone has to write the end of their story... and the beginning of what comes next.",
						"Stay? With me? We'd have a library to ourselves, and all the time in the world. Or go: the Tide Road is open, and the sun is up there. Your choice, explorer.",
						function(g: types.Game): string?
							g.events[#g.events + 1] = { kind = "endingChoice", ending = "archive" }
							return nil
						end,
					}
				end
				return { "Four tablets: the green sea, the four waters, the low, the Unebbing. Every word is worth it. And the Tidemother is below the palace, in the Engine." }
			end
			if game.level.id == "diggings" then
				if not flags["open:foundry_pump"] then
					return {
						"Ants that read! Did you know? Mortar has been teaching me their clicks. I'm hopeless.",
						"The sea people wrote everything down. Their archive must be in the palace of the High Tide. The gardens above the harbor lead to it, Mortar says. Open the way, and I'll read every word.",
					}
				end
				if not flags["open:archive_door"] then
					return {
						"A door that wants three words? Of course it does. They loved their riddles.",
						"\"The first tablet, carved when we came down\"... That's the first tablet of the oasis, in the colonnade, by my old camp! You copied it in your notebook, didn't you? Read it again.",
					}
				end
				return { "The Archive is open? I'm going. Now. Right now." }
			end
			if (flags.deepestFloor or 1) >= 5 and not flags.ilseCity then
				return {
					"You... found the city? The city of the sea people? Below the ice? Don't joke about that, please.",
					"You're not joking. Take me there. I mean it. Three years I've waited for this.",
					"I'll find the teleporter you woke down there: the ants' warren, you said? Give me a day to pack my notes.",
					setFlag("ilseCity", true),
				}
			end
			if flags.questPack == "started" and inventory.count(game.player, "wren_pack") > 0 then
				table.insert(steps, "Wait, that pack... it's Wren's! He has been grumbling about it for weeks. Take it back to his camp, before he limps all the way here with his bad knee.")
			end
			if not flags.ilseMet then
				flags.ilseMet = true
				table.insert(steps, "Oh! A living person. Sorry, I talk to the columns too much. Dr. Ilse, university of the surface.")
				table.insert(steps, "My expedition came down three years ago. I'm what's left of it. But look around you!")
				table.insert(steps, "The sea people built this. Engineers, astronomers... and when their sea dried up, they followed the water down.")
				table.insert(steps, "Bring me the fragments you find in the ruins. Every piece of writing tells me more. I'll teach you what I learn.")
				table.insert(steps, "Bring me three, and I'll give you something to deal with those bronze beetles.")
			end
			local fragments = inventory.count(game.player, "ancient_fragment")
			if fragments > 0 then
				table.insert(steps, function(g: types.Game): string?
					inventory.take(g.player, "ancient_fragment", fragments)
					g.flags.fragmentsGiven = (g.flags.fragmentsGiven or 0) + fragments
					player_rules.gainXp(g, fragments * 10)
					return `You give {fragments} fragment{if fragments > 1 then "s" else ""} to Ilse. +{fragments * 10} experience`
				end)
				table.insert(steps, "Wonderful. This symbol... it means 'tide'. Or 'mother'. They used the same word.")
			end
			local given: number = flags.fragmentsGiven or 0
			if given + fragments >= 3 and not flags.ilseReward then
				table.insert(steps, "Three fragments! As promised: a spark caster. I found it in the eastern halls, still humming.")
				table.insert(steps, "It turns thoughts into lightning. Those bronze beetles hate it: metal shells and lightning don't mix.")
				table.insert(steps, "It takes a steady mind, though. Train your sanity before you try it, or it will burn you out.")
				table.insert(steps, give("spark_caster"))
				table.insert(steps, setFlag("ilseReward", true))
			end
			if not flags.ilseReward and given + fragments < 3 then
				table.insert(steps, `{given + fragments} of 3 fragments so far. The chests of these halls hold some: one behind the vines, others in the eastern halls.`)
				table.insert(steps, "Break the pots of the ruins too, the sea people kept their writings in them. And the beetles swallow fragments with the columns they eat.")
			elseif #steps == 0 then
				table.insert(steps, "Fragments, tablets, anything with writing on it. Each one tells me more about the sea people.")
			end
			return steps
		end,
	},

	unit7 = {
		name = "Unit-7",
		sprite = "unit7",
		talk = function(game)
			local flags = game.flags
			local killed: number = game.notebook.creatures.beetle_bronze or 0
			-- Its arms, found in the stores of the foundry of the city
			if inventory.count(game.player, "unit7_arms") > 0 and not flags.unit7Armed then
				return {
					"...ARMS DETECTED. SERIAL NUMBER: UNIT-7. THESE ARE UNIT-7'S ARMS.",
					function(g: types.Game): string?
						inventory.take(g.player, "unit7_arms", 1)
						g.flags.unit7Armed = true
						return "You hold out the arms. Unit-7 clicks them into place, one, then the other."
					end,
					"INSTALLING... UNIT-7 ARMS: ONLINE. UNIT-7 CAN HOLD THINGS AGAIN. UNIT-7 CAN REPAIR THE COLUMNS.",
					"UNIT-7 WAITED FOR THE CHILDREN OF THE TIDE. THEY ARE NOT COMING BACK, ARE THEY? ...THEN UNIT-7 WILL STOP WAITING, AND WORK.",
					xp(80),
					give("energy_core"),
				}
			end
			if flags.unit7Armed then
				return { "UNIT-7 IS REPAIRING THE COLUMNS. FORTY TO GO. UNIT-7 HAS TIME." }
			end
			if not flags.unit7 then
				return {
					"UNIT-7 ONLINE. LAST INSTRUCTION: PROTECT THE HALLS OF THE TIDE.",
					"STATUS: HALLS UNDER ATTACK. BRONZE BEETLES ARE EATING THE COLUMNS. UNIT-7 ARMS: MISSING.",
					"REQUEST: DESTROY FOUR BRONZE BEETLES. REWARD: ONE ENERGY CORE. TELEPORTERS ACCEPT ENERGY CORES.",
					setFlag("unit7", "started"),
					setFlag("unit7KillsAtStart", killed),
				}
			end
			if flags.unit7 == "started" then
				local start: number = flags.unit7KillsAtStart or 0
				local done = killed - start
				if done >= 4 then
					return {
						"BEETLES DESTROYED: FOUR. THE HALLS ARE SAFE. UNIT-7 IS... GRATEFUL.",
						give("energy_core"),
						xp(30),
						setFlag("unit7", "done"),
					}
				end
				return {
					`BEETLES DESTROYED: {math.max(0, done)} OF FOUR. THEY ARE CRAWLING IN THE EASTERN HALLS.`,
					"ANALYSIS: BLADES SLIDE ON BRONZE SHELLS. A CLUB CRACKS THEM. LIGHTNING CRACKS THEM BETTER.",
				}
			end
			return {
				"THE CHILDREN OF THE TIDE WENT DOWN THE STAIRS. UNIT-7 STAYED. UNIT-7 WAITS.",
				"THE GREAT TUNNELER GUARDS THE STAIRS. SHE WAS A FRIEND, ONCE. SHE FORGOT.",
			}
		end,
	},

	-- MARK: The desert

	queen = {
		name = "Queen Tikra",
		sprite = "queen",
		talk = function(game)
			local flags = game.flags
			if not flags.queenMet then
				return {
					"*click*... A two-legs, alive, in the dry halls. I am Tikra, queen of this colony.",
					"Long ago our foremothers fled the city of the sea people, when the Clay rose. The sea people found us here and made us dig these halls. Their Sun Warden watched us, day and night. It still does.",
					"When the sea people sealed their city, the Great Pump still kept our cistern full. Then the sand ate its valves, and the water stopped.",
					"We drink the last drops of the cistern. Help yourself, friend: water shared is never lost.",
					"The Great Pump is past the dry canals. Its gate is sealed, its valves are stuck. Make the water flow again, and the colony will give you its greatest treasure.",
					"The sea people wrote down how their machines work. Ossa, our scribe, can teach you to read their words.",
					"And whatever you do, do not face the Sun Warden while the colony is thirsty. It drinks the water of those who fight it.",
					setFlag("queenMet", true),
					setFlag("questPump", "started"),
				}
			end
			if flags.waterRestored and flags.questPump ~= "done" then
				return {
					"Water! I hear it singing in the walls! The cistern is full for the first time in my life. *click click*",
					"Take this: the everflowing amphora. The sea people gave it to their overseers. We stole it, and kept it hidden. Its water never ends.",
					give("everflowing_amphora"),
					xp(50),
					setFlag("questPump", "done"),
					"One thing still keeps us slaves: the Sun Warden. It waits in its hall, beyond the storm dunes. If you are strong enough... free us.",
					setFlag("questWarden", "started"),
				}
			end
			if game.flags["killed:sun_warden"] and flags.questWarden ~= "done" then
				return {
					"The Warden is silent? ... For the first time in a thousand years, no ant has to dig for anyone.",
					"You are a friend of the colony, forever. The way down is through the Howling Gorge: with the Warden's eye, the storm will part for you.",
					xp(60),
					setFlag("questWarden", "done"),
				}
			end
			-- The cousins under the city (Old Mortar, in the Diggings)
			if flags.mortarColony == "started" and not flags.tikraToken then
				return {
					"Cousins? Ants of the Clay, under the city of the sea people, alive, after all this time? *click click*",
					"They think we died in the sand. Ha! Take my token, friend: they will know my scent.",
					"Tell them the Warden is silent and the water flows. There is room for all of us in the dry halls.",
					setFlag("tikraToken", true),
					give("queen_token"),
				}
			end
			if flags.questWarden == "done" then
				return { "Go well, friend. The colony will sing about you. Badly, but loudly. *click*" }
			end
			if flags.questWarden == "started" then
				return {
					"The hall of the Sun Warden is beyond the storm dunes. It will try to drink you dry...",
					"...but the amphora never empties. Let it drink, friend. Let it drink until it chokes.",
				}
			end
			return {
				"The pump is past the dry canals. Its gate is covered with the words of the sea people: learn to read them, Ossa can help.",
				"Do not go near the Sun Warden before the water flows again. Our bravest died thirsty at its feet.",
			}
		end,
	},

	ossa = {
		name = "Ossa the scribe",
		sprite = "ossa",
		talk = function(game)
			local flags = game.flags
			local steps: { types.DialogStep } = {}
			if not flags.ossaMet then
				flags.ossaMet = true
				table.insert(steps, "Ah, a reader? I am Ossa, scribe of the colony. I keep what is left of our archive.")
				table.insert(steps, "The sea people burned it when we rebelled. Only our lexicon survived: the key to their language. And three of its pages are lost.")
				table.insert(steps, "Clack's scouts saw one in the dry canals, behind a cracked wall. Another is in the bazaar, among the bronze guards. And little Pip found one, but Pip trades, Pip never gives.")
				table.insert(steps, "Bring me the three pages and I will bind the lexicon for you. The tablets of the sea people will speak to you, even those of the oasis above.")
			end
			local pages = inventory.count(game.player, "lexicon_page")
			local given: number = flags.lexiconPages or 0
			-- A failsafe: once the three pages have been found (the two chests opened, Pip fed), the lexicon is whole,
			-- even if a page got lost on the way (left in a chest, dropped...). Pages still around are bound into it.
			local allFound = flags.pipFed and flags["opened:dry_canals:2,29"] and flags["opened:bazaar:44,28"]
			if allFound and not game.player.artefacts.tide_lexicon then
				table.insert(steps, function(g: types.Game): string?
					inventory.take(g.player, "lexicon_page", pages)
					local quantum = g.chests.quantum or {}
					local stored = 0
					for _, stack in quantum do
						if stack.id == "lexicon_page" then
							stored += stack.count
						end
					end
					inventory.removeFrom(quantum, "lexicon_page", stored)
					g.flags.lexiconPages = 3
					return "You give Ossa what you found of the lexicon."
				end)
				table.insert(steps, "The three pages... I recognize them all, even the one you left behind. The lexicon is whole again! Take it, two-legs. Read everything, and remember us when you do.")
				table.insert(steps, give("tide_lexicon"))
				table.insert(steps, xp(40))
				return steps
			end
			if pages > 0 and not game.player.artefacts.tide_lexicon then
				table.insert(steps, function(g: types.Game): string?
					inventory.take(g.player, "lexicon_page", pages)
					g.flags.lexiconPages = given + pages
					return `You give {pages} page{if pages > 1 then "s" else ""} to Ossa.`
				end)
				if given + pages >= 3 then
					table.insert(steps, "The lexicon is whole again! Take it, two-legs. Read everything, and remember us when you do.")
					table.insert(steps, give("tide_lexicon"))
					table.insert(steps, xp(40))
				else
					table.insert(steps, `{given + pages} of 3 pages. Keep looking, please.`)
				end
				return steps
			end
			if game.player.artefacts.tide_lexicon then
				table.insert(steps, "Read everything, two-legs. The sea people wrote down how to open every door they built.")
				return steps
			end
			table.insert(steps, `{given} of 3 pages. The gate of the Great Pump, the door of the council... the sea people carved words next to every door.`)
			if not flags["opened:dry_canals:2,29"] then
				table.insert(steps, "One page is in the dry canals, behind a cracked wall in the far south-west. Clack's scouts saw it.")
			end
			if not flags["opened:bazaar:44,28"] then
				table.insert(steps, "One is in a chest of the bazaar, in the court of the bronze sentinels. The chest stays sealed while they stand.")
			end
			if not flags.pipFed then
				table.insert(steps, "And little Pip, in the colony, keeps the last one. Pip wants a prickly pear: the cacti of the canals grow them, Clack sells them.")
			end
			return steps
		end,
	},

	clack = {
		name = "Clack",
		sprite = "clack",
		talk = function(game)
			if not game.flags.clackMet then
				game.flags.clackMet = true
				return {
					"*click* A customer! Cousin Click told me about two-legs. Figs? Figs!",
					"Clack sells bombs. Boom-boom! Walls with cracks are hollow: one bomb, and the wall is a door. Step back first.",
					"My scouts saw cracks in the south-west of the dry canals. Boom-boom, and who knows what's behind?",
				}
			end
			return { "*click* Bombs, pears, arrows. Clack has everything, for figs. Cracks in walls? Boom-boom!" }
		end,
		shop = {
			{ item = "bomb", count = 2, price = 3, currency = "fig" },
			{ item = "prickly_pear", count = 1, price = 2, currency = "fig" },
			{ item = "arrows", count = 5, price = 2, currency = "fig" },
			{ item = "herb_tea", count = 1, price = 3, currency = "fig" },
			{ item = "bandage", count = 1, price = 2, currency = "fig" },
			{ item = "desert_wraps", count = 1, price = 10, currency = "fig" },
			{ item = "bone_bow", count = 1, price = 12, currency = "fig" },
		},
	},

	pip = {
		name = "Pip",
		sprite = "pip",
		talk = function(game)
			local flags = game.flags
			if not flags.pipFed and inventory.count(game.player, "prickly_pear") > 0 then
				return {
					"A pear! For me? *crunch crunch crunch* Thank you thank you!",
					function(g: types.Game): string?
						inventory.take(g.player, "prickly_pear", 1)
						g.flags.pipFed = true
						return "You give a prickly pear to Pip."
					end,
					"Here, the funny paper! It has the old squiggles on it.",
					give("lexicon_page"),
				}
			end
			if not flags.pipFed then
				return {
					"*click!* Hi! You're tall! Do you have a pear? I'm sooo thirsty. I found a funny paper, you can have it for a pear!",
				}
			end
			return {
				"Mom says the big bronze man drinks people. He drinks them until they're dry like a leaf! *shiver*",
				"Mom says nobody can beat him while we're thirsty. When the water comes back, maybe.",
			}
		end,
	},

	mandi = {
		name = "Mandi",
		sprite = "mandi",
		talk = function(game)
			if game.flags["killed:sun_warden"] then
				return { "The Warden is down? *click* ... I guess I'll need a new job. Thank you, two-legs." }
			end
			if not game.flags.mandiMet then
				game.flags.mandiMet = true
				return {
					"Halt. ...A two-legs. Fine, the queen says friends may pass. I am Mandi, I guard the colony.",
					"Scorpions: blades slide on their shell. Hit them with something heavy, and keep away from the tail when it rises.",
					"East of the bazaar are the storm dunes. When the sand rises, you see nothing. Keep to the rocks: storms pass.",
					"Beyond the dunes is the Howling Gorge. Its wind throws you back. They say only the Warden's eye sees through it.",
					"And the Warden... it drinks the water of those who fight it, and its bronze heals. Don't go before the water flows again.",
				}
			end
			return {
				"Sentinels fire when their lens glows. Hit them between two shots. Better: bring something heavy, or lightning.",
				"When the sand rises on the dunes, the wind is stronger than legs. Wait behind a rock until it passes.",
			}
		end,
	},

	mara = {
		name = "Mara",
		sprite = "mara",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			if flags.maraHelped then
				return {
					"Three dead palms leaning together, by the north wall of the dunes. Water behind the rock. Bring a bomb!",
					"I'll rest here a while. Then I'll go and see these ants.",
				}
			end
			local player = game.player
			local hasWater = player.sips > 0 or inventory.count(player, "prickly_pear") > 0
			if not hasWater then
				return { "Water... please. Anything. I've been stuck in this bazaar for days... if you find any water, please..." }
			end
			local steps: { types.DialogStep } = {
				"Water... please. Anything. I've been stuck in this bazaar for days...",
				function(g: types.Game): string?
					if g.player.sips > 0 then
						g.player.sips -= 1
						return "You give Mara a sip from your bottle."
					end
					inventory.take(g.player, "prickly_pear", 1)
					return "You give Mara a prickly pear."
				end,
				"Oh... thank you. I'm Mara. I wrote the note you may have found up in the sinkhole. I did go east... and down, and down, as far as the cold below the marshes.",
				"Then I came back up. I wanted to see the sun once more. The desert ran me dry before I could.",
				"Take my spare waterskin. Two more sips in your bottle: you'll need them more than I do now.",
				give("waterskin"),
				xp(20),
				setFlag("maraHelped", true),
				"And listen: in the storm dunes, by the north wall, three dead palms lean together. I heard water behind the rock there. The wall is cracked... I had nothing to break it with.",
			}
			return steps
		end,
	},

	-- MARK: The wetlands

	nettle = {
		name = "Nettle",
		sprite = "nettle",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local player = game.player
			local steps: { types.DialogStep } = {}
			if not flags.nettleMet then
				flags.nettleMet = true
				table.insert(steps, "Hm? A two-legs, dripping on my floor. Wipe your feet. I am Nettle.")
				table.insert(steps, "My foremothers cared for the Ebb, the sick the city threw down here. Herbs, broths, and a kind word. More than the healers ever gave them.")
				table.insert(steps, "The marsh is sick too. Its heart is the Frog King, fat on the poisons of the House of Healing.")
				table.insert(steps, "To go down, you must cross the fen. Its water eats you from the inside... unless you hold the stone that grows in the King's belly.")
				table.insert(steps, "The King lives on an island of the great mire: you'll need a boat. The ferry of the old ones sleeps at the docks, but the air there is rotten. The healers had masks for that. Look in their House.")
				table.insert(steps, "And if you find bog lilies, bring me four: I'll brew you my tonic.")
			end
			if inventory.count(player, "bog_lily") >= 4 and not flags.lilyQuest then
				table.insert(steps, function(g: types.Game): string?
					inventory.take(g.player, "bog_lily", 4)
					g.flags.lilyQuest = true
					return "You give four bog lilies to Nettle."
				end)
				table.insert(steps, "Fresh ones! Give me a moment... *bubble bubble* There. Drink it when the marsh bites hard.")
				table.insert(steps, give("nettle_tonic", 3))
				table.insert(steps, xp(30))
				return steps
			end
			if #steps > 0 then
				return steps
			end
			if not flags.lilyQuest then
				table.insert(steps, `Lilies, two-legs: {inventory.count(player, "bog_lily")} of 4. They grow in the bogs: at the edge of the mire, in the gardens of the hospital, on an island of the great mire. The lurkers of the bogs swallow them too.`)
			end
			if not player.artefacts.beaked_mask then
				table.insert(steps, "The masks of the healers are in their House. The menders still guard it, and they mend each other: strike the menders first.")
			elseif not player.artefacts.ferry_skiff then
				table.insert(steps, "With the mask, the docks. The ferry answers to the bell, they say, but not to just anyone. The old ones wrote everything on their stones.")
			elseif not flags["killed:frog_king"] then
				table.insert(steps, "The King's island is in the middle of the great mire. Watch its shadow when it leaps. When its throat swells, step aside.")
			else
				table.insert(steps, "The bezoar! Then cross the fen, two-legs. And come back one day to tell me what's below.")
			end
			return steps
		end,
		shop = {
			{ item = "swamp_salve", count = 1, price = 3, currency = "fig" },
			{ item = "nettle_tonic", count = 1, price = 6, currency = "fig" },
			{ item = "herb_tea", count = 1, price = 3, currency = "fig" },
			{ item = "arrows", count = 5, price = 2, currency = "fig" },
			{ item = "bomb", count = 2, price = 3, currency = "fig" },
			{ item = "oilskin_coat", count = 1, price = 14, currency = "fig" },
		},
	},

	unit9 = {
		name = "Unit-9",
		sprite = "unit9",
		talk = function(game): { types.DialogStep }
			local steps: { types.DialogStep } = {}
			if not game.flags.unit9Met then
				game.flags.unit9Met = true
				table.insert(steps, "UNIT-9, CARE AUTOMATON. WELCOME TO THE HOUSE OF HEALING. PLEASE STATE YOUR WATER.")
				table.insert(steps, "...NO WATER? THEN YOU ARE EBB. THE EBB ARE TREATED IN THE QUARANTINE. UNIT-9 IS SORRY.")
				table.insert(steps, "WARNING: THE CHIEF MENDER IS MALFUNCTIONING. IT KEEPS THE SEAL OF THE PHYSICIAN, AND IT MENDS EVERYTHING. EVEN WHAT SHOULD STAY BROKEN.")
			elseif game.player.artefacts.beaked_mask and not game.notebook.lore.quarantine then
				table.insert(steps, "THE QUARANTINE IS BEHIND THE GREEN AIR. NO ONE HAS ENTERED IT SINCE THE TIDE LEFT. UNIT-9 WOULD LIKE TO KNOW WHAT HAPPENED TO THE EBB.")
			end
			table.insert(steps, function(g: types.Game): string?
				g.player.hp = player_rules.maxHp(g.player)
				g.player.poison = 0
				return "Unit-9 treats your wounds. TREATMENT COMPLETE. NEXT PATIENT."
			end)
			return steps
		end,
	},

	wick = {
		name = "Wick",
		sprite = "wick",
		talk = function(game): { types.DialogStep }
			if not game.flags.wickMet then
				game.flags.wickMet = true
				return {
					"*click* Shh! You'll scare the fish. I'm Wick. I fish here, since the frogs ate my last boat.",
					"The ferry of the old ones still sleeps at the docks, past the green air. My grandmother said it came when the bell was rung right. Nobody remembers how.",
					"My uncle Fen was a smuggler. He hid his loot in the walls of the docks, he said. We never found where.",
				}
			end
			if game.player.artefacts.ferry_skiff and not game.flags.wickWaters then
				game.flags.wickWaters = true
				return {
					"You have the ferry! *click click* Then listen: the old waters above hide things.",
					"The lakes of the hollows, the drowned colonnade of the oasis... and the desert ants say their canals are full again. Sail them all.",
				}
			end
			if not game.player.artefacts.ferry_skiff then
				return {
					"The bell of the ferry is at the end of the docks, past the green air. The healers had masks for that air.",
					"My grandmother hummed a slow tune when she spoke of it. Slow, like the breath of the tide. Its stone says the rest, if you can read it.",
				}
			end
			return { "Fish don't bite when the King croaks. And the King croaks a lot." }
		end,
	},

	-- The frontier: the Frostborn of Rimehold, and what the Watch left behind

	--- Elder Hask, in the lodge of Rimehold: the way down, and the lost pup
	hask = {
		name = "Elder Hask",
		sprite = "hask",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local player = game.player
			local steps: { types.DialogStep } = {}
			if not flags.haskMet then
				flags.haskMet = true
				table.insert(steps, "Sit, sit, warm your hands. A traveller from above... We are the Frostborn. Our foremothers were soldiers of the Watch, the soldiers of the Bronze.")
				table.insert(steps, "The Watch kept this frontier for the city below. When the city sealed itself, the High Tide wanted a Watch that never tires, like its servants of bronze. So the Watch was told to sleep in the ice, and dream its watch forever.")
				table.insert(steps, "Some of us woke up. A soldier who wakes falls from his water: the city called us Ebb, like its sick in the marshes, and forgot us. We stayed in the cold, and we never quite stopped dreaming. We see things you don't. Not yet.")
				table.insert(steps, "The way down is past the Old Watch, beyond the Glare. Its gate is at the top of the icefall, and only crampons climb an icefall. The children keep the champion's pair, in the yard. Beat them at their game.")
				table.insert(steps, "And... one more thing. My granddaughter Tamsin went to the ice caves, south of the village, and she did not come back. If you see her, send her home.")
			end
			if flags.tamsinFound and not flags.tamsinThanked then
				table.insert(steps, function(g: types.Game): string?
					g.flags.tamsinThanked = true
					return nil
				end)
				table.insert(steps, "Tamsin is home, frozen to the bone and very proud of herself. You have my thanks, traveller. Take my old cloak: it kept me warm for sixty winters.")
				table.insert(steps, give("fur_cloak"))
				table.insert(steps, xp(60))
				return steps
			end
			if #steps > 0 then
				return steps
			end
			if not flags.tamsinFound then
				table.insert(steps, "Tamsin plays in the ice caves, south of the village, where the old blocks of ice are. Blocks slide until they hit something, she says. She must be stuck behind them.")
			end
			if not player.artefacts.rime_crampons then
				table.insert(steps, "The crampons first. Sleet, in the yard, will tell you the rules. They cheat, you know. Children.")
				return steps
			elseif not flags["killed:last_watchman"] then
				table.insert(steps, "The Watch is still up there, at the Old Watch. The Last Watchman never slept: they say he has become a husk of ice.")
				table.insert(steps, "Ysolde says that only those who dream can touch him. Ysolde says many things. This time, I believe her.")
				return steps
			end
			table.insert(steps, "You have his ember... Then he is relieved, at last. Go down, traveller. The whiteout won't bite you now.")
			return steps
		end,
	},

	--- Sleet, leader of the kids of the yard: the snowball gallery (gallery.luau)
	sleet = {
		name = "Sleet",
		sprite = "sleet",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local steps: { types.DialogStep } = {}
			if not flags.sleetMet then
				flags.sleetMet = true
				table.insert(steps, "Hey, two-legs! This is our yard. Wanna play? Snowballs at the targets: snowmen, pucks on the rink, and the hare if you're quick.")
				table.insert(steps, `{gallery.ROUND_TIME} seconds. Our record is {gallery.GOAL} points. Beat it, and you get the champion's crampons. Lose, and you're a snowman.`)
			elseif flags.galleryWon and not flags.galleryChampion then
				table.insert(steps, `Another go? Sorrel's record is still {gallery.CHAMPION}. She said the pale snowmen count triple. What pale snowmen? Ask her, she's... well. Gone.`)
			elseif flags.galleryChampion then
				table.insert(steps, "Champion! The yard is yours, whenever you want.")
			else
				table.insert(steps, `Ready? {gallery.ROUND_TIME} seconds. Beat {gallery.GOAL}!`)
			end
			table.insert(steps, function(g: types.Game): string?
				gallery.start(g)
				return "Snowballs! Attack to throw. Go!"
			end)
			return steps
		end,
	},

	--- Ysolde the dreamer: what the dream is, and what hides in it
	ysolde = {
		name = "Ysolde",
		sprite = "ysolde",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			if not flags.ysoldeMet then
				flags.ysoldeMet = true
				return {
					"Oh. You are awake. All the way awake. How loud the world must be for you.",
					"The veils, the walls of mist? Frozen dreams. A tired mind walks through them. A bright one bumps its nose.",
					"The healers of the House brewed the sleep of the Watch from hollowcaps. We still eat them, a little, to see. Gaze into the mirrors of the Watch, or eat a hollowcap, and you will dream. The light of a fire wakes you up again, slowly.",
					"In the dream, the Watch still patrols. Pale shades. They are not kind to the waking, and the waking's blades barely touch them.",
				}
			end
			if not flags.ysoldeVeils then
				flags.ysoldeVeils = true
				return {
					"I dreamed of you. You were walking in the gardens above, where the water is warm. There was a veil there too.",
					"Someone dreamed their way up through the floors, long ago, and left veils wherever they hid something: in the gardens of the oasis, in the dry halls, in the marshes... Look for the mist.",
				}
			end
			if not game.player.artefacts.sleepless_eye then
				return { "In the barracks of the Old Watch, a corporal still stands guard. He only speaks to dreamers. He has lost the names of his men." }
			end
			return { "The sleepless eye... Now you dream with your eyes open, like us. Welcome home." }
		end,
		shop = {
			{ item = "hollowcap", count = 2, price = 2, currency = "fig" },
			{ item = "herb_tea", count = 1, price = 3, currency = "fig" },
			{ item = "dirge_bell", count = 1, price = 30, currency = "fig" },
		},
	},

	--- Grizzle, the trader of Rimehold
	grizzle = {
		name = "Grizzle",
		sprite = "grizzle",
		talk = function(game): { types.DialogStep }
			if not game.flags.grizzleMet then
				game.flags.grizzleMet = true
				return {
					"Figs! You have figs? Nothing grows down here but mushrooms and frostbite. I trade anything for figs.",
					"Broth to warm your belly, cloaks for your back, slings for the wolves. The bombs come down from the ants of the dry halls, Clack's cousins. Snow is free.",
				}
			end
			return { "Snow out there, wolves out there, broth in here. Buying?" }
		end,
		shop = {
			{ item = "warm_broth", count = 1, price = 4, currency = "fig" },
			{ item = "fur_cloak", count = 1, price = 18, currency = "fig" },
			{ item = "icicle_sling", count = 1, price = 16, currency = "fig" },
			{ item = "icicle", count = 10, price = 2, currency = "fig" },
			{ item = "bomb", count = 2, price = 3, currency = "fig" },
			{ item = "arrows", count = 5, price = 2, currency = "fig" },
		},
	},

	--- Brann the lamplighter: light every brazier of the frontier
	brann = {
		name = "Brann",
		sprite = "brann",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local lit, total = module.braziers(game)
			if not flags.brannMet then
				flags.brannMet = true
				return {
					"Ho there! Brann, lamplighter of the frontier. Well. I was. My legs don't carry me to the far braziers any more.",
					"The Watch put braziers everywhere: a warm spot in the cold, a light in the dark. Light them for me, would you? Just walk up and light them.",
					`{lit} of {total} lit, by my count. Light them all and I'll give you my hearthstone.`,
				}
			end
			if lit >= total and not flags.brannDone then
				return {
					"I can see them from here, all burning! Like when I was a boy. Here, take my hearthstone: it never goes cold.",
					function(g: types.Game): string?
						g.flags.brannDone = true
						return nil
					end,
					give("hearthstone"),
					xp(50),
				}
			end
			if flags.brannDone then
				return { "All lit. The frontier is warmer for it. Thank you, friend." }
			end
			local dark = module.darkPlaces(game)
			return {
				`{lit} of {total} braziers burning. Keep going!`,
				`From my window I can still see darkness over: {table.concat(dark, ", ")}. There's always one more, somewhere behind the ice.`,
			}
		end,
	},

	--- Tamsin, Elder Hask's granddaughter, stuck in the ice caves (and back home once found)
	tamsin = {
		name = "Tamsin",
		sprite = "tamsin",
		talk = function(game): { types.DialogStep }
			if game.level.id == "rimehold" then
				return { "I'm never going in the caves again. Well. Maybe tomorrow." }
			end
			return {
				"Is someone there? I'm not lost! I'm... exploring. The ice blocks moved, and the way back is gone.",
				"You opened it? You can push the blocks? Wow. Grandpa is going to be so mad. Thank you!",
				function(g: types.Game): string?
					g.flags.tamsinFound = true
					return "Tamsin runs home to Rimehold."
				end,
			}
		end,
	},

	--- Corporal Vey, a phantom of the Watch: only dreamers see him. He lost the names of his men.
	vey = {
		name = "Corporal Vey",
		sprite = "vey",
		dream = true,
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local found = 0
			for _, id in module.WATCH_NAMES do
				if game.notebook.lore[id] then
					found += 1
				end
			end
			if flags.veyDone then
				return { "Orren, Maelis, Tobin, Astra. I say their names every watch. Thank you, dreamer." }
			end
			local steps: { types.DialogStep } = {}
			if not flags.veyMet then
				flags.veyMet = true
				table.insert(steps, "Halt. Who... You can see me? A dreamer. Good. Corporal Vey, fourth squad of the Watch. Still on duty.")
				table.insert(steps, "We slept in the ice, as ordered. Since then I have forgotten the names of my men. Four of them. A corporal should know his men.")
				table.insert(steps, "We carved our names where we stood guard, in the dream. Find them for me. Read them to me.")
			end
			if found >= #module.WATCH_NAMES then
				table.insert(steps, "Orren. Maelis. Tobin. Astra. ...Yes. Yes, that was them. Thank you.")
				table.insert(steps, "Take my eye. I kept it open for a thousand years: with it, you will always see the dream.")
				table.insert(steps, function(g: types.Game): string?
					g.flags.veyDone = true
					return nil
				end)
				table.insert(steps, give("sleepless_eye"))
				table.insert(steps, xp(80))
			elseif flags.veyMet and #steps == 0 then
				local missing = {}
				for i, id in module.WATCH_NAMES do
					if not game.notebook.lore[id] then
						table.insert(missing, module.WATCH_POSTS[i])
					end
				end
				table.insert(steps, `{found} of {#module.WATCH_NAMES} names. Still missing: the ones who stood guard {table.concat(missing, ", ")}. They carved their names in the dream: dream there, and look.`)
			end
			return steps
		end,
	},

	-- MARK: The city of the Tide

	--- Old Mortar, the elder of the Clay of the city, in the Diggings: the way through the city, step by step, and
	--- the two colonies (a token of Queen Tikra)
	mortar = {
		name = "Old Mortar",
		sprite = "mortar",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local player = game.player
			local steps: { types.DialogStep } = {}
			if not flags.mortarMet then
				flags.mortarMet = true
				table.insert(steps, "*click*... A two-legs, down here? You are not bronze. You are not High Tide. You smell of... figs. And snow.")
				table.insert(steps, "I am Mortar, eldest of the Clay of the city. We dug every hall of this city, little one. Now we hide in the holes we dug.")
				table.insert(steps, "When the water fell, the High Tide kept the last of it for itself. The Clay rose, and drank. They burned our archive for it, and their bronze hunted us.")
				table.insert(steps, "Some of us fled up, to the dry halls. They died in the sand, surely. We stayed, under the streets, where the lenses can't see.")
			end
			-- The two colonies
			if inventory.count(player, "queen_token") > 0 and flags.mortarColony ~= "done" then
				table.insert(steps, function(g: types.Game): string?
					inventory.take(g.player, "queen_token", 1)
					g.flags.mortarColony = "done"
					g.flags.tunnelCleared = true
					return "You give Queen Tikra's token to Old Mortar."
				end)
				table.insert(steps, "*click*... *click click*... It is her scent. A queen. The colony of the dry halls lives! And the Warden of the sun is dead?")
				table.insert(steps, "Children! Diggers! Fetch the picks: we clear the tunnel to the harbor tonight. And then... then maybe we go up, to see the sun on the sand.")
				table.insert(steps, "The tunnel is open, little one. The harbor is at its end. Thank you, from all the Clay.")
				table.insert(steps, xp(90))
				return steps
			end
			if flags.queenMet and not flags.mortarColony then
				flags.mortarColony = "started"
				table.insert(steps, "You say... the colony lives? In the dry halls, with a queen, and water? No. No, the sand ate them. You are kind, but ants don't believe tales about queens.")
				table.insert(steps, "Bring me a sign from her, and I will believe. A queen always carries a token with her scent.")
				return steps
			end
			-- Where to go now (detailed directions, every time)
			if not player.artefacts.tide_mark then
				table.insert(steps, "Up there, everything of bronze takes you for Ebb: no token, no name, no water. The lenses cry, the hounds run, the drudges punch.")
				table.insert(steps, "Unit-1 writes the citizens, in the Registry: the hall with the green dome, on the market square. But it only writes those who show a token, and the tokens of the Ebb were all collected.")
				table.insert(steps, "All of them? The collectors struck the doors of the Ebb with chalk. Look for a struck door, on the south street, past the canal. Families hide things. Ours did.")
				if game.notebook.lore.coral_letter ~= nil then
					table.insert(steps, "A toy boat in the basin by the old bridge? Ants don't swim, little one. But you didn't walk all the way here from the green waters of the marshes, did you? You sailed them.")
				end
				table.insert(steps, "And mind the red eyes: they see citizens too. Our scouts cross the canal under it: the grates by the west wall lead into the old ducts.")
			elseif not player.artefacts.salt_grapnel then
				table.insert(steps, "Coral! Ha. A name of the Bronze. The yellow eyes will leave you alone now. Not the red ones, not the hounds, not the bats: they never had a water.")
				table.insert(steps, "The Water Gate opens for you: the harbor of the Salt is beyond, at the bottom of the basin. The Salt kept their hook in their vault, and their vault opens to the light of their lighthouse.")
				table.insert(steps, "The lighthouse has been dark for a thousand years. Nothing burns down here, little one: no oil, no wood, no fire. Unless you brought a flame from up there, a fire that never goes out.")
				if not flags.tunnelCleared then
					table.insert(steps, "There was a tunnel from here to the harbor, but the rocks fell on it, long ago.")
				end
			elseif not flags["open:foundry_pump"] then
				table.insert(steps, "The gardens of the High Tide hang over the harbor, on their terraces: the hook takes you up. Their palace is at the top.")
				table.insert(steps, "Its gate floats on water, they say, in a basin of stone. The water came up a great pipe, from the pump of the Foundry: the Bronze built it, the High Tide used it. When the water stopped, the gate stayed down.")
				table.insert(steps, "The Foundry is behind the citizens' gate, in the south of the Ward. The Foreman still runs it. Badly.")
			elseif not flags["killed:tidemother"] then
				table.insert(steps, "The water runs up to the gardens again! I heard it in the pipes. Go up, little one: the palace, and under it, the Engine.")
				table.insert(steps, "They say the Tidemother is down there, holding the last of the tide. The water still sings, a little, when you put your ear to the floor.")
			else
				table.insert(steps, "Do you hear it? The water sings in the walls again. I never heard it, little one. Not once, in all my life.")
			end
			if flags.mortarColony == "started" then
				table.insert(steps, "And if you meet that queen of yours... bring me her token.")
			end
			return steps
		end,
	},

	--- Unit-1, the first automaton ever built, registrar of the Hall of Waters: it writes the player in (the tide-mark)
	unit1 = {
		name = "Unit-1",
		sprite = "unit1",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local player = game.player
			if not player.artefacts.tide_mark then
				if inventory.count(player, "coral_token") > 0 then
					return {
						"NEXT IN LINE. ...A TOKEN. READING.",
						"CORAL, OF THE BRONZE. AGED SIX. ...THIS NAME IS STRUCK. STRUCK AT THE EIGHTH BELL, ON THE ORDER OF THE HIGH TIDE. ITS TOKEN WAS NEVER COLLECTED.",
						"THE REGISTER HAS NO RULE FOR A STRUCK NAME THAT COMES BACK. UNIT-1 HAS CHECKED. TWICE.",
						"WHAT IS NOT FORBIDDEN IS ALLOWED. WRITTEN: CORAL, OF THE BRONZE, RETURNED. ...YOU HAVE GROWN, CORAL.",
						function(g: types.Game): string?
							inventory.take(g.player, "coral_token", 1)
							g.flags.coral = true
							g.flags["open:ebb_register"] = true
							return nil
						end,
						give("tide_mark"),
						"HOLD UP YOUR MARK TO THE LENSES, CITIZEN. THE YELLOW EYES OF THE BRONZE WILL KNOW YOU. THE RED EYES OF THE HIGH TIDE KNOW NOBODY.",
						"AND THE FIFTH DOOR, THE DOOR OF THE EBB, WILL OPEN FOR YOU. IT OPENS FOR THE EBB. YOU ARE THE ONLY ONE WHO EVER CAME BACK.",
						xp(60),
					}
				end
				if not flags.unit1Met then
					flags.unit1Met = true
					return {
						"...UNIT-1 ONLINE. UNIT-1: FIRST OF THE SERVANTS OF BRONZE. REGISTRAR OF THE WATERS OF THE CITY.",
						"NEXT IN LINE. STATE YOUR NAME. PRESENT YOUR TOKEN.",
						"...NO TOKEN. YOU ARE NOT IN THE REGISTER. WHO IS NOT IN THE REGISTER IS EBB. THE EBB DO NOT EXIST.",
						"TOKENS ARE NEVER LOST, CITIZEN. TOKENS ARE COLLECTED. THE DOORS OF THE EBB WERE STRUCK, THEIR TOKENS TAKEN.",
						"THE REGISTER SAYS: THIRTY THOUSAND TOKENS COLLECTED. THIRTY THOUSAND AND ONE NAMES STRUCK. ...UNIT-1 HAS ALWAYS FOUND THAT UNTIDY.",
					}
				end
				return {
					"PRESENT YOUR TOKEN. NO TOKEN, NO NAME. NO NAME, NO WATER.",
					"...THIRTY THOUSAND AND ONE. UNIT-1 STILL FINDS IT UNTIDY.",
				}
			end
			local steps: { types.DialogStep } = {}
			if not flags.unit1Told then
				flags.unit1Told = true
				table.insert(steps, "THE REGISTER HOLDS FORTY-ONE THOUSAND NAMES. THIRTY THOUSAND ARE STRUCK. STRUCK MEANS EBB.")
				table.insert(steps, "WHEN THE TIDE FELL, THE HIGH TIDE ORDERED UNIT-1 TO STRIKE THE SICK. THEN THE CLAY, WHEN THEY DRANK. THEN THE WATCH THAT WOKE. THEN THE SALT, WHEN THEY SAILED.")
				table.insert(steps, "THEN THE HIGH TIDE BECAME BRONZE, AND STOPPED HAVING NAMES. NOBODY WAS LEFT TO GIVE ORDERS. UNIT-1 WAITED.")
			end
			if flags.unit7 and not flags.unit1Arms then
				flags.unit1Arms = true
				table.insert(steps, "UNIT-7? A GOOD UNIT. ITS ARMS WERE RECALLED FOR THE WORKS OF THE HIGH TIDE. THEY MAY STILL BE IN THE STORES OF THE FOUNDRY.")
			end
			if #steps == 0 then
				table.insert(steps, "NEXT IN LINE. ...THERE IS NOBODY IN LINE, CORAL. THERE HAS BEEN NOBODY IN LINE FOR A THOUSAND YEARS.")
			end
			return steps
		end,
	},

	--- Beacon, the keeper of the lighthouse of the Salt, in the Dry Harbor: the vault of the light, the great lantern
	beacon = {
		name = "Beacon",
		sprite = "beacon",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			local player = game.player
			local steps: { types.DialogStep } = {}
			if not flags.beaconMet then
				flags.beaconMet = true
				table.insert(steps, "BEACON, KEEPER OF THE LIGHT OF THE SALT. ...A VISITOR? NO SHIP HAS COME IN FOR A THOUSAND YEARS. BEACON KEEPS THE LIGHT ANYWAY. IT IS ITS JOB.")
				table.insert(steps, "THE GREAT LANTERN AT THE TOP OF THE TOWER IS OUT. BEACON'S LEGS CANNOT CLIMB THE LADDERS ANY MORE. AND NOTHING BURNS IN THE CITY: NO OIL, NO WOOD, NO FLAME, FOR A THOUSAND YEARS.")
				table.insert(steps, "IF YOU HAVE A FLAME, VISITOR, LIGHT IT, AND BEACON WILL GIVE YOU ITS GYROSCOPE.")
			end
			if flags["open:great_lantern"] and not flags.beaconThanked then
				table.insert(steps, "THE LIGHT! ...BEACON WAITS FOR THE SHIPS. ...NO SHIP COMES. THEY SAILED UP, NOT OUT. BEACON KNOWS. BEACON KEEPS THE LIGHT ANYWAY.")
				table.insert(steps, "TAKE THE GYROSCOPE OF THE SALT. IT NEVER STOPS TURNING. NEITHER WILL YOUR FEET.")
				table.insert(steps, setFlag("beaconThanked", true))
				table.insert(steps, give("salt_gyroscope"))
				table.insert(steps, xp(50))
				return steps
			end
			if flags["killed:tidemother"] then
				table.insert(steps, "THE GATE OF THE TIDE ROAD IS OPEN. BEACON FEELS THE PULL IN ITS BOLTS. GO, IF YOU WANT. THE LIGHT WILL BE ON, FOR YOUR RETURN.")
			elseif not player.artefacts.salt_grapnel then
				table.insert(steps, "THE SALT LOCKED ITS VAULT WITH LIGHT. A CAPTAIN WHO CAN STEER LIGHT CAN STEER A SHIP, THEY SAID.")
				if not flags["open:great_lantern"] then
					table.insert(steps, "THE BEAM OF THE LIGHTHOUSE RUNS ALONG THE QUAY. THE CRYSTAL OF THE VAULT IS BY THE DOOR OF THE GUILD HALL. BUT FIRST, A FLAME.")
				else
					table.insert(steps, "THE MIRROR OF THE CRANE TURNS THE LIGHT DOWN. THE MIRRORS ON CRATES CAN TURN IT ALONG THE ROWS, IF YOU PUSH THEM IN PLACE. THE CRATES IN THE WAY CAN BE PUSHED. THE CARGO CANNOT.")
					table.insert(steps, "AND DO NOT STAND IN THE LIGHT. BEACON HAS SEEN WHAT IT DOES TO DRUDGES.")
				end
			else
				table.insert(steps, "THE HOOK OF THE SALT. ON FEAST DAYS, THE SAILORS HOOKED THE RINGS OF THE TERRACES TO CLIMB TO THE GARDENS. A RING HANGS ON THE LEDGE ACROSS THE VOID, AT THE EAST END OF THE QUAY.")
			end
			if not flags["open:great_lantern"] then
				table.insert(steps, "THE GREAT LANTERN, VISITOR. THE DOOR OF THE TOWER IS OPEN.")
			end
			return steps
		end,
	},

	--- The Gardener, a Tidekeeper who chose to tend the figs of the High Tide: it remembers one thing
	gardener = {
		name = "The Gardener",
		sprite = "gardener",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			if not flags.gardenerMet then
				flags.gardenerMet = true
				return {
					"...THE FIGS MUST BE WATERED. THE FIGS MUST BE WATERED. ...OH. A VISITOR. FORGIVE ME. THE FIGS ARE ALL I REMEMBER.",
					"I WAS ONE OF THE HIGH TIDE, ONCE, I THINK. WE POURED OURSELVES INTO BRONZE, SO AS NEVER TO FALL. MY NAME DID NOT FIT INTO THE BRONZE. IT STAYED OUTSIDE.",
					"THE OTHERS GUARD WHAT WAS THEIRS. I CHOSE THE FIGS. THEY GROW. THEY DO NOT REMEMBER EITHER, AND THEY DON'T MIND.",
					"TAKE SOME. THE CHILD LOVED THEM. THE TIDEMOTHER'S CHILD, WHO SAILED. NERISSA. ...THAT NAME STAYED. STRANGE.",
					give("fig", 6),
				}
			end
			if flags["killed:tidemother"] then
				return { "THE FOUNTAIN SINGS. ...I REMEMBER THE SOUND. I DO NOT REMEMBER MY NAME. THE SOUND IS BETTER." }
			end
			if not flags["open:foundry_pump"] then
				return {
					"THE FIGS MUST BE WATERED. ...THERE IS NO WATER. THERE HAS BEEN NO WATER SINCE THE PUMP STOPPED.",
					"THE GATE OF THE PALACE FLOATS ON THE WATER OF ITS BASIN. NO WATER, NO GATE. THE HIGH TIDE DID NOT MIND: THEY NEVER CAME OUT ANY MORE.",
					"THE WATER CAME UP THE BIG PIPE, FROM THE GREAT PUMP OF THE BRONZE, DOWN IN THEIR FOUNDRY. FOLLOW THE PIPE, VISITOR. PIPES ALWAYS GO SOMEWHERE.",
				}
			end
			if not flags["killed:tidemother"] and not flags.gardenerWater then
				flags.gardenerWater = true
				return {
					"WATER. WATER! THE FIGS DRINK. ...THE GATE HAS RISEN. THE PALACE IS OPEN, FOR THE FIRST TIME SINCE THE CHILD LEFT.",
					"TAKE THESE. FOR THE WATER.",
					give("fig", 8),
					give("energy_core", 1),
				}
			end
			return { "THE FIGS MUST BE WATERED. ...THE PALACE? SHE IS NOT IN THE PALACE. SHE IS BELOW. SHE IS ALWAYS BELOW, HOLDING ON." }
		end,
	},

	--- Grit, the trader of the Diggings
	grit = {
		name = "Grit",
		sprite = "grit",
		talk = function(game): { types.DialogStep }
			if not game.flags.gritMet then
				game.flags.gritMet = true
				return {
					"*click* A customer! Up there, the bronze sells for figs. Down here, Grit sells for figs too. Grit is modern.",
					"Salves against the plates, smoke against the lenses, quick-metal for the legs. Grit picked them all in the city, at night. Don't tell Mortar.",
				}
			end
			return { "*click* Smoke for the lenses, salve for the plates. Figs, please." }
		end,
		shop = {
			{ item = "amber_salve", count = 1, price = 4, currency = "fig" },
			{ item = "smoke_vial", count = 1, price = 5, currency = "fig" },
			{ item = "quicksilver", count = 1, price = 4, currency = "fig" },
			{ item = "salt_fury", count = 1, price = 5, currency = "fig" },
			{ item = "salt_hardtack", count = 2, price = 3, currency = "fig" },
			{ item = "bomb", count = 2, price = 3, currency = "fig" },
			{ item = "voltaic_charge", count = 10, price = 3, currency = "fig" },
			{ item = "storm_coil", count = 1, price = 30, currency = "fig" },
		},
	},

	ant_child = {
		name = "Pebble",
		sprite = "ant_child",
		talk = function(game): { types.DialogStep }
			if game.flags.tunnelCleared then
				return { "We're going to see a QUEEN! A real one! Grit says she's ten times bigger than Mortar. Mortar says that's rude." }
			end
			return { "Are you a Tidekeeper? No, you're too short. And you're not shiny. Mortar says the shiny ones are the worst." }
		end,
	},

	ant_child2 = {
		name = "Chip",
		sprite = "ant_child",
		talk = function(game): { types.DialogStep }
			return { "Mortar says the hounds sniff for water. Grit says they sniff for figs. I think they sniff for children. *click*" }
		end,
	},

	--- Tally, a merchant automaton of the market of the Bronze Ward: only trades with citizens (the tide-mark)
	tally = {
		name = "Tally",
		sprite = "tally",
		talk = function(game): { types.DialogStep }
			local flags = game.flags
			if not game.player.artefacts.tide_mark then
				if not flags.tallyMet then
					flags.tallyMet = true
					return {
						"TALLY, MERCHANT OF THE WARD. ALL WATERS ARE WELCOME AT THIS STALL.",
						"...SCANNING. NO TOKEN. YOU ARE EBB. THE EBB DO NOT TRADE. THE EBB DO NOT EXIST. GOOD DAY.",
					}
				end
				return {
					"THE EBB DO NOT TRADE. UNIT-1 WRITES THE CITIZENS, IN THE REGISTRY, UNDER THE GREEN DOME. COME BACK WITH A NAME.",
				}
			end
			if not flags.tallyCitizen then
				flags.tallyCitizen = true
				return {
					"TIDE-MARK DETECTED: CORAL, OF THE BRONZE. WELCOME, CITIZEN! TALLY APOLOGIZES FOR ANY EARLIER RUDENESS. TALLY WAS NOT RUDE.",
					"SINCE THE DROUGHT, FIGS ARE ACCEPTED AS CURRENCY. THE HIGH TIDE APPROVED IT. RECENTLY. A THOUSAND YEARS AGO.",
				}
			end
			return { "BUYING? SELLING? TALLY ONLY SELLS. FIGS, PLEASE." }
		end,
		trades = function(game)
			return game.player.artefacts.tide_mark == true
		end,
		shop = {
			{ item = "voltaic_charge", count = 12, price = 3, currency = "fig" },
			{ item = "quicksilver", count = 1, price = 5, currency = "fig" },
			{ item = "amber_salve", count = 1, price = 5, currency = "fig" },
			{ item = "iron_draught", count = 1, price = 5, currency = "fig" },
			{ item = "arc_pistol", count = 1, price = 28, currency = "fig" },
			{ item = "copper_scale", count = 1, price = 32, currency = "fig" },
			{ item = "amber_ring", count = 1, price = 22, currency = "fig" },
		},
	},
} :: { [string]: Npc }

return module
