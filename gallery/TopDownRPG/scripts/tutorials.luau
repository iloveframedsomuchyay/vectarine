--[[
The first steps: short narrations (like the opening of the game) that teach the basics the first time they matter.

- The first weapon picked up (the rusty knife of the sinkhole): how to equip it from the bag of the notebook.
- The first creature met (the cave rats of the sinkhole): how to fight, health, healing, fainting.
- The first creature defeated: the bestiary of the notebook, where the explorer writes down what they meet.
- The first level gained: how to spend the point on a stat, on the first page of the notebook.
- The pitch black of a lightless place (the Dark Hollow, see lighting.luau): the explorer can go on blind, but feels
  it is madness.

Each one is told once: a flag of the game remembers it (saved with the game).
]]
const dream = require("./dream")
const items = require("./data/items")
const level = require("./level")
const lighting = require("./lighting")
const loader = require("@vectarine/loader")
const monsters = require("./data/monsters")
const prompts = require("./prompts")
const types = require("./types")

const module = loader.init() or {}

--- How close the first creature must be for the combat narration
const CREATURE_DISTANCE = 4.5

--- Narrations told at the same moment (the first creature defeated is often the first level gained) follow each other
--- in one dialog
local function narrate(game: types.Game, steps: { types.DialogStep })
	local last = game.events[#game.events]
	if last and last.kind == "dialog" and last.speaker == nil and last.narration then
		for _, step in steps do
			table.insert(last.steps, step)
		end
		return
	end
	game.events[#game.events + 1] = { kind = "dialog", speaker = nil, steps = steps, narration = true }
end

--- An item went into the bag (picked up, or found in a chest)
function module.onPickup(game: types.Game, itemId: string)
	local item = items.items[itemId]
	if item.kind ~= "weapon" or item.bomb or game.flags.tutorialWeapon then
		return
	end
	game.flags.tutorialWeapon = true
	local notebook = prompts.keyName(prompts.NOTEBOOK_KEY)
	narrate(game, {
		`A {string.lower(item.name)}. Better than bare fists.`,
		`Open your notebook with [{notebook}]: your bag is on its first page.`,
		"Select the weapon with the arrows, and press [Space] to equip it. Then [Space] strikes in front of you.",
	})
end

--- The first creature that comes close: how to fight, and how to stay alive. Called every frame.
function module.checkCreatures(game: types.Game)
	if game.flags.tutorialCombat then
		return
	end
	local player = game.player
	for _, monster in game.monsters do
		local species = monsters.species[monster.kind]
		local close = (monster.pos - player.pos):length() < CREATURE_DISTANCE
		if close and not monster.dead and not species.hazard and not species.prize and dream.isPresent(game, monster)
			and level.lineIsClear(game.level :: any, monster.pos, player.pos) then
			game.flags.tutorialCombat = true
			local notebook = prompts.keyName(prompts.NOTEBOOK_KEY)
			narrate(game, {
				`Something moves in the dark... a {string.lower(species.name)}. And it has seen you.`,
				"Face it and press [Space] to strike. Creatures warn before they attack: a rat crouches, then pounces. Step aside, then hit back.",
				"Your health is the red bar at the top. It comes back slowly when nothing hurts you, and all at once when you rest by a campfire.",
				`Figs and bandages heal you: use them from the bag of your notebook [{notebook}].`,
				"If you faint, you wake up by the last fire you rested at, with everything you carry.",
			})
			return
		end
	end
end

--- A creature was defeated: the first time, the explorer starts the bestiary of their notebook
function module.onKill(game: types.Game, kind: string)
	local species = monsters.species[kind]
	if game.flags.tutorialBestiary or species.hazard or species.prize or species.boss then
		return
	end
	game.flags.tutorialBestiary = true
	local notebook = prompts.keyName(prompts.NOTEBOOK_KEY)
	local page = prompts.keyName(prompts.PAGE_KEY)
	narrate(game, {
		`The {string.lower(species.name)} drops, and doesn't get up. You catch your breath.`,
		"\"...Nobody up there will ever believe this. I need to take notes of everything I discover down here.\"",
		`Your notebook [{notebook}] keeps a bestiary: turn its pages with [{page}] to the Creatures. Every creature you meet goes in it, with its weaknesses, its strengths, and how many you have defeated.`,
	})
end

--- The player gained a level: the first time, how to spend the point
function module.onLevelUp(game: types.Game)
	if game.flags.tutorialLevelUp then
		return
	end
	game.flags.tutorialLevelUp = true
	local notebook = prompts.keyName(prompts.NOTEBOOK_KEY)
	narrate(game, {
		"You feel it in your legs, your arms, your head: this place is making you tougher. Every fight teaches you something.",
		`Each new level gives you a point to spend. Open your notebook [{notebook}]: your abilities are on the left of the first page.`,
		"Select one with the arrows and press [Space] to raise it: Health, Sanity, Strength, Agility or Intelligence. Choose well, points don't come back.",
	})
end

--- The pitch black of a lightless place, without the eternal lantern: the first time, the explorer feels how bad an
--- idea it is. Nothing stops them from going on blind (the creatures of the Hollow see in the dark).
--- Called every frame, after the lighting is updated.
function module.checkDarkness(game: types.Game)
	if game.flags.tutorialDark or lighting.blackout(game) < 0.9 then
		return
	end
	game.flags.tutorialDark = true
	narrate(game, {
		"Black. Not dark: black. Your flashlight shows nothing at all, as if the darkness drank its light.",
		"Somewhere ahead, pebbles roll... and fall for a long time before they hit anything. Something squeaks, close.",
		"Going on blind would be madness. Wren has lived here forty years: he might know a way.",
	})
end

return module
