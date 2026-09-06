--!strict
-- Keyboard, gamepad and touch bindings, plus the on-screen buttons phones need.
--
-- Touch players get a toggle, not a held button: tap Capture to start, tap it
-- again (or Cancel) to stop. Nothing in this game asks for two fingers at once
-- or a precise drag.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local W = require(script.Parent.Parent.UI.Widgets)
local Theme = require(script.Parent.Parent.UI.Theme)

local Input = {}

local handlers: { [string]: { () -> () } } = {}
local buttons: { [string]: TextButton } = {}

function Input.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Input.isGamepad(): boolean
	return UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
end

function Input.onAction(name: string, callback: () -> ())
	local list = handlers[name]
	if not list then
		list = {}
		handlers[name] = list
	end
	table.insert(list, callback)
end

local function fire(name: string)
	for _, callback in handlers[name] or {} do
		local ok, err = pcall(callback)
		if not ok then
			warn("[Input] " .. name .. " handler failed: " .. tostring(err))
		end
	end
end

-- The on-screen button's label changes with what the action will do next.
function Input.setActionLabel(name: string, text: string)
	local button = buttons[name]
	if button then
		button.Text = text
	end
end

function Input.setActionVisible(name: string, visible: boolean)
	local button = buttons[name]
	if button then
		button.Visible = visible
	end
end

function Input.init()
	local gui = W.screenGui("CatchInput", 5)
	W.attachScale(gui)
	-- touch buttons sit above the home indicator, not under it
	local safe = W.safeArea(gui)

	local container = W.frame({
		parent = safe,
		name = "TouchActions",
		size = UDim2.new(0, 150, 0, 130),
		position = UDim2.new(1, -20, 1, -30),
		anchor = Vector2.new(1, 1),
		transparency = 1,
		visible = Input.isTouch(),
	})
	W.list(container, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	buttons.Capture = W.button({
		parent = container,
		name = "Capture",
		text = "Capture",
		size = UDim2.new(0, 146, 0, 60),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 20,
		order = 1,
		onClick = function()
			fire("Capture")
		end,
	})
	buttons.Cancel = W.button({
		parent = container,
		name = "Cancel",
		text = "Cancel",
		size = UDim2.new(0, 146, 0, 52),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 18,
		order = 2,
		onClick = function()
			fire("Cancel")
		end,
	})
	buttons.Cancel.Visible = false

	-- keyboard + gamepad
	ContextActionService:BindAction("CatchCapture", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			fire("Capture")
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

	ContextActionService:BindAction("CatchCancel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			fire("Cancel")
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

	-- gamepad users navigate the panels with the stick, so turn selection on
	if UserInputService.GamepadEnabled then
		GuiService.AutoSelectGuiEnabled = true
	end

	-- a device can change mid-session (a phone with a controller paired)
	UserInputService.LastInputTypeChanged:Connect(function()
		container.Visible = Input.isTouch()
	end)
end

return Input
