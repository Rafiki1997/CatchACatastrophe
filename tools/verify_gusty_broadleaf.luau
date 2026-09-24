-- Native fixtures exist only in memory; this does not claim actual asset loading.
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
		game = { GetService = function() return { AddTag = function() end } end },
	} })()
	cache[m] = result
	return result
end
local Spec, Props, Staging = load(map.GustyBroadleafSpec), load(map.GustyBroadleafProps), load(map.ImportStaging)
local frame = CF.fromMatrix(V.new(0, 0, -315), V.new(-1, 0, 0), V.new(0, 1, 0), V.new(0, 0, -1))
local checks = 0
local function check(ok, why) assert(ok, why); checks += 1 end
local manifest = serde.decode("json", fs.readFile(Spec.manifest))
for _, a in manifest.assets do
	check((Spec.parts[a.name].size - V.new(table.unpack(a.dimensions_studs_xyz))).Magnitude < 0.0001, "manifest size mismatch")
	check((Spec.parts[a.name].center - V.new(table.unpack(a.center))).Magnitude < 0.0001, "manifest center mismatch")
end
local base = r.Instance.new("Model")
base.Name = "gusty_gardens"
local shape = load(map.GustyGardens).build(base, frame, 75, function(s)
	local p = r.Instance.new("Part")
	p.Name, p.Size, p.CFrame = s.name, s.size, s.cf
	p.Color, p.Material = s.color, s.material
	p.Anchored, p.CanCollide, p.CanTouch = true, s.collide == true, false
	p.CanQuery = if s.query == nil then true else s.query
	p.Transparency = s.transparency or 0
	p.Parent = s.parent
	return p
end)
check(shape.field == V.new(96, 0, 56) and #shape.keepOut == 3, "field contract changed")
check(#base.Boundary.BroadleafSites:GetChildren() == 35, "site grouping incomplete")
check(not Props.apply(base, frame), "missing kit changed trees")

-- Compare the pre-restyle measured trees, including all positions/rotations,
-- against the newly grouped fallback source, not a second copy of the generator.
local old = serde.decode("json", fs.readFile("assets/gusty-gardens/broadleaf-v2/region-inventory.json"))
local used, matched = {}, 0
for _, p in base:GetDescendants() do
	if p:IsA("BasePart") and (p.Name == "MeadowTreeTrunk" or p.Name == "MeadowTreeLobe") then
		local match = nil
		for i, a in old.geometry do
			if not used[i] and a.name == p.Name and (p.Size - V.new(table.unpack(a.size))).Magnitude < 0.001 then
				local cf = CF.new(table.unpack(a.cf))
				local delta = cf:ToObjectSpace(p.CFrame)
				local _, angle = delta:ToAxisAngle()
				if delta.Position.Magnitude < 0.001 and math.abs(angle) < 0.001 then match = i break end
			end
		end
		check(match ~= nil, "fallback tree geometry changed " .. p.Name)
		check(old.geometry[match].collide == p.CanCollide and old.geometry[match].material == p.Material.Name, "fallback material/collision changed")
		used[match] = true; matched += 1
	end
end
check(matched == 245, "not all fallback tree components compared")

local native = r.deserializeModel(fs.readFile("src/server/Map/CinderQuarryTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
fixture.MeshSize = fixture.InitialSize
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
fixture.TextureID = "rbxassetid://1"
local library = r.Instance.new("Model")
library.Name, library.Parent = Spec.library, map
library:SetAttribute("NativeMeshYawDegrees", 180)
for name, def in Spec.parts do
	local p = fixture:Clone()
	p.Name, p.Size, p.MeshSize, p.Parent = name, def.size, def.size * 100, library
end
local first = library:GetChildren()[1]
local function refuse(why, region)
	local copy = region or base:Clone()
	local n = #copy:GetDescendants()
	check(not Props.apply(copy, frame) and not copy:FindFirstChild("BroadleafTrees") and #copy:GetDescendants() == n, why)
	for _, site in copy.Boundary.BroadleafSites:GetChildren() do
		check(site.MeadowTreeTrunk.Transparency == 0 and site:FindFirstChild("PlaceholderArt") ~= nil, "partial retirement on rejection")
	end
	copy:Destroy()
end
first.Parent = nil; refuse("partial kit accepted"); first.Parent = library
library:SetAttribute("NativeMeshYawDegrees", nil); refuse("unverified orientation accepted"); library:SetAttribute("NativeMeshYawDegrees", 180)
local oldSize, oldNative = first.Size, first.MeshSize
first.Size *= 100; refuse("100x import accepted"); first.Size = oldSize
first.MeshSize *= V.new(1, 2, 1); refuse("distorted mesh accepted"); first.MeshSize = oldNative
local texture = first.TextureID; first.TextureID = ""; refuse("missing texture accepted"); first.TextureID = texture
local dup = first:Clone(); dup.Parent = library; refuse("duplicate template accepted"); dup:Destroy()
local rogue = r.Instance.new("Script"); rogue.Parent = first; refuse("script accepted"); rogue:Destroy()
local copy = base:Clone(); copy.Boundary.BroadleafSites:GetChildren()[1]:SetAttribute("AssetScale", 0); refuse("zero scale accepted", copy)
copy = base:Clone(); copy.Boundary.BroadleafSites:GetChildren()[1].MeadowTreeTrunk.CFrame *= CF.new(1, 0, 0); refuse("shifted proxy accepted", copy)
copy = base:Clone(); copy.Boundary.BroadleafSites:GetChildren()[1].PlaceholderArt:GetChildren()[1].CanCollide = true; refuse("solid art accepted", copy)
copy = base:Clone(); copy.Boundary.BroadleafSites:GetChildren()[1]:Destroy(); refuse("partial sites accepted", copy)

local protected = {}
for _, p in base:GetDescendants() do
	if p:IsA("BasePart") and not p:IsDescendantOf(base.Boundary.BroadleafSites) then
		protected[p] = { p.Size, p.CFrame, p.CanCollide, p.CanQuery, p.Transparency, p.Material, p.Color }
	end
end
local proxies = {}
for _, site in base.Boundary.BroadleafSites:GetChildren() do
	proxies[site.Name] = { site.MeadowTreeTrunk.Size, site.MeadowTreeTrunk.CFrame }
end
check(Props.apply(base, frame), "valid library rejected")
check(base:GetAttribute("BroadleafCount") == 35 and base:GetAttribute("BroadleafPartCount") == 105, "wrong counts")
local counts, parts = { A = 0, B = 0, C = 0 }, 0
for _, site in base.Boundary.BroadleafSites:GetChildren() do
	local tree = base.BroadleafTrees[site.Name]
	local scale = site:GetAttribute("AssetScale")
	local baseCF = frame * site:GetAttribute("GroundCF")
	local id = tree:GetAttribute("Variant"); counts[id] += 1
	check(tree:GetAttribute("BaseCF") == baseCF and tree:GetAttribute("UniformScale") == scale, "root socket or scale changed")
	check(not site:FindFirstChild("PlaceholderArt") and site.MeadowTreeTrunk.Transparency == 1, "placeholder visible")
	check(site.MeadowTreeTrunk.Size == proxies[site.Name][1] and site.MeadowTreeTrunk.CFrame == proxies[site.Name][2]
		and site.MeadowTreeTrunk.CanCollide and not site.MeadowTreeTrunk.CanQuery, "collision proxy changed")
	for _, p in tree:GetChildren() do
		parts += 1
		local def = Spec.parts[p.Name]
		check((p.Size - def.size * scale).Magnitude < 0.001 and p.MeshSize == library[p.Name].MeshSize, "native dimensions corrupted")
		check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and p.MeshId == library[p.Name].MeshId, "native flags or identity changed")
		check((baseCF:PointToObjectSpace(p.CFrame.Position) - def.center * scale).Magnitude < 0.001, "component offset changed")
		local relative = (baseCF * CF.new(def.center * scale) * CF.Angles(0, math.pi, 0)):ToObjectSpace(p.CFrame)
		local _, angle = relative:ToAxisAngle()
		check(math.abs(angle) < 0.001, "native mesh orientation not corrected")
		for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
			local q = baseCF:PointToObjectSpace(p.CFrame * V.new(x * p.Size.X / 2, y * p.Size.Y / 2, z * p.Size.Z / 2)) / scale
			check(q.X >= Spec.envelopeMin.X - .003 and q.Y >= Spec.envelopeMin.Y - .003 and q.Z >= Spec.envelopeMin.Z - .003
				and q.X <= Spec.envelopeMax.X + .003 and q.Y <= Spec.envelopeMax.Y + .003 and q.Z <= Spec.envelopeMax.Z + .003, "new crown escapes original envelope")
		end end end
	end
end
check(counts.A == 12 and counts.B == 12 and counts.C == 11 and parts == 105, "wrong distribution")
for p, a in protected do
	check(p:IsDescendantOf(base) and p.Size == a[1] and p.CFrame == a[2] and p.CanCollide == a[3] and p.CanQuery == a[4]
		and p.Transparency == a[5] and p.Material == a[6] and p.Color == a[7], "non-tree scenery changed")
end
check(not Props.apply(base, frame), "second apply duplicated trees")
local source, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
local raw = library:Clone(); raw.Name, raw.Parent = Spec.bundle, source
library.Parent = nil
check(Staging.move(source, storage) == 1 and raw.Parent == storage.RegionImportStaging, "first import not staged")
local partial = raw:Clone(); partial.Name, partial.Parent = Spec.bundle, source; partial:GetChildren()[1]:Destroy()
check(Staging.move(source, storage) == 0 and partial.Parent == source, "incomplete import moved")
library.Parent = map
print(serde.encode("json", { checks = checks, sites = 35, distribution = counts, parts = parts, nativeStatus = "In-memory fixture checks; separate real Studio evidence in integration-status.json" }))
