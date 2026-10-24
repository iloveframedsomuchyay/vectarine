--[[
Draws the machines of the city, for world_view.luau: the sprites of machines that change (cogs that turn, mirrors,
lenses, breakers), the live copper plates, the cones of the lenses, the beams, the ducts and the rope of the grapnel.
]]
const beams = require("./beams")
const cogs = require("./cogs")
const ducts = require("./ducts")
const graphics = require("@vectarine/graphics")
const grapnel = require("./grapnel")
const level = require("./level")
const lenses = require("./lenses")
const loader = require("@vectarine/loader")
const monster_ai = require("./monster_ai")
const power = require("./power")
const sprites = require("./sprites")
const switches = require("./switches")
const theme = require("./theme")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

-- MARK: Sprites

--- The top-left cell of the great wheel of the level (cached by level)
local wheelCache: { levelId: string, anchor: vec.Vec2 } = { levelId = "", anchor = vec.V2(0, 0) }
local function wheelAnchor(game: types.Game): vec.Vec2
	if wheelCache.levelId ~= game.level.id then
		local anchor = vec.V2(math.huge, math.huge)
		for _, prop in game.level.props do
			if prop.kind == "great_wheel" then
				anchor = vec.V2(math.min(anchor.x, prop.cell.x), math.min(anchor.y, prop.cell.y))
			end
		end
		wheelCache = { levelId = game.level.id, anchor = anchor }
	end
	return wheelCache.anchor
end

--- The sprite of a machine right now (nil: the sprite of its kind)
function module.propSprite(game: types.Game, prop: types.Prop, time: number): string?
	local name: string = prop.kind
	if name == "emitter" then
		return `world/emitter_{prop.data.dir or "right"}{if beams.isLit(game, prop) then "" else "_off"}`
	elseif name == "mirror" or name == "mirror_crate" or name == "splitter" then
		local slope = if beams.slope(prop) == "/" then "slash" else "back"
		return `world/{name}_{slope}`
	elseif name == "crystal" then
		return if beams.isLit(game, prop) then `world/crystal_lit_{math.floor(time * 6) % 2}` else "world/crystal"
	elseif name == "breaker" then
		return if power.isOff(game, prop.data.id) then "world/breaker_off" else "world/breaker_on"
	elseif name == "cog_output" then
		return `world/cog_output_{prop.data.turn or "cw"}`
	elseif name == "great_wheel" then
		-- Which part of the wheel: the offset from the top-left cell of the wheel. It turns until the Tidemother falls.
		local anchor = wheelAnchor(game)
		local frame = if game.flags["killed:tidemother"] then 0 else math.floor(time * 3) % 2
		return `world/wheel_{frame}_{prop.cell.x - anchor.x}_{prop.cell.y - anchor.y}`
	elseif name == "fountain" then
		-- The fountains run again once the Tidemother has fallen: the deep tide comes back
		return if game.flags["killed:tidemother"] then `world/fountain_{math.floor(time * 5) % 2}` else "world/fountain_dry"
	elseif name == "water_door" then
		return `world/water_door_{prop.data.water or "bronze"}`
	end
	return nil
end

--- A sprite drawn over the machine (the cog turning on its peg), or nil
function module.overlay(game: types.Game, prop: types.Prop, time: number): string?
	local name: string = prop.kind
	if name == "cog_peg" or name == "cog_drive" or name == "cog_output" or name == "cog_fixed" then
		if not cogs.hasCog(game, prop) then
			return nil
		end
		local spin = cogs.state.spin[prop.key] or 0
		-- Neighbours turn the other way: shift the frame of every other cell so that their teeth mesh
		local offset = (prop.cell.x + prop.cell.y) % 2 * 2
		local frame = (math.floor(time * 10 * spin) + offset) % 4
		if cogs.state.jammed[prop.key] then
			frame = (offset + math.floor(time * 30) % 2) % 4
		end
		local small = if name == "cog_peg" then "cog" else "cog"
		return `world/{small}_{frame}`
	end
	return nil
