-- Run from the repository root with Lune 0.10.5:
--   lune run tools/verify_plot_props.luau
-- Builds the Pocket Power Town plot headlessly (PlotTemplate with a Config
-- stub), then proves PlotProps.apply and ImportStaging behave against a
-- synthetic native kit: refusal without a library, partial kit, wrong scale,
-- solid placeholder; exact placement of all 62 sites; permanent geometry and
-- lights untouched; no double placement; build-time apply; raw bundle staging.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local V3, CF = roblox.Vector3, roblox.CFrame

-- Lune's CFrame.lookAt negates Z relative to Roblox; the plot never calls it,
-- but the shim keeps this loader interchangeable with the region harnesses.
local function lookAt(pos, target, up)
	up = up or V3.new(0, 1, 0)
	local look = (target - pos).Unit
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look)
	return CF.fromMatrix(pos, right, up2, -look)
end
local CFshim = setmetatable({ lookAt = lookAt }, { __index = CF })

-- ------------------------------------------------------------ Config stub
local Circuits = {}
Circuits.grid = { cols = 6, rows = 4 }
Circuits.maxPads = 24
function Circuits.padCoords(pad)
	return (pad - 1) % 6 + 1, (pad - 1) // 6 + 1
end
function Circuits.areAdjacent(a, b)
	local ca, ra = Circuits.padCoords(a)
	local cb, rb = Circuits.padCoords(b)
	return (ca == cb and math.abs(ra - rb) == 1) or (ra == rb and math.abs(ca - cb) == 1)
end
local Regions = { elements = { "Wind", "Water", "Heat", "Frost", "Storm", "Cosmic" } }
function Regions.elementColor(_e)
	return roblox.Color3.fromRGB(200, 130, 255)
end
local Config = { Circuits = Circuits, Regions = Regions, MaxPlayers = 6, Economy = { startingPads = 6 } }
local ConfigToken = { __token = "Config" }
local MachineryToken = { __token = "MachineryBuilders" }
local RS = { Shared = { Config = ConfigToken, Models = { MachineryBuilders = MachineryToken } } }
local CollectionStub = { AddTag = function() end, HasTag = function() return false end }
local gameStub = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then return RS end
		return CollectionStub
	end,
}
local workspaceStub = roblox.Instance.new("Folder")
workspaceStub.Name = "Workspace"
local plotsFolder = roblox.Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = workspaceStub

-- ------------------------------------------------------------ Map folder of real ModuleScripts
local map = roblox.Instance.new("Folder")
map.Name = "Map"
local sources = {}
for _, name in { "PlotTemplate", "PlotAssetSpec", "PlotProps", "ImportStaging", "OrbitAssetSpec" } do
	local m = roblox.Instance.new("ModuleScript")
	m.Name = name
	m.Parent = map
	sources[m] = "src/server/Map/" .. name .. ".luau"
end
local cache = {}
local loadModule
local function requireFn(target)
	if target == ConfigToken then return Config end
	if target == MachineryToken then
		return { buildDecoration = function(key)
			local m = roblox.Instance.new("Model")
			m.Name = "Decor_" .. key
			return m
		end }
	end
	if typeof(target) == "Instance" and sources[target] then
		return loadModule(target)
	end
	error("unexpected require: " .. tostring(target))
end
function loadModule(inst)
	if cache[inst] then return cache[inst] end
	local env = {
		Vector3 = roblox.Vector3, CFrame = CFshim, Color3 = roblox.Color3, Enum = roblox.Enum,
		Instance = roblox.Instance, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2,
		NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		script = inst, workspace = workspaceStub, game = gameStub,
		math = math, table = table, string = string, os = os, tostring = tostring, tonumber = tonumber,
		type = type, typeof = typeof, pairs = pairs, ipairs = ipairs, next = next, select = select,
		assert = assert, error = error, pcall = pcall, xpcall = xpcall, unpack = table.unpack,
		print = print, warn = print, setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
		require = requireFn,
	}
	env._G = env
	local f = luau.load(fs.readFile(sources[inst]), { debugName = inst.Name, environment = env })
	local value = f()
	cache[inst] = value
	return value
end

local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end

-- ------------------------------------------------------------ build and refuse
local PlotTemplate = loadModule(map.PlotTemplate)
local frame = CF.new(37, 0, -121) * CF.Angles(0, 0.7, 0)
local plot = PlotTemplate.build(frame, 3)
local sites = plot.model.PropSites
local siteCount = #sites:GetChildren()
check(siteCount == sites:GetAttribute("AssetCount") and siteCount == 68, "site count " .. tostring(siteCount))
check(plot.model:GetAttribute("PlotArt") == "placeholder", "no library -> placeholder")
local props = loadModule(map.PlotProps)
check(props.apply(plot.model, frame) == false, "apply must refuse without a library")

local protected, lights = {}, 0
for _, v in plot.model:GetDescendants() do
	if v:IsA("PointLight") or v:IsA("SpotLight") then lights += 1 end
	if v:IsA("BasePart") and not v:IsDescendantOf(sites) then
		protected[v] = { v.Size, v.CFrame, v.CanCollide, v.Transparency }
	end
end
check(lights == 16, "expected 16 lights, got " .. tostring(lights))

-- ------------------------------------------------------------ synthetic native library
local spec = loadModule(map.PlotAssetSpec)
local lib = roblox.Instance.new("Model")
lib.Name = "PlotPropTemplates"
local specCount = 0
for name, size in spec do
	specCount += 1
	local m = roblox.Instance.new("MeshPart")
	m.Name = name
	m.MeshId = "rbxassetid://" .. tostring(1000 + specCount)
	m.MeshSize = size * 100
	m.Size = size
	m.Parent = lib
