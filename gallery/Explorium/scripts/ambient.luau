--[[
Life in the air of a level, only to look at (no gameplay): set by the `ambient` of a level (data/levels.luau).

- fireflies: little lights drifting above the ground, pulsing. They shine through the darkness.
- motes: the same, pale blue: the glowworms of the Glowworm Grotto, let go of their threads.
- butterflies: white and golden, flapping over the grass (in the light only: they are drawn under the darkness).
- glints: the water catches the light, here and there.
Smoke rises from the chimneys of the buildings of the city, everywhere (see data/building_kinds.luau).

The values are densities (roughly, how many for 100 cells of the level). Each one is tied to a cell of the level and
wanders around it, so that they stay where they are when the camera moves.
]]
const building_kinds = require("./data/building_kinds")
const graphics = require("@vectarine/graphics")
const level = require("./level")
const levels = require("./data/levels")
const loader = require("@vectarine/loader")
const theme = require("./theme")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

const FIREFLY = theme.hex("bdbbae")
const FIREFLY_GLOW = theme.hex("a6884a")
const MOTE = theme.hex("e3ddd1")
const MOTE_GLOW = theme.hex("879ea3")
const WINGS = { theme.hex("e3ddd1"), theme.hex("a6884a"), theme.hex("bdbbae") }
const GLINT = theme.hex("e3ddd1")

--- A number from 0 to 1 for a cell, always the same
local function hash(x: number, y: number, salt: number): number
	local n = math.sin(x * 127.1 + y * 311.7 + salt * 74.7) * 43758.5453
	return n - math.floor(n)
end

local function open(lvl: level.Level, x: number, y: number): boolean
	local wall = level.wallAt(lvl, x, y)
	return level.inside(lvl, x, y) and not (wall and not wall.walkable)
end

--- Little lights wandering around their cell, pulsing
local function drawLights(lvl: level.Level, low: vec.Vec2, high: vec.Vec2, time: number, density: number, salt: number, core: any, glow: any)
	for y = low.y, high.y do
		for x = low.x, high.x do
			if hash(x, y, salt) < density / 100 and open(lvl, x, y) then
				local phase = hash(x, y, salt + 1) * 6.28
				local speed = 0.25 + hash(x, y, salt + 2) * 0.35
				local pos = vec.V2(
					x + 0.5 + math.sin(time * speed + phase) * 0.9 + math.sin(time * speed * 2.3 + phase) * 0.2,
					y + 0.2 + math.cos(time * speed * 0.8 + phase) * 0.6
				)
				-- They light up and go dark, slowly, each at its own pace
				local pulse = math.clamp(math.sin(time * (0.8 + speed) + phase * 2) * 1.4 + 0.4, 0, 1)
				if pulse > 0.02 then
					graphics.drawEllipse(pos, vec.V2(0.5, 0.5), theme.withAlpha(glow, 0.07 * pulse))
					graphics.drawEllipse(pos, vec.V2(0.34, 0.34), theme.withAlpha(glow, 0.12 * pulse))
					graphics.drawEllipse(pos, vec.V2(0.2, 0.2), theme.withAlpha(glow, 0.3 * pulse))
					graphics.drawRect(pos - vec.V2(0.065, 0.065), vec.V2(0.13, 0.13), theme.withAlpha(core, pulse))
				end
			end
		end
	end
end

