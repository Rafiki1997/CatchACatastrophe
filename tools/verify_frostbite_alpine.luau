-- Headless integration test for the Alpine Outpost layout and its asset swap.
-- Run with Lune from the repository root:  lune run tools/verify_frostbite_alpine.luau
-- Astra's kit is not delivered, so the swap is exercised with fixture MeshParts
-- built in memory from an already uploaded native library; nothing here stands
-- in for the real Alpine meshes or proves how they look.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local r = require("@lune/roblox")
local CF, V = r.CFrame, r.Vector3
local fmt = string["format"]
local map = r.Instance.new("Folder")
map.Name = "Map"
local cache = {}
local function loadModule(module)
	if cache[module] then return cache[module] end
	local value = luau.load(module.Source, { environment = {
		script = module, require = function(other) return loadModule(other) end,
		Vector3 = V, CFrame = CF, Color3 = r.Color3, Enum = r.Enum, Instance = r.Instance,
		NumberRange = r.NumberRange, NumberSequence = r.NumberSequence,
		NumberSequenceKeypoint = r.NumberSequenceKeypoint, ColorSequence = r.ColorSequence,
		Vector2 = r.Vector2,
		assert = assert, math = math, table = table, typeof = typeof, tostring = tostring,
		type = type, pairs = pairs, ipairs = ipairs, error = error, string = string,
		game = { GetService = function() return { AddTag = function() end } end },
	} })()
	cache[module] = value
	return value
end
for _, name in { "FrostbitePeaks", "FrostbiteAlpineProps", "FrostbiteAlpineAssetSpec", "FrostbitePowderProps", "FrostbitePowderSpec", "ImportStaging",
	"CinderQuarryAssetSpec", "SplashwaterTidepoolAssetSpec", "OrbitAssetSpec", "PlotAssetSpec" } do
	local module = r.Instance.new("ModuleScript")
	module.Name = name
	module.Source = fs.readFile("src/server/Map/" .. name .. ".luau")
	module.Parent = map
end
local Spec = loadModule(map.FrostbiteAlpineAssetSpec)
local props = loadModule(map.FrostbiteAlpineProps)
local staging = loadModule(map.ImportStaging)

