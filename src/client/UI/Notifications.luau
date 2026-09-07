--!strict
-- Toasts (top right) and the server broadcast banner (top centre, under the
-- HUD event banner).
--
--   Notifications.init()
--   Notifications.push("success", "You snatched a Glow Snail!", 4)
--   Notifications.broadcast("A Celestial Oddity is on the runway!", Color3...)
--
-- Kinds: info | success | warn | error | steal | event
-- `settings.notifications == false` silences the chatty kinds (info, event)
-- but never the ones the player must see (steal, error, success).

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Notifications = {}

local TOAST_WIDTH = 300
local MAX_TOASTS = 5
local DEDUPE_WINDOW = 1.5
local BROADCAST_SECONDS = 5

local KIND_COLORS: { [string]: Color3 } = {
	info = Theme.colors.accentAlt,
	success = Theme.colors.success,
	warn = Theme.colors.warn,
	error = Theme.colors.danger,
	steal = Theme.colors.steal,
	event = Theme.colors.gold,
}

local QUIET_KINDS: { [string]: boolean } = {
	info = true,
	event = true,
}

type Toast = {
	frame: Frame,
	inner: Frame,
	label: TextLabel,
	close: TextButton?,
	text: string,
	gen: number,
	shownAt: number,
	dying: boolean,
}

local built = false
local gui: ScreenGui = nil :: any
local stack: Frame = nil :: any
local toasts: { Toast } = {}
local orderCounter = 0

local broadcastFrame: Frame = nil :: any
local broadcastLabel: TextLabel = nil :: any
local broadcastGen = 0

-- ------------------------------------------------------------ helpers

local function notificationsAllowed(kind: string): boolean
	if not QUIET_KINDS[kind] then
		return true
	end
	local snap = State.get()
	if snap and snap.settings and snap.settings.notifications == false then
		return false
	end
	return true
end

local function removeToast(toast: Toast)
	local idx = table.find(toasts, toast)
	if idx then
		table.remove(toasts, idx)
	end
	if toast.frame.Parent then
		toast.frame:Destroy()
	end
end

local function fadeOut(toast: Toast)
	if toast.dying then
		return
	end
	toast.dying = true
	W.tween(toast.frame, { BackgroundTransparency = 1 }, 0.3)
	W.tween(toast.inner, { BackgroundTransparency = 1 }, 0.3)
	W.tween(toast.label, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.3)
	if toast.close then
		W.tween(toast.close, { TextTransparency = 1 }, 0.3)
	end
	local stroke = toast.frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		W.tween(stroke, { Transparency = 1 }, 0.3)
	end
	task.delay(0.35, function()
		removeToast(toast)
	end)
end

local function scheduleDismiss(toast: Toast, duration: number)
	local gen = toast.gen
	task.delay(duration, function()
		if toast.gen == gen and not toast.dying then
			fadeOut(toast)
		end
	end)
end

local function findDuplicate(text: string): Toast?
	local now = os.clock()
	for _, toast in toasts do
		if not toast.dying and toast.text == text and now - toast.shownAt <= DEDUPE_WINDOW then
			return toast
		end
	end
	return nil
end

-- ------------------------------------------------------------ build