--- Butterflies over the grass: two wings that open and close, a lazy flight around their cell
local function drawButterflies(lvl: level.Level, low: vec.Vec2, high: vec.Vec2, time: number, density: number)
	for y = low.y, high.y do
		for x = low.x, high.x do
			local ground = level.groundAt(lvl, x, y)
			if hash(x, y, 11) < density / 100 and ground and ground.name == "grass" and open(lvl, x, y) then
				local phase = hash(x, y, 12) * 6.28
				local speed = 0.3 + hash(x, y, 13) * 0.3
				local pos = vec.V2(
					x + 0.5 + math.sin(time * speed + phase) * 1.4,
					y + 0.1 + math.sin(time * speed * 1.7 + phase) * 0.7 - math.abs(math.sin(time * 3 + phase)) * 0.15
				)
				local color = WINGS[math.floor(hash(x, y, 14) * #WINGS) + 1]
				-- The wings flap: wide open, then closed (a thin line)
				local open_ = math.abs(math.sin(time * 9 + phase))
				local wing = vec.V2(0.06 + 0.1 * open_, 0.15)
				graphics.drawRect(pos - vec.V2(wing.x + 0.015, 0.075), wing, color)
				graphics.drawRect(pos + vec.V2(0.015, -0.075), wing, color)
				graphics.drawRect(pos - vec.V2(0.02, 0.08), vec.V2(0.04, 0.16), theme.colors.darkness)
			end
		end
	end
end

--- The water catches the light: little crosses that shine for a moment
local function drawGlints(lvl: level.Level, low: vec.Vec2, high: vec.Vec2, time: number)
	for y = low.y, high.y do
		for x = low.x, high.x do
			local ground = level.groundAt(lvl, x, y)
			if ground and ground.water and hash(x, y, 21) < 0.35 then
				local period = 2.5 + hash(x, y, 22) * 3
				local t = (time + hash(x, y, 23) * period) % period
				if t < 0.6 then
					local alpha = math.sin(t / 0.6 * math.pi) * 0.7
					local pos = vec.V2(x + 0.2 + hash(x, y, 24) * 0.6, y + 0.2 + hash(x, y, 25) * 0.6)
					local size = 0.06 + 0.1 * alpha
					graphics.drawRect(pos - vec.V2(size, 0.025), vec.V2(size * 2, 0.05), theme.withAlpha(GLINT, alpha))
					graphics.drawRect(pos - vec.V2(0.025, size * 0.7), vec.V2(0.05, size * 1.4), theme.withAlpha(GLINT, alpha * 0.8))
				end
			end
		end
	end
end

const SMOKE = theme.hex("969372")

--- Smoke rising from the chimneys of the buildings: puffs that grow, drift and fade
local function drawSmoke(game: types.Game, low: vec.Vec2, high: vec.Vec2, time: number)
	for _, placed in game.level.buildings do
		local kind = building_kinds[placed.kind]
		local chimney = kind.chimney
		if chimney and placed.cell.x + kind.w >= low.x and placed.cell.x <= high.x and placed.cell.y + kind.h >= low.y - 2 and placed.cell.y <= high.y then
			local base = placed.cell + vec.V2(chimney[1], chimney[2])
			for i = 0, 4 do
				local t = (time * 0.35 + i / 5 + placed.cell.x * 0.13) % 1
				local pos = base + vec.V2(math.sin(t * 5 + i) * 0.15 + t * 0.6, -t * 2.2)
				local size = 0.12 + t * 0.35
				graphics.drawEllipse(pos, vec.V2(size, size * 0.8), theme.withAlpha(SMOKE, 0.35 * (1 - t)))
			end
		end
	end
end

--- Under the darkness: what lives in the light (butterflies, glints, smoke). In world coordinates (cells).
function module.drawLit(game: types.Game, low: vec.Vec2, high: vec.Vec2, time: number)
	drawSmoke(game, low, high, time)
	local settings = levels.levels[game.level.id].ambient
	if not settings then
		return
	end
	local lvl = game.level :: level.Level
	if settings.glints then
		drawGlints(lvl, low, high, time)
	end
	if settings.butterflies then
		drawButterflies(lvl, low, high, time, settings.butterflies)
	end
end

--- Over the darkness: what shines by itself (fireflies, motes). In world coordinates (cells).
function module.drawGlow(game: types.Game, low: vec.Vec2, high: vec.Vec2, time: number)
	local settings = levels.levels[game.level.id].ambient
	if not settings then
		return
	end
	local lvl = game.level :: level.Level
	if settings.fireflies then
		drawLights(lvl, low, high, time, settings.fireflies, 1, FIREFLY, FIREFLY_GLOW)
	end
	if settings.motes then
		drawLights(lvl, low, high, time, settings.motes, 5, MOTE, MOTE_GLOW)
	end
end

return module
