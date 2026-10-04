--[[
The lenses of the city: bronze eyes on poles that sweep a cone of light over the floor, and lock the place down when
they see the player.

A lens (`lens` prop) looks towards `data.dir` ("down", "left"... or `data.angle` in degrees, 0 = right, 90 = down) and
sweeps `data.sweep` degrees around it (90 by default; 0 for a lens that stares), as far as `data.range` tiles (6). Walls,
buildings and solid things (crates, columns, the shutters) hide whoever is behind them. A player who stays in the cone
for SEE_TIME seconds (the eye turns orange first) starts a lockdown of the lens's `data.group`:
- the eye turns red, and so do the other lenses of the group
- the shutters of the group (`shutter` props) slam shut: the way is sealed
- the hatches of the group (`hatch` props) let out their squad (`data.spawn`, `data.count`): they hunt the player
- the lockdown lasts until the whole squad is down (or the player leaves the place, or faints): it is a real fight.
  The squad gives no experience (lockdowns are not a way to grow stronger).
A crate pushed onto a hatch keeps it shut: its squad stays inside. Nobody says so.
The yellow lenses of the lower city ignore a player who carries the tide-mark; the crimson ones of the High Tide
(`data.crimson`) never do. Crawling in a duct, or a smoke vial (the `hidden` buff), hides the player from every lens.
]]
const effects = require("./effects")
const level = require("./level")
const loader = require("@vectarine/loader")
const monsters = require("./data/monsters")
const player_rules = require("./player")
const props = require("./data/props")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

module.SEE_TIME = 0.55
--- Half of the angle of the cone, in radians
module.HALF_CONE = math.rad(24)
const DEFAULT_RANGE = 6
--- How fast a lens sweeps, at most (radians per second): a wide sweep takes longer, so that its cone stays on whoever
--- it passes long enough to see them (SEE_TIME)
const SWEEP_SPEED = math.rad(36)

const DIR_ANGLES: { [string]: number } = { right = 0, down = 90, left = 180, up = 270 }

export type LensState = { seen: number }

module.state = module.state or {
	levelId = "",
	lenses = {} :: { [string]: LensState },
	--- The groups in lockdown: true while their squad is up
	alarms = {} :: { [string]: boolean },
}

local function reset(game: types.Game)
	module.state.levelId = game.level.id
	module.state.lenses = {}
	module.state.alarms = {}
end

--- Where the lens looks from (its eye, on top of its pole)
function module.eye(prop: types.Prop): vec.Vec2
	return prop.cell + vec.V2(0.5, 0.55)
end

--- The angle the lens looks at right now, in radians
function module.angle(game: types.Game, prop: types.Prop): number
	local base = math.rad(prop.data.angle or DIR_ANGLES[prop.data.dir or "down"] or 90)
	local sweep = math.rad(prop.data.sweep or 90)
	if sweep <= 0 then
		return base
	end
	local phase = (prop.cell.x * 1.7 + prop.cell.y * 0.9)
	-- sin moves at most at 1 per second: scaled so that the cone never moves faster than SWEEP_SPEED
	local rate = math.min(1.2, SWEEP_SPEED / (sweep / 2))
	return base + math.sin(game.time * rate + phase) * sweep / 2
end

function module.range(prop: types.Prop): number
	return prop.data.range or DEFAULT_RANGE
end

function module.isAlarmed(group: string?): boolean
	return group ~= nil and module.state.alarms[group] == true
end

--- How far the sight of a lens goes along a direction, before a wall or something solid stops it
function module.sightLength(game: types.Game, from: vec.Vec2, angle: number, range: number, ignore: types.Prop?): number
	local lvl = game.level :: level.Level
	local dir = vec.fromAngle(angle, 1)
	local d = 0.3
	while d < range do
		local p = from + dir:scale(d)
		local x, y = math.floor(p.x), math.floor(p.y)
		local wall = level.wallAt(lvl, x, y)
		if not level.inside(lvl, x, y) or (wall and not wall.walkable) then
			return d
		end
		local prop = level.propAt(lvl, x, y)
		if prop and prop ~= ignore and not game.flags[`broken:{prop.key}`] then
			local kind = props.kinds[prop.kind]
			if kind.solid and not kind.flat then
				return d
			end
		end
		d += 0.2
	end
	return range
end

--- Does this lens ignore the player? (the tide-mark for the yellow lenses, the ducts, a smoke vial)
function module.ignores(game: types.Game, prop: types.Prop, hidden: boolean): boolean
	local player = game.player
	return hidden or player.hp <= 0 or player_rules.hasBuff(player, "hidden")
		or (player.artefacts.tide_mark == true and not prop.data.crimson)
end

--- Does the lens see the player right now?
function module.sees(game: types.Game, prop: types.Prop): boolean
	local eye = module.eye(prop)
	local target = game.player.pos + vec.V2(0, -0.2)
	local delta = target - eye
	local distance = delta:length()
	local range = module.range(prop)
	if distance > range or distance < 0.01 then
		return false
	end
	local difference = math.abs(((delta:angle() - module.angle(game, prop)) + math.pi) % (2 * math.pi) - math.pi)
	if difference > module.HALF_CONE then
		return false
	end
	return module.sightLength(game, eye, delta:angle(), distance, prop) >= distance - 0.05
