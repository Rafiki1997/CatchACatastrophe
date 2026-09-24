-- Run from the repository root with Lune. Uses the captured native Thunder kit.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local serde = require("@lune/serde")
local map = r.Instance.new("Folder")
local cache = {}
local function loadModule(module)
	if cache[module] then return cache[module] end
	local value = luau.load(module.Source, { environment = {
		script = module, require = loadModule, Vector3 = r.Vector3, CFrame = r.CFrame,
		Color3 = r.Color3, Enum = r.Enum, Instance = r.Instance,
	} })()
	cache[module] = value
	return value
end
for _, name in { "Thunderworks", "ThunderProps", "ThunderAssetSpec", "OrbitAssetSpec", "ImportStaging" } do
	local module = r.Instance.new("ModuleScript")
	module.Name, module.Source, module.Parent = name, fs.readFile("src/server/Map/" .. name .. ".luau"), map
end
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local region = r.Instance.new("Model")
local frame = r.CFrame.new(242.487, 0, -140) * r.CFrame.Angles(0, 1.1, 0)
loadModule(map.Thunderworks).build(region, frame, 75, function(s)
	local p = r.Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Parent = s.name, s.size, s.cf, s.parent
	p.Material, p.Color = s.material, s.color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, s.collide == true, false, s.query == true
	return p
end)
local sites = region.Landmarks.PropSites
check(#sites:GetChildren() == 33 and not region:FindFirstChild("BlenderProps"), "missing kit must retain 33 placeholders")
local protected, lights = {}, 0
for _, v in region:GetDescendants() do
	if v:IsA("PointLight") then lights += 1 end
	if v:IsA("BasePart") and not v:IsDescendantOf(sites) then
		protected[v] = { v.Size, v.CFrame, v.CanCollide, v.Transparency }
	end
end
local lib = r.deserializeModel(fs.readFile("src/server/Map/ThunderPropTemplates.rbxm"))[1]
lib.Parent = map
for _, mesh in lib:GetChildren() do
	-- Lune's serializer exposes current native content through legacy property names.
	mesh.MeshSize = mesh.InitialSize
	local xml = r.serializeModel({ mesh }, true)
	mesh.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
	mesh.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
end
local props = loadModule(map.ThunderProps)
local removed = lib.TW_Transformer
removed.Parent = nil
check(not props.apply(region, frame) and sites.TransformerSite01:FindFirstChild("PlaceholderArt"), "partial kit removed art")
removed.Parent = lib
local site = sites.TransformerSite01
local size = site:GetAttribute("AssetSize")
site:SetAttribute("AssetSize", size * 100)
check(not props.apply(region, frame), "100x size accepted")
site:SetAttribute("AssetSize", size)
local art = site.PlaceholderArt:FindFirstChildWhichIsA("BasePart")
art.CanCollide = true
check(not props.apply(region, frame), "solid placeholder would be deleted")
art.CanCollide = false
check(props.apply(region, frame), "native kit did not apply")
check(#region.BlenderProps:GetChildren() == 33, "wrong placement count")
for _, s in sites:GetChildren() do
	local v = region.BlenderProps:FindFirstChild(s.Name)
	local template = lib:FindFirstChild(s:GetAttribute("AssetName"))
	local cf = frame * s:GetAttribute("GroundCF") * r.CFrame.new(0, s:GetAttribute("AssetSize").Y / 2, 0)
	check(v.MeshId == template.MeshId and v.MeshSize == template.MeshSize and v.TextureID == template.TextureID, "native content changed")
	check(v.Size == s:GetAttribute("AssetSize") and (v.CFrame.Position - cf.Position).Magnitude < .001
		and v.CFrame.LookVector:Dot(cf.LookVector) > .9999, "wrong mesh placement")
	check(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery, "unsafe flags")
	check(s:GetAttribute("AssetPlaced") and not s:FindFirstChild("PlaceholderArt"), "placeholder remains")
end
for p, old in protected do
	check(p:IsDescendantOf(region) and p.Size == old[1] and p.CFrame == old[2]
		and p.CanCollide == old[3] and p.Transparency == old[4], "permanent geometry changed")
end
local afterLights = 0
for _, v in region:GetDescendants() do if v:IsA("PointLight") then afterLights += 1 end end
check(lights == 6 and afterLights == lights, "region lights lost")
check(not props.apply(region, frame), "repeat placement duplicated assets")
check(not region.Walkways:FindFirstChild("YardSkin"), "raised skin buries warnings")
for _, p in region.Landmarks:GetChildren() do
	if p:IsA("BasePart") and p.Name:match("^Yard") then
		local half = math.abs(p.CFrame.UpVector.Y) * p.Size.Y / 2
			+ math.abs(p.CFrame.RightVector.Y) * p.Size.X / 2 + math.abs(p.CFrame.LookVector.Y) * p.Size.Z / 2
		check(p.CFrame.Position.Y + half < .31 and not p.CanCollide, "floor mark buries warnings")
	end
end
local imports, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
local raw = lib:Clone()
raw.Name, raw.Parent = "ThunderworksPropsBundle", imports
for _, p in raw:GetChildren() do p.Anchored = false; p.Size *= 100 end
local staging = loadModule(map.ImportStaging)
check(staging.move(imports, storage) == 1 and raw:IsDescendantOf(storage), "raw import not staged")
for _, p in raw:GetChildren() do check(p.Anchored, "raw import can fall") end
local unrelated = lib:Clone()
unrelated.Name, unrelated.Parent = "ThunderworksPropsBundle", imports
unrelated.TW_Transformer.MeshId = "rbxassetid://1"
check(staging.move(imports, storage) == 0 and unrelated.Parent == imports, "unrelated import moved")
local report = { checks = checks, placements = 33, nativeAssets = 8, lightsRetained = 6,
	collisionPreserved = true, wrongScaleRejected = true, floorMarksBelowWarning = true, staging = true }
fs.writeFile("build/thunder-placement-validation.json", serde.encode("json", report, true))
print(serde.encode("json", report))
