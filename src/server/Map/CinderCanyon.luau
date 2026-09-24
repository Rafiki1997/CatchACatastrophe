--!strict
-- Cinder Canyon, built to the approved "Cinder Quarry" concept
-- (docs/art/regions/2026-09-22-cinder-canyon/cinder-canyon-v1-03-cinder-quarry.png,
-- contract in CINDER-QUARRY-CLAUDE-HANDOFF.md beside it): a flat warm orange
-- quarry floor, a recessed timber mine entrance in the rear-left rock, a short
-- rail with one ore cart running south out of it, a terraced quarry face at the
-- rear-right carrying a timber hoist, crates, amber mineral pockets and a narrow
-- lava cascade, and a band of layered red sandstone and cacti round the border.
-- The centre and the whole foreground stay open.
--
-- Local frame, as handed over by RegionScenery: local +X is world west, which
-- is the LEFT of the concept and the mine's side; local -Z is the Splashwater
-- threshold (south, near edge); local +Z is the Frostbite gate (north, far
-- edge). The cell is MapBuilder's 280 wide by 200 deep; the walls, both gate
-- piers, the barrier and the banner all belong to MapBuilder.buildChainWalls.
--
-- Where the numbers come from: the concept's four gate piers are engine
-- geometry at known coordinates, so they fit the concept's near-orthographic
-- projection (pitch 30.9 degrees, 6.59 px per stud) and read every flat feature
-- back in studs. That fit puts the concept's own side walls at x = +-103
-- against MapBuilder's +-140 -- the same discrepancy Splashwater Bay found --
-- so border features are measured in from the wall rather than scaled from the
-- centre, and the extra width lands where the concept wants it, in open floor
-- down the middle.
--
-- None of the geometry here is the twelve custom meshes. Every one of them is
-- an explicit PropSite under Landmarks/PropSites carrying AssetName, AssetSize
-- and a bottom-centre GroundCF, with stand-in geometry in its PlaceholderArt
-- child and nothing else. Placeholder art is authored in the asset's own local
-- space, so it lands correctly whatever the site's position and yaw and can be
-- measured against the delivered bounds. CinderQuarryProps swaps
-- art for mesh when the native library is imported. Walking containment is separate invisible
-- proxies in Boundary, and the lava, the minerals and their lights are effect
-- geometry in Landmarks/Effects, so none of it sits inside an asset's bounds.
local CollectionService = game:GetService("CollectionService")
local Quarry = {}
local AssetSpec = require(script.Parent.CinderQuarryAssetSpec)
local QuarryProps = require(script.Parent.CinderQuarryProps)
local rgb = Color3.fromRGB
local V = Vector3.new

-- ---------------------------------------------------------------- layout
local HALF_W, HALF_D = 140, 100 -- the cell MapBuilder walls
local GROUND_Y = 0.30 -- the region floor's top face, which nothing raises
local LANE_HALF = 12 -- the 24-wide clear centre lane the handoff fixes
local BAND_DEEP = 44 -- how far in from the wall the border band may reach

-- The two landmarks, bottom-centre, exactly as the handoff's site table fixes
-- them. Everything hung off them is derived from a socket, never re-measured.
local MINE_AT = CFrame.new(87, GROUND_Y, 66)
local TERRACE_AT = CFrame.new(-88, GROUND_Y, 65)
-- Final delivered sockets are mirrored with the terrace geometry onto local -X.
local MINE_DOOR = AssetSpec.sockets.CC_Quarry_Mine.DoorBase
local MINE_LANTERN = AssetSpec.sockets.CC_Quarry_Mine.Lantern
local MINE_JAMB_Z = MINE_DOOR.Position.Z
local MINE_DOOR_W, MINE_DOOR_H = 18, 21
local TERRACE_SOCKETS = AssetSpec.sockets.CC_Quarry_Terrace
local HOIST_BASE = TERRACE_SOCKETS.HoistBase
local LAVA_X = TERRACE_SOCKETS.LavaUpperLip.Position.X
local LAVA_FOOT = TERRACE_SOCKETS.LavaFoot

-- ---------------------------------------------------------------- palette
-- Sampled off the concept and pulled down a little for Roblox's outdoor light,
-- which lifts a flat colour by roughly a tenth.
local SAND_PALE = rgb(250, 150, 108) -- sunlit caps
local SAND_TOP = rgb(238, 118, 76) -- upper faces
local SAND = rgb(222, 96, 56) -- the mass of the rock
local SAND_DEEP = rgb(186, 74, 42) -- shaded faces
local SAND_SEAM = rgb(150, 54, 34) -- the dark horizontal seams
local SAND_DUST = rgb(240, 140, 92) -- floor detail, barely off the floor itself
local FLOOR_CRACK = rgb(198, 98, 62) -- shallow cracks, matte and low contrast
local CHARCOAL = rgb(78, 72, 78) -- the rock beside the lava
local CHARCOAL_LIGHT = rgb(106, 99, 106)
local CHARCOAL_DARK = rgb(52, 48, 54)
local LAVA = rgb(248, 112, 16)
local LAVA_HOT = rgb(255, 186, 64)
local LAVA_CRUST = rgb(176, 58, 20)
local MINERAL = rgb(255, 170, 40)
local MINERAL_CORE = rgb(255, 226, 150)
local TIMBER = rgb(178, 120, 74)
local TIMBER_DARK = rgb(132, 86, 50)
local TIMBER_PALE = rgb(206, 152, 102)
local IRON = rgb(58, 54, 58)
local IRON_LIGHT = rgb(88, 84, 88)
local ORE = rgb(255, 162, 44)
local CART_BODY = rgb(168, 84, 48)
local TUNNEL = rgb(38, 26, 26)
local CACTUS = rgb(78, 138, 68)
local CACTUS_DARK = rgb(52, 104, 52)
local CACTUS_LIGHT = rgb(110, 166, 82)
local AGAVE = rgb(104, 158, 124)
local AGAVE_DARK = rgb(70, 124, 100)
local BLOOM_ORANGE = rgb(246, 138, 48)
local BLOOM_YELLOW = rgb(252, 204, 76)
local PETAL = rgb(252, 250, 244)
local LANTERN_GLASS = rgb(255, 224, 152)

