--!strict
-- Orbit Outpost, the approved "V7 Gravity Garden" blockout. The concept is
-- docs/art/regions/2026-09-21-orbit-outpost/orbit-outpost-v7-gravity-garden.png
-- and the brief beside it is ORBIT-OUTPOST-CLAUDE-HANDOFF.md; the measured
-- contract Codex fits art against is ORBIT-OUTPOST-LAYOUT.md in the same folder.
-- Every number here is local to the frame RegionScenery supplies.
--
-- Local -Z is the hub entrance (the gate sits at z = -80), +Z the rear, and +X
-- the player's LEFT on walking in: the field laboratory is on +X, the teal
-- utility nook on -X, the gravity cradle across the rear.
--
-- There is deliberately NO ground skin. The Gravity Pulse telegraph is a disc
-- 0.3 studs thick centred 0.16 above the creature, so it spans y 0.01 .. 0.31
-- against the region ground's 0.30 top: a skin of any thickness buries it.
-- The lunar floor is the region `Ground` disc itself, recoloured and given a
-- Sand material in MapBuilder/Regions, so the walking height stays 0.30 and the
-- telegraph still reads. `SURFACE` below is that height, not a surface we own.
--
-- Three sibling Models split the output. Boundary is containment and must
-- survive an art pass: the rock cores, the invisible barrier fields behind the
-- energy panes, the gate shoulders, the entry pillar cores and the lab core.
-- Walkways are the functional walking surfaces: the gravity dais, its two
-- flights, the lab pad, the three dock pads and the utility pad. Landmarks are
-- replaceable placeholder art, and every Codex asset site inside `PropSites` is
-- its own Model carrying AssetName / AssetSize / GroundCF / PivotMode /
-- CollisionRole / PlacementRole / SupportPath, with its stand-in confined to a
-- `PlaceholderArt` child.
local OrbitOutpost = {}
local V = Vector3.new
local rgb = Color3.fromRGB

local SLATE = Enum.Material.Slate
local ROCK_MAT = Enum.Material.Rock
local SMOOTH = Enum.Material.SmoothPlastic
local MARBLE = Enum.Material.Marble
local METAL = Enum.Material.Metal
local GLASS_MAT = Enum.Material.Glass
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass

-- Violet-grey lunar tones. The Gravity Pulse telegraph is a pale lavender
-- (210, 150, 255) drawn on the floor, so nothing on or near the catching field
-- goes bright violet: the soil family below is deliberately desaturated and
-- darker, and every amethyst accent lives beyond radius 54.
local ROCK = rgb(96, 89, 112)
local ROCK_DK = rgb(76, 70, 92)
local ROCK_LT = rgb(129, 121, 146)
local ROCK_WARM = rgb(112, 102, 124)
local IVORY = rgb(228, 225, 234)
local IVORY_DK = rgb(193, 190, 203)
local IVORY_SH = rgb(158, 155, 172)
local AMETHYST = rgb(140, 94, 198)
local AMETHYST_LT = rgb(178, 134, 228)
local AMETHYST_DK = rgb(98, 64, 142)
local CYAN = rgb(128, 226, 234)
local CYAN_DK = rgb(70, 156, 176)
local TEAL = rgb(44, 118, 122)
local TEAL_DK = rgb(29, 84, 90)
local WARM = rgb(255, 214, 138)
local LAMP = rgb(255, 226, 172)
local BLOOM = rgb(126, 206, 196)
local BLOOM_DK = rgb(84, 152, 150)
local GLASS_TINT = rgb(156, 214, 228)
local STEEL = rgb(132, 141, 152)

-- Authored heights, measured from the region ground plane.
local SURFACE = 0.30 -- MapBuilder's `Ground` disc top; this module never raises it
local DAIS_TOP = 5.0
local LAB_TOP = 2.0
local DOCK_TOP = 1.2
local NOOK_TOP = 0.9
local SEGMENTS = 36

-- Exact exported bounds from assets/orbit-outpost/props-v1/manifest.json. The
-- placeholder built inside each site reproduces its bounding box one for one.
local CRADLE = V(16, 22, 16)
local METEOR = V(6, 11, 6)
local ORBIT_STONE = V(2.8, 2.4, 2.6)
local BOULDER = V(8, 4, 6)
local CRYSTAL = V(4, 5, 4)
local MUSHROOM_TALL = V(6, 7, 5)
local MUSHROOM_CLUSTER = V(4, 3, 3)
local FERN = V(4, 3, 4)
local STAR_BLOOM = V(3, 1.2, 3)
local DRONE = V(3.2, 2.8, 3.2)
local DOCK = V(5, 1.5, 5)
local POD = V(3, 4, 3)
local BEACON = V(1.2, 3, 1.2)
local LAB_BASE = V(16, 5, 16)
local LAB_DOME = V(16, 6.5, 16)

-- The rock terrace band. It is low either side of the entrance, steps up at the
-- shoulders and stands tall down the sides and across the rear.
--
-- Nothing here is under 9.5 on purpose. A character standing on the 0.30 floor
-- reaches about 7.2 studs, so a terrace top below 7.5 would be one hop onto the
-- containment; the side and rear bands clear the two highest surfaces a player
-- can actually stand on (the 6.8 lab roof and the 5.0 dais) by the same margin.
local function terraceHeight(i: number): number
	if i <= 4 or i >= 32 then
		return 9.5 + (i % 3) * 0.9
	elseif i <= 6 or i >= 30 then
		return 12.6 + (i % 2) * 0.8
	end
	return 16.0 + (i % 5) * 1.1
