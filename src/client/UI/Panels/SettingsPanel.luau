--!strict
-- "Settings": volume sliders, the accessibility toggles the spec requires,
-- the save status, and a short controls guide so nobody has to guess.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)
local BuildInfo = require(ReplicatedStorage.Shared.Util.BuildInfo)

type Snapshot = Types.Snapshot

local M = {}

local built = false
local gui: ScreenGui
local panel: any
local sliders: { [string]: any } = {}
local toggles: { [string]: TextButton } = {}
local dataLabel: TextLabel
local buildLabel: TextLabel? = nil

-- A slider Widgets does not provide: a track, a fill and a draggable knob.
local function makeSlider(parent: Instance, key: string, title: string, order: number): any
	local card = W.card(parent, 62)
	card.LayoutOrder = order
	W.label({
		parent = card,
		text = title,
		size = UDim2.new(1, -80, 0, 20),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 14,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	local valueLabel = W.label({
		parent = card,
		size = UDim2.new(0, 60, 0, 20),
		position = UDim2.new(1, -10, 0, 6),
		anchor = Vector2.new(1, 0),
		textSize = 14,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Right,
	})

	local track = W.frame({
		parent = card,
		size = UDim2.new(1, -20, 0, 18),
		position = UDim2.new(0, 10, 0, 32),
		color = Theme.colors.bgDeep,
		radius = 9,
		stroke = Theme.colors.ink,
		strokeThickness = 2,
		clip = true,
	})
	local fill = W.frame({ parent = track, size = UDim2.new(0.5, 0, 1, 0), color = Theme.colors.accent, radius = 9 })

	local dragging = false
	local function setFromX(x: number)
		local absolute = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local value = math.clamp((x - absolute) / width, 0, 1)
		value = math.floor(value * 20 + 0.5) / 20
		fill.Size = UDim2.new(value, 0, 1, 0)
		valueLabel.Text = tostring(math.floor(value * 100)) .. "%"
		Net.fire("SetSetting", key, value)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local record = {
		frame = card,
		fill = fill,
		valueLabel = valueLabel,
		set = function(value: number)
			if dragging then
				return
			end
			fill.Size = UDim2.new(math.clamp(value, 0, 1), 0, 1, 0)
			valueLabel.Text = tostring(math.floor(value * 100)) .. "%"
		end,
	}
	sliders[key] = record
	return record
end

local function makeToggle(parent: Instance, key: string, title: string, blurb: string, order: number): TextButton
	local card = W.card(parent, 58)
	card.LayoutOrder = order
	W.label({
		parent = card,
		text = title,
		size = UDim2.new(1, -150, 0, 20),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 14,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	W.label({
		parent = card,
		text = blurb,
		size = UDim2.new(1, -150, 0, 26),
		position = UDim2.new(0, 10, 0, 26),
		textSize = 11,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = "Off",
		size = UDim2.new(0, 120, 0, 38),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 14,
		onClick = function()
			local snap = State.get()
			if snap then
				Net.fire("SetSetting", key, not (snap.settings :: any)[key])
			end
		end,
	})
	toggles[key] = button
	return button
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	if not panel.frame.Visible then
		return
	end
	if sliders.music then
		sliders.music.set(snap.settings.music)
	end
	if sliders.sfx then
		sliders.sfx.set(snap.settings.sfx)
	end
	for key, button in toggles do
		local on = (snap.settings :: any)[key] == true
		button.Text = if on then "On" else "Off"
		W.setButtonColor(button, if on then Theme.colors.success else Theme.colors.bgAlt, if on then Theme.colors.ink else Theme.colors.text)
	end

	if buildLabel then
		buildLabel.Text = BuildInfo.long(snap.build) .. "  |  " .. snap.build.environment .. " place v" .. tostring(snap.build.placeVersion)
	end
	if not snap.dataSafe then
		dataLabel.Text = "Data: could not be loaded. Nothing is being saved this session, and your real city is untouched."
		dataLabel.TextColor3 = Theme.colors.danger
	elseif snap.testAdapter then
		dataLabel.Text = "Data: Studio test adapter. DataStores are off here, so this city lasts only while the server runs."
		dataLabel.TextColor3 = Theme.colors.warn
	elseif snap.dataState == "saving" then
		dataLabel.Text = "Data: saving..."
		dataLabel.TextColor3 = Theme.colors.accentAlt
	else
		dataLabel.Text = "Data: saved and safe."
		dataLabel.TextColor3 = Theme.colors.success
	end
end

local function refresh()
	M.update(State.get())
end

function M.init()
	if built then
		return
	end
	gui = W.screenGui("Panels", 10)
	if not gui:FindFirstChildOfClass("UIScale") then
		W.attachScale(gui)
	end
	panel = W.panel(gui, "Settings", "Settings", UDim2.new(0, 640, 0, 440))
	local body = panel.body

	local scroll = W.scroll(body, UDim2.new(1, 0, 1, -70), UDim2.new(0, 0, 0, 0), 6)

	makeSlider(scroll, "music", "Music volume", 1)
	makeSlider(scroll, "sfx", "Effects volume", 2)
	makeToggle(scroll, "reducedMotion", "Reduced motion", "Fewer particles, no screen push, gentler pull from gravity zones.", 3)
	makeToggle(scroll, "reducedFlashing", "Reduced flashing", "Hazard warnings stop strobing and stay a steady colour.", 4)
	makeToggle(scroll, "notifications", "Pop-up messages", "Turn off the small messages in the corner.", 5)

	local controls = W.card(scroll, 148)
	controls.LayoutOrder = 6
	W.label({
		parent = controls,
		text = "Controls",
		size = UDim2.new(1, -20, 0, 20),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 14,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})
	W.label({
		parent = controls,
		text = "Mouse and keyboard: point at a creature and press E or click it to start the tether. E again or Q stops it. Click a work pad in your own city to open the circuit editor. Escape closes a panel.\n"
			.. "Touch: tap a creature to select it, then tap Capture. Tap the same button again to cancel. Tap a work pad to open the circuit editor.\n"
			.. "Controller: X starts or stops the tether, B cancels, the D-pad steps through your work pads and A picks one.",
		size = UDim2.new(1, -20, 0, 112),
		position = UDim2.new(0, 10, 0, 28),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	dataLabel = W.label({
		parent = body,
		text = "",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.new(0, 0, 1, -50),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	-- which code is running, for bug reports (see tools/stamp.py)
	buildLabel = W.label({
		parent = body,
		text = "",
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -18),
		textSize = 11,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})

	built = true
	panel.refresh = refresh
	refresh()
end

return M
