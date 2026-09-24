--!strict
-- Shared presentation for wild and deployed creatures. The root is at the feet;
-- anchoring the bottom of the label above it avoids double-counting model height.
local Config = require(script.Parent.Parent.Config)

local CreatureLabel = {}
local INK = Color3.fromRGB(23, 27, 38)
local CREAM = Color3.fromRGB(255, 247, 226)
local ROWS = {
	{ name = "Title", y = 0, height = 28 },
	{ name = "Metadata", y = 30, height = 20 },
	{ name = "Detail", y = 52, height = 18 },
	{ name = "Status", y = 73, height = 18 },
}

local function row(parent: BillboardGui, name: string, y: number, height: number, font: Enum.Font, color: Color3)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 4, 0, y)
	text.Size = UDim2.new(1, -8, 0, height)
	text.Font = font
	text.TextWrapped = false
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeColor3 = INK
	text.TextStrokeTransparency = 0.15
	text.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 1
	limit.MaxTextSize = height - 2
	limit.Parent = text
end

function CreatureLabel.create(model: Model, name: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = model.PrimaryPart
	gui.Size = UDim2.fromOffset(250, 72)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") :: number? or 3) + 0.7, 0)
	gui.MaxDistance = 150
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ClipsDescendants = false
	row(gui, "Title", 0, 28, Enum.Font.FredokaOne, CREAM)
	row(gui, "Metadata", 30, 20, Enum.Font.GothamBold, CREAM)
	row(gui, "Detail", 52, 18, Enum.Font.GothamMedium, Color3.fromRGB(219, 227, 236))
	row(gui, "Status", 73, 18, Enum.Font.GothamBold, Color3.fromRGB(155, 242, 193))
	local status = gui.Status :: TextLabel
	status.Visible = false
	gui.Parent = model
	return gui
end

function CreatureLabel.setIdentity(gui: BillboardGui, speciesId: string, variant: string?, favorite: boolean?)
	local def = Config.Species.byId[speciesId]
	if not def then return end
	local title = gui.Title :: TextLabel
	local metadata = gui.Metadata :: TextLabel
	title.Text = def.name .. (if favorite then " *" else "")
	-- A simple diamond works in the shipped font; ornate rarity glyphs can render
	-- as missing-character boxes. Rarity is always explicitly named as well.
	metadata.Text = "◆ " .. def.rarity .. "  ·  " .. (if variant and variant ~= "Normal" then variant else def.element)
	metadata.TextColor3 = Config.Rarities.color(def.rarity)
end

function CreatureLabel.setDetail(gui: BillboardGui, detail: string, status: string?)
	local detailRow = gui.Detail :: TextLabel
	local statusRow = gui.Status :: TextLabel
	detailRow.Text = detail
	statusRow.Text = status or ""
	statusRow.Visible = status ~= nil and status ~= ""
end

-- Called locally for both server-authored city labels and client-only wild ones.
-- Perspective shrinks far labels without allowing close labels to fill the screen.
function CreatureLabel.resize(gui: BillboardGui, cam: Camera)
	local root = gui.Adornee
	if not root or not root:IsA("BasePart") then return end
	local screen = cam:WorldToViewportPoint(root.Position + gui.StudsOffsetWorldSpace)
	if screen.Z <= 0 or (cam.CFrame.Position - root.Position).Magnitude > gui.MaxDistance then return end
	-- Replicated city labels can arrive before all of their text children.
	for _, spec in ROWS do
		if not gui:FindFirstChild(spec.name) then return end
	end
	local scale = math.clamp((45 / math.max(1, screen.Z)) ^ 0.7, 0.55, 1)
	local status = (gui.Status :: TextLabel).Visible
	local size = UDim2.fromOffset(250 * scale, (if status then 94 else 72) * scale)
	if gui.Size == size then return end
	gui.Size = size
	for _, spec in ROWS do
		local text = gui:FindFirstChild(spec.name) :: TextLabel
		text.Position = UDim2.new(0, 4 * scale, 0, spec.y * scale)
		text.Size = UDim2.new(1, -8 * scale, 0, spec.height * scale)
	end
end

return CreatureLabel
