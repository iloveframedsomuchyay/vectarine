--[[
The foreground: dark silhouettes along the outer walls of the level, as if they were close to the camera (the art is
drawn by tools/art/foreground.py). Things hang from the top wall (stalactites, vines, icicles, chains), grow from the
bottom one (ferns, mushrooms, grass, rocks, reeds) and cling to the sides (shelf fungus, ivy, ice crystals).

Beyond the pieces, a dark mass (the rock, the ceiling, close to the camera) fills the screen up to its edge, so that
the pieces hang from something and grow out of something: they are the same black.

They only decorate, and only show near the edges of the level: the edges of where the player can go (the lowest,
highest, leftmost and rightmost cells they can stand on or sail, exits aside), not of the map, whose rock can be much
thicker; each piece follows the edge of its own columns (or rows). Standing on the lowest floor of a level shows the
bottom pieces a couple of tiles below; when the camera moves away, they slide away faster than the world (FACTOR:
the parallax makes them feel close). They only move with the camera: when it stops at the border of the map, they
stop too. They fade when the player comes close
to them.

Each level picks a set with its `foreground` (by default its style: the caves of the oasis, the desert, the swamp, the
frost; "interior" indoors). The pieces are laid along each edge in slots that never change for a given place of the
level, so going back and forth shows the same ones.
]]
const graphics = require("@vectarine/graphics")
const level = require("./level")
const loader = require("@vectarine/loader")
const sprites = require("./sprites")
const theme_colors = require("./theme")
const types = require("./types")
const vec = require("@vectarine/vec")
const vec4 = require("@vectarine/vec4")

const module = loader.init() or {}

--- How much faster than the world the foreground scrolls
module.FACTOR = 1.6

export type Theme = {
	--- Pieces hanging from the top edge
	top: { string },
	--- Pieces growing from the bottom edge
	bottom: { string },
	--- Pieces on the left edge (mirrored on the right one)
	side: { string },
	--- A piece in the two top corners (cobwebs): stretched across the corner, its threads end on the edges of the mass
	corner: string?,
	--- The edge of the mass is straight (walls of metal and marble), not rough like rock
	smooth: boolean?,
}

module.themes = {
	cave = { top = { "stalactite", "stalactites", "vine", "roots" }, bottom = { "fern", "mushrooms", "grass", "rock" }, side = { "shelf", "ivy" } },
	desert = { top = { "stalactite", "stalactites", "roots" }, bottom = { "grass", "rock", "dry_bush" }, side = { "ivy" } },
	swamp = { top = { "vine", "moss", "roots" }, bottom = { "reeds", "fern", "mushrooms" }, side = { "shelf", "ivy" } },
	frost = { top = { "icicles", "stalactite", "stalactites" }, bottom = { "grass", "rock" }, side = { "crystals" } },
	interior = { top = { "chain" }, bottom = { "rubble", "barrel" }, side = {}, corner = "cobweb" },
	city = { top = { "pipes", "girder", "chain" }, bottom = { "gear", "rubble", "barrel" }, side = { "pipe_side", "ivy" } },
	-- The great halls of the city (the palace, the Archive, the Registry, the guild of the Salt): only black pipes
	halls = { top = { "pipes", "pipe_bend" }, bottom = { "pipe_floor" }, side = { "pipe_side", "pipe_side_low" }, smooth = true },
} :: { [string]: Theme }

--- A strip of pieces along an edge: the distance between two slots (in tiles), and how many slots are empty
type Strip = { spacing: number, empty: number, seed: number }

const TOP: Strip = { spacing = 2.3, empty = 0.35, seed = 1 }
const BOTTOM: Strip = { spacing = 2.3, empty = 0.3, seed = 2 }
const LEFT: Strip = { spacing = 3.2, empty = 0.5, seed = 3 }
const RIGHT: Strip = { spacing = 3.2, empty = 0.5, seed = 4 }

--- The dark mass beyond the pieces: drawn in steps of this width (in tiles), its edge a little rough
const MASS_STEP = 0.25
const MASS_ROUGHNESS = 0.18
--- The black of the pieces (see tools/art/foreground.py)
const MASS_COLOR = theme_colors.hex("0b1016")

--- The edge at a cell is the most extreme one this many cells around it: the mass doesn't dive into narrow gaps
const WINDOW = 2

--- A piece is only placed where the edge of the mass varies less than this across its width (in tiles), so that it
--- never hangs from nothing
const MAX_STEP = 0.2

--- Pieces fade below this distance (in tiles) from the player, down to FADED
const FADE_DISTANCE = 2.5
const FADED = 0.3

--- A stable pseudo-random number in [0, 1) for slot `i` of a strip (`k` picks one of its properties)
local function random(i: number, seed: number, k: number): number
	return (math.sin(i * 12.9898 + seed * 78.233 + k * 37.719) * 43758.5453) % 1
