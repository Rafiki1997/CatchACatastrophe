-- Run through the Studio bridge in the Client datamodel during Play.
-- This file is outside the Rojo source tree and never ships with the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)
local playerGui = Players.LocalPlayer.PlayerGui
assert(not playerGui:FindFirstChild("CreatureArtReview"), "Close the existing art review first")

local camera = workspace.CurrentCamera
local previousType, previousCF, previousFOV = camera.CameraType, camera.CFrame, camera.FieldOfView
local hidden = {}
for _, child in playerGui:GetChildren() do
	if child:IsA("ScreenGui") and child.Enabled then
		table.insert(hidden, child)
		child.Enabled = false
	end
end
local folder = Instance.new("Folder")
folder.Name = "CreatureArtReview"
folder.Parent = workspace
local gui = Instance.new("ScreenGui")
gui.Name = "CreatureArtReview"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Name = "Controls"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.new(0.92, 0, 0, 104)
panel.BackgroundColor3 = Color3.fromRGB(33, 43, 52)
panel.Parent = gui
local title = Instance.new("TextLabel")
title.Name = "Region"
title.Size = UDim2.new(1, 0, 0, 46)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(247, 248, 239)
title.Font = Enum.Font.FredokaOne
title.TextSize = 22
title.Parent = panel
local index, variantIndex = 2, 1
local variants = { "Normal", "Overcharged", "Prismatic", "Silhouette" }
local connections = {}
local function show()
	folder:ClearAllChildren()
	local region = Config.Regions.list[index]
	local variant = variants[variantIndex]
	title.Text = region.name .. " / " .. variant
	gui:SetAttribute("RegionId", region.id)
	gui:SetAttribute("Appearance", variant)
	for i, def in Config.Species.byRegion[region.id] do
		-- Camera looks along +Z, so decreasing world X reads left to right.
		local x = (2.5 - i) * 7
		local plinth = Instance.new("Part")
		plinth.Name = "ReviewPlinth"
		plinth.Anchored = true
		plinth.CanCollide = false
		plinth.CanTouch = false
		plinth.CanQuery = false
		plinth.Size = Vector3.new(6.5, 0.35, 7)
		plinth.Position = Vector3.new(x, 99.825, 0)
		plinth.Color = Color3.fromRGB(76, 89, 95)
		plinth.Parent = folder
		local model = CreatureModels.build(def.id, if variant == "Silhouette" then "Normal" else variant, variant == "Silhouette")
		model.Parent = folder
		model:PivotTo(CFrame.new(x, 100, 0))
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(180, 32)
		tag.StudsOffset = Vector3.new(0, -0.5, -3.5)
		tag.AlwaysOnTop = true
		tag.Adornee = plinth
		tag.Parent = plinth
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = Color3.fromRGB(33, 43, 52)
		text.TextColor3 = Color3.fromRGB(247, 248, 239)
		text.Font = Enum.Font.FredokaOne
		text.TextSize = 15
		text.Text = def.name
		text.Parent = tag
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 106, -29), Vector3.new(0, 102.4, 0))
end
local function button(name, text, order, callback)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(0.24, -6, 0, 44)
	b.Position = UDim2.new(0.02 + (order - 1) * 0.24, 0, 0, 50)
	b.Text = text
	b.TextSize = 16
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.fromRGB(245, 248, 255)
	b.BackgroundColor3 = Color3.fromRGB(64, 87, 103)
	b.Parent = panel
	table.insert(connections, b.Activated:Connect(callback))
end
button("Previous", "Previous region", 1, function()
	index = (index - 2) % #Config.Regions.list + 1
	show()
end)
button("Next", "Next region", 2, function()
	index = index % #Config.Regions.list + 1
	show()
end)
button("Variant", "Change appearance", 3, function()
	variantIndex = variantIndex % #variants + 1
	show()
end)
button("Close", "Back to game", 4, function()
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, screen in hidden do
		if screen.Parent then
			screen.Enabled = true
		end
	end
	camera.CameraType = previousType
	camera.CFrame = previousCF
	camera.FieldOfView = previousFOV
	folder:Destroy()
	gui:Destroy()
end)
show()
return "Art review open: use the region and appearance buttons, or Back to game."
