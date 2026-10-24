--[[
God mode, to test the game quickly and skip to the end: the player takes no damage (health, poison, cold, shocks,
stuns), moves fast and kills any creature in one hit.

It is the global boolean GOD_MODE, off by default and never saved. Toggle it:
- in the Watcher of the editor (it is a global),
- with the console command "god",
- from a test: `explorium.debug.god(true)`.
]]
const loader = require("@vectarine/loader")
const types = require("./types")

const module = loader.init() or {}

--- How much faster the player moves
module.SPEED = 2.5

if _G.GOD_MODE == nil then
	_G.GOD_MODE = false
end

function module.isOn(): boolean
	return _G.GOD_MODE == true
end

function module.set(on: boolean)
	_G.GOD_MODE = on
end

--- Undo whatever hurt the player: called before and after each update of the game, so that nothing (the cold, the
--- thirst, poison, a shock) can bring them down in between
function module.protect(game: types.Game, maxHp: number)
	if not module.isOn() then
		return
	end
	local player = game.player
	player.hp = maxHp
	player.poison = 0
	player.stun = 0
	player.warmth = 100
end

return module
