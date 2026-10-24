--[[
Big texts drawn over the game: the title card of a new place, announcements (level up, artefact found),
the death screen and the end of the floor.
]]
const graphics = require("@vectarine/graphics")
const loader = require("@vectarine/loader")
const sprites = require("./sprites")
const theme = require("./theme")
const ui_components = require("./ui_components")
const vec = require("@vectarine/vec")
const vec4 = require("@vectarine/vec4")

const module = loader.init() or {}

--- Centered text with a shadow
function module.drawCentered(text: string, center: vec.Vec2, size: number, color: vec4.Vec4, shadow: vec4.Vec4?)
	local width = theme.font:measureText(text, size).width
	local pos = vec.V2(center.x - width / 2, center.y - size / 2)
	theme.font:drawText(text, pos + vec.V2(0.006, -0.009), size, shadow or theme.withAlpha(vec4.BLACK, color.a * 0.8))
	theme.font:drawText(text, pos, size, color)
end

--- The name of a place, shown for a moment after entering it. `t` is the time since entering.
--- How long a title card stays on screen, in seconds
module.TITLE_DURATION = 3

function module.drawTitleCard(title: string, subtitle: string, center: vec.Vec2, t: number)
	local alpha = math.min(1, t / 0.4) * math.clamp((module.TITLE_DURATION - t) / 0.7, 0, 1)
	if alpha <= 0 then
		return
	end
	local lineWidth = 0.5 * math.min(1, t / 0.5)
	graphics.drawRect(vec.V2(center.x - lineWidth / 2, center.y - 0.075), vec.V2(lineWidth, 0.006), theme.withAlpha(theme.colors.gold, alpha))
	module.drawCentered(title, center + vec.V2(0, 0.02), 0.15, theme.withAlpha(theme.colors.text, alpha))
	module.drawCentered(subtitle, center + vec.V2(0, -0.14), 0.07, theme.withAlpha(theme.colors.gold, alpha))
end

--- A banner announcing something (level up, artefact found...), with an optional icon
function module.drawBanner(title: string, subtitle: string, icon: string?, t: number, duration: number)
	local appear = math.min(1, t / 0.3)
	local alpha = math.clamp((duration - t) / 0.4, 0, 1) * appear
	if alpha <= 0 then
		return
	end
	local height = 0.36
	graphics.drawRect(vec.V2(-1, 0.25), vec.V2(2, height), theme.withAlpha(theme.colors.darkness, 0.75 * alpha))
	local scale = 0.6 + 0.4 * appear + math.sin(appear * math.pi) * 0.15
	local center = vec.V2(0, 0.25 + height / 2)
	if icon then
		local size = ui_components.square(0.2 * scale)
		sprites.draw(icon, vec.V2(-size.x / 2, center.y + 0.02), size, theme.withAlpha(vec4.WHITE, alpha))
	end
	local textCenter = if icon then center + vec.V2(0, -0.05) else center + vec.V2(0, 0.03)
	module.drawCentered(title, textCenter, 0.12 * scale, theme.withAlpha(theme.colors.gold, alpha))
	module.drawCentered(subtitle, textCenter + vec.V2(0, -0.1), 0.055, theme.withAlpha(theme.colors.text, alpha))
end

--- Widest line of a message, in screen units (the screen is 2 wide): longer messages go on several lines
const MESSAGE_WIDTH = 1.75

--- Split a text into lines that fit in `width`, at spaces
local function wrap(text: string, size: number, width: number): { string }
	local lines: { string } = {}
	local current = ""
	for word in string.gmatch(text, "%S+") do
		local candidate = if current == "" then word else `{current} {word}`
		if current ~= "" and theme.font:measureText(candidate, size).width > width then
			table.insert(lines, current)
			current = word
		else
			current = candidate
		end
	end
	if current ~= "" then
		table.insert(lines, current)
	end
	return lines
end

--- A paragraph centered on `center`, wrapped to `width`
function module.drawWrapped(text: string, center: vec.Vec2, size: number, width: number, color: any)
	local lines = wrap(text, size, width)
	local lineHeight = size * 1.25
	local top = center.y + lineHeight * (#lines - 1) / 2
	for i, line in lines do
		module.drawCentered(line, vec.V2(center.x, top - (i - 1) * lineHeight), size, color)
	end
end

--- A short message at the bottom of the world (an item picked up, a door that is locked...)
function module.drawMessage(text: string, bottom: number, t: number, duration: number)
	local alpha = math.min(1, t / 0.15) * math.clamp((duration - t) / 0.4, 0, 1)
	if alpha <= 0 then
		return
	end
	local size = 0.06
	local lines = wrap(text, size, MESSAGE_WIDTH)
	local width = 0
	for _, line in lines do
		width = math.max(width, theme.font:measureText(line, size).width)
	end
	local lineHeight = size * 1.15
	local height = size * 0.35 + lineHeight * #lines
	local pos = vec.V2(-width / 2 - 0.03, bottom + 0.03)
	graphics.drawRect(pos, vec.V2(width + 0.06, height), theme.withAlpha(theme.colors.panel, alpha))
	for i, line in lines do
		local lineWidth = theme.font:measureText(line, size).width
		local y = pos.y + height - size * 0.1 - lineHeight * i + size * 0.2
		theme.font:drawText(line, vec.V2(-lineWidth / 2, y), size, theme.withAlpha(theme.colors.text, alpha))
	end
end

function module.drawFainted(t: number)
	local alpha = math.clamp(t / 0.8, 0, 1)
	graphics.drawRect(vec.V2(-1, -1), vec.V2(2, 2), theme.withAlpha(theme.colors.darkness, alpha * 0.85))
	module.drawCentered("You fainted...", vec.V2(0, 0.08), 0.13, theme.withAlpha(theme.colors.text, alpha))
	module.drawCentered("You wake up by the last fire you rested at.", vec.V2(0, -0.06), 0.055, theme.withAlpha(theme.colors.textDim, alpha))
end

--- The end of the last floor built: the stairs of the toxic fen go down to the frosted frontier
function module.drawFloorEnd(t: number)
	local alpha = math.clamp(t / 1.2, 0, 1)
	graphics.drawRect(vec.V2(-1, -1), vec.V2(2, 2), theme.withAlpha(theme.colors.darkness, alpha))
	module.drawCentered("The Frosted Frontier", vec.V2(0, 0.25), 0.2, theme.withAlpha(theme.colors.gold, alpha))
	module.drawCentered("The stairs go down, and the air turns cold. Frost on the steps.", vec.V2(0, 0.05), 0.065, theme.withAlpha(theme.colors.text, alpha))
	module.drawCentered("The fourth floor of the Explorium is still to be dug.", vec.V2(0, -0.05), 0.055, theme.withAlpha(theme.colors.textDim, alpha))
	module.drawCentered("This is where the template ends - and your game begins.", vec.V2(0, -0.15), 0.055, theme.withAlpha(theme.colors.textDim, alpha))
end

return module
