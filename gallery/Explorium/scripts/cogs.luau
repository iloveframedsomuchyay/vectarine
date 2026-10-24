--[[
Cogs of the city: a powered drive, empty pegs, and a wheel that opens something.

- `cog_drive`: a motor that turns its cog clockwise (unless its `data.breaker` is thrown, see power.luau).
- `cog_peg`: a peg. The player puts a cog on it with [E] (cogs are items, see data/items.luau), and takes it back with
  [E]. Cogs put on pegs stay there (the flag "cog:<key>"). A `cog_fixed` is a cog bolted in place.
- `cog_output`: the wheel of a mechanism: when it turns the way its arrow says (`data.turn`, "cw" or "ccw"), what it
  opens opens, for good (`data.opens`, see switches.luau).

Cogs on cells side by side (not diagonally) turn each other, each one the opposite way of its neighbour. Two cogs on the
same shaft (`data.shaft`, a bronze rod across a gap) turn the same way. A train of cogs that can't all turn (two drives
fighting, a shaft against the meshing) jams: nothing in it turns. A drive whose breaker is thrown is a plain cog.
]]
const effects = require("./effects")
const inventory = require("./inventory")
const loader = require("@vectarine/loader")
const power = require("./power")
const switches = require("./switches")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

module.state = module.state or {
	--- How each cog turns: 1 clockwise, -1 counterclockwise, 0 still, by prop key
	spin = {} :: { [string]: number },
	jammed = {} :: { [string]: boolean },
	--- What the outputs did last time, to tell the player only when it changes
	outcome = {} :: { [string]: string },
}

local function message(game: types.Game, text: string)
	game.events[#game.events + 1] = { kind = "message", text = text }
end

--- Is there a cog on this peg (or drive, or output)?
function module.hasCog(game: types.Game, prop: types.Prop): boolean
	if prop.kind == "cog_drive" or prop.kind == "cog_output" or prop.kind == "cog_fixed" then
		return true
	end
	return prop.kind == "cog_peg" and (prop.data.fixed == true or game.flags[`cog:{prop.key}`] == true)
end

--- [E] on a peg: put a cog on it, or take it back
function module.usePeg(game: types.Game, prop: types.Prop)
	if prop.data.fixed then
		message(game, "This cog is bolted to its peg. It won't come off.")
		return
	end
	if game.flags[`cog:{prop.key}`] then
		game.flags[`cog:{prop.key}`] = nil
		inventory.give(game.player, "cog", 1)
		effects.burst(prop.cell + vec.V2(0.5, 0.5), "debris", 4)
		return
	end
	if not inventory.take(game.player, "cog", 1) then
		message(game, if game.flags.taughtCogs
			then "An empty peg. A cog would fit on it."
			else "An empty peg, next to other cogs. A loose cog would fit on it, if you had one.")
		return
	end
	game.flags[`cog:{prop.key}`] = true
	effects.burst(prop.cell + vec.V2(0.5, 0.5), "sparkle", 6)
	if not game.flags.taughtCogs then
		game.flags.taughtCogs = true
		message(game, "The cog clicks in place. Cogs side by side turn each other, each one the other way. [E] takes a cog back.")
	end
end

--- Turn the cogs of the level. Called every frame.
function module.update(game: types.Game)
	local state = module.state
	state.spin = {}
	state.jammed = {}
	local byCell: { [string]: types.Prop } = {}
	local shafts: { [string]: { types.Prop } } = {}
	local powered: { [string]: boolean } = {}
	local drives: { types.Prop } = {}
	local any = false
	for _, prop in game.level.props do
		if module.hasCog(game, prop) then
			byCell[`{prop.cell.x},{prop.cell.y}`] = prop
			any = true
			if prop.data.shaft then
				shafts[prop.data.shaft] = shafts[prop.data.shaft] or {}
				table.insert(shafts[prop.data.shaft], prop)
			end
			if prop.kind == "cog_drive" and not power.isOff(game, prop.data.breaker) then
				table.insert(drives, prop)
				powered[prop.key] = true
			end
		end
	end
	if not any then
		return
	end
	-- Spread the turning from each drive; a cog asked to turn both ways jams its whole train
	local visited: { [string]: boolean } = {}
	for _, drive in drives do
		if not visited[drive.key] then
			local train: { types.Prop } = {}
			local spin: { [string]: number } = {}
			local jam = false
			local queue = { drive }
			spin[drive.key] = 1
			visited[drive.key] = true
			while #queue > 0 do
				local prop = table.remove(queue, 1) :: types.Prop
				table.insert(train, prop)
				-- Neighbours turn the other way, cogs on the same shaft the same way
				local links: { { other: types.Prop, sign: number } } = {}
				for _, offset in { vec.V2(1, 0), vec.V2(-1, 0), vec.V2(0, 1), vec.V2(0, -1) } do
					local other = byCell[`{prop.cell.x + offset.x},{prop.cell.y + offset.y}`]
					if other then
						table.insert(links, { other = other, sign = -1 })
					end
				end
				local shaft: string? = prop.data.shaft
				for _, other in (if shaft then shafts[shaft] else {}) :: { types.Prop } do
					if other ~= prop then
						table.insert(links, { other = other, sign = 1 })
					end
				end
				for _, link in links do
					local other = link.other
					local wanted = spin[prop.key] * link.sign
					-- A running drive turns clockwise, whatever the train asks: if it asks otherwise, it jams
					if spin[other.key] == nil and powered[other.key] then
						spin[other.key] = 1
						visited[other.key] = true
						table.insert(queue, other)
					end
					if spin[other.key] == nil then
						spin[other.key] = wanted
						visited[other.key] = true
						table.insert(queue, other)
					elseif spin[other.key] ~= wanted then
						jam = true
					end
				end
			end
			for _, prop in train do
				state.spin[prop.key] = if jam then 0 else spin[prop.key]
				state.jammed[prop.key] = jam
			end
		end
	end
	-- The outputs: open what they open when they turn the right way
	for _, prop in game.level.props do
		if prop.kind == "cog_output" then
			local spin = state.spin[prop.key] or 0
			local wanted = if prop.data.turn == "ccw" then -1 else 1
			local outcome = if state.jammed[prop.key] then "jammed" elseif spin == wanted then "open" elseif spin ~= 0 then "wrong" else "still"
			local before = state.outcome[prop.key]
			state.outcome[prop.key] = outcome
			local opens: string = prop.data.opens or ""
			if outcome == "open" and opens ~= "" and switches.open(game, opens) then
				message(game, prop.data.text or "The wheel turns the right way. Chains rattle in the walls, and something opens.")
			elseif before ~= nil and before ~= outcome and not switches.isOpen(game, opens) then
				if outcome == "wrong" then
					message(game, "The wheel turns... the wrong way. Its arrow points the other way, and the mechanism groans.")
				elseif outcome == "jammed" then
					message(game, "Clank! The cogs bite into each other and lock: they can't all turn.")
				end
			end
		end
	end
end

return module
