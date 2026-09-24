-- In-memory native fixture tests; never export substitute meshes into production.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local r = require("@lune/roblox")
local V, CF = r.Vector3, r.CFrame
local map = r.Instance.new("Folder")
local cache = {}
local function load(module)
	if cache[module] then return cache[module] end
	local value = luau.load(module.Source, { environment = {
		script = module, require = function(other) return load(other) end,
		Vector3 = V, CFrame = CF, Color3 = r.Color3, Enum = r.Enum, Instance = r.Instance,
		assert = assert, math = math, table = table, typeof = typeof, tostring = tostring, string = string,
		game = { GetService = function() return { AddTag = function() end } end },
	} })()
	cache[module] = value
	return value
end
for _, name in { "SplashwaterBay", "GardenBayProps", "SplashwaterTidepoolProps", "SplashwaterTidepoolAssetSpec" } do
	local path = "src/server/Map/" .. name .. ".luau"
	if fs.isFile(path) then
		local module = r.Instance.new("ModuleScript")
		module.Name, module.Source, module.Parent = name, fs.readFile(path), map
	end
end
local region = r.Instance.new("Model")
local frame = CF.new(0, 0, -560) * CF.Angles(0, math.pi, 0)
local function makePart(s)
	local p = r.Instance.new("Part")
	p.Name, p.Size, p.CFrame = s.name, s.size, s.cf
	p.Color, p.Material = s.color, s.material
	p.Anchored, p.CanCollide, p.CanTouch = true, s.collide == true, false
	p.CanQuery = s.query == true
	p.Parent = s.parent
	return p
end
local layout = load(map.SplashwaterBay).build(region, frame, 75, makePart)
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local sites = region.Landmarks:FindFirstChild("TidepoolSites")
check(sites ~= nil, "Bay needs explicit whole-assembly TidepoolSites")
local Spec = load(map.SplashwaterTidepoolAssetSpec)
local props = load(map.SplashwaterTidepoolProps)
local manifest = serde.decode("json", fs.readFile("assets/splashwater-bay/tidepools-v2/manifest.json"))
local byAsset = {}
for _, site in sites:GetChildren() do
	local name = site:GetAttribute("AssetName")
	byAsset[name] = (byAsset[name] or 0) + 1
	check(site:FindFirstChild("PlaceholderArt") ~= nil, "site lacks complete fallback group")