local function buildStack()
	stack = W.frame({
		parent = gui,
		name = "Toasts",
		size = UDim2.new(0, TOAST_WIDTH + 8, 0, 460),
		position = UDim2.new(1, -12, 0, 12),
		anchor = Vector2.new(1, 0),
		transparency = 1,
	})
	local layout = W.list(stack, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
end

local function buildBroadcast()
	broadcastFrame = W.frame({
		parent = gui,
		name = "Broadcast",
		size = UDim2.new(0, 560, 0, 44),
		position = UDim2.new(0.5, 0, 0, 70),
		anchor = Vector2.new(0.5, 0),
		color = Theme.colors.gold,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		visible = false,
	})
	broadcastLabel = W.label({
		parent = broadcastFrame,
		name = "BroadcastText",
		text = "",
		size = UDim2.new(1, -20, 1, 0),
		position = UDim2.new(0, 10, 0, 0),
		textSize = Theme.sizes.text,
		font = Theme.fonts.title,
		color = Theme.colors.ink,
		xalign = Enum.TextXAlignment.Center,
		wrap = true,
		zindex = 2,
	})
end

-- ------------------------------------------------------------ public

function Notifications.init()
	if built then
		return
	end
	built = true
	gui = W.screenGui("Notifications", 20)
	W.attachScale(gui)
	buildStack()
	buildBroadcast()
end

function Notifications.push(kind: string, text: string, duration: number?)
	if not built then
		Notifications.init()
	end
	if type(text) ~= "string" or text == "" then
		return
	end
	if not notificationsAllowed(kind) then
		return
	end

	local seconds = duration or 4

	local existing = findDuplicate(text)
	if existing then
		existing.gen += 1
		existing.shownAt = os.clock()
		scheduleDismiss(existing, seconds)
		W.pop(existing.frame, 1.08)
		return
	end

	while #toasts >= MAX_TOASTS do
		local oldest = toasts[1]
		if not oldest then
			break
		end
		removeToast(oldest)
	end

	orderCounter += 1

	local barColor = KIND_COLORS[kind] or Theme.colors.accentAlt

	local frame = W.frame({
		parent = stack,
		name = "Toast",
		size = UDim2.new(0, TOAST_WIDTH, 0, 0),
		color = barColor,
		radius = Theme.sizes.radiusSmall + 2,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		order = orderCounter,
	})
	frame.AutomaticSize = Enum.AutomaticSize.Y

	local inner = W.frame({
		parent = frame,
		name = "Inner",
		size = UDim2.new(1, -7, 0, 0),
		position = UDim2.new(0, 7, 0, 0),
		color = Theme.colors.bgAlt,
		radius = Theme.sizes.radiusSmall + 2,
	})
	inner.AutomaticSize = Enum.AutomaticSize.Y
	W.padding(inner, { top = 8, bottom = 8, left = 10, right = 40 })

	local label = W.label({
		parent = inner,
		name = "Text",
		text = text,
		size = UDim2.new(1, 0, 0, 0),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
		wrap = true,
		yalign = Enum.TextYAlignment.Top,
		automatic = true,
		zindex = 2,
	})

	local toast: Toast = {
		frame = frame,
		inner = inner,
		label = label,
		text = text,
		close = nil,
		gen = 1,
		shownAt = os.clock(),
		dying = false,
	}
	table.insert(toasts, toast)

	-- A toast that keeps re-arming itself is inescapable without this.
	-- The hit area is 44x44 (every button in the game is at least 44 for touch);
	-- only the glyph is visible, so a one-line toast does not grow to fit it.
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "✕"
	close.Size = UDim2.new(0, 44, 0, 44)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)
	close.BackgroundTransparency = 1
	close.BorderSizePixel = 0
	close.AutoButtonColor = false
	close.TextColor3 = Theme.colors.textDim
	close.TextSize = 16
	close.Font = Theme.fonts.bold
	close.ZIndex = 3
	close.MouseEnter:Connect(function()
		close.TextColor3 = Theme.colors.text
	end)
	close.MouseLeave:Connect(function()
		close.TextColor3 = Theme.colors.textDim
	end)
	close.Activated:Connect(function()
		fadeOut(toast)
	end)
	close.Parent = frame
	toast.close = close

	W.pop(frame, 1.12)
	scheduleDismiss(toast, seconds)
end

function Notifications.broadcast(text: string, color: Color3?)
	if not built then
		Notifications.init()
	end
	if type(text) ~= "string" or text == "" then
		return
	end

	broadcastGen += 1
	local gen = broadcastGen

	broadcastFrame.BackgroundColor3 = color or Theme.colors.gold
	broadcastLabel.Text = text
	broadcastFrame.Visible = true
	W.pop(broadcastFrame, 1.1)

	task.delay(BROADCAST_SECONDS, function()
		if broadcastGen == gen then
			broadcastFrame.Visible = false
		end
	end)
end

return Notifications
