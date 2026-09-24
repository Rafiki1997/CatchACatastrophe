-- Headless integration test using actual region/source modules and native mesh fixtures.
-- Run with Lune from the repository root. Fixture meshes are never exported to src.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local r = require("@lune/roblox")
local CF, V = r.CFrame, r.Vector3
local map = r.Instance.new("Folder")
local cache = {}
local function loadModule(module)
	if cache[module] then return cache[module] end
	local value = luau.load(module.Source, { environment = {
		script = module, require = function(other) return loadModule(other) end,
		Vector3 = V, CFrame = CF, Color3 = r.Color3, Enum = r.Enum, Instance = r.Instance,
		game = { GetService = function() return { AddTag = function() end } end },
	} })()
	cache[module] = value
	return value
end
for _, name in { "OrbitOutpost", "OrbitProps", "OrbitAssetSpec", "ImportStaging" } do
	local module = r.Instance.new("ModuleScript")
	module.Name = name
	module.Source = fs.readFile("src/server/Map/" .. name .. ".luau")
	module.Parent = map
end
local specs = loadModule(map.OrbitAssetSpec)
local props = loadModule(map.OrbitProps)
local staging = loadModule(map.ImportStaging)
local region = r.Instance.new("Model")
region.Name = "orbit_outpost"
local frame = CF.new(242.487, 0, 140) * CF.Angles(0, 1.1, 0)
loadModule(map.OrbitOutpost).build(region, frame, 75, function(s)
	local p = r.Instance.new("Part")
	p.Name, p.Size, p.CFrame = s.name, s.size, s.cf
	p.Color, p.Material = s.color, s.material
	p.Anchored, p.CanCollide, p.CanTouch = true, s.collide == true, false
	p.CanQuery = if s.query == nil then true else s.query
	p.Transparency = s.transparency or 0
	if s.shape then p.Shape = s.shape end
	p.Parent = s.parent
	return p
end)
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local sites = region.Landmarks.PropSites
check(#sites:GetChildren() == 51, "Claude layout site count changed")
check(not region:FindFirstChild("BlenderProps"), "missing templates must retain blockout")
local originalCount = #sites:GetDescendants()
local protected = {}
for _, host in { region.Boundary, region.Walkways, region.Landmarks.FieldLaboratory } do
	for _, p in host:GetDescendants() do
		if p:IsA("BasePart") then protected[p] = { p.Size, p.CFrame, p.CanCollide, p.Transparency } end
	end
end
local lights = {}
for _, light in region:GetDescendants() do
	if light:IsA("PointLight") then
		table.insert(lights, { position = light.Parent.CFrame.Position, brightness = light.Brightness,
			range = light.Range, color = light.Color })
	end
end
local native = r.deserializeModel(fs.readFile("src/server/Map/GustyPropTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
-- Lune exposes the serialized native size as InitialSize, while Studio's
-- read-only API calls it MeshSize. Bridge only this fixture property in memory.
if fixture then
	fixture.MeshSize = fixture.InitialSize
	local xml = r.serializeModel({ fixture }, true)
	fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
	fixture.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
end
assert(fixture and fixture.MeshSize.Magnitude > 0, "native fixture missing")
local library = r.Instance.new("Model")
library.Name, library.Parent = "OrbitPropTemplates", map
for name in specs do
	if name ~= "OO_Gravity_Meteor" then
		local mesh = fixture:Clone()
		mesh.Name, mesh.Parent = name, library
	end
end
check(not props.apply(region, frame) and #sites:GetDescendants() == originalCount, "partial kit modified blockout")
local meteor = fixture:Clone()
meteor.Name, meteor.Parent = "OO_Gravity_Meteor", library
local site = sites.GravityMeteor01
local size = site:GetAttribute("AssetSize")
site:SetAttribute("AssetSize", V.new(600, 1100, 600))
check(not props.apply(region, frame) and #sites:GetDescendants() == originalCount, "100x size was accepted")
site:SetAttribute("AssetSize", size)
local firstArt = site.PlaceholderArt:FindFirstChildWhichIsA("BasePart", true)
firstArt.CanCollide = true
check(not props.apply(region, frame) and #sites:GetDescendants() == originalCount, "solid placeholder destroyed")
firstArt.CanCollide = false
check(props.apply(region, frame), "valid kit failed")
check(#region.BlenderProps:GetChildren() == 51, "wrong placement count")
local triangles = 0
local manifest = serde.decode("json", fs.readFile("assets/orbit-outpost/props-v1/manifest.json"))
local triangleByName = {}
for _, item in manifest.assets do triangleByName[item.name] = item.triangles end
for _, s in sites:GetChildren() do
	local mesh = region.BlenderProps:FindFirstChild(s.Name)
	local expected = frame * s:GetAttribute("GroundCF")
	local bottom = mesh.CFrame * CF.new(0, -mesh.Size.Y/2, 0)
	check((bottom.Position-expected.Position).Magnitude < .001
		and bottom.LookVector:Dot(expected.LookVector) > .9999, s.Name .. " frame wrong")
	check(mesh.Size == s:GetAttribute("AssetSize") and mesh.Anchored
		and not mesh.CanCollide and not mesh.CanTouch and not mesh.CanQuery, s.Name .. " size/flags wrong")
	check(not s:FindFirstChild("PlaceholderArt") and s:GetAttribute("AssetPlaced"), "temporary art remains")
	triangles += triangleByName[s:GetAttribute("AssetName")]
end
for p, values in protected do
	check(p:IsDescendantOf(region) and p.Size == values[1] and p.CFrame == values[2]
		and p.CanCollide == values[3] and p.Transparency == values[4], "permanent geometry changed")
end
local afterLights = {}
for _, light in region:GetDescendants() do
	if light:IsA("PointLight") then
		local parent = light.Parent
		local cf = if parent:IsA("Attachment") then parent.Parent.CFrame * parent.CFrame else parent.CFrame
		table.insert(afterLights, { position = cf.Position, brightness = light.Brightness, range = light.Range, color = light.Color })
	end
end
check(#afterLights == #lights and #lights == 6, "light count changed")
for _, old in lights do
	local found = false
	for _, new in afterLights do
		if (old.position-new.position).Magnitude < .001 and old.brightness == new.brightness
			and old.range == new.range and old.color == new.color then found = true end
	end
	check(found, "light transform/settings lost")
end
check(not props.apply(region, frame) and #region.BlenderProps:GetChildren() == 51, "placement duplicates")
local imports, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
local raw = library:Clone()
raw.Name, raw.Parent = "OrbitPropsBundle", imports
for _, p in raw:GetDescendants() do
	if p:IsA("BasePart") then p.Anchored = false p.Size *= 100 end
end
check(staging.move(imports, storage) == 1 and raw:IsDescendantOf(storage), "native bundle not staged")
-- First import before native template registration.
library.Parent = nil
local first = raw:Clone()
first.Name, first.Parent = "OrbitPropsBundle", imports
check(staging.move(imports, storage) == 1 and first:IsDescendantOf(storage), "first import not staged")
for _, p in first:GetDescendants() do
	if p:IsA("BasePart") then check(p.Anchored, "raw gallery can fall") end
end
local partial = raw:Clone()
partial.Name, partial.Parent = "OrbitPropsBundle", imports
partial:FindFirstChild("OO_Gravity_Meteor"):Destroy()
check(staging.move(imports, storage) == 0 and partial.Parent == imports, "partial/unrelated bundle moved")
check(staging.move(imports, storage) == 0, "staging is not idempotent")
local report = { checks = checks, placements = 51, lightsRetained = #afterLights, placedTriangles = triangles,
	nativeAssets = "Fixture geometry only; actual Orbit upload not verified",
	completeKitRequired = true, wrongScaleRejected = true, collisionPreserved = true,
	glazingPreserved = true, idempotent = true, firstImportStaging = true }
fs.writeFile("build/orbit-placement-validation.json", serde.encode("json", report, true))
print(serde.encode("json", report))
