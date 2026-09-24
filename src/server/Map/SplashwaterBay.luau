--!strict
-- Splashwater Bay, built to the approved "Tropical Tidepools" concept
-- (docs/art/world/2026-09-21-linear-regions/splashwater-bay/
--  splashwater-bay-v1-03-tropical-tidepools.png): a broad open beach with one
-- irregular turquoise tide pool hugging each side wall, a hollow rock grotto
-- over the west pool's head, a two-tier cascade over the east pool's, and a
-- palm-and-tropical-leaf band around the perimeter.
--
-- Local frame, as handed over by RegionScenery: local -Z is the Gusty Gardens
-- threshold (south), local +Z is the Cinder Canyon gate (north), and local +X
-- is world west -- which is the LEFT of the concept, the grotto's side.
--
-- The cell is MapBuilder's: 280 wide by 200 deep. Walls, piers, both gates and
-- the barrier belong to MapBuilder.buildChainWalls; everything inside is here.
--
-- Where the numbers come from: the concept's four gate piers are a known
-- 44 x 200 rectangle on the ground, so they fix a homography that reads every
-- flat feature straight back in studs. The concept draws a ~206-wide cell
-- against MapBuilder's 280, so measured x is scaled by 140/103 and z is taken
-- 1:1 -- the composition holds and the extra width lands where the concept
-- wants it, in open sand down the middle.
--
-- Placeholder geometry is named for the swap GardenBayProps performs: TideRock
-- becomes SB_Coastal_Rock_*, SeaShell becomes SB_Shell_Cluster. The grotto,
-- the cascade, palms and tropical planting use explicit whole-assembly sites
-- for the separate tidepools-v2 library; a missing kit keeps the blockout.
local CollectionService = game:GetService("CollectionService")
local Bay = {}
local GardenBayProps = require(script.Parent.GardenBayProps)
local TidepoolSpec = require(script.Parent.SplashwaterTidepoolAssetSpec)
local TidepoolProps = require(script.Parent.SplashwaterTidepoolProps)
local rgb = Color3.fromRGB
local V = Vector3.new

-- ---------------------------------------------------------------- layout
local HALF_W, HALF_D = 140, 100 -- the cell MapBuilder walls
local GATE_CLEAR = 24 -- planting keeps this far off the centreline at both gates
local BAND_IN, BAND_OUT = 12, 36 -- planting band, measured in from the wall

-- Each pool is a chain of flat discs: overlapping circles give the concept's
-- scalloped outline, and a disc is the one primitive whose cross-section does
-- not get clamped to a square. { x, z, radius }, read off the concept.
local WEST_POOL = {
	{ 101, -5, 13 }, { 97, 8, 21 }, { 90, 20, 21 }, { 97, 37, 23 },
	{ 93, 52, 27 }, { 88, 64, 27 }, { 82, 74, 14 },
}
local EAST_POOL = {
	{ -93, -14, 11 }, { -94, -2, 18 }, { -92, 12, 19 }, { -87, 25, 21 },
	{ -77, 40, 21 }, { -78, 52, 25 }, { -85, 64, 19 }, { -81, 73, 10 },
}
local GROTTO = CFrame.new(86, 0, 68) -- hollow rock dome over the west pool
local CASCADE = CFrame.new(-94, 0, 72) -- two-tier waterfall over the east pool

-- ---------------------------------------------------------------- palette
local SAND_PALE = rgb(250, 228, 178) -- dry sand highlights, path stones
local SAND_WET = rgb(247, 224, 180) -- the shore band around each pool
local FOAM = rgb(252, 252, 248)
local WATER = rgb(64, 214, 235) -- the concept's turquoise
local WATER_DEEP = rgb(36, 176, 214)
local WATER_PALE = rgb(148, 236, 244)
local ROCK = rgb(138, 142, 152) -- faceted grey, as the concept draws it
local ROCK_LIGHT = rgb(172, 176, 186)
local ROCK_DARK = rgb(104, 108, 120)
local ROCK_SHADOW = rgb(58, 62, 74) -- the cave mouth
local TIMBER = rgb(124, 84, 48)
local TIMBER_DARK = rgb(92, 60, 34)
local DRIFT = rgb(196, 178, 152)
local DRIFT_DARK = rgb(178, 160, 136)
local PALM_BARK = rgb(150, 108, 66)
local PALM_BARK_DARK = rgb(118, 82, 50)
local FROND = rgb(74, 158, 66)
local FROND_DARK = rgb(48, 118, 54)
local FROND_LIGHT = rgb(108, 186, 80)
local LEAF_MID = rgb(74, 146, 64)
local LEAF_DARK = rgb(52, 116, 54)
local LEAF_LIGHT = rgb(104, 178, 78)
local COCONUT = rgb(120, 88, 56)
local PETAL = rgb(253, 252, 248)
local PETAL_PINK = rgb(244, 118, 126) -- the concept's hibiscus
local POLLEN = rgb(250, 208, 76)
local SHELL = rgb(240, 216, 198)
local SHELL_PINK = rgb(238, 178, 186)
local STARFISH = rgb(236, 128, 74)