end

-- How tall the energy barrier above each terrace is. The low run carries the
-- most glass, so the skyline stays even at roughly 19 to 26 studs all round.
local function barrierHeight(i: number): number
	if i <= 4 or i >= 32 then
		return 9.5
	elseif i <= 6 or i >= 30 then
		return 8.0
	end
	return 6.0
end

local function pad2(n: number): string
	return if n < 10 then "0" .. tostring(n) else tostring(n)
end

function OrbitOutpost.build(parent: Model, frame: CFrame, radius: number, makePart: (any) -> Part)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = parent
	local walkways = Instance.new("Model")
	walkways.Name = "Walkways"
	walkways.Parent = parent
	local decor = Instance.new("Model")
	decor.Name = "Landmarks"
	decor.Parent = parent

	-- Decoration defaults to CanQuery false with CanCollide, so no placeholder
	-- and no energy pane can absorb a capture ray or one of the 27 sightlines
	-- the harness casts at the region board.
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		return makePart({ name = name, size = size, cf = frame * cf, color = color,
			material = material or SLATE, collide = solid == true,
			query = solid == true, parent = host or decor })
	end
	local function disc(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		local p = part(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, solid, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function ball(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local p = part(name, size, cf, color, material, false, host)
		p.Shape = Enum.PartType.Ball
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	-- A squashed sphere. A Roblox Ball part is always a true sphere of its
	-- largest axis, so anything that is not round needs the mesh, exactly as
	-- RegionSign builds its board studs.
	local function ellipsoid(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local extent = math.max(size.X, size.Y, size.Z)
		local p = ball(name, V(extent, extent, extent), cf, color, material, host)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = size / extent
		mesh.Parent = p
		return p
	end
	-- A frame on the boundary ring at bearing `a` radians: +X runs tangentially
	-- in the direction of increasing bearing, +Z points inward at the centre.
	local function ring(a: number, r: number): CFrame
		return CFrame.new(math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, -a, 0)
	end
	local function bearing(degrees: number, r: number): CFrame
		return ring(math.rad(degrees), r)
	end
	local function flat(p: Part): Part
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	local function glow(p: Part, brightness: number, range: number): Part
		flat(p)
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Brightness = brightness
		light.Range = range
		light.Shadows = false
		light.Parent = p
		return p
	end
	local function group(host: Instance, name: string): Model
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = host
		return m
	end
	-- A chunky lunar rock: one block cocked off axis, so a row of them never
	-- reads as a row of boxes. Always decoration, never collision.
	local function rock(name: string, size: Vector3, cf: CFrame, color: Color3, host: Instance?): Part
		return flat(part(name, size, cf * CFrame.Angles(0.07, size.X * 0.21, 0.11), color, ROCK_MAT, false, host))
	end

	-- ------------------------------------------------------------ prop sites
	-- One Model per Codex asset. GroundCF is the bottom-centre placement frame
	-- in region-local space, so a MeshPart goes at
	-- `frame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)`. A suspended asset
	-- records its intended lower extent there and names the landmark it hangs
	-- against; nothing is ever unanchored.
	local sites = group(decor, "PropSites")
	sites:SetAttribute("AssetKit", "assets/orbit-outpost/props-v1")
	sites:SetAttribute("AssetOrigin", "bottom-centre")
	local counts: { [string]: number } = {}
	local siteTotal = 0
	local function place(prefix: string, asset: string, size: Vector3, cf: CFrame, role: string, support: string, stackOn: string?): Model
		local n = (counts[prefix] or 0) + 1
		counts[prefix] = n
		siteTotal += 1
		local m = group(sites, prefix .. pad2(n))
		m:SetAttribute("AssetName", asset)
		m:SetAttribute("AssetSize", size)
		m:SetAttribute("GroundCF", cf)
		m:SetAttribute("PivotMode", "BottomCenter")
		m:SetAttribute("CollisionRole", "none")
		m:SetAttribute("PlacementRole", role)
		m:SetAttribute("SupportPath", support)
		if stackOn then
			m:SetAttribute("StackOnSite", stackOn)
		end
		-- Every visible stand-in lives in here and only in here, so replacing
		-- art never touches the site, its metadata or any permanent geometry.
		return group(m, "PlaceholderArt")
	end

	-- --------------------------------------------------------- rock terraces
	-- One continuous ring of asymmetric rock terraces with the entrance cut out
	-- of it. The solid core is the containment; above it an invisible
	-- `BarrierField` fills exactly the volume the cyan energy pane occupies, so
	-- the barrier reads as glass and still closes the ring when the pane is
	-- replaced. Pane and post are decoration and neither collides nor queries.
	local chord = 2 * radius * math.tan(math.pi / SEGMENTS) + 0.5
	local barrier = group(decor, "EnergyBarrier")
	local terraces = group(decor, "RockTerraces")
	for i = 2, SEGMENTS - 2 do
		local a = i * math.pi * 2 / SEGMENTS
		local cf = ring(a, radius)
		local h = terraceHeight(i)
		local fh = barrierHeight(i)
		part("Perimeter", V(chord, h, 3.0), cf * CFrame.new(0, h / 2, 0), ROCK, ROCK_MAT, true, boundary)
		-- The field starts 0.3 inside the rock top, so a probe can never slip
		-- between the two, and stops well short of a jump from anywhere inside.
		local field = part("BarrierField", V(chord, fh, 1.3), cf * CFrame.new(0, h - 0.3 + fh / 2, 0), CYAN, SMOOTH, true, boundary)
		field.Transparency = 1
		field.CastShadow = false
		local pane = flat(part("BarrierPane", V(chord - 1.8, fh - 1.2, 0.34), cf * CFrame.new(0, h - 0.3 + fh / 2, 0), CYAN, GLASS_MAT, false, barrier))
		pane.Transparency = 0.62
		-- Pale stone posts on the segment joins carry the panes in the concept.
		local post = ring(a + math.pi / SEGMENTS, radius)
		flat(part("BarrierPost", V(1.6, fh + 1.4, 1.9), post * CFrame.new(0, h - 0.5 + (fh + 1.4) / 2, 0), IVORY_DK, MARBLE, false, barrier))
		flat(part("BarrierPostLamp", V(0.34, fh - 1.6, 0.3), post * CFrame.new(0, h - 0.3 + fh / 2, 1.05), CYAN, NEON, false, barrier))
		-- Every third segment gets a shelf and a pair of boulders in front, so
		-- the terrace line breaks up instead of reading as a fence.
		if i % 3 == 0 then
			flat(part("TerraceShelf", V(chord * 0.7, 1.4, 4.6), cf * CFrame.new(0, h - 1.6, 1.9), ROCK_LT, ROCK_MAT, false, terraces))
			rock("TerraceRock", V(6.4, h * 0.55, 5.2), cf * CFrame.new(-3.0, h * 0.26, 3.1), ROCK_DK, terraces)
			rock("TerraceRock", V(5.0, h * 0.4, 4.4), cf * CFrame.new(3.4, h * 0.19, 3.6), ROCK_WARM, terraces)
		elseif i % 3 == 1 then
			rock("TerraceRock", V(5.6, h * 0.45, 4.8), cf * CFrame.new(1.2, h * 0.21, 3.2), ROCK_DK, terraces)
		end
	end
	-- Angled shoulders close the ring either side of the entrance opening.
	-- Both lookAt points share y = 5, so the default up vector is never parallel.
	for _, side in { -1, 1 } do
		-- 11.8, not 11.5: at 11.5 the 3.4-deep core's inner face landed at 9.8 and
		-- pinched the 20-stud doorway to 19.44.
		local from = V(side * 11.8, 5, -80)
		local to = V(side * math.sin(math.pi / 9) * radius, 5, -math.cos(math.pi / 9) * radius)
		local run = (to - from).Magnitude + 2
		local along = CFrame.lookAt((from + to) / 2, to)
		part("GateShoulder", V(3.4, 13.0, run), along * CFrame.new(0, 1.5, 0), ROCK, ROCK_MAT, true, boundary)
		local field = part("ShoulderField", V(3.4, 8.4, run), along * CFrame.new(0, 12.2, 0), CYAN, SMOOTH, true, boundary)
		field.Transparency = 1
		field.CastShadow = false
		local pane = flat(part("ShoulderPane", V(0.34, 7.2, run - 2.4), along * CFrame.new(0, 12.2, 0), CYAN, GLASS_MAT, false, barrier))
		pane.Transparency = 0.62
		-- Banked against the inside of the shoulder, and placed in region-local
		-- coordinates rather than on the shoulder's own frame: rolled onto that
		-- frame they leaned back into the 20-stud approach corridor.
		rock("ShoulderRock", V(6.0, 6.4, 5.4), CFrame.new(side * 19.0, 1.4, -70.5), ROCK_DK, terraces)
		rock("ShoulderRock", V(5.2, 5.0, 4.6), CFrame.new(side * 23.5, 0.9, -62.0), ROCK_WARM, terraces)
	end

	-- --------------------------------------------------------------- entrance
	-- Two stout ivory research pillars either side of the existing Gate, with a
	-- warm strip sunk into each inward face. There is no lintel: the concept
	-- frames the way in with the pair alone, which is why Cosmic joins
	-- MapBuilder's OWN_ENTRANCE set and its post/lintel/hazard trim is skipped.
	-- Nothing here reaches the board box (x 15..33, z -90.33..-89.68) or the
	-- wedge its sightlines sweep: the pillars stand ten studs further in.
	local entry = group(decor, "ResearchGateway")
	for _, side in { -1, 1 } do
		local x = side * 13
		part("EntryPillarCore", V(5.6, 15, 4.4), CFrame.new(x, 7.2, -80), IVORY_SH, MARBLE, true, boundary)
		flat(part("PillarFoot", V(6.0, 1.6, 6.0), CFrame.new(x, 0.5, -80), IVORY_SH, MARBLE, false, entry))
		flat(part("PillarShaft", V(4.8, 11.4, 4.8), CFrame.new(x, 7.0, -80), IVORY, MARBLE, false, entry))
		flat(part("PillarChamfer", V(5.2, 1.1, 5.2), CFrame.new(x, 2.1, -80), IVORY_DK, MARBLE, false, entry))
		flat(part("PillarCap", V(5.4, 1.8, 5.4), CFrame.new(x, 13.9, -80), IVORY_DK, MARBLE, false, entry))
		flat(part("PillarCrown", V(3.6, 1.5, 3.6), CFrame.new(x, 15.55, -80) * CFrame.Angles(0, math.pi / 4, 0), IVORY, MARBLE, false, entry))
		glow(part("PillarLamp", V(0.36, 6.6, 0.9), CFrame.new(side * 10.55, 7.0, -80), WARM, NEON, false, entry), 1.2, 22)
		flat(part("PillarPlate", V(1.7, 2.1, 0.22), CFrame.new(x, 10.6, -82.25), IVORY_DK, METAL, false, entry))
		rock("GatewayRock", V(6.8, 4.4, 5.6), CFrame.new(side * 19.5, 1.5, -77.5), ROCK_DK, entry)
	end

	-- ----------------------------------------------------------- gravity dais
	-- The rear hero. A raised rock dais carries the three-pronged cradle, the
	-- meteor hangs inside it and three orbit stones float clear of the prongs.
	-- The dais is 21 x 16 at z 63.5, not the brief's 23 x 19 at z 63: a 23 x 19
	-- slab there reaches radius 73.4 at its back corners, 0.1 inside the rock
	-- terrace face at 73.5, and its front face would sit at 53.5 inside the
	-- flat field. This footprint keeps 55.5 in front and 1.6 behind.
	local garden = group(decor, "GravityGarden")
	part("GravityDais", V(21, 5.4, 16), CFrame.new(0, DAIS_TOP - 2.7, 63.5), ROCK_LT, ROCK_MAT, true, walkways)
	flat(part("DaisRim", V(21.5, 0.5, 16.5), CFrame.new(0, DAIS_TOP - 0.4, 63.5), ROCK_DK, ROCK_MAT, false, garden))
	flat(part("DaisSkirt", V(19.6, 2.2, 14.6), CFrame.new(0, 1.3, 63.5), ROCK, ROCK_MAT, false, garden))
	for _, side in { -1, 1 } do
		flat(part("DaisButtress", V(2.2, 3.4, 3.0), CFrame.new(side * 9.0, 1.9, 56.6), ROCK_DK, ROCK_MAT, false, garden))
		flat(part("DaisButtress", V(2.2, 3.4, 3.0), CFrame.new(side * 9.0, 1.9, 70.4), ROCK_DK, ROCK_MAT, false, garden))
	end
	-- Two tangential flights up the dais sides. Neither runs down into the
	-- capture field: they climb front to back along the flanks, and their
	-- footprints sit between radius 58.4 and 72.2.
	for _, side in { -1, 1 } do
		for k = 1, 8 do
			local top = SURFACE + k * 0.5825
			part("DaisStep", V(5.0, top, 1.625), CFrame.new(side * 13.0, top / 2, 57.5 + (k - 0.5) * 1.625), ROCK_LT, ROCK_MAT, true, walkways)
		end
		flat(part("DaisStepRail", V(0.26, 0.26, 13.6), CFrame.new(side * 15.4, 4.1, 64.0) * CFrame.Angles(-0.304, 0, 0), IVORY_DK, METAL, false, garden))
		flat(part("DaisStepNewel", V(0.4, 3.0, 0.4), CFrame.new(side * 15.4, 1.6, 58.0), IVORY_DK, METAL, false, garden))
		flat(part("DaisStepNewel", V(0.4, 3.0, 0.4), CFrame.new(side * 15.4, 6.2, 70.0), IVORY_DK, METAL, false, garden))
	end
	-- The cradle, the meteor it holds and the stones orbiting them. The meteor
	-- and the stones are suspended on purpose and stay anchored for ever; the
	-- cradle's own bounding box contains all four, which is the concept.
	local cradleCF = CFrame.new(0, DAIS_TOP, 63.5) * CFrame.Angles(0, math.pi, 0)
	local cradleArt = place("GravityCradle", "OO_Gravity_Cradle", CRADLE, cradleCF, "Grounded", "Walkways/GravityDais")
	for _, side in { -1, 1 } do
		flat(part("CradleProng", V(2.6, 20.0, 3.0), cradleCF * CFrame.new(side * 5.6, 10.6, 1.2) * CFrame.Angles(0, 0, side * 0.16), IVORY, MARBLE, false, cradleArt))
		flat(part("CradleFoot", V(4.4, 1.8, 5.2), cradleCF * CFrame.new(side * 5.2, 0.9, 1.2), IVORY_DK, MARBLE, false, cradleArt))
	end
	flat(part("CradleProng", V(2.6, 20.0, 3.0), cradleCF * CFrame.new(0, 10.6, -5.6) * CFrame.Angles(-0.16, 0, 0), IVORY, MARBLE, false, cradleArt))
	flat(part("CradleFoot", V(4.4, 1.8, 5.2), cradleCF * CFrame.new(0, 0.9, -5.4), IVORY_DK, MARBLE, false, cradleArt))
	flat(part("CradleCollar", V(13.2, 1.2, 13.2), cradleCF * CFrame.new(0, 21.0, 0), IVORY_DK, MARBLE, false, cradleArt))
	local meteorArt = place("GravityMeteor", "OO_Gravity_Meteor", METEOR, CFrame.new(0, 12.0, 63.5) * CFrame.Angles(0, 0.5, 0),
		"Suspended", "Landmarks/PropSites/GravityCradle01")
	glow(part("MeteorMass", V(5.4, 10.2, 5.4), CFrame.new(0, 17.5, 63.5) * CFrame.Angles(0.2, 0.5, 0.15), AMETHYST, SMOOTH, false, meteorArt), 1.6, 34)
	for _, spec in { { -5.5, 15.0, 63.5 }, { 5.5, 15.0, 63.5 }, { 0, 24.3, 63.5 } } do
		local sx, sy, sz = spec[1], spec[2], spec[3]
		local stoneArt = place("OrbitStone", "OO_Orbit_Stone", ORBIT_STONE, CFrame.new(sx, sy, sz) * CFrame.Angles(0, sx * 0.3, 0),
			"Suspended", "Landmarks/PropSites/GravityCradle01")
		rock("OrbitStoneMass", V(2.6, 2.2, 2.4), CFrame.new(sx, sy + 1.2, sz), ROCK_DK, stoneArt)
	end

	-- ------------------------------------------------------------- field lab
	-- Image left: a closed round laboratory on a permanent pad. `LabCore` in
	-- Boundary is the collision that outlives the mesh; `LabGlazing` is the
	-- transparent shell the open dome ribs are meant to carry, and it is kept
	-- through the art pass. There is no door, no prompt and no interior.
	local labCF = bearing(114, 63.25)
	local lab = group(decor, "FieldLaboratory")
	part("LabPad", V(21, 2.4, 17), labCF * CFrame.new(0, LAB_TOP - 1.2, 0), ROCK_LT, ROCK_MAT, true, walkways)
	flat(part("LabPadRim", V(21.5, 0.45, 17.5), labCF * CFrame.new(0, LAB_TOP - 0.35, 0), ROCK_DK, ROCK_MAT, false, lab))
	flat(part("LabPadNosing", V(21.5, 0.16, 0.7), labCF * CFrame.new(0, LAB_TOP - 0.02, 8.2), IVORY_SH, MARBLE, false, lab))
	local labCore = part("LabCore", V(15.6, 4.8, 15.6), labCF * CFrame.new(0, LAB_TOP + 2.4, 0), IVORY_SH, MARBLE, true, boundary)
	-- The square collision proxy must not cover the round imported facade.
	labCore.Transparency = 1
	local labArt = place("FieldLabBase", "OO_Field_Lab_Base", LAB_BASE, labCF * CFrame.new(0, LAB_TOP, 0), "Grounded", "Walkways/LabPad")
	flat(part("LabSkirt", V(16, 1.0, 16), labCF * CFrame.new(0, LAB_TOP + 0.5, 0), IVORY_DK, MARBLE, false, labArt))
	flat(part("LabWall", V(15.8, 3.6, 15.8), labCF * CFrame.new(0, LAB_TOP + 2.9, 0), IVORY, MARBLE, false, labArt))
	flat(part("LabCornice", V(16, 0.8, 16), labCF * CFrame.new(0, LAB_TOP + 4.6, 0), IVORY_DK, MARBLE, false, labArt))
	-- Two of the six PointLights this region is allowed. The middle window is
	-- lit geometry only, so the warm glow reads without a third emitter.
	for _, x in { -4.6, 0, 4.6 } do
		local window = part("LabWindow", V(2.8, 2.0, 0.4), labCF * CFrame.new(x, LAB_TOP + 2.9, 7.95), WARM, NEON, false, labArt)
		if x == 0 then flat(window) else glow(window, 0.9, 18) end
	end
	local domeArt = place("FieldLabDome", "OO_Field_Lab_Dome_Frame", LAB_DOME, labCF * CFrame.new(0, LAB_TOP + 5, 0),
		"Stacked", "Walkways/LabPad", "FieldLabBase01")
	for k = 0, 5 do
		local a = k * math.pi / 3
		flat(part("DomeRib", V(0.5, 6.6, 0.5), labCF * CFrame.new(math.sin(a) * 6.4, LAB_TOP + 8.1, math.cos(a) * 6.4) * CFrame.Angles(math.cos(a) * 0.5, 0, -math.sin(a) * 0.5), IVORY, MARBLE, false, domeArt))
	end
	flat(part("DomeCrown", V(3.2, 0.6, 3.2), labCF * CFrame.new(0, LAB_TOP + 6.3, 0), IVORY_DK, MARBLE, false, domeArt))
	-- Inset the glazing beneath the imported dome ribs to avoid intersecting faces.
	-- Its lower half is inside the opaque base and the solid core, which is how
	-- a Roblox dome is made; no opaque dummy dome geometry fights the ribs.
	local glazing = ellipsoid("LabGlazing", V(15.4, 12.4, 15.4), labCF * CFrame.new(0, LAB_TOP + 5, 0), GLASS_TINT, GLASS_MAT, lab)
	glazing.Transparency = 0.58

	-- ----------------------------------------------------------- survey docks
	-- Three drone pads in the arcs the dais, the lab and the nook leave free.
	-- Each pad carries a dock, a drone stacked on it and one garden site.
	local docks = group(decor, "SurveyDocks")
	local dockSpec = { { 67, "A" }, { 222, "B" }, { 255, "C" } }
	for index, spec in dockSpec do
		local deg, tag = spec[1] :: number, spec[2] :: string
		local at = bearing(deg, 61)
		part("DockPad" .. tag, V(13, 1.5, 11), at * CFrame.new(0, DOCK_TOP - 0.75, 0), ROCK_LT, ROCK_MAT, true, walkways)
		flat(part("DockPadRim", V(13.4, 0.36, 11.4), at * CFrame.new(0, DOCK_TOP - 0.28, 0), ROCK_DK, ROCK_MAT, false, docks))
		flat(part("DockPadInlay", V(6.4, 0.14, 6.4), at * CFrame.new(0, DOCK_TOP + 0.02, -1.0), IVORY_SH, MARBLE, false, docks))
		local dockArt = place("DroneDock", "OO_Drone_Dock", DOCK, at * CFrame.new(0, DOCK_TOP, -1.0), "Grounded", "Walkways/DockPad" .. tag)
		flat(part("DockPlate", V(5, 1.1, 5), at * CFrame.new(0, DOCK_TOP + 0.55, -1.0), IVORY_DK, MARBLE, false, dockArt))
		flat(part("DockRing", V(4.2, 0.45, 4.2), at * CFrame.new(0, DOCK_TOP + 1.28, -1.0), CYAN_DK, METAL, false, dockArt))
		local droneArt = place("SurveyDrone", "OO_Survey_Drone", DRONE, at * CFrame.new(0, DOCK_TOP + 1.5, -1.0),
			"Stacked", "Walkways/DockPad" .. tag, "DroneDock" .. pad2(index))
		ellipsoid("DroneShell", V(3.2, 2.8, 3.2), at * CFrame.new(0, DOCK_TOP + 2.9, -1.0), IVORY, MARBLE, droneArt)
		flat(part("DroneLens", V(1.5, 1.5, 0.5), at * CFrame.new(0, DOCK_TOP + 2.9, 0.4), CYAN, NEON, false, droneArt))
		flat(part("DroneBand", V(3.3, 0.35, 3.3), at * CFrame.new(0, DOCK_TOP + 2.0, -1.0), IVORY_SH, METAL, false, droneArt))
		local podArt = place("SamplePod", "OO_Sample_Pod", POD, at * CFrame.new(4.6, DOCK_TOP, 2.4) * CFrame.Angles(0, -0.3, 0), "Grounded", "Walkways/DockPad" .. tag)
		flat(part("PodBase", V(3, 0.6, 3), at * CFrame.new(4.6, DOCK_TOP + 0.3, 2.4), IVORY_DK, MARBLE, false, podArt))
		flat(part("PodBody", V(2.6, 3.0, 2.6), at * CFrame.new(4.6, DOCK_TOP + 2.1, 2.4), IVORY, MARBLE, false, podArt))
		flat(part("PodLid", V(3, 0.5, 3), at * CFrame.new(4.6, DOCK_TOP + 3.75, 2.4), CYAN_DK, METAL, false, podArt))
	end

	-- ------------------------------------------------------------ utility nook
	-- The teal service kit from the older regions, kept small and pushed into
	-- one corner so it cannot compete with the garden. This is blockout only:
	-- the Thunderworks meshes are not part of the Orbit Outpost kit, so nothing
	-- here claims an asset site.
	local nookCF = bearing(304, 63)
	local nook = group(decor, "UtilityNook")
	part("NookPad", V(16, 1.2, 11), nookCF * CFrame.new(0, NOOK_TOP - 0.6, 0), ROCK_LT, ROCK_MAT, true, walkways)
	flat(part("NookRim", V(16.4, 0.3, 11.4), nookCF * CFrame.new(0, NOOK_TOP - 0.2, 0), ROCK_DK, ROCK_MAT, false, nook))
	flat(part("NookCabinet", V(3.4, 4.2, 2.0), nookCF * CFrame.new(-4.8, NOOK_TOP + 2.1, -2.2), TEAL, METAL, false, nook))
	flat(part("NookCabinet", V(3.4, 4.2, 2.0), nookCF * CFrame.new(-1.0, NOOK_TOP + 2.1, -2.2), TEAL_DK, METAL, false, nook))
	flat(part("NookCabinetLid", V(7.6, 0.5, 2.2), nookCF * CFrame.new(-2.9, NOOK_TOP + 4.45, -2.2), STEEL, METAL, false, nook))
	flat(part("NookTank", V(4.6, 3.4, 3.8), nookCF * CFrame.new(3.6, NOOK_TOP + 1.7, -1.8), TEAL, METAL, false, nook))
	flat(part("NookTankLid", V(4.8, 0.7, 4.0), nookCF * CFrame.new(3.6, NOOK_TOP + 3.75, -1.8), STEEL, METAL, false, nook))
	flat(disc("NookReelDrum", 2.8, 1.8, nookCF * CFrame.new(6.4, NOOK_TOP + 1.6, 2.6) * CFrame.Angles(math.pi / 2, 0, 0), TEAL_DK, METAL, false, nook))
	for _, side in { -1, 1 } do
		flat(part("NookCanopyPost", V(0.5, 4.6, 0.5), nookCF * CFrame.new(side * 6.6, NOOK_TOP + 2.3, -3.6), STEEL, METAL, false, nook))
	end
	flat(part("NookCanopy", V(14.6, 0.4, 4.4), nookCF * CFrame.new(0, NOOK_TOP + 4.7, -2.6), STEEL, METAL, false, nook))
	glow(part("NookLamp", V(2.4, 0.3, 1.2), nookCF * CFrame.new(0, NOOK_TOP + 4.42, -2.6), LAMP, NEON, false, nook), 0.9, 16)
	flat(part("NookCrate", V(2.2, 1.8, 2.2), nookCF * CFrame.new(-6.2, NOOK_TOP + 0.9, 2.8) * CFrame.Angles(0, 0.4, 0), TEAL_DK, METAL, false, nook))
	flat(part("NookCrate", V(1.8, 1.5, 1.8), nookCF * CFrame.new(-3.6, NOOK_TOP + 0.75, 3.2) * CFrame.Angles(0, -0.25, 0), TEAL, METAL, false, nook))

	-- -------------------------------------------------------- garden dressing
	-- Everything below stands on the region ground between radius 55 and 71, in
	-- the arcs the four landmarks leave open. Nothing stands inside the flat
	-- field: the catching space keeps its telegraphs unobstructed, and the only
	-- thing near the entrance road is a pair of beacons 3.2 studs off its edge.
	local plants = group(decor, "LunarGarden")

	local function boulder(deg: number, r: number, yaw: number)
		local at = bearing(deg, r) * CFrame.Angles(0, yaw, 0)
		local art = place("LunarBoulder", "OO_Lunar_Boulder", BOULDER, at * CFrame.new(0, SURFACE, 0), "Grounded", "Ground")
		rock("BoulderMass", V(7.6, 3.6, 5.6), at * CFrame.new(0, SURFACE + 1.9, 0), ROCK_DK, art)
		rock("BoulderChip", V(3.4, 1.6, 2.6), at * CFrame.new(1.9, SURFACE + 0.8, 1.4), ROCK_WARM, art)
	end
	local function crystal(deg: number, r: number, yaw: number)
		local at = bearing(deg, r) * CFrame.Angles(0, yaw, 0)
		local art = place("CrystalCluster", "OO_Crystal_Cluster", CRYSTAL, at * CFrame.new(0, SURFACE, 0), "Grounded", "Ground")
		rock("CrystalBase", V(3.8, 1.1, 3.8), at * CFrame.new(0, SURFACE + 0.55, 0), ROCK_DK, art)
		flat(part("CrystalShard", V(1.2, 3.6, 1.2), at * CFrame.new(-0.7, SURFACE + 2.6, 0.3) * CFrame.Angles(0.16, 0.5, -0.2), AMETHYST, GLASS_MAT, false, art))
		flat(part("CrystalShard", V(0.9, 2.6, 0.9), at * CFrame.new(0.9, SURFACE + 2.1, -0.4) * CFrame.Angles(-0.2, 0.2, 0.22), AMETHYST_LT, GLASS_MAT, false, art))
	end
	local function mushroomTall(deg: number, r: number, yaw: number)
		local at = bearing(deg, r) * CFrame.Angles(0, yaw, 0)
		local art = place("MushroomTall", "OO_Alien_Mushroom_Tall", MUSHROOM_TALL, at * CFrame.new(0, SURFACE, 0), "Grounded", "Ground")
		flat(disc("MushroomStalk", 1.5, 4.6, at * CFrame.new(0, SURFACE + 2.3, 0), IVORY_DK, SMOOTH, false, art))
		flat(part("MushroomCap", V(5.8, 1.6, 4.8), at * CFrame.new(0, SURFACE + 5.6, 0), AMETHYST, SMOOTH, false, art))
		flat(part("MushroomGill", V(4.6, 0.5, 3.8), at * CFrame.new(0, SURFACE + 4.7, 0), AMETHYST_DK, SMOOTH, false, art))
		flat(part("MushroomCrown", V(3.4, 1.0, 2.8), at * CFrame.new(0, SURFACE + 6.6, 0), AMETHYST_LT, SMOOTH, false, art))
	end
	local function mushroomCluster(deg: number, r: number, yaw: number)
		local at = bearing(deg, r) * CFrame.Angles(0, yaw, 0)
		local art = place("MushroomCluster", "OO_Alien_Mushroom_Cluster", MUSHROOM_CLUSTER, at * CFrame.new(0, SURFACE, 0), "Grounded", "Ground")
		for _, spec in { { -1.1, 0.6, 1.9, 1.5 }, { 0.8, -0.7, 2.6, 1.9 } } do
			flat(disc("ClusterStalk", 0.8, spec[3] * 0.6, at * CFrame.new(spec[1], SURFACE + spec[3] * 0.3, spec[2]), IVORY_DK, SMOOTH, false, art))
			flat(part("ClusterCap", V(spec[4], 0.8, spec[4] * 0.85), at * CFrame.new(spec[1], SURFACE + spec[3] * 0.72, spec[2]), AMETHYST, SMOOTH, false, art))
		end
	end
	local function fern(deg: number, r: number, yaw: number)
		local at = bearing(deg, r) * CFrame.Angles(0, yaw, 0)
		local art = place("AlienFern", "OO_Alien_Fern", FERN, at * CFrame.new(0, SURFACE, 0), "Grounded", "Ground")
		flat(part("FernCore", V(1.0, 1.4, 1.0), at * CFrame.new(0, SURFACE + 0.7, 0), AMETHYST_DK, GRASS, false, art))
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.4
			flat(part("FernLeaf", V(2.4, 0.5, 1.5), at * CFrame.new(math.sin(a) * 0.9, SURFACE + 1.6 + k * 0.14, math.cos(a) * 0.9) * CFrame.Angles(0, -a, 0.42), AMETHYST, GRASS, false, art))
		end
	end
	local function starBloom(deg: number, r: number, yaw: number)
		local at = bearing(deg, r) * CFrame.Angles(0, yaw, 0)
		local art = place("StarBloom", "OO_Star_Bloom_Tuft", STAR_BLOOM, at * CFrame.new(0, SURFACE, 0), "Grounded", "Ground")
		flat(part("BloomMat", V(2.9, 0.3, 2.9), at * CFrame.new(0, SURFACE + 0.15, 0), BLOOM_DK, GRASS, false, art))
		for k, spec in { { -0.8, 0.5 }, { 0.7, -0.6 }, { 0.2, 0.9 } } do
			flat(part("BloomTuft", V(0.9, 0.9, 0.9), at * CFrame.new(spec[1], SURFACE + 0.52 + k * 0.12, spec[2]) * CFrame.Angles(0, spec[1], 0.2), BLOOM, GRASS, false, art))
		end
	end
	local function beacon(cf: CFrame, support: string)
		local art = place("CosmicBeacon", "OO_Cosmic_Beacon", BEACON, cf, "Grounded", support)
		flat(part("BeaconFoot", V(1.2, 0.5, 1.2), cf * CFrame.new(0, 0.25, 0), IVORY_SH, MARBLE, false, art))
		flat(part("BeaconPost", V(0.8, 1.9, 0.8), cf * CFrame.new(0, 1.4, 0), IVORY, MARBLE, false, art))
		flat(part("BeaconLens", V(0.5, 0.9, 0.5), cf * CFrame.new(0, 2.5, 0), CYAN, NEON, false, art))
	end

	-- Two bands, not a scatter. The big growth stands on the outer band at
	-- radius 66.5 and the low growth on the inner one at 58, which guarantees
	-- 0.7 studs of radial clearance between the two whatever their bearings; a
	-- single band had crystals sitting inside boulders. Bearings are at least 8
	-- degrees apart within a band (9.3 studs at 66.5, against the 7.8 an
	-- 8 x 6 boulder needs beside a crystal) and every one of them falls in an
	-- arc the dais, the lab, the three dock pads and the nook leave open.
	local OUTER, INNER = 66.5, 58.0
	for _, spec in { { 20, 0.3 }, { 55, -0.4 }, { 87, 0.8 }, { 139, -0.6 }, { 205, 0.2 }, { 268, -0.9 } } do
		boulder(spec[1], OUTER, spec[2])
	end
	for _, spec in { { 29, 0.4 }, { 47, -0.5 }, { 130, 0.9 }, { 157, -0.2 }, { 237, 0.6 }, { 330, -0.8 } } do
		crystal(spec[1], OUTER, spec[2])
	end
	for _, spec in { { 38, 0.2 }, { 96, -0.6 }, { 148, 0.5 } } do
		mushroomTall(spec[1], OUTER, spec[2])
	end
	for _, spec in { { 44, -0.3 }, { 90, 0.7 }, { 142, -0.5 }, { 241, 0.4 } } do
		mushroomCluster(spec[1], INNER, spec[2])
	end
	for _, spec in { { 26, 0.5 }, { 53, -0.7 }, { 151, 0.3 }, { 272, -0.4 }, { 322, 0.8 } } do
		fern(spec[1], INNER, spec[2])
	end
	for _, spec in { { 35, 0.2 }, { 81, -0.5 }, { 133, 0.7 }, { 209, -0.3 }, { 281, 0.6 } } do
		starBloom(spec[1], INNER, spec[2])
	end
	for _, side in { -1, 1 } do
		-- 11.0, not 10.5: the beacon's 1.2-wide foot has to stay outside the
		-- 20-stud doorway the Gate opens, and it clears the road by 3.65.
		beacon(CFrame.new(side * 11.0, SURFACE, -66) * CFrame.Angles(0, if side > 0 then -math.pi / 2 else math.pi / 2, 0), "Ground")
		beacon(CFrame.new(side * 11.0, SURFACE, -56) * CFrame.Angles(0, if side > 0 then -math.pi / 2 else math.pi / 2, 0), "Ground")
		beacon(CFrame.new(side * 13.0, SURFACE, 55.8), "Ground")
	end

	sites:SetAttribute("AssetCount", siteTotal)
	parent:SetAttribute("SceneryVersion", 3)
	require(script.Parent.OrbitProps).apply(parent, frame)
end

return OrbitOutpost
