--[[
Ducts under the floor of the city: a `vent` (a grate on the floor) leads into them, the `ducts` rows of the level say
where they go (see data/levels.luau).

[E] on a vent: the player crawls in. In the ducts, they only move along the duct cells, nothing sees them (creatures,
lenses), nothing reaches them (beams, plates, shots), and they can't attack. The level above is drawn dimmed, so the
player sees the hall they crawl under before they have to cross it. [E] on any vent along the way gets them out.
]]
const effects = require("./effects")
const level = require("./level")
const loader = require("@vectarine/loader")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

module.state = module.state or { levelId = "", active = false }

local function center(cell: vec.Vec2): vec.Vec2
	return cell + vec.V2(0.5, 0.6)
end

--- Is the player crawling in the ducts of the level right now?
function module.isActive(game: types.Game): boolean
	return module.state.active and module.state.levelId == game.level.id
end

--- [E] on a vent: in or out
function module.use(game: types.Game, prop: types.Prop)
	local state = module.state
	local player = game.player
	if module.isActive(game) then
		state.active = false
		player.pos = center(prop.cell)
		player.height = level.heightAt(game.level :: level.Level, prop.cell.x, prop.cell.y)
		effects.burst(player.pos, "dust", 8)
		return
	end
	local lvl = game.level :: level.Level
	if not lvl.ducts[1 + prop.cell.x + prop.cell.y * lvl.width] then
		game.events[#game.events + 1] = { kind = "message", text = "The grate is rusted shut." }
		return
	end
	state.active = true
	state.levelId = game.level.id
	player.pos = center(prop.cell)
	player.velocity = vec.V2(0, 0)
	player.knockback = vec.V2(0, 0)
	effects.burst(player.pos, "dust", 8)
	if not game.flags.taughtDucts then
		game.flags.taughtDucts = true
		game.events[#game.events + 1] = {
			kind = "message",
			text = "You squeeze through the grate into a duct. Down here, nothing sees you. [E] at another grate to climb out.",
		}
	end
end

--- Leaving the level (or fainting) puts the player back on their feet
function module.reset()
	module.state.active = false
end

return module
