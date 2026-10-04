--[[
Beams of light of the city: emitters, mirrors and crystals.

- An emitter (`emitter`, `data.dir`: "up", "down", "left" or "right") shoots a beam in a straight line, until it meets a
  wall or something solid (a crate, a column, a closed shutter, the player doesn't stop it). An emitter with a
  `data.breaker` is dark while that breaker is thrown (see power.luau), one with `data.needs` is dark until that switch
  is open (a lever, see switches.luau).
- A mirror (`mirror` props: a fixed mirror, or a mirror on a crate that can be pushed) turns the beam by a quarter:
  "/" or "\" (`data.slope`, "/" by default). [E] turns a mirror the other way. Mirrors go back to how they were when the
  player comes back, like the blocks.
- A prism (`splitter`) lets the beam through, and turns a part of it like a mirror would: one lamp, two beams.
- A crystal (`crystal`, `data.opens`) lights up when a beam hits it. When every crystal with the same `data.opens` is
  lit at the same time, what they open opens, for good (see switches.luau).

Beams burn the player (fire), and the automatons that walk into them are cut down fast.
Beams travel above the floor: chasms and water don't stop them, heights don't matter.
]]
const combat = require("./combat")
const effects = require("./effects")
const level = require("./level")
const loader = require("@vectarine/loader")
const monsters = require("./data/monsters")
const player_rules = require("./player")
const props = require("./data/props")
const switches = require("./switches")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

module.DIRS = {
	up = vec.V2(0, -1),
	down = vec.V2(0, 1),
	left = vec.V2(-1, 0),
	right = vec.V2(1, 0),
} :: { [string]: vec.Vec2 }

const BURN = 16
const AUTOMATON_BURN = 90
const CREATURE_BURN = 14
const BURN_EVERY = 0.4
const MAX_LENGTH = 80
--- How many times a beam can be split by prisms
const MAX_SPLITS = 4

export type Trace = {
	--- The points of the beam: the emitter, each mirror, and where it stops
	points: { vec.Vec2 },
	--- Cells the beam goes through, by "x,y"
	cells: { [string]: boolean },
	--- The crystal it lights, if any
	crystal: types.Prop?,
}

module.state = module.state or {
	levelId = "",
	--- The slope of each mirror ("/" or "\"), by prop key
	slopes = {} :: { [string]: string },
	traces = {} :: { Trace },
	--- Crystals lit this frame, by prop key
	lit = {} :: { [string]: boolean },
}

local function reset(game: types.Game)
	local state = module.state
	state.levelId = game.level.id
	state.slopes = {}
	state.traces = {}
	state.lit = {}
end

function module.slope(prop: types.Prop): string
	return module.state.slopes[prop.key] or prop.data.slope or "/"
end

--- [E] on a mirror: it turns the other way
function module.turn(game: types.Game, prop: types.Prop)
	module.state.slopes[prop.key] = if module.slope(prop) == "/" then "\\" else "/"
	effects.burst(prop.cell + vec.V2(0.5, 0.4), "sparkle", 4)
end

local function reflect(dir: vec.Vec2, slope: string): vec.Vec2
	if slope == "/" then
		return vec.V2(-dir.y, -dir.x)
	end
	return vec.V2(dir.y, dir.x)
end

local function center(cell: vec.Vec2): vec.Vec2
	return cell + vec.V2(0.5, 0.5)
end

--- Follow a beam from a cell, towards `dir`. A splitter starts a new beam (in `out`), up to a few times.
local function traceFrom(game: types.Game, start: vec.Vec2, dir: vec.Vec2, out: { Trace }, depth: number)
	local lvl = game.level :: level.Level
	local cell = start
	local result: Trace = { points = { center(cell) }, cells = {}, crystal = nil }
	table.insert(out, result)
	for _ = 1, MAX_LENGTH do
		local next = cell + dir
		if not level.inside(lvl, next.x, next.y) then
			table.insert(result.points, center(cell) + dir:scale(0.5))
			break
		end
		local wall = level.wallAt(lvl, next.x, next.y)
		if wall and not wall.walkable then
			table.insert(result.points, center(cell) + dir:scale(0.5))
			break
		end
		cell = next
		result.cells[`{cell.x},{cell.y}`] = true
		local prop = level.propAt(lvl, cell.x, cell.y)
		local kind = if prop then props.kinds[prop.kind] else nil
		if prop and kind and kind.split then
			-- A prism: the beam goes on, and a part of it turns like on a mirror
			if depth < MAX_SPLITS then
				traceFrom(game, cell, reflect(dir, module.slope(prop)), out, depth + 1)
			end
		elseif prop and kind and kind.mirror then
			table.insert(result.points, center(cell))
			dir = reflect(dir, module.slope(prop))
		elseif prop and prop.kind == "crystal" then
			table.insert(result.points, center(cell))
			result.crystal = prop
			break
		elseif prop and kind and kind.solid and not kind.flat and not game.flags[`broken:{prop.key}`] then
			table.insert(result.points, center(cell) - dir:scale(0.45))
			break
		end
	end
	if #result.points == 1 then
		table.insert(result.points, center(cell))
	end
end

--- Is this emitter shining, or this crystal lit?
function module.isLit(game: types.Game, prop: types.Prop): boolean
	if prop.kind == "emitter" then
		local cut = prop.data.breaker ~= nil and game.flags[`off:{prop.data.breaker}`] == true
		local waiting = prop.data.needs ~= nil and not switches.isOpen(game, prop.data.needs)
		return not cut and not waiting
	end
	return module.state.lit[prop.key] == true or (prop.data.opens ~= nil and switches.isOpen(game, prop.data.opens))
end

--- Is a cell crossed by a beam right now?
function module.onBeam(cell: vec.Vec2): boolean
	local key = `{cell.x},{cell.y}`
	for _, t in module.state.traces do
		if t.cells[key] then
			return true
		end
	end
	return false
end

--- Called every frame: follow the beams, light the crystals, burn what stands in the way. `exposed` is false while the
--- player is out of reach (crawling in a duct).
function module.update(game: types.Game, dt: number, exposed: boolean)
	local state = module.state
	if state.levelId ~= game.level.id then
		reset(game)
	end
	state.traces = {}
	state.lit = {}
	local emitters = false
	for _, prop in game.level.props do
		if prop.kind == "emitter" and module.isLit(game, prop) then
			emitters = true
			local out: { Trace } = {}
			traceFrom(game, prop.cell, module.DIRS[prop.data.dir or "right"], out, 0)
			for _, t in out do
				table.insert(state.traces, t)
				if t.crystal then
					state.lit[t.crystal.key] = true
				end
			end
		end
	end
	if not emitters then
		return
	end

	-- Crystals: when every crystal of a group is lit, what they open opens
	local groups: { [string]: boolean } = {}
	for _, prop in game.level.props do
		if prop.kind == "crystal" and prop.data.opens then
			local id = prop.data.opens :: string
			groups[id] = (groups[id] == nil or groups[id] == true) and state.lit[prop.key] == true
		end
	end
	for id, lit in groups do
		if lit and switches.open(game, id) then
			game.events[#game.events + 1] = {
				kind = "message",
				text = "The crystal blazes with light. Somewhere in the walls, a lock clicks open.",
			}
		end
	end

	local player = game.player
	if exposed and module.onBeam(level.cellOf(player.pos)) and player.invincible <= 0 then
		player_rules.hurt(game, BURN, "fire", nil, nil)
		effects.burst(player.pos + vec.V2(0, -0.4), "spark", 8)
		if not game.flags.taughtBeam then
			game.flags.taughtBeam = true
			game.events[#game.events + 1] = { kind = "message", text = "The beam burns! Crates and mirrors stop it, and the bronze servants don't survive it." }
		end
	end
	for _, monster in game.monsters do
		local species = monsters.species[monster.kind]
		if not monster.dead and not species.hazard and not species.boss and module.onBeam(level.cellOf(monster.pos)) then
			local mon = monster :: any
			mon.burnTime = math.max(0, (mon.burnTime or 0) - dt)
			if mon.burnTime <= 0 then
				mon.burnTime = BURN_EVERY
				effects.burst(monster.pos + vec.V2(0, -0.4), "spark", 8)
				combat.hurtMonster(game, monster, if species.automaton then AUTOMATON_BURN else CREATURE_BURN, "fire", monster.pos + vec.V2(0, 0.01))
			end
		end
	end
end

return module
