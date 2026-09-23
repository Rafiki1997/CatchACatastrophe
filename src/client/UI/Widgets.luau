--!strict
-- Widget factory used by every UI module. Keeps the look consistent and the
-- panel modules short. Nesting order for the chunky style is
--   W.corner(W.stroke(frame, colour, thickness), radius)
-- but you normally just pass `radius` / `stroke` in props.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Kit = require(ReplicatedStorage.Shared.Models.ModelKit)

local W = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

W.sfxEnabled = true

-- ------------------------------------------------------------ primitives

function W.corner(inst: GuiObject, radius: number?): GuiObject
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.sizes.radius)
	c.Parent = inst
	return inst
end

function W.stroke(inst: GuiObject, color: Color3?, thickness: number?, transparency: number?): GuiObject
	local s = Instance.new("UIStroke")
	s.Name = "Border"
	s.Color = color or Theme.colors.ink
	s.Thickness = thickness or Theme.sizes.stroke
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return inst
end

-- Light text on a candy colour reads only with a heavy dark outline around the
-- glyphs, the reference sample's look. Contextual mode strokes the text rather
-- than the box, so it sits alongside a button's Border stroke. Dark text gets
-- none: it already contrasts with the bright surfaces it is used on. The
-- luminance here is the cheap gamma-space estimate; 0.3 keeps danger red
-- outlined.
local function isLight(color: Color3): boolean
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.3
end

function W.outline(inst: TextLabel | TextButton, thickness: number?): UIStroke
	local existing = inst:FindFirstChild("TextOutline")
	local stroke: UIStroke
	if existing and existing:IsA("UIStroke") then
		stroke = existing
	else
		stroke = Instance.new("UIStroke")
		stroke.Name = "TextOutline"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = Theme.colors.ink
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = inst
		inst:GetPropertyChangedSignal("TextColor3"):Connect(function()
			stroke.Enabled = isLight(inst.TextColor3)
		end)
	end
	stroke.Thickness = thickness or Theme.sizes.textOutline
	stroke.Enabled = isLight(inst.TextColor3)
	return stroke
end

-- Top-lit gloss. The gradient multiplies BackgroundColor3, so hover and press
-- recolouring through BaseColor keeps working underneath it.
function W.gloss(inst: GuiObject): UIGradient
	local existing = inst:FindFirstChild("Gloss")
	if existing and existing:IsA("UIGradient") then
		return existing
	end
	local g = Instance.new("UIGradient")
	g.Name = "Gloss"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.gloss.top),
		ColorSequenceKeypoint.new(0.5, Theme.gloss.mid),
		ColorSequenceKeypoint.new(1, Theme.gloss.bottom),
	})
	g.Parent = inst
	return g
end

-- Drop shadow drawn as a sibling behind the target: under ZIndexBehavior.Sibling
-- a child always draws above its parent, so it cannot be a child. It follows
-- the target's size, position, anchor and visibility, and dies with it.
function W.shadow(target: GuiObject, offset: number?): Frame
	local o = offset or Theme.sizes.shadowOffset
	local corner = target:FindFirstChildOfClass("UICorner")
	local shadow = W.frame({
		parent = target.Parent,
		name = target.Name .. "Shadow",
		color = Theme.colors.ink,
		transparency = Theme.sizes.shadowTransparency,
		radius = if corner then corner.CornerRadius.Offset else 0,
		zindex = math.max(target.ZIndex - 1, 1),
	})
	local function sync()
		shadow.AnchorPoint = target.AnchorPoint
		shadow.Size = target.Size
		shadow.Position = target.Position + UDim2.fromOffset(o, o)
		shadow.Visible = target.Visible
	end
	sync()
	for _, prop in { "AnchorPoint", "Size", "Position", "Visible" } do
		target:GetPropertyChangedSignal(prop):Connect(sync)
	end
	target.Destroying:Connect(function()
		shadow:Destroy()
	end)
	return shadow
end