end

--- The top of a lens: its eye, yellow, orange or red (crimson for the lenses of the High Tide)
function module.lensTop(prop: types.Prop): string
	local mood = lenses.mood(prop)
	return `world/lens_{if prop.data.crimson then "crimson_" else ""}{mood}`
end

--- The sprite drawn on the cell above a machine (nil: the `tall` of its kind): the eye of a lens, the dial of a wheel
function module.top(prop: types.Prop): string?
	if prop.kind == "lens" then
		return module.lensTop(prop)
	elseif prop.kind == "cog_output" then
		return `world/cog_dial_{prop.data.turn or "cw"}`
	end
	return nil
end

-- MARK: On the floor

const SPARK_BLUE = theme.hex("879ea3")
const SPARK_WHITE = theme.hex("e3ddd1")
const CONE_CALM = theme.hex("a6884a")
const CONE_SEEING = theme.hex("e3ddd1")
const CONE_CRIMSON = theme.hex("83473d")
const CONE_ALARM = theme.hex("612638")

--- Live copper plates glow and spark; plates about to spark crackle
function module.drawPlates(game: types.Game, low: vec.Vec2, high: vec.Vec2, time: number)
	local lvl = game.level :: level.Level
	if #lvl.power == 0 then
		return
	end
	for y = low.y, high.y do
		for x = low.x, high.x do
			local state = power.cellState(game, x, y)
			local seed = x * 7.13 + y * 3.71
			if state == "live" then
				sprites.drawInWorld("world/copper_plate_1", vec.V2(x, y))
				local frame = math.floor(time * 14 + seed) % 3
				if frame < 2 then
					sprites.drawInWorld(`world/spark_{frame}`, vec.V2(x, y))
				end
			elseif state == "warning" then
				if math.floor(time * 10 + seed) % 4 == 0 then
					local p = vec.V2(x + 0.2 + (seed * 0.37) % 0.6, y + 0.2 + (seed * 0.53) % 0.6)
					graphics.drawRect(p, vec.V2(0.12, 0.12), SPARK_WHITE)
					graphics.drawRect(p + vec.V2(0.12, 0.08), vec.V2(0.1, 0.06), SPARK_BLUE)
				end
			end
		end
	end
end

--- The cones of light of the lenses, on the floor (cut by walls and solid things)
function module.drawCones(game: types.Game, low: vec.Vec2, high: vec.Vec2, ignoreAll: boolean)
	for _, prop in game.level.props do
		if prop.kind == "lens" and prop.cell.x >= low.x - 8 and prop.cell.x <= high.x + 8 and prop.cell.y >= low.y - 8
			and prop.cell.y <= high.y + 8 then
			local mood = lenses.mood(prop)
			local friendly = lenses.ignores(game, prop, false)
			-- At rest, the cone is faint (crimson for the lenses that see everyone); about to see, it blazes orange;
			-- in a lockdown, it flashes
			local color = if mood == "alarm" then CONE_ALARM elseif mood == "seeing" then CONE_SEEING elseif prop.data.crimson then CONE_CRIMSON else CONE_CALM
			local alpha = if mood == "alarm" then 0.25 + 0.15 * math.sin(game.time * 12)
				elseif mood == "seeing" then 0.3 + 0.2 * lenses.warning(prop)
				elseif friendly then 0.06
				else 0.13
			local eye = lenses.eye(prop)
			local angle = lenses.angle(game, prop)
			local range = lenses.range(prop)
			local rays = 10
			local points: { vec.Vec2 } = {}
			for i = 0, rays do
				local a = angle - lenses.HALF_CONE + (2 * lenses.HALF_CONE) * i / rays
				local length = lenses.sightLength(game, eye, a, range, prop)
				table.insert(points, eye + vec.fromAngle(a, length))
			end
			-- A fan of triangles from the eye
			for i = 1, #points - 1 do
				graphics.drawPolygon({ eye, points[i], points[i + 1] }, theme.withAlpha(color, alpha))
			end
			for i = 1, #points - 1 do
				graphics.drawLine(points[i], points[i + 1], theme.withAlpha(color, alpha * 2), 0.06)
			end
		end
	end
