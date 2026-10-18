local Resource = require("@vectarine/resource")

local module = {}

local AudioResourceImpl = { type = "audio" }
AudioResourceImpl.__index = AudioResourceImpl
export type AudioResource = typeof(setmetatable({}, AudioResourceImpl)) & Resource.Resource

--- Play an audio resource from its beginning.
--- If loop is true, the audio will loop indefinitely.
--- `fadeIn`: milliseconds over which the volume rises from silence (default: 100 when starting, 0 when resuming).
---
--- A sound plays once at a time: playing it while it plays does nothing. Use pause and resume for that.
function AudioResourceImpl.play(self: AudioResource, loop: boolean?, fadeIn: number?): ()
	error("Implemented in native code")
end

--- Returns true if the audio resource is currently playing.
function AudioResourceImpl.isPlaying(self: AudioResource): boolean
	error("Implemented in native code")
end

--- Returns the duration of the audio resource in seconds.
function AudioResourceImpl.getDuration(self: AudioResource): number
	error("Implemented in native code")
end

--- Returns the current progress of the audio resource in seconds.
--- This is a number between 0 and the duration.
function AudioResourceImpl.getProgress(self: AudioResource): number
	error("Implemented in native code")
end

--- Stop an audio resource.
--- If fadeOut is provided, the audio will fade out over that many milliseconds (it counts as playing until then).
--- Does nothing if the audio is not playing.
function AudioResourceImpl.pause(self: AudioResource, fadeOut: number?): ()
	error("Implemented in native code")
end

--- Play a paused audio resource again from where it was.
--- If fadeIn is provided, the volume rises from silence over that many milliseconds.
function AudioResourceImpl.resume(self: AudioResource, fadeIn: number?): ()
	error("Implemented in native code")
end

function AudioResourceImpl.setVolume(self: AudioResource, volume: number): ()
	error("Implemented in native code")
end

function AudioResourceImpl.getVolume(self: AudioResource): number
	error("Implemented in native code")
end

return module