local SANDSTONE = Enum.Material.Sandstone
local ROCK_MAT = Enum.Material.Rock
local SLATE = Enum.Material.Slate
local BASALT_MAT = Enum.Material.Basalt
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local PLANK = Enum.Material.WoodPlanks
local GRASS = Enum.Material.Grass
local SMOOTH = Enum.Material.SmoothPlastic

-- Where the border rock stands. { x, z, kind, yaw, stackYaw? }, kind "L" for
-- CC_Quarry_Mesa_Large (27 x 22 x 21) and "S" for CC_Quarry_Mesa_Low
-- (22 x 11 x 17). The two side runs overlap along z so the band reads as one
-- continuous mass rather than a row of boulders, as the concept draws it, and
-- a front rank of low shelves steps down into the floor. An entry with a
-- fifth number carries a second, lower rock stacked on its top: the concept's
-- border rises well above the wall in places, and the kit's two rocks are
-- meant to be reused and piled rather than resized. Measured off the concept's
-- rock silhouette, which stands about 100 studs out from the centre.
local MESAS = {
	-- left (+X) band, south to north; the mine takes the corner past z = 44
	{ 126, -92, "S", 0.34 }, { 118, -88, "L", -0.20, 0.5 },
	{ 124, -70, "L", 0.16, -0.4 }, { 112, -80, "S", 0.52 },
	{ 127, -52, "S", -0.36 }, { 121, -50, "L", 0.28, 0.3 },
	{ 124, -32, "L", -0.12, -0.6 },
	{ 126, -14, "S", 0.22 }, { 120, -12, "L", -0.30, 0.2 },
	{ 124, 6, "L", 0.38, -0.3 },
	{ 127, 24, "S", -0.18 }, { 117, 26, "L", 0.24, 0.6 },
	{ 128, 44, "L", -0.26, -0.2 }, { 127, 64, "S", 0.30 },
	-- right (-X) band; the terrace takes the corner past z = 36
	{ -126, -92, "S", -0.34 }, { -118, -88, "L", 0.20, -0.5 },
	{ -124, -70, "L", -0.16, 0.4 }, { -112, -80, "S", -0.52 },
	{ -127, -52, "S", 0.36 }, { -121, -50, "L", -0.28, -0.3 },
	-- no stacked rock north of here on this side: a 33-stud pile anywhere
	-- inside about 55 studs of the lava pocket stands in the sightline to it,
	-- and the terrace is the tall mass the concept puts on this side anyway
	{ -124, -32, "L", 0.12 },
	{ -126, -14, "S", -0.22 }, { -120, -12, "L", 0.30 },
	{ -128, -30, "L", -0.38 }, { -113, 4, "S", 0.48 },
	-- The right band stops low and early. Past this the terrace's own charcoal
	-- rock and the lava pocket carry the edge, and at this camera anything
	-- taller than about eleven studs within twenty of the pool stands in front
	-- of the cascade and hides the one thing that makes the quarry read as hot.
	{ -127, -2, "S", 0.18 }, { -118, 4, "S", -0.24 },
	-- north wall, between each landmark and the gate throat
	{ 58, 92, "L", 0.42, 0.2 }, { 40, 94, "S", -0.28 },
	{ -40, 94, "S", 0.30 }, { -58, 92, "L", -0.44, -0.2 },
	-- south wall flanks, kept low so the foreground stays open
	-- the foreground fringe is carried by planting rather than more rock: a
	-- cactus costs no floor, and the concept's south edge is mostly cactus,
	-- agave and flowers with a rock here and there
	{ 44, -94, "S", -0.22 }, { 70, -95, "S", 0.34 },
	{ -44, -94, "S", 0.22 }, { -72, -95, "S", -0.34 },
	{ 96, -96, "L", 0.18, 0.5 }, { -96, -96, "L", -0.18, -0.5 },
}

-- Cacti, agave and flower patches, every one of them in the band or at a
-- landmark's foot. { x, z, kind, yaw }: "T" tall cactus, "R" round cactus,
-- "A" agave, "F" flower patch.
local PLANTS = {
	{ 104, -96, "T", 0.2 }, { 96, -86, "F", 0.6 }, { 112, -80, "R", -0.3 },
	{ 100, -64, "T", -0.4 }, { 92, -58, "A", 0.5 }, { 106, -44, "F", 0.1 },
	{ 98, -38, "T", 0.3 }, { 112, -24, "R", 0.8 }, { 94, -20, "F", -0.5 },
	{ 100, -6, "T", -0.2 }, { 96, 10, "A", 0.4 }, { 110, 16, "R", -0.6 },
	{ 98, 30, "T", 0.5 }, { 104, 36, "F", 0.2 }, { 116, 54, "T", -0.3 },
	{ 118, 72, "R", 0.7 }, { 112, 84, "F", -0.1 },
	{ -104, -96, "T", -0.2 }, { -96, -86, "F", -0.6 }, { -112, -80, "R", 0.3 },
	{ -100, -64, "T", 0.4 }, { -92, -58, "A", -0.5 }, { -106, -44, "F", -0.1 },
	{ -98, -38, "T", -0.3 }, { -112, -24, "R", -0.8 }, { -94, -20, "F", 0.5 },
	{ -100, -6, "T", 0.2 }, { -96, 10, "A", -0.4 }, { -110, 16, "R", 0.6 },
	{ -98, 30, "T", -0.5 }, { -104, 40, "A", 0.3 }, { -90, 42, "T", 0.6 },
	{ -78, 40, "R", -0.4 }, { -66, 42, "F", 0.2 },
	-- either side of both gate throats, as the concept plants them
	{ 44, 90, "T", -0.5 }, { 38, 86, "F", 0.3 }, { -42, 90, "T", 0.5 },
	{ -38, 86, "R", -0.3 }, { 40, -92, "R", 0.4 }, { -40, -92, "F", -0.4 },
	-- the mine forecourt
	{ 72, 34, "T", 0.6 }, { 66, 28, "F", -0.2 }, { 104, 32, "R", 0.3 },
	-- a second rank at the foot of each band, where the concept crowds them
	{ 96, -78, "F", 0.3 }, { 98, -52, "R", -0.6 }, { 98, -30, "T", 0.4 },
	{ 96, -4, "F", -0.2 }, { 98, 22, "R", 0.7 }, { 100, 46, "F", -0.3 },
	{ 108, 64, "T", 0.2 }, { 110, 78, "R", -0.5 },
	{ -96, -78, "F", -0.3 }, { -98, -52, "R", 0.6 }, { -98, -30, "T", -0.4 },
	{ -96, -4, "F", 0.2 }, { -98, 22, "R", -0.7 }, { -100, 30, "F", 0.3 },
	-- and along the south wall either side of the threshold
	{ 52, -90, "T", 0.4 }, { 64, -88, "F", -0.2 }, { 78, -90, "R", 0.6 },
	{ 88, -86, "T", -0.5 }, { 30, -88, "F", 0.3 },
	{ -52, -90, "T", -0.4 }, { -64, -88, "F", 0.2 }, { -78, -90, "R", -0.6 },
	{ -88, -86, "T", 0.5 }, { -30, -88, "F", -0.3 },
	{ 62, 88, "R", 0.4 }, { 70, 86, "F", -0.4 },
	{ -62, 88, "R", -0.4 }, { -70, 86, "F", 0.4 },
}

