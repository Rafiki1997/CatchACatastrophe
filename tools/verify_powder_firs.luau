-- Geometry/atomic replacement checks. Native fixtures exist only in memory;
-- this does not stand in for uploading or visually testing the actual FBXs.
local fs, luau, r, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox"), require("@lune/serde")
local V, CF = r.Vector3, r.CFrame
local map, cache = r.Instance.new("Folder"), {}
for _, file in fs.readDir("src/server/Map") do
	if file:sub(-5) == ".luau" then
		local m = r.Instance.new("ModuleScript")
		m.Name, m.Source, m.Parent = file:sub(1, -6), fs.readFile("src/server/Map/" .. file), map
	end
end
local function load(m)
	if cache[m] then return cache[m] end
	local result = luau.load(m.Source, { environment = {
		script = m, require = function(other) return load(other) end,
		Instance = r.Instance, Vector3 = V, CFrame = CF, Color3 = r.Color3, Enum = r.Enum,
		NumberRange = r.NumberRange, NumberSequence = r.NumberSequence, NumberSequenceKeypoint = r.NumberSequenceKeypoint,
		ColorSequence = r.ColorSequence, Vector2 = r.Vector2,
		game = { GetService = function() return { AddTag = function() end } end },
	} })()
	cache[m] = result
	return result
end
local Spec, Alpine = load(map.FrostbitePowderSpec), load(map.FrostbiteAlpineAssetSpec)
local Props, AlpineProps, Staging = load(map.FrostbitePowderProps), load(map.FrostbiteAlpineProps), load(map.ImportStaging)
local frame = CF.fromMatrix(V.new(0, 0, -915), V.new(-1, 0, 0), V.new(0, 1, 0), V.new(0, 0, -1))
local checks = 0
local function check(ok, why) assert(ok, why); checks += 1 end
local manifest = serde.decode("json", fs.readFile(Spec.manifest))
for _, a in manifest.assets do
	check((Spec.parts[a.name].size - V.new(table.unpack(a.dimensions_studs_xyz))).Magnitude < 0.0001, "manifest size mismatch")
	check((Spec.parts[a.name].center - V.new(table.unpack(a.center))).Magnitude < 0.0001, "manifest centre mismatch")
end
for i, a in manifest.variants do
	check((Spec.variants[i].size - V.new(table.unpack(a.size))).Magnitude < 0.0001, "variant bounds mismatch")
	check((Spec.variants[i].root - V.new(table.unpack(a.trunk_base))).Magnitude < 0.0001, "root mismatch")