end

--- The slots of a strip that are on the screen: calls `place(index, offset)`, `offset` being the position of the slot
--- along the edge, in tiles from the start of the screen
local function eachSlot(strip: Strip, scroll: number, length: number, place: (index: number, offset: number) -> ())
	local first = math.floor((scroll - 2) / strip.spacing)
	local last = math.ceil((scroll + length) / strip.spacing)
	for index = first, last do
		if random(index, strip.seed, 1) >= strip.empty then
			local offset = index * strip.spacing + random(index, strip.seed, 2) * strip.spacing * 0.5 - scroll
			place(index, offset)
		end
	end
end

--- How far beyond the reachable cells the pieces are (in tiles): the bottom of the bottom pieces, the top of the top
--- pieces, the outer side of the side pieces
const MARGIN = { top = 1.6, bottom = 1.1, side = 1.3 }

--- Where the player can go, edge by edge: for each column, its highest and lowest reachable cells; for each row, its
--- leftmost and rightmost ones (nil where nothing is reachable)
type Edges = {
	top: { [number]: number },
	bottom: { [number]: number },
	left: { [number]: number },
	right: { [number]: number },
	--- The corner of all of them (for the cobwebs)
	minX: number,
	minY: number,
	maxX: number,
	maxY: number,
}

--- The edges of each level, computed again when its terrain changes (a bomb, the canals filling up)
local edgesCache: { [any]: { version: number, edges: Edges } } = setmetatable({}, { __mode = "k" }) :: any

--- The edges of the cells the player can stand on or sail (the exits at the borders of the map aside)
local function reachable(lvl: level.Level): Edges
	local cached = edgesCache[lvl]
	if cached and cached.version == lvl.version then
		return cached.edges
	end
	local exits: { [number]: boolean } = {}
	for _, cells in lvl.entries do
		for _, cell in cells do
			exits[cell.y * lvl.width + cell.x] = true
		end
	end
	local edges: Edges = { top = {}, bottom = {}, left = {}, right = {}, minX = lvl.width, minY = lvl.height, maxX = 0, maxY = 0 }
	for y = 0, lvl.height - 1 do
		for x = 0, lvl.width - 1 do
			local ground = level.groundAt(lvl, x, y)
			local wall = level.wallAt(lvl, x, y)
			local open = ground ~= nil and (ground.walkable or ground.sailable == true)
				and (wall == nil or wall.walkable or wall.ladder == true)
			if open and not exits[y * lvl.width + x] then
				edges.top[x] = math.min(edges.top[x] or y, y)
				edges.bottom[x] = math.max(edges.bottom[x] or y, y)
				edges.left[y] = math.min(edges.left[y] or x, x)
				edges.right[y] = math.max(edges.right[y] or x, x)
				edges.minX = math.min(edges.minX, x)
				edges.minY = math.min(edges.minY, y)
				edges.maxX = math.max(edges.maxX, x)
				edges.maxY = math.max(edges.maxY, y)
			end
		end
	end
	edgesCache[lvl] = { version = lvl.version, edges = edges }
	return edges
end

--- The most extreme value of `line` (the lowest with `pick = math.max`) over the cells `from` to `to`, or nil
local function extreme(line: { [number]: number }, from: number, to: number, pick: (number, number) -> number): number?
	local result: number? = nil
	for i = math.floor(from), math.floor(to) do
		local value = line[i]
		if value then
			result = if result then pick(result, value) else value
		end
	end
	return result
end