end
check(#sites:GetChildren() == sites:GetAttribute("AssetCount"), "site count metadata wrong")
for _, asset in manifest.assets do
	local d = asset.dimensions_studs_xyz
	check(Spec.tidepools[asset.name] == V.new(d[1], d[2], d[3]), "authored bounds differ from manifest")
	check((byAsset[asset.name] or 0) > 0, asset.name .. " has no placements")
	for name, xyz in asset.sockets_roblox_xyz_from_base do
		check(Spec.sockets[asset.name][name] == V.new(xyz[1], xyz[2], xyz[3]), "socket differs from manifest")
	end
end
check(byAsset.SB_Tidepool_Grotto == 1 and byAsset.SB_Cascade_Rocks == 1, "landmarks duplicated")
check(layout.field == V.new(100, 0, 62) and #layout.keepOut == 6, "spawn layout changed")
local originalCount = #region:GetDescendants()
check(not props.apply(region, frame) and #region:GetDescendants() == originalCount, "missing kit changed fallback")
local native = r.deserializeModel(fs.readFile("src/server/Map/CinderPropTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
fixture.MeshSize = fixture.InitialSize
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
fixture.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
local library = r.Instance.new("Model")
library.Name, library.Parent = Spec.library, map
for name, size in Spec.tidepools do
	if name ~= "SB_Hibiscus_Clump" then
		local mesh = fixture:Clone()
		mesh.Name, mesh.Size, mesh.Parent = name, size, library
	end
end
check(not props.apply(region, frame) and #region:GetDescendants() == originalCount, "partial kit changed fallback")
local last = fixture:Clone()
last.Name, last.Size, last.Parent = "SB_Hibiscus_Clump", V.new(6, 3, 6), library
last.Size *= 100
check(not props.apply(region, frame) and #region:GetDescendants() == originalCount, "100x native template accepted")
last.Size /= 100
local texture = last.TextureID
last.TextureID = ""
check(not props.apply(region, frame) and #region:GetDescendants() == originalCount, "untextured native template accepted")
last.TextureID = texture
local first = sites:GetChildren()[1]
local scale = first:GetAttribute("UniformScale")
first:SetAttribute("UniformScale", -1)
check(not props.apply(region, frame) and #region:GetDescendants() == originalCount, "invalid site scale accepted")
first:SetAttribute("UniformScale", scale)
local protected, solids = {}, {}
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") then
		if p.CanCollide then solids[p] = { p.Size, p.CFrame, p.CanQuery } end
		if p.Name == "TideRock" or p.Name == "TidePool" or p.Name == "SeaShell" or p.Name == "Starfish"
			or p.Name == "Driftwood" or p.Name == "BayBarrel" or p.Name == "PathStone" then
			protected[p] = { p.Size, p.CFrame, p.Transparency }
		end
	end
end
check(props.apply(region, frame), "valid complete kit refused")
local placements = #sites:GetChildren()
check(#region.TidepoolProps:GetChildren() == placements, "one mesh per assembly violated")
for _, site in sites:GetChildren() do
	local mesh = region.TidepoolProps:FindFirstChild(site.Name)
	local expected = frame * site:GetAttribute("GroundCF")
	local bottom = mesh.CFrame * CF.new(0, -mesh.Size.Y / 2, 0)
	check((bottom.Position - expected.Position).Magnitude < 0.001 and bottom.LookVector:Dot(expected.LookVector) > 0.9999,
		site.Name .. " incorrect bottom frame / double half-height")
	check((mesh.Size - Spec.tidepools[site:GetAttribute("AssetName")] * site:GetAttribute("UniformScale")).Magnitude < 0.0001, "nonuniform asset scale")
	check(mesh.MeshSize == fixture.MeshSize and mesh.TextureID == texture, "native metadata lost")
	check(mesh.Anchored and not mesh.CanCollide and not mesh.CanTouch and not mesh.CanQuery, "decorative mesh collision")
	check(not site:FindFirstChild("PlaceholderArt"), "duplicate primitive silhouette")
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.5, 0.5 } do
			local p = frame:PointToObjectSpace(mesh.CFrame:PointToWorldSpace(V.new(x * mesh.Size.X, 0, z * mesh.Size.Z)))
			check(math.abs(p.X) <= 138.01 and math.abs(p.Z) <= 98.01, site.Name .. " crosses cell wall")
			check(math.abs(p.X) >= 23.99 or math.abs(p.Z) < 65, site.Name .. " blocks gate throat")
		end
	end
end
for p, before in solids do
	check(p:IsDescendantOf(region) and p.CanCollide and p.Size == before[1] and p.CFrame == before[2]
		and p.CanQuery == before[3], "functional collision changed")
end
for p, before in protected do
	check(p:IsDescendantOf(region) and p.Size == before[1] and p.CFrame == before[2] and p.Transparency == before[3], "shore / small art changed")
end
for _, p in region:GetDescendants() do
	check(p.Name ~= "GrottoMouth", "obsolete mouth fill survived")
end
-- A socket test catches stale prototype waterfall coordinates and a half-height
-- offset applied to sockets that already describe positions from the base.
local function checkWater(host)
	local heroSites = {}
	for _, site in host.Landmarks.TidepoolSites:GetChildren() do
		heroSites[site:GetAttribute("AssetName")] = site
	end
	check(#host.TidepoolWaterEffects:GetChildren() == 9, "missing or duplicate native water surfaces")
	for _, p in host.TidepoolWaterEffects:GetChildren() do
		local site = heroSites[p:GetAttribute("AssetName")]
		local asset
		for _, candidate in manifest.assets do
			if candidate.name == p:GetAttribute("AssetName") then asset = candidate end
		end
		local function socket(name)
			local xyz = asset.sockets_roblox_xyz_from_base[name]
			return (frame * site:GetAttribute("GroundCF")):PointToWorldSpace(V.new(xyz[1], xyz[2], xyz[3]) * site:GetAttribute("UniformScale"))
		end
		local from, to, at = p:GetAttribute("SocketFrom"), p:GetAttribute("SocketTo"), p:GetAttribute("Socket")
		if from then
			check((p.CFrame:PointToWorldSpace(V.new(0, p.Size.Y / 2, 0)) - socket(from)).Magnitude < 0.001, "fall top detached from manifest lip")
			check((p.CFrame:PointToWorldSpace(V.new(0, -p.Size.Y / 2, 0)) - socket(to)).Magnitude < 0.001, "fall foot detached from manifest socket")
		elseif at then
			check((p.Position - socket(at)).Magnitude < 0.001, "water plane not at manifest socket")
		else
			check((p.Position - (socket("MidPool") + socket("LowerLip")) / 2).Magnitude < 0.001, "mid-pool does not bridge shelf sockets")
		end
		check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery, "water affects gameplay collision")
	end
	for _, p in host:GetDescendants() do
		check(p.Name ~= "GrottoFall" and p.Name ~= "CascadeFall" and p.Name ~= "CascadeShelfPool"
			and p.Name ~= "GrottoFallFoam" and p.Name ~= "CascadeFoam", "duplicate fallback effects survive")
	end
end
checkWater(region)
check(not props.apply(region, frame) and #region.TidepoolProps:GetChildren() == placements, "swap is not idempotent")
-- Load the captured imports when available. Bridge Lune's serialization names
-- only in memory; neither these fixtures nor bridges are exported to src.
library:Destroy()
local nativePath = "src/server/Map/SplashwaterTidepoolTemplates.rbxm"
if fs.isFile(nativePath) then
	local function importLibrary(path, name)
		local model = r.deserializeModel(fs.readFile(path))[1]
		model.Name = name
		for _, mesh in model:GetDescendants() do
			if mesh:IsA("MeshPart") then
				mesh.MeshSize = mesh.InitialSize
				local data = r.serializeModel({ mesh }, true)
				mesh.MeshId = assert(data:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
				mesh.TextureID = data:match('<Content name="TextureContent">%s*<uri>(.-)</uri>') or ""
			end
		end
		model.Parent = map
		return model
	end
	local actual = importLibrary(nativePath, Spec.library)
	importLibrary("src/server/Map/SplashwaterPropTemplates.rbxm", "SplashwaterPropTemplates")
	local realRegion = r.Instance.new("Model")
	load(map.SplashwaterBay).build(realRegion, frame, 75, makePart)
	check(realRegion:FindFirstChild("TidepoolProps") ~= nil, "captured native kit rejected")
	check(realRegion:FindFirstChild("BlenderProps") ~= nil, "old small-prop kit not applied alongside native tidepools")
	check(#realRegion.TidepoolProps:GetChildren() == placements, "real kit placement count differs")
	for _, mesh in realRegion.TidepoolProps:GetChildren() do
		local source = actual:FindFirstChild(mesh:GetAttribute("BlenderAsset"), true)
		check(mesh.MeshId == source.MeshId and mesh.MeshSize == source.MeshSize and mesh.TextureID == source.TextureID,
			"captured mesh or native scale lost")
	end
	checkWater(realRegion)
	print("Captured native library + old small-prop kit: PASS")
else
	print("Captured native library absent; fixture checks only")
end
print("Site breakdown:", serde.encode("json", byAsset))
print("Splashwater checks:", checks)
