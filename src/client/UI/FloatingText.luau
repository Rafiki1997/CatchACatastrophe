--!strict
-- Rising "+1.2K" style world text.
--
--   FloatingText.init()
--   FloatingText.show("+1.2K", part.Position, Theme.colors.coin)
--
-- Each call makes one invisible anchored anchor part under Workspace.Effects
-- carrying a BillboardGui. The gui drifts up 3 studs and fades over 1.2 s and
-- is then destroyed. At most 20 live at once; the oldest is dropped first.

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)

local FloatingText = {}

local MAX_ACTIVE = 20
local RISE_STUDS = 3
local LIFETIME = 1.2

type Floater = {
	part: BasePart,
	gui: BillboardGui,
	label: TextLabel,
}

local built = false
local folder: Instance = nil :: any
local active: { Floater } = {}

local function destroyFloater(floater: Floater)
	local idx = table.find(active, floater)
	if idx then
		table.remove(active, idx)
	end
	if floater.part.Parent then
		floater.part:Destroy()
	end
end

function FloatingText.init()
	if built then
		return
	end
	built = true
	local existing = workspace:FindFirstChild("Effects")
	if existing then
		folder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "Effects"
		f.Parent = workspace
		folder = f
	end
end

function FloatingText.show(text: string, worldPos: Vector3, color: Color3?)
	if not built then
		FloatingText.init()
	end
	if type(text) ~= "string" or text == "" then
		return
	end
	if typeof(worldPos) ~= "Vector3" then
		return
	end

	while #active >= MAX_ACTIVE do
		local oldest = active[1]
		if not oldest then
			break
		end
		destroyFloater(oldest)
	end

	local part = Instance.new("Part")
	part.Name = "FloatingTextAnchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(worldPos)
	part.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FloatingText"
	billboard.Size = UDim2.new(0, 160, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Adornee = part
	billboard.Parent = part

	local label = W.label({
		parent = billboard,
		name = "Text",
		text = text,
		size = UDim2.new(1, 0, 1, 0),
		textSize = 24,
		font = Theme.fonts.number,
		color = color or Theme.colors.coin,
		xalign = Enum.TextXAlignment.Center,
		yalign = Enum.TextYAlignment.Center,
		strokeText = true,
	})

	local floater: Floater = { part = part, gui = billboard, label = label }
	table.insert(active, floater)

	W.tween(billboard, { StudsOffset = Vector3.new(0, RISE_STUDS, 0) }, LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	W.tween(label, { TextTransparency = 1, TextStrokeTransparency = 1 }, LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	task.delay(LIFETIME + 0.05, function()
		destroyFloater(floater)
	end)
end

return FloatingText
