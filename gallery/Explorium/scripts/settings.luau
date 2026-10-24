--[[
Player settings. They are saved to disk (or to the browser storage on the web) using `persist`,
so they are kept when the game is restarted.
]]
const io = require("@vectarine/io")
const loader = require("@vectarine/loader")
const persist = require("@vectarine/persist")

export type Settings = {
	--- Show the keyboard hints in the bottom-left corner
	showPrompts: boolean,
	--- Characters per second of the dialog typewriter effect
	textSpeed: number,
	fullscreen: boolean,
	screenShake: boolean,
	--- Volumes, from 0 (off) to 100: the music and the ambiences, and the sound effects
	musicVolume: number,
	soundVolume: number,
}

const module = loader.init() or {}

const SAVE_NAME = "top_down_rpg.settings"

const defaults: Settings = {
	showPrompts = true,
	textSpeed = 45,
	fullscreen = false,
	screenShake = true,
	musicVolume = 70,
	soundVolume = 80,
}

local function loadSettings(): Settings
	local saved = persist.load(SAVE_NAME)
	local values = table.clone(defaults)
	if type(saved) == "table" then
		for key, value in saved :: { [string]: any } do
			if (values :: any)[key] ~= nil and type(value) == type((values :: any)[key]) then
				(values :: any)[key] = value
			end
		end
	end
	return values
end

module.values = module.values or loadSettings() :: Settings

function module.save()
	persist.save(SAVE_NAME, module.values)
end

--- Change a volume by `step` (in steps of 10, from 0 to 100)
function module.changeVolume(key: "musicVolume" | "soundVolume", step: number)
	module.values[key] = math.clamp(module.values[key] + step * 10, 0, 100)
	module.save()
end

--- A volume as the menus show it
function module.volumeLabel(value: number): string
	return if value <= 0 then "Off" else `{value}%`
end

function module.toggleFullscreen()
	module.values.fullscreen = not module.values.fullscreen
	io.setFullscreen(module.values.fullscreen)
	module.save()
end

return module