-- Crates sit on dry forecourts or another crate. The delivered y=36 shelf
-- carries the hoist; read-only rays against the .blend found no free 6x6 flat
-- footprint beside its fixed envelope, so the former y=25 crates move here.
-- { x, y, z, yaw, support }
local CRATES = {
	{ 70, GROUND_Y, 24, 0.3, "Ground" },
	{ 76, GROUND_Y, 22, -0.4, "Ground" },
	{ 70, GROUND_Y + 6, 24, 0.3, "Crate01" },
	{ -78, GROUND_Y, 26, 0.2, "Ground" },
	{ -69, GROUND_Y, 27, -0.3, "Ground" },
	{ -78, GROUND_Y + 6, 26, 0.2, "Crate04" },
	{ -101, GROUND_Y, 22, 0.4, "Ground" },
	{ 52, GROUND_Y, 88, -0.2, "Ground" },
}

function Quarry.build(parent: Model, frame: CFrame, _radius: number, makePart: (any) -> Part)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = parent
	local decor = Instance.new("Model")
	decor.Name = "Landmarks"
	decor.Parent = parent
	local sites = Instance.new("Model")
	sites.Name = "PropSites"
	sites.Parent = decor
	sites:SetAttribute("AssetKit", "assets/cinder-canyon/quarry-v2")
	sites:SetAttribute("AssetOrigin", "bottom-centre")
	local effects = Instance.new("Model")
	effects.Name = "Effects"
	effects.Parent = decor
	local floor = Instance.new("Model")
	floor.Name = "FloorDetail"
	floor.Parent = decor

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		return makePart({ name = name, size = size, cf = frame * cf, color = color,
			material = material or SANDSTONE, collide = solid == true,
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
	-- Walking containment, and only that: an invisible box in Boundary under a
	-- landmark, so the visible art can stay CanCollide/CanTouch/CanQuery off and
	-- be replaced wholesale without touching what keeps a player out of a rock.
	local function proxy(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, SAND, SANDSTONE, true, boundary)
		p.Transparency = 1
		p.CastShadow = false
		p:SetAttribute("CollisionProxy", true)
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

	-- ------------------------------------------------------------ asset sites
	-- One record per intended mesh. `GroundCF` is the asset's bottom-centre
	-- frame in this module's local coordinates; CinderQuarryProps turns it into
	-- a MeshPart CFrame with ground * CFrame.new(0, size.Y / 2, 0), because a
	-- native MeshPart's CFrame is its bounds centre.
	--
	-- `place` hands back a brush that draws into the site's own local space, so
	-- every stand-in is authored the way the mesh will be authored -- origin on
	-- the ground at the asset's centre, facing local -Z -- and the verifier can
	-- hold each one against the bounds in the contract.
	local counts: { [string]: number } = {}
	local siteCount = 0
	type Brush = {
		block: (string, Vector3, CFrame, Color3, Enum.Material?) -> Part,
		post: (string, number, number, CFrame, Color3, Enum.Material?) -> Part,
		roll: (string, number, number, CFrame, Color3, Enum.Material?) -> Part,
		blob: (string, Vector3, CFrame, Color3, Enum.Material?) -> Part,
	}
	local function place(prefix: string, asset: string, ground: CFrame, role: string, support: string, socket: string?): Brush
		local size = AssetSpec.quarry[asset]
		assert(size, "no fixed bounds for " .. asset)
		local n = (counts[prefix] or 0) + 1
		counts[prefix] = n
		siteCount += 1
		local site = Instance.new("Model")
		site.Name = prefix .. (if n < 10 then "0" .. n else tostring(n))
		site:SetAttribute("AssetName", asset)
		site:SetAttribute("AssetSize", size)
		site:SetAttribute("AssetLibrary", AssetSpec.library.CC_Quarry)
		site:SetAttribute("GroundCF", ground)
		site:SetAttribute("PivotMode", "BottomCenter")
		site:SetAttribute("SizeLock", "Fixed")
		site:SetAttribute("CollisionRole", "none")
		site:SetAttribute("PlacementRole", role)
		site:SetAttribute("SupportPath", support)
		if socket then
			-- sourced from the delivered manifest, independently checked headlessly
			site:SetAttribute("SocketName", socket)
			site:SetAttribute("SocketManifest", "assets/cinder-canyon/quarry-v2/manifest.json")
		end
		site.Parent = sites
		local art = Instance.new("Model")
		art.Name = "PlaceholderArt"
		art.Parent = site
		local function block(name: string, s: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
			return part(name, s, ground * cf, color, material, false, art)
		end
		-- An upright cylinder: a Roblox cylinder runs along its own X, so a
		-- standing one is sized (height, diameter, diameter) and turned onto
		-- its end.
		local function post(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		-- and one left on its side, axis along the asset's own X: cactus arms,
		-- cart wheels, the hoist's pulley.
		local function roll(name: string, diameter: number, length: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, V(length, diameter, diameter), cf, color, material)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		local function blob(name: string, s: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
			local p = block(name, s, cf, color, material)
			p.Shape = Enum.PartType.Ball
			return p
		end
		return { block = block, post = post, roll = roll, blob = blob }
	end

	-- ------------------------------------------------------------ floor
	-- The floor is MapBuilder's own Ground part and stays at y = 0.30: a raised
	-- skin here would bury the Heat telegraph, which is drawn flat at the
	-- creature's feet. All that goes on it is matte, shallow and walk-through --
	-- shallow cracks, dust patches and loose rubble, none of it 0.05 proud.
	for i = 1, 26 do
		local x = ((i * 53) % 173 - 86) * 1.32
		local z = ((i * 79) % 167 - 83) * 1.06
		if math.abs(x) > LANE_HALF + 4 and math.abs(x) < 96 and math.abs(z) < 92 then
			local at = CFrame.new(x, 0, z) * CFrame.Angles(0, i * 0.83, 0)
			flat(part("FloorCrack", V(7 + (i % 4) * 4, 0.06, 0.5 + (i % 3) * 0.15),
				at * CFrame.new(0, GROUND_Y + 0.01, 0), FLOOR_CRACK, SANDSTONE, false, floor))
			if i % 3 == 0 then
				flat(part("FloorDust", V(13 + (i % 5) * 4, 0.05, 9 + (i % 4) * 3),
					at * CFrame.new(2, GROUND_Y, 1) * CFrame.Angles(0, 0.4, 0), SAND_DUST, SANDSTONE, false, floor))
			end
		end
	end
	-- Loose stones. Small, flush and never in the lane; this is the one place
	-- props-v1's sandstone rubble mesh still fits the new art, so each one is
	-- tagged for that later pass rather than being given an asset site.
	for i = 1, 36 do
		local x = ((i * 67) % 181 - 90) * 1.28
		local z = ((i * 41) % 179 - 89) * 1.04
		if math.abs(x) > LANE_HALF + 6 and math.abs(x) < 104 and math.abs(z) < 94 then
			local h = 0.6 + (i % 3) * 0.3
			local tone = if i % 3 == 0 then SAND_DEEP else SAND
			local rubble = flat(part("Rubble", V(1.5 + (i % 4) * 0.5, h, 1.2 + (i % 3) * 0.45),
				CFrame.new(x, GROUND_Y + h / 2 - 0.15, z) * CFrame.Angles(0.08, i * 1.1, 0.06),
				tone, ROCK_MAT, false, floor))
			rubble:SetAttribute("ReusableAsset", "CC_Sandstone_Rubble")
		end
	end

	-- ------------------------------------------------------------ border rock
	-- Layered blocks inside the asset's envelope: three tiers, each turned a
	-- little off the last, each with a pale cap and a dark seam under it, which
	-- is how the concept draws every rock in the band.
	local function mesaArt(brush: Brush, w: number, h: number, d: number, seed: number)
		-- Two chunky tiers, not three thin ones: the concept's rock is big
		-- blocks parted by one deep seam, never a flight of steps.
		local split = 0.62
		local prevW, prevD, prevTurn = w, d, 0
		for t = 1, 2 do
			local turn = (seed % 5 - 2) * 0.08 * t
			-- A turned box needs room for its own corners. The asset bounds are
			-- the contract Astra models to, so each tier is pre-shrunk by
			-- whatever its turn costs it rather than leaning out of them.
			local c, sn = math.cos(turn), math.abs(math.sin(turn))
			local tw = if t == 1 then w else w * 0.70
			local td = if t == 1 then d else d * 0.72
			local fit = math.min(w / (tw * c + td * sn), d / (td * c + tw * sn), 1)
			tw, td = tw * fit, td * fit
			local y0 = if t == 1 then 0 else h * split
			local y1 = if t == 1 then h * split else h
			local tone = if t == 1 then SAND else SAND_TOP
			brush.block("MesaTier", V(tw, y1 - y0, td), CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(0, turn, 0), tone, SANDSTONE)
			if t == 2 then
				flat(brush.block("MesaSeam", V(prevW * 0.98, 0.6, prevD * 0.98),
					CFrame.new(0, y0 + 0.3, 0) * CFrame.Angles(0, prevTurn, 0), SAND_SEAM, SANDSTONE))
			end
			prevW, prevD, prevTurn = tw, td, turn
		end
		-- broken blocks at the foot, so the silhouette is not a plain step
		for _, side in { -1, 1 } do
			if (seed + (if side > 0 then 0 else 1)) % 2 == 0 then
				brush.block("MesaShoulder", V(w * 0.30, h * 0.34, d * 0.32),
					CFrame.new(side * w * 0.24, h * 0.18, -d * 0.10) * CFrame.Angles(0.04, seed * 0.5 * side, 0.05), SAND_DEEP, SANDSTONE)
			end
		end
	end

	-- A turned box reaches further than its own half width, and a rock standing
	-- in the wall would poke through into the next region along the chain. The
	-- band is laid out from the wall inward, so holding each rock inside the
	-- cell here costs the composition nothing and cannot be forgotten.
	local function insideCell(x: number, z: number, size: Vector3, yaw: number): (number, number)
		local c, sn = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
		local ex = (size.X * c + size.Z * sn) / 2
		local ez = (size.Z * c + size.X * sn) / 2
		return math.clamp(x, ex - HALF_W + 2, HALF_W - 2 - ex),
			math.clamp(z, ez - HALF_D + 2, HALF_D - 2 - ez)
	end

	for index, spec in MESAS do
		local kind, yaw = spec[3], spec[4]
		local asset = if kind == "L" then "CC_Quarry_Mesa_Large" else "CC_Quarry_Mesa_Low"
		local size = AssetSpec.quarry[asset]
		local x, z = insideCell(spec[1], spec[2], size, yaw)
		local at = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0)
		local name = "Mesa" .. (if #sites:GetChildren() + 1 < 10 then "0" else "") .. tostring(#sites:GetChildren() + 1)
		mesaArt(place("Mesa", asset, at, "Grounded", "Ground"), size.X, size.Y, size.Z, index)
		-- The containment under it. 0.74 of the asset box, not the whole box: a
		-- faceted rock inscribed in those bounds has a footprint well inside
		-- them, and a proxy out at the corners is both collision against air and
		-- open floor the region never gets back.
		proxy("MesaProxy", V(size.X * 0.74, size.Y, size.Z * 0.74), at * CFrame.new(0, size.Y / 2, 0))
		-- and the rock piled on its top, where the concept wants real height
		if spec[5] then
			local low = AssetSpec.quarry.CC_Quarry_Mesa_Low
			local sx, sz = insideCell(x, z, low, spec[5])
			local on = CFrame.new(sx, GROUND_Y + size.Y, sz) * CFrame.Angles(0, spec[5], 0)
			mesaArt(place("Mesa", "CC_Quarry_Mesa_Low", on, "Stacked", name), low.X, low.Y, low.Z, index + 7)
			proxy("MesaProxy", V(low.X * 0.74, low.Y, low.Z * 0.74), on * CFrame.new(0, low.Y / 2, 0))
		end
	end

	-- ------------------------------------------------------------ mine
	-- CC_Quarry_Mine is one 64 x 42 x 48 mesh: a layered butte with the opening
	-- genuinely recessed into it and its timber frame included. The stand-in
	-- builds that shape from two flanking masses, a rear mass behind the doorway
	-- and a lintel over it, which leaves the alcove the concept shows.
	local mineSize = AssetSpec.quarry.CC_Quarry_Mine
	do
		local W, H, D = mineSize.X, mineSize.Y, mineSize.Z
		local doorZ = MINE_DOOR.Position.Z -- the alcove's back wall, asset-local
		local doorW, doorH = MINE_DOOR_W, MINE_DOOR_H
		local alcoveD = D / 2 + doorZ -- front face to back wall
		local rearD = D / 2 - doorZ -- back wall to the rear of the butte
		local b = place("Mine", "CC_Quarry_Mine", MINE_AT, "Grounded", "Ground")
		for _, side in { -1, 1 } do
			local mw = (W - doorW) / 2
			local mx = side * (doorW / 2 + mw / 2)
			b.block("MineFlank", V(mw, H * 0.62, D), CFrame.new(mx, H * 0.31, 0), SAND, SANDSTONE)
			b.block("MineFlankTier", V(mw * 0.82, H * 0.26, D * 0.84), CFrame.new(mx - side * 1.5, H * 0.74, -1.5) * CFrame.Angles(0, side * 0.12, 0), SAND_TOP, SANDSTONE)
			flat(b.block("MineSeam", V(mw + 0.3, 0.6, D), CFrame.new(mx, H * 0.62, 0), SAND_SEAM, SANDSTONE))
		end
		b.block("MineRear", V(doorW + 2, H * 0.72, rearD), CFrame.new(0, H * 0.36, D / 2 - rearD / 2), SAND, SANDSTONE)
		b.block("MineLintel", V(doorW + 2, H * 0.40, alcoveD), CFrame.new(0, doorH + H * 0.20, -D / 2 + alcoveD / 2), SAND_DEEP, SANDSTONE)
		-- the rounded crown, which is what reads from across the region
		b.blob("MineCrown", V(W * 0.62, H * 0.52, D * 0.72), CFrame.new(-2, H * 0.74, 4), SAND_TOP, SANDSTONE)
		b.blob("MineCrown", V(W * 0.40, H * 0.34, D * 0.48), CFrame.new(W * 0.24, H * 0.80, -2) * CFrame.Angles(0, 0.4, 0.06), SAND_PALE, SANDSTONE)
		b.blob("MineCrown", V(W * 0.32, H * 0.30, D * 0.42), CFrame.new(-W * 0.24, H * 0.76, 2) * CFrame.Angles(0, -0.25, 0.04), SAND_TOP, SANDSTONE)
		b.blob("MineBoulder", V(W * 0.22, H * 0.26, D * 0.30), CFrame.new(-W * 0.26, H * 0.30, -D * 0.28) * CFrame.Angles(0.06, 0.8, 0.04), SAND, SANDSTONE)
		b.blob("MineBoulder", V(W * 0.20, H * 0.22, D * 0.26), CFrame.new(W * 0.28, H * 0.24, -D * 0.28) * CFrame.Angles(0.05, -0.6, 0.06), SAND_DEEP, SANDSTONE)
		-- the alcove: a dark back wall, and shadow filling the recess in front
		-- of it so the opening reads as depth rather than a painted panel
		b.block("MineShadow", V(doorW, doorH, 1.2), CFrame.new(0, doorH / 2, doorZ), CHARCOAL_DARK, SLATE)
		b.block("MineTunnel", V(doorW - 4, doorH - 2, alcoveD - 1.4), CFrame.new(0, (doorH - 2) / 2, doorZ - alcoveD / 2), TUNNEL, SLATE)
		-- the timber frame standing in the mouth of the alcove
		for _, side in { -1, 1 } do
			b.block("MinePost", V(2.4, doorH, 2.4), CFrame.new(side * (doorW / 2 - 1.2), doorH / 2, MINE_JAMB_Z), TIMBER, WOOD)
			b.block("MineBrace", V(6.6, 1.5, 2.0), CFrame.new(side * (doorW / 2 - 4.0), doorH - 3.4, MINE_JAMB_Z) * CFrame.Angles(0, 0, side * 0.62), TIMBER_DARK, WOOD)
		end
		b.block("MineHeader", V(doorW + 8, 2.8, 3.0), CFrame.new(0, doorH + 1.4, MINE_JAMB_Z), TIMBER_PALE, PLANK)
		b.block("MineHeaderCap", V(doorW + 5, 1.2, 3.4), CFrame.new(0, doorH + 3.2, MINE_JAMB_Z), TIMBER, PLANK)
		-- and the lantern housing, hung off the header's -X end as the concept
		-- has it. The lit pane is effect geometry, not part of the mesh.
		b.block("MineLanternHook", V(0.5, 3.2, 0.5), MINE_LANTERN * CFrame.new(0, 3, 0), IRON, METAL)
		b.block("MineLanternCage", V(2.6, 3.4, 2.6), MINE_LANTERN, IRON_LIGHT, METAL)
		b.block("MineLanternCap", V(3.2, 0.8, 3.2), MINE_LANTERN * CFrame.new(0, 1.8, 0), IRON, METAL)
		-- containment: the whole footprint is solid, because the alcove is
		-- scenery and nothing in this design walks into the mine
		proxy("MineProxy", V(W, H, D), MINE_AT * CFrame.new(0, H / 2, 0))
	end
	-- the lantern's lit pane, on the mine's lantern socket
	glow(flat(part("MineLanternGlass", V(1.9, 2.4, 1.9),
		MINE_AT * MINE_LANTERN, LANTERN_GLASS, NEON, false, effects)), 1.5, 22)

	-- ------------------------------------------------------- rail and ore cart
	-- Both hang off the mine's DoorBase socket exactly as the handoff's table
	-- writes them, so the rail meets the doorway however the delivered mesh
	-- recesses it, and the cart sits on the rail rather than in the dirt.
	local railAt = MINE_AT * MINE_DOOR * CFrame.new(0, 0.02, -13)
	local cartAt = MINE_AT * MINE_DOOR * CFrame.new(0, 1.05, -16)
	do
		local size = AssetSpec.quarry.CC_Quarry_Rail
		local b = place("Rail", "CC_Quarry_Rail", railAt, "Grounded", "Ground", "Mine01/DoorBase")
		local sleepers = 9
		for i = 1, sleepers do
			local z = (i - (sleepers + 1) / 2) * (size.Z / sleepers)
			flat(b.block("RailSleeper", V(size.X, 0.5, 1.5), CFrame.new(0, 0.25, z), TIMBER_DARK, WOOD))
		end
		for _, side in { -1, 1 } do
			flat(b.block("RailBar", V(0.8, 0.55, size.Z), CFrame.new(side * 3.2, 0.72, 0), IRON, METAL))
		end
	end
	do
		local size = AssetSpec.quarry.CC_Quarry_Cart
		local b = place("Cart", "CC_Quarry_Cart", cartAt, "Stacked", "Rail01", "Mine01/DoorBase")
		b.block("CartBody", V(size.X, 5.2, size.Z - 2), CFrame.new(0, 3.4, 0), CART_BODY, METAL)
		b.block("CartRim", V(size.X + 0.4, 0.9, size.Z - 1.4), CFrame.new(0, 6.1, 0), IRON, METAL)
		for _, side in { -1, 1 } do
			for _, along in { -1, 1 } do
				b.roll("CartWheel", 2.2, 0.7, CFrame.new(side * 5.1, 1.1, along * 3.6), IRON, METAL)
			end
		end
		-- the bright mineral load. Warm, but not Neon: the glow is one core.
		for i = 1, 5 do
			local a = i * 1.27
			b.block("CartOre", V(2.4, 1.9, 2.2), CFrame.new(math.sin(a) * 2.0, 6.4 + (i % 2) * 0.4, math.cos(a) * 2.4) * CFrame.Angles(0.2, a, 0.15), ORE, SMOOTH)
		end
	end

	-- ------------------------------------------------------------ terrace
	-- CC_Quarry_Terrace is 72 x 36 x 56: an asymmetric stepped quarry face with
	-- a flat hoist shelf and the lava channel cut into it. Four tiers stepping
	-- back toward the wall, the shelf being the third tier's top.
	local terraceSize = AssetSpec.quarry.CC_Quarry_Terrace
	do
		local W, H, D = terraceSize.X, terraceSize.Y, terraceSize.Z
		local b = place("Terrace", "CC_Quarry_Terrace", TERRACE_AT, "Grounded", "Ground")
		-- { half width, how far back the tier sits, base y, top y }
		local tiers = {
			{ W / 2, 0, 0, 9 },
			{ W / 2 - 4, 4, 9, 17 },
			{ W / 2 - 10, 8, 17, 25 },
			{ W / 2 - 16, 10, 25, H },
		}
		for t, spec in tiers do
			local hw, back, y0, y1 = spec[1], spec[2], spec[3], spec[4]
			local depth = D - back * 2
			local tone = if t == 1 then SAND elseif t == 4 then SAND_PALE else SAND_TOP
			-- the asymmetry the concept draws: each tier sits a little toward
			-- the wall, so the front corner nearest the centre steps down furthest
			local offX = if t == 4 then HOIST_BASE.Position.X else (t - 1) * -2.5
			b.block("TerraceTier", V(hw * 2, y1 - y0, depth), CFrame.new(offX, (y0 + y1) / 2, back), tone, SANDSTONE)
			flat(b.block("TerraceSeam", V(hw * 2, 0.55, depth), CFrame.new(offX, y1 - 0.3, back), SAND_SEAM, SANDSTONE))
			-- broken blocks along each step's lip, so the edge is not a ruler.
			-- They sit a little back from the lip: turned, their corners would
			-- otherwise reach past the bounds Astra is modelling to.
			for k = -1, 1 do
				b.block("TerraceBlock", V(7 + (t % 3) * 2, (y1 - y0) * 0.44, 6),
					CFrame.new(offX + k * (hw * 0.5), y0 + (y1 - y0) * 0.22, back - depth / 2 + 6) * CFrame.Angles(0, k * 0.22 + t * 0.1, 0.04),
					SAND_DEEP, SANDSTONE)
			end
		end
		proxy("TerraceProxy", V(W, H, D), TERRACE_AT * CFrame.new(0, H / 2, 0))
	end

	-- the hoist, standing on the terrace's HoistBase socket
	do
		local size = AssetSpec.quarry.CC_Quarry_Hoist
		local b = place("Hoist", "CC_Quarry_Hoist", TERRACE_AT * HOIST_BASE, "Stacked", "Terrace01", "Terrace01/HoistBase")
		for _, side in { -1, 1 } do
			b.block("HoistLeg", V(1.8, size.Y - 2, 1.8), CFrame.new(side * 6.5, (size.Y - 2) / 2, 3.2) * CFrame.Angles(side * 0.10, 0, 0), TIMBER, WOOD)
		end
		b.block("HoistBrace", V(1.5, 1.5, 11), CFrame.new(6.5, size.Y * 0.42, -1.0) * CFrame.Angles(0.46, 0, 0), TIMBER_DARK, WOOD)
		b.block("HoistBeam", V(size.X - 1, 2.0, 2.2), CFrame.new(0, size.Y - 1.0, 3.2), TIMBER_PALE, PLANK)
		b.block("HoistPulley", V(1.0, 1.4, 1.0), CFrame.new(-6.8, size.Y - 2.6, 3.2), IRON, METAL)
		b.block("HoistRope", V(0.3, 7.0, 0.3), CFrame.new(-6.8, size.Y - 6.6, 3.2), IRON_LIGHT, METAL)
		b.block("HoistLoad", V(5.4, 5.4, 5.4), CFrame.new(-6.8, size.Y - 12.4, 3.2) * CFrame.Angles(0, 0.24, 0), TIMBER, PLANK)
		for _, k in { -1, 1 } do
			flat(b.block("HoistLoadBrace", V(5.6, 0.7, 5.6), CFrame.new(-6.8, size.Y - 12.4 + k * 1.9, 3.2) * CFrame.Angles(0, 0.24, 0), TIMBER_DARK, WOOD))
		end
	end

	-- ------------------------------------------------------------ crates
	for _, spec in CRATES do
		local y, yaw = spec[2], spec[4]
		local size = AssetSpec.quarry.CC_Quarry_Crate
		local x, z = insideCell(spec[1], spec[3], size, yaw)
		local at = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
		local grounded = y <= GROUND_Y + 0.1
		local b = place("Crate", "CC_Quarry_Crate", at, if grounded then "Grounded" else "Stacked", spec[5])
		b.block("CrateBody", V(size.X, size.Y, size.Z), CFrame.new(0, size.Y / 2, 0), TIMBER, PLANK)
		for _, k in { -1, 1 } do
			flat(b.block("CrateBrace", V(size.X, 0.8, size.Z), CFrame.new(0, size.Y / 2 + k * 1.9, 0), TIMBER_DARK, WOOD))
		end
		flat(b.block("CrateLid", V(size.X * 0.9, 0.5, size.Z * 0.9), CFrame.new(0, size.Y - 0.25, 0), TIMBER_PALE, PLANK))
		if grounded then
			proxy("CrateProxy", V(size.X, size.Y, size.Z), at * CFrame.new(0, size.Y / 2, 0))
		end
	end

	-- ------------------------------------------------------------ planting
	local function cactusTall(b: Brush, size: Vector3, seed: number)
		local trunk = size.Y - 1.6
		b.post("CactusTrunk", 3.4, trunk, CFrame.new(0, trunk / 2, 0), CACTUS, GRASS)
		b.blob("CactusCrown", V(3.4, 3.2, 3.4), CFrame.new(0, trunk, 0), CACTUS_LIGHT, GRASS)
		for _, side in { -1, 1 } do
			if (seed + (if side > 0 then 0 else 1)) % 2 == 0 then
				local h = size.Y * 0.34
				b.roll("CactusArm", 2.0, 4.0, CFrame.new(side * 1.9, size.Y * 0.52, 0), CACTUS_DARK, GRASS)
				b.post("CactusArm", 2.0, h, CFrame.new(side * 3.2, size.Y * 0.52 + h / 2, 0), CACTUS, GRASS)
				b.blob("CactusArmTip", V(2.0, 1.8, 2.0), CFrame.new(side * 3.2, size.Y * 0.52 + h, 0), CACTUS_LIGHT, GRASS)
			end
		end
		for k = 1, 3 do
			flat(b.block("CactusRib", V(0.22, trunk * 0.8, 0.22), CFrame.new(math.sin(k * 2.1) * 1.5, trunk * 0.5, math.cos(k * 2.1) * 1.5), CACTUS_DARK, GRASS))
		end
		if seed % 3 == 0 then
			flat(b.block("CactusBloom", V(1.2, 0.9, 1.2), CFrame.new(1.2, size.Y - 0.6, 0), BLOOM_ORANGE, SMOOTH))
		end
	end
	local function cactusRound(b: Brush, size: Vector3, seed: number)
		b.blob("CactusBall", V(size.X, size.Y, size.Z), CFrame.new(0, size.Y / 2, 0), CACTUS, GRASS)
		b.blob("CactusBall", V(size.X * 0.5, size.Y * 0.5, size.Z * 0.5), CFrame.new(1.6, size.Y * 0.3, -1.2) * CFrame.Angles(0, seed * 0.7, 0), CACTUS_DARK, GRASS)
		for k = 1, 4 do
			flat(b.block("CactusRib", V(0.2, size.Y * 0.7, 0.2), CFrame.new(math.sin(k * 1.6) * 1.7, size.Y * 0.45, math.cos(k * 1.6) * 1.7), CACTUS_DARK, GRASS))
		end
		if seed % 2 == 0 then
			flat(b.block("CactusBloom", V(1.1, 0.8, 1.1), CFrame.new(0.4, size.Y - 0.5, 0), BLOOM_YELLOW, SMOOTH))
		end
	end
	local function agave(b: Brush, size: Vector3, seed: number)
		for k = 1, 7 do
			local a = k * math.pi * 2 / 7 + seed * 0.3
			local tone = if k % 2 == 0 then AGAVE else AGAVE_DARK
			flat(b.block("AgaveLeaf", V(1.8, 0.7, size.Z * 0.46),
				CFrame.new(math.sin(a) * 2.0, size.Y * 0.42, math.cos(a) * 2.0) * CFrame.Angles(-0.7, a, 0),
				tone, GRASS))
		end
		b.blob("AgaveHeart", V(2.6, 1.8, 2.6), CFrame.new(0, 0.9, 0), AGAVE_DARK, GRASS)
	end
	local function bloomPatch(b: Brush, size: Vector3, seed: number)
		b.blob("FlowerFoliage", V(size.X * 0.8, size.Y * 0.7, size.Z * 0.8), CFrame.new(0, size.Y * 0.3, 0), CACTUS_DARK, GRASS)
		for k = 1, 4 do
			local a = k * 1.7 + seed
			local head = if k % 3 == 0 then PETAL elseif k % 3 == 1 then BLOOM_ORANGE else BLOOM_YELLOW
			flat(b.block("FlowerStem", V(0.18, size.Y * 0.6, 0.18), CFrame.new(math.sin(a) * 1.4, size.Y * 0.4, math.cos(a) * 1.4), CACTUS, GRASS))
			flat(b.block("FlowerHead", V(1.1, 0.5, 1.1), CFrame.new(math.sin(a) * 1.4, size.Y * 0.72, math.cos(a) * 1.4), head, SMOOTH))
		end
	end

	-- Planting never collides: the handoff keeps plant collision out of the
	-- route, and a cactus is not containment anywhere else in the cell either.
	for index, spec in PLANTS do
		local kind, yaw = spec[3], spec[4]
		local asset = if kind == "T" then "CC_Quarry_Cactus_Tall"
			elseif kind == "R" then "CC_Quarry_Cactus_Round"
			elseif kind == "A" then "CC_Quarry_Agave"
			else "CC_Quarry_Flowers"
		local size = AssetSpec.quarry[asset]
		local x, z = insideCell(spec[1], spec[2], size, yaw)
		local b = place("Plant", asset, CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0), "Grounded", "Ground")
		if kind == "T" then
			cactusTall(b, size, index)
		elseif kind == "R" then
			cactusRound(b, size, index)
		elseif kind == "A" then
			agave(b, size, index)
		else
			bloomPatch(b, size, index)
		end
	end

	-- ------------------------------------------------------------ lava
	-- Effect geometry at the terrace's lava sockets, nowhere near a walking
	-- route. The rock it runs over is the terrace mesh's own notch; only the
	-- ribbon, the crust and the pool live here, and only the ribbon moves.
	local foot = (TERRACE_AT * LAVA_FOOT).Position
	-- The final foot is still within the terrace bounds. Extend the flow to a
	-- shallow pool just south of that footprint rather than burying a pool in rock.
	local poolAt = V(foot.X, GROUND_Y + 0.08, TERRACE_AT.Position.Z - 37)
	do
		local anchors = { TERRACE_SOCKETS.LavaUpperLip, TERRACE_SOCKETS.LavaLowerLip, LAVA_FOOT }
		for k = 1, 2 do
			local a = (TERRACE_AT * anchors[k] * CFrame.new(0, 0, -0.3)).Position
			local b = (TERRACE_AT * anchors[k + 1] * CFrame.new(0, 0, -0.3)).Position
			local at = CFrame.lookAt((a + b) / 2, b)
			local ribbon = flat(part("LavaFall" .. k, V(3.5 + (k - 1), 0.35, (b - a).Magnitude), at, LAVA, NEON, false, effects))
			glow(ribbon, 0.75, 20)
			-- Keep the delivered endpoints fixed; pulse light rather than sway the
			-- whole ribbon away from its rock channel.
		end
		local runA = foot + V(0, 0, -0.3)
		local runB = poolAt + V(0, 0.15, 4)
		flat(part("LavaRun", V(4.5, 0.3, (runB - runA).Magnitude),
			CFrame.lookAt((runA + runB) / 2, runB), LAVA, NEON, false, effects))
		flat(part("LavaPool", V(17, 0.3, 15), CFrame.new(poolAt), LAVA, NEON, false, effects))
		glow(flat(part("LavaPoolCore", V(11, 0.28, 9), CFrame.new(poolAt + V(0, 0.04, 0)), LAVA_HOT, NEON, false, effects)), 1.6, 34)
		-- Low rear semicircle: every stone stays behind the pool centre, leaving
		-- the entire south approach open at player height.
		for k = 0, 6 do
			local a = math.pi * k / 6
			local rh = 0.6 + (k % 2) * 0.2
			local at = CFrame.new(poolAt.X + math.cos(a) * 9.8, GROUND_Y + rh / 2, poolAt.Z + math.sin(a) * 8)
			part("LavaKerb", V(4, rh, 3), at * CFrame.Angles(0, -a, 0), CHARCOAL, BASALT_MAT, false, effects)
		end
		proxy("LavaPocketProxy", V(19, 6, 17), CFrame.new(poolAt.X, GROUND_Y + 3, poolAt.Z))
	end

	-- The delivered mesh exposes two mineral pockets. Separate effect cores
	-- sit exactly at those sockets; rock and crystal shards stay matte/glass.
	for _, name in { "Crystal01", "Crystal02" } do
		local at = TERRACE_AT * TERRACE_SOCKETS[name]
		for k = 1, 3 do
			local h = 3.0 + k * 0.9
			local shard = flat(part("Mineral", V(1.8, h, 1.8),
				at * CFrame.new((k - 2) * 1.8, h / 2 - 1, -(k % 2) * 1.2) * CFrame.Angles(0.16 * (k - 2), k * 1.1, 0.14 * (2 - k)),
				MINERAL, GLASS, false, effects))
			shard.Transparency = 0.2
		end
		glow(flat(part(name .. "Core", V(0.9, 2.4, 0.9), at, MINERAL_CORE, NEON, false, effects)), 0.9, 18)
	end

	sites:SetAttribute("AssetCount", siteCount)
	parent:SetAttribute("SceneryVersion", 5)
	parent:SetAttribute("ConceptId", "cinder-canyon-v1-03-cinder-quarry")
	QuarryProps.apply(parent, frame)

	-- What the rest of the game needs to know about this shape: the open orange
	-- floor, and the two landmarks and the lava pocket standing in it. Given in
	-- world axes relative to the region centre, so callers need no local frame.
	local function world(x: number, z: number): Vector3
		return frame:VectorToWorldSpace(V(x, 0, z))
	end
	-- The field stops short of the wall on all four sides, and the numbers are
	-- measured rather than guessed: the side band's inner rank reaches in to
	-- x = 95, and the low rocks flanking both gates reach in to z = 76. Both
	-- landmark circles are sized past the far corner of their own footprint --
	-- 45 studs for the terrace, 37 for the mine -- so a creature pushed out to
	-- a circle's edge lands on open floor rather than on the rock.
	return {
		field = Vector3.new(HALF_W - BAND_DEEP - 4, 0, HALF_D - 28),
		keepOut = {
			-- the mine, sized past its rail, cart and forecourt crates
			{ at = world(MINE_AT.Position.X, MINE_AT.Position.Z - 6), radius = 48 },
			-- the terrace, sized past its near corner and the crates on it
			{ at = world(TERRACE_AT.Position.X, TERRACE_AT.Position.Z - 1), radius = 48 },
			-- the lava pocket, which stands clear of the terrace's own circle
			{ at = world(poolAt.X, poolAt.Z), radius = 18 },
			-- the route: creatures belong on the floor either side of the lane
			{ at = Vector3.zero, radius = 0, lane = LANE_HALF + 5 },
		},
	}
end

return Quarry