end

--- Over a lens about to see the player: a little bar that fills up (when it is full, the place locks down)
function module.drawLensWarnings(game: types.Game)
	for _, prop in game.level.props do
		if prop.kind == "lens" then
			local warning = lenses.warning(prop)
			if warning > 0 and lenses.mood(prop) ~= "alarm" then
				local top = prop.cell + vec.V2(0.1, -1.35)
				graphics.drawRect(top, vec.V2(0.8, 0.16), theme.colors.darkness)
				graphics.drawRect(top + vec.V2(0.04, 0.04), vec.V2(0.72 * warning, 0.08), CONE_SEEING)
			end
		end
	end
end

-- MARK: Above

const BEAM_GLOW = theme.hex("83473d")
const BEAM_CORE = theme.hex("e3ddd1")
const BEAM_MID = theme.hex("a6884a")

--- The beams: a red glow with a bright core, at the height of a chest
function module.drawBeams(time: number)
	local lift = vec.V2(0, -0.35)
	for _, trace in beams.state.traces do
		local pulse = 0.8 + math.sin(time * 18) * 0.2
		for i = 1, #trace.points - 1 do
			local a, b = trace.points[i] + lift, trace.points[i + 1] + lift
			graphics.drawLine(a, b, theme.withAlpha(BEAM_GLOW, 0.35 * pulse), 0.32)
			graphics.drawLine(a, b, theme.withAlpha(BEAM_MID, 0.85), 0.12)
			graphics.drawLine(a, b, theme.withAlpha(BEAM_CORE, pulse), 0.05)
		end
		local last = trace.points[#trace.points] + lift
		graphics.drawCircle(last, 0.12 + math.sin(time * 25) * 0.04, theme.withAlpha(BEAM_CORE, 0.9))
	end
end

const WAVE_DEEP = theme.hex("245273")
const WAVE_MID = theme.hex("4e7499")
const WAVE_FOAM = theme.hex("e3ddd1")

--- The attacks of the Tidemother: the beam of her crown, and the wave of the tide rolling across the arena
function module.drawBoss(game: types.Game, time: number)
	for _, monster in game.monsters do
		if monster.kind == "tidemother" and not monster.dead then
			local from, to = monster_ai.crownBeam(game, monster)
			if from and to then
				local pulse = 0.8 + math.sin(time * 22) * 0.2
				graphics.drawLine(from, to, theme.withAlpha(BEAM_GLOW, 0.45 * pulse), 0.45)
				graphics.drawLine(from, to, theme.withAlpha(SPARK_BLUE, 0.9), 0.16)
				graphics.drawLine(from, to, theme.withAlpha(BEAM_CORE, pulse), 0.06)
			end
			local wave = monster_ai.tideWave(monster)
			if wave then
				-- A band of water, two tiles high, with a gap; foam on its front. While she calls it, it rises (faint).
				local alpha = if wave.forming then 0.35 + math.sin(time * 10) * 0.1 else 1
				local x = wave.left
				while x < wave.right do
					local inGap = math.abs(x + 0.25 - wave.gap) < monster_ai.WAVE_GAP
					if not inGap then
						local bob = math.sin(time * 9 + x * 1.3) * 0.08
						graphics.drawRect(vec.V2(x, wave.y - 1.6 + bob), vec.V2(0.52, 1.4), theme.withAlpha(WAVE_DEEP, 0.75 * alpha))
						graphics.drawRect(vec.V2(x, wave.y - 0.7 + bob), vec.V2(0.52, 0.5), theme.withAlpha(WAVE_MID, 0.9 * alpha))
						graphics.drawRect(vec.V2(x, wave.y - 0.25 + bob), vec.V2(0.52, 0.18), theme.withAlpha(WAVE_FOAM, alpha))
					end
					x += 0.5
				end
			end
		end
	end
end

const ROPE = theme.hex("a6884a")
const ROPE_DARK = theme.hex("46332c")

function module.drawRope(game: types.Game)
	local pull = grapnel.state.pull
	if not pull or pull.levelId ~= game.level.id then
		return
	end
	local hand = game.player.pos + vec.V2(0, -0.5)
	graphics.drawLine(hand, pull.ring, ROPE_DARK, 0.09)
	graphics.drawLine(hand, pull.ring, ROPE, 0.05)
end

const DUCT_DIM = theme.withAlpha(theme.colors.darkness, 0.6)
const DUCT_WALL = theme.hex("323b42")
const DUCT_INSIDE = theme.hex("0b1016")
const DUCT_LIGHT = theme.hex("595c55")

--- In the ducts: the level above is dimmed, the ducts show as dark tunnels, the player crawls in them
function module.drawDucts(game: types.Game, low: vec.Vec2, high: vec.Vec2, time: number)
	if not ducts.isActive(game) then
		return
	end
	local lvl = game.level :: level.Level
	graphics.drawRect(low - vec.V2(1, 1), high - low + vec.V2(3, 3), DUCT_DIM)
	for y = low.y, high.y do
		for x = low.x, high.x do
			if lvl.ducts[1 + x + y * lvl.width] then
				graphics.drawRect(vec.V2(x + 0.12, y + 0.12), vec.V2(0.76, 0.76), DUCT_WALL)
				-- Join the neighbours
				for _, offset in { vec.V2(1, 0), vec.V2(0, 1) } do
					local nx, ny = x + offset.x, y + offset.y
					if level.inside(lvl, nx, ny) and lvl.ducts[1 + nx + ny * lvl.width] then
						graphics.drawRect(vec.V2(x + 0.12, y + 0.12), vec.V2(0.76 + offset.x, 0.76 + offset.y), DUCT_WALL)
					end
				end
			end
		end
	end
	for y = low.y, high.y do
		for x = low.x, high.x do
			if lvl.ducts[1 + x + y * lvl.width] then
				graphics.drawRect(vec.V2(x + 0.22, y + 0.22), vec.V2(0.56, 0.56), DUCT_INSIDE)
				for _, offset in { vec.V2(1, 0), vec.V2(0, 1) } do
					local nx, ny = x + offset.x, y + offset.y
					if level.inside(lvl, nx, ny) and lvl.ducts[1 + nx + ny * lvl.width] then
						graphics.drawRect(vec.V2(x + 0.22, y + 0.22), vec.V2(0.56 + offset.x, 0.56 + offset.y), DUCT_INSIDE)
					end
				end
				-- Light falls through the vents
				local prop = level.propAt(lvl, x, y)
				if prop and prop.kind == "vent" then
					graphics.drawRect(vec.V2(x + 0.25, y + 0.25), vec.V2(0.5, 0.5), theme.withAlpha(DUCT_LIGHT, 0.8))
				end
			end
		end
	end
	-- The player, crawling: a small dark shape with the light of the flashlight
	local pos = game.player.pos
	local frame = if game.player.moving then math.floor(time * 8) % 2 else 0
	sprites.drawInWorld(`characters/crawl_{frame}`, pos + vec.V2(-0.5, -0.8), { flipX = game.player.facing == "left" })
end

--- Is the player crawling? (world_view doesn't draw them standing then)
function module.isCrawling(game: types.Game): boolean
	return ducts.isActive(game)
end

--- Is the prop open for good? (a crystal of a mechanism already solved)
function module.isSolved(game: types.Game, prop: types.Prop): boolean
	return prop.data.opens ~= nil and switches.isOpen(game, prop.data.opens)
end

return module