local region = r.Instance.new("Model")
region.Name = "frostbite_peaks"
-- The real frame MapBuilder hands over: region 4's centre, looking at the hub.
-- Local +X is world west, local -Z the Cinder threshold.
local centre = V.new(0, 0, -215 - 3.5 * 200)
local frame = CF.fromMatrix(centre, V.new(-1, 0, 0), V.new(0, 1, 0), V.new(0, 0, -1))
local layout = loadModule(map.FrostbitePeaks).build(region, frame, 75, function(s)
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
local GROUND_Y, TERRACE_Y, SHELF_Y, LANE = 0.30, 5.80, 8.80, 12

local function localBox(p)
	local at = frame:ToObjectSpace(p.CFrame)
	local ex = math.abs(at.RightVector.X) * p.Size.X + math.abs(at.UpVector.X) * p.Size.Y + math.abs(at.LookVector.X) * p.Size.Z
	local ez = math.abs(at.RightVector.Z) * p.Size.X + math.abs(at.UpVector.Z) * p.Size.Y + math.abs(at.LookVector.Z) * p.Size.Z
	local ey = math.abs(at.RightVector.Y) * p.Size.X + math.abs(at.UpVector.Y) * p.Size.Y + math.abs(at.LookVector.Y) * p.Size.Z
	return at.Position, ex / 2, ey / 2, ez / 2
end

-- --------------------------------------------------------------- manifest
-- The spec must say exactly what Astra delivered: every bound and every socket
-- the map uses, read straight from the manifest rather than trusted.
local manifest = serde.decode("json", fs.readFile(Spec.manifest))
local delivered = {}
for _, asset in manifest.assets do delivered[asset.name] = asset end
for name, size in Spec.alpine do
	local d = delivered[name]
	check(d ~= nil, name .. " is not in the delivered manifest")
	local dims = d.dimensions_studs_xyz
	check((V.new(dims[1], dims[2], dims[3]) - size).Magnitude < 0.005, name .. " bounds drift from the manifest")
end
for name, sockets in Spec.sockets do
	for socketName, cf in sockets do
		local xyz = delivered[name].sockets_roblox_xyz_from_base[socketName]
		check(xyz ~= nil, name .. "." .. socketName .. " is not a delivered socket")
		check((V.new(xyz[1], xyz[2], xyz[3]) - cf.Position).Magnitude < 0.002, name .. "." .. socketName .. " drifts from the manifest")
	end
end

-- ------------------------------------------------------------------ sites
local sites = region.Landmarks.PropSites
local byAsset = {}
local siteList = {}
for _, site in sites:GetChildren() do
	local name = site:GetAttribute("AssetName")
	local size = site:GetAttribute("AssetSize")
	local scale = site:GetAttribute("AssetScale")
	local base = Spec.alpine[name]
	check(base ~= nil, site.Name .. " names an asset outside the spec: " .. tostring(name))
	check(typeof(scale) == "number" and scale >= 0.25 and scale <= 2, site.Name .. " scale out of range")
	check((size - base * scale).Magnitude < 0.005, site.Name .. " AssetSize is not spec x scale")
	check(site:GetAttribute("PivotMode") == "BottomCenter" and site:GetAttribute("SizeLock") == "Uniform"
		and site:GetAttribute("CollisionRole") == "none" and site:GetAttribute("AssetLibrary") == Spec.library,
		site.Name .. " metadata incomplete")
	local role = site:GetAttribute("PlacementRole")
	check(role == "Grounded" or role == "Stacked", site.Name .. " has no placement role")
	check(typeof(site:GetAttribute("SupportPath")) == "string", site.Name .. " has no support path")
	check(typeof(site:GetAttribute("GroundCF")) == "CFrame", site.Name .. " has no GroundCF")
	byAsset[name] = (byAsset[name] or 0) + 1
	table.insert(siteList, site)
end
check(#sites:GetChildren() == sites:GetAttribute("AssetCount"), "AssetCount disagrees with the sites")
for name in Spec.alpine do
	check((byAsset[name] or 0) > 0, name .. " has no site at all")
end
check(byAsset.FP_Alpine_Lodge == 1 and byAsset.FP_Alpine_Bridge == 1 and byAsset.FP_Alpine_Shelf_North == 1
	and byAsset.FP_Alpine_Shelf_South == 1 and byAsset.FP_Alpine_Gorge_Rock == 1 and byAsset.FP_Alpine_Tent == 1,
	"one-off landmarks are not one-off")
check(not region:FindFirstChild("BlenderProps"), "missing library must retain the blockout")

-- Every placeholder lives inside the bounds its site promises, because those
-- bounds are what Astra models to.
local worst, worstBy = "", 0
for _, site in siteList do
	local size = site:GetAttribute("AssetSize")
	local ground = site:GetAttribute("GroundCF")
	local art = site:FindFirstChild("PlaceholderArt")
	check(art and art:IsA("Model") and #art:GetChildren() > 0, site.Name .. " has no placeholder art")
	for _, child in site:GetChildren() do
		check(child == art, site.Name .. " holds something besides PlaceholderArt")
	end
	for _, p in art:GetDescendants() do
		if p:IsA("BasePart") then
			check(not p.CanCollide and not p.CanTouch and not p.CanQuery, p.Name .. " is solid placeholder art")
			local l = ground:ToObjectSpace(frame:ToObjectSpace(p.CFrame))
			for _, sx in { -0.5, 0.5 } do
				for _, sy in { -0.5, 0.5 } do
					for _, sz in { -0.5, 0.5 } do
						local c = (l * CF.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz)).Position
						local over = math.max(math.abs(c.X) - size.X / 2, math.abs(c.Z) - size.Z / 2, c.Y - size.Y, -c.Y)
						if over > worstBy then worstBy, worst = over, site.Name .. "/" .. p.Name end
					end
				end
			end
		end
	end
end
check(worstBy <= 0.75, fmt("placeholder %s overflows its asset bounds by %.2f", worst, worstBy))

-- Containment is a proxy in Boundary, never art.
local proxies = 0
for _, p in region.Boundary:GetDescendants() do
	if p:IsA("BasePart") then
		proxies += 1
		check(p.CanCollide and p.Transparency == 1 and p:GetAttribute("CollisionProxy"), p.Name .. " in Boundary is not an invisible proxy")
	end
end
check(proxies > 60, "too few collision proxies")
for _, p in region.Landmarks:GetDescendants() do
	if p:IsA("BasePart") then
		check(not p.CanCollide and not p.CanQuery, p.Name .. " under Landmarks collides or answers rays")
	end
end
local lights = 0
for _, l in region:GetDescendants() do
	if l:IsA("PointLight") then lights += 1 end
end
check(lights <= 8, "light budget exceeded: " .. lights)

-- ------------------------------------------------------------- the ground
-- The meadow floor is MapBuilder's y 0.30 and nothing raises it: no solid in
-- the field, no broad surface over it, floor detail at most 0.06 proud.
local fieldHits, floorHits, laneHits, throat, outside = {}, {}, {}, {}, {}
for _, p in region:GetDescendants() do
	if not p:IsA("BasePart") then continue end
	local at, ex, ey, ez = localBox(p)
	local top = at.Y + ey
	local inField = math.abs(at.X) - ex < layout.field.X and math.abs(at.Z) - ez < layout.field.Z
	if p.CanCollide and inField and top > GROUND_Y + 0.05 then
		-- only the rear-left boulder cluster, behind its keep-out circle,
		-- reaches into the field rectangle
		local cluster = math.sqrt((at.X - 35) ^ 2 + (at.Z - 64) ^ 2) < 12
		if not cluster then table.insert(fieldHits, p.Name) end
	end
	if p:IsDescendantOf(region.Landmarks.FloorDetail) and top > GROUND_Y + 0.06 then
		table.insert(floorHits, p.Name .. fmt(" %.3f", top - GROUND_Y))
	end
	if not p:IsDescendantOf(sites) and not p:IsDescendantOf(region.Landmarks.FloorDetail)
		and math.abs(at.X) < 80 and math.abs(at.Z) < 64 and ex * ez * 4 > 30 and top > GROUND_Y + 0.06 and top < GROUND_Y + 1.5 then
		table.insert(floorHits, "ground skin: " .. p.Name)
	end
	if math.abs(at.X) - ex < LANE and math.abs(at.Z) - ez < 100 and top > GROUND_Y + 0.06 then
		table.insert(laneHits, p.Name)
	end
	if p.CanCollide and math.abs(at.X) - ex < 24 and math.abs(at.Z) + ez > 84 and top > GROUND_Y + 0.05 then
		table.insert(throat, p.Name)
	end
	local exempt = p:IsDescendantOf(region.Landmarks.WallSnow) or p:IsDescendantOf(region.Landmarks.Flanks)
		or p.Name == "WallTopProxy"
	local host = p.Parent
	while host and host.Parent ~= sites and host ~= region do host = host.Parent end
	if host and host.Parent == sites and host:GetAttribute("OutsideCell") then exempt = true end
	if not exempt and (math.abs(at.X) + ex > 140.5 or math.abs(at.Z) + ez > 100.5) then
		table.insert(outside, p.Name)
	end
end
check(#fieldHits == 0, "solid geometry in the creature field: " .. table.concat(fieldHits, ", "))
check(#floorHits == 0, "floor detail stands proud of the meadow: " .. table.concat(floorHits, ", "))
check(#laneHits == 0, "anything standing in the 24-stud route: " .. table.concat(laneHits, ", "))
check(#throat == 0, "geometry blocks a gate throat: " .. table.concat(throat, ", "))
check(#outside == 0, "geometry crosses the cell wall: " .. table.concat(outside, ", "))
-- the catching-field test the live harness runs: nothing solid within the
-- spawn radius (the smaller field half-extent) of the centre
local spawnRadius = math.min(layout.field.X, layout.field.Z)
local inCircle = {}
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and p.Size.X < spawnRadius and p.Size.Z < spawnRadius then
		local at, ex, _, ez = localBox(p)
		local nx0 = math.clamp(0, at.X - ex, at.X + ex)
		local nz0 = math.clamp(0, at.Z - ez, at.Z + ez)
		if math.sqrt(nx0 * nx0 + nz0 * nz0) < spawnRadius then table.insert(inCircle, p.Name) end
	end
end
check(#inCircle == 0, "solid inside the spawn circle: " .. table.concat(inCircle, ", "))

-- --------------------------------------------------------------- creatures
local solids = {}
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		local at, ex, _, ez = localBox(p)
		table.insert(solids, { at.X, at.Z, ex, ez })
	end
end
local keepOut = {}
for _, zone in layout.keepOut do
	local at = frame:VectorToObjectSpace(zone.at)
	table.insert(keepOut, { at.X, at.Z, zone.radius or 0, zone.lane })
end
local seed, accepted, inside = 4242, 0, 0
local function rnd()
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end
for _ = 1, 6000 do
	local x = (rnd() * 2 - 1) * layout.field.X
	local z = (rnd() * 2 - 1) * layout.field.Z
	local rejected = false
	for _, k in keepOut do
		if k[4] then
			if math.abs(x - k[1]) < k[4] and math.abs(z - k[2]) < k[4] then rejected = true end
		elseif k[3] > 0 and math.sqrt((x - k[1]) ^ 2 + (z - k[2]) ^ 2) < k[3] then
			rejected = true
		end
	end
	if not rejected then
		accepted += 1
		for _, s in solids do
			if math.abs(x - s[1]) < s[3] + 1 and math.abs(z - s[2]) < s[4] + 1 then inside += 1 break end
		end
	end
end
check(accepted > 4000, fmt("only %d of 6000 homes survive the keep-outs", accepted))
check(inside == 0, fmt("%d creature homes within a stud of solid geometry", inside))

-- ------------------------------------------------------------ walking routes
-- A 2.5-D flood fill over every collision surface in the region plus the
-- region floor: a walker steps up at most 0.75, drops any height, and needs
-- 4.5 studs of headroom. Tilted parts (cheeks, bridge planks) are intersected
-- with the vertical line exactly, not by their bounding boxes.
local STEP, CLEAR, G = 0.75, 4.5, 0.5
local colliders = {}
for _, p in region:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		local at, ex, _, ez = localBox(p)
		-- faces that touch count as continuous: a grid point on the seam between
		-- two treads must not read as a hole
		table.insert(colliders, { cf = frame:ToObjectSpace(p.CFrame), h = p.Size / 2 + V.new(0.02, 0.02, 0.02),
			x0 = at.X - ex, x1 = at.X + ex, z0 = at.Z - ez, z1 = at.Z + ez })
	end
end
local function interval(c, x, z)
	local inv = c.cf:Inverse()
	local p0 = inv * V.new(x, 0, z)
	local dir = inv:VectorToWorldSpace(V.new(0, 1, 0))
	local lo, hi = -math.huge, math.huge
	for _, axis in { "X", "Y", "Z" } do
		local o, d, h = p0[axis], dir[axis], c.h[axis]
		if math.abs(d) < 1e-9 then
			if math.abs(o) > h then return nil end
		else
			local t1, t2 = (-h - o) / d, (h - o) / d
			if t1 > t2 then t1, t2 = t2, t1 end
			lo, hi = math.max(lo, t1), math.min(hi, t2)
		end
	end
	if lo > hi then return nil end
	return lo, hi
end
local nx, nz = math.floor(277 / G), math.floor(197 / G)
local cellSolids = {}
for _, c in colliders do
	for i = math.max(0, math.floor((c.x0 + 138.5) / G)), math.min(nx, math.ceil((c.x1 + 138.5) / G)) do
		for j = math.max(0, math.floor((c.z0 + 98.5) / G)), math.min(nz, math.ceil((c.z1 + 98.5) / G)) do
			local lo, hi = interval(c, -138.5 + i * G, -98.5 + j * G)
			if lo then
				local key = i * 10000 + j
				cellSolids[key] = cellSolids[key] or {}
				table.insert(cellSolids[key], { lo, hi })
			end
		end
	end
end
local levels = {}
local function levelsAt(i, j)
	local key = i * 10000 + j
	if levels[key] then return levels[key] end
	local spans = cellSolids[key] or {}
	local tops = { GROUND_Y }
	for _, s in spans do table.insert(tops, s[2]) end
	local out = {}
	for _, t in tops do
		local free = true
		for _, s in spans do
			if s[1] < t + CLEAR - 0.01 and s[2] > t + 0.01 then free = false break end
		end
		if free then table.insert(out, t) end
	end
	levels[key] = out
	return out
end
local seen, queue = {}, {}
local function push(i, j, y)
	local key = tostring(i * 10000 + j) .. ":" .. tostring(math.floor(y * 100 + 0.5))
	if seen[key] then return end
	seen[key] = true
	table.insert(queue, { i, j, y })
end
local function cellOf(x, z) return math.floor((x + 138.5) / G + 0.5), math.floor((z + 98.5) / G + 0.5) end
local si, sj = cellOf(0, -96)
push(si, sj, GROUND_Y)
local head = 1
local reach = {}
while head <= #queue do
	local q = queue[head]
	head += 1
	local i, j, y = q[1], q[2], q[3]
	local key = i * 10000 + j
	reach[key] = reach[key] or {}
	table.insert(reach[key], y)
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local a, b = i + d[1], j + d[2]
		if a >= 0 and a <= nx and b >= 0 and b <= nz then
			for _, t in levelsAt(a, b) do
				if t - y <= STEP then push(a, b, t) end
			end
		end
	end
end
local function reached(label, x, z, y)
	local i, j = cellOf(x, z)
	local ok = false
	for _, got in reach[i * 10000 + j] or {} do
		if math.abs(got - y) < 0.3 then ok = true end
	end
	check(ok, fmt("%s unreachable on foot at (%.1f, %.1f)", label, x, z))
end
reached("north gate apron", 0, 95, GROUND_Y)
reached("terrace deck", 104, 40, TERRACE_Y)
reached("lodge porch", 117.5, 50, TERRACE_Y + 1.0)
reached("south shelf top", -130, 16, SHELF_Y)
reached("bridge mid-span", -115.75, 39, SHELF_Y - 1.2)
reached("north landing A", -118, 58, SHELF_Y)
reached("signpost shelf C", -92, 46, SHELF_Y)
local function risers(name, count)
	local tops = {}
	for _, p in region.Walkways:GetChildren() do
		if p.Name == name then table.insert(tops, (p.CFrame.Position.Y + p.Size.Y / 2) - centre.Y) end
	end
	table.sort(tops)
	local worstRise, previous = 0, GROUND_Y
	for _, t in tops do
		worstRise = math.max(worstRise, t - previous)
		previous = t
	end
	check(#tops == count, name .. " tread count " .. #tops)
	check(worstRise <= 0.7, name .. " riser " .. worstRise)
	return worstRise
end
local terraceRise = risers("TerraceStep", 8)
local shelfRise = risers("ShelfStep", 13)

-- Grounded sites stand on the region floor, as the live SelfTest checks with a
-- 3-stud ray from 1.5 above: a ray ignores a part it starts inside, so the
-- site's own proxy never counts, anything else under it would.
local floating = {}
for _, site in siteList do
	if site:GetAttribute("PlacementRole") == "Grounded" and not site:GetAttribute("OutsideCell") then
		local at = site:GetAttribute("GroundCF").Position
		local origin = at.Y + 1.5
		local best = GROUND_Y
		for _, c in colliders do
			if at.X >= c.x0 and at.X <= c.x1 and at.Z >= c.z0 and at.Z <= c.z1 then
				local lo, hi = interval(c, at.X, at.Z)
				if lo and not (lo < origin and hi > origin) and hi <= origin then best = math.max(best, hi) end
			end
		end
		if math.abs(best - at.Y) > 0.05 then table.insert(floating, site.Name) end
	end
end
check(#floating == 0, "grounded sites not on the floor: " .. table.concat(floating, ", "))

-- ------------------------------------------------------------- sockets
local function siteCF(name)
	for _, s in siteList do if s.Name == name then return s:GetAttribute("GroundCF") end end
	error("no site " .. name)
end
local bridge = siteCF("Bridge01")
local north = (bridge * Spec.sockets.FP_Alpine_Bridge.NorthDeck).Position
local south = (bridge * Spec.sockets.FP_Alpine_Bridge.SouthDeck).Position
check(math.abs(north.Y - SHELF_Y) < 0.01 and math.abs(south.Y - SHELF_Y) < 0.01, "bridge ends not at shelf level")
check(north.X < -106 and north.X > -126 and north.Z > 54 and north.Z < 62, "bridge north end misses landing A")
check(south.X < -107 and south.X > -136 and south.Z > 9 and south.Z < 24, "bridge south end misses shelf B")
local lodge = siteCF("Lodge01")
local door = (lodge * Spec.sockets.FP_Alpine_Lodge.DoorBase).Position
check(math.abs(door.Y - (TERRACE_Y + 1.0)) < 0.01, "lodge door not at porch level")
local stepAt = (lodge * Spec.sockets.FP_Alpine_Lodge.PorchStep).Position
check(math.abs(stepAt.Y - TERRACE_Y) < 0.01 and stepAt.Z > 28.5, "porch step not on the terrace")

-- ------------------------------------------------------------ the asset swap
local originalCount = #sites:GetDescendants()
local native = r.deserializeModel(fs.readFile("src/server/Map/CinderQuarryTemplates.rbxm"))[1]
local fixture = native:FindFirstChildWhichIsA("MeshPart", true)
fixture.MeshSize = fixture.InitialSize
local xml = r.serializeModel({ fixture }, true)
fixture.MeshId = assert(xml:match('<Content name="MeshContent">%s*<uri>(.-)</uri>'))
local texture = xml:match('<Content name="TextureContent">%s*<uri>(.-)</uri>')
fixture.TextureID = if texture and texture ~= "" then texture else "rbxassetid://1"
local library = r.Instance.new("Model")
library.Name, library.Parent = Spec.library, map
local last
for name, size in Spec.alpine do
	local mesh = fixture:Clone()
	mesh.Size, mesh.MeshSize = size, size * (256 / 9)
	mesh.Name, mesh.Parent = name, library
	last = mesh
end
local function refused(message)
	local copy = region:Clone()
	check(not props.apply(copy, frame) and not copy:FindFirstChild("BlenderProps")
		and #copy.Landmarks.PropSites:GetDescendants() == originalCount, message)
	copy:Destroy()
end
last.Parent = nil
refused("a partial kit modified the blockout")
last.Parent = library
local size0, native0 = last.Size, last.MeshSize
last.Size = size0 * 100
refused("100x native template Size accepted")
last.Size = size0
last.MeshSize = V.new(native0.X * 2, native0.Y, native0.Z)
refused("distorted native MeshSize accepted")
last.MeshSize = native0
local fir = nil
for _, s in siteList do if s:GetAttribute("AssetName") == "FP_Alpine_Fir_Tall" then fir = s break end end
local firSize = fir:GetAttribute("AssetSize")
fir:SetAttribute("AssetSize", V.new(firSize.X * 1.2, firSize.Y, firSize.Z))
refused("a non-uniformly scaled site accepted")
fir:SetAttribute("AssetSize", firSize)
local art = fir.PlaceholderArt:FindFirstChildWhichIsA("BasePart", true)
art.CanCollide = true
refused("solid placeholder accepted")
art.CanCollide = false
local protected = {}
for _, host in { region.Boundary, region.Walkways, region.Landmarks.Effects } do
	for _, p in host:GetDescendants() do
		if p:IsA("BasePart") then protected[p] = { p.Size, p.CFrame, p.CanCollide, p.Transparency } end
	end
end
local placements = #siteList
check(props.apply(region, frame), "the complete kit was refused")
check(#region.BlenderProps:GetChildren() == placements, "wrong placement count")
for _, site in siteList do
	local mesh = region.BlenderProps:FindFirstChild(site.Name)
	local bottom = mesh.CFrame * CF.new(0, -mesh.Size.Y / 2, 0)
	local expected = frame * site:GetAttribute("GroundCF")
	check((bottom.Position - expected.Position).Magnitude < 0.001 and bottom.LookVector:Dot(expected.LookVector) > 0.9999, site.Name .. " frame wrong")
	check((mesh.Size - site:GetAttribute("AssetSize")).Magnitude < 0.001 and mesh.MeshSize == library[site:GetAttribute("AssetName")].MeshSize, site.Name .. " size or native data wrong")
	check(mesh.Anchored and not mesh.CanCollide and not mesh.CanTouch and not mesh.CanQuery, site.Name .. " flags wrong")
	check(not site:FindFirstChild("PlaceholderArt") and site:GetAttribute("AssetPlaced"), "temporary art remains at " .. site.Name)
end
for p, v in protected do
	check(p:IsDescendantOf(region) and p.Size == v[1] and p.CFrame == v[2] and p.CanCollide == v[3] and p.Transparency == v[4], "permanent geometry changed")
end
check(not props.apply(region, frame), "second apply was not a no-op")

-- ------------------------------------------------------------ import staging
local source, storage = r.Instance.new("Folder"), r.Instance.new("Folder")
local bundle = r.Instance.new("Model")
bundle.Name = Spec.bundle
local n = 0
for name in Spec.alpine do
	n += 1
	local mesh = fixture:Clone()
	mesh.Name, mesh.Anchored, mesh.Parent = name, false, bundle
	mesh.MeshId = "rbxassetid://" .. tostring(1000 + n)
end
local extra = fixture:Clone()
extra.Name, extra.MeshId, extra.Parent = "FP_Alpine_Icicles", "rbxassetid://999", bundle
library:Destroy()
bundle.Parent = source
check(staging.move(source, storage) == 1 and bundle:IsDescendantOf(storage), "complete first Alpine bundle not quarantined")
for _, p in bundle:GetDescendants() do
	if p:IsA("BasePart") then check(p.Anchored, "staged mesh left unanchored") end
end
local partial = bundle:Clone()
partial.Parent = source
partial:FindFirstChild("FP_Alpine_Lodge"):Destroy()
check(staging.move(source, storage) == 0 and partial.Parent == source, "partial Alpine bundle was moved")

local report = {
	checks = checks,
	sites = placements,
	siteBreakdown = byAsset,
	collisionProxies = proxies,
	pointLights = lights,
	field = { layout.field.X, layout.field.Z },
	spawnRadius = spawnRadius,
	fieldSamplesAccepted = accepted,
	homesNearSolids = inside,
	terraceRiser = terraceRise,
	shelfRiser = shelfRise,
	walkable = { "north gate apron", "terrace deck", "lodge porch", "south shelf top", "bridge mid-span", "north landing A", "signpost shelf C" },
	placeholderWorstOverflow = worstBy,
	nativeAssets = "Swap exercised with fixture MeshParts (cloned from CinderQuarryTemplates). Astra's kit is delivered as FBX (manifest v3) and its bounds and sockets are checked above, but it is not yet uploaded or captured as FrostbiteAlpineTemplates",
}
if not fs.isDir("build") then fs.writeDir("build") end
-- The authoritative site list for Astra: region-local bottom-centre, yaw, scale.
local rows = { "site,asset,scale,x,y,z,yaw_deg,W,H,D,role,support,outside_cell" }
table.sort(siteList, function(a, b) return a.Name < b.Name end)
for _, site in siteList do
	local g = site:GetAttribute("GroundCF")
	local lv = g.LookVector
	local size = site:GetAttribute("AssetSize")
	table.insert(rows, table.concat({ site.Name, site:GetAttribute("AssetName"),
		fmt("%.3f", site:GetAttribute("AssetScale")), fmt("%.2f", g.Position.X), fmt("%.2f", g.Position.Y), fmt("%.2f", g.Position.Z),
		fmt("%.1f", math.deg(math.atan2(-lv.X, -lv.Z))), fmt("%.2f", size.X), fmt("%.2f", size.Y), fmt("%.2f", size.Z),
		site:GetAttribute("PlacementRole"), site:GetAttribute("SupportPath"), tostring(site:GetAttribute("OutsideCell") == true) }, ","))
end
fs.writeFile("build/frostbite-alpine-sites.csv", table.concat(rows, string.char(10)) .. string.char(10))
fs.writeFile("build/frostbite-alpine-validation.json", serde.encode("json", report, true))
print(serde.encode("json", report))