end

local function summon(game: types.Game, hatch: types.Prop, group: string)
	local kind = hatch.data.spawn or "alarm_drone"
	for i = 1, hatch.data.count or 2 do
		local pos = hatch.cell + vec.V2(0.5 + (i - 1.5) * 0.4, 0.6)
		local monster: types.Monster = {
			id = game.nextMonsterId,
			kind = kind,
			pos = pos,
			height = level.heightAt(game.level :: level.Level, hatch.cell.x, hatch.cell.y),
			spawn = pos,
			hp = monsters.species[kind].hp,
			state = "idle",
			stateTime = 0,
			facing = "down",
			cooldown = 0.5,
			hitTime = 10,
			knockback = vec.V2(0, 0),
			phase = 1,
			dead = false,
		};
		(monster :: any).alarm = group
		table.insert(game.monsters, monster)
		game.nextMonsterId += 1
		effects.burst(pos, "spark", 10)
	end
end

--- Is a hatch covered (a crate pushed onto it)? Its squad can't get out.
local function covered(game: types.Game, hatch: types.Prop): boolean
	for _, prop in game.level.props do
		if prop ~= hatch and prop.cell.x == hatch.cell.x and prop.cell.y == hatch.cell.y and props.kinds[prop.kind].solid
			and not game.flags[`broken:{prop.key}`] then
			return true
		end
	end
	return false
end

local function raise(game: types.Game, group: string, lens: types.Prop)
	local state = module.state
	if module.isAlarmed(group) then
		return
	end
	state.alarms[group] = true
	effects.shake(0.3)
	effects.burst(module.eye(lens), "spark", 16)
	effects.floatText(module.eye(lens) + vec.V2(0, -1), "!", nil)
	for _, prop in game.level.props do
		if prop.kind == "hatch" and prop.data.group == group and not covered(game, prop) then
			summon(game, prop, group)
		end
	end
	local text = if game.flags.taughtAlarm
		then "LOCKDOWN. The lens shrieks, the shutters slam shut."
		else "The lens shrieks: it saw you! LOCKDOWN: the shutters slam shut, and a squad comes out of the walls. It won't end until they are down."
	game.flags.taughtAlarm = true
	game.events[#game.events + 1] = { kind = "message", text = text }
end

--- Is the squad of a lockdown still up?
local function squadUp(game: types.Game, group: string): boolean
	for _, monster in game.monsters do
		if (monster :: any).alarm == group and not monster.dead then
			return true
		end
	end
	return false
end

--- Called every frame. `hidden` is true while the player can't be seen at all (in a duct).
function module.update(game: types.Game, dt: number, hidden: boolean)
	local state = module.state
	if state.levelId ~= game.level.id then
		reset(game)
	end
	-- A lockdown ends when its squad is down (or when nothing came out: every hatch was covered)
	for group in state.alarms do
		if not squadUp(game, group) then
			state.alarms[group] = nil
			game.events[#game.events + 1] = { kind = "message", text = "The lockdown is over. The shutters grind open." }
		end
	end
	local player = game.player
	local playerCell = level.cellOf(player.pos)
	for _, prop in game.level.props do
		if prop.kind == "lens" then
			local lens = state.lenses[prop.key] or { seen = 0 }
			state.lenses[prop.key] = lens
			if not module.ignores(game, prop, hidden) and module.sees(game, prop) then
				lens.seen += dt
				if lens.seen >= module.SEE_TIME then
					raise(game, prop.data.group or prop.key, prop)
				end
			else
				lens.seen = math.max(0, lens.seen - dt)
			end
		elseif prop.kind == "shutter" or prop.kind == "shutter_open" then
			-- Shutters close during the alarm of their group (never on top of the player)
			local closed = module.isAlarmed(prop.data.group)
			local under = playerCell.x == prop.cell.x and playerCell.y == prop.cell.y
			local wanted = if closed and not under then "shutter" elseif not closed then "shutter_open" else prop.kind
			if wanted ~= prop.kind then
				prop.kind = wanted
				effects.burst(prop.cell + vec.V2(0.5, 0.5), "debris", 6)
				effects.shake(0.1)
			end
		end
	end
end

--- How close a lens is to seeing the player, from 0 to 1 (its warning, drawn over it)
function module.warning(prop: types.Prop): number
	local lens = module.state.lenses[prop.key]
	return if lens then math.clamp(lens.seen / module.SEE_TIME, 0, 1) else 0
end

--- How alarmed a lens looks: "calm", "seeing" (orange: it is about to see the player) or "alarm" (red)
function module.mood(prop: types.Prop): string
	if module.isAlarmed(prop.data.group or prop.key) then
		return "alarm"
	end
	local lens = module.state.lenses[prop.key]
	return if lens and lens.seen > 0.05 then "seeing" else "calm"
end

return module