end
local base = r.Instance.new("Model")
base.Name = "frostbite_peaks"
load(map.FrostbitePeaks).build(base, frame, 75, function(s)
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
check(not Props.apply(base, frame), "missing kit changed existing trees")
local native = r.deserializeModel(fs.readFile("src/server/Map/CinderQuarryTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
fixture.MeshSize = fixture.InitialSize
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
fixture.TextureID = "rbxassetid://1"
local library = r.Instance.new("Model")
library.Name, library.Parent = Spec.library, map
for name, part in Spec.parts do
	local p = fixture:Clone()
	p.Name, p.Size, p.MeshSize, p.Parent = name, part.size, part.size * 100, library
end
local first = library:GetChildren()[1]
local function refuse(why, region)
	local copy = region or base:Clone()
	local n = #copy:GetDescendants()
	check(not Props.apply(copy, frame) and not copy:FindFirstChild("PowderFirs") and #copy:GetDescendants() == n, why)
	copy:Destroy()
end
first.Parent = nil; refuse("partial kit accepted"); first.Parent = library
local originalSize, originalNative = first.Size, first.MeshSize
first.Size *= 100; refuse("100x scale accepted"); first.Size = originalSize
first.MeshSize *= V.new(1, 2, 1); refuse("distorted native bounds accepted"); first.MeshSize = originalNative
local texture = first.TextureID; first.TextureID = ""; refuse("untextured template accepted"); first.TextureID = texture
local dup = first:Clone(); dup.Parent = library; refuse("duplicate template accepted"); dup:Destroy()
local rogue = r.Instance.new("Script"); rogue.Parent = first; refuse("script in library accepted"); rogue:Destroy()
local copy = base:Clone()
for _, site in copy.Landmarks.PropSites:GetChildren() do
	if Spec.firs[site:GetAttribute("AssetName")] then
		site.PlaceholderArt:FindFirstChildWhichIsA("BasePart", true).CanCollide = true
		break
	end
end
refuse("solid art removed", copy)
copy = base:Clone()
for _, site in copy.Landmarks.PropSites:GetChildren() do
	if Spec.firs[site:GetAttribute("AssetName")] then site:SetAttribute("AssetSize", V.new(100, 26, 100)); break end
end
refuse("invalid site bounds accepted", copy)

local function exercise(region)
	local protected, treeSites = {}, {}
	local old = region:FindFirstChild("BlenderProps")
	for _, site in region.Landmarks.PropSites:GetChildren() do
		if Spec.firs[site:GetAttribute("AssetName")] then table.insert(treeSites, site) end
	end
	for _, obj in region:GetDescendants() do
		if not obj:IsA("BasePart") then continue end
		local treeArt = false
		for _, site in treeSites do
			if obj:IsDescendantOf(site) or (old and obj.Parent == old and obj.Name == site.Name) then treeArt = true break end
		end
		if not treeArt then protected[obj] = { obj.Size, obj.CFrame, obj.Transparency, obj.CanCollide, obj.CanQuery } end
	end
	check(Props.apply(region, frame), "valid full kit refused")
	check(#treeSites == 91 and region:GetAttribute("PowderFirCount") == 91, "not all 91 sites replaced")
	check(#region.PowderFirs:GetChildren() == 91, "wrong tree count")
	local distribution, parts = { A = 0, B = 0, C = 0 }, 0
	for _, site in treeSites do
		local tree = region.PowderFirs[site.Name]
		local id = tree:GetAttribute("Variant")
		distribution[id] += 1
		local variant
		for _, v in Spec.variants do if v.id == id then variant = v end end
		local scale = tree:GetAttribute("UniformScale")
		local baseCF = tree:GetAttribute("BaseCF")
		local siteCF = frame * site:GetAttribute("GroundCF")
		local oldRoot = Alpine.sockets[site:GetAttribute("AssetName")].TrunkBase.Position * site:GetAttribute("AssetScale")
		check(((baseCF * CF.new(variant.root * scale)).Position - (siteCF * CF.new(oldRoot)).Position).Magnitude < 0.001, "trunk anchor shifted")
		check(not site:FindFirstChild("PlaceholderArt") and (not old or not old:FindFirstChild(site.Name)), "old tree remains")
		check(#tree:GetChildren() == #variant.parts, "missing tree components")
		local size = site:GetAttribute("AssetSize")
		for _, p in tree:GetChildren() do
			parts += 1
			local def = Spec.parts[p.Name]
			check((p.Size - def.size * scale).Magnitude < 0.001 and p.MeshSize == library[p.Name].MeshSize, "native scale corrupted")
			check(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and p.MeshId == library[p.Name].MeshId, "flags/ID corrupted")
			local cf = siteCF:ToObjectSpace(p.CFrame)
			for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
				local q = cf * V.new(x * p.Size.X / 2, y * p.Size.Y / 2, z * p.Size.Z / 2)
				check(math.abs(q.X) <= size.X / 2 + 0.003 and math.abs(q.Z) <= size.Z / 2 + 0.003
					and q.Y >= -0.003 and q.Y <= size.Y + 0.003, "new crown escapes original site")
			end end end
		end
	end
	check(distribution.A == 31 and distribution.B == 30 and distribution.C == 30, "variant distribution wrong")
	check(parts == 425 and region:GetAttribute("PowderFirPartCount") == parts, "component total wrong")
	for p, before in protected do
		check(p:IsDescendantOf(region) and p.Size == before[1] and p.CFrame == before[2]
			and p.Transparency == before[3] and p.CanCollide == before[4] and p.CanQuery == before[5], "non-tree scenery changed")
	end
	check(not Props.apply(region, frame), "second application duplicated trees")
	return distribution
end
local distribution = exercise(base:Clone())
local alpineLibrary = r.Instance.new("Model")
alpineLibrary.Name, alpineLibrary.Parent = Alpine.library, map
for name, size in Alpine.alpine do
	local p = fixture:Clone();p.Name, p.Size, p.MeshSize, p.Parent = name, size, size * 100, alpineLibrary
end
local nativeRegion = base:Clone()
check(AlpineProps.apply(nativeRegion, frame), "native fixture setup failed")
exercise(nativeRegion)
check(#nativeRegion.BlenderProps:GetChildren() == 191 and nativeRegion:GetAttribute("BlenderPropCount") == 191, "non-fir native count wrong")
local source, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
local raw = library:Clone();raw.Name, raw.Parent = Spec.bundle, source
check(Staging.move(source, storage) == 1 and raw.Parent == storage.RegionImportStaging, "new gallery not staged")
local partial = library:Clone();partial.Name, partial.Parent = Spec.bundle, source;partial:GetChildren()[1]:Destroy()
check(Staging.move(source, storage) == 0 and partial.Parent == source, "partial gallery moved")
print(serde.encode("json", { checks = checks, trees = 91, distribution = distribution, parts = 425,
	nativeStatus = "In-memory fixtures only; actual Powder Fir upload and Studio visual validation still required" }))