function W.padding(inst: GuiObject, all: number | { top: number?, bottom: number?, left: number?, right: number? })
	local p = Instance.new("UIPadding")
	if typeof(all) == "number" then
		p.PaddingTop = UDim.new(0, all)
		p.PaddingBottom = UDim.new(0, all)
		p.PaddingLeft = UDim.new(0, all)
		p.PaddingRight = UDim.new(0, all)
	else
		p.PaddingTop = UDim.new(0, all.top or 0)
		p.PaddingBottom = UDim.new(0, all.bottom or 0)
		p.PaddingLeft = UDim.new(0, all.left or 0)
		p.PaddingRight = UDim.new(0, all.right or 0)
	end
	p.Parent = inst
	return p
end

function W.list(parent: GuiObject, direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding or 6)
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function W.grid(parent: GuiObject, cellSize: UDim2, padding: number?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = cellSize
	g.CellPadding = UDim2.new(0, padding or 8, 0, padding or 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Left
	g.Parent = parent
	return g
end

export type FrameProps = {
	parent: Instance?,
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	radius: number?,
	stroke: Color3?,
	strokeThickness: number?,
	zindex: number?,
	order: number?,
	visible: boolean?,
	clip: boolean?,
}

function W.frame(props: FrameProps): Frame
	local f = Instance.new("Frame")
	f.Name = props.name or "Frame"
	f.Size = props.size or UDim2.new(1, 0, 1, 0)
	f.Position = props.position or UDim2.new(0, 0, 0, 0)
	f.AnchorPoint = props.anchor or Vector2.new(0, 0)
	f.BackgroundColor3 = props.color or Theme.colors.bg
	f.BackgroundTransparency = props.transparency or 0
	f.BorderSizePixel = 0
	f.ZIndex = props.zindex or 1
	f.LayoutOrder = props.order or 0
	f.ClipsDescendants = props.clip or false
	if props.visible ~= nil then
		f.Visible = props.visible
	end
	if props.radius and props.radius > 0 then
		W.corner(f, props.radius)
	end
	if props.stroke then
		W.stroke(f, props.stroke, props.strokeThickness)
	end
	f.Parent = props.parent
	return f
end

export type LabelProps = {
	parent: Instance?,
	name: string?,
	text: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	font: Enum.Font?,
	color: Color3?,
	xalign: Enum.TextXAlignment?,
	yalign: Enum.TextYAlignment?,
	rich: boolean?,
	wrap: boolean?,
	scaled: boolean?,
	bg: Color3?, -- background (default transparent)
	radius: number?,
	zindex: number?,
	order: number?,
	strokeText: boolean?, -- heavier outline (HUD numbers, captions)
	automatic: boolean?, -- AutomaticSize Y
	outline: boolean?, -- dark text outline (default on; off for text in dark insets)
}

function W.label(props: LabelProps): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = props.name or "Label"
	l.Text = props.text or ""
	l.Size = props.size or UDim2.new(1, 0, 0, Theme.sizes.text + 8)
	l.Position = props.position or UDim2.new(0, 0, 0, 0)
	l.AnchorPoint = props.anchor or Vector2.new(0, 0)
	l.TextSize = props.textSize or Theme.sizes.text
	l.Font = props.font or Theme.fonts.body
	l.TextColor3 = props.color or Theme.colors.text
	l.TextXAlignment = props.xalign or Enum.TextXAlignment.Left
	l.TextYAlignment = props.yalign or Enum.TextYAlignment.Center
	l.RichText = props.rich or false
	l.TextWrapped = props.wrap or false
	l.TextScaled = props.scaled or false
	l.BackgroundTransparency = if props.bg then 0 else 1
	l.BackgroundColor3 = props.bg or Theme.colors.bg
	l.BorderSizePixel = 0
	l.ZIndex = props.zindex or 1
	l.LayoutOrder = props.order or 0
	if props.automatic then
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
	if props.outline ~= false then
		W.outline(l, if props.strokeText then Theme.sizes.textOutlineLarge else nil)
	end
	if props.radius and props.bg then
		W.corner(l, props.radius)
	end
	l.Parent = props.parent
	return l
end

export type ButtonProps = {
	parent: Instance?,
	name: string?,
	text: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textColor: Color3?,
	textSize: number?,
	font: Enum.Font?,
	radius: number?,
	stroke: Color3?,
	zindex: number?,
	order: number?,
	onClick: (() -> ())?,
	silent: boolean?,
	wrap: boolean?,
	scaled: boolean?,
	rich: boolean?,
	outline: boolean?,
	gloss: boolean?,
}

local function playClick()
	if not W.sfxEnabled then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = Sounds.ids.click
	s.Volume = Sounds.volume.click
	s.Parent = playerGui
	s:Play()
	task.delay(2, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function W.button(props: ButtonProps): TextButton
	local b = Instance.new("TextButton")
	b.Name = props.name or "Button"
	b.Text = props.text or ""
	b.Size = props.size or UDim2.new(0, 160, 0, Theme.sizes.buttonHeight)
	b.Position = props.position or UDim2.new(0, 0, 0, 0)
	b.AnchorPoint = props.anchor or Vector2.new(0, 0)
	b.BackgroundColor3 = props.color or Theme.colors.accent
	b.TextColor3 = props.textColor or Theme.colors.text
	b.TextSize = props.textSize or Theme.sizes.text
	b.Font = props.font or Theme.fonts.title
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.ZIndex = props.zindex or 1
	b.LayoutOrder = props.order or 0
	b.TextWrapped = props.wrap or false
	b.TextScaled = props.scaled or false
	b.RichText = props.rich or false
	W.corner(b, props.radius or Theme.sizes.radius)
	W.stroke(b, props.stroke or Theme.colors.ink, Theme.sizes.stroke)
	if props.gloss ~= false then
		W.gloss(b)
	end
	if props.outline ~= false then
		W.outline(b)
	end
	b:SetAttribute("BaseColor", b.BackgroundColor3)
	local function base(): Color3
		local c = b:GetAttribute("BaseColor")
		return if typeof(c) == "Color3" then c else b.BackgroundColor3
	end
	b.MouseEnter:Connect(function()
		if b.Active then
			b.BackgroundColor3 = base():Lerp(Color3.new(1, 1, 1), 0.15)
		end
	end)
	b.MouseLeave:Connect(function()
		if b.Active then
			b.BackgroundColor3 = base()
		end
	end)
	b.MouseButton1Down:Connect(function()
		if b.Active then
			b.BackgroundColor3 = base():Lerp(Color3.new(0, 0, 0), 0.15)
		end
	end)
	b.MouseButton1Up:Connect(function()
		if b.Active then
			b.BackgroundColor3 = base()
		end
	end)
	b.Activated:Connect(function()
		if not b.Active then
			return
		end
		if not props.silent then
			playClick()
		end
		if props.onClick then
			props.onClick()
		end
	end)
	b.Parent = props.parent
	return b
end

-- Recolours a button (and its stored hover base). Use for state changes.
function W.setButtonColor(b: TextButton, color: Color3, textColor: Color3?)
	b.BackgroundColor3 = color
	b:SetAttribute("BaseColor", color)
	if textColor then
		b.TextColor3 = textColor
	end
end

-- Greys a button out (Active = false stops clicks) or restores it.
function W.setEnabled(b: TextButton, enabled: boolean, disabledColor: Color3?)
	b.Active = enabled
	if enabled then
		local baseColor = b:GetAttribute("BaseColor")
		if typeof(baseColor) == "Color3" then
			b.BackgroundColor3 = baseColor
		end
		b.TextTransparency = 0
	else
		b.BackgroundColor3 = disabledColor or Theme.colors.disabled
		b.TextTransparency = 0.35
	end
end

-- Big square icon button for the sidebar: glyph on top, caption below.
function W.iconButton(parent: Instance, icon: string, caption: string, color: Color3, onClick: () -> (), order: number?): TextButton
	local b = W.button({
		parent = parent,
		name = caption,
		text = "",
		size = UDim2.new(0, Theme.sizes.sidebarButton, 0, Theme.sizes.sidebarButton),
		color = color,
		order = order,
		onClick = onClick,
	})
	W.label({
		parent = b,
		text = icon,
		size = UDim2.new(1, 0, 0.62, 0),
		position = UDim2.new(0, 0, 0, 2),
		textSize = 30,
		font = Theme.fonts.title,
		xalign = Enum.TextXAlignment.Center,
		color = Theme.colors.ink,
		zindex = 2,
	})
	W.label({
		parent = b,
		text = caption,
		size = UDim2.new(1, -4, 0.34, 0),
		position = UDim2.new(0, 2, 0.64, 0),
		textSize = 12,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Center,
		color = Theme.colors.ink,
		zindex = 2,
	})
	return b
end

-- Pill-shaped tag ("Rare", "Chrome", "x2")
function W.badge(parent: Instance, text: string, color: Color3, order: number?): TextLabel
	local l = W.label({
		parent = parent,
		text = text,
		size = UDim2.new(0, 0, 0, 20),
		textSize = 12,
		font = Theme.fonts.bold,
		color = Theme.colors.ink,
		bg = color,
		radius = 10,
		xalign = Enum.TextXAlignment.Center,
		order = order,
	})
	l.AutomaticSize = Enum.AutomaticSize.X
	W.padding(l, { left = 8, right = 8 })
	return l
end

-- Progress bar. Returns a record with set(fraction, text?).
export type Progress = { frame: Frame, fill: Frame, label: TextLabel, set: (number, string?) -> () }

function W.progress(parent: Instance, size: UDim2, color: Color3?, order: number?, position: UDim2?): Progress
	local frame = W.frame({
		parent = parent,
		size = size,
		position = position,
		color = Theme.colors.bgDeep,
		radius = 8,
		stroke = Theme.colors.ink,
		strokeThickness = 2,
		order = order,
		clip = true,
	})
	local fill = W.frame({
		parent = frame,
		size = UDim2.new(0, 0, 1, 0),
		color = color or Theme.colors.success,
		radius = 8,
	})
	local label = W.label({
		parent = frame,
		size = UDim2.new(1, -8, 1, 0),
		position = UDim2.new(0, 4, 0, 0),
		textSize = 13,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Center,
		strokeText = true,
		zindex = 2,
	})
	local record: Progress
	record = {
		frame = frame,
		fill = fill,
		label = label,
		set = function(fraction: number, text: string?)
			fraction = math.clamp(fraction, 0, 1)
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			label.Text = text or (tostring(math.floor(fraction * 100)) .. "%")
		end,
	}
	return record
end

-- Scrolling list with automatic canvas size.

-- Mouse-wheel fallback for scroll lists. Playtest: the scrollbar dragged but the
-- wheel did nothing. When a wheel tick arrives that nothing in the GUI consumed
-- (processed == false) and the cursor is over this frame, scroll it by hand.
-- Native wheel scrolling marks its input processed, so this never doubles it.
local WHEEL_STEP = 60

local function visibleChain(frame: GuiObject): boolean
	local node: Instance? = frame
	while node and not node:IsA("ScreenGui") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and (node :: ScreenGui).Enabled
end

function W.wheelFallback(frame: ScrollingFrame)
	local connection: RBXScriptConnection? = nil
	connection = UserInputService.InputChanged:Connect(function(input, processed)
		if not frame.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		if not visibleChain(frame) or frame.ScrollingDirection == Enum.ScrollingDirection.X then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		local x, y = mouse.X - inset.X, mouse.Y - inset.Y
		local p, size = frame.AbsolutePosition, frame.AbsoluteSize
		if x < p.X or x > p.X + size.X or y < p.Y or y > p.Y + size.Y then
			return
		end
		local maxY = frame.AbsoluteCanvasSize.Y - size.Y
		if maxY <= 0 then
			return
		end
		local target = math.clamp(frame.CanvasPosition.Y - input.Position.Z * WHEEL_STEP, 0, maxY)
		frame.CanvasPosition = Vector2.new(frame.CanvasPosition.X, target)
	end)
end

function W.scroll(parent: Instance, size: UDim2?, position: UDim2?, padding: number?, direction: Enum.FillDirection?): (ScrollingFrame, UIListLayout)
	local s = Instance.new("ScrollingFrame")
	s.Name = "Scroll"
	s.Size = size or UDim2.new(1, 0, 1, 0)
	s.Position = position or UDim2.new(0, 0, 0, 0)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = Theme.colors.accent
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.Parent = parent
	W.wheelFallback(s)
	local layout = W.list(s, direction, padding or 8)
	return s, layout
end

-- Scrolling grid with automatic canvas size.
function W.scrollGrid(parent: Instance, cellSize: UDim2, size: UDim2?, position: UDim2?, padding: number?): (ScrollingFrame, UIGridLayout)
	local s = Instance.new("ScrollingFrame")
	s.Name = "ScrollGrid"
	s.Size = size or UDim2.new(1, 0, 1, 0)
	s.Position = position or UDim2.new(0, 0, 0, 0)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = Theme.colors.accent
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.Parent = parent
	W.wheelFallback(s)
	local grid = W.grid(s, cellSize, padding)
	return s, grid
end

-- ------------------------------------------------------------ ScreenGui + scale

function W.screenGui(name: string, displayOrder: number?): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = playerGui
	return gui
end

-- Adds a UIScale that shrinks the UI on small screens (phones) and keeps it 1.0 on desktop.
function W.attachScale(gui: ScreenGui): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function update()
		local vp = camera.ViewportSize
		local s = math.min(vp.X / 1280, vp.Y / 720)
		scale.Scale = math.clamp(s, 0.7, 1.1)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

-- ------------------------------------------------------------ safe area

-- A full-screen frame inset by whatever the device is covering: the Roblox top
-- bar, and on a phone the notch and the home indicator. Anchor HUD elements
-- inside this rather than to the ScreenGui, or they end up under the hardware.
--
-- GuiService reports the top-left and bottom-right insets; the bottom one is
-- zero on desktop, so this costs nothing there.
function W.safeArea(gui: ScreenGui): Frame
	local existing = gui:FindFirstChild("SafeArea")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local frame = W.frame({
		parent = gui,
		name = "SafeArea",
		size = UDim2.fromScale(1, 1),
		transparency = 1,
	})
	local function update()
		local topLeft, bottomRight = GuiService:GetGuiInset()
		-- the ScreenGui already accounts for the top bar (IgnoreGuiInset = false),
		-- so only the part beyond it needs taking off here
		local extraTop = math.max(0, topLeft.Y - 36)
		frame.Position = UDim2.new(0, topLeft.X, 0, extraTop)
		frame.Size = UDim2.new(1, -(topLeft.X + bottomRight.X), 1, -(extraTop + bottomRight.Y))
	end
	update()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return frame
end

-- ------------------------------------------------------------ tooltips

local tooltipGui: ScreenGui? = nil
local tooltipLabel: TextLabel? = nil

-- Hover (or long-press) help for anything whose meaning is not obvious from its
-- face: an abbreviated number whose exact value matters, a button whose cost is
-- elsewhere. Follows the pointer and never blocks input.
function W.tooltip(target: GuiObject, text: string | () -> string)
	if not tooltipGui then
		local gui = W.screenGui("CatchTooltip", 50)
		gui.ResetOnSpawn = false
		local label = W.label({
			parent = gui,
			name = "Text",
			text = "",
			size = UDim2.new(0, 260, 0, 30),
			textSize = 13,
			font = Theme.fonts.body,
			color = Theme.colors.text,
			bg = Theme.colors.bgDeep,
			radius = Theme.sizes.radiusSmall,
			wrap = true,
			automatic = true,
			visible = false,
			zindex = 60,
		})
		W.stroke(label, Theme.colors.ink, 3)
		label.TextXAlignment = Enum.TextXAlignment.Center
		tooltipGui = gui
		tooltipLabel = label
	end
	local label = tooltipLabel
	if not label then
		return
	end

	local function show()
		local value = if typeof(text) == "function" then text() else text
		if value == nil or value == "" then
			return
		end
		label.Text = value
		label.Visible = true
	end
	local function hide()
		label.Visible = false
	end

	target.MouseEnter:Connect(show)
	target.MouseLeave:Connect(hide)
	target.MouseMoved:Connect(function(x, y)
		if label.Visible then
			label.Position = UDim2.new(0, x + 14, 0, y - 34)
		end
	end)
	-- a destroyed button must not leave its tooltip on screen
	target.AncestryChanged:Connect(function()
		if not target:IsDescendantOf(game) then
			hide()
		end
	end)
end

-- ------------------------------------------------------------ tweens

function W.tween(inst: Instance, props: { [string]: any }, time: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Quick scale "pop" on a GuiObject (needs a UIScale child; creates one).
function W.pop(inst: GuiObject, amount: number?)
	local scale = inst:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = inst
	end
	scale.Scale = amount or 1.15
	W.tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
end

-- ------------------------------------------------------------ panels

export type Panel = {
	name: string,
	frame: Frame,
	body: Frame,
	title: TextLabel,
	close: TextButton,
	refresh: (() -> ())?,
}

local panels: { [string]: Panel } = {}
local openPanelName: string? = nil
local panelListeners: { (string?) -> () } = {}

-- A centred window with a title bar and close button. Hidden until opened.
function W.panel(gui: ScreenGui, name: string, title: string, size: UDim2?): Panel
	local colors = Theme.panelColors(name)
	local frame = W.frame({
		parent = gui,
		name = name .. "Panel",
		size = size or UDim2.new(0, 640, 0, 440),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = colors.body,
		radius = Theme.sizes.radius + 4,
		stroke = Theme.colors.ink,
		strokeThickness = Theme.sizes.strokePanel,
		zindex = 10,
		visible = false,
	})
	W.shadow(frame)
	-- the header is a glossy rounded banner inset in the window, in the
	-- panel's deeper shade; it no longer needs its bottom corners squared off
	local header = W.frame({
		parent = frame,
		name = "Header",
		size = UDim2.new(1, -12, 0, 44),
		position = UDim2.new(0, 6, 0, 6),
		color = colors.header,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		zindex = 11,
	})
	W.gloss(header)
	local titleLabel = W.label({
		parent = header,
		text = title,
		size = UDim2.new(1, -110, 1, 0),
		position = UDim2.new(0, 14, 0, 0),
		textSize = Theme.sizes.title,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		strokeText = true,
		zindex = 12,
	})
	local close = W.button({
		parent = header,
		name = "Close",
		text = "X",
		size = UDim2.new(0, 40, 0, 34),
		position = UDim2.new(1, -6, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 20,
		zindex = 12,
		onClick = function()
			W.closePanels()
		end,
	})
	local body = W.frame({
		parent = frame,
		name = "Body",
		size = UDim2.new(1, -24, 1, -64),
		position = UDim2.new(0, 12, 0, 56),
		transparency = 1,
		zindex = 11,
	})
	local panel: Panel = { name = name, frame = frame, body = body, title = titleLabel, close = close, refresh = nil }
	panels[name] = panel
	return panel
end

function W.registerPanel(panel: Panel)
	panels[panel.name] = panel
end

function W.getPanel(name: string): Panel?
	return panels[name]
end

function W.onPanelChanged(cb: (string?) -> ())
	table.insert(panelListeners, cb)
end

local function notifyPanel()
	for _, cb in panelListeners do
		task.spawn(cb, openPanelName)
	end
end

function W.closePanels()
	for _, p in panels do
		p.frame.Visible = false
	end
	openPanelName = nil
	notifyPanel()
end

function W.openPanel(name: string)
	local p = panels[name]
	if not p then
		warn("[Widgets] no panel", name)
		return
	end
	for other, op in panels do
		if other ~= name then
			op.frame.Visible = false
		end
	end
	p.frame.Visible = true
	openPanelName = name
	if p.refresh then
		p.refresh()
	end
	W.pop(p.frame, 1.04)
	notifyPanel()
end

function W.togglePanel(name: string)
	if openPanelName == name then
		W.closePanels()
	else
		W.openPanel(name)
	end
end

function W.currentPanel(): string?
	return openPanelName
end

-- Simple confirm dialog (modal). onConfirm runs when the player accepts.
function W.confirm(gui: ScreenGui, title: string, body: string, confirmText: string, onConfirm: () -> (), danger: boolean?)
	local overlay = W.frame({
		parent = gui,
		name = "Confirm",
		size = UDim2.new(1, 0, 1, 0),
		color = Color3.new(0, 0, 0),
		transparency = 0.45,
		zindex = 50,
	})
	local box = W.frame({
		parent = overlay,
		size = UDim2.new(0, 420, 0, 230),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius + 4,
		stroke = Theme.colors.ink,
		strokeThickness = Theme.sizes.strokePanel,
		zindex = 51,
	})
	W.shadow(box)
	W.label({
		parent = box,
		text = title,
		size = UDim2.new(1, -24, 0, 40),
		position = UDim2.new(0, 12, 0, 10),
		textSize = Theme.sizes.title,
		font = Theme.fonts.title,
		color = if danger then Theme.colors.danger else Theme.colors.accent,
		zindex = 52,
	})
	W.label({
		parent = box,
		text = body,
		size = UDim2.new(1, -24, 0, 100),
		position = UDim2.new(0, 12, 0, 52),
		textSize = Theme.sizes.text,
		wrap = true,
		yalign = Enum.TextYAlignment.Top,
		rich = true,
		color = Theme.colors.textDim,
		zindex = 52,
	})
	W.button({
		parent = box,
		text = "Cancel",
		size = UDim2.new(0.45, 0, 0, 44),
		position = UDim2.new(0.03, 0, 1, -56),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		zindex = 52,
		onClick = function()
			overlay:Destroy()
		end,
	})
	W.button({
		parent = box,
		text = confirmText,
		size = UDim2.new(0.45, 0, 0, 44),
		position = UDim2.new(0.52, 0, 1, -56),
		color = if danger then Theme.colors.danger else Theme.colors.success,
		textColor = if danger then Theme.colors.text else Theme.colors.ink,
		zindex = 52,
		onClick = function()
			overlay:Destroy()
			onConfirm()
		end,
	})
	W.pop(box, 1.06)
end

-- ------------------------------------------------------------ viewport preview

-- Frames a model inside a ViewportFrame. Camera is placed on the model's
-- -Z side (Oddity faces are built on -Z) at a distance derived from the
-- LONGEST axis, never the bounding-box diagonal.
export type Viewport = { frame: ViewportFrame, setModel: (Model?) -> (), model: Model? }

function W.viewport(parent: Instance, size: UDim2?, position: UDim2?, bg: Color3?): Viewport
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.Size = size or UDim2.new(1, 0, 1, 0)
	vp.Position = position or UDim2.new(0, 0, 0, 0)
	vp.BackgroundColor3 = bg or Theme.colors.bgDeep
	vp.BackgroundTransparency = if bg then 0 else 1
	vp.BorderSizePixel = 0
	vp.Ambient = Theme.viewport.ambient
	vp.LightColor = Theme.viewport.light
	vp.LightDirection = Vector3.new(-1, -2, -1.5)
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local record: Viewport
	record = {
		frame = vp,
		model = nil,
		setModel = function(model: Model?)
			if record.model then
				record.model:Destroy()
				record.model = nil
			end
			if not model then
				return
			end
			model:PivotTo(CFrame.new())
			model.Parent = vp
			record.model = model
			local centre, boxSize = Kit.bounds(model)
			local longest = math.max(boxSize.X, boxSize.Y, boxSize.Z)
			local dist = longest / (2 * math.tan(math.rad(cam.FieldOfView / 2))) * 1.25 + 0.5
			cam.CFrame = CFrame.lookAt(centre + Vector3.new(dist * 0.35, dist * 0.28, -dist), centre)
		end,
	}
	return record
end

-- ------------------------------------------------------------ misc

function W.divider(parent: Instance, order: number?): Frame
	return W.frame({ parent = parent, size = UDim2.new(1, 0, 0, 2), color = Theme.colors.ink, transparency = 0.5, order = order })
end

-- A card row: coloured background, rounded, returns the frame. Height in px.
function W.card(parent: Instance, height: number, order: number?, color: Color3?): Frame
	return W.frame({
		parent = parent,
		size = UDim2.new(1, -4, 0, height),
		color = color or Theme.colors.bgAlt,
		radius = Theme.sizes.radiusSmall,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
		order = order,
	})
end

-- Tab strip: returns the bar and a selectTab(name) function; fires onSelect(name).
function W.tabs(parent: Instance, names: { string }, onSelect: (string) -> (), height: number?): (Frame, (string) -> ())
	local bar = W.frame({ parent = parent, size = UDim2.new(1, 0, 0, height or 40), transparency = 1 })
	W.list(bar, Enum.FillDirection.Horizontal, 6)
	local buttons: { [string]: TextButton } = {}
	local select: (string) -> ()
	select = function(name: string)
		for n, b in buttons do
			local active = n == name
			W.setButtonColor(b, if active then Theme.colors.accent else Theme.colors.bgAlt, if active then Theme.colors.ink else Theme.colors.textDim)
		end
		onSelect(name)
	end
	for i, name in names do
		buttons[name] = W.button({
			parent = bar,
			text = name,
			size = UDim2.new(1 / #names, -6, 1, 0),
			color = Theme.colors.bgAlt,
			textColor = Theme.colors.textDim,
			order = i,
			onClick = function()
				select(name)
			end,
		})
	end
	return bar, select
end

return W