end
check(specCount == 12, "spec has 12 assets")
lib.Parent = map

local removed = lib.PP_Water_Tower
removed.Parent = nil
check(props.apply(plot.model, frame) == false and sites.WaterTower:FindFirstChild("PlaceholderArt") ~= nil, "partial kit removed art")
removed.Parent = lib
local site = sites.PadFrame_1
local size = site:GetAttribute("AssetSize")
site:SetAttribute("AssetSize", size * 100)
check(props.apply(plot.model, frame) == false, "100x size accepted")
site:SetAttribute("AssetSize", size)
local artPart = sites.DispatchBooth.PlaceholderArt:FindFirstChildWhichIsA("BasePart")
artPart.CanCollide = true
check(props.apply(plot.model, frame) == false, "solid placeholder would be deleted")
artPart.CanCollide = false

-- ------------------------------------------------------------ the swap
check(props.apply(plot.model, frame) == true, "native kit did not apply")
local placed = plot.model.BlenderProps
check(#placed:GetChildren() == 68, "wrong placement count " .. tostring(#placed:GetChildren()))
for _, s in sites:GetChildren() do
	local v = placed:FindFirstChild(s.Name)
	local template = lib:FindFirstChild(s:GetAttribute("AssetName"))
	local cf = frame * s:GetAttribute("GroundCF") * CF.new(0, s:GetAttribute("AssetSize").Y / 2, 0)
	check(v ~= nil and template ~= nil, "missing placement " .. s.Name)
	check(v.MeshId == template.MeshId and v.MeshSize == template.MeshSize, "native content changed " .. s.Name)
	check(v.Size == s:GetAttribute("AssetSize") and (v.CFrame.Position - cf.Position).Magnitude < 0.001
		and v.CFrame.LookVector:Dot(cf.LookVector) > 0.9999 and v.CFrame.UpVector:Dot(cf.UpVector) > 0.9999, "wrong mesh placement " .. s.Name)
	check(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery, "unsafe flags " .. s.Name)
	check(s:GetAttribute("AssetPlaced") == true and not s:FindFirstChild("PlaceholderArt"), "placeholder remains " .. s.Name)
end
for p, old in protected do
	check(p:IsDescendantOf(plot.model) and p.Size == old[1] and p.CFrame == old[2]
		and p.CanCollide == old[3] and p.Transparency == old[4], "permanent geometry changed: " .. p.Name)
end
local afterLights = 0
for _, v in plot.model:GetDescendants() do
	if v:IsA("PointLight") or v:IsA("SpotLight") then afterLights += 1 end
end
check(afterLights == lights, "lights lost")
check(plot.model:GetAttribute("BlenderPropCount") == 68 and plot.model:GetAttribute("BlenderPropsVersion") == 1, "attributes")
check(props.apply(plot.model, frame) == false, "repeat placement duplicated assets")
check(plot.booth.ventButton.Parent ~= nil and plot.collectPad.Parent ~= nil and plot.pads[24].Parent ~= nil
	and plot.pads[1]:FindFirstChild("Strip") ~= nil and plot.model:FindFirstChild("Billboard") ~= nil, "gameplay parts survived")

-- a plot built while the library exists gets native art immediately
local plot2 = PlotTemplate.build(CF.new(0, 0, 0), 4)
check(plot2.model:GetAttribute("PlotArt") == "native" and #plot2.model.BlenderProps:GetChildren() == 68, "build-time apply")
local leftovers = 0
for _, v in plot2.model.PropSites:GetDescendants() do
	if v:IsA("BasePart") then leftovers += 1 end
end
check(leftovers == 0, "placeholder parts left after build-time apply: " .. tostring(leftovers))

-- ------------------------------------------------------------ ImportStaging
-- Studio inserts an FBX bundle as a Model of unanchored, 100x MeshParts.
local staging = loadModule(map.ImportStaging)
local function rawBundle(parent)
	local bundle = roblox.Instance.new("Model")
	bundle.Name = "PlotPropsBundle"
	for _, template in lib:GetChildren() do
		local p = template:Clone()
		p.Anchored = false
		p.Size *= 100
		p.Parent = bundle
	end
	bundle.Parent = parent
	return bundle
end
lib.Parent = nil
local imports, storage = roblox.Instance.new("Folder"), roblox.Instance.new("Folder")
local raw = rawBundle(imports)
check(staging.move(imports, storage) == 1 and raw:IsDescendantOf(storage), "first raw plot import not staged")
for _, p in raw:GetChildren() do
	check(p.Anchored, "raw import can fall")
end
local partial = rawBundle(imports)
partial.PP_Lantern:Destroy()
check(staging.move(imports, storage) == 0 and partial.Parent == imports, "partial first import must stay put")
partial:Destroy()
local doubled = rawBundle(imports)
local extra = doubled.PP_Lantern:Clone()
extra.Parent = doubled
check(staging.move(imports, storage) == 0 and doubled.Parent == imports, "duplicate mesh in a first import must stay put")
doubled:Destroy()
lib.Parent = map
local again = rawBundle(imports)
check(staging.move(imports, storage) == 1 and again:IsDescendantOf(storage), "known plot bundle not staged")
local unrelated = rawBundle(imports)
unrelated.PP_Water_Tower.MeshId = "rbxassetid://1"
check(staging.move(imports, storage) == 0 and unrelated.Parent == imports, "unrelated import moved")

local report = { checks = checks, sites = 68, assets = 12, lightsRetained = lights, buildTimeApply = true, staging = true }
if fs.isDir("build") then
	fs.writeFile("build/plot-props-validation.json", serde.encode("json", report, true))
end
print(serde.encode("json", report))
