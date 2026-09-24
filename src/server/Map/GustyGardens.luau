--!strict
-- Gusty Gardens, built to the approved concept
-- (docs/art/world/2026-09-21-linear-regions/gusty-gardens/gusty-gardens-v2-wider.png):
-- a wide flat meadow split into two open clearings by one straight earth road,
-- two matching windmill houses north of the midpoint, and a layered planting
-- band hugging the cream perimeter wall.
--
-- Local frame, as handed over by RegionScenery: local -Z is the town entrance
-- (south), local +Z is the Splashwater gate (north), and local +X is world west.
-- The region is symmetric left to right, so the X mirror does not matter.
--
-- The cell is MapBuilder's: 280 wide by 200 deep. The wall, its piers and the
-- two gates belong to MapBuilder.buildChainWalls; everything inside is here.
--
-- Every prop is procedural geometry named for the swap Astra's kit performs
-- through GardenBayProps: GardenStone becomes GG_Moss_Rock_*, FlowerBed becomes
-- GG_Daisy_Cluster / GG_Bluebell_Cluster. Names outside that contract are new
-- placeholders and are listed in the asset request beside the concept.
local CollectionService = game:GetService("CollectionService")
local Gardens = {}
local GardenBayProps = require(script.Parent.GardenBayProps)
local BroadleafProps = require(script.Parent.GustyBroadleafProps)
local rgb = Color3.fromRGB
local V = Vector3.new

-- ---------------------------------------------------------------- layout
local HALF_W, HALF_D = 140, 100 -- the cell MapBuilder walls
local PATH_HALF = 12 -- the 24-wide earth road on the centreline
local GATE_CLEAR = 21 -- planting keeps this far off the centreline at both gates
local BAND_IN, BAND_OUT = 15, 38 -- planting band, measured in from the wall
local MILL_X, MILL_Z = 76, 18 -- windmill centres, north of the midpoint

-- ---------------------------------------------------------------- palette
local CREAM = rgb(246, 240, 226) -- windmill render
local COPPER = rgb(206, 116, 58) -- body bands, door arch, sail frames
local COPPER_DEEP = rgb(172, 88, 44)
local ROOF = rgb(146, 96, 62) -- the cone
local ROOF_DARK = rgb(118, 76, 50)
local TIMBER = rgb(124, 84, 48)
local TIMBER_DARK = rgb(92, 60, 34)
local SAIL = rgb(250, 246, 236)
local STONE = rgb(154, 156, 164) -- footing boulders, steps
local STONE_PALE = rgb(202, 202, 208)
local ROCK = rgb(140, 143, 152)
local ROCK_LIGHT = rgb(172, 175, 183)
local ROCK_DARK = rgb(112, 116, 126)
local DIRT = rgb(226, 190, 132)
local DIRT_PALE = rgb(238, 214, 172)
local LEAF_DARK = rgb(52, 116, 54)
local LEAF_MID = rgb(74, 146, 64)
local LEAF_LIGHT = rgb(104, 178, 78)
local PINE = rgb(40, 100, 58)
local PINE_LIGHT = rgb(56, 124, 68)
local GRASS_DEEP = rgb(112, 178, 92)
local GRASS_LIGHT = rgb(132, 196, 104)
local PETAL = rgb(253, 252, 248)
local PETAL_PINK = rgb(247, 190, 202)
local POLLEN = rgb(250, 208, 76)

