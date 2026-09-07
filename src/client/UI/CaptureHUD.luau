--!strict
-- The capture readout: what you are catching, how far along you are, whether
-- you are in range, and why you just lost progress.
--
-- It sits low on the screen and never covers the middle, because the middle is
-- where the hazards are. The hazard warning is the biggest text in the game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)

local CaptureHUD = {}

type TargetInfo = {
	uid: any,
	name: string,
	rarity: string,
	element: string,
	difficulty: number,
	claimedBy: number?,
	hint: string?, -- names a control that exists on this device (CaptureController decides)
}

local gui: ScreenGui? = nil
local targetCard: Frame? = nil
local targetName: TextLabel? = nil
local targetMeta: TextLabel? = nil
local targetHint: TextLabel? = nil
local captureCard: Frame? = nil
local captureName: TextLabel? = nil
local progress: any = nil
local rangeLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local perfectBadge: TextLabel? = nil
local surgeBadge: TextLabel? = nil
local timerLabel: TextLabel? = nil
local warningLabel: TextLabel? = nil
local cancelButton: TextButton? = nil

local lastState: Types.CaptureState? = nil

function CaptureHUD.init()
	local g = W.screenGui("CatchCaptureHUD", 4)
	W.attachScale(g)
	gui = g
	local safe = W.safeArea(g)

	-- ---------------------------------------------------------------- warning
	-- Centred text on a dark pill: bare outlined text was left-aligned inside a
	-- centred frame (so it sat off to one side) and was hard to read over the sky.
	warningLabel = W.label({
		parent = safe,
		name = "HazardWarning",
		text = "",
		size = UDim2.new(0, 720, 0, 58),
		position = UDim2.new(0.5, 0, 0, 96),
		anchor = Vector2.new(0.5, 0),
		textSize = 28,
		font = Theme.fonts.title,
		color = Theme.colors.warn,
		xalign = Enum.TextXAlignment.Center,
		wrap = true,
		bg = Theme.colors.bg,
		radius = Theme.sizes.radius,
		strokeText = true,
		zindex = 6,
	})
	warningLabel.BackgroundTransparency = 0.25
	warningLabel.Visible = false
	W.padding(warningLabel, { left = 16, right = 16 })

	-- ---------------------------------------------------------------- target card
	local card = W.frame({
		parent = safe,
		name = "TargetCard",
		size = UDim2.new(0, 330, 0, 108),
		position = UDim2.new(0.5, 0, 1, -168),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		visible = false,
	})
	targetCard = card
	targetName = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -20, 0, 30),
		position = UDim2.new(0, 10, 0, 8),
		textSize = 22,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
	})
	targetMeta = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -20, 0, 22),
		position = UDim2.new(0, 10, 0, 38),
		textSize = 15,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	targetHint = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -20, 0, 26),
		position = UDim2.new(0, 10, 0, 68),
		textSize = 16,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})

	-- ---------------------------------------------------------------- capture card
	local cap = W.frame({
		parent = safe,
		name = "CaptureCard",
		size = UDim2.new(0, 420, 0, 150),
		position = UDim2.new(0.5, 0, 1, -150),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		visible = false,
	})
	captureCard = cap
	captureName = W.label({
		parent = cap,
		text = "",
		size = UDim2.new(1, -110, 0, 28),
		position = UDim2.new(0, 12, 0, 8),
		textSize = 21,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
	})
	timerLabel = W.label({
		parent = cap,
		text = "",
		size = UDim2.new(0, 90, 0, 28),
		position = UDim2.new(1, -12, 0, 8),
		anchor = Vector2.new(1, 0),
		textSize = 17,
		font = Theme.fonts.bold,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Right,
	})
	progress = W.progress(cap, UDim2.new(1, -24, 0, 26), Theme.colors.success, nil, UDim2.new(0, 12, 0, 42))
	rangeLabel = W.label({
		parent = cap,
		text = "",
		size = UDim2.new(0.5, -12, 0, 22),
		position = UDim2.new(0, 12, 0, 74),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.success,
		xalign = Enum.TextXAlignment.Left,
	})
	statusLabel = W.label({
		parent = cap,
		text = "",
		size = UDim2.new(1, -24, 0, 22),
		position = UDim2.new(0, 12, 0, 96),
		textSize = 15,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})

	local badgeRow = W.frame({
		parent = cap,
		size = UDim2.new(0, 190, 0, 22),
		position = UDim2.new(1, -12, 0, 74),
		anchor = Vector2.new(1, 0),
		transparency = 1,
	})
	W.list(badgeRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	perfectBadge = W.badge(badgeRow, "PERFECT", Theme.colors.gold, 1)
	surgeBadge = W.badge(badgeRow, "SURGE", Theme.colors.overdrive, 2)

	cancelButton = W.button({
		parent = cap,
		name = "Cancel",
		text = "Cancel",
		size = UDim2.new(0, 96, 0, 32),
		position = UDim2.new(1, -12, 1, -8),
		anchor = Vector2.new(1, 1),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 16,
		onClick = function()
			Net.fire("CancelCapture")
		end,
	})

	CaptureHUD.setState(nil)
	CaptureHUD.setTarget(nil)
	CaptureHUD.setHazardWarning(nil, nil)
end

function CaptureHUD.setHazardWarning(text: string?, color: Color3?)
	if not warningLabel then
		return
	end
	warningLabel.Text = text or ""
	warningLabel.TextColor3 = color or Theme.colors.warn
	-- the pill only exists while there is a warning to read
	warningLabel.Visible = text ~= nil and text ~= ""
end

function CaptureHUD.setTarget(info: TargetInfo?)
	if not targetCard then
		return
	end
	-- while capturing, the capture card replaces the target card
	if lastState then
		targetCard.Visible = false
		return
	end
	if not info then
		targetCard.Visible = false
		return
	end
	targetCard.Visible = true
	if targetName then
		targetName.Text = info.name
		targetName.TextColor3 = Config.Rarities.color(info.rarity)
	end
	if targetMeta then
		local stars = string.rep("*", info.difficulty) .. string.rep("-", math.max(0, 5 - info.difficulty))
		targetMeta.Text = Config.Rarities.label(info.rarity) .. "   " .. info.element .. "   Difficulty " .. stars
	end
	if targetHint then
		if info.claimedBy then
			targetHint.Text = "Someone is already catching this one"
			targetHint.TextColor3 = Theme.colors.danger
		else
			targetHint.Text = info.hint or "Press E"
			targetHint.TextColor3 = Theme.colors.accent
		end
	end
end

function CaptureHUD.setState(state: Types.CaptureState?)
	lastState = state
	if not captureCard then
		return
	end
	if not state then
		captureCard.Visible = false
		CaptureHUD.setHazardWarning(nil, nil)
		return
	end
	captureCard.Visible = true
	if targetCard then
		targetCard.Visible = false
	end

	local def = Config.Species.byId[state.speciesId]
	if captureName and def then
		captureName.Text = "Catching " .. def.name
		captureName.TextColor3 = Config.Rarities.color(def.rarity)
	end

	if progress then
		local fraction = if state.required > 0 then state.progress / state.required else 0
		progress.set(fraction, ("%.1f"):format(state.progress) .. " / " .. ("%.1f"):format(state.required) .. "s")
		progress.fill.BackgroundColor3 = if state.inRange then Theme.colors.success else Theme.colors.danger
	end

	if rangeLabel then
		if state.inRange then
			rangeLabel.Text = "In range"
			rangeLabel.TextColor3 = Theme.colors.success
		else
			rangeLabel.Text = ("Out of range! %.1fs"):format(math.max(0, Config.Capture.outOfRangeGrace - state.outOfRangeFor))
			rangeLabel.TextColor3 = Theme.colors.danger
		end
	end

	if statusLabel then
		statusLabel.Text = state.status
		statusLabel.TextColor3 = if state.hits > 0 and string.find(state.status, "-") then Theme.colors.danger else Theme.colors.textDim
	end

	if timerLabel then
		local left = math.max(0, state.expiresAt - State.now())
		timerLabel.Text = ("%.0fs left"):format(left)
		timerLabel.TextColor3 = if left < 10 then Theme.colors.danger else Theme.colors.textDim
	end

	if perfectBadge then
		perfectBadge.Visible = state.perfect
	end
	if surgeBadge then
		surgeBadge.Visible = state.surge
	end
	if cancelButton then
		cancelButton.Visible = true
	end
end

-- Keeps the countdown honest between server pushes.
function CaptureHUD.update(_snapshot: any)
	if lastState and timerLabel then
		local left = math.max(0, lastState.expiresAt - State.now())
		timerLabel.Text = ("%.0fs left"):format(left)
		timerLabel.TextColor3 = if left < 10 then Theme.colors.danger else Theme.colors.textDim
	end
end

return CaptureHUD
