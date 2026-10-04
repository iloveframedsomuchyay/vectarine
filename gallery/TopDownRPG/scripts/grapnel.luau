--[[
The grapnel of the Salt (an artefact): facing a mooring ring (`mooring_ring` prop) across a chasm or water, in a straight
line, [E] throws the hook and pulls the player across, onto the ground beyond the ring (rings stand at the edge of the
far side, on a post).

The rope reaches RANGE cells. Walls and solid things in between stop it; chasms, water, and anything low don't. A ring
with no ground beyond it (the ring the player just came from, behind them) is passed over.
]]
const effects = require("./effects")
const level = require("./level")
const loader = require("@vectarine/loader")
const props = require("./data/props")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

module.RANGE = 8
const SPEED = 14

export type Pull = { from: vec.Vec2, to: vec.Vec2, ring: vec.Vec2, t: number, duration: number, levelId: string }

module.state = module.state or { pull = nil :: Pull? }

--- The ring the player could hook right now (in the direction they face), and where they would land
function module.target(game: types.Game, direction: vec.Vec2): (types.Prop?, vec.Vec2?)
	local lvl = game.level :: level.Level
	local cell = level.cellOf(game.player.pos)
	for distance = 2, module.RANGE do
		local at = cell + direction:scale(distance)
		if not level.inside(lvl, at.x, at.y) then
			return nil, nil
		end
		local prop = level.propAt(lvl, at.x, at.y)
		if prop and prop.kind == "mooring_ring" then
			-- The ground beyond the ring
			local landing = at + direction
			local mover: level.Mover = { height = level.heightAt(lvl, landing.x, landing.y) }
			if level.isFree(lvl, landing.x, landing.y, mover) then
				return prop, landing
			end
		else
			local wall = level.wallAt(lvl, at.x, at.y)
			if wall and not wall.walkable then
				return nil, nil
			end
			if prop and props.kinds[prop.kind].solid and not props.kinds[prop.kind].flat then
				return nil, nil
			end
		end
	end
	return nil, nil
end

function module.throw(game: types.Game, ring: types.Prop, landing: vec.Vec2)
	local from = game.player.pos
	local to = landing + vec.V2(0.5, 0.6)
	module.state.pull = {
		from = from,
		to = to,
		ring = ring.cell + vec.V2(0.5, 0.3),
		t = 0,
		duration = (to - from):length() / SPEED + 0.15,
		levelId = game.level.id,
	}
	effects.burst(ring.cell + vec.V2(0.5, 0.3), "sparkle", 8)
end

--- Is the player flying on the rope right now?
function module.isPulling(game: types.Game): boolean
	local pull = module.state.pull
	return pull ~= nil and pull.levelId == game.level.id
end

--- Move the player along the rope. Returns true while they are on it.
function module.update(game: types.Game, dt: number): boolean
	local pull = module.state.pull
	if not pull then
		return false
	end
	if pull.levelId ~= game.level.id then
		module.state.pull = nil
		return false
	end
	pull.t += dt
	-- A short moment to throw the hook, then the rope pulls
	local t = math.clamp((pull.t - 0.15) / (pull.duration - 0.15), 0, 1)
	local player = game.player
	player.pos = pull.from:lerp(pull.to, t * t * (3 - 2 * t))
	player.velocity = vec.V2(0, 0)
	player.knockback = vec.V2(0, 0)
	if pull.t >= pull.duration then
		module.state.pull = nil
		local cell = level.cellOf(player.pos)
		player.height = level.heightAt(game.level :: level.Level, cell.x, cell.y)
		effects.burst(player.pos, "dust", 8)
		return false
	end
	return true
end

return module
