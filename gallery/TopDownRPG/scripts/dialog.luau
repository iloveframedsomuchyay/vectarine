--[[
Dialog system: shows lines of text one after the other in a box at the bottom of the screen.

Usage:
	dialog.open(game, { name = "Morgane", sprite = "dungeon/fairy" }, {
		"Hello!",
		function(game) return game:giveItem("sword") end, -- shown as "You got the Sword!"
		"Good luck!",
	})

While a dialog is open, the game is paused and [Space] shows the next line.
See types.DialogStep for what a step can be.
]]
const audio = require("./audio")
const graphics = require("@vectarine/graphics")
const loader = require("@vectarine/loader")
const settings = require("./settings")
const sprites = require("./sprites")
const theme = require("./theme")
const types = require("./types")
const ui = require("@vectarine/ui")
const ui_components = require("./ui_components")
const vec = require("@vectarine/vec")

const module = loader.init() or {}

type DialogState = {
	game: types.Game,
	speaker: types.Speaker?,
	steps: { types.DialogStep },
	nextStep: number,
	--- Who says the current line. nil for narration lines (returned by function steps).
	lineSpeaker: types.Speaker?,
	text: string,
	--- Number of characters of `text` (not bytes: the writing of the sea people uses Greek letters)
	length: number,
	--- Number of characters of `text` currently visible (typewriter effect)
	shownChars: number,
	time: number,
	--- A choice to make on this line, and the option selected
	choice: types.DialogChoice?,
	selected: number,
}

module.current = module.current :: DialogState?

--- Go to the next line of text, running function steps along the way. Returns false when there is nothing left.
local function goToNextLine(state: DialogState): boolean
	while state.nextStep <= #state.steps do
		local step = state.steps[state.nextStep]
		state.nextStep += 1
		local text: string? = nil
		local speaker: types.Speaker? = nil
		state.choice = nil
		if type(step) == "string" then
			text = step
			speaker = state.speaker
		elseif type(step) == "table" then
			local choice = (step :: any) :: types.DialogChoice
			text = choice.question
			speaker = state.speaker
			state.choice = choice
			state.selected = 1
		else
			text = (step :: (any) -> string?)(state.game)
		end
		if text then
			state.text = text
			state.length = utf8.len(text) or #text
			state.lineSpeaker = speaker
			state.shownChars = 0
			return true
		end
	end
	return false
end

function module.open(game: types.Game, speaker: types.Speaker?, steps: { types.DialogStep })
	local state: DialogState = {
		game = game,
		speaker = speaker,
		steps = steps,
		nextStep = 1,
		text = "",
		length = 0,
		shownChars = 0,
		time = 0,
		choice = nil,
		selected = 1,
	}
	if goToNextLine(state) then
		module.current = state
	end
end

function module.isOpen(): boolean
	return module.current ~= nil
end

--- Is the current line still being typed?
function module.isTyping(): boolean
	local state = module.current
	return state ~= nil and state.shownChars < state.length
end

--- Show the full line if it is being typed, otherwise go to the next line (or close the dialog).
function module.advance()
	local state = module.current
	if not state then
		return
	end
	if module.isTyping() then
		state.shownChars = state.length
		return
	end
	-- A choice: run the option picked, then show what it says (or go on)
	local choice = state.choice
	if choice then
		state.choice = nil
		audio.cue("ui_select")
		local option = choice.options[state.selected]
		local said = option.run(state.game)
		if module.current ~= state then
			return -- the option closed the dialog (an ending starts)
		end
		if said then
			state.text = said
			state.length = utf8.len(said) or #said
			state.lineSpeaker = nil
			state.shownChars = 0
			return
		end
	end
	if not goToNextLine(state) then
		module.current = nil
	end
end

--- Is there a choice to make on the current line?
function module.isChoosing(): boolean
	local state = module.current
	return state ~= nil and state.choice ~= nil and not module.isTyping()
end

--- Move the selection of a choice up (-1) or down (1)
function module.select(step: number)
	local state = module.current
	local choice = if state then state.choice else nil
	if state and choice then
		state.selected = (state.selected - 1 + step) % #choice.options + 1
		audio.cue("ui_move")
	end
end

function module.close()
	module.current = nil
end

--- Letters typed between two blips of a voice
const VOICE_EVERY = 3

function module.update(dt: number)
	local state = module.current
	if state then
		state.time += dt
		local before = math.floor(state.shownChars)
		state.shownChars = math.min(state.length, state.shownChars + dt * settings.values.textSpeed)
		-- People speak in soft blips while their words appear (one every few letters); narration is silent
		local now = math.floor(state.shownChars)
		if state.lineSpeaker and now // VOICE_EVERY > before // VOICE_EVERY then
			audio.cue("voice", 0.7)
		end
	end
end

-- MARK: Drawing

module.BOX_SIZE = vec.V2(1.6, 0.44)
const PADDING = 0.035

module.widget = ui.widget(module.BOX_SIZE, function(_events, extra)
	local state = module.current
	if not state then
		return
	end
	local speaker = state.lineSpeaker
	local portraitSize = ui_components.square(0.2)
	local textWidth = module.BOX_SIZE.x - PADDING * 2 - (if speaker and speaker.sprite then portraitSize.x + PADDING else 0)

	local lines: { ui.Widget<any> } = {}
	-- The name of who speaks (narration has none: the text takes its place)
	if speaker then
		table.insert(lines, ui.text(speaker.name, {
			align = "left",
			font = theme.font,
			fontSize = 0.075,
			color = theme.colors.gold,
		}))
	end
	table.insert(lines, ui.text(string.sub(state.text, 1, (utf8.offset(state.text, math.floor(state.shownChars) + 1) or #state.text + 1) - 1), {
			align = "left",
			font = theme.font,
			fontSize = 0.07,
			color = theme.colors.text,
			maxWidth = textWidth,
			maxHeight = if state.choice then 0.16 else 0.26,
		}))
	-- The options of a choice, the selected one marked
	local choice = state.choice
	if choice and not module.isTyping() then
		for i, option in choice.options do
			local selected = i == state.selected
			local label: string = `{if selected then "> " else "  "}{option.label}`
			table.insert(lines, ui.text(label, {
				align = "left",
				font = theme.font,
				fontSize = 0.065,
				color = if selected then theme.colors.gold else theme.colors.textDim,
			} :: any))
		end
	end
	local textColumn = ui.column({ gap = 0.02 }, lines)

	local content: { ui.Widget<any> } = {}
	local sprite: string? = if speaker then speaker.sprite else nil
	if sprite then
		table.insert(
			content,
			ui.widget(portraitSize, function()
				sprites.draw(sprite, vec.V2(-1, -1), portraitSize)
			end)
		)
	end
	table.insert(content, textColumn)

	-- The box grows upwards when a long question and its options don't fit in it
	local row = ui.row({ padding = PADDING, gap = PADDING, align = "end" }, content)
	local boxSize = vec.V2(module.BOX_SIZE.x, math.max(module.BOX_SIZE.y, row:size(extra).y))
	ui.stack({ alignX = "start", alignY = "end" }, {
		ui_components.panel(boxSize),
		row,
	}):draw(extra)

	-- Blinking arrow telling the player that they can continue.
	if not module.isTyping() and not state.choice and math.floor(state.time * 2.5) % 2 == 0 then
		local tip = vec.V2(-1 + module.BOX_SIZE.x - PADDING * 1.5, -1 + PADDING * 1.2)
		graphics.drawPolygon({
			tip,
			tip + vec.V2(0.02, 0.035),
			tip + vec.V2(-0.02, 0.035),
		}, theme.colors.gold)
	end
end)

return module
