-- Headless integration test for the Cinder Quarry layout and its asset swap.
-- Run with Lune from the repository root. Fixture meshes are never exported to
-- src: the Blender kit is delivered, but its native upload is still pending.
-- A MeshPart from an older imported bundle is used only for swap fixtures.
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
		assert = assert, math = math, table = table, typeof = typeof, tostring = tostring,
		game = { GetService = function() return { AddTag = function() end } end },
	} })()
	cache[module] = value
	return value
end
for _, name in { "CinderCanyon", "CinderQuarryProps", "CinderQuarryAssetSpec" } do
	local module = r.Instance.new("ModuleScript")
	module.Name = name
	module.Source = fs.readFile("src/server/Map/" .. name .. ".luau")
	module.Parent = map
end
local Spec = loadModule(map.CinderQuarryAssetSpec)
local props = loadModule(map.CinderQuarryProps)

local region = r.Instance.new("Model")
region.Name = "cinder_canyon"
-- The real frame MapBuilder hands over: region 3's centre, looking at the hub.
-- Local +X is world west, local -Z the Splashwater threshold.
local centre = V.new(0, 0, -260 - 2.5 * 200)
local frame = CF.fromMatrix(centre, V.new(-1, 0, 0), V.new(0, 1, 0), V.new(0, 0, -1))
local layout = loadModule(map.CinderCanyon).build(region, frame, 75, function(s)
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

-- ------------------------------------------------------------------ sites
local sites = region.Landmarks.PropSites
local manifest = serde.decode("json", fs.readFile("assets/cinder-canyon/quarry-v2/manifest.json"))
local delivered = {}
for _, asset in manifest.assets do delivered[asset.name] = asset end
local function socket(asset, name)
	local p = delivered[asset].sockets_roblox_xyz_from_base[name]
	return CF.new(p[1], p[2], p[3])
end
local function near(a, b) return (a - b).Magnitude < 0.002 end
local mineBase = sites.Mine01:GetAttribute("GroundCF")
local terraceBase = sites.Terrace01:GetAttribute("GroundCF")
check(near(sites.Rail01:GetAttribute("GroundCF").Position,
	(mineBase * socket("CC_Quarry_Mine", "DoorBase") * CF.new(0, 0.02, -13)).Position), "rail misses delivered DoorBase")
check(near(sites.Cart01:GetAttribute("GroundCF").Position,
	(mineBase * socket("CC_Quarry_Mine", "DoorBase") * CF.new(0, 1.05, -16)).Position), "cart misses delivered DoorBase")
check(near(sites.Hoist01:GetAttribute("GroundCF").Position,
	(terraceBase * socket("CC_Quarry_Terrace", "HoistBase")).Position), "hoist misses delivered shelf")
check(near(region.Landmarks.Effects.MineLanternGlass.CFrame.Position,
	(frame * mineBase * socket("CC_Quarry_Mine", "Lantern")).Position), "lantern misses delivered housing")
for _, site in sites:GetChildren() do
	check(not site:GetAttribute("SocketProvisional"), site.Name .. " retains provisional socket")
	if site:GetAttribute("AssetName") == "CC_Quarry_Crate" then
		local base = site:GetAttribute("GroundCF")
		local support = site:GetAttribute("SupportPath")
		if support == "Ground" then
			check(math.abs(base.Position.Y - 0.3) < 0.001, site.Name .. " floats over ground")
		else
			local below = sites:FindFirstChild(support)
			check(below and below:GetAttribute("AssetName") == "CC_Quarry_Crate", site.Name .. " unsupported crate stack")
			check(near(base.Position, (below:GetAttribute("GroundCF") * CF.new(0, 6, 0)).Position), site.Name .. " misses supporting crate")
		end
	end
end
local effects = region.Landmarks.Effects
local anchors = { "LavaUpperLip", "LavaLowerLip", "LavaFoot" }
for k = 1, 2 do
	local ribbon = effects:FindFirstChild("LavaFall" .. k)
	check(ribbon ~= nil, "missing socket-to-socket lava ribbon")
	local a = frame * terraceBase * socket("CC_Quarry_Terrace", anchors[k]) * CF.new(0, 0, -0.3)
	local b = frame * terraceBase * socket("CC_Quarry_Terrace", anchors[k + 1]) * CF.new(0, 0, -0.3)
	local endA = (ribbon.CFrame * CF.new(0, 0, ribbon.Size.Z / 2)).Position
	local endB = (ribbon.CFrame * CF.new(0, 0, -ribbon.Size.Z / 2)).Position
	check((near(endA, a.Position) and near(endB, b.Position))
		or (near(endA, b.Position) and near(endB, a.Position)), "lava ribbon misses manifest endpoints")
end
for _, name in { "Crystal01", "Crystal02" } do
	local core = effects:FindFirstChild(name .. "Core")
	check(core and near(core.CFrame.Position, (frame * terraceBase * socket("CC_Quarry_Terrace", name)).Position), "crystal misses delivered exposed pocket")
end
local pool = frame:ToObjectSpace(effects.LavaPool.CFrame).Position
local foot = (terraceBase * socket("CC_Quarry_Terrace", "LavaFoot")).Position
check(pool.Z + effects.LavaPool.Size.Z / 2 < 37, "pool remains buried in terrace footprint")
check(math.abs(pool.X - foot.X) < 0.001, "pool misses outer -X lava channel")
for _, part in effects:GetChildren() do
	if part.Name == "LavaKerb" then
		local p = frame:ToObjectSpace(part.CFrame).Position
		check(p.Y + part.Size.Y / 2 <= 1.3 and p.Z >= pool.Z - 0.001, "kerb obscures pool from south")
	end
end
local byAsset = {}
for _, site in sites:GetChildren() do
	local name = site:GetAttribute("AssetName")
	byAsset[name] = (byAsset[name] or 0) + 1
end
check(#sites:GetChildren() == sites:GetAttribute("AssetCount"), "AssetCount disagrees with the sites")
check(byAsset.CC_Quarry_Mine == 1 and byAsset.CC_Quarry_Terrace == 1
	and byAsset.CC_Quarry_Hoist == 1 and byAsset.CC_Quarry_Cart == 1
	and byAsset.CC_Quarry_Rail == 1, "one-off landmarks are not one-off")
for name in Spec.quarry do
	check((byAsset[name] or 0) > 0, name .. " has no site at all")
end
check(not region:FindFirstChild("BlenderProps"), "missing library must retain the blockout")

-- Every placeholder has to live inside the bounds its site promises, because
-- those bounds are what Astra is modelling to. A stand-in that overflows its
-- envelope is a layout that will move when the mesh lands.
local worst, worstBy = "", 0
local overflows = {}
for _, site in sites:GetChildren() do
	local size = site:GetAttribute("AssetSize")
	local ground = site:GetAttribute("GroundCF")
	local art = site.PlaceholderArt
	for _, p in art:GetDescendants() do
		if p:IsA("BasePart") then
			local local_ = ground:ToObjectSpace(frame:ToObjectSpace(p.CFrame))
			for _, sx in { -0.5, 0.5 } do
				for _, sy in { -0.5, 0.5 } do
					for _, sz in { -0.5, 0.5 } do
						local corner = local_ * CF.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz)
						local over = math.max(
							math.abs(corner.Position.X) - size.X / 2,
							math.abs(corner.Position.Z) - size.Z / 2,
							corner.Position.Y - size.Y,
							-corner.Position.Y)
						if over > worstBy then
							worstBy, worst = over, site.Name .. "/" .. p.Name
						end
						if over > 0.75 then
							overflows[site:GetAttribute("AssetName") .. " " .. p.Name] =
								math.max(overflows[site:GetAttribute("AssetName") .. " " .. p.Name] or 0, over)
						end
					end
				end
			end
		end
	end
	check(art:IsA("Model") and #art:GetChildren() > 0, site.Name .. " has no placeholder art")
	check(site:GetAttribute("PivotMode") == "BottomCenter" and site:GetAttribute("SizeLock") == "Fixed"
		and site:GetAttribute("CollisionRole") == "none", site.Name .. " metadata incomplete")
end
for name, over in overflows do
	print(("  OVERFLOW %-40s %.2f"):format(name, over))
end
check(worstBy <= 0.75, ("placeholder %s overflows its asset bounds by %.2f"):format(worst, worstBy))

-- Placeholder art is art. Containment is a proxy in Boundary, never a site.
for _, p in sites:GetDescendants() do
	if p:IsA("BasePart") then
		check(not p.CanCollide and not p.CanTouch and not p.CanQuery, p.Name .. " is solid placeholder art")
	end
end
local proxies = 0
for _, p in region.Boundary:GetDescendants() do
	if p:IsA("BasePart") then
		proxies += 1
		check(p.CanCollide and p.Transparency == 1 and p:GetAttribute("CollisionProxy"),
			p.Name .. " in Boundary is not an invisible collision proxy")
	end
end
check(proxies > 40, "too few collision proxies to contain the border")

-- ------------------------------------------------------------- the ground
-- Nothing this module builds may raise the walkable floor, because the Heat
-- telegraph is drawn flat at the creature's feet. Only shallow floor detail is
-- allowed to stand proud of y = 0.30 at all, and then by less than 0.05.
local LANE, GROUND_Y = 12, 0.30
local laneHits, floorHits = {}, {}
local function localBox(p)
	local at = frame:ToObjectSpace(p.CFrame)
	-- conservative: the axis-aligned box that contains the rotated part
	local ex = math.abs(at.RightVector.X) * p.Size.X + math.abs(at.UpVector.X) * p.Size.Y + math.abs(at.LookVector.X) * p.Size.Z
	local ez = math.abs(at.RightVector.Z) * p.Size.X + math.abs(at.UpVector.Z) * p.Size.Y + math.abs(at.LookVector.Z) * p.Size.Z
	local ey = math.abs(at.RightVector.Y) * p.Size.X + math.abs(at.UpVector.Y) * p.Size.Y + math.abs(at.LookVector.Y) * p.Size.Z
	return at.Position, ex / 2, ey / 2, ez / 2
end
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") then
		local at, ex, ey, ez = localBox(p)
		local top = at.Y + ey
		if p.CanCollide and math.abs(at.X) - ex < LANE and math.abs(at.Z) - ez < 100 and top > GROUND_Y + 0.05 then
			table.insert(laneHits, p.Name)
		end
		-- The two things that would bury a Heat telegraph: a crack or dust patch
		-- that is not flush, and any broad flat surface laid over the open floor
		-- at just above floor level -- a ground skin by another name. Loose
		-- stones are neither: they are small, walk-through and obviously props.
		if p.Parent and p.Parent.Name == "FloorDetail" then
			if p.Name ~= "Rubble" and top > GROUND_Y + 0.05 then
				table.insert(floorHits, p.Name .. " proud by " .. string.format("%.2f", top - GROUND_Y))
			elseif p.Name == "Rubble" and (p.CanCollide or ex * ez * 4 > 36 or top > GROUND_Y + 2) then
				table.insert(floorHits, "solid or oversized " .. p.Name)
			end
		elseif not p:IsDescendantOf(sites) and math.abs(at.X) < 92 and math.abs(at.Z) < 88
			and ex * ez * 4 > 40 and top > GROUND_Y + 0.05 and top < GROUND_Y + 1.5 then
			table.insert(floorHits, "ground skin: " .. p.Name)
		end
	end
end
check(#laneHits == 0, "solid geometry in the centre lane: " .. table.concat(laneHits, ", "))
check(#floorHits == 0, "floor detail stands proud of the walkable floor: " .. table.concat(floorHits, ", "))

-- Nothing may cross the cell walls or the gate throats.
local outside, throat = {}, {}
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") then
		local at, ex, ey, ez = localBox(p)
		if math.abs(at.X) + ex > 140.5 or math.abs(at.Z) + ez > 100.5 then
			table.insert(outside, p.Name)
		end
		if p.CanCollide and math.abs(at.X) - ex < 24 and math.abs(at.Z) + ez > 84 and at.Y + ey > GROUND_Y + 0.05 then
			table.insert(throat, p.Name)
		end
	end
end
check(#outside == 0, "geometry crosses the cell wall: " .. table.concat(outside, ", "))
check(#throat == 0, "geometry blocks a gate throat: " .. table.concat(throat, ", "))

-- --------------------------------------------------------------- the field
-- The rectangle the region reports for creature homes must actually be open
-- floor once the keep-out circles are applied. Replay EncounterService's own
-- pickHome / clearOf arithmetic against the built solids.
local solids = {}
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		local at, ex, _, ez = localBox(p)
		table.insert(solids, { at.X, at.Z, ex, ez, p.Name })
	end
end
local hitBy = {}
local function inSolid(x, z)
	for _, s in solids do
		if math.abs(x - s[1]) < s[3] and math.abs(z - s[2]) < s[4] then
			local key = ("%s at %d,%d"):format(s[5], s[1], s[2])
			hitBy[key] = (hitBy[key] or 0) + 1
			return true
		end
	end
	return false
end
local keepOut = {}
for _, zone in layout.keepOut do
	-- the module reports world offsets; bring them back into the local frame
	local at = frame:VectorToObjectSpace(zone.at)
	table.insert(keepOut, { at.X, at.Z, zone.radius or 0, zone.lane })
end
local function rejected(x, z)
	for _, k in keepOut do
		if k[4] then
			if math.abs(x - k[1]) < k[4] and math.abs(z - k[2]) < k[4] then return true end
		elseif k[3] > 0 and math.sqrt((x - k[1]) ^ 2 + (z - k[2]) ^ 2) < k[3] then
			return true
		end
	end
	return false
end
local seed, accepted, inside = 12345, 0, 0
local function nextRandom()
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end
for _ = 1, 6000 do
	local x = (nextRandom() * 2 - 1) * layout.field.X
	local z = (nextRandom() * 2 - 1) * layout.field.Z
	if not rejected(x, z) then
		accepted += 1
		if inSolid(x, z) then inside += 1 end
	end
end
for key, n in hitBy do
	print(("  HOME-IN-SOLID %-34s %d"):format(key, n))
end
check(accepted > 3000, ("only %d of 6000 field samples survive the keep-outs"):format(accepted))
check(inside == 0, ("%d accepted creature homes land inside solid geometry"):format(inside))

-- ------------------------------------------------------------ the asset swap
local originalCount = #sites:GetDescendants()
local nativeRegion = region:Clone()
local native = r.deserializeModel(fs.readFile("src/server/Map/CinderPropTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
if fixture then
	-- Lune exposes the serialized native size as InitialSize, while Studio's
	-- read-only API calls it MeshSize. Bridge only this fixture in memory.
	fixture.MeshSize = fixture.InitialSize
	local xml = r.serializeModel({ fixture }, true)
	fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
	fixture.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
end
assert(fixture and fixture.MeshSize.Magnitude > 0, "native fixture missing")
local library = r.Instance.new("Model")
library.Name, library.Parent = "CinderQuarryTemplates", map
for name in Spec.quarry do
	if name ~= "CC_Quarry_Crate" then
		local mesh = fixture:Clone()
		mesh.Size, mesh.MeshSize = Spec.quarry[name], Spec.quarry[name] * (256 / 9)
		mesh.Name, mesh.Parent = name, library
	end
end
check(not props.apply(region, frame) and #sites:GetDescendants() == originalCount,
	"a partial kit modified the blockout")
local crate = fixture:Clone()
crate.Size, crate.MeshSize = Spec.quarry.CC_Quarry_Crate, Spec.quarry.CC_Quarry_Crate * (256 / 9)
crate.Name, crate.Parent = "CC_Quarry_Crate", library

-- Reject bad *native data*, not only bad site attributes. Each attempt must
-- leave all art and collision intact, even if the fault belongs to a late type.
local function refused(message)
	local copy = region:Clone()
	check(not props.apply(copy, frame) and not copy:FindFirstChild("BlenderProps")
		and #copy.Landmarks.PropSites:GetDescendants() == originalCount, message)
	copy:Destroy()
end
local crateSize, nativeSize = crate.Size, crate.MeshSize
crate.Size = crateSize * 100
refused("100x native template Size accepted")
crate.Size = crateSize
crate.MeshSize = V.new(nativeSize.X * 2, nativeSize.Y, nativeSize.Z)
refused("distorted native MeshSize accepted")
crate.MeshSize = V.new(0, nativeSize.Y, nativeSize.Z)
refused("zero native MeshSize axis accepted")
crate.MeshSize = nativeSize
local duplicate = crate:Clone()
duplicate.Parent = library
refused("ambiguous duplicate template accepted")
duplicate:Destroy()
local meshId, texture = crate.MeshId, crate.TextureID
crate.MeshId = "rbxassetid://0"
refused("zero mesh id accepted")
crate.MeshId = meshId
crate.TextureID = ""
refused("untextured template accepted")
crate.TextureID = texture
local bad = r.Instance.new("Part")
bad.Name, bad.Parent = "UnexpectedCollider", crate
refused("template with nested physical geometry accepted")
bad:Destroy()

local mine = sites.Mine01
local size = mine:GetAttribute("AssetSize")
mine:SetAttribute("AssetSize", size * 100)
check(not props.apply(region, frame) and #sites:GetDescendants() == originalCount, "a 100x import was accepted")
mine:SetAttribute("AssetSize", size)

local firstArt = mine.PlaceholderArt:FindFirstChildWhichIsA("BasePart", true)
firstArt.CanCollide = true
check(not props.apply(region, frame) and #sites:GetDescendants() == originalCount, "solid placeholder was destroyed")
firstArt.CanCollide = false

-- what must survive the swap untouched
local protected = {}
for _, p in region.Boundary:GetDescendants() do
	if p:IsA("BasePart") then protected[p] = { p.Size, p.CFrame, p.CanCollide, p.Transparency } end
end
local effectLights = 0
for _, light in region.Landmarks.Effects:GetDescendants() do
	if light:IsA("PointLight") then effectLights += 1 end
end

local placements = #sites:GetChildren()
check(props.apply(region, frame), "the complete kit was refused")
check(#region.BlenderProps:GetChildren() == placements, "wrong placement count")
for _, site in sites:GetChildren() do
	local mesh = region.BlenderProps:FindFirstChild(site.Name)
	local expected = frame * site:GetAttribute("GroundCF")
	local bottom = mesh.CFrame * CF.new(0, -mesh.Size.Y / 2, 0)
	check((bottom.Position - expected.Position).Magnitude < 0.001
		and bottom.LookVector:Dot(expected.LookVector) > 0.9999, site.Name .. " frame wrong")
	check(mesh.Size == site:GetAttribute("AssetSize") and mesh.Anchored and not mesh.CanCollide
		and not mesh.CanTouch and not mesh.CanQuery, site.Name .. " size or flags wrong")
	check(not site:FindFirstChild("PlaceholderArt") and site:GetAttribute("AssetPlaced"), "temporary art remains")
end
for p, values in protected do
	check(p:IsDescendantOf(region) and p.Size == values[1] and p.CFrame == values[2]
		and p.CanCollide == values[3] and p.Transparency == values[4], "a collision proxy changed")
end
local afterLights = 0
for _, light in region.Landmarks.Effects:GetDescendants() do
	if light:IsA("PointLight") then afterLights += 1 end
end
check(afterLights == effectLights and effectLights > 0, "effect lights lost in the swap")
check(not props.apply(region, frame) and #region.BlenderProps:GetChildren() == placements, "placement duplicates")

-- Exercise the actual captured twelve-mesh library, without changing native
-- data on disk. Lune exposes serialized properties under their file names.
library:Destroy()
local deliveredNative = r.deserializeModel(fs.readFile("src/server/Map/CinderQuarryTemplates.rbxm"))[1]
deliveredNative.Parent = map
local nativeByName = {}
for _, mesh in deliveredNative:GetDescendants() do
	if mesh:IsA("MeshPart") then
		mesh.MeshSize = mesh.InitialSize
		local xml = r.serializeModel({ mesh }, true)
		mesh.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
		mesh.TextureID = assert(xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>'))
		nativeByName[mesh.Name] = mesh
	end
end
check(props.apply(nativeRegion, frame), "actual uploaded quarry library was rejected")
check(#nativeRegion.BlenderProps:GetChildren() == placements, "actual uploaded kit did not replace every site")
for _, mesh in nativeRegion.BlenderProps:GetChildren() do
	local original = nativeByName[mesh:GetAttribute("BlenderAsset")]
	check(mesh.MeshSize == original.MeshSize and mesh.MeshId == original.MeshId
		and mesh.TextureID == original.TextureID, "swap altered uploaded native mesh/texture data")
	local at, ex, _, ez = localBox(mesh)
	check(math.abs(at.X) + ex <= 140.5 and math.abs(at.Z) + ez <= 100.5, "native mesh crosses cell wall")
	check(math.abs(at.X) - ex >= 12, "native mesh enters 24-stud route")
end

local report = {
	checks = checks,
	sites = placements,
	siteBreakdown = byAsset,
	collisionProxies = proxies,
	effectLights = effectLights,
	field = { layout.field.X, layout.field.Z },
	keepOut = #layout.keepOut,
	fieldSamplesAccepted = accepted,
	homesInsideSolids = inside,
	laneClear = true,
	gateThroatsClear = true,
	wallsRespected = true,
	floorHeightPreserved = true,
	completeKitRequired = true,
	wrongScaleRejected = true,
	solidPlaceholderRejected = true,
	idempotent = true,
	nativeAssets = "Actual uploaded CinderQuarryTemplates.rbxm passed headless placement; malformed cases use in-memory fixtures",
}
if not fs.isDir("build") then fs.writeDir("build") end
fs.writeFile("build/cinder-placement-validation.json", serde.encode("json", report, true))
print(serde.encode("json", report))