--- Draw the foreground of the level over the world. `camera` is the top-left corner of the view, in tiles.
function module.draw(game: types.Game, origin: vec.Vec2, tileSize: vec.Vec2, camera: vec.Vec2, visible: vec.Vec2)
	-- No theme (out in the open, on the surface): nothing close to the camera
	local theme = module.themes[game.level.foreground]
	local roughness = if theme and theme.smooth then 0 else MASS_ROUGHNESS
	if not theme then
		return
	end
	local lvl = game.level :: level.Level
	local edges = reachable(lvl)
	-- Closer to the camera than the level, the foreground moves faster than the world when the camera moves (FACTOR),
	-- and only then. Positions on the screen are in tiles from its top-left corner. Along an edge, the world position
	-- of a place on the screen is measured from the center of the screen.
	local half = visible:scale(0.5)
	local center = camera + half
	--- The world position of the middle of a piece at `offset` on the screen, along x or y
	local function worldX(offset: number): number
		return center.x + (offset + 1 - half.x) / module.FACTOR
	end
	local function worldY(offset: number): number
		return center.y + (offset + 1 - half.y) / module.FACTOR
	end
	--- Where the camera is when it looks at `focus` (the same rule as the camera of world_view.luau), on one axis
	local function cameraFor(focusValue: number, size: number, worldSize: number): number
		if worldSize <= size then
			return (worldSize - size) / 2
		end
		return math.clamp(focusValue - size / 2, 0, worldSize - size)
	end
	--- Where an edge of the mass is on the screen, on one axis. When the camera is where it would be with the player on
	--- that edge (`focusValue`), the edge is at its place in the world (`lineValue`, kept on the screen by `limit`);
	--- when the camera moves away from there, the edge slides FACTOR times faster than the world.
	local function onScreen(lineValue: number, focusValue: number, isX: boolean, limit: (number) -> number): number
		local size = if isX then visible.x else visible.y
		local reference = cameraFor(focusValue, size, if isX then lvl.width else lvl.height)
		local current = if isX then camera.x else camera.y
		return limit(lineValue - reference) - (current - reference) * module.FACTOR
	end
	-- Silhouettes are darker in the dark
	local light = 1 - lvl.darkness * 0.55
	local playerAt = game.player.pos - camera
	-- Along the edges, the slots scroll with the same parallax
	local scroll = center:scale(module.FACTOR) - half

	-- Where the mass ends, on the screen, at a place along an edge (`world` is the world position along the edge). The
	-- edge of each cell is the most extreme one around it; between two cells, it slopes from one to the other.
	local function smooth(world: number, low: number, high: number, at: (cell: number) -> number?): number?
		local cell = math.clamp(math.floor(world), low, high)
		local a, b = at(cell), at(cell + 1)
		if not a or not b then
			return a or b
		end
		local t = math.clamp(world - cell, 0, 1)
		return a + (b - a) * t
	end
	local function topLine(world: number): number?
		local highest = smooth(world - 0.5, edges.minX, edges.maxX, function(cell)
			return extreme(edges.top, cell - WINDOW, cell + WINDOW, math.min)
		end)
		if not highest then
			return nil
		end
		-- The player stands on the highest cell with their focus (see world_view.luau) 0.1 below its top
		return onScreen(highest - MARGIN.top, highest + 0.1, false, function(value)
			return math.max(value, 0.5)
		end)
	end
	local function bottomLine(world: number): number?
		local lowest = smooth(world - 0.5, edges.minX, edges.maxX, function(cell)
			return extreme(edges.bottom, cell - WINDOW, cell + WINDOW, math.max)
		end)
		if not lowest then
			return nil
		end
		return onScreen(lowest + 1 + MARGIN.bottom, lowest + 0.1, false, function(value)
			return math.min(value, visible.y - 0.6)
		end)
	end
	local function sideLine(world: number, isLeft: boolean): number?
		local outer = smooth(world - 0.5, edges.minY, edges.maxY, function(cell)
			return extreme(if isLeft then edges.left else edges.right, cell - WINDOW, cell + WINDOW, if isLeft then math.min else math.max)
		end)
		if not outer then
			return nil
		end
		if isLeft then
			return onScreen(outer - MARGIN.side, outer + 0.5, true, function(value)
				return math.max(value, 0.4)
			end)
		end
		return onScreen(outer + 1 + MARGIN.side, outer + 0.5, true, function(value)
			return math.min(value, visible.x - 0.4)
		end)
	end
	local massColor = vec4.createColor(MASS_COLOR.x * light, MASS_COLOR.y * light, MASS_COLOR.z * light, 1)

	--- The dark mass beyond the pieces, along the four edges
	local function drawMass()
		local first = math.floor((scroll.x - 1) / MASS_STEP)
		local last = math.ceil((scroll.x + visible.x + 1) / MASS_STEP)
		for i = first, last do
			local x = i * MASS_STEP - scroll.x
			local world = worldX(x - 1 + MASS_STEP / 2)
			local top = topLine(world)
			if top and top > 0 then
				local edge = top + random(i, 11, 1) * roughness
				graphics.drawRect(vec.V2(x, 0), vec.V2(MASS_STEP, edge), massColor)
			end
			local bottom = bottomLine(world)
			if bottom and bottom < visible.y then
				local edge = bottom - random(i, 12, 1) * roughness
				graphics.drawRect(vec.V2(x, edge), vec.V2(MASS_STEP, visible.y - edge), massColor)
			end
		end
		first = math.floor((scroll.y - 1) / MASS_STEP)
		last = math.ceil((scroll.y + visible.y + 1) / MASS_STEP)
		for i = first, last do
			local y = i * MASS_STEP - scroll.y
			local world = worldY(y - 1 + MASS_STEP / 2)
			local left = sideLine(world, true)
			if left and left > 0 then
				local edge = left + random(i, 13, 1) * roughness
				graphics.drawRect(vec.V2(0, y), vec.V2(edge, MASS_STEP), massColor)
			end
			local right = sideLine(world, false)
			if right and right < visible.x then
				local edge = right - random(i, 14, 1) * roughness
				graphics.drawRect(vec.V2(edge, y), vec.V2(visible.x - edge, MASS_STEP), massColor)
			end
		end
	end

	--- Where a piece meets the mass, sampled across its width (from `offset`, 2 tiles wide): `line` gives the edge of
	--- the mass at a screen position. The piece must be held by the mass all along: nil where the edge drops away under
	--- part of it (a step of the rock), or else the edge that holds it everywhere (`pick`: the least deep one)
	local function holding(offset: number, line: (screen: number) -> number?, pick: (number, number) -> number): number?
		local result: number? = nil
		local low: number, high: number = math.huge, -math.huge
		for i = 0, 4 do
			local found = line(offset + 0.1 + i * 0.45)
			if not found then
				return nil
			end
			local value: number = found
			low, high = math.min(low, value), math.max(high, value)
			result = if result then pick(result, value) else value
		end
		return if high - low <= MAX_STEP then result else nil
	end

	local function piece(names: { string }, index: number, seed: number): string
		return `foreground/{lvl.foreground}_{names[math.floor(random(index, seed, 3) * #names) + 1]}`
	end
	local function draw(name: string, pos: vec.Vec2, flipX: boolean)
		if pos.x > visible.x or pos.y > visible.y or pos.x < -2 or pos.y < -2 then
			return
		end
		local middle = pos + vec.V2(1, 1)
		local distance = (middle - playerAt):length()
		local alpha = if distance < FADE_DISTANCE then FADED + (1 - FADED) * distance / FADE_DISTANCE else 1
		sprites.drawInWorld(name, pos, { size = 2, flipX = flipX, tint = vec4.createColor(light, light, light, alpha) })
	end

	graphics.withTransformation({ translation = origin }, function()
		graphics.withTransformation({ scale = vec.V2(tileSize.x, -tileSize.y) }, function()
			drawMass()
			-- Hanging from the mass above the highest cells of their columns, growing from the one below the lowest
			eachSlot(TOP, scroll.x, visible.x, function(index, offset)
				local top = holding(offset, function(x)
					return topLine(worldX(x - 1))
				end, math.min)
				if top then
					-- The top of the piece on the line: only the roughness of the mass covers it (see foreground.py)
					local y = top
					draw(piece(theme.top, index, TOP.seed), vec.V2(offset, y), random(index, TOP.seed, 5) < 0.5)
				end
			end)
			eachSlot(BOTTOM, scroll.x, visible.x, function(index, offset)
				local bottom = holding(offset, function(x)
					return bottomLine(worldX(x - 1))
				end, math.max)
				if bottom then
					local y = bottom - 2
					draw(piece(theme.bottom, index, BOTTOM.seed), vec.V2(offset, y), random(index, BOTTOM.seed, 5) < 0.5)
				end
			end)
			-- Beyond the leftmost and rightmost cells of their rows, away from the corners
			if #theme.side > 0 then
				for _, side in { { strip = LEFT, isLeft = true }, { strip = RIGHT, isLeft = false } } do
					local strip = side.strip
					eachSlot(strip, scroll.y, visible.y, function(index, offset)
						local y = worldY(offset)
						local line = if side.isLeft then edges.left else edges.right
						local outer = extreme(line, y - 1, y + 1, if side.isLeft then math.min else math.max)
						local edge = holding(offset, function(screen)
							return sideLine(worldY(screen - 1), side.isLeft)
						end, if side.isLeft then math.min else math.max)
						if not outer or not edge then
							return
						end
						local columnTop, columnBottom = edges.top[outer], edges.bottom[outer]
						if not columnTop or not columnBottom or y - 1.5 < columnTop or y + 1.5 > columnBottom then
							return
						end
						local x = if side.isLeft then edge else edge - 2
						draw(piece(theme.side, index, strip.seed), vec.V2(x, offset), not side.isLeft)
					end)
				end
			end
			if theme.corner then
				local corner = `foreground/{lvl.foreground}_{theme.corner}`
				local top = onScreen(edges.minY - MARGIN.top, edges.minY + 0.1, false, function(value)
					return math.max(value, 0.5)
				end)
				local left = onScreen(edges.minX - MARGIN.side, edges.minX + 0.5, true, function(value)
					return math.max(value, 0.4)
				end)
				local right = onScreen(edges.maxX + 1 + MARGIN.side, edges.maxX + 0.5, true, function(value)
					return math.min(value, visible.x - 0.4)
				end)
				draw(corner, vec.V2(left, top), false)
				draw(corner, vec.V2(right - 2, top), true)
			end
		end)
	end)
end

return module
