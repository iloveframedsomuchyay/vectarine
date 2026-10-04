--[[
Electrified floors of the city: copper plates (terrains with `plate`) wired to a circuit.

A level lists its circuits in `power` (see data/levels.luau): an area of cells (x1, y1, x2, y2, included) where the
copper plates are wired, and how they are fed:
- `mode = "steady"`: always live
- `mode = "pulse"`: live for `on` seconds every `period` seconds (shifted by `offset`). They crackle for WARNING seconds
  before they spark, so that the player can time the crossing.
A circuit with a `breaker` id is cut when the flag "off:<id>" is set: a breaker (a lever, see interactions.luau) throws
it, and it stays thrown. Plates outside of every circuit are dead copper.

A live plate shocks whoever stands on it, and it really hurts: lightning worth a large part of the player's health, a
stun, and the jolt throws them back to where they last stood off the live copper. Creatures get shocked too (not the
ones flying): luring them over the plates is a good trick. The amber salve keeps the lightning out (no stun, no jolt),
the amber ring softens it (see player.luau).
]]
const combat = require("./combat")
const effects = require("./effects")
const level = require("./level")
const loader = require("@vectarine/loader")
const monsters = require("./data/monsters")
const player_rules = require("./player")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

export type Circuit = {
	area: { number },
	mode: string,
	period: number?,
	on: number?,
	offset: number?,
	breaker: string?,
	--- The circuit is dead until this switch is open (the plates of the heart wake with the Tidemother)
	needs: string?,
}

--- Seconds of crackling before a pulsing plate sparks
module.WARNING = 0.7
--- A shock, as a share of the player's health (before their armor)
const SHOCK_SHARE = 0.55
const SHOCK_DAMAGE = 18
--- Seconds the player can't move after a shock
const STUN = 1

--- Where the player last stood off any copper that carries current: the jolt of a shock throws them back there
module.state = module.state or { levelId = "", safe = nil :: vec.Vec2? }
const MONSTER_SHOCK = 24
const MONSTER_SHOCK_EVERY = 0.9

--- Is the breaker with this id thrown? (A circuit or a machine without breaker is always on.)
function module.isOff(game: types.Game, breaker: string?): boolean
	return breaker ~= nil and game.flags[`off:{breaker}`] == true
end

function module.circuitAt(game: types.Game, x: number, y: number): Circuit?
	local lvl = game.level :: level.Level
	local ground = level.groundAt(lvl, x, y)
	if not (ground and ground.plate) then
		return nil
	end
	for _, circuit in lvl.power do
		local a = circuit.area
		if x >= a[1] and x <= a[3] and y >= a[2] and y <= a[4] then
			return circuit
		end
	end
	return nil
end

--- "dead" (no current), "idle" (a pulsing plate between two sparks), "warning" (about to spark) or "live"
function module.circuitState(game: types.Game, circuit: Circuit): string
	if module.isOff(game, circuit.breaker) or (circuit.needs ~= nil and not game.flags[`open:{circuit.needs}`]) then
		return "dead"
	end
	if circuit.mode ~= "pulse" then
		return "live"
	end
	local period = circuit.period or 3
	local t = (game.time + (circuit.offset or 0)) % period
	if t < (circuit.on or 1.2) then
		return "live"
	elseif t > period - module.WARNING then
		return "warning"
	end
	return "idle"
end

function module.cellState(game: types.Game, x: number, y: number): string
	local circuit = module.circuitAt(game, x, y)
	return if circuit then module.circuitState(game, circuit) else "dead"
end

local function shockPlayer(game: types.Game)
	local player = game.player
	if player.invincible > 0 then
		return
	end
	local insulated = player_rules.hasBuff(player, "insulated")
	local damage = math.max(SHOCK_DAMAGE, math.floor(player_rules.maxHp(player) * SHOCK_SHARE))
	effects.burst(player.pos + vec.V2(0, -0.3), "spark", 12)
	if player_rules.hurt(game, damage, "electric", nil, nil) and not insulated then
		player.stun = STUN
		-- The jolt throws the player off the copper
		local safe = module.state.safe
		if safe and module.state.levelId == game.level.id then
			effects.burst(player.pos + vec.V2(0, -0.3), "spark", 16)
			player.pos = safe
			player.knockback = vec.V2(0, 0)
			effects.shake(0.4)
		end
	end
	if not game.flags.taughtShock then
		game.flags.taughtShock = true
		game.events[#game.events + 1] = {
			kind = "message",
			text = "The copper plates are live! The jolt throws you back. They crackle before they spark: cross between two sparks, or cut what feeds them.",
		}
	end
end

--- Shocks: the player and the creatures standing on live plates. `grounded` is false while the player isn't touching
--- the floor (crawling in a duct, flying on the rope of the grapnel).
function module.update(game: types.Game, dt: number, grounded: boolean)
	local lvl = game.level :: level.Level
	if #lvl.power == 0 then
		return
	end
	local cell = level.cellOf(game.player.pos)
	if module.state.levelId ~= game.level.id then
		module.state.levelId = game.level.id
		module.state.safe = nil
	end
	local state = module.cellState(game, cell.x, cell.y)
	if state == "dead" then
		module.state.safe = game.player.pos
	end
	if grounded and state == "live" then
		shockPlayer(game)
	end
	for _, monster in game.monsters do
		local species = monsters.species[monster.kind]
		if not monster.dead and not species.flying and not species.hazard and not species.boss then
			local m = level.cellOf(monster.pos)
			local mon = monster :: any
			mon.shockTime = math.max(0, (mon.shockTime or 0) - dt)
			if mon.shockTime <= 0 and module.cellState(game, m.x, m.y) == "live" then
				mon.shockTime = MONSTER_SHOCK_EVERY
				effects.burst(monster.pos + vec.V2(0, -0.3), "spark", 8)
				combat.hurtMonster(game, monster, MONSTER_SHOCK, "electric", monster.pos + vec.V2(0, 0.01))
			end
		end
	end
end

return module
