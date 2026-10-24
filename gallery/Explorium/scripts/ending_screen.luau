--[[
Plays an ending (see endings.luau): the shots of the cut-scene in the game's own rendering, with their captions and the
camera gliding, then the epilogue cards, then the end and the summary of the journey.

The game screen (game_screen.luau) gives it its flow while the ending plays: `update` moves time on, `skip` jumps to the
next caption or card (Space), `draw` draws it. `update` returns true once the player has left the last screen.
]]
const endings = require("./endings")
const graphics = require("@vectarine/graphics")
const loader = require("@vectarine/loader")
const overlays = require("./overlays")
const theme = require("./theme")
const types = require("./types")
const vec = require("@vectarine/vec")
const world_view = require("./world_view")

const module = loader.init() or {}

export type State = {
	ending: string,
	stage: string,
	--- Index of the shot (stage "shots") or of the card (stage "cards")
	index: number,
	t: number,
	view: types.Game?,
	cards: { endings.Card },
	summary: { string },
	--- Seconds of fading to black between two shots
	fade: number,
}

--- Seconds each epilogue card stays, and the fades
const CARD_TIME = 7.5
const FADE = 0.8

function module.start(game: types.Game, id: string): State
	local ending = endings.endings[id]
	local cards = endings.epilogue(game)
	table.insert(cards, ending.final)
	return {
		ending = id,
		stage = "shots",
		index = 1,
		t = 0,
		view = endings.shotGame(game, ending.shots[1]),
		cards = cards,
		summary = endings.summary(game),
		fade = 0,
	}
end

local function shotDuration(shot: endings.Shot): number
	return #shot.captions * endings.CAPTION_TIME
end

local function nextShot(game: types.Game, state: State)
	local ending = endings.endings[state.ending]
	state.index += 1
	state.t = 0
	if state.index > #ending.shots then
		state.stage = "cards"
		state.index = 1
		state.view = nil
	else
		state.view = endings.shotGame(game, ending.shots[state.index])
	end
end

--- Move time on. Returns true when the ending is over (the player pressed a key on the last screen).
function module.update(game: types.Game, state: State, dt: number)
	state.t += dt
	if state.stage == "shots" then
		local shot = endings.endings[state.ending].shots[state.index]
		if state.t >= shotDuration(shot) then
			nextShot(game, state)
		end
	elseif state.stage == "cards" then
		if state.t >= CARD_TIME then
			state.index += 1
			state.t = 0
			if state.index > #state.cards then
				state.stage = "end"
			end
		end
	end
end

--- Space: the next caption, the next card. Returns true when the ending is over.
function module.skip(game: types.Game, state: State): boolean
	if state.stage == "shots" then
		local shot = endings.endings[state.ending].shots[state.index]
		local caption = math.floor(state.t / endings.CAPTION_TIME) + 1
		if caption >= #shot.captions then
			nextShot(game, state)
		else
			state.t = caption * endings.CAPTION_TIME
		end
	elseif state.stage == "cards" then
		state.t = CARD_TIME
		module.update(game, state, 0)
	elseif state.stage == "end" and state.t > 1.5 then
		return true
	end
	return false
end

-- MARK: Drawing

local function drawCaption(text: string, bottom: number, alpha: number)
	local size = 0.065
	graphics.drawRect(vec.V2(-1, bottom), vec.V2(2, 0.2), theme.withAlpha(theme.colors.darkness, 0.75 * alpha))
	overlays.drawWrapped(text, vec.V2(0, bottom + 0.1), size, 1.7, theme.withAlpha(theme.colors.text, alpha))
end

function module.draw(state: State, world: world_view.Viewport, time: number)
	graphics.clear(theme.colors.darkness)
	if state.stage == "shots" and state.view then
		local ending = endings.endings[state.ending]
		local shot = ending.shots[state.index]
		local duration = shotDuration(shot)
		local progress = math.clamp(state.t / duration, 0, 1)
		local eased = progress * progress * (3 - 2 * progress)
		local focus = vec.V2(shot.from[1], shot.from[2]):lerp(vec.V2(shot.to[1], shot.to[2]), eased) + vec.V2(0.5, 0.5)
		local visible = world_view.visibleTiles(world)
		world_view.camera = focus - visible:scale(0.5)
		world_view.drawWorld(state.view, world, { time = time, darkness = false })
		-- Fading in and out of each shot
		local alpha = math.min(1, state.t / FADE, (duration - state.t) / FADE)
		graphics.drawRect(vec.V2(-1, -1), vec.V2(2, 2), theme.withAlpha(theme.colors.darkness, 1 - math.clamp(alpha, 0, 1)))
		local caption = math.min(#shot.captions, math.floor(state.t / endings.CAPTION_TIME) + 1)
		local local_t = state.t - (caption - 1) * endings.CAPTION_TIME
		local captionAlpha = math.clamp(math.min(local_t / 0.5, (endings.CAPTION_TIME - local_t) / 0.5), 0, 1)
		drawCaption(shot.captions[caption], world.pos.y + 0.05, captionAlpha)
	elseif state.stage == "cards" then
		local card = state.cards[state.index]
		local alpha = math.clamp(math.min(state.t / FADE, (CARD_TIME - state.t) / FADE), 0, 1)
		overlays.drawCentered(card.title, vec.V2(0, 0.32), 0.12, theme.withAlpha(theme.colors.gold, alpha))
		overlays.drawWrapped(card.text, vec.V2(0, 0.1), 0.07, 1.5, theme.withAlpha(theme.colors.text, alpha))
	else
		local alpha = math.clamp(state.t / 1.5, 0, 1)
		local ending = endings.endings[state.ending]
		overlays.drawCentered("The End", vec.V2(0, 0.55), 0.2, theme.withAlpha(theme.colors.gold, alpha))
		overlays.drawCentered(ending.name, vec.V2(0, 0.38), 0.08, theme.withAlpha(theme.colors.text, alpha))
		for i, line in state.summary do
			overlays.drawCentered(line, vec.V2(0, 0.18 - i * 0.09), 0.065, theme.withAlpha(theme.colors.textDim, alpha))
		end
		overlays.drawCentered("Thank you for playing Explorium.", vec.V2(0, -0.48), 0.07, theme.withAlpha(theme.colors.text, alpha))
		if state.t > 1.5 and math.floor(state.t * 2) % 2 == 0 then
			overlays.drawCentered("Space: back to the title screen", vec.V2(0, -0.62), 0.05, theme.colors.textDim)
		end
	end
end

return module
