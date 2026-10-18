--[[
Sound: the effects, the music and the ambience of the levels (data/sounds.luau, data/sound_effects.luau; the files are
made by the scripts of tools/sound).

- Effects are cues, like the visual effects (effects.luau): `audio.cue("swing")`, or `audio.cueAt(game, "hit", pos)`
  for a sound that is quieter far from the player. They never change the game, and pick their variant in turn (never
  with math.random: the tests share its sequence).
- The engine plays each sound file once at a time: playing it again while it plays does nothing. So every effect has
  variants, and a cue plays the next one that is free. It also keeps a repeated sound from sounding the same.
- One music and one ambience at a time, chosen by the level (its floor, or its own `music` and `ambience`), crossfaded
  when it changes. A track is loaded the first time it plays, and starts once loaded.
- The volumes of the settings (0 to 100) apply to everything, at once.

The engine resamples nothing: every file must be 48 kHz stereo (tools/sound/check.py checks them).
]]
const level = require("./level")
const levels = require("./data/levels")
const loader = require("@vectarine/loader")
const settings = require("./settings")
const sound_effects = require("./data/sound_effects")
const sounds = require("./data/sounds")
const types = require("./types")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

--- Crossfade between two tracks, in milliseconds
const CROSSFADE = 1500
--- Distance (tiles) at which a sound starts getting quieter, and at which it can't be heard anymore
const NEAR, FAR = 4, 14
--- Tiles walked between two footsteps
const STRIDE = 0.95

type Playing = { name: string, resource: any, volume: number }
--- The variants of an effect (loaded when the game starts), and the next one to try
type Effect = { resources: { any }, next: number }

module.state = module.state
	or {
		--- Effects, by name: their variants (loaded when the game starts) and the next one to try
		effects = {} :: { [string]: Effect },
		--- Tracks loaded so far, by "music/name" or "ambience/name"
		tracks = {} :: { [string]: any },
		music = nil :: Playing?,
		ambience = nil :: Playing?,
		walked = 0,
		lastPos = nil :: vec.Vec2?,
	}

--- Everything at half: at 100% the sounds were much too loud
const MASTER = 0.5

--- A volume of the settings (0 to 100) as a gain. The ear hears loudness as a ratio, so the setting is squared: 10% is
--- really quiet, 50% about half as loud as 100%.
local function gain(setting: number): number
	local fraction = math.clamp(setting / 100, 0, 1)
	return MASTER * fraction * fraction
end

local function soundVolume(): number
	return gain(settings.values.soundVolume)
end

local function musicVolume(): number
	return gain(settings.values.musicVolume)
end

local function effect(name: string): Effect?
	local loaded: Effect? = module.state.effects[name]
	if loaded then
		return loaded
	end
	local spec = sound_effects[name]
	if not spec then
		return nil
	end
	local resources: { any } = {}
	for i = 1, spec.variants do
		resources[i] = loader.loadAudio(`audio/sfx/{name}_{i}.mp3`)
	end
	local created: Effect = { resources = resources, next = 1 }
	module.state.effects[name] = created
	return created
end

--- Load every effect now, so that the first cue of each one is heard
function module.preload()
	for name in sound_effects do
		effect(name)
	end
end

--- Play a sound effect (`volume`: 0 to 1, on top of its own volume and of the settings)
function module.cue(name: string, volume: number?)
	local spec = sound_effects[name]
	local loaded = effect(name)
	local gain = soundVolume() * (volume or 1)
	if not spec or not loaded or gain <= 0.001 then
		return
	end
	local count = #loaded.resources
	for attempt = 0, count - 1 do
		local index = (loaded.next + attempt - 1) % count + 1
		local resource = loaded.resources[index]
		if resource:isReady() and not resource:isPlaying() then
			resource:setVolume(spec.volume * gain)
			-- A short fade in: the engine's default (100 ms) would soften the attack of a hit
			resource:play(false, 2)
			loaded.next = index % count + 1
			return
		end
	end
end

--- Play a sound effect made at `pos`: quieter far from the player, silent out of earshot
function module.cueAt(game: types.Game, name: string, pos: vec.Vec2, volume: number?)
	local distance = (pos - game.player.pos):length()
	local falloff = 1 - math.clamp((distance - NEAR) / (FAR - NEAR), 0, 1)
	if falloff > 0 then
		module.cue(name, (volume or 1) * falloff)
	end
end

-- MARK: Music and ambience

local function track(kind: string, name: string): any
	local key = `{kind}/{name}`
	local resource = module.state.tracks[key]
	if not resource then
		resource = loader.loadAudio(`audio/{kind}/{name}.mp3`)
		module.state.tracks[key] = resource
	end
	return resource
end

--- Switch the music or the ambience to `name` (nil: silence), crossfading. Waits for the new track to be loaded.
local function switch(kind: "music" | "ambience", name: string?)
	local state = module.state
	local current: Playing? = if kind == "music" then state.music else state.ambience
	local list = if kind == "music" then sounds.music else sounds.ambience
	if name and not list[name] then
		name = nil
	end
	if (current and current.name) == name then
		return
	end
	local resource = if name then track(kind, name) else nil
	if resource and not resource:isReady() then
		return -- update() tries again every frame
	end
	if current then
		current.resource:pause(CROSSFADE)
	end
	local playing: Playing? = nil
	if resource and name then
		local volume = list[name].volume
		resource:setVolume(volume * musicVolume())
		resource:play(true, CROSSFADE)
		playing = { name = name, resource = resource, volume = volume }
	end
	if kind == "music" then
		state.music = playing
	else
		state.ambience = playing
	end
end

--- What the level wants to hear: its own music and ambience, or its floor's ("none" is silence)
local function wanted(game: types.Game, field: "music" | "ambience"): string?
	local data = levels.levels[game.levelId]
	local own: string? = if not data then nil elseif field == "music" then data.music else data.ambience
	if own then
		return if own == "none" then nil else own
	end
	local floor = sounds.floors[game.level.depth]
	if not floor then
		return nil
	end
	return if field == "music" then floor.music else floor.ambience
end

--- Stop the music and the ambience (the title screen, the endings)
function module.silence()
	switch("music", nil)
	switch("ambience", nil)
end

-- MARK: Footsteps

local function footstep(game: types.Game)
	local player = game.player
	local cell = level.cellOf(player.pos)
	local ground = level.groundAt(game.level :: any, cell.x, cell.y)
	local material = (ground and sounds.footsteps[ground.name]) or "dirt"
	module.cue(`step_{material}`)
end

--- Every frame of play: the tracks of the level, the volumes of the settings, the footsteps of the player
function module.update(game: types.Game)
	local state = module.state
	switch("music", wanted(game, "music"))
	switch("ambience", wanted(game, "ambience"))
	for _, playing in { state.music, state.ambience } do
		if playing then
			local volume = playing.volume * musicVolume()
			if math.abs(playing.resource:getVolume() - volume) > 0.001 then
				playing.resource:setVolume(volume)
			end
		end
	end
	-- Footsteps: one every stride walked (not when pushed, carried or teleported)
	local pos = game.player.pos
	local last = state.lastPos
	state.lastPos = pos
	if last then
		local moved = (pos - last):length()
		if moved < 0.5 and game.player.velocity:length() > 0.5 then
			state.walked += moved
			if state.walked >= STRIDE then
				state.walked = 0
				footstep(game)
			end
		end
	end
end

-- The effects are small: they load with the game, so that the first cue of each one is heard
module.preload()

return module
