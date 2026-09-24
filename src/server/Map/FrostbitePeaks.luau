--!strict
-- Frostbite Peaks, built to the approved "Alpine Outpost V2" concept
-- (docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png).
-- The measured layout is ALPINE-OUTPOST-V2-LAYOUT.md beside it and the mesh
-- contract Astra models to is ALPINE-OUTPOST-V2-ASSET-REQUEST.md.
--
-- A broad snowy meadow down the middle with a straight packed-snow route gate
-- to gate; a timber lodge on a low stone terrace at the rear-left with a compact
-- camp in front of it; a rope bridge between two layered slate shelves over a
-- frozen creek on the right; broad snow-capped slate formations in the rear
-- corners and down both side bands, composed with mixed firs, nested boulders,
-- frosted shrubs, golden grass and drifts; snowy flanks outside both walls.
--
-- Local frame, as RegionScenery hands it over: local +X is world west, which is
-- the LEFT of the concept and the lodge's side; local -Z is the Cinder threshold
-- (south, the entry); local +Z the Thunderworks gate (north, the exit). The cell
-- is MapBuilder's 280 x 200; walls, both gate piers, barriers and banners belong
-- to MapBuilder.buildChainWalls and are not touched here.
--
-- Where the numbers come from: the concept's four gate-pier bases fit a ground
-- homography (the gates are engine geometry, 44 apart and 200 deep), and the
-- concept draws the rest of the cell about ten percent narrower than the gates
-- imply, so x is read through a piecewise map anchored on the gate piers, both
-- divider piers and the wall face. Heights come from the gate piers' panels.
--
-- Output splits the way the quarry's does. Boundary holds nothing but invisible
-- collision proxies. Walkways holds the functional walking surfaces: the stone
-- terrace and both stairs are permanent visible geometry, the shelf tops, porch
-- and bridge deck are invisible proxies under art. Landmarks/PropSites holds one
-- metadata site per intended mesh with its stand-in under PlaceholderArt.
-- Landmarks/Effects holds the window and lantern glow, lights, chimney smoke and
-- all the ice; Landmarks/FloorDetail the flush field dressing; Landmarks/WallSnow
-- the decorative caps on this cell's stretch of wall; Landmarks/Flanks the snow
-- skin outside it. None of the art collides, touches or answers raycasts.
--
-- Ice and Glacier are slippery materials in Roblox, so every ice surface here is
-- CanCollide false decoration over ordinary ground. Nothing raises the meadow:
-- the floor is MapBuilder's own Ground at y = 0.30 and field detail stands at
-- most 0.05 proud of it, so the Ice Wave telegraph drawn at the creature's feet
-- is never buried.
local Peaks = {}
local Spec = require(script.Parent.FrostbiteAlpineAssetSpec)
local AlpineProps = require(script.Parent.FrostbiteAlpineProps)
local PowderProps = require(script.Parent.FrostbitePowderProps)
local V = Vector3.new
local rgb = Color3.fromRGB
local rad = math.rad

-- ---------------------------------------------------------------- layout
local HALF_W, HALF_D = 140, 100 -- the cell MapBuilder walls
local GROUND_Y = 0.30 -- the region floor's top face, which nothing raises
local LANE_HALF = 12 -- the 24-wide clear route the handoff fixes
local TERRACE_Y = GROUND_Y + 5.5 -- lodge terrace walk level: 9 risers of 0.61
local SHELF_Y = GROUND_Y + 8.5 -- bridge shelves walk level: 14 risers of 0.61
-- MapBuilder's lateral walls run the whole 1200-stud chain from z = -215 with a
-- pier every 1200 / 27 studs; the snow caps below land on this cell's piers.
local CHAIN_Z0, PIER_STEP = -215, 1200 / 27