function Gardens.build(parent: Model, frame: CFrame, _radius: number, makePart: (any) -> Part)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = parent
	local broadleafSites = Instance.new("Model")
	broadleafSites.Name = "BroadleafSites"
	broadleafSites.Parent = boundary
	local decor = Instance.new("Model")
	decor.Name = "Landmarks"
	decor.Parent = parent
	local walkways = Instance.new("Model")
	walkways.Name = "Walkways"
	walkways.Parent = parent

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
	-- A disc standing up and facing local -Z, for the door arch and the sail hub.
	local function facing(name: string, diameter: number, thickness: number, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local p = part(name, V(thickness, diameter, diameter), cf * CFrame.Angles(0, math.pi / 2, 0), color, material, false, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- A flat plate laid on the ground, kept off the floor so it cannot z-fight.
	local function plate(name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local p = part(name, V(0.22, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, false, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function motion(p: Part, pivot: CFrame, mode: string, speed: number, phase: number)
		p.CanCollide = false
		p.CanQuery = false
		p:SetAttribute("SceneryPivot", frame * pivot)
		p:SetAttribute("SceneryOffset", (frame * pivot):ToObjectSpace(p.CFrame))
		p:SetAttribute("SceneryMode", mode)
		p:SetAttribute("ScenerySpeed", speed)
		p:SetAttribute("SceneryPhase", phase)
		CollectionService:AddTag(p, "SceneryMotion")
	end

	-- The lawn is left as MapBuilder's single grass plate. Mottling it with
	-- plates read as pale patches at any tone; the concept's variation is in a
	-- texture, which is an asset request, not geometry.

	-- ------------------------------------------------------------ the road
	-- MapBuilder lays the 24-wide earth strip; these are the concept's soft
	-- irregular shoulders and its sparse pale flagstones. The route stays straight.
	for i = -8, 8 do
		local z = i * 11.8
		for _, side in { -1, 1 } do
			local nick = 1.1 + ((i + 8) % 3) * 0.9
			-- Longer than the 11.8 spacing so consecutive nicks overlap: at 9 they
			-- left gaps and the shoulder read as a dashed line beside the road.
			part("PathEdge", V(nick, 0.26, 14 + (i % 2) * 3), CFrame.new(side * (PATH_HALF - nick / 2 + 0.2), 0.42, z),
				DIRT, Enum.Material.Ground, false, walkways)
		end
	end
	for i, spec in { { -3.2, -70 }, { 4.0, -44 }, { -2.4, -16 }, { 3.6, 20 }, { -3.8, 52 }, { 2.6, 84 } } do
		plate("PathStone", 4.8 + (i % 3) * 0.9, CFrame.new(spec[1], 0.5, spec[2]), DIRT_PALE, Enum.Material.Slate, walkways)
	end

	-- --------------------------------------------------------- the windmills
	-- Cream tapered house on a low boulder footing, copper-trimmed, brown cone
	-- roof, and four broad cream sails in a rust frame. Door faces the approach.
	local function windmill(side: number)
		local mill = CFrame.new(side * MILL_X, 0, MILL_Z)
		local house = Instance.new("Model")
		house.Name = "Windmill"
		house.Parent = decor

		-- Boulder footing, kept low: at head height it hid the door and the
		-- render read as a pile of rock with a roof on it.
		for i = 1, 16 do
			local a = (i / 16) * math.pi * 2
			local r = 11.4 + (i % 3) * 0.5
			local h = 2.0 + (i % 4) * 0.45
			local shade = if i % 3 == 0 then ROCK_LIGHT else STONE
			local b = part("MillFooting", V(4.2 + (i % 3) * 0.7, h, 3.4), mill
				* CFrame.new(math.cos(a) * r, h / 2 - 0.5, math.sin(a) * r) * CFrame.Angles(0, a + 0.4, 0),
				shade, Enum.Material.Rock, true, house)
			b.CanQuery = false
		end
		pillar("MillPlinth", 22.4, 1.5, mill * CFrame.new(0, 0.75, 0), STONE_PALE, Enum.Material.Concrete, true, house)

		-- tapered body
		pillar("MillBody", 21.6, 7.4, mill * CFrame.new(0, 5.2, 0), CREAM, Enum.Material.Concrete, true, house)
		pillar("MillBody", 20.2, 7.4, mill * CFrame.new(0, 12.6, 0), CREAM, Enum.Material.Concrete, true, house)
		pillar("MillBody", 18.8, 7.0, mill * CFrame.new(0, 19.8, 0), CREAM, Enum.Material.Concrete, true, house)
		pillar("MillBand", 22.2, 1.5, mill * CFrame.new(0, 2.2, 0), COPPER, Enum.Material.Metal, false, house)
		pillar("MillBand", 19.3, 1.3, mill * CFrame.new(0, 22.6, 0), COPPER, Enum.Material.Metal, false, house)

		-- Cone roof in ten thin courses: six read as a ziggurat from above.
		for i = 1, 10 do
			local t = (i - 1) / 9
			local d = 23.0 - t * 18.6
			pillar("MillRoof", d, 1.12, mill * CFrame.new(0, 23.8 + (i - 1) * 0.98, 0),
				ROOF:Lerp(ROOF_DARK, t * 0.5), Enum.Material.Slate, i == 1, house)
		end
		ball("MillRoofCap", V(4.8, 3.8, 4.8), mill * CFrame.new(0, 33.6, 0), ROOF, Enum.Material.Slate, false, house)
		pillar("MillChimney", 2.6, 3.6, mill * CFrame.new(0, 34.8, 1.4), TIMBER, Enum.Material.Wood, false, house)

		-- arched door on the approach face, clear of the footing now
		local face = -10.9
		facing("MillDoorArch", 8.2, 0.8, mill * CFrame.new(0, 7.6, face), COPPER, Enum.Material.Metal, house)
		part("MillDoorArchLeg", V(8.2, 7.2, 0.8), mill * CFrame.new(0, 4.0, face), COPPER, Enum.Material.Metal, false, house)
		facing("MillDoor", 6.6, 0.7, mill * CFrame.new(0, 7.6, face - 0.5), TIMBER, Enum.Material.WoodPlanks, house)
		part("MillDoor", V(6.6, 7.2, 0.7), mill * CFrame.new(0, 4.0, face - 0.5), TIMBER, Enum.Material.WoodPlanks, false, house)
		for _, dx in { -1.6, 1.6 } do
			part("MillDoorPlank", V(0.26, 9.6, 0.4), mill * CFrame.new(dx, 5.6, face - 0.9), TIMBER_DARK, Enum.Material.Wood, false, house)
		end
		ball("MillDoorKnob", V(0.9, 0.9, 0.9), mill * CFrame.new(2.2, 4.8, face - 1.0), COPPER, Enum.Material.Metal, false, house)

		-- two slot windows above the door line
		for _, dx in { -6.6, 6.6 } do
			part("MillWindowFrame", V(2.6, 4.0, 0.7), mill * CFrame.new(dx, 12.4, face + 1.6), COPPER, Enum.Material.Metal, false, house)
			part("MillWindow", V(1.6, 3.0, 0.7), mill * CFrame.new(dx, 12.4, face + 1.2), rgb(70, 56, 48), Enum.Material.SmoothPlastic, false, house)
		end

		-- steps and the trodden patch they land on
		part("MillStep", V(10.0, 1.0, 2.8), mill * CFrame.new(0, 1.2, -13.4), STONE_PALE, Enum.Material.Concrete, true, house)
		part("MillStep", V(11.4, 1.0, 2.8), mill * CFrame.new(0, 0.55, -16.0), STONE_PALE, Enum.Material.Concrete, true, house)
		plate("MillApron", 16, mill * CFrame.new(0, 0.36, -19.5), DIRT, Enum.Material.Ground, walkways)

		-- Sails: hub stood well off the roof so the broad panels clear the body,
		-- four arms in an X, each a bright panel inside a rust frame.
		local rotor = mill * CFrame.new(0, 22.6, -12.6)
		facing("MillHubRing", 7.0, 1.8, rotor, ROOF_DARK, Enum.Material.Wood, house)
		facing("MillHubPlate", 5.0, 2.4, rotor * CFrame.new(0, 0, -0.6), TIMBER, Enum.Material.Wood, house)
		ball("MillHubBoss", V(4.0, 4.0, 3.2), rotor * CFrame.new(0, 0, -1.6), COPPER_DEEP, Enum.Material.Metal, false, house)
		for i = 0, 3 do
			local arm = rotor * CFrame.Angles(0, 0, i * math.pi / 2 + math.pi / 4)
			local spar = part("MillSailFrame", V(6.6, 18.0, 0.7), arm * CFrame.new(0, 11.6, -1.3), COPPER, Enum.Material.Wood, false, house)
			motion(spar, rotor, "Spin", 0.2, 0)
			local panel = part("MillSailPanel", V(5.3, 16.6, 0.6), arm * CFrame.new(0, 11.6, -1.9), SAIL, Enum.Material.SmoothPlastic, false, house)
			motion(panel, rotor, "Spin", 0.2, 0)
			for j = 1, 2 do
				local bar = part("MillSailBar", V(5.4, 0.66, 0.8), arm * CFrame.new(0, 6.1 + j * 5.5, -2.0), COPPER, Enum.Material.Wood, false, house)
				motion(bar, rotor, "Spin", 0.2, 0)
			end
		end

		-- the crate the concept leaves beside each mill
		local crate = mill * CFrame.new(-side * 17.5, 0, -7.0) * CFrame.Angles(0, side * 0.35, 0)
		part("MeadowCrate", V(5.4, 5.2, 5.4), crate * CFrame.new(0, 2.6, 0), TIMBER, Enum.Material.WoodPlanks, true, house)
		part("MeadowCrateLid", V(5.8, 0.55, 5.8), crate * CFrame.new(0, 5.3, 0), rgb(152, 110, 66), Enum.Material.WoodPlanks, false, house)
		for _, dy in { 1.1, 4.1 } do
			part("MeadowCrateBand", V(5.7, 0.5, 5.7), crate * CFrame.new(0, dy, 0), TIMBER_DARK, Enum.Material.Wood, false, house)
		end
	end
	windmill(1)
	windmill(-1)

	-- -------------------------------------------------------------- planting
	-- A chunky faceted canopy: overlapping lobes rather than one sphere, with a
	-- lighter crown catching the light the way the concept's trees do.
	local function bigTree(at: CFrame, scale: number, tone: number)
		local site = Instance.new("Model")
		site.Name = string.format("Broadleaf_%02d", #broadleafSites:GetChildren() + 1)
		site:SetAttribute("GroundCF", at)
		site:SetAttribute("AssetScale", scale)
		site:SetAttribute("PivotMode", "TrunkBase")
		site:SetAttribute("SizeLock", "Uniform")
		site.Parent = broadleafSites
		local art = Instance.new("Model")
		art.Name = "PlaceholderArt"
		art.Parent = site
		local trunk = part("MeadowTreeTrunk", V(2.6, 8.5, 2.6) * scale, at * CFrame.new(0, 4.2 * scale, 0), TIMBER, Enum.Material.Wood, true, site)
		trunk.CanQuery = false
		local lobes = {
			{ V(0, 11.6, 0), 12.6, 2 }, { V(-4.6, 9.6, 1.4), 10.4, 1 }, { V(4.8, 9.8, -1.0), 10.8, 1 },
			{ V(1.0, 9.2, 4.6), 9.8, 0 }, { V(-1.1, 10.2, -4.4), 10.0, 0 }, { V(0.4, 14.2, 0.6), 8.4, 2 },
		}
		local shades = { LEAF_DARK, LEAF_MID, LEAF_LIGHT }
		for i, spec in lobes do
			local d = (spec[2] :: number) * scale
			ball("MeadowTreeLobe", V(d, d * 0.9, d), at * CFrame.new((spec[1] :: Vector3) * scale),
				shades[((spec[3] :: number) + tone) % 3 + 1], Enum.Material.Grass, false, art)
		end
	end
	local function pineTree(at: CFrame, scale: number)
		local trunk = part("PineTrunk", V(2.0, 5.8, 2.0) * scale, at * CFrame.new(0, 2.9 * scale, 0), TIMBER_DARK, Enum.Material.Wood, true, boundary)
		trunk.CanQuery = false
		for i = 1, 6 do
			local t = (i - 1) / 5
			local d = (11.2 - t * 8.4) * scale
			local needle = PINE:Lerp(PINE_LIGHT, t * 0.8)
			pillar("PineTier", d, 2.6 * scale, at * CFrame.new(0, (4.4 + (i - 1) * 2.15) * scale, 0), needle,
				Enum.Material.Grass, false, boundary)
		end
		ball("PineCrown", V(2.8, 3.6, 2.8) * scale, at * CFrame.new(0, 16.4 * scale, 0), PINE_LIGHT, Enum.Material.Grass, false, boundary)
	end
	local function shrub(at: CFrame, scale: number, tone: number)
		local d = 6.6 * scale
		local leaf = if tone % 2 == 0 then LEAF_MID else LEAF_LIGHT
		ball("MeadowShrub", V(d, d * 0.84, d * 0.96), at * CFrame.new(0, d * 0.36, 0), leaf,
			Enum.Material.Grass, false, boundary)
		ball("MeadowShrub", V(d * 0.68, d * 0.62, d * 0.68), at * CFrame.new(d * 0.44, d * 0.3, d * 0.22),
			LEAF_DARK, Enum.Material.Grass, false, boundary)
		ball("MeadowShrub", V(d * 0.56, d * 0.52, d * 0.56), at * CFrame.new(-d * 0.36, d * 0.26, -d * 0.2),
			LEAF_MID, Enum.Material.Grass, false, boundary)
	end
	-- GardenStone and FlowerBed are the two names GardenBayProps swaps for
	-- Astra's meshes, so the perimeter upgrades in place when the kit lands.
	-- Until then a boulder is three rotated slabs, because one box reads as a box.
	local function gardenRock(at: CFrame, scale: number)
		local specs = {
			{ V(5.6, 4.4, 5.0), V(0, 1.9, 0), 0.18, 0.5, 0.10 },
			{ V(4.2, 3.4, 4.6), V(1.5, 1.3, -0.9), -0.22, 1.3, 0.16 },
			{ V(3.4, 2.8, 3.8), V(-1.4, 1.2, 1.1), 0.14, 2.2, -0.2 },
		}
		local shades = { ROCK, ROCK_LIGHT, ROCK_DARK }
		for i, spec in specs do
			local r = part("GardenStone", (spec[1] :: Vector3) * scale,
				at * CFrame.new((spec[2] :: Vector3) * scale)
					* CFrame.Angles(spec[3] :: number, (spec[4] :: number) + scale, spec[5] :: number),
				shades[i], Enum.Material.Rock, i == 1, boundary)
			r.CanQuery = false
		end
	end
	local function flowerBed(at: CFrame, seed: number)
		ball("FlowerBed", V(4.2, 1.8, 4.0), at * CFrame.new(0, 0.7, 0), LEAF_MID, Enum.Material.Grass, false, boundary)
		for i = 1, 7 do
			local a = seed + i * 0.897
			local r = 0.9 + (i % 3) * 0.7
			local p = at * CFrame.new(math.cos(a) * r, 1.7 + (i % 3) * 0.4, math.sin(a) * r)
			part("FlowerStalk", V(0.18, 1.5, 0.18), p * CFrame.new(0, -0.7, 0), LEAF_DARK, Enum.Material.Grass, false, boundary)
			local petal = if (seed + i) % 6 == 0 then PETAL_PINK else PETAL
			plate("FlowerHead", 2.1, p, petal, Enum.Material.SmoothPlastic, boundary)
			plate("FlowerEye", 0.9, p * CFrame.new(0, 0.14, 0), POLLEN, Enum.Material.Neon, boundary)
		end
	end
	local function tuft(at: CFrame, scale: number)
		for i = 1, 3 do
			part("GrassTuft", V(0.34, 2.4 * scale, 0.34), at * CFrame.new((i - 2) * 0.6, 1.2 * scale, (i % 2) * 0.45)
				* CFrame.Angles(0.14 * (i - 2), 0, 0.12), LEAF_LIGHT, Enum.Material.Grass, false, boundary)
		end
	end

	-- Two ranks around all four sides: trees and pines against the wall, low
	-- planting in front of them. Both gate throats stay clear. The inset is
	-- jittered so the band reads as planting rather than a hedge row.
	local function planted(x: number, z: number): boolean
		return not (math.abs(z) > HALF_D - BAND_OUT - 4 and math.abs(x) < GATE_CLEAR)
	end
	-- `thin` drops every third tree on the north and south runs: at full density
	-- they closed into a hedge and the cream wall behind them stopped reading.
	local edges = {
		{ axis = "z", sign = 1, span = HALF_W, steps = 16, thin = true },
		{ axis = "z", sign = -1, span = HALF_W, steps = 16, thin = true },
		{ axis = "x", sign = 1, span = HALF_D, steps = 12, thin = false },
		{ axis = "x", sign = -1, span = HALF_D, steps = 12, thin = false },
	}
	local seq = 0
	for _, edge in edges do
		for i = 0, edge.steps do
			local t = (i / edge.steps) * 2 - 1
			local along = t * (edge.span - BAND_IN - 7) + ((i % 3) - 1) * 3.2
			seq += 1
			for rank = 1, 2 do
				local jitter = ((seq * 7) % 5) - 2
				local inset = if rank == 1 then BAND_IN + (i % 2) * 4 + jitter else BAND_OUT - 7 - (i % 3) * 4 + jitter
				local x, z
				if edge.axis == "z" then
					x, z = along, edge.sign * (HALF_D - inset)
				else
					x, z = edge.sign * (HALF_W - inset), along
				end
				local skip = edge.thin and rank == 1 and i % 3 == 1
				if planted(x, z) and not skip then
					local at = CFrame.new(x, 0, z) * CFrame.Angles(0, seq * 0.9 + rank, 0)
					local pick = (seq + rank * 3) % 7
					if rank == 1 then
						if pick == 0 or pick == 3 then
							pineTree(at, 0.95 + (seq % 3) * 0.05)
						else
							bigTree(at, 0.90 + (seq % 4) * 0.04, seq)
						end
					elseif pick == 1 or pick == 5 then
						gardenRock(at, 0.85 + (seq % 3) * 0.3)
					elseif pick == 2 or pick == 6 then
						flowerBed(at, seq * 1.7)
					else
						shrub(at, 0.9 + (seq % 3) * 0.2, seq)
					end
				end
			end
		end
	end

	-- corners get one more tree each so the border reads as thicker there
	for _, c in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
		bigTree(CFrame.new(c.X * (HALF_W - 28), 0, c.Z * (HALF_D - 26)) * CFrame.Angles(0, c.X * c.Z * 1.2, 0), 1.16, 1)
		pineTree(CFrame.new(c.X * (HALF_W - 40), 0, c.Z * (HALF_D - 20)), 1.05)
		gardenRock(CFrame.new(c.X * (HALF_W - 18), 0, c.Z * (HALF_D - 38)), 1.3)
		shrub(CFrame.new(c.X * (HALF_W - 48), 0, c.Z * (HALF_D - 30)), 1.15, 2)
	end

	-- The concept banks low planting right against both gates' piers.
	for _, z in { HALF_D - 12, -(HALF_D - 12) } do
		for _, x in { -30, -24, 24, 30 } do
			local at = CFrame.new(x, 0, z + (x % 7) * 0.4) * CFrame.Angles(0, x * 0.3, 0)
			if math.abs(x) > 27 then
				shrub(at, 1.0, math.floor(x))
			else
				flowerBed(at, x * 0.9 + z * 0.02)
			end
		end
	end

	-- A scatter of daisies along the inner lip of the band, which is where the
	-- concept banks most of its white flowers.
	for i = 1, 20 do
		local t = (i / 20) * 2 - 1
		local along = t * (HALF_W - 24)
		local lip = HALF_D - BAND_OUT + 3 + ((i * 5) % 7) - 3
		if math.abs(along) > GATE_CLEAR + 10 and i % 3 ~= 0 then
			flowerBed(CFrame.new(along, 0, lip) * CFrame.Angles(0, i * 1.1, 0), i * 1.3)
		end
		if math.abs(along) > GATE_CLEAR + 10 and i % 4 ~= 1 then
			flowerBed(CFrame.new(along + 4, 0, -lip) * CFrame.Angles(0, i * 0.8, 0), i * 2.6)
		end
	end
	for i = 1, 12 do
		local t = (i / 12) * 2 - 1
		local lip = HALF_W - BAND_OUT + 3 + ((i * 3) % 5) - 2
		if i % 3 ~= 2 then
			flowerBed(CFrame.new(lip, 0, t * (HALF_D - 32)) * CFrame.Angles(0, i * 1.4, 0), i * 1.9)
		end
		if i % 4 ~= 0 then
			flowerBed(CFrame.new(-lip, 0, t * (HALF_D - 32) + 5) * CFrame.Angles(0, i * 0.6, 0), i * 3.1)
		end
	end

	-- ------------------------------------------------- open meadow dressing
	-- Sparse only: the clearings are the capture field and stay walkable.
	for i = 1, 26 do
		local x = ((i * 71) % 197 - 98) * 1.06
		local z = ((i * 43) % 131 - 65) * 0.98
		local clearOfMill = math.abs(math.abs(x) - MILL_X) > 24 or math.abs(z - MILL_Z) > 24
		if math.abs(x) > PATH_HALF + 8 and math.abs(x) < HALF_W - BAND_OUT - 4
			and math.abs(z) < HALF_D - BAND_OUT - 2 and clearOfMill then
			local at = CFrame.new(x, 0, z) * CFrame.Angles(0, i * 1.3, 0)
			if i % 4 == 0 then
				flowerBed(at, i * 2.1)
			else
				tuft(at, 0.8 + (i % 3) * 0.2)
			end
		end
	end
	-- the one rustic edge prop the concept keeps, a little barrel by the wall
	local barrel = CFrame.new(HALF_W - 30, 0, -34) * CFrame.Angles(0, 0.4, 0)
	pillar("MeadowBarrel", 4.8, 4.6, barrel * CFrame.new(0, 2.3, 0), TIMBER, Enum.Material.WoodPlanks, true, decor)
	pillar("MeadowBarrelBand", 5.1, 0.55, barrel * CFrame.new(0, 1.2, 0), TIMBER_DARK, Enum.Material.Wood, false, decor)
	pillar("MeadowBarrelBand", 5.1, 0.55, barrel * CFrame.new(0, 3.5, 0), TIMBER_DARK, Enum.Material.Wood, false, decor)
	pillar("MeadowBarrelTop", 4.4, 0.4, barrel * CFrame.new(0, 4.7, 0), rgb(154, 114, 70), Enum.Material.WoodPlanks, false, decor)

	parent:SetAttribute("SceneryVersion", 4)
	GardenBayProps.apply(parent, frame, "Wind")
	BroadleafProps.apply(parent, frame)

	-- What the rest of the game needs to know about this shape: the open grass
	-- rectangle, and the two windmills standing in the middle of it. Given in
	-- world axes relative to the region centre, so callers need no local frame.
	local millOffset = frame:VectorToWorldSpace(V(MILL_X, 0, MILL_Z))
	return {
		field = Vector3.new(HALF_W - BAND_OUT - 6, 0, HALF_D - BAND_OUT - 6),
		keepOut = {
			-- 28, not 24: the sails reach 21 out and the crate sits 22 out, so a
			-- tighter circle let creatures graze both.
			{ at = millOffset, radius = 28 },
			{ at = Vector3.new(-millOffset.X, 0, millOffset.Z), radius = 28 },
			-- the road itself: creatures belong on the grass either side of it
			{ at = Vector3.zero, radius = 0, lane = PATH_HALF + 5 },
		},
	}
end

return Gardens
