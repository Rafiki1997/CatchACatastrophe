--!strict
-- Thunderworks, the "storm-powered industrial yard" blockout. There is no
-- approved concept image for this region; the direction is written down in
-- docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-CLAUDE-HANDOFF.md and
-- the measured contract Codex fits art against is THUNDERWORKS-LAYOUT.md beside
-- it. Every number here is local to the frame RegionScenery supplies.
--
-- Local -Z is the hub entrance (the gate sits at z = -80), +Z the rear, and +X
-- the player's LEFT on walking in: the maintenance catwalk and its cable trench
-- are on +X, the control shed on -X, the collector towers across the rear.
-- The walkable asphalt yard uses the original ground at y = 0.30. Nothing solid
-- stands inside radius 44, and nothing but flush matte scuff inside 58.
--
-- Three sibling Models split the output. Boundary is containment and must
-- survive an art pass. Walkways are the functional walking surfaces:
-- both stair flights, the catwalk deck, the trench covers, the service
-- pads, the shed apron and the generator plinth. Landmarks are replaceable
-- placeholders, and every Codex asset site inside it is its own Model carrying
-- AssetName / AssetSize / GroundCF / CollisionRole.
--
-- The Storm hazard draws pale yellow warning circles (255, 235, 110) on this
-- floor, so the yard stays a dark desaturated blue-grey and no yellow, neon or
-- painted circle goes anywhere near the catching field.
local Thunderworks = {}
local V = Vector3.new
local rgb = Color3.fromRGB

local ASPHALT = Enum.Material.Asphalt
local CONCRETE_MAT = Enum.Material.Concrete
local METAL = Enum.Material.Metal
local PLATE = Enum.Material.DiamondPlate
local SMOOTH = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.Wood
local NEON = Enum.Material.Neon

-- Yard tones stay close together and well away from the hazard's yellow.
local YARD_DARK = rgb(66, 71, 85)
local YARD_SCUFF = rgb(88, 94, 109)
local CONCRETE = rgb(96, 104, 118)
local CONCRETE_LT = rgb(122, 131, 145)
local CONCRETE_DK = rgb(72, 79, 92)
local GRAPHITE = rgb(56, 61, 70)
local GRAPHITE_LT = rgb(84, 90, 101)
local STEEL = rgb(132, 141, 152)
local STEEL_DARK = rgb(95, 103, 114)
local TEAL = rgb(44, 118, 122)
local TEAL_DARK = rgb(29, 84, 90)
local COPPER = rgb(184, 112, 66)
local COPPER_DK = rgb(139, 83, 50)
local CERAMIC = rgb(226, 221, 206)
local CERAMIC_DK = rgb(190, 184, 167)
-- A worn equipment yellow, well down from the hazard telegraph's pale
-- (255, 235, 110) so the two can never be confused. It appears on machinery
-- only, never on the floor.
local WORN_YELLOW = rgb(172, 141, 56)
local LAMP_GLASS = rgb(255, 226, 172)
local WINDOW_WARM = rgb(255, 214, 138)

-- Authored heights, measured from the region ground plane, whose top is y 0.30.
local YARD_TOP = 0.30
local PAD_TOP = 0.67
local APRON_TOP = 0.70
local DECK_TOP = 6.48
local CAT_R = 65

-- Exact exported bounds from assets/thunderworks/props-v1/manifest.json. The
-- placeholder built at each site reproduces its bounding box one for one.
local TRANSFORMER = V(5.8, 6.2, 4.6)
local INSULATOR = V(1.8, 3.0, 1.8)
local CABLE_REEL = V(4.0, 4.4, 3.0)
local CAPACITOR = V(3.4, 4.8, 3.4)
local CABINET = V(3.2, 4.6, 1.8)
local VENT = V(4.0, 2.4, 3.4)
local ELBOW = V(3.0, 2.5, 2.2)
local BOLLARD = V(1.2, 3.0, 1.2)

-- The perimeter's uneven industrial skyline: low either side of the gate, a
-- tall block across the rear behind the collectors, mid everywhere else.
--
-- The side band is 17 and up on purpose. The catwalk kerb tops out at 7.42 and
-- a Roblox character's jump reaches about 7.2 studs, so a 15-stud wall opposite
-- the deck would have been one hop from the coping. Every band clears the
-- highest surface a player can actually stand on beneath it by more than that.
local function wallHeight(i: number): number
	if i <= 5 or i >= 43 then
		return 12.5 + (i % 3) * 0.9
	elseif i >= 19 and i <= 29 then
		return 20.0 + (i % 4) * 1.2
	end
	return 17.0 + (i % 5) * 1.0
end

local function pad2(n: number): string
	return if n < 10 then "0" .. tostring(n) else tostring(n)
end