-- Terrace: x 84.5 (east face) .. 138.4 (the west wall), z 28.5 (front) .. 77.
local TERRACE = { x0 = 84.5, x1 = 138.4, z0 = 28.5, z1 = 77 }
local T_STAIR = { x0 = 110.5, x1 = 120.5, risers = 9, tread = 1.0 }
-- The lodge's bottom-centre on the deck, door facing south into the meadow.
local LODGE_AT = CFrame.new(113.5, TERRACE_Y, 58.5)
-- Bridge shelves. C (signpost) and A (the bridge's north landing) are one mesh.
local SHELF_N_AT = CFrame.new(-104.75, GROUND_Y, 50.25)
local SHELF_S_AT = CFrame.new(-121.5, GROUND_Y, 16.5)
local SHELF_C = { x0 = -106, x1 = -83.5, z0 = 38.5, z1 = 62 }
local SHELF_A = { x0 = -126, x1 = -106, z0 = 54, z1 = 62 }
local SHELF_B = { x0 = -136, x1 = -107, z0 = 9, z1 = 24 }
local B_STAIR = { x0 = -127.5, x1 = -115.5, risers = 14, tread = 1.05 }
local GORGE_AT = CFrame.new(-132.3, GROUND_Y, 49)
-- The bridge axis, south landing to north landing, measured off the concept.
local BRIDGE_S, BRIDGE_N = V(-117.5, 0, 22), V(-114, 0, 56)
local BRIDGE_MID = (BRIDGE_S + BRIDGE_N) / 2
local BRIDGE_AT = CFrame.new(BRIDGE_MID.X, SHELF_Y - 1.5, BRIDGE_MID.Z)
	* CFrame.Angles(0, math.atan2(BRIDGE_N.X - BRIDGE_S.X, BRIDGE_N.Z - BRIDGE_S.Z), 0)

-- ---------------------------------------------------------------- palette
-- Sampled off the concept and pulled down a little for Roblox's outdoor light.
local SNOW = rgb(236, 240, 246)
local SNOW_MID = rgb(218, 226, 238)
local SNOW_TRACK = rgb(200, 212, 230)
local SNOW_WIND = rgb(226, 233, 243)
local SLATE_LIGHT = rgb(96, 108, 128)
local SLATE = rgb(72, 84, 104)
local SLATE_DARK = rgb(54, 62, 80)
local SEAM = rgb(34, 40, 54)
local STONE = rgb(92, 100, 114)
local STONE_LIGHT = rgb(126, 128, 134)
local STONE_DARK = rgb(66, 72, 84)
local TIMBER = rgb(122, 72, 44)
local TIMBER_DARK = rgb(78, 46, 30)
local TIMBER_LIGHT = rgb(160, 104, 62)
local TEAL = rgb(36, 112, 112)
local TEAL_DARK = rgb(24, 78, 82)
local IRON = rgb(58, 56, 60)
local GOLD = rgb(214, 170, 76)
local FIR = rgb(30, 74, 62)
local FIR_DEEP = rgb(18, 50, 44)
local BARK = rgb(84, 58, 42)
local GRASS_GOLD = rgb(210, 164, 84)
local GRASS_DARK = rgb(168, 124, 60)
local SHRUB = rgb(176, 196, 190)
local CANVAS = rgb(240, 128, 60)
local CANVAS_SHADE = rgb(196, 98, 44)
local ROPE = rgb(176, 146, 100)
local ICE = rgb(150, 198, 226)
local ICE_DEEP = rgb(112, 164, 204)
local ICE_PALE = rgb(186, 214, 238)
local ICE_FIELD = rgb(184, 210, 236)
local AMBER = rgb(255, 196, 110)
local LANTERN_GLASS = rgb(255, 224, 152)
local SMOKE = rgb(232, 236, 242)

local SNOW_MAT = Enum.Material.Snow
local SLATE_MAT = Enum.Material.Slate
local ROCK_MAT = Enum.Material.Rock
local COBBLE = Enum.Material.Cobblestone
local WOOD = Enum.Material.Wood
local PLANK = Enum.Material.WoodPlanks
local METAL = Enum.Material.Metal
local GLACIER = Enum.Material.Glacier
local ICE_MAT = Enum.Material.Ice
local NEON = Enum.Material.Neon
local GRASS_MAT = Enum.Material.Grass
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic

-- ---------------------------------------------------------------- placements
-- Every table below is generated from the measured layout
-- (docs/art/regions/2026-09-22-frostbite-peaks/src, see the layout doc) and
-- then fitted to the adopted kit: firs carry their measured height and take a
-- uniform scale of height / mesh height.

-- { asset, x, z, yaw degrees, scale, treeHeight? }: a tree height puts a medium
-- fir on the cliff's TopMount, as the concept does on three of the rear rocks.
local CLIFFS = {
	-- rear left: the tall corner rock behind the lodge, the wide block behind the
	-- annex, the block at the terrace's back corner, and the run to the gate
	{ "FP_Alpine_Cliff_Tall", 118, 87.3, 4, 1 }, { "FP_Alpine_Cliff_Wide", 104, 88, -6, 1 },
	{ "FP_Alpine_Cliff_Block", 92, 81, 12, 1 }, { "FP_Alpine_Cliff_Wide", 72, 88, 3, 1 },
	{ "FP_Alpine_Cliff_Block", 49, 91, -8, 1 }, { "FP_Alpine_Cliff_Block", 43, 80, 20, 1 },
	-- rear right: the massif either side of the creek's spring
	{ "FP_Alpine_Cliff_Block", -66, 91, -5, 1, 16.2 }, { "FP_Alpine_Cliff_Wide", -86, 86, 4, 1, 18 },
	{ "FP_Alpine_Cliff_Tall", -105, 87.3, -3, 1 }, { "FP_Alpine_Cliff_Tall", -127.3, 85, -90, 1, 16.2 },
	-- the side bands
	{ "FP_Alpine_Cliff_Wide", 112, -14, -5, 1 }, { "FP_Alpine_Cliff_Block", 116, -41, 10, 1 },
	{ "FP_Alpine_Cliff_Block", 98, -60, -15, 1.2 }, { "FP_Alpine_Cliff_Block", -114.5, -34, 8, 1.3 },
	{ "FP_Alpine_Cliff_Block", -131, -40, -90, 1 },
}
-- { x, z, kind, yaw degrees, scale }: L Snow_Rock, S Snow_Rock_Small
local ROCKS = {
	{ 36.8, 68.9, "L", 30, 1 }, { 29, 64.4, "L", -20, 0.8 }, { 40.5, 60.6, "S", 10, 1 }, { -67.8, 69.6, "L", 15, 1 },
	{ -31.6, 77.7, "S", -30, 1.4 }, { -102, 82, "S", 0, 1.3 }, { 102.3, -72.5, "L", 20, 1 }, { 92, -82, "L", 30, 1 },
	{ 121.4, -54.2, "S", 0, 1.4 }, { 122, -86, "L", -10, 0.9 }, { 116, -46.5, "S", 40, 1.2 }, { -99.4, -55, "L", 10, 1.4 },
	{ -106.7, -41.8, "L", -25, 1 }, { -118.3, -81.5, "L", 5, 1.2 }, { -117.7, -73.1, "S", 15, 1.5 }, { -89.1, -1.1, "L", 25, 1.3 },
	{ -95.4, -2.6, "S", -15, 1.2 }, { -91.5, 17.7, "L", 0, 1 }, { -83.8, 1, "S", 30, 1 },
}
-- { x, z, kind, height, baseY }: T tall / M medium / S sapling fir.
local FIRS = {
	{ 113, -34.6, "T", 31, 0 }, { 133.7, -18.4, "M", 23.75, 0 }, { 123.6, -30.8, "M", 16.72, 0 }, { 91.8, -49, "M", 21.28, 0 },
	{ 127.4, -75.9, "T", 27.9, 0 }, { 114.6, -63.8, "M", 16.53, 0 }, { 133.7, -82.8, "M", 13.3, 0 }, { 125.3, -85, "M", 13.68, 0 },
	{ 108.2, -68.1, "S", 10, 0 }, { 124.6, 2.5, "M", 20.33, 0 }, { 135.2, 3, "M", 16.34, 0 }, { 115.2, 2, "S", 12, 0 },
	{ 100.8, -3.5, "M", 16.15, 0 }, { 71, -84.5, "S", 12.5, 0 }, { 44.2, -84, "M", 13.68, 0 }, { -48.9, -84, "M", 19, 0 },
	{ -56.4, -81.5, "M", 14.63, 0 }, { -84.2, -86, "S", 6, 0 }, { 59.5, 73.4, "M", 20.14, 0 }, { 39.6, 88, "T", 23.56, 0 },
	{ 58.3, 95, "S", 11.5, 0 }, { 47.3, 96, "S", 8, 0 }, { 24.5, 70.2, "M", 19, 0 }, { 88, 80, "M", 20.9, 0 },
	{ 135, 73.5, "M", 11.4, 5.5 }, { -56.8, 77.7, "T", 24.8, 0 }, { -52.2, 93, "M", 16.15, 0 }, { -93.7, 76, "T", 24.8, 0 },
	{ -130.8, 56.8, "M", 13.87, 0 }, { -132.1, 41, "S", 11, 0 }, { -86.4, -46.7, "M", 13.87, 0 }, { -95.8, -39.5, "M", 13.87, 0 },
	{ -100.6, -43.3, "S", 10.5, 0 }, { -114.9, -64.7, "T", 26.35, 0 }, { -105.6, -77.9, "M", 22.8, 0 }, { -129.3, -63, "M", 17.67, 0 },
	{ -131.9, -80.6, "M", 16.34, 0 }, { -126.5, -28.7, "M", 22.8, 0 }, { -134.1, -17, "M", 14.82, 0 }, { -99, -17.6, "M", 16.72, 0 },
	{ -104.7, -19.5, "M", 14.06, 0 }, { -84.6, -85.6, "S", 9.2, 0 },
}
-- Outside both side walls, on the snowed-over flank strip: two staggered rows
-- of big firs a side, packed the way the concept frames the cell.
local FLANK_FIRS: { { any } } = {}
for _, side in { -1, 1 } do
	for k = 0, 11 do
		local shift = if side > 0 then 4 else 0
		local medium = k % 3 == 1
		table.insert(FLANK_FIRS, { side * (147 + (k * 7) % 5), -92 + k * 16.4 + shift, if medium then "M" else "T", if medium then 19 + (k * 3) % 5 else 26 + (k * 5) % 7 })
	end
	for k = 0, 10 do
		local shift = if side > 0 then -3 else 2
		local medium = k % 4 == 2
		table.insert(FLANK_FIRS, { side * (160 + (k * 11) % 12), -84 + k * 16.4 + shift, if medium then "M" else "T", if medium then 20 + k % 4 else 27 + (k * 3) % 6 })
	end
end
-- { x, z, kind }: G golden grass, F frosted shrub. Walk-through.
local PLANTS = {
	{ 130.8, -37.5, "G" }, { 102.7, -32.3, "G" }, { 116.9, -74.5, "G" }, { 83.3, -77.3, "G" }, { 93.2, -4.4, "F" }, { 86.8, -66.6, "F" },
	{ -96.3, -16.4, "G" }, { -120.6, -15.5, "G" }, { -82.2, -46.7, "G" }, { -93.6, -66.1, "G" }, { -123.5, -73.9, "G" }, { -106.6, -81.2, "G" },
	{ -97.6, -64.7, "F" }, { -87.9, -49, "F" }, { -90.8, 24, "G" }, { -81.6, 42.5, "G" }, { -82.8, 29, "F" }, { 68, 80.9, "G" },
	{ 57.5, 68, "G" }, { 46.1, 66.4, "G" }, { 67.7, 69.6, "F" }, { 25, 85.8, "G" }, { -33.1, 90, "G" }, { -36.1, 69.6, "G" },
	{ -38.5, 77.7, "F" }, { -81.4, 74.4, "G" }, { 81.1, 22, "G" }, { 101.1, 21, "G" }, { 97.5, 18, "G" }, { 40, -86, "G" },
	{ 60, -88, "G" }, { -40, -87, "G" }, { -66, -88, "G" }, { 78, -88, "F" }, { -74, -84, "F" },
}
-- { x, z, yaw degrees, scale }: soft drifts at wall bases and cluster feet.
local DRIFTS = {
	{ 133, -60, 90, 1 }, { 133, -40, 90, 0.9 }, { 133.5, -95, 0, 1 }, { 104, -92, 5, 1 }, { -133, -55, 90, 1 }, { -133, 0, 90, 0.9 },
	{ -133.5, -95, 0, 1 }, { -104, -92, -5, 1 }, { 78, -94, 0, 0.9 }, { -78, -94, 0, 0.9 }, { 106, -24, 10, 0.9 }, { -110, -48, -15, 0.9 },
	{ 60, 62, 20, 0.8 }, { -60, 64, -20, 0.8 }, { -88, 30, 0, 0.8 }, { 88, 14, 0, 0.8 }, { 97, 25.5, 0, 0.8 }, { 131, 25.5, 0, 0.8 },
	{ 133, -75, 90, 0.9 }, { 133, -20, 90, 1 }, { 133, 8, 90, 0.8 }, { -133, -80, 90, 0.9 }, { -133, -32, 90, 1 },
	{ -133, -12, 90, 0.8 }, { 32, 93, 0, 0.9 }, { -32, 93, 0, 0.9 }, { 58, -94, 0, 0.8 }, { -52, -94, 0, 0.8 },
}
-- { x, z, width, depth, yaw degrees }: muted blue ice patches in the meadow.
local FIELD_ICE = {
	{ 65, 12, 24, 11, 8 }, { -35, 46, 12, 8, -10 }, { -46, 24, 12, 9, 15 }, { -41, -15, 14, 7, 0 },
	{ 43, -5, 10, 6, 5 }, { -62, -37, 14, 7, -12 }, { 52, 34, 9, 6, 20 }, { -24, -48, 8, 5, 0 },
}
-- The creek as overlapping discs { x, z, diameter }: the spring pool between the
-- rear-right cliffs, down the gorge under the bridge, then along the south
-- shelf's west face to where it thins out into the meadow edge.
local CREEK = {
	{ -114.5, 71, 12 }, { -111.5, 66, 11 }, { -117, 64.5, 10 }, { -113.5, 60, 10 },
	{ -113.5, 51, 11.5 }, { -113, 47, 12 }, { -112.5, 43, 11.5 }, { -112, 39, 12 }, { -111, 35, 11.5 },
	{ -110, 31, 12 }, { -108.5, 27, 12 }, { -106, 23, 11 }, { -104, 19.5, 10.5 },
	{ -103, 16, 10 }, { -102.5, 12.5, 9.5 }, { -102, 9, 9 }, { -101.5, 5.5, 8 }, { -101, 2.5, 6 },
}
-- Footprint trails through the meadow, off the route: polylines { x, z }.
local TRAILS = {
	{ { 52, 44 }, { 44, 30 }, { 40, 16 } },
	{ { 38, -22 }, { 32, -36 }, { 28, -52 } },
	{ { -30, 26 }, { -38, 14 }, { -44, 2 } },
	{ { -56, -20 }, { -50, -32 }, { -44, -48 } },
	{ { 62, -40 }, { 54, -54 } },
	{ { -44, 50 }, { -54, 40 } },
}
-- Lane stakes, the concept's seven a side just outside the route.
local STAKE_X, STAKE_Z = 15.25, { -58.5, -39, -19.5, 0, 19.5, 39, 58.5 }

function Peaks.build(parent: Model, frame: CFrame, _radius: number, makePart: (any) -> Part)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = parent
	local walkways = Instance.new("Model")
	walkways.Name = "Walkways"
	walkways.Parent = parent
	local decor = Instance.new("Model")
	decor.Name = "Landmarks"
	decor.Parent = parent
	local sites = Instance.new("Model")
	sites.Name = "PropSites"
	sites.Parent = decor
	sites:SetAttribute("AssetKit", "assets/frostbite-peaks/alpine-v2")
	sites:SetAttribute("AssetOrigin", "bottom-centre")
	sites:SetAttribute("AssetLibrary", Spec.library)
	local effects = Instance.new("Model")
	effects.Name = "Effects"
	effects.Parent = decor
	local floor = Instance.new("Model")
	floor.Name = "FloorDetail"
	floor.Parent = decor
	local wallSnow = Instance.new("Model")
	wallSnow.Name = "WallSnow"
	wallSnow.Parent = decor
	local flanks = Instance.new("Model")
	flanks.Name = "Flanks"
	flanks.Parent = decor

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		return makePart({ name = name, size = size, cf = frame * cf, color = color,
			material = material or SLATE_MAT, collide = solid == true,
			query = solid == true, parent = host or decor })
	end
	local function flat(p: Part): Part
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	local function glow(p: Part, brightness: number, range: number): Part
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Brightness = brightness
		light.Range = range
		light.Shadows = false
		light.Parent = p
		return p
	end
	-- An upright disc or cylinder: a Roblox cylinder runs along its own X, so a
	-- standing one is sized (height, diameter, diameter) and turned onto its end.
	local function disc(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local p = part(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, false, host)
		p.Shape = Enum.PartType.Cylinder
		return flat(p)
	end
	-- Walking containment, and only that: an invisible box in Boundary, so the art
	-- can be replaced wholesale without touching what keeps a player out of a rock.
	local function proxy(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, SLATE, SLATE_MAT, true, boundary)
		p.Transparency = 1
		p.CastShadow = false
		p:SetAttribute("CollisionProxy", true)
		return p
	end
	-- A walking surface. Visible ones are permanent stone; invisible ones sit
	-- under art that draws the surface for them.
	local function walk(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, visible: boolean): Part
		local p = part(name, size, cf, color, material, true, walkways)
		p:SetAttribute("WalkSurface", true)
		if not visible then
			p.Transparency = 1
			p.CastShadow = false
			p:SetAttribute("CollisionProxy", true)
		end
		return p
	end
	-- A turned box reaches further than its half width. Everything in the cell
	-- is held inside the wall faces here, whatever its yaw.
	local function insideCell(x: number, z: number, size: Vector3, yaw: number): (number, number)
		local c, sn = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
		local ex = (size.X * c + size.Z * sn) / 2
		local ez = (size.Z * c + size.X * sn) / 2
		return math.clamp(x, ex - HALF_W + 2, HALF_W - 2 - ex),
			math.clamp(z, ez - HALF_D + 2, HALF_D - 2 - ez)
	end

	-- ------------------------------------------------------------ asset sites
	-- One record per intended mesh. GroundCF is the asset's bottom-centre frame
	-- in this module's local coordinates; AssetSize is the spec bounds times the
	-- site's uniform AssetScale. `place` hands back a brush that draws into the
	-- site's own local space at the mesh's native size, scaling as it goes, so
	-- every stand-in is authored exactly the way the mesh is.
	type Brush = {
		block: (string, Vector3, CFrame, Color3, Enum.Material?) -> Part,
		post: (string, number, number, CFrame, Color3, Enum.Material?) -> Part,
		roll: (string, number, number, CFrame, Color3, Enum.Material?) -> Part,
		ball: (string, number, CFrame, Color3, Enum.Material?) -> Part,
		egg: (string, Vector3, CFrame, Color3, Enum.Material?) -> Part,
		site: Model,
	}
	local counts: { [string]: number } = {}
	local siteCount = 0
	local siteFrames: { [string]: CFrame } = {}
	local function place(prefix: string, asset: string, ground: CFrame, role: string, support: string, scale: number?, host: Instance?): Brush
		local base = Spec.alpine[asset]
		assert(base, "no fixed bounds for " .. asset)
		local s = scale or 1
		local n = (counts[prefix] or 0) + 1
		counts[prefix] = n
		siteCount += 1
		local site = Instance.new("Model")
		site.Name = prefix .. (if n < 10 then "0" .. n else tostring(n))
		site:SetAttribute("AssetName", asset)
		site:SetAttribute("AssetSize", base * s)
		site:SetAttribute("AssetScale", s)
		site:SetAttribute("AssetLibrary", Spec.library)
		site:SetAttribute("GroundCF", ground)
		site:SetAttribute("PivotMode", "BottomCenter")
		site:SetAttribute("SizeLock", "Uniform")
		site:SetAttribute("CollisionRole", "none")
		site:SetAttribute("PlacementRole", role)
		site:SetAttribute("SupportPath", support)
		if host == flanks then
			site:SetAttribute("OutsideCell", true)
		end
		site.Parent = sites
		siteFrames[site.Name] = ground
		local art = Instance.new("Model")
		art.Name = "PlaceholderArt"
		art.Parent = site
		local function at(cf: CFrame): CFrame
			return ground * CFrame.new(cf.Position * s) * cf.Rotation
		end
		local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
			return flat(part(name, size * s, at(cf), color, material, false, art))
		end
		local function post(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		local function roll(name: string, diameter: number, length: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, V(length, diameter, diameter), cf, color, material)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		local function ball(name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, V(diameter, diameter, diameter), cf, color, material)
			p.Shape = Enum.PartType.Ball
			return p
		end
		-- A squashed sphere filling the given box: primitives have no ellipsoid,
		-- a SpecialMesh sphere does, and it is what makes snow read as soft.
		local function egg(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, size, cf, color, material)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			return p
		end
		return { block = block, post = post, roll = roll, ball = ball, egg = egg, site = site }
	end
	local function socket(asset: string, name: string): CFrame
		local s = Spec.sockets[asset]
		local cf = s and s[name]
		assert(cf, "no socket " .. asset .. "." .. name)
		return cf
	end

	-- ------------------------------------------------------------ stand-in art
	-- Firs: slender and snow-laden, as the concept draws them. A short trunk, five
	-- tapering tiers of deep green, each under a snow pillow nearly as wide, so
	-- from above the tree reads mostly white with the green showing at the edges.
	local FIR_ASSET = { T = "FP_Alpine_Fir_Tall", M = "FP_Alpine_Fir_Medium", S = "FP_Alpine_Fir_Sapling" }
	local function firArt(b: Brush, size: Vector3, seed: number)
		local W, H = size.X, size.Y
		b.post("FirTrunk", W * 0.14, H * 0.18, CFrame.new(0, H * 0.09, 0), BARK, WOOD)
		local tiers = if H < 12 then 4 else 5
		for i = 0, tiers - 1 do
			local t = i / (tiers - 1)
			local d = W * (0.96 - 0.72 * t)
			local y0 = H * (0.1 + t * 0.66)
			local th = H * 0.19
			b.post("FirTier", d, th, CFrame.new(0, y0 + th / 2, 0), if (i + seed) % 2 == 0 then FIR else FIR_DEEP, GRASS_MAT)
			b.egg("FirSnow", V(d * 0.92, H * 0.1, d * 0.92), CFrame.new(W * 0.02 * (seed % 3 - 1), y0 + th, 0), SNOW, SNOW_MAT)
		end
		b.ball("FirTopSnow", W * 0.24, CFrame.new(0, H - W * 0.12, 0), SNOW, SNOW_MAT)
	end
	-- A snow pillow on a rectangular top: an inset slab, then a rounded disc on
	-- it, so the cap reads soft and thick with rock showing round the edge.
	local function pillow(b: Brush, name: string, w: number, d: number, y: number, thick: number, cf: CFrame)
		b.block(name, V(w * 0.94, thick * 0.6, d * 0.94), cf * CFrame.new(0, y + thick * 0.3 - 0.1, 0), SNOW_MID, SNOW_MAT)
		b.egg(name, V(w * 0.97, thick * 2.0, d * 0.97), cf * CFrame.new(0, y + thick * 0.3, 0), SNOW, SNOW_MAT)
	end
	-- Layered slate: broad dark blocks stepping back, each under a thick snow
	-- pillow, with deep horizontal fractures across the faces the meadow sees.
	local function cliffArt(b: Brush, size: Vector3, seed: number)
		local W, H, D = size.X, size.Y, size.Z
		local side = if seed % 2 == 0 then 1 else -1
		local tiers = {
			{ W * 0.94, 0, H * 0.56, D * 0.9, 0, 0, SLATE_DARK },
			{ W * 0.7, H * 0.56, H * 0.84, D * 0.66, side * W * 0.1, D * 0.08, SLATE },
			{ W * 0.42, H * 0.84, H * 0.92, D * 0.4, -side * W * 0.06, D * 0.14, SLATE_LIGHT },
		}
		for k, tier in tiers do
			local tw, y0, y1, td, ox, oz, tone = tier[1], tier[2], tier[3], tier[4], tier[5], tier[6], tier[7]
			local cf = CFrame.new(ox, 0, oz) * CFrame.Angles(0, (k - 1) * 0.05 * side, 0)
			b.block("CliffTier", V(tw, y1 - y0, td), cf * CFrame.new(0, (y0 + y1) / 2, 0), tone, SLATE_MAT)
			pillow(b, "CliffSnow", tw, td, y1, math.min(H * 0.04 + 0.3, 1.5), cf)
			-- fractures across the south face
			local fracs = if k == 1 then { 0.3, 0.62 } else { 0.5 }
			for _, f in fracs do
				b.block("CliffSeam", V(tw * 0.96, 0.4, 0.5), cf * CFrame.new(0, y0 + (y1 - y0) * f, -td / 2 - 0.05), SEAM, SLATE_MAT)
			end
		end
		local shoulder = CFrame.new(side * W * 0.3, 0, -D * 0.34) * CFrame.Angles(0, 0.3 * side, 0)
		b.block("CliffShoulder", V(W * 0.3, H * 0.22, D * 0.26), shoulder * CFrame.new(0, H * 0.11, 0), SLATE, ROCK_MAT)
		pillow(b, "CliffSnow", W * 0.3, D * 0.26, H * 0.22, 0.6, shoulder)
	end
	local function rockArt(b: Brush, size: Vector3, seed: number)
		local W, H, D = size.X, size.Y, size.Z
		b.block("RockBody", V(W * 0.86, H * 0.64, D * 0.84), CFrame.new(0, H * 0.32, 0) * CFrame.Angles(0, 0.08, 0.04), SLATE_DARK, SLATE_MAT)
		b.block("RockSide", V(W * 0.5, H * 0.5, D * 0.56), CFrame.new(W * 0.2 * (if seed % 2 == 0 then 1 else -1), H * 0.25, -D * 0.12) * CFrame.Angles(0, 0.5, 0), SLATE, SLATE_MAT)
		b.block("RockSeam", V(W * 0.8, H * 0.06, 0.3), CFrame.new(0, H * 0.3, -D * 0.43), SEAM, SLATE_MAT)
		b.egg("RockSnow", V(W * 0.84, H * 0.42, D * 0.82), CFrame.new(0, H * 0.72, 0), SNOW, SNOW_MAT)
	end
	local function driftArt(b: Brush, size: Vector3)
		local W, H, D = size.X, size.Y, size.Z
		b.egg("Drift", V(W * 0.7, H * 0.8, D * 0.9), CFrame.new(-W * 0.14, H * 0.4, 0), SNOW_MID, SNOW_MAT)
		b.egg("Drift", V(W * 0.62, H, D * 0.8), CFrame.new(W * 0.18, H * 0.5, D * 0.04), SNOW, SNOW_MAT)
	end
	local function shrubArt(b: Brush, size: Vector3)
		local W, H = size.X, size.Y
		b.ball("Shrub", W * 0.56, CFrame.new(0, W * 0.28, 0), SHRUB, GRASS_MAT)
		b.ball("Shrub", W * 0.42, CFrame.new(W * 0.24, H * 0.46, W * 0.08), SNOW_MID, SNOW_MAT)
		b.ball("Shrub", W * 0.4, CFrame.new(-W * 0.22, H * 0.42, -W * 0.12), SHRUB, GRASS_MAT)
	end
	local function grassArt(b: Brush, size: Vector3, seed: number)
		local W, H = size.X, size.Y
		for k = 1, 5 do
			local a = k * 1.26 + seed
			b.block("GrassBlade", V(0.5, H * 0.8, W * 0.3), CFrame.new(math.sin(a) * W * 0.18, H * 0.4, math.cos(a) * W * 0.18) * CFrame.Angles(0, a, 0.22 * (k % 2 * 2 - 1)), if k % 2 == 0 then GRASS_GOLD else GRASS_DARK, GRASS_MAT)
		end
	end

	-- A fir anywhere: in the cell it gets a trunk proxy, outside the walls none.
	local function fir(x: number, z: number, kind: string, height: number, baseY: number, support: string, host: Instance?, seed: number)
		local asset = FIR_ASSET[kind]
		local size = Spec.alpine[asset]
		local scale = height / size.Y
		local at = CFrame.new(x, baseY, z) * CFrame.Angles(0, seed * 0.61, 0)
		local prefix = if host == flanks then "FlankFir" else "Fir"
		local role = if support == "Ground" then "Grounded" else "Stacked"
		local b = place(prefix, asset, at, role, support, scale, host)
		firArt(b, size, seed)
		if host ~= flanks and kind ~= "S" then
			local trunk = socket(asset, "TrunkBase").Position * scale
			proxy("FirTrunkProxy", V(size.X * 0.12, size.Y * 0.4, size.X * 0.12) * scale, at * CFrame.new(trunk.X, size.Y * 0.2 * scale, trunk.Z))
		end
	end

	-- ------------------------------------------------------------ the terrace
	-- A low stone terrace against the west wall, the lodge's floor. Permanent
	-- visible geometry: a Cobblestone core with coursed faces and a snow skin
	-- whose lip overhangs the stone, so no two faces are coplanar.
	do
		local T = TERRACE
		local w, d = T.x1 - T.x0, T.z1 - T.z0
		local cx, cz = (T.x0 + T.x1) / 2, (T.z0 + T.z1) / 2
		walk("TerraceCore", V(w, TERRACE_Y - 0.3, d), CFrame.new(cx, (TERRACE_Y - 0.3) / 2, cz), STONE, COBBLE, true)
		walk("TerraceSnow", V(w + 0.2, 0.5, d + 0.4), CFrame.new(cx - 0.1, TERRACE_Y - 0.25, cz), SNOW_MID, SNOW_MAT, true)
		-- coursed stone on the two faces the meadow sees, and a coping under the lip
		for _, y in { 1.9, 3.7 } do
			flat(part("TerraceCourse", V(w - 0.2, 0.35, 0.16), CFrame.new(cx, GROUND_Y + y, T.z0 - 0.06), STONE_DARK, COBBLE, false, walkways))
			flat(part("TerraceCourse", V(0.16, 0.35, d - 0.2), CFrame.new(T.x0 - 0.06, GROUND_Y + y, cz), STONE_DARK, COBBLE, false, walkways))
		end
		flat(part("TerraceCoping", V(w - 0.1, 0.45, 0.3), CFrame.new(cx, TERRACE_Y - 0.72, T.z0 - 0.1), STONE_LIGHT, COBBLE, false, walkways))
		flat(part("TerraceCoping", V(0.3, 0.45, d - 0.1), CFrame.new(T.x0 - 0.1, TERRACE_Y - 0.72, cz), STONE_LIGHT, COBBLE, false, walkways))
		-- the low parapet along the front edge, open at the stair, ending inside
		-- the stone posts so its end faces never share a plane with them
		for _, run in { { 85.6, 109.4 }, { 121.6, 138.3 } } do
			local a, bb = run[1], run[2]
			local cxp = (a + bb) / 2
			walk("TerraceParapet", V(bb - a, 1.2, 1.0), CFrame.new(cxp, TERRACE_Y + 0.6, T.z0 + 0.5), STONE, COBBLE, true)
			flat(part("ParapetSnow", V(bb - a + 0.1, 0.35, 1.25), CFrame.new(cxp, TERRACE_Y + 1.3, T.z0 + 0.45), SNOW, SNOW_MAT, false, walkways))
		end
		-- the stair: nine risers of 0.61 down to the meadow, each tread a solid
		-- block from the floor with a snow cap, between two sloped stone cheeks
		local st = T_STAIR
		local rise = (TERRACE_Y - GROUND_Y) / st.risers
		for k = 1, st.risers - 1 do
			local top = GROUND_Y + k * rise
			local z1 = T.z0 - (st.risers - 1 - k) * st.tread
			walk("TerraceStep", V(st.x1 - st.x0, top - GROUND_Y + 0.2, st.tread), CFrame.new((st.x0 + st.x1) / 2, (top + GROUND_Y - 0.2) / 2, z1 - st.tread / 2), STONE_LIGHT, SLATE_MAT, true)
			flat(part("StepSnow", V(st.x1 - st.x0 - 0.6, 0.12, st.tread - 0.25), CFrame.new((st.x0 + st.x1) / 2, top + 0.03, z1 - st.tread / 2 + 0.05), SNOW, SNOW_MAT, false, walkways))
		end
		local run = (st.risers - 1) * st.tread
		local slope = math.atan2(TERRACE_Y - GROUND_Y, run)
		for _, x in { st.x0 - 0.4, st.x1 + 0.4 } do
			walk("TerraceCheek", V(0.8, 1.6, run / math.cos(slope) + 1.2),
				CFrame.new(x, (GROUND_Y + TERRACE_Y) / 2 + 0.55, T.z0 - run / 2) * CFrame.Angles(-slope, 0, 0), STONE, COBBLE, true)
		end
		-- the east edge's low timber rail: art on five sites, with one invisible
		-- rail proxy so walking into it is not walking through it
		for k = 0, 4 do
			local z = T.z0 + 4.8 + k * 9.6
			local b = place("Railing", "FP_Alpine_Railing", CFrame.new(T.x0 + 0.7, TERRACE_Y, z) * CFrame.Angles(0, rad(90), 0), "Stacked", "Walkways/TerraceSnow", 0.8)
			local size = Spec.alpine.FP_Alpine_Railing
			for _, x in { -size.X / 2 + 0.4, size.X / 2 - 0.4 } do
				b.block("RailPost", V(0.5, size.Y - 0.3, 0.5), CFrame.new(x, (size.Y - 0.3) / 2, 0), TIMBER_DARK, WOOD)
				b.block("RailPostSnow", V(0.7, 0.3, 0.7), CFrame.new(x, size.Y - 0.15, 0), SNOW, SNOW_MAT)
			end
			for _, y in { 0.45, 0.82 } do
				b.block("RailBar", V(size.X - 0.2, 0.3, 0.3), CFrame.new(0, size.Y * y, 0), TIMBER, WOOD)
			end
		end
		proxy("TerraceRailProxy", V(0.5, 3.4, T.z1 - T.z0 - 1), CFrame.new(T.x0 + 0.7, TERRACE_Y + 1.7, cz))
		-- stone posts at the stair head and the front-east corner
		for _, x in { st.x0 - 1, st.x1 + 1, T.x0 + 1 } do
			local b = place("TerracePost", "FP_Alpine_Terrace_Post", CFrame.new(x, GROUND_Y, T.z0 + 0.5), "Grounded", "Ground")
			b.block("PostStone", V(1.9, 6.8, 1.9), CFrame.new(0, 3.4, 0), STONE, COBBLE)
			b.block("PostCap", V(2.0, 0.5, 2.0), CFrame.new(0, 7.0, 0), STONE_LIGHT, COBBLE)
			b.block("PostSnow", V(1.8, 0.25, 1.8), CFrame.new(0, 7.38, 0), SNOW, SNOW_MAT)
			proxy("TerracePostProxy", V(2, 7.5, 2), CFrame.new(x, GROUND_Y + 3.75, T.z0 + 0.5))
		end
	end

	-- ------------------------------------------------------------ the lodge
	-- FP_Alpine_Lodge: 40 x 30 x 24, one mesh with its porch, east annex and
	-- chimney. The stand-in follows the request's interior table exactly.
	do
		local b = place("Lodge", "FP_Alpine_Lodge", LODGE_AT, "Stacked", "Walkways/TerraceSnow")
		local mx, mw, mz, md = 4.0, 27.5, 2.5, 16 -- main block centre x, width, centre z, depth
		b.block("LodgePlinth", V(mw + 0.4, 0.96, md + 0.4), CFrame.new(mx, 0.48, mz), STONE, COBBLE)
		b.block("LodgePlinth", V(10.2, 0.96, 12.2), CFrame.new(-14.9, 0.48, 5.5), STONE, COBBLE)
		b.block("LodgeWalls", V(mw, 11.6, md), CFrame.new(mx, 6.7, mz), TIMBER, WOOD)
		for k = 0, 6 do
			b.block("LogBand", V(mw + 0.1, 0.25, 0.25), CFrame.new(mx, 1.9 + k * 1.55, -5.55), TIMBER_DARK, WOOD)
		end
		for _, x in { mx - mw / 2 + 0.45, mx + mw / 2 - 0.45 } do
			b.block("LogCorner", V(1.0, 11.5, 1.0), CFrame.new(x, 6.75, -5.4), TIMBER_LIGHT, WOOD)
		end
		-- the gable: a square turned 45 degrees whose upper half is the triangle
		-- above the eaves, 0.1 inside the wall faces front and back
		b.block("LodgeGable", V(18.4, 18.4, md - 0.2), CFrame.new(mx, 12.5, mz) * CFrame.Angles(0, 0, math.pi / 4), TIMBER, PLANK)
		local slope = math.atan2(13, 15.75)
		local len = math.sqrt(13 * 13 + 15.75 * 15.75)
		for _, side in { -1, 1 } do
			local roofCF = CFrame.new(mx + side * 7.875, 19.0, 2.25) * CFrame.Angles(0, 0, -side * slope)
			b.block("LodgeRoof", V(len, 0.6, 19.5), roofCF * CFrame.new(0, 0.3, 0), TEAL, METAL)
			b.block("RoofSnow", V(len - 0.6, 1.3, 19.1), roofCF * CFrame.new(0, 1.2, 0), SNOW, SNOW_MAT)
			b.block("GableTrim", V(len, 0.55, 0.35), roofCF * CFrame.new(0, 0.25, -9.6), TEAL_DARK, METAL)
		end
		b.roll("RidgeSnow", 1.8, 19.4, CFrame.new(mx, 26.6, 2.25) * CFrame.Angles(0, math.pi / 2, 0), SNOW, SNOW_MAT)
		-- openings: dark frames round the panes the Effects model lights
		local function frame4(cx: number, cy: number, z: number, w: number, h: number)
			b.block("WindowFrame", V(w + 0.6, 0.35, 0.35), CFrame.new(cx, cy + h / 2 + 0.15, z), TIMBER_DARK, WOOD)
			b.block("WindowFrame", V(w + 0.6, 0.35, 0.35), CFrame.new(cx, cy - h / 2 - 0.15, z), TIMBER_DARK, WOOD)
			b.block("WindowFrame", V(0.35, h, 0.35), CFrame.new(cx - w / 2 - 0.15, cy, z), TIMBER_DARK, WOOD)
			b.block("WindowFrame", V(0.35, h, 0.35), CFrame.new(cx + w / 2 + 0.15, cy, z), TIMBER_DARK, WOOD)
		end
		frame4(11.5, 6.75, -5.7, 4.0, 4.5)
		frame4(-3.5, 6.75, -5.7, 4.0, 4.5)
		frame4(4.0, 16.5, -5.7, 3.5, 3.0)
		frame4(-14.75, 5.5, -0.7, 3.0, 3.0)
		b.block("LodgeDoor", V(4.5, 8.5, 0.3), CFrame.new(4.0, 5.25, -5.65), TIMBER_DARK, PLANK)
		b.block("DoorLintel", V(5.4, 0.5, 0.4), CFrame.new(4.0, 9.75, -5.7), TIMBER_LIGHT, WOOD)
		-- porch: deck, step, posts, rails with the entrance gap, an awning
		b.block("PorchDeck", V(21, 0.5, 5.5), CFrame.new(4.0, 0.75, -8.25), TIMBER, PLANK)
		b.block("PorchStep", V(5, 0.5, 1), CFrame.new(4.0, 0.25, -11.5), TIMBER_LIGHT, PLANK)
		for _, x in { -6.0, 1.5, 6.5, 14.0 } do
			b.block("PorchPost", V(0.6, 8.5, 0.6), CFrame.new(x, 5.25, -10.7), TIMBER, WOOD)
		end
		for _, run in { { -6.0, 1.5 }, { 6.5, 14.0 } } do
			for _, y in { 2.6, 4.0 } do
				b.block("PorchRail", V(run[2] - run[1], 0.3, 0.3), CFrame.new((run[1] + run[2]) / 2, y, -10.7), TIMBER_LIGHT, WOOD)
			end
		end
		local awning = CFrame.new(4.0, 10.9, -7.3) * CFrame.Angles(0.26, 0, 0)
		b.block("PorchAwning", V(9, 0.4, 3.8), awning, TEAL, METAL)
		b.block("AwningSnow", V(8.6, 0.6, 3.5), awning * CFrame.new(0, 0.5, 0), SNOW, SNOW_MAT)
		for _, name in { "PorchLanternW", "PorchLanternE" } do
			local cf = socket("FP_Alpine_Lodge", name)
			b.block("LanternCap", V(1.1, 0.3, 1.1), cf * CFrame.new(0, 0.6, 0), IRON, METAL)
			b.block("LanternBase", V(0.9, 0.25, 0.9), cf * CFrame.new(0, -0.58, 0), IRON, METAL)
		end
		-- east annex: lower log wing with a lean-to roof falling east
		b.block("AnnexWalls", V(10.2, 8.0, 12), CFrame.new(-14.9, 5.0, 5.5), TIMBER, WOOD)
		local lean = math.atan2(4.5, 10.25)
		local leanCF = CFrame.new(-14.9, 11.25, 5.5) * CFrame.Angles(0, 0, lean)
		b.block("AnnexRoof", V(11.0, 0.5, 12.8), leanCF, TEAL, METAL)
		b.block("AnnexSnow", V(10.6, 1.0, 12.4), leanCF * CFrame.new(0, 0.7, 0), SNOW, SNOW_MAT)
		-- chimney on the west slope near the back
		b.block("Chimney", V(3, 10.2, 3), CFrame.new(8.5, 24.1, 7.5), STONE_LIGHT, COBBLE)
		b.block("ChimneyCap", V(3.6, 0.6, 3.6), CFrame.new(8.5, 29.5, 7.5), STONE_DARK, COBBLE)
		b.block("ChimneySnow", V(3.2, 0.3, 3.2), CFrame.new(8.5, 29.85, 7.5), SNOW, SNOW_MAT)
		-- collision: the main block and annex are solid, the porch is walkable
		proxy("LodgeProxy", V(mw, 12.5, md), LODGE_AT * CFrame.new(mx, 6.25, mz))
		proxy("AnnexProxy", V(10.25, 9, 12), LODGE_AT * CFrame.new(-14.875, 4.5, 5.5))
		walk("PorchDeck", V(21, 1.0, 5.5), LODGE_AT * CFrame.new(4.0, 0.5, -8.25), TIMBER, PLANK, false)
		walk("PorchStep", V(5, 0.5, 1.0), LODGE_AT * CFrame.new(4.0, 0.25, -11.5), TIMBER, PLANK, false)
		for _, run in { { -6.5, 1.5 }, { 6.5, 14.5 } } do
			proxy("PorchRailProxy", V(run[2] - run[1], 3, 0.5), LODGE_AT * CFrame.new((run[1] + run[2]) / 2, 2.5, -10.7))
		end
		for _, x in { -6.5, 14.5 } do
			proxy("PorchRailProxy", V(0.5, 3, 5.0), LODGE_AT * CFrame.new(x, 2.5, -8.2))
		end
	end
	-- the lit panes and the warm light inside, outside the mesh's bounds of
	-- responsibility: art stays art, glow is an effect on a socket
	do
		local panes = {
			{ "WindowW", 4.0, 4.5 }, { "WindowE", 4.0, 4.5 }, { "WindowGable", 3.5, 3.0 }, { "AnnexWindow", 3.0, 3.0 },
		}
		for _, spec in panes do
			local cf = LODGE_AT * socket("FP_Alpine_Lodge", spec[1]) * CFrame.new(0, 0, -0.1)
			flat(part("LodgeWindowGlow", V(spec[2], spec[3], 0.1), cf, AMBER, NEON, false, effects))
		end
		glow(flat(part("LodgeInterior", V(1, 1, 1), LODGE_AT * CFrame.new(4.0, 6.0, -3.0), AMBER, NEON, false, effects)), 1.1, 22).Transparency = 1
		for _, name in { "PorchLanternW", "PorchLanternE" } do
			local pane = flat(part("PorchLanternGlass", V(0.7, 0.9, 0.7), LODGE_AT * socket("FP_Alpine_Lodge", name), LANTERN_GLASS, NEON, false, effects))
			if name == "PorchLanternW" then glow(pane, 0.8, 14) end
		end
		-- restrained chimney smoke on an invisible anchor at the flue
		local anchor = flat(part("ChimneySmoke", V(1, 1, 1), LODGE_AT * socket("FP_Alpine_Lodge", "ChimneyTop") * CFrame.new(0, 0.6, 0), SMOKE, SMOOTH, false, effects))
		anchor.Transparency = 1
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Smoke"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Rate = 2.5
		smoke.Lifetime = NumberRange.new(6, 9)
		smoke.Speed = NumberRange.new(2, 3.5)
		smoke.SpreadAngle = Vector2.new(8, 8)
		smoke.Acceleration = V(0.6, 0.35, 0)
		smoke.Drag = 0.4
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 7) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.7, 0.8), NumberSequenceKeypoint.new(1, 1) })
		smoke.Color = ColorSequence.new(SMOKE)
		smoke.LightInfluence = 1
		smoke.LightEmission = 0
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = anchor
	end

	-- ------------------------------------------------------------ the camp
	-- In front of the lodge on the deck. Measured off the concept; every piece is
	-- its own site so the tent, sled, pennants and supplies land one for one.
	do
		local function camp(prefix: string, asset: string, x: number, z: number, yaw: number, scale: number, y: number?, support: string?): (Brush, CFrame)
			local size = Spec.alpine[asset] * scale
			local sx, sz = insideCell(x, z, size, rad(yaw))
			local cf = CFrame.new(sx, y or TERRACE_Y, sz) * CFrame.Angles(0, rad(yaw), 0)
			return place(prefix, asset, cf, "Stacked", support or "Walkways/TerraceSnow", scale), cf
		end
		-- the orange tent, door to the south-east
		do
			local b, cf = camp("Tent", "FP_Alpine_Tent", 95.5, 35.5, 40, 1)
			local slope = math.atan2(5.4, 4)
			for _, side in { -1, 1 } do
				b.block("TentCanvas", V(6.7, 0.3, 8.6), CFrame.new(side * 2.0, 2.7, 0) * CFrame.Angles(0, 0, -side * slope), if side > 0 then CANVAS else CANVAS_SHADE, FABRIC)
			end
			b.roll("TentRidge", 0.4, 8.8, CFrame.new(0, 5.45, 0) * CFrame.Angles(0, math.pi / 2, 0), TIMBER_DARK, WOOD)
			b.block("TentRidgeSnow", V(1.1, 0.4, 8.4), CFrame.new(0, 5.8, 0), SNOW, SNOW_MAT)
			b.block("TentDoor", V(2.4, 3.4, 0.2), CFrame.new(0, 1.7, -4.4), TIMBER_DARK, FABRIC)
			proxy("TentProxy", V(6.5, 5, 7.5), cf * CFrame.new(0, 2.5, 0))
		end
		do
			local b, cf = camp("Sled", "FP_Alpine_Camp_Sled", 104, 36.5, -10, 1)
			for _, x in { -1.9, 1.9 } do
				b.block("SledRunner", V(0.3, 0.4, 3.0), CFrame.new(x * 0.5, 0.2, 0), TIMBER_DARK, WOOD)
			end
			b.block("SledDeck", V(4.8, 0.4, 2.8), CFrame.new(0, 0.6, 0), TEAL, WOOD)
			b.block("SledBundle", V(3.4, 1.1, 2.2), CFrame.new(0, 1.35, 0), CANVAS_SHADE, FABRIC)
			proxy("SledProxy", V(4.6, 1.8, 2.8), cf * CFrame.new(0, 0.9, 0))
		end
		local function pennant(x: number, z: number, scale: number)
			-- the pole, not the bounds' centre, stands where the concept puts it
			local pole = socket("FP_Alpine_Pennant", "PoleBase").Position * scale
			local b = camp("Pennant", "FP_Alpine_Pennant", x - pole.X, z - pole.Z, 0, scale)
			local p = socket("FP_Alpine_Pennant", "PoleBase").Position
			b.post("PennantPole", 0.35, 10.4, CFrame.new(p.X, 5.2, p.Z), TIMBER_DARK, WOOD)
			b.ball("PennantFinial", 0.6, CFrame.new(p.X, 10.65, p.Z), GOLD, METAL)
			b.block("PennantFlag", V(3.4, 5.2, 0.2), CFrame.new(p.X + 1.95, 7.2, p.Z), TEAL, FABRIC)
			b.block("PennantMark", V(1.6, 1.2, 0.25), CFrame.new(p.X + 1.95, 7.4, p.Z), SNOW, FABRIC)
		end
		pennant(88.5, 39, 0.85)
		pennant(96, 57, 1.15)
		local function lanternPost(x: number, z: number)
			local b, cf = camp("LanternPost", "FP_Alpine_Lantern_Post", x, z, 0, 0.85)
			local light = socket("FP_Alpine_Lantern_Post", "Light")
			b.block("LanternPost", V(0.5, 4.2, 0.5), CFrame.new(0, 2.1, 0), TIMBER_DARK, WOOD)
			b.block("LanternArm", V(0.3, 0.3, 1.1), CFrame.new(0, 5.4, -0.4), IRON, METAL)
			b.block("LanternBase", V(1.1, 0.3, 1.1), light * CFrame.new(0, -0.7, 0), IRON, METAL)
			b.block("LanternCap", V(1.5, 0.4, 1.5), light * CFrame.new(0, 0.75, 0), IRON, METAL)
			local pane = flat(part("LanternGlass", V(0.85, 1.1, 0.85), cf * CFrame.new(light.Position * 0.85), LANTERN_GLASS, NEON, false, effects))
			glow(pane, 0.9, 16)
			proxy("LanternPostProxy", V(0.6, 5.5, 0.6), cf * CFrame.new(0, 2.75, 0))
		end
		lanternPost(126.5, 33)
		lanternPost(92.5, 55.5)
		local function barrel(x: number, z: number, yaw: number)
			local b, cf = camp("Barrel", "FP_Alpine_Barrel", x, z, yaw, 0.65)
			b.post("BarrelBody", 3.3, 4.2, CFrame.new(0, 2.1, 0), TIMBER, WOOD)
			for _, y in { 1.0, 3.2 } do
				b.post("BarrelHoop", 3.45, 0.3, CFrame.new(0, y, 0), IRON, METAL)
			end
			b.post("BarrelSnow", 2.9, 0.3, CFrame.new(0, 4.35, 0), SNOW, SNOW_MAT)
			proxy("BarrelProxy", V(2.1, 2.9, 2.1), cf * CFrame.new(0, 1.45, 0))
		end
		barrel(135, 37.5, 0)
		barrel(134.5, 33.5, 20)
		barrel(135, 52, 0)
		barrel(99, 55.5, 0)
		for k = 1, 2 do
			local y = if k == 1 then TERRACE_Y else TERRACE_Y + 4.5 * 0.65
			local support = if k == 1 then "Walkways/TerraceSnow" else "PropSites/Crate01"
			local b, cf = camp("Crate", "FP_Alpine_Crate", 131, 36, 15 + (k - 1) * 12, 0.65, y, support)
			b.block("CrateBody", V(4.4, 4.4, 4.4), CFrame.new(0, 2.2, 0), TIMBER_LIGHT, PLANK)
			for _, y2 in { 0.9, 3.5 } do
				b.block("CrateBrace", V(4.5, 0.4, 4.5), CFrame.new(0, y2, 0), TIMBER_DARK, WOOD)
			end
			b.block("CrateSnow", V(3.8, 0.3, 3.8), CFrame.new(0, 4.35, 0), SNOW, SNOW_MAT)
			if k == 1 then
				proxy("CrateProxy", V(2.8, 5.6, 2.8), cf * CFrame.new(0, 2.8, 0))
			end
		end
		do
			local b, cf = camp("Woodpile", "FP_Alpine_Woodpile", 131, 49.5, 90, 1)
			for _, x in { -2.6, 2.6 } do
				b.block("RackPost", V(0.4, 3.4, 0.4), CFrame.new(x, 1.7, 0), TIMBER_DARK, WOOD)
			end
			for row = 0, 2 do
				for k = 0, 3 - row do
					b.roll("Log", 1.1, 4.6, CFrame.new(0, 0.55 + row * 0.95, -1.6 + k * 1.1 + row * 0.55) * CFrame.Angles(0, 0, 0), TIMBER_LIGHT, WOOD)
				end
			end
			b.block("WoodSnow", V(5.0, 0.4, 3.2), CFrame.new(0, 3.35, -0.4), SNOW, SNOW_MAT)
			proxy("WoodpileProxy", V(5.4, 3.2, 4.2), cf * CFrame.new(0, 1.6, 0))
		end
		do
			local b = camp("NoticeBoard", "FP_Alpine_Notice_Board", 89.5, 63, -15, 1)
			for _, x in { -1.6, 1.6 } do
				b.block("BoardPost", V(0.35, 4.6, 0.35), CFrame.new(x, 2.3, 0), TIMBER_DARK, WOOD)
			end
			b.block("NoticeBoard", V(3.6, 2.4, 0.25), CFrame.new(0, 3.1, -0.05), TEAL, WOOD)
			b.block("BoardRoof", V(4.0, 0.3, 0.9), CFrame.new(0, 4.6, 0), TIMBER, WOOD)
			b.block("BoardSnow", V(3.8, 0.25, 0.8), CFrame.new(0, 4.85, 0), SNOW, SNOW_MAT)
		end
	end

	-- ------------------------------------------------------------ the bridge
	-- Two layered slate shelves and the gorge rock, each one mesh; the walkable
	-- tops are invisible proxies at exactly the shelves' walk level.
	do
		local b = place("ShelfNorth", "FP_Alpine_Shelf_North", SHELF_N_AT, "Grounded", "Ground")
		local top = SHELF_Y - GROUND_Y
		-- C: x +21.25 .. -1.25 in the asset; A: x -1.25 .. -21.25, z +3.75 .. +11.75
		for _, mass in { { 10, 0, 22.0, 23.0 }, { -10.975, 7.75, 20.15, 7.6 } } do
			local mx, mz, mw, md = mass[1], mass[2], mass[3], mass[4]
			b.block("ShelfMass", V(mw, top * 0.55, md), CFrame.new(mx, top * 0.275, mz), SLATE_DARK, SLATE_MAT)
			b.block("ShelfMass", V(mw - 0.6, top * 0.45 - 0.3, md - 0.6), CFrame.new(mx, top * 0.55 + (top * 0.45 - 0.3) / 2, mz), SLATE, SLATE_MAT)
			b.block("ShelfSnow", V(mw + 0.4, 0.6, md + 0.4), CFrame.new(mx, top - 0.3, mz), SNOW_MID, SNOW_MAT)
		end
		for _, pad in { { 16, -6, 7 }, { 6, 4, 6 }, { 15, 8, 5.5 }, { -9, 8.5, 5.5 }, { -17, 7.5, 4.5 } } do
			b.egg("ShelfPillow", V(pad[3], 0.8, pad[3] * 0.8), CFrame.new(pad[1], top - 0.05, pad[2]), SNOW, SNOW_MAT)
		end
		for _, y in { 1.8, 3.6, 6.0 } do
			b.block("ShelfSeam", V(21.8, 0.4, 0.4), CFrame.new(10, y, -11.55), SEAM, SLATE_MAT)
			b.block("ShelfSeam", V(0.4, 0.4, 22.8), CFrame.new(21.05, y, 0), SEAM, SLATE_MAT)
			b.block("ShelfSeam", V(19.8, 0.4, 0.4), CFrame.new(-10.975, y, 3.8), SEAM, SLATE_MAT)
		end
		b.block("ShelfLedge", V(9, 3.2, 3.5), CFrame.new(14, 1.6, -9.9) * CFrame.Angles(0, 0.1, 0), SLATE, SLATE_MAT)
		b.egg("ShelfPillow", V(8.4, 1.4, 3.2), CFrame.new(14, 3.2, -9.9), SNOW, SNOW_MAT)
		b.block("ShelfLedge", V(6, 2.4, 3.2), CFrame.new(17.5, 1.2, 4) * CFrame.Angles(0, 0.2, 0), SLATE_DARK, ROCK_MAT)
		b.egg("ShelfLip", V(22.4, 1.1, 2.2), CFrame.new(10, top - 0.2, -10.7), SNOW, SNOW_MAT)
		b.egg("ShelfLip", V(2.2, 1.1, 23.0), CFrame.new(20.2, top - 0.2, 0), SNOW, SNOW_MAT)
		walk("ShelfTop", V(SHELF_C.x1 - SHELF_C.x0, top, SHELF_C.z1 - SHELF_C.z0),
			CFrame.new((SHELF_C.x0 + SHELF_C.x1) / 2, GROUND_Y + top / 2, (SHELF_C.z0 + SHELF_C.z1) / 2), SLATE, SLATE_MAT, false)
		walk("ShelfTop", V(SHELF_A.x1 - SHELF_A.x0, top, SHELF_A.z1 - SHELF_A.z0),
			CFrame.new((SHELF_A.x0 + SHELF_A.x1) / 2, GROUND_Y + top / 2, (SHELF_A.z0 + SHELF_A.z1) / 2), SLATE, SLATE_MAT, false)
	end
	do
		local b = place("ShelfSouth", "FP_Alpine_Shelf_South", SHELF_S_AT, "Grounded", "Ground")
		local top = SHELF_Y - GROUND_Y
		b.block("ShelfMass", V(28.4, top * 0.55, 14.4), CFrame.new(0, top * 0.275, 0), SLATE_DARK, SLATE_MAT)
		b.block("ShelfMass", V(27.8, top * 0.45 - 0.3, 13.8), CFrame.new(0, top * 0.55 + (top * 0.45 - 0.3) / 2, 0), SLATE, SLATE_MAT)
		b.block("ShelfSnow", V(29, 0.6, 15), CFrame.new(0, top - 0.3, 0), SNOW_MID, SNOW_MAT)
		for _, pad in { { -10, 3, 6 }, { 9, -2, 5 }, { 11, 4.5, 4 } } do
			b.egg("ShelfPillow", V(pad[3], 0.8, pad[3] * 0.8), CFrame.new(pad[1], top - 0.05, pad[2]), SNOW, SNOW_MAT)
		end
		for _, y in { 1.8, 3.6, 6.0 } do
			b.block("ShelfSeam", V(0.4, 0.4, 14.2), CFrame.new(14.3, y, 0), SEAM, SLATE_MAT)
			for _, side in { -1, 1 } do
				b.block("ShelfSeam", V(7.6, 0.4, 0.4), CFrame.new(side * 10.4, y, -7.3), SEAM, SLATE_MAT)
			end
		end
		walk("ShelfTop", V(SHELF_B.x1 - SHELF_B.x0, top, SHELF_B.z1 - SHELF_B.z0),
			CFrame.new((SHELF_B.x0 + SHELF_B.x1) / 2, GROUND_Y + top / 2, (SHELF_B.z0 + SHELF_B.z1) / 2), SLATE, SLATE_MAT, false)
		-- the stair down its south face: fourteen risers of 0.61
		local st = B_STAIR
		local rise = (SHELF_Y - GROUND_Y) / st.risers
		for k = 1, st.risers - 1 do
			local stepTop = GROUND_Y + k * rise
			local z1 = SHELF_B.z0 - (st.risers - 1 - k) * st.tread
			walk("ShelfStep", V(st.x1 - st.x0, stepTop - GROUND_Y + 0.2, st.tread), CFrame.new((st.x0 + st.x1) / 2, (stepTop + GROUND_Y - 0.2) / 2, z1 - st.tread / 2), STONE_LIGHT, SLATE_MAT, true)
			flat(part("StepSnow", V(st.x1 - st.x0 - 0.6, 0.12, st.tread - 0.25), CFrame.new((st.x0 + st.x1) / 2, stepTop + 0.03, z1 - st.tread / 2 + 0.05), SNOW, SNOW_MAT, false, walkways))
		end
		local run = (st.risers - 1) * st.tread
		local slope = math.atan2(SHELF_Y - GROUND_Y, run)
		for _, x in { st.x0 - 0.4, st.x1 + 0.4 } do
			walk("ShelfCheek", V(0.8, 1.6, run / math.cos(slope) + 1.2),
				CFrame.new(x, (GROUND_Y + SHELF_Y) / 2 + 0.55, SHELF_B.z0 - run / 2) * CFrame.Angles(-slope, 0, 0), STONE, COBBLE, true)
		end
		-- short stone posts at the stair foot, as the concept frames it
		-- just outside the cheeks, whose buried low ends would otherwise be what
		-- the posts stand on
		for _, x in { st.x0 - 1.4, st.x1 + 1.4 } do
			local pb = place("TerracePost", "FP_Alpine_Terrace_Post", CFrame.new(x, GROUND_Y, SHELF_B.z0 - run - 0.4), "Grounded", "Ground", 0.5)
			pb.block("PostStone", V(1.9, 6.8, 1.9), CFrame.new(0, 3.4, 0), STONE, COBBLE)
			pb.block("PostCap", V(2.0, 0.5, 2.0), CFrame.new(0, 7.0, 0), STONE_LIGHT, COBBLE)
			pb.block("PostSnow", V(1.8, 0.25, 1.8), CFrame.new(0, 7.38, 0), SNOW, SNOW_MAT)
			proxy("TerracePostProxy", V(1, 3.75, 1), CFrame.new(x, GROUND_Y + 1.875, SHELF_B.z0 - run - 0.4))
		end
	end
	do
		local b = place("GorgeRock", "FP_Alpine_Gorge_Rock", GORGE_AT, "Grounded", "Ground")
		b.block("GorgeMass", V(11.4, 8.0, 49.4), CFrame.new(0, 4.0, 0), SLATE_DARK, SLATE_MAT)
		b.block("GorgeCap", V(11.8, 0.5, 49.6), CFrame.new(0, 8.25, 0), SNOW_MID, SNOW_MAT)
		b.block("GorgeTier", V(7.6, 2.3, 39.6), CFrame.new(-1.2, 9.4, 2), SLATE, SLATE_MAT)
		b.block("GorgeCap", V(8.0, 0.5, 40), CFrame.new(-1.2, 10.75, 2), SNOW, SNOW_MAT)
		for k = -2, 2 do
			b.egg("GorgeSnow", V(7.6, 1.4, 8.5), CFrame.new(-1.0 + (k % 2) * 0.8, 10.4, 2 + k * 8.2), SNOW, SNOW_MAT)
		end
		for _, y in { 2.8, 5.6 } do
			b.block("GorgeSeam", V(0.4, 0.45, 49.5), CFrame.new(5.75, y, 0), SEAM, SLATE_MAT)
		end
		proxy("GorgeProxy", V(11, 10.5, 49), GORGE_AT * CFrame.new(0, 5.25, 0))
	end
	-- the rope bridge: one mesh on the measured axis, a segmented invisible deck
	-- on the same sag underneath it, and low invisible kerbs either side
	do
		local size = Spec.alpine.FP_Alpine_Bridge
		local base = BRIDGE_AT
		local b = place("Bridge", "FP_Alpine_Bridge", base, "Stacked", "Walkways/ShelfTop", 1)
		local L = size.Z
		local function deckY(z: number): number
			local u = z / (L / 2)
			return 1.5 - 1.2 * (1 - u * u)
		end
		for k = -8, 8 do
			local z = k * 2.0
			local slopeZ = 2.4 * z / ((L / 2) * (L / 2)) -- d(deckY)/dz
			b.block("BridgePlank", V(8, 0.3, 1.7), CFrame.new(0, deckY(z) - 0.15, z) * CFrame.Angles(-math.atan(slopeZ), 0, 0), if k % 3 == 0 then TIMBER_LIGHT else TIMBER, PLANK)
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local lantern = (sx == 1 and sz == 1) or (sx == -1 and sz == -1)
				local h = if lantern then 5.9 else 7.2
				b.block("BridgePost", V(0.8, h, 0.8), CFrame.new(sx * 4.6, h / 2, sz * 16.3), TIMBER_DARK, WOOD)
				if not lantern then
					b.block("PostSnow", V(1.0, 0.3, 1.0), CFrame.new(sx * 4.6, 7.35, sz * 16.3), SNOW, SNOW_MAT)
				end
			end
			for _, lift in { 1.4, 3.0 } do
				for seg = 0, 3 do
					local z0, z1 = -16.3 + seg * 8.15, -16.3 + (seg + 1) * 8.15
					local sag = if lift > 2 then 0.7 else 1.0
					local y0 = 1.5 + lift - sag * (1 - (z0 / 16.3) ^ 2)
					local y1 = 1.5 + lift - sag * (1 - (z1 / 16.3) ^ 2)
					local len = math.sqrt((z1 - z0) ^ 2 + (y1 - y0) ^ 2)
					b.block("BridgeRope", V(0.22, 0.22, len + 0.1), CFrame.new(sx * 4.4, (y0 + y1) / 2, (z0 + z1) / 2) * CFrame.Angles(-math.atan2(y1 - y0, z1 - z0), 0, 0), ROPE, FABRIC)
				end
			end
		end
		for _, name in { "LanternNW", "LanternSE" } do
			local cf = socket("FP_Alpine_Bridge", name)
			b.block("LanternBase", V(1.1, 0.3, 1.1), cf * CFrame.new(0, -0.65, 0), IRON, METAL)
			b.block("LanternCap", V(1.5, 0.4, 1.5), cf * CFrame.new(0, 0.62, 0), IRON, METAL)
			glow(flat(part("BridgeLanternGlass", V(0.85, 1.0, 0.85), base * cf, LANTERN_GLASS, NEON, false, effects)), 0.9, 16)
		end
		-- the walkable deck: twelve short planks of collision on the same sag
		local n = 12
		for k = 1, n do
			local za = -L / 2 + (k - 1) * L / n
			local zb = -L / 2 + k * L / n
			local ya, yb = deckY(za), deckY(zb)
			local len = math.sqrt((zb - za) ^ 2 + (yb - ya) ^ 2)
			local seg = base * CFrame.new(0, (ya + yb) / 2 - 0.25, (za + zb) / 2) * CFrame.Angles(-math.atan2(yb - ya, zb - za), 0, 0)
			walk("BridgeDeck", V(8, 0.5, len + 0.05), seg, TIMBER, PLANK, false)
			for _, sx in { -1, 1 } do
				proxy("BridgeKerb", V(0.4, 1.4, len + 0.05), seg * CFrame.new(sx * 4.25, 0.95, 0))
			end
		end
	end
	-- the signpost and the rope rail on shelf C, and a coil of rope by the bridge
	do
		local sp = SHELF_N_AT * socket("FP_Alpine_Shelf_North", "Signpost")
		local at = CFrame.new(sp.Position.X, SHELF_Y, sp.Position.Z) * CFrame.Angles(0, rad(-45), 0)
		local b = place("Signpost", "FP_Alpine_Signpost", at, "Stacked", "Walkways/ShelfTop", 0.8)
		b.block("SignPost", V(0.5, 6.8, 0.5), CFrame.new(0, 3.4, 0), TIMBER_DARK, WOOD)
		b.block("SignBoard", V(5.6, 1.1, 0.25), CFrame.new(0.3, 5.3, -0.2) * CFrame.Angles(0, 0, 0.05), TEAL, WOOD)
		b.block("SignBoard", V(5.2, 1.0, 0.25), CFrame.new(-0.3, 4.05, -0.2) * CFrame.Angles(0, 0, -0.05), SNOW_MID, WOOD)
		b.block("SignSnow", V(0.8, 0.3, 0.8), CFrame.new(0, 6.85, 0), SNOW, SNOW_MAT)
		proxy("SignpostProxy", V(0.6, 5.6, 0.6), at * CFrame.new(0, 2.8, 0))
		-- the rope rail down shelf C's gorge edge, from its middle to the corner
		-- where the bridge's north-west post stands
		local railA = (SHELF_N_AT * socket("FP_Alpine_Shelf_North", "RailStart")).Position
		local railB = V(SHELF_C.x0 + 0.7, 0, SHELF_A.z0 - 0.5)
		local dir = V(railB.X - railA.X, 0, railB.Z - railA.Z)
		local yawR = math.atan2(dir.X, dir.Z) + math.pi / 2
		local rs = Spec.alpine.FP_Alpine_Railing
		for k = 0, 1 do
			local c = V(railA.X, 0, railA.Z) + dir * ((k + 0.5) / 2)
			local rb = place("Railing", "FP_Alpine_Railing", CFrame.new(c.X, SHELF_Y, c.Z) * CFrame.Angles(0, yawR, 0), "Stacked", "Walkways/ShelfTop", dir.Magnitude / 2 / rs.X)
			for _, x in { -rs.X / 2 + 0.4, rs.X / 2 - 0.4 } do
				rb.block("RailPost", V(0.5, rs.Y - 0.3, 0.5), CFrame.new(x, (rs.Y - 0.3) / 2, 0), TIMBER_DARK, WOOD)
			end
			for _, y in { 0.45, 0.82 } do
				rb.block("RailRope", V(rs.X - 0.2, 0.22, 0.22), CFrame.new(0, rs.Y * y, 0), ROPE, FABRIC)
			end
		end
		proxy("ShelfRailProxy", V(0.5, 3, dir.Magnitude), CFrame.new((railA.X + railB.X) / 2, SHELF_Y + 1.5, (railA.Z + railB.Z) / 2) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0))
	end

	-- ------------------------------------------------------------ cliffs, rocks
	for index, spec in CLIFFS do
		local asset, x, z, yaw, scale, treeH = spec[1], spec[2], spec[3], rad(spec[4]), spec[5], spec[6]
		local size = Spec.alpine[asset] * scale
		local cx, cz = insideCell(x, z, size, yaw)
		local at = CFrame.new(cx, GROUND_Y, cz) * CFrame.Angles(0, yaw, 0)
		local prefix = if asset == "FP_Alpine_Cliff_Tall" then "CliffTall" elseif asset == "FP_Alpine_Cliff_Wide" then "CliffWide" else "CliffBlock"
		local b = place(prefix, asset, at, "Grounded", "Ground", scale)
		cliffArt(b, Spec.alpine[asset], index)
		proxy("CliffProxy", V(size.X * 0.8, size.Y, size.Z * 0.8), at * CFrame.new(0, size.Y / 2, 0))
		if treeH then
			local mount = at * CFrame.new(socket(asset, "TopMount").Position * scale)
			fir(mount.Position.X, mount.Position.Z, "M", treeH, mount.Position.Y, "PropSites/" .. b.site.Name, nil, index)
		end
	end
	for index, spec in ROCKS do
		local asset = if spec[3] == "L" then "FP_Alpine_Snow_Rock" else "FP_Alpine_Snow_Rock_Small"
		local yaw, scale = rad(spec[4]), spec[5]
		local size = Spec.alpine[asset] * scale
		local x, z = insideCell(spec[1], spec[2], size, yaw)
		local at = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0)
		rockArt(place("Rock", asset, at, "Grounded", "Ground", scale), Spec.alpine[asset], index)
		proxy("RockProxy", V(size.X * 0.74, size.Y * 0.9, size.Z * 0.74), at * CFrame.new(0, size.Y * 0.45, 0))
	end

	-- ------------------------------------------------------------ vegetation
	for index, spec in FIRS do
		local x, z, kind, height, baseY = spec[1], spec[2], spec[3], spec[4], spec[5]
		local size = Spec.alpine[FIR_ASSET[kind]] * (height / Spec.alpine[FIR_ASSET[kind]].Y)
		local sx, sz = insideCell(x, z, size, 0)
		fir(sx, sz, kind, height, GROUND_Y + baseY, if baseY > 0 then "Walkways/TerraceSnow" else "Ground", nil, index)
	end
	local function plant(x: number, z: number, kind: string, seed: number)
		local asset = if kind == "G" then "FP_Alpine_Grass" else "FP_Alpine_Frosted_Shrub"
		local scale = if kind == "G" then 0.55 else 0.57
		local size = Spec.alpine[asset] * scale
		local px, pz = insideCell(x, z, size, seed * 0.9)
		local b = place("Plant", asset, CFrame.new(px, GROUND_Y, pz) * CFrame.Angles(0, seed * 0.9, 0), "Grounded", "Ground", scale)
		if kind == "G" then grassArt(b, Spec.alpine[asset], seed) else shrubArt(b, Spec.alpine[asset]) end
	end
	local function drift(x: number, z: number, yawDeg: number, scale: number)
		local yaw = rad(yawDeg)
		local size = Spec.alpine.FP_Alpine_Snow_Drift * scale
		local dx, dz = insideCell(x, z, size, yaw)
		driftArt(place("Drift", "FP_Alpine_Snow_Drift", CFrame.new(dx, GROUND_Y, dz) * CFrame.Angles(0, yaw, 0), "Grounded", "Ground", scale), Spec.alpine.FP_Alpine_Snow_Drift)
	end
	for index, spec in PLANTS do
		plant(spec[1], spec[2], spec[3], index)
	end
	-- Composed base dressing, the way the concept plants every cluster: golden
	-- grass and frosted shrubs at the meadow-side foot of each rock and of every
	-- other band fir, and a drift banked against each side-band cliff. Fixed by
	-- the tables above, never in the route, never on the terrace, the stairs or
	-- the bridge shelves.
	local function dressable(x: number, z: number): boolean
		if math.abs(x) < LANE_HALF + 8 then return false end
		if x > TERRACE.x0 - 3 and z > 17 and z < TERRACE.z1 + 2 then return false end
		if x < SHELF_C.x1 + 3 and z > SHELF_B.z0 - 16 and z < SHELF_C.z1 + 2 then return false end
		return true
	end
	for index, spec in ROCKS do
		local size = Spec.alpine[if spec[3] == "L" then "FP_Alpine_Snow_Rock" else "FP_Alpine_Snow_Rock_Small"] * spec[5]
		local yaw = rad(spec[4])
		for k, side in { -1, 1 } do
			local off = CFrame.Angles(0, yaw, 0) * V(side * size.X * 0.45, 0, -size.Z * 0.6 - 0.8)
			local x, z = spec[1] + off.X, spec[2] + off.Z
			if dressable(x, z) and (k == 1 or index % 2 == 0) then
				plant(x, z, if (index + k) % 3 == 0 then "F" else "G", index * 7 + k)
			end
		end
	end
	for index, spec in FIRS do
		local x, z = spec[1] + (if index % 2 == 0 then 3 else -3), spec[2] - 3.5
		if index % 2 == 0 and spec[5] == 0 and dressable(x, z) then
			plant(x, z, if index % 4 == 0 then "F" else "G", index * 5)
		end
	end
	for index = #CLIFFS - 4, #CLIFFS do
		local spec = CLIFFS[index]
		local size = Spec.alpine[spec[1]] * spec[5]
		local off = CFrame.Angles(0, rad(spec[4]), 0) * V(0, 0, -size.Z * 0.5 - 2)
		if dressable(spec[2] + off.X, spec[3] + off.Z) then
			drift(spec[2] + off.X, spec[3] + off.Z, spec[4], 0.8)
		end
	end
	for _, spec in DRIFTS do
		drift(spec[1], spec[2], spec[3], spec[4])
	end
	-- lane stakes: the concept's small timber markers either side of the route.
	-- Walk-through, so neither creatures nor players snag on them.
	for _, side in { -1, 1 } do
		for _, z in STAKE_Z do
			local b = place("TrailPost", "FP_Alpine_Trail_Post", CFrame.new(side * STAKE_X, GROUND_Y, z), "Grounded", "Ground")
			b.block("StakePost", V(0.6, 3.1, 0.6), CFrame.new(0, 1.55, 0), TIMBER, WOOD)
			b.block("StakeBand", V(0.7, 0.35, 0.7), CFrame.new(0, 2.8, 0), GOLD, METAL)
			b.block("StakeSnow", V(0.75, 0.3, 0.75), CFrame.new(0, 3.3, 0), SNOW, SNOW_MAT)
		end
	end

	-- ------------------------------------------------------------ ice
	-- The frozen creek: a deep blue bed with a paler, faintly clear surface inset
	-- on it and a few hairline cracks. Decoration over the ground, nothing more.
	for k, spec in CREEK do
		local x, z, d = spec[1], spec[2], spec[3]
		disc("CreekBed", d, 0.1, CFrame.new(x, GROUND_Y + 0.02 + (k % 3) * 0.03, z), ICE_DEEP, GLACIER, effects)
		local top = disc("CreekIce", d - 1.4, 0.1, CFrame.new(x, GROUND_Y + 0.12 + (k % 3) * 0.03, z), ICE, ICE_MAT, effects)
		top.Transparency = 0.08
		top:SetAttribute("TextureSlot", "FP_Alpine_Tex_IceCracks")
		if k % 3 == 0 then
			flat(part("IceCrack", V(0.12, 0.04, d * 0.7), CFrame.new(x, GROUND_Y + 0.22, z) * CFrame.Angles(0, k * 0.8, 0), ICE_PALE, ICE_MAT, false, effects))
		end
	end
	-- Muted ice patches in the meadow: flush, 0.05 proud of the floor at most.
	for k, spec in FIELD_ICE do
		local x, z, w, d, yaw = spec[1], spec[2], spec[3], spec[4], rad(spec[5])
		local along = V(math.cos(yaw), 0, -math.sin(yaw))
		for j = -1, 1 do
			local c = V(x, 0, z) + along * (j * (w - d) / 2)
			local p = disc("FieldIce", if j == 0 then d * 1.05 else d * 0.9, 0.04, CFrame.new(c.X, GROUND_Y + 0.01 + (j + 1) * 0.01, c.Z), ICE_FIELD, GLACIER, floor)
			p:SetAttribute("TextureSlot", "FP_Alpine_Tex_IceCracks")
		end
		flat(part("IceHairline", V(0.1, 0.02, w * 0.6), CFrame.new(x, GROUND_Y + 0.045, z) * CFrame.Angles(0, yaw + math.pi / 2 + k * 0.2, 0), ICE_PALE, ICE_MAT, false, floor))
	end

	-- ------------------------------------------------------------ snow surface
	-- Footprint trails and wind lines, flush and low contrast, off the route.
	for t, trail in TRAILS do
		for s = 1, #trail - 1 do
			local a, bb = V(trail[s][1], 0, trail[s][2]), V(trail[s + 1][1], 0, trail[s + 1][2])
			local dir = (bb - a).Unit
			local side = V(dir.Z, 0, -dir.X)
			local n = math.floor((bb - a).Magnitude / 2.2)
			for k = 0, n - 1 do
				local p = a + dir * (k * 2.2 + 1) + side * (if k % 2 == 0 then 0.55 else -0.55)
				local print_ = disc("Footprint", 0.9, 0.04, CFrame.new(p.X, GROUND_Y + 0.015, p.Z), SNOW_TRACK, SNOW_MAT, floor)
				print_:SetAttribute("TextureSlot", "FP_Alpine_Decal_Tracks")
				print_:SetAttribute("Trail", t)
			end
		end
	end
	for k = 1, 10 do
		local side = if k % 2 == 0 then 1 else -1
		local x = side * (26 + (k * 13) % 48)
		local z = -70 + k * 13
		flat(part("WindLine", V(0.5, 0.03, 12 + (k % 4) * 4), CFrame.new(x, GROUND_Y + 0.008, z) * CFrame.Angles(0, 0.35 * side + k * 0.05, 0), SNOW_WIND, SNOW_MAT, false, floor))
	end
	-- the one small dark stone the concept leaves in the open field, flush
	flat(part("FieldStone", V(2.2, 0.1, 1.7), CFrame.new(33, GROUND_Y + 0.005, 20) * CFrame.Angles(0, 0.6, 0), SLATE_DARK, ROCK_MAT, false, floor))

	-- ------------------------------------------------------------ wall snow
	-- Non-colliding caps on this cell's stretch of MapBuilder's walls: the two
	-- side walls and the north divider's Frostbite half, and the lantern caps of
	-- the piers on them. The south wall faces Cinder and stays clean, as drawn.
	-- WallCap tops out at y 10 and a pier's LanternCap at 16.1; every cap here
	-- starts inside the stone it sits on and ends above it.
	do
		local runs = { 14, 9, 18, 7, 12, 20, 8, 15, 11, 17, 10, 13, 16, 6 }
		local gaps = { 3, 5, 2, 6, 4, 3, 7, 2, 5, 3 }
		for _, side in { -1, 1 } do
			local z, k = -97, (if side > 0 then 1 else 4)
			while z < 97 do
				local len = math.min(runs[(k - 1) % #runs + 1], 97 - z)
				if len > 2 then
					flat(part("WallCapSnow", V(4.3, 0.42, len), CFrame.new(side * HALF_W, 10.12, z + len / 2), SNOW, SNOW_MAT, false, wallSnow))
				end
				z += len + gaps[(k - 1) % #gaps + 1]
				k += 1
			end
		end
		for x0 = 1, 2 do
			local xs = if x0 == 1 then { 27, 138 } else { -138, -27 }
			local x, k = xs[1], x0 * 3
			while x < xs[2] do
				local len = math.min(runs[(k - 1) % #runs + 1], xs[2] - x)
				if len > 2 then
					flat(part("WallCapSnow", V(len, 0.42, 2.3), CFrame.new(x + len / 2, 10.12, HALF_D - 1.05), SNOW, SNOW_MAT, false, wallSnow))
				end
				x += len + gaps[(k - 1) % #gaps + 1]
				k += 1
			end
		end
		-- pier lantern caps: the lateral piers inside this cell and the four on
		-- the north divider
		local centreZ = frame.Position.Z
		for kPier = 0, 27 do
			local z = centreZ - CHAIN_Z0 + kPier * PIER_STEP
			if math.abs(z) < HALF_D - 1 then
				for _, side in { -1, 1 } do
					flat(part("PierCapSnow", V(3.6, 0.32, 3.6), CFrame.new(side * HALF_W, 16.2, z), SNOW, SNOW_MAT, false, wallSnow))
				end
			end
		end
		for _, x in { -100.67, -61.33, 61.33, 100.67 } do
			flat(part("PierCapSnow", V(3.6, 0.32, 3.6), CFrame.new(x, 16.2, HALF_D), SNOW, SNOW_MAT, false, wallSnow))
		end
	end

	-- ------------------------------------------------------------ flanks
	-- The strip outside both side walls is shared grass; along this cell only it
	-- is snowed over and planted with big firs, as the concept frames it.
	-- MapBuilder leaves its own treeline out of this stretch (OWN_FLANK).
	for _, side in { -1, 1 } do
		flat(part("FlankSnow", V(38.4, 0.4, HALF_D * 2), CFrame.new(side * (HALF_W + 1.6 + 19.2), -0.08, 0), SNOW_MID, SNOW_MAT, false, flanks))
	end
	for index, spec in FLANK_FIRS do
		fir(spec[1], spec[2], spec[3], spec[4], 0.12, "Landmarks/Flanks/FlankSnow", flanks, index + 40)
	end
	-- Containment over the wall where a walk level comes within a jump of its
	-- coping: behind the terrace and behind the south shelf and gorge. Invisible,
	-- and inside the wall's own width.
	proxy("WallTopProxy", V(1.8, 13, HALF_D - 18), CFrame.new(HALF_W - 0.5, 16.8, (HALF_D + 18) / 2 - 1))
	proxy("WallTopProxy", V(1.8, 13, HALF_D + 2), CFrame.new(-(HALF_W - 0.5), 16.8, (HALF_D - 2) / 2))

	sites:SetAttribute("AssetCount", siteCount)
	parent:SetAttribute("SceneryVersion", 4)
	parent:SetAttribute("ConceptId", "frostbite-peaks-v2-02-alpine-outpost-refined")
	AlpineProps.apply(parent, frame)
	PowderProps.apply(parent, frame)

	-- What the rest of the game needs to know about this shape: the open meadow
	-- and the one cluster standing in it. Given in world axes relative to the
	-- region centre, so callers need no local frame. The field stops where the
	-- side bands, the terrace and the shelves begin (|x| 80) and short of the rear
	-- rocks and the south planting (|z| 64); a 64-stud circle is also what the
	-- catching-field test measures against.
	local function world(x: number, z: number): Vector3
		return frame:VectorToWorldSpace(V(x, 0, z))
	end
	return {
		field = Vector3.new(80, 0, 64),
		keepOut = {
			-- the boulders by the north gate's west pier
			{ at = world(35, 64), radius = 12 },
			-- the route: creatures belong on the snow either side of the lane
			{ at = Vector3.zero, radius = 0, lane = LANE_HALF + 5 },
		},
	}
end

return Peaks