function Bay.build(parent: Model, frame: CFrame, _radius: number, makePart: (any) -> Part)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = parent
	local decor = Instance.new("Model")
	decor.Name = "Landmarks"
	decor.Parent = parent
	local shore = Instance.new("Model")
	shore.Name = "Shore"
	shore.Parent = parent

	local sites = Instance.new("Model")
	sites.Name, sites.Parent = "TidepoolSites", decor
	local siteCount = 0
	local function site(asset: string, ground: CFrame, scale: number): Model
		siteCount += 1
		local group = Instance.new("Model")
		group.Name = string.format("TidepoolSite%03d", siteCount)
		group:SetAttribute("AssetName", asset)
		group:SetAttribute("AssetLibrary", TidepoolSpec.library)
		group:SetAttribute("GroundCF", ground)
		-- Keep the measured base coordinates. Uniformly constrain the authored
		-- foliage envelope at the cell walls; never stretch its individual axes.
		local size = TidepoolSpec.tidepools[asset]
		local right, back = ground.RightVector, ground.LookVector
		local halfX = (math.abs(right.X) * size.X + math.abs(back.X) * size.Z) / 2
		local halfZ = (math.abs(right.Z) * size.X + math.abs(back.Z) * size.Z) / 2
		local fit = math.min(scale, (138 - math.abs(ground.X)) / halfX, (98 - math.abs(ground.Z)) / halfZ)
		if math.abs(ground.Z) + halfZ * fit > 65 then
			fit = math.min(fit, (math.abs(ground.X) - GATE_CLEAR) / halfX)
		end
		group:SetAttribute("UniformScale", fit)
		group:SetAttribute("AssetSize", size * fit)
		group:SetAttribute("PivotMode", "BottomCenter")
		group.Parent = sites
		local art = Instance.new("Model")
		art.Name, art.Parent = "PlaceholderArt", group
		return art
	end

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		return makePart({ name = name, size = size, cf = frame * cf, color = color,
			material = material or Enum.Material.SmoothPlastic, collide = solid == true,
			query = solid == true, parent = host or decor })
	end
	local function ball(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		local p = part(name, size, cf, color, material or Enum.Material.Grass, solid, host)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- An upright cylinder: a Roblox cylinder runs along its own X, so a standing
	-- one is a part sized (height, diameter, diameter) turned onto its end.
	local function pillar(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		local p = part(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, solid, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- A flat disc laid on the ground. Every pool surface is built from these.
	local function plate(name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local p = part(name, V(0.22, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, false, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function motion(p: Part, pivot: CFrame, speed: number, phase: number, amplitude: number)
		p.CanCollide = false
		p.CanQuery = false
		p:SetAttribute("SceneryPivot", frame * pivot)
		p:SetAttribute("SceneryOffset", (frame * pivot):ToObjectSpace(p.CFrame))
		p:SetAttribute("SceneryMode", "Sway")
		p:SetAttribute("ScenerySpeed", speed)
		p:SetAttribute("SceneryPhase", phase)
		p:SetAttribute("SceneryAmplitude", amplitude)
		CollectionService:AddTag(p, "SceneryMotion")
	end

	-- ------------------------------------------------------------ tide pools
	-- Three stacked discs per lobe. The ground's top face is y = 0.3, so the
	-- wet band, the foam lip and the water each get their own clear 0.06 and
	-- nothing z-fights. The water is the smallest disc, which leaves the foam
	-- showing as a rim instead of being buried under it.
	local function pool(lobes: { { number } }, name: string)
		for i, spec in lobes do
			local x, z, r = spec[1], spec[2], spec[3]
			local at = CFrame.new(x, 0, z)
			plate(name .. "Shore", (r + 5.5) * 2, at * CFrame.new(0, 0.40, 0), SAND_WET, Enum.Material.Sand, shore)
			plate(name .. "Foam", (r + 1.5) * 2, at * CFrame.new(0, 0.46, 0), FOAM, Enum.Material.Sand, shore)
			local top = plate(name, r * 2, at * CFrame.new(0, 0.52, 0), WATER, Enum.Material.Glass, shore)
			top.Transparency = 0.14
			top.Reflectance = 0.08
			-- the darker middle the concept paints into the wider lobes
			if r > 18 then
				local deep = plate(name .. "Deep", (r - 4.5) * 2, at * CFrame.new(0, 0.58, 0), WATER_DEEP, Enum.Material.Glass, shore)
				deep.Transparency = 0.2
				deep.Reflectance = 0.1
			end
			-- a couple of pale glints, which is all the surface detail the
			-- concept carries at this scale
			if i % 2 == 1 then
				part(name .. "Glint", V(r * 0.7, 0.03, 0.5), at * CFrame.new(-r * 0.2, 0.62, r * 0.25)
					* CFrame.Angles(0, 0.2 * i, 0), WATER_PALE, Enum.Material.SmoothPlastic, false, shore)
				part(name .. "Glint", V(r * 0.45, 0.03, 0.42), at * CFrame.new(r * 0.25, 0.62, -r * 0.3)
					* CFrame.Angles(0, -0.3 * i, 0), WATER_PALE, Enum.Material.SmoothPlastic, false, shore)
			end
		end
	end
	pool(WEST_POOL, "TidePool")
	pool(EAST_POOL, "TidePool")

	-- ----------------------------------------------------------- the boulders
	-- TideRock is the name GardenBayProps swaps for Astra's coastal rock, so
	-- every boulder in the bay upgrades in place when the kit lands. Until then
	-- one is three rotated slabs, because a single box reads as a box.
	local function boulder(at: CFrame, scale: number, host: Instance?)
		local specs = {
			{ V(6.2, 4.8, 5.6), V(0, 2.1, 0), 0.16, 0.5, 0.10 },
			{ V(4.6, 3.8, 5.0), V(1.7, 1.4, -1.0), -0.20, 1.3, 0.15 },
			{ V(3.8, 3.0, 4.2), V(-1.5, 1.3, 1.2), 0.13, 2.2, -0.18 },
		}
		local shades = { ROCK, ROCK_LIGHT, ROCK_DARK }
		for i, spec in specs do
			local r = part("TideRock", (spec[1] :: Vector3) * scale,
				at * CFrame.new((spec[2] :: Vector3) * scale)
					* CFrame.Angles(spec[3] :: number, (spec[4] :: number) + scale, spec[5] :: number),
				shades[i], Enum.Material.Rock, i == 1, host or boundary)
			r.CanQuery = false
		end
	end

	-- --------------------------------------------------------- the west grotto
	-- A hollow dome of faceted rock standing over the head of the west pool,
	-- its mouth turned back down the beach, with a short fall off the sill.
	do
		local cave = Instance.new("Model")
		cave.Name = "TidepoolGrotto"
		cave.Parent = decor
		-- The mouth faces south and a little east, back down the beach towards
		-- the player walking up it. This angle is in the dome loop's own
		-- parameterisation, where x = cos(a) and z = sin(a).
		local facing = math.rad(-96)
		-- the yaw that turns a CFrame's +Z onto that same direction
		local mouthYaw = math.atan2(math.cos(facing), math.sin(facing))
		-- Dome shell: an arch of boulders, cut down across the mouth arc so the
		-- opening reads as a cave rather than a gap between two piles.
		for i = 1, 22 do
			local a = (i / 22) * math.pi * 2
			local toMouth = math.abs(((a - facing + math.pi) % (math.pi * 2)) - math.pi)
			local isMouth = toMouth < 0.95
			local lift = math.cos(toMouth * 0.9)
			local h = if isMouth then 5.5 + (i % 3) * 0.8 else 12 + lift * 9 + (i % 4) * 1.4
			local r = 21 + (i % 3) * 2.2 - lift * 2
			local pick = i % 3
			local shade = if pick == 0 then ROCK_LIGHT else (if pick == 1 then ROCK else ROCK_DARK)
			local rock = part("GrottoRock", V(10 + (i % 3) * 2.4, h, 9.5),
				GROTTO * CFrame.new(math.cos(a) * r, h / 2 - 1.2, math.sin(a) * r * 0.70)
					* CFrame.Angles(0.06 * (i % 3 - 1), a + 0.35, 0.09 * (i % 2 - 0.5)),
				shade, Enum.Material.Rock, true, cave)
			rock.CanQuery = false
		end
		-- the crown: three overlapping caps, the tallest a little behind centre
		local caps = {
			{ V(34, 17, 24), V(0, 15.5, 2.0), ROCK },
			{ V(25, 14, 19), V(-11, 13.5, -2), ROCK_LIGHT },
			{ V(22, 12, 17), V(11, 12.5, 4), ROCK_DARK },
		}
		for i, spec in caps do
			local cap = ball("GrottoRock", spec[1] :: Vector3, GROTTO * CFrame.new(spec[2] :: Vector3)
				* CFrame.Angles(0.08, i * 1.1, 0.06), spec[3] :: Color3, Enum.Material.Rock, true, cave)
			cap.CanQuery = false
		end
		-- the dark mouth, recessed so it reads as depth and not a painted patch
		local mouthCF = GROTTO * CFrame.Angles(0, mouthYaw, 0) * CFrame.new(0, 0, 19)
		part("GrottoMouth", V(21, 15, 11), mouthCF * CFrame.new(0, 7.5, -3.0), ROCK_SHADOW, Enum.Material.Slate, false, cave)
		part("GrottoMouth", V(15, 17, 11), mouthCF * CFrame.new(0, 8.5, -7.5), ROCK_SHADOW, Enum.Material.Slate, false, cave)
		local arch = part("GrottoArch", V(22.0, 8.5, 9.5), mouthCF * CFrame.new(0, 15.0, 0.0), ROCK, Enum.Material.Rock, true, cave)
		arch.CanQuery = false
		for _, s in { -1, 1 } do
			local jamb = part("GrottoRock", V(7.0, 15, 10), mouthCF * CFrame.new(s * 12.5, 7.5, 0)
				* CFrame.Angles(0, s * 0.2, s * 0.05), ROCK_LIGHT, Enum.Material.Rock, true, cave)
			jamb.CanQuery = false
		end
		-- the fall out of the sill, landing in the pool below
		local sill = mouthCF * CFrame.new(0, 0, 1.5)
		local sheet = part("GrottoFall", V(9.0, 10.5, 1.0), sill * CFrame.new(0, 5.4, 1.2) * CFrame.Angles(-0.1, 0, 0), WATER_PALE, Enum.Material.Glass, false, cave)
		sheet.Transparency = 0.30
		sheet.Reflectance = 0.20
		sheet.Material = Enum.Material.Neon
		part("GrottoFallLip", V(10.0, 1.1, 2.4), sill * CFrame.new(0, 10.4, 1.2), WATER, Enum.Material.Glass, false, cave)
		for i = 1, 3 do
			plate("GrottoFallFoam", 8.5 + i * 3.2, sill * CFrame.new(0, 0.56 + i * 0.05, 2.5 + i * 1.5), FOAM, Enum.Material.Sand, shore)
		end
		-- boulders spilling out of the foot, onto the shore and into the water
		for _, spec in { { -30, -6, 1.25 }, { -26, -18, 1.0 }, { 20, -20, 1.15 }, { 28, -8, 0.95 }, { 30, 8, 1.2 } } do
			boulder(GROTTO * CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[1] * 0.12, 0), spec[3], cave)
		end
	end

	-- -------------------------------------------------------- the east cascade
	-- A stepped grey formation with a ledge pool halfway down, as the concept
	-- draws it: one narrow fall onto the shelf, a wider one into the tide pool.
	do
		local falls = Instance.new("Model")
		falls.Name = "CascadeRocks"
		falls.Parent = decor
		for tier = 1, 3 do
			local t = (tier - 1) / 2
			local top = 10 + tier * 9.0
			local r = 30 - tier * 6.5
			local zback = t * 7
			local ring = 14 - tier * 2
			for i = 1, ring do
				local a = (i / ring) * math.pi * 2
				-- the front of each tier is cut away, so the water has a face to fall down
				local front = math.abs(((a + math.pi / 2 + math.pi) % (math.pi * 2)) - math.pi)
				local light = (i + tier) % 3 == 0
				local shade = if light then ROCK_LIGHT else (if i % 2 == 0 then ROCK else ROCK_DARK)
				local notch = front < 0.45
				local h = if notch then top * 0.42 else top
				local slab = part("CascadeRock", V(11 - tier * 1.2, h, 10 - tier),
					CASCADE * CFrame.new(math.cos(a) * r, h / 2 - 1.5, math.sin(a) * r * 0.74 + zback)
						* CFrame.Angles(0.05 * (i % 3 - 1), a + 0.3, 0.07 * (i % 2 - 0.5)),
					shade, Enum.Material.Rock, true, falls)
				slab.CanQuery = false
			end
		end
		local head = ball("CascadeRock", V(26, 15, 21), CASCADE * CFrame.new(-2, 33, 9) * CFrame.Angles(0.07, 0.6, 0.05),
			ROCK, Enum.Material.Rock, true, falls)
		head.CanQuery = false
		-- the two drops: the upper one narrow onto the shelf, the lower one
		-- spread wide into the pool
		local spout = CASCADE * CFrame.new(0, 0, -20)
		local upper = part("CascadeFall", V(11.5, 15.0, 1.1), spout * CFrame.new(0, 25.0, -0.8) * CFrame.Angles(-0.12, 0, 0), WATER_PALE, Enum.Material.Glass, false, falls)
		upper.Transparency = 0.30
		upper.Reflectance = 0.20
		upper.Material = Enum.Material.Neon
		part("CascadeLip", V(11.5, 1.2, 3.0), spout * CFrame.new(0, 32.4, 0.4), WATER, Enum.Material.Glass, false, falls)
		local shelf = plate("CascadeShelfPool", 16, spout * CFrame.new(0, 17.1, 0.6), WATER, Enum.Material.Glass, falls)
		shelf.Transparency = 0.16
		local lower = part("CascadeFall", V(18.5, 16.0, 1.2), spout * CFrame.new(0, 8.6, -2.6) * CFrame.Angles(-0.1, 0, 0), WATER_PALE, Enum.Material.Glass, false, falls)
		lower.Transparency = 0.30
		lower.Reflectance = 0.20
		lower.Material = Enum.Material.Neon
		part("CascadeLip", V(18.0, 1.2, 2.8), spout * CFrame.new(0, 16.8, -2.0), WATER, Enum.Material.Glass, false, falls)
		for i = 1, 3 do
			plate("CascadeFoam", 12 + i * 4.0, spout * CFrame.new(0, 0.56 + i * 0.05, -3.5 - i * 1.8), FOAM, Enum.Material.Sand, shore)
		end
		for _, spec in { { -24, -18, 1.2 }, { -6, -26, 1.0 }, { 15, -22, 1.15 }, { 26, -6, 1.25 }, { 22, 12, 1.0 } } do
			boulder(CASCADE * CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[2] * 0.1, 0), spec[3], falls)
		end
	end

	-- ------------------------------------------------- boulders in the pools
	-- The concept sits a few half-submerged rocks in each pool. They are the
	-- only solid thing standing in the water.
	for _, spec in {
		{ 96, 12, 1.0 }, { 84, 30, 0.85 }, { 104, 44, 1.1 }, { 78, 56, 0.95 }, { 108, 62, 0.8 },
		{ -90, -6, 0.95 }, { -100, 16, 1.05 }, { -72, 34, 0.85 }, { -95, 44, 1.15 }, { -68, 56, 0.9 },
	} do
		boulder(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[1] * 0.09, 0), spec[3], shore)
	end

	-- the rock the concept banks between each pool's outer lip and the wall
	for _, spec in {
		{ 120, -2, 1.2 }, { 126, 22, 1.0 }, { 122, 44, 1.3 }, { 116, 66, 1.1 }, { 108, 82, 0.9 },
		{ -116, -20, 1.1 }, { -122, 8, 1.25 }, { -118, 34, 1.0 }, { -112, 58, 1.2 }, { -104, 80, 0.95 },
	} do
		boulder(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[2] * 0.11, 0), spec[3], shore)
	end

	-- ---------------------------------------------------------------- planting
	local function palm(at: CFrame, scale: number, lean: number, seed: number)
		local tree = Instance.new("Model")
		tree.Name = "Palm"
		tree.Parent = site(if scale < 0.83 then "SB_Palm_Small" else (if lean >= 0.3 then "SB_Palm_Bent" else "SB_Palm_Tall"),
			at * CFrame.Angles(0, seed * 0.9, 0), scale)
		-- Curved segmented trunk: each drum leans a little further than the last,
		-- which is what gives the concept's palms their arc.
		local cursor = at * CFrame.Angles(0, seed * 0.9, 0)
		local segments = 7
		for i = 1, segments do
			local t = (i - 1) / (segments - 1)
			local d = (4.6 - t * 2.1) * scale
			local h = 4.3 * scale
			cursor = cursor * CFrame.Angles(lean / segments, 0, 0)
			local bark = if i % 2 == 0 then PALM_BARK else PALM_BARK_DARK
			local drum = pillar("PalmTrunk", d, h + 0.6, cursor * CFrame.new(0, h / 2, 0), bark, Enum.Material.Wood, i <= 2, tree)
			drum.CanQuery = false
			cursor = cursor * CFrame.new(0, h, 0)
		end
		-- the crown: fronds radiating and drooping, plus a few coconuts
		local crown = cursor
		ball("PalmCrownBoss", V(4.4, 3.6, 4.4) * scale, crown, PALM_BARK_DARK, Enum.Material.Wood, false, tree)
		-- Each frond is three tapering blades hinged end to end: up off the
		-- crown, out, then down. One long slab per frond read as a green plank
		-- sticking out sideways, which is the opposite of the concept's arc.
		local widths = { 2.2, 2.5, 1.6 }
		local lengths = { 5.4, 5.6, 4.8 }
		local bends = { -0.36, 0.54, 0.88 }
		for i = 1, 9 do
			local a = (i / 9) * math.pi * 2 + seed
			local pick = i % 3
			local shade = if pick == 0 then FROND_DARK else (if pick == 1 then FROND else FROND_LIGHT)
			-- a little roll per frond, so the crown is not nine coplanar blades
			local stretch = 0.86 + (i % 4) * 0.12
			local cursor = crown * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, (i % 3 - 1) * 0.22)
			for s = 1, 3 do
				cursor = cursor * CFrame.Angles(bends[s] + (i % 3) * 0.05, 0, 0)
				local len = lengths[s] * scale * stretch
				local blade = part("PalmFrond", V(widths[s] * scale, 0.42 * scale, len),
					cursor * CFrame.new(0, 0, len / 2), shade, Enum.Material.Grass, false, tree)
				motion(blade, crown, 0.85, seed + i * 0.6, 0.05)
				cursor = cursor * CFrame.new(0, 0, len)
			end
		end
		for i = 1, 3 do
			local a = seed + i * 2.1
			ball("PalmCoconut", V(2.1, 2.1, 2.1) * scale,
				crown * CFrame.new(math.cos(a) * 2.6 * scale, -1.8 * scale, math.sin(a) * 2.6 * scale),
				COCONUT, Enum.Material.Wood, false, tree)
		end
	end
	-- The broad spiky leaf clumps the concept banks against the rocks.
	local function tropicalLeaf(at: CFrame, scale: number, seed: number)
		local art = site(if scale >= 1.15 then "SB_Tropical_Leaf_Broad" else "SB_Tropical_Leaf_Low", at, scale)
		for i = 1, 7 do
			local a = (i / 7) * math.pi * 2 + seed
			local rise = 0.62 + (i % 3) * 0.18
			local pick = i % 3
			local shade = if pick == 0 then LEAF_DARK else (if pick == 1 then LEAF_MID else LEAF_LIGHT)
			part("TropicalLeaf", V(3.2 * scale, 0.42 * scale, 8.4 * scale),
				at * CFrame.Angles(0, a, 0) * CFrame.Angles(-rise, 0, 0) * CFrame.new(0, 0.6 * scale, 4.0 * scale),
				shade, Enum.Material.Grass, false, art)
		end
		ball("TropicalLeafBase", V(3.6, 2.2, 3.6) * scale, at * CFrame.new(0, 0.9 * scale, 0), LEAF_DARK,
			Enum.Material.Grass, false, art)
	end
	local function shrub(at: CFrame, scale: number, tone: number)
		local d = 6.8 * scale
		local leaf = if tone % 2 == 0 then LEAF_MID else LEAF_LIGHT
		ball("BayShrub", V(d, d * 0.84, d * 0.96), at * CFrame.new(0, d * 0.36, 0), leaf, Enum.Material.Grass, false, boundary)
		ball("BayShrub", V(d * 0.68, d * 0.62, d * 0.68), at * CFrame.new(d * 0.44, d * 0.3, d * 0.22), LEAF_DARK,
			Enum.Material.Grass, false, boundary)
		ball("BayShrub", V(d * 0.56, d * 0.52, d * 0.56), at * CFrame.new(-d * 0.36, d * 0.26, -d * 0.2), LEAF_MID,
			Enum.Material.Grass, false, boundary)
	end
	-- White daisies and the concept's pink hibiscus, on one low green pad.
	local function flowers(at: CFrame, seed: number, pink: boolean)
		local art = if pink then site("SB_Hibiscus_Clump", at, 1) else boundary
		ball("FlowerBed", V(4.4, 1.9, 4.2), at * CFrame.new(0, 0.7, 0), LEAF_MID, Enum.Material.Grass, false, art)
		for i = 1, 6 do
			local a = seed + i * 1.047
			local r = 0.9 + (i % 3) * 0.7
			local p = at * CFrame.new(math.cos(a) * r, 1.7 + (i % 3) * 0.4, math.sin(a) * r)
			part("FlowerStalk", V(0.18, 1.5, 0.18), p * CFrame.new(0, -0.7, 0), LEAF_DARK, Enum.Material.Grass, false, art)
			local isPink = pink and (seed + i) % 2 == 0
			local petal = if isPink then PETAL_PINK else PETAL
			local head = if isPink then "HibiscusBloom" else "FlowerHead"
			local width = if isPink then 2.8 else 2.1
			plate(head, width, p, petal, Enum.Material.SmoothPlastic, art)
			plate("FlowerEye", 0.9, p * CFrame.new(0, 0.14, 0), POLLEN, Enum.Material.SmoothPlastic, art)
		end
	end

	-- Two ranks around all four sides: palms and boulders against the wall, low
	-- tropical planting in front of them. Both gate throats stay clear, and the
	-- inset is jittered so the band reads as planting rather than a hedge row.
	local function planted(x: number, z: number): boolean
		local nearGate = math.abs(z) > HALF_D - BAND_OUT - 6 and math.abs(x) < GATE_CLEAR
		return not nearGate
	end
	local edges = {
		{ axis = "z", sign = 1, span = HALF_W, steps = 19, thin = true },
		{ axis = "z", sign = -1, span = HALF_W, steps = 19, thin = true },
		{ axis = "x", sign = 1, span = HALF_D, steps = 14, thin = false },
		{ axis = "x", sign = -1, span = HALF_D, steps = 14, thin = false },
	}
	local seq = 0
	for _, edge in edges do
		for i = 0, edge.steps do
			local t = (i / edge.steps) * 2 - 1
			local along = t * (edge.span - BAND_IN - 8) + ((i % 3) - 1) * 3.4
			seq += 1
			for rank = 1, 3 do
				local jitter = ((seq * 7) % 5) - 2
				local outer = BAND_IN + (i % 2) * 4 + jitter
				local middle = BAND_OUT - 8 - (i % 3) * 4 + jitter
				local inset = if rank == 1 then outer else (if rank == 2 then middle else 10 + (i % 3) * 2.5)
				local x, z
				if edge.axis == "z" then
					x, z = along, edge.sign * (HALF_D - inset)
				else
					x, z = edge.sign * (HALF_W - inset), along
				end
				-- The grotto and the cascade own the north corners outright; the
				-- band would otherwise grow straight through them.
				local inGrotto = math.abs(x - 86) < 40 and math.abs(z - 68) < 30
				local inCascade = math.abs(x + 94) < 40 and math.abs(z - 72) < 32
				local skip = (edge.thin and rank == 1 and i % 3 == 1) or inGrotto or (inCascade and rank ~= 3)
				if planted(x, z) and not skip then
					local at = CFrame.new(x, 0, z) * CFrame.Angles(0, seq * 0.9 + rank, 0)
					local pick = (seq + rank * 3) % 7
					if rank == 1 then
						if pick == 0 or pick == 4 then
							boulder(at, 1.0 + (seq % 3) * 0.25)
						elseif pick == 3 or pick == 6 then
							-- blades reach ~8.4 x scale, so this rank stays under the wall line
							tropicalLeaf(at, 1.02 + (seq % 3) * 0.14, seq * 1.1)
						else
							palm(at, 0.76 + (seq % 4) * 0.06, 0.26 + (seq % 3) * 0.08, seq * 1.3)
						end
					elseif rank == 3 then
						-- the low run banked against the wall itself
						if pick == 0 or pick == 3 then
							boulder(at, 0.62 + (seq % 3) * 0.14)
						elseif pick == 1 or pick == 4 then
							flowers(at, seq * 2.3, seq % 2 == 1)
						else
							shrub(at, 0.66 + (seq % 4) * 0.12, seq + 1)
						end
					elseif pick == 1 or pick == 5 then
						tropicalLeaf(at, 0.95 + (seq % 3) * 0.2, seq * 0.8)
					elseif pick == 2 or pick == 6 then
						flowers(at, seq * 1.7, seq % 2 == 0)
					else
						shrub(at, 0.9 + (seq % 3) * 0.2, seq)
					end
				end
			end
		end
	end

	-- The concept banks low planting tight against all four gate piers, which
	-- the band's gate clearance leaves bare.
	for _, z in { HALF_D - 13, -(HALF_D - 13) } do
		for _, x in { -36, -29, 29, 36 } do
			local at = CFrame.new(x, 0, z + (x % 5) * 0.6) * CFrame.Angles(0, x * 0.3, 0)
			if math.abs(x) > 32 then
				shrub(at, 1.05, math.floor(x))
			else
				flowers(at, x * 0.9 + z * 0.02, true)
			end
		end
	end

	-- The two palms the concept stands either side of the south threshold, and
	-- one on each side wall at the midpoint, which is where its silhouettes read.
	for _, spec in { { 82, -92, 1.00, 0.30 }, { -74, -92, 0.96, 0.26 }, { -123, 36, 1.04, 0.22 }, { 126, -34, 0.98, 0.28 } } do
		palm(CFrame.new(spec[1], 0, spec[2]), spec[3], spec[4], spec[1] * 0.3)
	end
	-- the south corners get one more palm, a leaf clump and a boulder each,
	-- which is where the concept thickens its border
	for _, c in { V(-1, 0, -1), V(1, 0, -1) } do
		palm(CFrame.new(c.X * (HALF_W - 26), 0, c.Z * (HALF_D - 24)), 0.92, 0.3, c.X * 2)
		tropicalLeaf(CFrame.new(c.X * (HALF_W - 42), 0, c.Z * (HALF_D - 20)), 1.2, c.X)
		boulder(CFrame.new(c.X * (HALF_W - 16), 0, c.Z * (HALF_D - 40)), 1.35)
	end

	-- ---------------------------------------------------- the open beach itself
	-- Sparse only: the dry sand is the capture field and stays walkable. Shells,
	-- starfish and pebbles, banked towards the pool margins the way the concept
	-- banks them, and never in a gate throat.
	local function seaShell(at: CFrame, pink: boolean)
		local tone = if pink then SHELL_PINK else SHELL
		local body = ball("SeaShell", V(2.0, 0.7, 1.5), at * CFrame.new(0, 0.5, 0), tone,
			Enum.Material.SmoothPlastic, false, shore)
		body.CanQuery = false
		for j = -1, 1 do
			part("ShellRidge", V(0.09, 0.12, 1.1), at * CFrame.new(j * 0.36, 0.86, 0) * CFrame.Angles(0, j * 0.32, 0),
				FOAM, Enum.Material.SmoothPlastic, false, shore)
		end
	end
	local function starfish(at: CFrame)
		-- One hub part per starfish, which is what GardenBayProps swaps for
		-- SB_Starfish; the five arms are dressing and retire with it.
		-- a plain block, so the mesh swap can reuse its CFrame unrotated
		local hub = part("Starfish", V(1.4, 0.2, 1.4), at * CFrame.new(0, 0.44, 0), STARFISH,
			Enum.Material.SmoothPlastic, false, shore)
		hub.CanQuery = false
		for j = 0, 4 do
			part("StarfishArm", V(0.5, 0.22, 1.5), at * CFrame.Angles(0, j * math.pi * 2 / 5, 0) * CFrame.new(0, 0.45, 0.55),
				STARFISH, Enum.Material.SmoothPlastic, false, shore)
		end
	end
	for _, spec in { { 62, 6, 1 }, { 58, 40, 0 }, { 70, -24, 0 }, { -50, 22, 1 }, { -58, -18, 0 }, { -46, 48, 1 }, { 104, -30, 0 }, { -104, -34, 1 } } do
		seaShell(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[1] * 0.4, 0), spec[3] == 1)
	end
	for _, spec in { { 55, 24 }, { -56, 6 }, { -62, 44 }, { 74, -40 }, { -98, 60 } } do
		starfish(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[1] * 0.3, 0))
	end
	-- loose pebbles across the open sand, the concept's only interior detail
	for i = 1, 22 do
		local x = ((i * 71) % 181 - 90) * 0.62
		local z = ((i * 43) % 137 - 68) * 1.02
		local clearOfWater = (x < 52 and x > -44) or math.abs(z) > 72
		if math.abs(z) < HALF_D - 16 and clearOfWater then
			local d = 1.1 + (i % 3) * 0.55
			local tone = if i % 3 == 0 then ROCK_LIGHT else ROCK
			local pebble = ball("BeachPebble", V(d * 1.5, d * 0.7, d * 1.2), CFrame.new(x, 0.5, z) * CFrame.Angles(0, i * 1.1, 0),
				tone, Enum.Material.Rock, false, shore)
			pebble.CanQuery = false
		end
	end
	-- a few pale flat stones on the route, the same restrained dressing Gusty gets
	for i, spec in { { -3.0, -68 }, { 4.2, -40 }, { -2.6, -8 }, { 3.4, 26 }, { -3.6, 58 } } do
		plate("PathStone", 4.6 + (i % 3) * 0.9, CFrame.new(spec[1], 0.5, spec[2]), SAND_PALE, Enum.Material.Sand, shore)
	end

	-- The rustic props the concept tucks against the wall: barrels either side
	-- and by the north gate, and a pair of driftwood logs on the shore.
	local function barrel(at: CFrame)
		pillar("BayBarrel", 4.8, 4.6, at * CFrame.new(0, 2.3, 0), TIMBER, Enum.Material.WoodPlanks, true, decor)
		pillar("BayBarrelBand", 5.1, 0.55, at * CFrame.new(0, 1.2, 0), TIMBER_DARK, Enum.Material.Wood, false, decor)
		pillar("BayBarrelBand", 5.1, 0.55, at * CFrame.new(0, 3.5, 0), TIMBER_DARK, Enum.Material.Wood, false, decor)
		pillar("BayBarrelTop", 4.4, 0.4, at * CFrame.new(0, 4.7, 0), rgb(154, 114, 70), Enum.Material.WoodPlanks, false, decor)
	end
	for _, spec in { { 124, -6, 0.4 }, { 118, -14, -0.2 }, { -122, -4, 0.5 }, { -34, 82, 0.3 }, { -42, 80, -0.4 } } do
		barrel(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[3], 0))
	end
	for _, spec in { { 70, -52, 0.7 }, { -66, 66, -0.5 } } do
		local log = CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[3], 0)
		local trunk = pillar("Driftwood", 3.0, 9.5, log * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
			DRIFT, Enum.Material.Wood, true, shore)
		trunk.CanQuery = false
		pillar("DriftwoodBranch", 1.8, 4.0, log * CFrame.new(2.4, 1.3, 1.8) * CFrame.Angles(0, math.pi / 3, 0),
			DRIFT_DARK, Enum.Material.Wood, false, shore)
	end

	-- Only the primitive hero silhouette belongs to these sites. Water and
	-- foam form a separate fallback group; TideRock skirts remain old-kit art.
	local function hero(asset: string, ground: CFrame, host: Model, names: { [string]: boolean }, effects: { [string]: boolean })
		local art = site(asset, ground, 1)
		local fallback = Instance.new("Model")
		fallback.Name, fallback.Parent = "FallbackEffects", art.Parent
		for _, obj in host:GetChildren() do
			if names[obj.Name] then obj.Parent = art end
		end
		for _, obj in parent:GetDescendants() do
			if effects[obj.Name] and obj:IsA("BasePart") then obj.Parent = fallback end
		end
	end
	hero("SB_Tidepool_Grotto", GROTTO, decor.TidepoolGrotto,
		{ GrottoRock = true, GrottoArch = true, GrottoMouth = true },
		{ GrottoFall = true, GrottoFallLip = true, GrottoFallFoam = true })
	hero("SB_Cascade_Rocks", CASCADE, decor.CascadeRocks,
		{ CascadeRock = true },
		{ CascadeFall = true, CascadeLip = true, CascadeShelfPool = true, CascadeFoam = true })
	sites:SetAttribute("AssetCount", siteCount)
	parent:SetAttribute("SceneryVersion", 5)
	GardenBayProps.apply(parent, frame, "Water")
	TidepoolProps.apply(parent, frame)

	-- What the rest of the game needs to know about this shape: the open dry
	-- sand rectangle, and the two pools and two rock landmarks standing in it.
	-- Given in world axes relative to the region centre, so callers need no
	-- local frame.
	local function world(x: number, z: number): Vector3
		return frame:VectorToWorldSpace(V(x, 0, z))
	end
	return {
		field = Vector3.new(HALF_W - BAND_OUT - 4, 0, HALF_D - BAND_OUT - 2),
		keepOut = {
			-- the two tide pools, a pair of circles each: creatures belong on
			-- the dry sand, which is most of the cell
			{ at = world(95, 16), radius = 32 },
			{ at = world(89, 58), radius = 31 },
			{ at = world(-92, 2), radius = 28 },
			{ at = world(-80, 52), radius = 31 },
			-- the two landmarks, sized past their boulder skirts
			{ at = world(86, 68), radius = 38 },
			{ at = world(-94, 72), radius = 36 },
		},
	}
end

return Bay