function Thunderworks.build(parent: Model, frame: CFrame, radius: number, makePart: (any) -> Part)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = parent
	local walkways = Instance.new("Model")
	walkways.Name = "Walkways"
	walkways.Parent = parent
	local decor = Instance.new("Model")
	decor.Name = "Landmarks"
	decor.Parent = parent

	-- Decoration defaults to CanQuery false with CanCollide, so a placeholder can
	-- never absorb one of the 27 sightline rays the harness casts at the board.
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		return makePart({ name = name, size = size, cf = frame * cf, color = color,
			material = material or METAL, collide = solid == true,
			query = solid == true, parent = host or decor })
	end
	local function disc(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		local p = part(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, solid, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- A pipe lying along the local X axis of `cf`, for bus bars and conduit runs.
	local function pipe(name: string, diameter: number, length: number, cf: CFrame, color: Color3, material: Enum.Material?, host: Instance?): Part
		local p = part(name, V(length, diameter, diameter), cf, color, material, false, host)
		p.Shape = Enum.PartType.Cylinder
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	-- A frame on the boundary ring at bearing `a`: +X runs tangentially in the
	-- direction of increasing bearing, +Z points inward at the region centre.
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
	-- One Model per Codex asset. GroundCF is the bottom-centre placement frame
	-- in region-local space, so a MeshPart goes at
	-- `frame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)`. Every site in this
	-- region is ground supported; there is no hanging convention here.
	local function site(host: Instance, name: string, asset: string, size: Vector3, cf: CFrame, support: string): Model
		local m = group(host, name)
		m:SetAttribute("AssetName", asset)
		m:SetAttribute("AssetSize", size)
		m:SetAttribute("GroundCF", cf)
		m:SetAttribute("CollisionRole", "none")
		m:SetAttribute("PivotMode", "BottomCenter")
		m:SetAttribute("PlacementRole", "Grounded")
		m:SetAttribute("SupportPath", support)
		return group(m, "PlaceholderArt")
	end
	-- A caged yard lamp whose local +Z points back at whatever it is bolted to.
	local function yardLamp(name: string, cf: CFrame, host: Instance)
		flat(part(name .. "Arm", V(0.32, 0.32, 1.6), cf * CFrame.new(0, 0.25, 1.05), GRAPHITE, METAL, false, host))
		flat(part(name .. "Hood", V(2.1, 0.55, 2.1), cf * CFrame.new(0, 1.0, 0), GRAPHITE_LT, METAL, false, host))
		glow(part(name .. "Glass", V(1.5, 1.1, 1.5), cf, LAMP_GLASS, NEON, false, host), 1.1, 20)
	end
	-- A louvred vent face: a recessed plate with four slats across it.
	local function louvre(name: string, cf: CFrame, width: number, height: number, host: Instance)
		flat(part(name, V(width, height, 0.3), cf, GRAPHITE, METAL, false, host))
		for k = 1, 4 do
			flat(part(name .. "Slat", V(width - 0.5, height / 7, 0.16), cf * CFrame.new(0, height * (0.34 - (k - 1) * 0.22), 0.18), STEEL_DARK, METAL, false, host))
		end
	end

	-- ----------------------------------------------------------- catching yard
	-- Use the original asphalt Ground disc (top 0.30). The old 0.42 skin
	-- hid lightning warning discs whose upper face is at 0.31. Decorative
	-- floor marks stay below 0.31 and do not alter the walking surface.
	-- Expansion joints: four straight low-contrast seams, none of them through
	-- the middle of the aiming space, all flat enough to walk over unnoticed.
	for _, spec in { { 18, 0 }, { -18, 0 }, { 0, 21 }, { 0, -21 } } do
		local x, z = spec[1], spec[2]
		local along = if x == 0 then CFrame.Angles(0, math.pi / 2, 0) else CFrame.Angles(0, 0, 0)
		flat(part("YardSeam", V(0.55, 0.002, 104), CFrame.new(x, 0.301, z) * along, YARD_DARK, ASPHALT, false, decor))
	end
	-- Worn patches. Deliberately low contrast, because a Lightning circle is
	-- drawn on top of them and has to stay the brightest thing on the floor.
	for _, spec in { { 24, 31, 15, 11 }, { 128, 26, 12, 9 }, { 205, 38, 17, 12 }, { 268, 22, 11, 8 }, { 312, 35, 14, 10 }, { 168, 45, 13, 9 } } do
		local deg, r, sx, sz = spec[1], spec[2], spec[3], spec[4]
		flat(part("YardScuff", V(sx, 0.002, sz), bearing(deg, r) * CFrame.new(0, 0.303, 0) * CFrame.Angles(0, r * 0.11, 0), YARD_SCUFF, ASPHALT, false, decor))
	end
	for _, spec in { { 72, 29 }, { 250, 34 } } do
		flat(disc("YardDrain", 2.6, 0.002, bearing(spec[1], spec[2]) * CFrame.new(0, 0.305, 0), CONCRETE_DK, METAL, false, decor))
	end

	-- ---------------------------------------------------------- retaining wall
	-- One continuous ring of 48 tangential concrete segments with the entrance
	-- cut out of it. Each segment is a solid core plus a coping; every fourth
	-- carries a pair of buttresses and the plain ones take an inset steel panel.
	-- Chain link only ever sits on top of solid concrete, never instead of it.
	local segments = 48
	local length = 2 * radius * math.tan(math.pi / segments) + 0.5
	local panels = group(decor, "WallPanels")
	for i = 2, segments - 2 do
		local a = i * math.pi * 2 / segments
		local cf = ring(a, radius)
		local h = wallHeight(i)
		part("Perimeter", V(length, h, 3.6), cf * CFrame.new(0, h / 2, 0), CONCRETE, CONCRETE_MAT, true, boundary)
		-- the coping starts 0.2 below the core top, never level with it
		part("WallCoping", V(length + 0.16, 1.0, 4.2), cf * CFrame.new(0, h + 0.3, 0), CONCRETE_LT, CONCRETE_MAT, true, boundary)
		if i % 4 == 0 then
			-- Full-height pilasters, not half-height brackets: a buttress that
			-- stopped short of the coping would be a step onto the containment.
			local bh = h + 0.55
			for _, side in { -1, 1 } do
				part("WallButtress", V(2.3, bh, 2.2), cf * CFrame.new(side * 2.7, bh / 2, 2.6), CONCRETE_DK, CONCRETE_MAT, true, boundary)
				flat(part("ButtressCap", V(2.7, 0.6, 2.5), cf * CFrame.new(side * 2.7, h + 0.75, 2.6), CONCRETE_LT, CONCRETE_MAT, false, panels))
			end
		elseif i % 2 == 0 then
			flat(part("WallPanel", V(length - 2.4, h * 0.52, 0.34), cf * CFrame.new(0, h * 0.36, 1.87), STEEL_DARK, PLATE, false, panels))
		end
		-- Chain link tops the low run either side of the gate, where concrete
		-- alone would read as a bunker. It is decoration above containment.
		if i <= 5 or i >= 43 then
			local mesh = flat(part("WallMesh", V(length, 3.0, 0.14), cf * CFrame.new(0, h + 2.4, 0), STEEL_DARK, PLATE, false, panels))
			mesh.Transparency = 0.45
		end
		-- Four vent stacks break the rear skyline.
		if i == 20 or i == 23 or i == 26 or i == 29 then
			flat(disc("WallStack", 2.8, 7.0, cf * CFrame.new(1.1, h + 4.1, -0.4), GRAPHITE_LT, METAL, false, panels))
			flat(disc("WallStackCap", 3.3, 0.7, cf * CFrame.new(1.1, h + 7.85, -0.4), GRAPHITE, METAL, false, panels))
		end
	end
	-- Angled shoulders close the ring either side of the gate opening. Both
	-- lookAt points share y = 6, so the default up vector is never parallel.
	for _, side in { -1, 1 } do
		local from = V(side * 11.5, 6, -80)
		local to = V(side * math.sin(math.pi / 12) * radius, 6, -math.cos(math.pi / 12) * radius)
		local run = (to - from).Magnitude + 2
		local along = CFrame.lookAt((from + to) / 2, to)
		part("GateShoulder", V(3.6, 13, run), along, CONCRETE, CONCRETE_MAT, true, boundary)
		part("ShoulderCoping", V(4.2, 1.0, run), along * CFrame.new(0, 6.8, 0), CONCRETE_LT, CONCRETE_MAT, true, boundary)
	end

	-- ---------------------------------------------------------------- entrance
	-- A stout steel portal straddling the existing Gate. Only the two pier cores
	-- are solid and they live in Boundary, so an art pass can replace every
	-- visible plate and still leave the opening framed. Nothing here reaches the
	-- board box (x 15..33, z -90.33..-89.68) or the wedge its 27 sightlines
	-- sweep: the portal stands ten studs further in than the board.
	local portal = group(decor, "StormPortal")
	for _, side in { -1, 1 } do
		part("PortalPierCore", V(4.6, 17, 4.6), CFrame.new(side * 13, 8.2, -80), STEEL_DARK, METAL, true, boundary)
		flat(part("PierFlare", V(5.8, 1.5, 5.8), CFrame.new(side * 13, 0.95, -80), GRAPHITE, METAL, false, portal))
		flat(part("PierBand", V(4.95, 0.55, 4.95), CFrame.new(side * 13, 6.9, -80), GRAPHITE_LT, METAL, false, portal))
		flat(part("PierBand", V(4.95, 0.55, 4.95), CFrame.new(side * 13, 12.4, -80), GRAPHITE_LT, METAL, false, portal))
		-- Decoration, deliberately not a collision surface: a solid ledge here
		-- would be one jump off the road and one more onto the 12.5-stud gate
		-- shoulder, which is containment. The kit's insulator sites live on the
		-- generator support pads instead; this one is a fixed pier detail.
		flat(part("PierLedge", V(2.8, 0.7, 2.4), CFrame.new(side * 13, 6.15, -77.6), GRAPHITE, METAL, false, portal))
		flat(part("PierLedgeBrace", V(0.5, 1.6, 1.4), CFrame.new(side * 13, 5.25, -77.15) * CFrame.Angles(0.5, 0, 0), GRAPHITE, METAL, false, portal))
		flat(disc("PierInsulator", 1.5, 2.3, CFrame.new(side * 13, 7.65, -77.6), CERAMIC, SMOOTH, false, portal))
		flat(disc("PierInsulatorCap", 0.8, 0.4, CFrame.new(side * 13, 8.95, -77.6), COPPER, METAL, false, portal))
		pipe("PierConduit", 0.7, 13.5, CFrame.new(side * 10.4, 8.6, -80) * CFrame.Angles(0, 0, math.pi / 2), COPPER_DK, METAL, portal)
		flat(part("PierChevron", V(3.4, 0.5, 0.2), CFrame.new(side * 13, 2.3, -82.35), WORN_YELLOW, SMOOTH, false, portal))
		flat(part("PierChevron", V(3.4, 0.5, 0.2), CFrame.new(side * 13, 3.2, -82.35), WORN_YELLOW, SMOOTH, false, portal))
		yardLamp("PortalLamp", CFrame.new(side * 10.1, 10.6, -80) * CFrame.Angles(0, side * math.pi / 2, 0), portal)
	end
	flat(part("PortalHeader", V(30, 2.8, 3.2), CFrame.new(0, 17.4, -80), STEEL, METAL, false, portal))
	flat(part("HeaderCap", V(30.4, 0.6, 3.6), CFrame.new(0, 19.05, -80), GRAPHITE_LT, METAL, false, portal))
	flat(part("HeaderTie", V(26, 0.9, 1.2), CFrame.new(0, 15.55, -80), GRAPHITE, METAL, false, portal))
	for _, x in { -8.5, 0, 8.5 } do
		flat(part("HeaderStrut", V(0.7, 2.0, 0.7), CFrame.new(x, 16.4, -80), GRAPHITE, METAL, false, portal))
	end
	pipe("HeaderConduit", 0.6, 22, CFrame.new(0, 16.35, -78.6), COPPER_DK, METAL, portal)
	for _, x in { -6.5, 6.5 } do
		flat(disc("HeaderInsulator", 1.1, 1.3, CFrame.new(x, 19.95, -80), CERAMIC, SMOOTH, false, portal))
	end

	-- ------------------------------------------------------- maintenance route
	-- The optional walking route on image left: a tangential flight up out of
	-- the yard at bearings 60-76, a raised deck at 76-104 crossing the covered
	-- cable trench beneath it, and a second flight back down at 104-120. Both
	-- ends connect, so it is a route through and not a dead-end platform.
	-- Running the flights along the ring keeps every tread outside radius 60.5.
	local catwalk = group(decor, "MaintenanceCatwalk")
	for _, flight in { { 60, 1 }, { 120, -1 } } do
		local first, turn = flight[1], flight[2]
		for k = 1, 10 do
			local deg = first + turn * (k - 0.5) * 1.6
			local top = YARD_TOP + k * 0.60
			local at = bearing(deg, CAT_R)
			part("CatStep", V(1.82, top, 9.0), at * CFrame.new(0, top / 2, 0), STEEL_DARK, PLATE, true, walkways)
			for _, side in { -1, 1 } do
				part("CatStepKerb", V(1.82, top + 0.75, 0.7), at * CFrame.new(0, (top + 0.75) / 2, side * 4.15), GRAPHITE, METAL, true, walkways)
			end
		end
		-- One raking handrail per side per flight, rolled onto the flight's own
		-- chord so it reads as a rake and not a staircase of short bars.
		local rise = 6.0
		local run = 2 * CAT_R * math.sin(math.rad(16) / 2)
		local roll = turn * math.atan2(rise, run)
		local at = bearing(first + turn * 8, CAT_R)
		for _, side in { -1, 1 } do
			flat(part("CatStairRail", V(math.sqrt(run * run + rise * rise), 0.22, 0.22),
				at * CFrame.new(0, YARD_TOP + 4.05, side * 4.15) * CFrame.Angles(0, 0, roll), STEEL, METAL, false, catwalk))
			flat(part("CatStairNewel", V(0.3, 4.3, 0.3), bearing(first + turn * 15.4, CAT_R) * CFrame.new(0, YARD_TOP + 2.15, side * 4.15), STEEL, METAL, false, catwalk))
		end
	end
	for j = 0, 4 do
		local at = bearing(78.8 + j * 5.6, CAT_R)
		local lift = (j % 2) * 0.03
		part("CatDeck", V(6.40, 0.8, 9.0), at * CFrame.new(0, DECK_TOP - 0.4 + lift, 0), STEEL_DARK, PLATE, true, walkways)
		for _, side in { -1, 1 } do
			part("CatKerb", V(6.40, 0.9, 0.7), at * CFrame.new(0, DECK_TOP + 0.45 + lift, side * 4.15), GRAPHITE, METAL, true, walkways)
			flat(part("CatRail", V(6.40, 0.22, 0.22), at * CFrame.new(0, DECK_TOP + 3.0 + lift, side * 4.15), STEEL, METAL, false, catwalk))
		end
	end
	for j = 0, 5 do
		local at = bearing(76 + j * 5.6, CAT_R)
		for _, side in { -1, 1 } do
			part("CatLeg", V(1.0, 5.9, 1.0), at * CFrame.new(0, 2.95, side * 3.8), GRAPHITE, METAL, true, walkways)
			flat(part("CatPost", V(0.3, 2.9, 0.3), at * CFrame.new(0, DECK_TOP + 1.5, side * 4.15), STEEL, METAL, false, catwalk))
		end
	end

	-- ------------------------------------------------------------ cable trench
	-- Shallow and closed: two kerbs with bolted covers between them, walkable
	-- end to end. There is no hole and no new fall here, only a service channel
	-- the catwalk deck passes 4.96 studs above.
	local trench = group(decor, "CableTrench")
	for j = 0, 3 do
		local at = bearing(78 + j * 8, CAT_R)
		for _, side in { -1, 1 } do
			part("TrenchKerb", V(9.12, 0.75 + (j % 2) * 0.05, 0.8), at * CFrame.new(0, 0.575 + (j % 2) * 0.025, side * 2.2), CONCRETE_DK, CONCRETE_MAT, true, walkways)
		end
	end
	for j = 0, 7 do
		local at = bearing(76 + j * 4, CAT_R)
		part("TrenchCover", V(4.58, 0.45, 4.2), at * CFrame.new(0, 0.495 + (j % 2) * 0.04, 0), GRAPHITE_LT, PLATE, true, walkways)
		flat(part("TrenchCoverRib", V(4.2, 0.1, 0.4), at * CFrame.new(0, 0.775 + (j % 2) * 0.04, 0), GRAPHITE, METAL, false, trench))
	end
	for _, deg in { 74, 106 } do
		local at = bearing(deg, CAT_R)
		flat(part("TrenchEnd", V(0.7, 0.9, 4.4), at * CFrame.new(0, 0.62, 0), CONCRETE_DK, CONCRETE_MAT, false, trench))
		for k = 1, 3 do
			pipe("TrenchCable", 0.5, 3.6, at * CFrame.new(0, 0.42 + k * 0.12, (k - 2) * 1.2) * CFrame.Angles(0, math.pi / 2, 0), COPPER_DK, METAL, trench)
		end
	end

	-- ------------------------------------------------------------ control shed
	-- Image right: a closed facade on a low service apron. The door opens onto
	-- nothing, the windows are lit panels, and the solid ShedCore in Boundary is
	-- the collision that outlives every board bolted to it.
	local apronCF = bearing(270, 65.25)
	local shedCF = bearing(270, 67.25)
	local shed = group(decor, "ControlShed")
	part("ServiceApron", V(24, 0.9, 13.5), apronCF * CFrame.new(0, 0.25, 0), CONCRETE, CONCRETE_MAT, true, walkways)
	flat(part("ApronNosing", V(24.2, 0.14, 0.7), apronCF * CFrame.new(0, 0.77, 6.45), CONCRETE_DK, CONCRETE_MAT, false, shed))
	part("ShedCore", V(18, 9.2, 9), shedCF * CFrame.new(0, 4.9, 0), GRAPHITE, METAL, true, boundary)
	flat(part("ShedSkirt", V(19, 1.1, 10), shedCF * CFrame.new(0, 1.25, 0), CONCRETE, CONCRETE_MAT, false, shed))
	flat(part("ShedFront", V(18.4, 8.1, 0.5), shedCF * CFrame.new(0, 5.4, 4.6), TEAL, METAL, false, shed))
	flat(part("ShedBack", V(18.4, 8.1, 0.5), shedCF * CFrame.new(0, 5.4, -4.6), TEAL_DARK, METAL, false, shed))
	for _, side in { -1, 1 } do
		flat(part("ShedSide", V(0.5, 7.9, 9.2), shedCF * CFrame.new(side * 9.2, 5.3, 0), TEAL_DARK, METAL, false, shed))
		pipe("ShedDownpipe", 0.55, 7.7, shedCF * CFrame.new(side * 9.0, 5.3, 4.45) * CFrame.Angles(0, 0, math.pi / 2), GRAPHITE_LT, METAL, shed)
	end
	-- Mono-pitch roof: rotating about the tangential axis drops the inward eave,
	-- so the shed sheds toward the yard and its high parapet reads from inside.
	-- 19.2 x 10.2, not 19.6 x 10.6: the wider plate's outer corners reached
	-- exactly radius 73.20, which is the wall's inner face.
	flat(part("ShedRoof", V(19.2, 0.7, 10.2), shedCF * CFrame.new(0, 10.8, 0) * CFrame.Angles(0.16, 0, 0), STEEL_DARK, METAL, false, shed))
	flat(part("ShedEave", V(19.9, 0.6, 0.9), shedCF * CFrame.new(0, 9.35, 5.45), GRAPHITE, METAL, false, shed))
	flat(part("ShedParapet", V(19.6, 1.1, 0.7), shedCF * CFrame.new(0, 12.1, -5.1), GRAPHITE_LT, METAL, false, shed))
	flat(part("ShedDoorFrame", V(4.3, 6.4, 0.3), shedCF * CFrame.new(-5.6, 4.0, 4.85), GRAPHITE, METAL, false, shed))
	flat(part("ShedDoor", V(3.6, 5.8, 0.36), shedCF * CFrame.new(-5.6, 3.75, 4.99), STEEL_DARK, METAL, false, shed))
	flat(part("ShedDoorHandle", V(0.28, 0.9, 0.24), shedCF * CFrame.new(-4.1, 3.75, 5.19), STEEL, METAL, false, shed))
	for _, x in { -0.4, 3.9, 8.2 } do
		flat(part("ShedWindowFrame", V(3.4, 3.0, 0.3), shedCF * CFrame.new(x, 6.9, 4.85), GRAPHITE, METAL, false, shed))
		glow(part("ShedWindow", V(2.8, 2.4, 0.36), shedCF * CFrame.new(x, 6.9, 4.99), WINDOW_WARM, NEON, false, shed), 0.8, 17)
	end
	louvre("ShedVent", shedCF * CFrame.new(-1.6, 2.4, 4.92), 4.2, 2.3, shed)
	louvre("ShedVent", shedCF * CFrame.new(6.6, 2.4, 4.92), 4.2, 2.3, shed)
	flat(part("ShedGlyph", V(1.5, 1.8, 0.18), shedCF * CFrame.new(-5.6, 8.4, 4.98) * CFrame.Angles(0, 0, 0.2), WORN_YELLOW, SMOOTH, false, shed))
	yardLamp("ShedLamp", shedCF * CFrame.new(5.9, 8.0, 5.1) * CFrame.Angles(0, math.pi, 0), shed)

	-- --------------------------------------------------- collectors and gantry
	-- The rear hero: a pair of lightning collectors on a generator plinth, with
	-- a static three-phase bus strung between their gantries. No arcs, no
	-- flashing and no damage; the masts are art and the pedestals are collision.
	local plinth = group(decor, "GeneratorYard")
	-- z 59.5 to 71.5: clear of the flat field at 58 and of the wall face at 73.2,
	-- and only 1.48 studs up, so walking onto it is a step and not a climb.
	part("GeneratorPlinth", V(28, 2.0, 12), CFrame.new(0, 0.9, 65.5), CONCRETE, CONCRETE_MAT, true, walkways)
	flat(part("PlinthNosing", V(28.2, 0.16, 0.8), CFrame.new(0, 1.96, 59.8), CONCRETE_LT, CONCRETE_MAT, false, plinth))
	part("GeneratorHousing", V(11, 5.4, 8), CFrame.new(0, 4.6, 66.5), GRAPHITE, METAL, true, boundary)
	for k = 1, 4 do
		flat(part("HousingRib", V(11.3, 0.45, 8.3), CFrame.new(0, 2.6 + (k - 1) * 1.4, 66.5), TEAL_DARK, METAL, false, plinth))
	end
	flat(part("HousingLid", V(11.6, 0.7, 8.6), CFrame.new(0, 7.55, 66.5), STEEL_DARK, METAL, false, plinth))
	louvre("HousingVent", CFrame.new(-2.9, 4.4, 62.4) * CFrame.Angles(0, math.pi, 0), 3.4, 2.4, plinth)
	louvre("HousingVent", CFrame.new(2.9, 4.4, 62.4) * CFrame.Angles(0, math.pi, 0), 3.4, 2.4, plinth)
	flat(part("HousingGlyph", V(1.4, 2.0, 0.18), CFrame.new(0, 6.35, 62.33) * CFrame.Angles(0, math.pi, 0.2), WORN_YELLOW, SMOOTH, false, plinth))

	-- A collector: concrete pedestal, porcelain neck, braced mast, two broad
	-- copper rings and a crown. Only the pedestal is solid.
	local function collector(name: string, cx: number, cz: number, host: Instance)
		part(name .. "Pedestal", V(7.4, 3.8, 7.4), CFrame.new(cx, 3.6, cz), CONCRETE_DK, CONCRETE_MAT, true, boundary)
		flat(part(name .. "PedestalCap", V(8.0, 0.6, 8.0), CFrame.new(cx, 5.7, cz), CONCRETE_LT, CONCRETE_MAT, false, host))
		for k = 1, 3 do
			flat(disc(name .. "Neck", 5.4 - (k - 1) * 0.4, 1.5, CFrame.new(cx, 6.5 + (k - 1) * 1.3, cz), if k % 2 == 1 then CERAMIC else CERAMIC_DK, SMOOTH, false, host))
		end
		flat(part(name .. "Collar", V(4.4, 0.7, 4.4), CFrame.new(cx, 10.1, cz), COPPER, METAL, false, host))
		flat(part(name .. "Mast", V(3.0, 20.0, 3.0), CFrame.new(cx, 20.4, cz), GRAPHITE_LT, METAL, false, host))
		for k = 1, 3 do
			local y = 13.0 + (k - 1) * 6.0
			for _, side in { -1, 1 } do
				flat(part(name .. "Brace", V(0.5, 5.4, 0.5), CFrame.new(cx + side * 1.5, y, cz) * CFrame.Angles(0, 0, side * 0.42), GRAPHITE, METAL, false, host))
			end
		end
		for _, spec in { { 16.0, 6.5, 1.2 }, { 23.5, 5.0, 1.0 } } do
			local y, r, tube = spec[1], spec[2], spec[3]
			local chord = 2 * r * math.tan(math.pi / 10) + 0.08
			for s = 1, 10 do
				local a = (s - 1) * math.pi * 2 / 10
				-- alternate segments are 0.06 slimmer, so the mitre where two of
				-- them overlap is never two top faces in the same plane
				local t = if s % 2 == 0 then tube else tube - 0.06
				flat(part(name .. "Ring", V(chord, t, t),
					CFrame.new(cx + math.sin(a) * r, y, cz - math.cos(a) * r) * CFrame.Angles(0, -a, 0), COPPER, METAL, false, host))
			end
			pipe(name .. "RingStay", 0.4, r * 2 - 0.4, CFrame.new(cx, y, cz), COPPER_DK, METAL, host)
			pipe(name .. "RingStay", 0.4, r * 2 - 0.4, CFrame.new(cx, y, cz) * CFrame.Angles(0, math.pi / 2, 0), COPPER_DK, METAL, host)
		end
		local crown = flat(part(name .. "Crown", V(4.8, 4.8, 4.8), CFrame.new(cx, 31.6, cz), COPPER, METAL, false, host))
		crown.Shape = Enum.PartType.Ball
		flat(disc(name .. "Finial", 0.7, 2.0, CFrame.new(cx, 34.8, cz), CERAMIC, SMOOTH, false, host))
		flat(part(name .. "Gantry", V(2.2, 0.6, 7.2), CFrame.new(cx, 24.6, cz), GRAPHITE, METAL, false, host))
	end
	collector("CollectorL", 9.5, 66.5, plinth)
	collector("CollectorR", -9.5, 66.5, plinth)
	for _, z in { 64.9, 66.5, 68.1 } do
		pipe("PowerBus", 0.75, 21, CFrame.new(0, 26.5, z), COPPER, METAL, plinth)
		for _, x in { -9.5, 9.5 } do
			flat(disc("BusInsulator", 1.3, 1.4, CFrame.new(x, 25.6, z), CERAMIC, SMOOTH, false, plinth))
		end
	end

	-- ------------------------------------------------------------ service pads
	-- Four low concrete pads in the arcs the catwalk, shed and generator yard
	-- leave free. Every pad is a measured surface a prop site can name.
	local function servicePad(name: string, deg: number, r: number, w: number, d: number): CFrame
		local at = bearing(deg, r)
		part(name, V(w, 0.7, d), at * CFrame.new(0, 0.32, 0), CONCRETE, CONCRETE_MAT, true, walkways)
		flat(part(name .. "Nosing", V(w + 0.2, 0.14, 0.6), at * CFrame.new(0, 0.74, d / 2 - 0.3), CONCRETE_DK, CONCRETE_MAT, false, decor))
		return at
	end
	local padA = servicePad("ServicePadA", 34, 64, 13, 9)
	local padB = servicePad("ServicePadB", 138, 64, 12, 8.5)
	local padC = servicePad("ServicePadC", 224, 64, 12, 8.5)
	local padD = servicePad("ServicePadD", 320, 64, 13, 9)
	-- Two more flanking the generator yard, for the capacitor banks supporting it.
	local supportL = servicePad("GeneratorSupportL", 160, 64, 10, 8)
	local supportR = servicePad("GeneratorSupportR", 200, 64, 10, 8)

	-- -------------------------------------------------------------- asset sites
	-- One Model per mesh Codex will place, each named, dimensioned and framed.
	-- The placeholder inside reproduces the manifest bounding box exactly, so
	-- swapping in a MeshPart is one for one with no nearest-neighbour guessing.
	local sites = group(decor, "PropSites")
	sites:SetAttribute("AssetKit", "assets/thunderworks/props-v1")
	sites:SetAttribute("AssetOrigin", "ground-centre")

	local counts: { [string]: number } = {}
	local total = 0
	local function place(prefix: string, asset: string, size: Vector3, at: CFrame, support: string): Model
		local n = (counts[prefix] or 0) + 1
		counts[prefix] = n
		total += 1
		return site(sites, prefix .. "Site" .. pad2(n), asset, size, at, support)
	end

	local function transformer(at: CFrame, support: string)
		local host = place("Transformer", "TW_Transformer", TRANSFORMER, at, support)
		flat(part("TransformerSkid", V(5.8, 0.5, 4.6), at * CFrame.new(0, 0.25, 0), GRAPHITE, METAL, false, host))
		flat(part("TransformerTank", V(5.0, 3.6, 4.0), at * CFrame.new(0, 2.3, 0), TEAL, METAL, false, host))
		flat(part("TransformerFin", V(5.4, 2.8, 4.4), at * CFrame.new(0, 2.3, 0), TEAL_DARK, PLATE, false, host))
		flat(part("TransformerLid", V(5.8, 0.9, 4.6), at * CFrame.new(0, 4.55, 0), STEEL_DARK, METAL, false, host))
		for _, x in { -1.3, 1.3 } do
			flat(disc("TransformerBushing", 1.3, 1.3, at * CFrame.new(x, 5.6, 0), CERAMIC, SMOOTH, false, host))
		end
		pipe("TransformerJumper", 0.35, 2.9, at * CFrame.new(0, 6.05, 0), COPPER, METAL, host)
	end
	local function insulator(at: CFrame, support: string)
		local host = place("Insulator", "TW_Ceramic_Insulator", INSULATOR, at, support)
		flat(part("InsulatorFoot", V(1.8, 0.5, 1.8), at * CFrame.new(0, 0.25, 0), GRAPHITE, METAL, false, host))
		flat(disc("InsulatorStack", 1.6, 2.1, at * CFrame.new(0, 1.55, 0), CERAMIC, SMOOTH, false, host))
		flat(disc("InsulatorCap", 0.9, 0.45, at * CFrame.new(0, 2.775, 0), COPPER, METAL, false, host))
	end
	local function cableReel(at: CFrame, support: string)
		local host = place("CableReel", "TW_Cable_Reel", CABLE_REEL, at, support)
		for _, x in { -1.6, 1.6 } do
			flat(part("ReelFoot", V(0.6, 0.4, 3.0), at * CFrame.new(x, 0.2, 0), GRAPHITE, METAL, false, host))
		end
		for _, z in { -1.3, 1.3 } do
			flat(disc("ReelFlange", 4.0, 0.4, at * CFrame.new(0, 2.4, z) * CFrame.Angles(math.pi / 2, 0, 0), COPPER_DK, WOOD, false, host))
		end
		flat(disc("ReelDrum", 3.2, 2.2, at * CFrame.new(0, 2.4, 0) * CFrame.Angles(math.pi / 2, 0, 0), GRAPHITE, METAL, false, host))
	end
	local function capacitor(at: CFrame, support: string)
		local host = place("Capacitor", "TW_Capacitor_Bank", CAPACITOR, at, support)
		flat(part("CapacitorBase", V(3.4, 0.4, 3.4), at * CFrame.new(0, 0.2, 0), GRAPHITE, METAL, false, host))
		for _, spec in { { -0.85, -0.7 }, { 0.85, -0.7 }, { 0, 0.85 } } do
			local x, z = spec[1], spec[2]
			flat(disc("CapacitorCan", 1.5, 3.4, at * CFrame.new(x, 2.1, z), TEAL, METAL, false, host))
			flat(disc("CapacitorCap", 1.0, 0.6, at * CFrame.new(x, 4.05, z), CERAMIC, SMOOTH, false, host))
		end
		pipe("CapacitorJumper", 0.3, 2.4, at * CFrame.new(0, 4.6, -0.7), COPPER, METAL, host)
	end
	local function cabinet(at: CFrame, support: string)
		local host = place("Cabinet", "TW_Switch_Cabinet", CABINET, at, support)
		flat(part("CabinetPlinth", V(3.2, 0.4, 1.8), at * CFrame.new(0, 0.2, 0), GRAPHITE, METAL, false, host))
		flat(part("CabinetBody", V(3.0, 3.8, 1.7), at * CFrame.new(0, 2.3, 0), TEAL, METAL, false, host))
		flat(part("CabinetLouvre", V(2.2, 0.9, 0.2), at * CFrame.new(0, 1.5, 0.85), STEEL_DARK, PLATE, false, host))
		flat(part("CabinetRoof", V(3.2, 0.45, 1.8), at * CFrame.new(0, 4.375, 0), STEEL_DARK, METAL, false, host))
	end
	local function ventHousing(at: CFrame, support: string)
		local host = place("Vent", "TW_Vent_Housing", VENT, at, support)
		flat(part("VentBase", V(4.0, 0.4, 3.4), at * CFrame.new(0, 0.2, 0), GRAPHITE, METAL, false, host))
		flat(part("VentLouvre", V(3.6, 1.1, 3.0), at * CFrame.new(0, 0.95, 0), STEEL, PLATE, false, host))
		flat(part("VentFrame", V(3.8, 0.35, 3.2), at * CFrame.new(0, 1.675, 0), GRAPHITE_LT, METAL, false, host))
		flat(part("VentLid", V(4.0, 0.55, 3.4), at * CFrame.new(0, 2.125, 0), TEAL, METAL, false, host))
	end
	local function conduitElbow(at: CFrame, support: string)
		local host = place("Conduit", "TW_Conduit_Elbow", ELBOW, at, support)
		flat(part("ElbowPad", V(3.0, 0.3, 2.2), at * CFrame.new(0, 0.15, 0), GRAPHITE, METAL, false, host))
		pipe("ElbowRiser", 0.85, 1.9, at * CFrame.new(-1.05, 1.25, 0) * CFrame.Angles(0, 0, math.pi / 2), COPPER, METAL, host)
		pipe("ElbowRun", 0.85, 2.1, at * CFrame.new(0, 2.05, 0), COPPER, METAL, host)
		flat(part("ElbowFlange", V(0.4, 1.1, 1.1), at * CFrame.new(1.2, 2.05, 0), COPPER_DK, METAL, false, host))
	end
	local function bollard(at: CFrame, support: string)
		local host = place("Bollard", "TW_Storm_Bollard", BOLLARD, at, support)
		flat(part("BollardFoot", V(1.2, 0.35, 1.2), at * CFrame.new(0, 0.175, 0), GRAPHITE, METAL, false, host))
		flat(disc("BollardPost", 0.95, 2.3, at * CFrame.new(0, 1.5, 0), TEAL, METAL, false, host))
		flat(disc("BollardBand", 1.05, 0.28, at * CFrame.new(0, 1.9, 0), WORN_YELLOW, SMOOTH, false, host))
		flat(disc("BollardCap", 0.85, 0.35, at * CFrame.new(0, 2.825, 0), CERAMIC, SMOOTH, false, host))
	end

	-- Pad A, the transformer group: two tanks across the back, light gear in front.
	transformer(padA * CFrame.new(-3.5, PAD_TOP, -1.3), "Walkways/ServicePadA")
	transformer(padA * CFrame.new(3.5, PAD_TOP, -1.3), "Walkways/ServicePadA")
	insulator(padA * CFrame.new(-2.0, PAD_TOP, 2.6), "Walkways/ServicePadA")
	conduitElbow(padA * CFrame.new(2.2, PAD_TOP, 2.7) * CFrame.Angles(0, math.pi, 0), "Walkways/ServicePadA")
	bollard(padA * CFrame.new(-5.8, PAD_TOP, 3.4), "Walkways/ServicePadA")
	bollard(padA * CFrame.new(5.8, PAD_TOP, 3.4), "Walkways/ServicePadA")

	cableReel(padB * CFrame.new(-3.2, PAD_TOP, 0.2), "Walkways/ServicePadB")
	cableReel(padB * CFrame.new(1.6, PAD_TOP, 1.0) * CFrame.Angles(0, 0.55, 0), "Walkways/ServicePadB")
	cabinet(padB * CFrame.new(4.4, PAD_TOP, -2.6), "Walkways/ServicePadB")
	bollard(padB * CFrame.new(-5.2, PAD_TOP, 3.2), "Walkways/ServicePadB")

	capacitor(padC * CFrame.new(-3.4, PAD_TOP, -0.5), "Walkways/ServicePadC")
	ventHousing(padC * CFrame.new(1.2, PAD_TOP, -1.6), "Walkways/ServicePadC")
	conduitElbow(padC * CFrame.new(4.1, PAD_TOP, 2.0) * CFrame.Angles(0, -0.4, 0), "Walkways/ServicePadC")
	bollard(padC * CFrame.new(5.2, PAD_TOP, -3.4), "Walkways/ServicePadC")

	transformer(padD * CFrame.new(-3.4, PAD_TOP, 0), "Walkways/ServicePadD")
	ventHousing(padD * CFrame.new(3.8, PAD_TOP, -2.0), "Walkways/ServicePadD")
	cabinet(padD * CFrame.new(2.4, PAD_TOP, 2.4), "Walkways/ServicePadD")
	insulator(padD * CFrame.new(5.4, PAD_TOP, 2.6), "Walkways/ServicePadD")
	bollard(padD * CFrame.new(-5.6, PAD_TOP, 3.6), "Walkways/ServicePadD")

	local supports: { { cf: CFrame, name: string } } = {
		{ cf = supportL, name = "GeneratorSupportL" },
		{ cf = supportR, name = "GeneratorSupportR" },
	}
	for _, sp in supports do
		capacitor(sp.cf * CFrame.new(-2.6, PAD_TOP, -0.4), "Walkways/" .. sp.name)
		capacitor(sp.cf * CFrame.new(2.6, PAD_TOP, -0.4), "Walkways/" .. sp.name)
		insulator(sp.cf * CFrame.new(0, PAD_TOP, 2.6), "Walkways/" .. sp.name)
	end

	cableReel(bearing(57, 62.5) * CFrame.new(0, YARD_TOP, 0) * CFrame.Angles(0, 0.35, 0), "Ground")
	cableReel(bearing(123, 62.5) * CFrame.new(0, YARD_TOP, 0) * CFrame.Angles(0, -0.45, 0), "Ground")

	cabinet(apronCF * CFrame.new(-7.6, APRON_TOP, 5.6), "Walkways/ServiceApron")
	cabinet(apronCF * CFrame.new(-3.8, APRON_TOP, 5.6), "Walkways/ServiceApron")
	ventHousing(apronCF * CFrame.new(3.4, APRON_TOP, 4.9), "Walkways/ServiceApron")
	cableReel(apronCF * CFrame.new(8.2, APRON_TOP, 4.9) * CFrame.Angles(0, 0.15, 0), "Walkways/ServiceApron")
	bollard(apronCF * CFrame.new(-11.3, APRON_TOP, 5.9), "Walkways/ServiceApron")
	bollard(apronCF * CFrame.new(11.3, APRON_TOP, 5.9), "Walkways/ServiceApron")

	sites:SetAttribute("AssetCount", total)
	parent:SetAttribute("SceneryVersion", 3)
	require(script.Parent.ThunderProps).apply(parent, frame)
end

return Thunderworks
