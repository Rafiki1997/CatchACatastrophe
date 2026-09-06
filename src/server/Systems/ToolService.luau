--!strict
-- The Containment Tether: the free tool every player starts with.
--
-- The tool is the visible instrument for a capture. Activating it toggles the
-- tether, exactly as the E key and the touch button do; it is deliberately not
-- *required*, because a player who unequips it should not silently lose the
-- ability to catch anything, and the tutorial cannot rely on a hotbar slot.
--
-- One prototype is built at boot and cloned into each backpack, so the parts
-- are made once rather than per player per respawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local ToolService = {}

local TOOL_NAME = "Containment Tether"
local prototype: Tool? = nil

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(46, 44, 52)
local HAZARD = rgb(255, 190, 50)
local STEEL = rgb(150, 156, 168)

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.Parent = parent
	return p
end

-- A chunky hazard-striped emitter: grip, body, coil rings, glowing muzzle.
local function build(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Aim at a wild creature and activate to start the tether"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 1.5, 0.6)
	handle.Color = INK
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Massless = true
	handle.Parent = tool

	-- everything else is welded to the handle so the tool animates as one piece
	local parts: { Part } = {}
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local p = piece(tool, name, size, handle.CFrame * offset, color, material)
		table.insert(parts, p)
		return p
	end

	add("Body", Vector3.new(0.75, 0.75, 2.2), CFrame.new(0, 1.0, -0.6), STEEL, Enum.Material.Metal)
	add("Stripe", Vector3.new(0.8, 0.2, 0.5), CFrame.new(0, 1.0, -0.3), HAZARD)
	for i = 1, 3 do
		add("Coil" .. tostring(i), Vector3.new(1.0, 0.16, 1.0), CFrame.new(0, 1.0, -1.2 - (i - 1) * 0.32) * CFrame.Angles(math.rad(90), 0, 0), if i % 2 == 0 then HAZARD else INK)
	end
	local muzzle = add("Muzzle", Vector3.new(0.5, 0.5, 0.3), CFrame.new(0, 1.0, -1.85), rgb(120, 230, 255), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(120, 230, 255)
	light.Range = 9
	light.Brightness = 1.2
	light.Parent = muzzle
	add("Trigger", Vector3.new(0.22, 0.4, 0.22), CFrame.new(0, 0.5, -0.4) * CFrame.Angles(math.rad(20), 0, 0), HAZARD)

	for _, p in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	end

	-- the muzzle points forward when held
	local grip = Instance.new("Attachment")
	grip.Name = "GripAttachment"
	grip.Parent = handle
	tool.Grip = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)

	return tool
end

function ToolService.prototype(): Tool
	if not prototype or not prototype.Parent then
		local tool = build()
		tool.Parent = ServerStorage
		prototype = tool
	end
	return prototype :: Tool
end

-- Give the tether to a player, replacing any copy they already have.
function ToolService.give(profile: Profile)
	local player = profile.player
	if not player.Parent then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local existing = backpack:FindFirstChild(TOOL_NAME)
	if existing then
		return
	end
	local character = player.Character
	if character and character:FindFirstChild(TOOL_NAME) then
		return
	end
	local copy = ToolService.prototype():Clone()
	copy.Parent = backpack
end

function ToolService.init()
	ToolService.prototype()
end

ToolService.toolName = TOOL_NAME
local _ = Config

S.Tools = ToolService
return ToolService
