--!strict
-- The dressing around a region's GateSign: frame, posts, footings and crest.
--
-- MapBuilder owns the board part and its live SurfaceGui rows; this module only
-- builds around them. Nothing here touches the 18 x 10 face or the text layout
-- verified in the sign fix, and every decorative piece is CanQuery = false, so
-- the 27 approach sightlines per sign in TestHarness see the board and nothing
-- else. Regions whose board has no concept art keep the plain metal trim.
--
-- Local space is the sign's own: +X right across the face, +Y up, -Z out
-- towards the player, origin at the board centre. So:
--   board face      x +/- 9, y +/- 5, front at z = -0.325
--   ground          y = -7.5 (-8.6 for Splashwater's taller exposed legs)
--   outer frame     plain/Gusty frame stays inside |x| = 9.8; Splashwater's
--                   footings reach 11.05, still clear of the approach road
--   text rows       occupy x +/- 8.1; the Element row starts at y = 4.5 and
--                   the Forecast row ends at y = -4.5, so frame members that
--                   cross the face must stay outside those bounds

local RegionSign = {}

local rgb = Color3.fromRGB
local V = Vector3.new

local INK = rgb(46, 44, 52)
local DECK = rgb(120, 126, 142)
local SLATE = rgb(48, 52, 70)

type Ctx = {
	stand: Model,
	cf: CFrame,
	make: (any) -> Part,
}

-- Decorative pieces are neither solid nor queryable: they cannot absorb the
-- sightline rays that prove the board is readable from the approach road.
local function piece(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	return ctx.make({
		name = name,
		size = size,
		cf = ctx.cf * cf,
		color = color,
		material = material or Enum.Material.Wood,
		collide = solid == true,
		query = solid == true,
		parent = ctx.stand,
	})
end

-- A disc facing the player: a cylinder's axis is its X, so turn it onto -Z.
local function disc(ctx: Ctx, name: string, diameter: number, depth: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = piece(ctx, name, V(depth, diameter, diameter), cf * CFrame.Angles(0, math.pi / 2, 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Primitive balls clamp unequal cross-section axes, so leaves and petals use a
-- built-in sphere mesh to stay genuinely elliptical (as SplashwaterBay does).
local function ellipsoid(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local extent = math.max(size.X, size.Y, size.Z)
	local p = piece(ctx, name, V(extent, extent, extent), cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size / extent
	mesh.Parent = p
	p.CastShadow = false
	return p
end

-- ------------------------------------------------------------------ plain
-- The board every undesigned region still wears: rear supports, feet and a
-- metal edge trim that sits outside the face.
local function plain(ctx: Ctx)
	for _, side in { -1, 1 } do
		piece(ctx, "SignPost", V(0.8, 7, 0.8), CFrame.new(side * 6.2, -4, 0.8), INK, Enum.Material.Metal, true)
		piece(ctx, "SignFoot", V(2.2, 0.5, 2.2), CFrame.new(side * 6.2, -7.25, 0.8), DECK, Enum.Material.Concrete, true)
		piece(ctx, "SignSideTrim", V(0.3, 10.6, 0.75), CFrame.new(side * 9.15, 0, 0), INK, Enum.Material.Metal)
	end
	for _, y in { -5.15, 5.15 } do
		piece(ctx, "SignEdgeTrim", V(18, 0.3, 0.75), CFrame.new(0, y, 0), INK, Enum.Material.Metal)
	end
end

-- ----------------------------------------------------------------- gusty
-- Warm honey timber, an arched crown carved with wind swirls, a cream pinwheel
-- crest and daisies at the lower corners, over a matte forest-green panel.
local GUSTY = {
	timber = rgb(198, 150, 92),
	crown = rgb(211, 165, 107),
	carve = rgb(158, 114, 66),
	stone = rgb(133, 133, 141),
	cream = rgb(238, 232, 210),
	leaf = rgb(62, 115, 57),
	pollen = rgb(247, 200, 70),
}

-- The crown's top edge follows a shallow parabola from the shoulders to the
-- apex; its underside is flat on the panel, so it is the top rail and the arch
-- at once. Steps of 0.89 studs keep the arc readable without a mesh.
local CROWN_SPAN = 18.6
local CROWN_STEPS = 21
local CROWN_BASE = 4.7
local CROWN_APEX = 7.7
local CROWN_SPRING = 5.5

local function gusty(ctx: Ctx)
	local s = GUSTY

	-- Posts carry the board and double as its side frame. Their inner faces sit
	-- at |x| = 8.3, clear of the 8.1 the text rows reach.
	for _, side in { -1, 1 } do
		local x = side * 9.05
		piece(ctx, "SignPost", V(1.5, 13.8, 1.7), CFrame.new(x, -0.3, -0.2), s.timber, Enum.Material.Wood, true)
		piece(ctx, "SignPostCap", V(2.1, 0.8, 2.2), CFrame.new(x, 7, -0.2), s.crown, Enum.Material.Wood, true)
		piece(ctx, "SignFooting", V(2.6, 1.2, 2.7), CFrame.new(x, -6.9, -0.2), s.stone, Enum.Material.Rock, true)
		piece(ctx, "SignFooting", V(2.3, 1, 2.4), CFrame.new(x, -5.8, -0.2), s.stone, Enum.Material.Rock, true)
	end

	piece(ctx, "SignRail", V(CROWN_SPAN, 1.7, 0.9), CFrame.new(0, -5.55, -0.45), s.timber, Enum.Material.Wood)

	for i = 1, CROWN_STEPS do
		local x = -CROWN_SPAN / 2 + CROWN_SPAN * (i - 0.5) / CROWN_STEPS
		local t = x / (CROWN_SPAN / 2)
		local top = CROWN_APEX - (CROWN_APEX - CROWN_SPRING) * t * t
		piece(ctx, "SignCrown", V(CROWN_SPAN / CROWN_STEPS + 0.12, top - CROWN_BASE, 0.9),
			CFrame.new(x, (top + CROWN_BASE) / 2, -0.45), s.crown, Enum.Material.Wood)
	end

	-- Pinwheel crest, centred on the crown and cresting its apex.
	disc(ctx, "SignCrestRim", 2.9, 0.55, CFrame.new(0, 6.4, -1.05), s.carve, Enum.Material.Wood)
	disc(ctx, "SignCrestFace", 2.35, 0.5, CFrame.new(0, 6.4, -1.02), s.timber, Enum.Material.Wood)
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		ellipsoid(ctx, "SignCrestBlade", V(1.18, 0.66, 0.3),
			CFrame.new(math.cos(a) * 0.62, 6.4 + math.sin(a) * 0.62, -1.42) * CFrame.Angles(0, 0, a + math.rad(26)),
			s.cream, Enum.Material.SmoothPlastic)
	end
	disc(ctx, "SignCrestHub", 0.62, 0.34, CFrame.new(0, 6.4, -1.5), s.cream, Enum.Material.SmoothPlastic)

	-- A carved curl either side of the crest, its gust trailing outwards.
	for _, side in { -1, 1 } do
		local cx = side * 2.95
		for i = 0, 4 do
			local a = math.rad(i * 62) * side
			local r = 0.58 - i * 0.1
			piece(ctx, "SignCarving", V(0.42, 0.2, 0.22),
				CFrame.new(cx + math.cos(a) * r, 6.05 + math.sin(a) * r, -0.99) * CFrame.Angles(0, 0, a + math.pi / 2),
				s.carve, Enum.Material.Wood)
		end
		for i = 1, 2 do
			local lift = if i % 2 == 0 then 0.16 else -0.16
			piece(ctx, "SignCarving", V(0.78, 0.2, 0.22),
				CFrame.new(cx + side * (0.62 + i * 0.72), 6.05 + lift, -0.99) * CFrame.Angles(0, 0, side * math.rad(if i % 2 == 0 then -12 else 12)),
				s.carve, Enum.Material.Wood)
		end
	end

	-- Leaves and a daisy tucked into each lower corner. The text rows are
	-- centred, so the corners they nominally span are empty.
	for _, side in { -1, 1 } do
		local cx, cy = side * 7.8, -4.2
		for _, deg in { 18, 62, 118, 158 } do
			local a = math.rad(if side < 0 then 180 - deg else deg)
			ellipsoid(ctx, "SignLeaf", V(1.5, 0.62, 0.28),
				CFrame.new(cx + math.cos(a) * 0.74, cy + math.sin(a) * 0.74, -0.86) * CFrame.Angles(0, 0, a),
				s.leaf, Enum.Material.Grass)
		end
		for i = 0, 4 do
			local a = math.rad(i * 72 + 12)
			ellipsoid(ctx, "SignPetal", V(0.66, 0.4, 0.26),
				CFrame.new(cx + math.cos(a) * 0.3, cy + math.sin(a) * 0.3, -1.1) * CFrame.Angles(0, 0, a),
				s.cream, Enum.Material.SmoothPlastic)
		end
		disc(ctx, "SignPollen", 0.4, 0.3, CFrame.new(cx, cy, -1.24), s.pollen, Enum.Material.SmoothPlastic)
	end
end

-- -------------------------------------------------------------- splashwater
-- Reference: docs/art/region-boards/2026-09-20-mockups/splashwater-bay.png.
-- The clear 18 x 10 text window is surrounded by whitewashed timber, a navy
-- cap, rope lashings, a life ring and the three-shell/starfish corner cluster.
local BAY = {
	wood = rgb(143, 110, 77),
	whitewash = rgb(218, 211, 190),
	navy = rgb(35, 65, 96),
	panel = rgb(24, 53, 78),
	rope = rgb(170, 134, 82),
	ropeLight = rgb(186, 153, 103),
	ropeDark = rgb(152, 124, 82),
	metal = rgb(67, 73, 78),
	stone = rgb(107, 113, 122),
	cream = rgb(232, 223, 196),
	red = rgb(177, 75, 50),
	shell = rgb(228, 205, 165),
	starfish = rgb(215, 134, 87),
}

local function bayTube(ctx: Ctx, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local p = piece(ctx, name, V((b - a).Magnitude * 1.06, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function splashwater(ctx: Ctx)
	local s = BAY
	-- A little wider than the plain stand: the near footing remains more than
	-- 12 studs from the road centre, and the existing 10-stud forward offset
	-- keeps the entrance piers behind the board rather than through its frame.
	for _, side in { -1, 1 } do
		local x = side * 9.65
		piece(ctx, "BayTimberPost", V(1.5, 15.8, 1.8), CFrame.new(x, -0.6, 0.3), s.wood, Enum.Material.Wood, true)
		piece(ctx, "BayWhitewashUpright", V(1.05, 11.6, 0.4), CFrame.new(side * 9.05, 0.05, -0.8), s.whitewash, Enum.Material.Wood)
		piece(ctx, "BayStoneFooting", V(2.8, 1.65, 2.8), CFrame.new(x, -7.775, 0.3), s.stone, Enum.Material.Slate, true)
		piece(ctx, "BayFootingTop", V(2.4, 0.3, 2.4), CFrame.new(x, -6.8, 0.3), s.stone:Lerp(s.cream, 0.06), Enum.Material.Slate, true)
	end
	piece(ctx, "BayWhitewashHeader", V(20.4, 1.3, 0.6), CFrame.new(0, 5.45, -0.75), s.whitewash, Enum.Material.Wood)
	piece(ctx, "BayWhitewashSill", V(20.4, 1.25, 0.65), CFrame.new(0, -5.425, -0.8), s.whitewash, Enum.Material.Wood)
	piece(ctx, "BayNavyCap", V(21.6, 0.9, 1.8), CFrame.new(0, 6.45, -0.25), s.navy, Enum.Material.Wood)
	-- Shallow panel plank seams stay BEHIND the live SurfaceGui plane, so all
	-- dynamic words remain intact. They read as horizontal boards in the mockup.
	for i = 1, 5 do
		piece(ctx, "BayPanelSeam", V(17.8, 0.035, 0.018), CFrame.new(0, -5 + i * 10 / 6, -0.325), rgb(17, 43, 62), Enum.Material.Wood)
	end
	-- Iron fasteners on the cap and frame, outside the text area.
	for _, x in { -8.65, 8.65 } do
		for _, y in { 6.45, 5.45, -5.425 } do
			disc(ctx, "BayBoltRim", 0.42, 0.08, CFrame.new(x, y, -1.19), s.metal:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal)
			ellipsoid(ctx, "BayBolt", V(0.32, 0.32, 0.12), CFrame.new(x, y, -1.26), s.metal, Enum.Material.Metal)
		end
	end
	-- Deterministic exposed grain along the whitewash; no global random calls.
	local grain = Random.new(5824)
	for i = 1, 42 do
		local side = if i % 2 == 0 then 1 else -1
		local vertical = i <= 20
		local x = if vertical then side * 9.05 + grain:NextNumber(-0.4, 0.4) else grain:NextNumber(-8.4, 8.4)
		local y = if vertical then grain:NextNumber(-4.7, 4.7) else side * 5.43 + grain:NextNumber(-0.42, 0.42)
		local length = grain:NextNumber(0.12, 0.7)
		local size = if vertical then V(0.025, length, 0.025) else V(length, 0.025, 0.025)
		local p = piece(ctx, "BayWeatheredGrain", size, CFrame.new(x, y, -1.145), s.wood, Enum.Material.Wood)
		p.Transparency = 0.5
	end
	-- Ten rope turns, each made from two interwoven strands. Their elliptical
	-- path follows the posts, with the knotwork visible from the road.
	for _, side in { -1, 1 } do
		for _, y in { 5.65, 5.2, -4.9, -5.35, -5.8 } do
			for strand = 0, 1 do
				local function point(a: number): Vector3
					local twist = a * 7 + strand * math.pi
					local radial = math.cos(twist) * 0.055
					return V(side * 9.65 + math.cos(a) * (1.02 + radial), y + math.sin(twist) * 0.075,
						0.02 + math.sin(a) * (1.32 + radial))
				end
				for segment = 0, 23 do
					local a = segment * math.pi * 2 / 24
					local color = if strand == 0 then s.rope else s.ropeLight
					bayTube(ctx, "BayRopeStrand", point(a), point(a + math.pi * 2 / 24), 0.23, color, Enum.Material.SmoothPlastic)
				end
			end
		end
	end
	-- Life ring: a true open torus with four red cloth bands, backed by rope.
	local ring = V(0, 6.2, -1.38)
	for i = 0, 47 do
		local a, b = i * math.pi / 24, (i + 1) * math.pi / 24
		local color = if (i + 2) % 12 < 4 then s.red else s.cream
		bayTube(ctx, "BayLifeRing", ring + V(math.sin(a) * 1.12, math.cos(a) * 1.12, 0),
			ring + V(math.sin(b) * 1.12, math.cos(b) * 1.12, 0), 0.65, color, Enum.Material.SmoothPlastic)
		bayTube(ctx, "BayLifeRingRope", ring + V(math.sin(a) * 1.52, math.cos(a) * 1.52, 0.12),
			ring + V(math.sin(b) * 1.52, math.cos(b) * 1.52, 0.12), 0.15, s.rope, Enum.Material.SmoothPlastic)
	end
	-- The mockup's lower-right shell cluster sits on the sill, below all text.
	local star = CFrame.new(-8.5, -4.95, -1.3) * CFrame.Angles(0, 0, 0.18)
	ellipsoid(ctx, "BayStarfishCentre", V(0.62, 0.62, 0.26), star, s.starfish, Enum.Material.SmoothPlastic)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local arm = star * CFrame.Angles(0, 0, a)
		ellipsoid(ctx, "BayStarfishArm", V(0.32, 1.03, 0.24), arm * CFrame.new(0, 0.46, 0), s.starfish, Enum.Material.SmoothPlastic)
		for j = 1, 3 do
			ellipsoid(ctx, "BayStarfishTexture", V(0.055, 0.055, 0.035), arm * CFrame.new(0, j * 0.19, -0.15), s.cream, Enum.Material.SmoothPlastic)
		end
	end
	local scallop = CFrame.new(-7.35, -5.5, -1.28) * CFrame.Angles(0, 0, 0.25)
	ellipsoid(ctx, "BayScallop", V(0.97, 1.08, 0.34), scallop, s.shell, Enum.Material.SmoothPlastic)
	for i = -3, 3 do
		local a = i * 0.14
		ellipsoid(ctx, "BayScallopRib", V(0.07, 0.95, 0.1), scallop * CFrame.new(i * 0.092, 0, -0.17) * CFrame.Angles(0, 0, -a), s.cream, Enum.Material.SmoothPlastic)
	end
	local snail = V(-8.4, -5.85, -1.28)
	ellipsoid(ctx, "BaySpiralShell", V(0.67, 0.62, 0.3), CFrame.new(snail), s.shell, Enum.Material.SmoothPlastic)
	for i = 0, 17 do
		local a, b = i * 0.48, (i + 1) * 0.48
		local ra, rb = 0.24 - i * 0.011, 0.24 - (i + 1) * 0.011
		bayTube(ctx, "BayShellSpiral", snail + V(math.cos(a) * ra, math.sin(a) * ra, -0.16),
			snail + V(math.cos(b) * rb, math.sin(b) * rb, -0.16), 0.035, s.cream, Enum.Material.SmoothPlastic)
	end
end

-- -------------------------------------------------------------- cinder
-- Reference: docs/art/region-boards/2026-09-20-mockups/cinder-canyon.png.
-- Rusty canyon stone posts split by ember cracks, a charcoal basalt frame
-- bolted at every corner with a copper bracket plate, and a stepped volcano
-- crest whose lava fissure forks down a cone of broken rock.
local CINDER = {
	stone = rgb(158, 80, 60),
	stoneLit = rgb(190, 104, 76),
	stoneDark = rgb(116, 54, 41),
	basalt = rgb(63, 53, 53),
	basaltLit = rgb(97, 84, 84),
	basaltDark = rgb(38, 31, 32),
	copper = rgb(176, 104, 66),
	copperLit = rgb(212, 142, 94),
	copperDark = rgb(120, 67, 44),
	lava = rgb(255, 172, 66),
	ember = rgb(226, 88, 26),
	emberCore = rgb(255, 226, 158),
	shard = rgb(198, 82, 50),
	shardLit = rgb(228, 122, 78),
	panel = rgb(34, 32, 34),
}

-- Cinder Canyon stands on the longest legs of the family: the mockup gives it
-- 5.6 studs of post and stepped footing below the panel, so the ground is 10.6
-- under the board centre and the lowest basalt course lands exactly on it.
local CINDER_GROUND = -10.6

-- One ember fissure: neon slivers inside a wider, softer sleeve, so a crack
-- reads hot-cored the way the mockup's do. Each joint's kink comes from the
-- segment index, never a random, so every server builds the same board.
local function emberCrack(ctx: Ctx, name: string, from: Vector3, heading: number, span: number, segments: number, phase: number, width: number)
	local x, y = from.X, from.Y
	local step = span / segments
	for i = 0, segments - 1 do
		local a = heading + math.sin(phase + i * 2.2) * 0.5
		local nx, ny = x + math.cos(a) * step, y + math.sin(a) * step
		local mid = CFrame.new((x + nx) / 2, (y + ny) / 2, from.Z) * CFrame.Angles(0, 0, a)
		-- A crack bleeds out as it runs, as the heat behind it does.
		local taper = 1 - i / (segments * 1.7)
		local halo = piece(ctx, name .. "Halo", V(step * 1.32, width * 2.2 * taper, width * 0.66), mid * CFrame.new(0, 0, 0.06), CINDER.ember, Enum.Material.Neon)
		halo.Transparency = 0.45
		halo.CastShadow = false
		local core = piece(ctx, name, V(step * 1.26, width * taper, width * 0.5), mid, CINDER.lava, Enum.Material.Neon)
		core.CastShadow = false
		x, y = nx, ny
	end
end

-- A domed copper rivet: seat, head and the catchlight every head carries in the
-- mockup. Twelve of them on the board, so it earns the three lines.
local function cinderRivet(ctx: Ctx, name: string, cf: CFrame, diameter: number)
	disc(ctx, name .. "Seat", diameter, 0.14, cf, CINDER.copperDark, Enum.Material.Metal)
	ellipsoid(ctx, name, V(diameter * 0.8, diameter * 0.8, diameter * 0.46), cf * CFrame.new(0, 0, -0.11), CINDER.copper, Enum.Material.Metal)
	ellipsoid(ctx, name .. "Shine", V(diameter * 0.28, diameter * 0.28, diameter * 0.16), cf * CFrame.new(-diameter * 0.15, diameter * 0.15, -0.2), CINDER.copperLit, Enum.Material.Metal)
end

local function cinder(ctx: Ctx)
	local s = CINDER

	-- Faceted ember shards, tucked against each footing where the mockup piles
	-- them, and yawed off-axis so a box reads as a cut crystal.
	-- x, y, z, width, height, depth, yaw, lean.
	local shards = {
		{ 10.15, -8.6, -1.62, 0.6, 1.5, 0.52, 0.62, 0.1 },
		{ 10.62, -9.04, -1.52, 0.46, 0.86, 0.42, -0.48, -0.2 },
		{ 9.76, -9, -1.8, 0.4, 0.74, 0.36, 0.34, 0.16 },
	}

	-- Posts, their rail-end caps and the stepped footings are the only solid
	-- pieces on the board. Every inner face sits at |x| >= 7.9, outside the 7.2
	-- the approach sightlines sweep, and the three that reach into y -4.5 .. 4.5
	-- stand at |x| >= 8.2, outboard of the text rows.
	for _, side in { -1, 1 } do
		local x = side * 9.4
		piece(ctx, "CinderPost", V(2, 15, 1.9), CFrame.new(x, -1, -0.25), s.stone, Enum.Material.Rock, true)
		-- The mockup's posts swell where they meet the stone rather than taper.
		piece(ctx, "CinderPostFlare", V(2.35, 1.7, 2.15), CFrame.new(x, -7.85, -0.3), s.stone, Enum.Material.Rock, true)
		piece(ctx, "CinderPostCap", V(2.4, 2.35, 2.25), CFrame.new(x, 5.75, -0.35), s.basalt, Enum.Material.Slate, true)
		piece(ctx, "CinderPostCapBevel", V(2.05, 0.3, 1.95), CFrame.new(x, 7.07, -0.35), s.basaltLit, Enum.Material.Slate)
		-- Quarried, not milled: a lit arris inboard and a shadowed one outboard.
		piece(ctx, "CinderPostArris", V(0.3, 14.2, 0.34), CFrame.new(side * 8.56, -1.1, -1.12), s.stoneLit, Enum.Material.Rock)
		piece(ctx, "CinderPostArris", V(0.3, 14.2, 0.34), CFrame.new(side * 10.24, -1.1, -1.12), s.stoneDark, Enum.Material.Rock)

		-- Three basalt courses, each wider than the one above, then the low
		-- outboard step the mockup sets beside the near foot.
		piece(ctx, "CinderFootingTop", V(2.5, 0.45, 2.5), CFrame.new(x, -8.775, -0.3), s.basaltLit, Enum.Material.Slate, true)
		piece(ctx, "CinderFooting", V(2.75, 0.95, 2.75), CFrame.new(x, -9.475, -0.3), s.basalt, Enum.Material.Slate, true)
		piece(ctx, "CinderFootingBase", V(2.95, 0.65, 2.9), CFrame.new(x, CINDER_GROUND + 0.325, -0.3), s.basalt, Enum.Material.Slate, true)
		piece(ctx, "CinderFootingStep", V(1.5, 1.2, 2), CFrame.new(side * 10.15, CINDER_GROUND + 0.6, -0.4), s.basalt, Enum.Material.Slate, true)
		cinderRivet(ctx, "CinderFootingRivet", CFrame.new(x + side * 0.2, -9.45, -1.85), 0.6)
		cinderRivet(ctx, "CinderStepRivet", CFrame.new(side * 10.15, -10.02, -1.47), 0.42)

		for _, d in shards do
			local cf = CFrame.new(side * d[1], d[2], d[3]) * CFrame.Angles(0, side * d[7], side * d[8])
			piece(ctx, "CinderShard", V(d[4], d[5], d[6]), cf, s.shard, Enum.Material.Glass)
			piece(ctx, "CinderShardTip", V(d[4] * 0.62, d[5] * 0.42, d[6] * 0.62), cf * CFrame.new(0, d[5] * 0.58, 0) * CFrame.Angles(0, 0, side * 0.22), s.shardLit, Enum.Material.Glass)
			piece(ctx, "CinderShardFacet", V(d[4] * 0.3, d[5] * 0.7, d[6] * 0.3), cf * CFrame.new(-d[4] * 0.3, 0, -d[6] * 0.2), s.shardLit, Enum.Material.Glass)
		end
		piece(ctx, "CinderRubble", V(0.62, 0.42, 0.58), CFrame.new(side * 8.35, -10.32, -1.55) * CFrame.Angles(0, side * 0.5, side * 0.12), s.basaltDark, Enum.Material.Slate)
		piece(ctx, "CinderRubble", V(0.44, 0.34, 0.4), CFrame.new(side * 10.6, -10.34, -1.1) * CFrame.Angles(0, -side * 0.4, -side * 0.18), s.basalt, Enum.Material.Slate)

		-- Post cracks: the brightest on the board, running out across the face
		-- of the stone from just inboard of the post centre.
		for i = 0, 3 do
			local tilt = math.rad(if i % 2 == 0 then 26 else -31)
			local head = if side > 0 then tilt else math.pi - tilt
			emberCrack(ctx, "CinderPostEmber", V(side * 8.78, 3.2 - i * 3, -1.27), head, 1.35, 3, i * 1.7, 0.1)
		end
	end

	-- Frame: a straight basalt rail top and bottom, each with a proud cap lip
	-- and a shallower tapered end past the post. The rails hold the proven 4.72
	-- inner face, so the Element and Forecast rows stay uncovered.
	for _, rail in { 1, -1 } do
		piece(ctx, "CinderRail", V(20.2, 1.33, 1.15), CFrame.new(0, rail * 5.385, -0.575), s.basalt, Enum.Material.Slate)
		piece(ctx, "CinderRailCap", V(20.9, 0.4, 1.45), CFrame.new(0, rail * 6.25, -0.5), s.basaltLit, Enum.Material.Slate)
		for _, side in { -1, 1 } do
			piece(ctx, "CinderRailEnd", V(0.9, 0.95, 1.1), CFrame.new(side * 10.45, rail * 5.385, -0.58), s.basalt, Enum.Material.Slate)
			-- Heat seeps from the rail's inner arris, but only across the outer
			-- thirds: the mockup keeps the middle of the frame cold and plain.
			local seam = piece(ctx, "CinderRailSeam", V(3.4, 0.09, 0.06), CFrame.new(side * 8.6, rail * 4.79, -1.19), s.lava, Enum.Material.Neon)
			seam.Transparency = 0.45
			seam.CastShadow = false
			for i = 0, 1 do
				local tilt = math.rad(15 - i * 36) * rail
				local head = if side > 0 then tilt else math.pi - tilt
				emberCrack(ctx, "CinderFrameEmber", V(side * (4.6 + i * 3.1), rail * (5.2 + i * 0.3), -1.22), head, 1.5, 3, i * 2.3 + side, 0.09)
			end
		end
	end

	-- Copper corner brackets, the board's signature: a bevelled plate straddling
	-- every rail-and-post junction with one domed rivet dead centre, plus the
	-- small rivet the mockup sets just inside each panel corner -- at |x| 8.55,
	-- outboard of the 8.1 the text rows reach.
	for _, side in { -1, 1 } do
		for _, rail in { 1, -1 } do
			local x, y = side * 9.4, rail * 5.55
			piece(ctx, "CinderBracketPlate", V(1.75, 1.85, 0.28), CFrame.new(x, y, -1.47), s.copperDark, Enum.Material.Metal)
			piece(ctx, "CinderBracketFace", V(1.42, 1.52, 0.2), CFrame.new(x, y, -1.7), s.copper, Enum.Material.Metal)
			cinderRivet(ctx, "CinderBracketRivet", CFrame.new(x, y, -1.88), 0.66)
			cinderRivet(ctx, "CinderPanelRivet", CFrame.new(side * 8.55, rail * 4.15, -0.52), 0.5)
		end
	end

	-- Crest: a stepped volcano over the top rail. A long shelf on the cap, two
	-- stepped shoulders a side set behind it, then the triangular basalt outline
	-- -- base half width 2.4 on the shelf, apex at y 9.5, so its legs lean 0.835
	-- rad -- standing proud of the shoulders so it reads as the front plane.
	piece(ctx, "CinderCrestShelf", V(7.9, 0.42, 1.55), CFrame.new(0, 6.66, -0.45), s.basalt, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		piece(ctx, "CinderCrestShoulder", V(1.25, 1.2, 1.3), CFrame.new(side * 1.72, 7.45, -0.32), s.basalt, Enum.Material.Slate)
		piece(ctx, "CinderCrestShoulderCap", V(1.35, 0.12, 1.36), CFrame.new(side * 1.72, 8.11, -0.32), s.basaltLit, Enum.Material.Slate)
		piece(ctx, "CinderCrestStep", V(1.08, 0.62, 1.2), CFrame.new(side * 2.82, 7.16, -0.34), s.basalt, Enum.Material.Slate)
		piece(ctx, "CinderCrestStepCap", V(1.16, 0.1, 1.26), CFrame.new(side * 2.82, 7.52, -0.34), s.basaltLit, Enum.Material.Slate)
		local leg = CFrame.new(side * 1.2, 8.175, -0.55) * CFrame.Angles(0, 0, -side * 0.835)
		piece(ctx, "CinderCrestLeg", V(3.62, 0.75, 1.4), leg, s.basalt, Enum.Material.Slate)
		-- The inner chamfer that gives the crest its doubled outline.
		piece(ctx, "CinderCrestLegBevel", V(3.4, 0.22, 0.26), leg * CFrame.new(0, -0.22, -0.83), s.basaltLit, Enum.Material.Slate)
	end
	piece(ctx, "CinderCrestApexSeam", V(0.14, 0.5, 0.22), CFrame.new(0, 9.35, -1.22), s.basaltDark, Enum.Material.Slate)

	-- Backglow behind the cone, so every seam between its rocks runs warm.
	for _, band in { { 2.7, 7.4 }, { 2.1, 8.25 }, { 1.35, 9 } } do
		local glow = piece(ctx, "CinderCrestGlow", V(band[1], 0.95, 0.6), CFrame.new(0, band[2], -0.3), s.ember, Enum.Material.Neon)
		glow.Transparency = 0.3
		glow.CastShadow = false
	end
	-- The cone inside the triangle: stacked, canted blocks, so the silhouette
	-- behind the fissure is broken stone and not one slab.
	-- x, y, width, height, cant.
	local cone = {
		{ -0.88, 7.25, 1.14, 0.94, 0.14 },
		{ 0, 7.2, 0.98, 0.86, -0.06 },
		{ 0.88, 7.25, 1.14, 0.94, -0.14 },
		{ -0.66, 8.05, 1, 0.86, -0.17 },
		{ 0.1, 8.08, 0.88, 0.82, 0.09 },
		{ 0.78, 8.03, 0.94, 0.82, 0.18 },
		{ -0.46, 8.75, 0.76, 0.68, 0.22 },
		{ 0.18, 8.8, 0.72, 0.64, -0.1 },
		{ 0.6, 8.7, 0.7, 0.62, -0.24 },
		{ -0.05, 9.25, 0.56, 0.46, 0.08 },
	}
	for i, r in cone do
		local cf = CFrame.new(r[1], r[2], -0.9) * CFrame.Angles(0, 0, r[5])
		local shade = if i % 2 == 0 then s.basalt else s.basaltDark
		piece(ctx, "CinderCrestRock", V(r[3], r[4], 0.5), cf, shade, Enum.Material.Slate)
		if i % 3 == 0 then
			piece(ctx, "CinderCrestRockLit", V(r[3] * 0.88, 0.1, 0.54), cf * CFrame.new(0, r[4] * 0.42, 0), s.basaltLit, Enum.Material.Slate)
		end
	end
	-- The fissure the mockup runs down the cone: a trunk out of the vent that
	-- forks low, and the vent itself burning through the summit.
	emberCrack(ctx, "CinderCrestFissure", V(0.04, 8.72, -1.25), -math.pi / 2 + 0.08, 1, 3, 0.35, 0.27)
	emberCrack(ctx, "CinderCrestFissure", V(-0.02, 7.82, -1.25), -math.pi / 2 - 0.6, 0.88, 3, 1.4, 0.19)
	emberCrack(ctx, "CinderCrestFissure", V(0.08, 7.82, -1.25), -math.pi / 2 + 0.55, 0.82, 3, 2.6, 0.17)
	local vent = ellipsoid(ctx, "CinderCrestVent", V(1.25, 0.62, 0.36), CFrame.new(0, 8.95, -1.18), s.lava, Enum.Material.Neon)
	vent.Transparency = 0.1
	ellipsoid(ctx, "CinderCrestVentCore", V(0.62, 0.3, 0.24), CFrame.new(0, 8.95, -1.28), s.emberCore, Enum.Material.Neon)
end

-- --------------------------------------------------------------- frostbite
-- Reference: docs/art/region-boards/2026-09-20-mockups/frostbite-peaks.png.
-- Blue-grey slate uprights on stepped plinths carry a faceted ice frame, snow
-- settles on every upward face, and a slate hexagon above the top rail holds a
-- six-armed ice crystal.
local FROST = {
	stone = rgb(88, 102, 128),
	stoneLit = rgb(119, 134, 160),
	ice = rgb(134, 172, 210),
	iceLit = rgb(177, 206, 233),
	iceDark = rgb(101, 139, 185),
	gem = rgb(122, 145, 177),
	icicle = rgb(158, 203, 233),
	crystal = rgb(199, 228, 247),
	snow = rgb(234, 239, 249),
	snowShade = rgb(203, 213, 233),
	medallion = rgb(38, 48, 70),
	panel = rgb(23, 38, 63),
}

-- Posts stand as far out as the widest plinth tier allows: the step, the base
-- and the ground drift all reach |x| = 11 exactly, the outer limit, which fixes
-- the post centre at 9.75 and leaves the ice frame the 8.3 .. 8.85 band inboard
-- of it. Legs are longer than the Bay's because the mockup stacks four plinth
-- tiers under the board, not one footing.
local FROST_POST_X = 9.75
local FROST_GROUND = -9.4
local FROST_CREST_Y = 7
local FROST_HEX_W = 1.7
local FROST_HEX_H = 2

-- Icicles taper to a point and primitives do not, so a spike is a short stack
-- of shrinking boxes. Five steps is the fewest that still reads as a point from
-- the road the board is approached along.
local function frostSpike(ctx: Ctx, name: string, top: Vector3, length: number, width: number, color: Color3)
	local steps = 5
	for i = 0, steps - 1 do
		local w = width * (1 - i / steps)
		piece(ctx, name, V(w, length / steps * 1.1, w * 0.85),
			CFrame.new(top.X, top.Y - (i + 0.5) * length / steps, top.Z), color, Enum.Material.Ice)
	end
end

-- The crest hexagon and the post gems are pointy-top polygons no primitive can
-- cut, so both are stacked slabs: half-width is flat within |y| <= waist and
-- tapers to the apex beyond it. waist = halfW / 2 gives the crest's hexagon,
-- waist = 0 collapses the flat and gives the gems' rhombus.
local function frostFace(ctx: Ctx, name: string, centre: Vector3, halfW: number, halfH: number,
	waist: number, depth: number, rows: number, color: Color3, material: Enum.Material)
	for i = 1, rows do
		local y = -halfH + 2 * halfH * (i - 0.5) / rows
		local w = if math.abs(y) <= waist then halfW else halfW * (halfH - math.abs(y)) / (halfH - waist)
		piece(ctx, name, V(w * 2, 2 * halfH / rows + 0.05, depth),
			CFrame.new(centre.X, centre.Y + y, centre.Z), color, material)
	end
end

local function frostbite(ctx: Ctx)
	local s = FROST
	-- Angle of the hexagon's upper edge, from the side vertex to the apex. The
	-- rim bars and the snow that settles on them are both laid along it.
	local slant = math.atan2(FROST_HEX_H - FROST_HEX_W / 2, FROST_HEX_W)

	-- Posts, caps and plinths are the only solid pieces on this board, and the
	-- innermost face any of them presents is |x| = 8.5: clear of the 8.1 the
	-- text rows reach and of the 7.2 the approach sightlines sweep.
	for _, side in { -1, 1 } do
		local x = side * FROST_POST_X

		piece(ctx, "FrostPost", V(1.8, 12.6, 2), CFrame.new(x, -0.3, -0.3), s.stone, Enum.Material.Slate, true)
		-- A lit arris down each front corner. The mockup's stone is cut, not
		-- rounded, and these two bright edges are what says so at a distance.
		-- They run only over the exposed shaft, y -5.45 .. 5.65, so they never
		-- end up a hundredth of a stud behind the collar and neck faces.
		for _, edge in { -1, 1 } do
			piece(ctx, "FrostPostArris", V(0.22, 11.1, 0.24), CFrame.new(x + edge * 0.79, 0.1, -1.36), s.stoneLit, Enum.Material.Slate)
		end

		-- Cap: neck, lower chamfer, block, upper chamfer. Four tiers are what
		-- give the mockup's cap its overhang without a bevelled mesh. Each tier
		-- stands further forward than the post except the top bevel, which is
		-- inset because that is the face the light catches.
		piece(ctx, "FrostPostNeck", V(1.95, 0.32, 2.3), CFrame.new(x, 5.81, -0.3), s.stone, Enum.Material.Slate, true)
		piece(ctx, "FrostPostCapChamfer", V(2.12, 0.22, 2.4), CFrame.new(x, 6.08, -0.3), s.stoneLit, Enum.Material.Slate, true)
		piece(ctx, "FrostPostCap", V(2.3, 0.9, 2.5), CFrame.new(x, 6.64, -0.3), s.stone, Enum.Material.Slate, true)
		piece(ctx, "FrostPostCapBevel", V(2.06, 0.24, 2.26), CFrame.new(x, 7.21, -0.3), s.stoneLit, Enum.Material.Slate, true)

		-- Snow lies over each cap as a soft dome, heaped towards the back.
		ellipsoid(ctx, "FrostCapSnow", V(2.24, 1, 2.42), CFrame.new(x, 7.42, -0.34), s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostCapSnow", V(1.15, 0.62, 1.1), CFrame.new(x - side * 0.42, 7.72, -0.75), s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostCapSnow", V(0.9, 0.5, 0.95), CFrame.new(x + side * 0.46, 7.6, -0.05), s.snowShade, Enum.Material.Snow)

		-- Three icicles under each cap, two long and one stub, biased inboard
		-- exactly as the mockup hangs them, and all three standing in front of
		-- the post face so they read against the stone rather than through it.
		for _, spike in { { -0.55, 1.8, 0.34 }, { -0.12, 2.4, 0.42 }, { 0.34, 1.25, 0.28 } } do
			frostSpike(ctx, "FrostIcicle", V(x + side * spike[1], 5.66, -1.44), spike[2], spike[3], s.icicle)
		end

		-- A faceted ice rhombus set into the post at 91% of the way down the
		-- board, where the mockup cuts it, its lower point just grazing the snow
		-- heaped on the plinth collar. The ridge and waist bars are the two
		-- facet seams the mockup draws across its front.
		frostFace(ctx, "FrostPostGem", V(x, -4.1, -1.45), 0.52, 0.95, 0, 0.3, 9, s.gem, Enum.Material.Ice)
		piece(ctx, "FrostPostGemRidge", V(0.12, 1.24, 0.18), CFrame.new(x, -4.1, -1.63), s.iceLit, Enum.Material.Ice)
		piece(ctx, "FrostPostGemWaist", V(0.78, 0.1, 0.18), CFrame.new(x, -4.1, -1.63), s.iceLit, Enum.Material.Ice)

		-- Stepped plinth: collar, shaft, step, base. The step and base flare to
		-- |x| = 11 to get the mockup's broad footing, and the base lip's
		-- underside is the ground plane itself.
		piece(ctx, "FrostPlinthCollar", V(2.15, 1, 2.35), CFrame.new(x, -5.95, -0.32), s.stone, Enum.Material.Slate, true)
		piece(ctx, "FrostPlinthCollarLip", V(2, 0.2, 2.2), CFrame.new(x, -6.55, -0.32), s.stoneLit, Enum.Material.Slate, true)
		piece(ctx, "FrostPlinthShaft", V(1.9, 1.35, 2.1), CFrame.new(x, -7.32, -0.32), s.stone, Enum.Material.Slate, true)
		piece(ctx, "FrostPlinthStep", V(2.5, 0.28, 2.6), CFrame.new(x, -8.13, -0.34), s.stoneLit, Enum.Material.Slate, true)
		piece(ctx, "FrostPlinthBase", V(2.5, 0.95, 2.72), CFrame.new(x, -8.75, -0.34), s.stone, Enum.Material.Slate, true)
		piece(ctx, "FrostPlinthBaseLip", V(2.3, 0.18, 2.5), CFrame.new(x, FROST_GROUND + 0.09, -0.34), s.stoneLit, Enum.Material.Slate, true)

		-- Snow on both upward-facing tiers, and a drift banked around the base.
		ellipsoid(ctx, "FrostPlinthSnow", V(2.25, 0.42, 2.45), CFrame.new(x, -5.38, -0.32), s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostPlinthSnow", V(1.2, 0.34, 1.2), CFrame.new(x - side * 0.5, -5.22, -0.7), s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostPlinthSnow", V(0.9, 0.28, 1), CFrame.new(x + side * 0.55, -5.28, 0.1), s.snowShade, Enum.Material.Snow)
		ellipsoid(ctx, "FrostPlinthSnow", V(2.5, 0.5, 2.65), CFrame.new(x, -7.9, -0.34), s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostPlinthSnow", V(1.3, 0.4, 1.3), CFrame.new(x - side * 0.45, -7.72, -0.85), s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostPlinthSnow", V(1, 0.3, 1.1), CFrame.new(x + side * 0.5, -7.78, 0.2), s.snowShade, Enum.Material.Snow)
		ellipsoid(ctx, "FrostDrift", V(2.5, 0.6, 2.9), CFrame.new(x, FROST_GROUND + 0.3, -0.34), s.snow, Enum.Material.Snow)
	end

	-- The ice frame, inboard of the posts and none of it solid. The top rail's
	-- underside is 4.7 and the bottom rail's top is -4.7, the proven clearances;
	-- the side rails stop at |x| = 8.3 and run 0.2 into the posts, so that joint
	-- has no pair of coincident faces to shimmer.
	for _, y in { 5.15, -5.15 } do
		piece(ctx, "FrostRail", V(16.1, 0.9, 0.75), CFrame.new(0, y, -0.6), s.ice, Enum.Material.Ice)
	end
	for _, side in { -1, 1 } do
		piece(ctx, "FrostRail", V(0.75, 9.6, 0.75), CFrame.new(side * 8.675, 0, -0.6), s.ice, Enum.Material.Ice)
		-- The mockup takes all four corners off at 45 degrees. Kept short, so
		-- the diagonal crosses |x| = 8.1 at 4.656, still above the Element row.
		for _, vert in { -1, 1 } do
			piece(ctx, "FrostRailCorner", V(1.25, 0.8, 0.75),
				CFrame.new(side * 8.42, vert * 4.9, -0.6) * CFrame.Angles(0, 0, -side * vert * math.rad(46)),
				s.ice, Enum.Material.Ice)
		end
	end
	-- A bright lip where the ice meets the navy: the frame's inner highlight.
	for _, y in { 4.78, -4.78 } do
		piece(ctx, "FrostRailLip", V(16.4, 0.16, 0.2), CFrame.new(0, y, -1), s.iceLit, Enum.Material.Ice)
	end
	for _, side in { -1, 1 } do
		piece(ctx, "FrostRailLip", V(0.16, 9.7, 0.2), CFrame.new(side * 8.38, 0, -1), s.iceLit, Enum.Material.Ice)
	end

	-- Faceting: the mockup cuts the ice into a zigzag of triangles along every
	-- rail, which is what a row of squares turned 45 degrees becomes once the
	-- tones alternate. Half-diagonal 0.41 keeps the top row's lowest point at
	-- 4.74, still inside the rail and above the text.
	for i = 0, 16 do
		local tone = if i % 2 == 0 then s.iceLit else s.iceDark
		for _, y in { 5.15, -5.15 } do
			piece(ctx, "FrostRailFacet", V(0.58, 0.58, 0.2),
				CFrame.new(-7.6 + i * 0.95, y, -1.03) * CFrame.Angles(0, 0, math.pi / 4), tone, Enum.Material.Ice)
		end
	end
	for _, side in { -1, 1 } do
		for i = 0, 9 do
			local tone = if i % 2 == 0 then s.iceDark else s.iceLit
			piece(ctx, "FrostRailFacet", V(0.52, 0.52, 0.2),
				CFrame.new(side * 8.675, -4.3 + i * 0.955, -1.03) * CFrame.Angles(0, 0, math.pi / 4), tone, Enum.Material.Ice)
		end
	end

	-- A narrow drift along the top rail only, since that is the one rail snow
	-- can sit on. Its ridge is driven off the loop index through sin and cos, so
	-- the same lumps land in the same places on every build.
	piece(ctx, "FrostRailSnow", V(16.6, 0.3, 0.95), CFrame.new(0, 5.68, -0.62), s.snow, Enum.Material.Snow)
	for i = 0, 20 do
		local h = 0.5 + 0.17 * math.sin(i * 1.7) + 0.09 * math.cos(i * 2.9)
		local tone = if i % 3 == 0 then s.snowShade else s.snow
		ellipsoid(ctx, "FrostRailSnow", V(1.05, h, 1.02), CFrame.new(-8.4 + i * 0.84, 5.66 + h * 0.4, -0.63), tone, Enum.Material.Snow)
	end

	-- Crest: a pointy-top slate hexagon standing clear above the top rail, its
	-- lower half in front of the rail. The lowest rim corner is 4.763 and the
	-- lowest body slab 4.975, so the Element row at 4.5 is clear. The stack runs
	-- strictly forward -- body 1.26, rim 1.34, inlay 1.42, crystal 1.61 -- so the
	-- medallion and the flake on it are in front of the slate they sit on rather
	-- than sealed inside it.
	local crest = V(0, FROST_CREST_Y, -0.95)
	frostFace(ctx, "FrostCrestBody", crest, FROST_HEX_W, FROST_HEX_H, FROST_HEX_W / 2, 0.62, 11, s.stone, Enum.Material.Slate)
	frostFace(ctx, "FrostCrestInlay", V(0, FROST_CREST_Y, -1.34), 1.3, 1.55, 0.75, 0.16, 11, s.medallion, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		-- The upright rim is cut to the flat side it traces, 1.7 long, so the
		-- four slanted bars mitre onto its ends instead of past the vertices.
		piece(ctx, "FrostCrestRim", V(0.5, 1.7, 0.68), CFrame.new(side * FROST_HEX_W, FROST_CREST_Y, -1), s.stoneLit, Enum.Material.Slate)
		for _, vert in { -1, 1 } do
			piece(ctx, "FrostCrestRim", V(2.16, 0.5, 0.68),
				CFrame.new(side * FROST_HEX_W / 2, FROST_CREST_Y + vert * (FROST_HEX_H + FROST_HEX_W / 2) / 2, -1)
					* CFrame.Angles(0, 0, -side * vert * slant),
				s.stoneLit, Enum.Material.Slate)
		end
		-- Snow catches on the two upper edges and nowhere else. Each blob is
		-- turned onto the slant and set on the edge line, so it beds into the
		-- slate instead of floating off the slope.
		ellipsoid(ctx, "FrostCrestSnow", V(1.15, 0.36, 0.66),
			CFrame.new(side * 1.19, FROST_CREST_Y + 1.275, -1.36) * CFrame.Angles(0, 0, -side * slant),
			s.snow, Enum.Material.Snow)
		ellipsoid(ctx, "FrostCrestSnow", V(0.85, 0.3, 0.58),
			CFrame.new(side * 0.595, FROST_CREST_Y + 1.675, -1.34) * CFrame.Angles(0, 0, -side * slant),
			s.snowShade, Enum.Material.Snow)
	end

	-- Six-armed crystal: every arm is a shaft, a diamond spearhead and two pairs
	-- of swept branches. The three arms facing the light keep the pale crystal
	-- tone and the three facing away take the darker ice, which is the shading
	-- the mockup paints across the flake's lower-left half.
	for i = 0, 5 do
		local a = math.rad(90 + i * 60)
		local tone = if math.cos(a - math.rad(50)) > 0 then s.crystal else s.iceLit
		piece(ctx, "FrostFlakeArm", V(1.24, 0.17, 0.2),
			CFrame.new(math.cos(a) * 0.59, FROST_CREST_Y + math.sin(a) * 0.59, -1.51) * CFrame.Angles(0, 0, a),
			tone, Enum.Material.Ice)
		piece(ctx, "FrostFlakeTip", V(0.34, 0.34, 0.22),
			CFrame.new(math.cos(a) * 1.04, FROST_CREST_Y + math.sin(a) * 1.04, -1.52) * CFrame.Angles(0, 0, a + math.pi / 4),
			s.crystal, Enum.Material.Ice)
		for _, branch in { { 0.5, 0.54 }, { 0.9, 0.34 } } do
			for _, wing in { -1, 1 } do
				local b = a + wing * math.rad(54)
				piece(ctx, "FrostFlakeBranch", V(branch[2], 0.14, 0.19),
					CFrame.new(math.cos(a) * branch[1] + math.cos(b) * branch[2] / 2,
						FROST_CREST_Y + math.sin(a) * branch[1] + math.sin(b) * branch[2] / 2, -1.5)
						* CFrame.Angles(0, 0, b),
					tone, Enum.Material.Ice)
			end
		end
	end
	piece(ctx, "FrostFlakeHub", V(0.42, 0.42, 0.24),
		CFrame.new(0, FROST_CREST_Y, -1.53) * CFrame.Angles(0, 0, math.pi / 4), s.crystal, Enum.Material.Ice)
end

-- ------------------------------------------------------------- thunderworks
-- Reference: docs/art/region-boards/2026-09-20-mockups/thunderworks.png
-- Substation steel: weathered blue-grey rails with armoured chamfered corners
-- over a near-black panel, a hazard-striped outer cap rail split by the
-- lightning crest, ceramic insulators and cable drops on the post heads.
local WORKS = {
	steel = rgb(101, 108, 126),
	steelLit = rgb(134, 141, 158),
	post = rgb(78, 82, 95),
	shadow = rgb(54, 57, 66),
	panel = rgb(31, 31, 37),
	concrete = rgb(134, 128, 122),
	bolt = rgb(138, 132, 121),
	rust = rgb(156, 96, 54),
	hazard = rgb(232, 176, 52),
	brass = rgb(255, 214, 74),
	ceramic = rgb(226, 220, 206),
	ceramicShade = rgb(194, 187, 172),
	cable = rgb(34, 33, 38),
	lamp = rgb(255, 178, 74),
	lampCore = rgb(255, 236, 176),
}

-- Every fastener on this board is the same pair: a seated rim and a head proud
-- of it. Two dozen of them ride the four corner brackets and the crest, so the
-- pair is worth a name.
local function worksBolt(ctx: Ctx, x: number, y: number, z: number, diameter: number)
	disc(ctx, "SignBoltRim", diameter, 0.16, CFrame.new(x, y, z), WORKS.shadow, Enum.Material.Metal)
	disc(ctx, "SignBoltHead", diameter * 0.72, 0.2, CFrame.new(x, y, z - 0.14), WORKS.bolt, Enum.Material.Metal)
end

-- The insulator drops are the only free curves on the board; like BayRope they
-- are drawn as short cylinders between sampled points.
local function worksCable(ctx: Ctx, a: Vector3, b: Vector3, diameter: number): Part
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local p = piece(ctx, "SignCable", V((b - a).Magnitude * 1.1, diameter, diameter), cf, WORKS.cable, Enum.Material.Rubber)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function thunderworks(ctx: Ctx)
	local s = WORKS

	-- The mockup's legs are half the board again, so the ground is 9.9 below
	-- the centre and the plinth's underside lands exactly on it. Post centres
	-- sit at 9.55: far enough out for a plinth that reads as a plinth, and the
	-- widest piece still stops at 10.975, clear of the approach road.
	for _, side in { -1, 1 } do
		local x = side * 9.55
		piece(ctx, "WorksPlinth", V(2.85, 1.65, 2.3), CFrame.new(x, -9.075, 0.05), s.concrete, Enum.Material.Concrete, true)
		piece(ctx, "WorksPlinthCap", V(2.55, 0.23, 2.05), CFrame.new(x, -8.135, 0.05), s.concrete:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Concrete, true)
		piece(ctx, "WorksBasePlate", V(2.6, 0.32, 2.2), CFrame.new(x, -7.86, 0.05), s.shadow, Enum.Material.DiamondPlate)
		piece(ctx, "WorksPostCollar", V(1.9, 0.4, 1.8), CFrame.new(x, -7.5, 0.1), s.post, Enum.Material.Metal)
		piece(ctx, "WorksPost", V(1.8, 13.2, 1.9), CFrame.new(x, -0.7, 0.15), s.post, Enum.Material.CorrodedMetal, true)
		piece(ctx, "WorksPostCap", V(2.06, 0.36, 2), CFrame.new(x, 6.08, 0.15), s.steel, Enum.Material.Metal, true)
		-- The exposed leg reads as an I-beam: a raised web filling the 1.28
		-- studs of bare post between the collar top and the bottom rail.
		piece(ctx, "WorksPostWeb", V(0.72, 1.28, 0.2), CFrame.new(x, -6.66, -0.85), s.steelLit, Enum.Material.Metal)
		-- Ten nuts ring the post on the base plate: four to a long edge and one
		-- to each end.
		for i = 0, 9 do
			local dx = if i == 8 then -1.08 elseif i == 9 then 1.08 else -1.08 + (i % 4) * 0.72
			local dz = if i >= 8 then 0 elseif i < 4 then -0.92 else 0.92
			piece(ctx, "WorksBaseNut", V(0.34, 0.3, 0.34), CFrame.new(x + dx, -7.55, 0.05 + dz), s.bolt, Enum.Material.Metal)
		end
	end

	-- Frame. The rails clear the live rows with room to spare: the top rail's
	-- underside is 4.88 and the bottom rail's top -4.88, against the 4.5 the
	-- Element and Forecast rows reach; the side rails stop outside |x| 8.7.
	piece(ctx, "WorksTopRail", V(20.9, 1, 0.86), CFrame.new(0, 5.38, -0.62), s.steel, Enum.Material.Metal)
	piece(ctx, "WorksTopRailLip", V(20.9, 0.16, 0.3), CFrame.new(0, 5.8, -1.02), s.steelLit, Enum.Material.Metal)
	piece(ctx, "WorksBottomRail", V(20.9, 1.14, 0.86), CFrame.new(0, -5.45, -0.62), s.steel, Enum.Material.Metal)
	piece(ctx, "WorksBottomRailLip", V(20.9, 0.16, 0.3), CFrame.new(0, -5.94, -1.02), s.steelLit, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		piece(ctx, "WorksSideRail", V(0.92, 10.9, 0.62), CFrame.new(side * 9.16, 0, -0.78), s.steel, Enum.Material.Metal)
		piece(ctx, "WorksSideRailLip", V(0.14, 8.6, 0.26), CFrame.new(side * 8.78, 0, -1.16), s.steelLit, Enum.Material.Metal)
	end
	for _, y in { 4.95, -4.95 } do
		piece(ctx, "WorksBezel", V(17.2, 0.14, 0.26), CFrame.new(0, y, -1.14), s.steelLit, Enum.Material.Metal)
	end

	-- Armoured corners: an L of plate over each corner of the frame with its
	-- inner edge cut at 45 degrees across the panel corner. The cut's leading
	-- point is 8.166, so every rotated corner stays outside the 8.1 the rows
	-- reach while the chamfer still bites a clear stud out of the panel. The
	-- upright leg is only as wide as the side rail it armours, so its outer
	-- edge stops at 9.97 and leaves the post's outer face to the lamp.
	for _, side in { -1, 1 } do
		for _, vert in { -1, 1 } do
			piece(ctx, "WorksCornerPlate", V(1.1, 2.1, 0.28), CFrame.new(side * 9.42, vert * 3.95, -1.16), s.steelLit, Enum.Material.Metal)
			piece(ctx, "WorksCornerPlate", V(2.25, 1.05, 0.28), CFrame.new(side * 9.35, vert * 5.38, -1.16), s.steelLit, Enum.Material.Metal)
			local cut = CFrame.new(side * 8.82, vert * 4.52, -1.18) * CFrame.Angles(0, 0, math.rad(-45) * side * vert)
			piece(ctx, "WorksCornerChamfer", V(1.35, 0.5, 0.26), cut, s.steelLit, Enum.Material.Metal)
			piece(ctx, "WorksCornerChamferLip", V(1.1, 0.16, 0.2), cut * CFrame.new(0, -0.24, -0.16), s.steel, Enum.Material.Metal)
			for _, spot in { V(9.62, 5.38, 0), V(8.62, 5.38, 0), V(9.42, 4.2, 0), V(9.42, 3.15, 0) } do
				worksBolt(ctx, side * spot.X, vert * spot.Y, -1.34, 0.44)
			end
		end
	end

	-- Cap rail: the outer rail that carries the hazard runs the whole span
	-- between the post heads, one run either side of the crest. Both runs lean
	-- the same way, as painted stripes do.
	piece(ctx, "WorksCapRail", V(16.6, 0.82, 0.8), CFrame.new(0, 6.27, -0.45), s.shadow, Enum.Material.Metal)
	piece(ctx, "WorksCapRailTop", V(16.6, 0.14, 0.9), CFrame.new(0, 6.72, -0.45), s.steel, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		piece(ctx, "WorksCapRailEnd", V(0.18, 0.9, 0.84), CFrame.new(side * 8.39, 6.27, -0.45), s.steel, Enum.Material.Metal)
		for i = 0, 5 do
			piece(ctx, "WorksHazardStripe", V(0.62, 0.64, 0.1),
				CFrame.new(side * (2.85 + i), 6.27, -0.9) * CFrame.Angles(0, 0, math.rad(30)),
				s.hazard, Enum.Material.SmoothPlastic)
		end
	end

	-- Crest: a lightning badge in a bolted circular housing on a backing plate,
	-- centred above the cap rail and cresting it by most of a radius.
	piece(ctx, "WorksCrestPlate", V(4.4, 2.1, 0.5), CFrame.new(0, 6.12, -1.02), s.steel, Enum.Material.Metal)
	piece(ctx, "WorksCrestFlange", V(4.9, 0.5, 0.42), CFrame.new(0, 5.3, -0.95), s.steel, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		worksBolt(ctx, side * 1.8, 6.6, -1.3, 0.42)
	end
	disc(ctx, "WorksCrestRing", 3.05, 0.34, CFrame.new(0, 6.6, -1.45), s.steel, Enum.Material.Metal)
	disc(ctx, "WorksCrestBevel", 2.56, 0.3, CFrame.new(0, 6.6, -1.44), s.steelLit, Enum.Material.Metal)
	disc(ctx, "WorksCrestFace", 2.3, 0.3, CFrame.new(0, 6.6, -1.4), s.shadow, Enum.Material.Metal)
	-- Radial ticks machined into the housing rim, flush with its front face.
	-- Under about a tenth of a stud thick they stop reading from the road.
	for i = 0, 11 do
		local a = math.rad(15 + i * 30)
		piece(ctx, "WorksCrestNotch", V(0.3, 0.13, 0.08),
			CFrame.new(math.cos(a) * 1.33, 6.6 + math.sin(a) * 1.33, -1.66) * CFrame.Angles(0, 0, a),
			s.shadow, Enum.Material.Metal)
	end
	for i = 0, 3 do
		local a = math.rad(i * 90)
		worksBolt(ctx, math.cos(a) * 1.36, 6.6 + math.sin(a) * 1.36, -1.66, 0.36)
	end

	-- Lightning bolt: two arms and their tips leaning with the stripes, joined
	-- by the middle jog. Every rotated corner stays inside the 1.15 recess.
	piece(ctx, "WorksCrestBolt", V(0.53, 1.32, 0.14), CFrame.new(-0.026, 6.89, -1.62) * CFrame.Angles(0, 0, math.rad(34)), s.brass, Enum.Material.SmoothPlastic)
	piece(ctx, "WorksCrestBolt", V(0.3, 0.4, 0.14), CFrame.new(-0.414, 7.374, -1.62) * CFrame.Angles(0, 0, math.rad(34)), s.brass, Enum.Material.SmoothPlastic)
	piece(ctx, "WorksCrestBolt", V(1.14, 0.46, 0.14), CFrame.new(-0.185, 6.53, -1.62) * CFrame.Angles(0, 0, math.rad(-12)), s.brass, Enum.Material.SmoothPlastic)
	piece(ctx, "WorksCrestBolt", V(0.48, 1.21, 0.14), CFrame.new(-0.326, 6.181, -1.62) * CFrame.Angles(0, 0, math.rad(34)), s.brass, Enum.Material.SmoothPlastic)
	piece(ctx, "WorksCrestBolt", V(0.26, 0.38, 0.14), CFrame.new(0.026, 5.72, -1.62) * CFrame.Angles(0, 0, math.rad(34)), s.brass, Enum.Material.SmoothPlastic)

	-- Porcelain insulators on the post heads. The sheds narrow as they rise,
	-- as glazed porcelain does, and two cables drop from each cap onto the cap
	-- rail end. Enum.Material has no Ceramic member; SmoothPlastic is the glaze.
	for _, side in { -1, 1 } do
		local x = side * 9.32
		piece(ctx, "WorksInsulatorBase", V(0.74, 0.22, 0.74), CFrame.new(x, 6.34, 0.15), s.shadow, Enum.Material.Metal)
		local core = piece(ctx, "WorksInsulatorCore", V(1.5, 0.5, 0.5), CFrame.new(x, 7.14, 0.15) * CFrame.Angles(0, 0, math.pi / 2), s.ceramicShade, Enum.Material.SmoothPlastic)
		core.Shape = Enum.PartType.Cylinder
		for i = 0, 5 do
			local width = 1.18 - i * 0.076
			local flange = piece(ctx, "WorksInsulatorShed", V(0.15, width, width),
				CFrame.new(x, 6.5 + i * 0.26, 0.15) * CFrame.Angles(0, 0, math.pi / 2), s.ceramic, Enum.Material.SmoothPlastic)
			flange.Shape = Enum.PartType.Cylinder
		end
		piece(ctx, "WorksInsulatorCap", V(0.62, 0.3, 0.62), CFrame.new(x, 8.02, 0.15), s.shadow, Enum.Material.Metal)
		piece(ctx, "WorksInsulatorKnob", V(0.3, 0.18, 0.3), CFrame.new(x, 8.25, 0.15), s.bolt, Enum.Material.Metal)
		for strand = 0, 1 do
			local p0 = V(x + side * 0.24, 8.02 - strand * 0.18, 0.02 + strand * 0.26)
			local p1 = V(side * 9.95, 8.95 - strand * 0.3, -0.3 + strand * 0.22)
			local p2 = V(side * 8.42, 6.72 - strand * 0.22, -0.5 + strand * 0.2)
			local function point(t: number): Vector3
				local u = 1 - t
				return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
			end
			for segment = 0, 7 do
				worksCable(ctx, point(segment / 8), point((segment + 1) / 8), 0.22)
			end
			piece(ctx, "WorksCableClamp", V(0.3, 0.32, 0.38), CFrame.new(p2.X, p2.Y - 0.06, p2.Z), s.shadow, Enum.Material.Metal)
		end
	end

	-- A caged pilot light on the outer face of each post. It hangs below the
	-- corner armour's top leg and outboard of its upright, so the two never
	-- interpenetrate, and it sits a stud and a third outside the panel, so
	-- nothing warm falls across a word.
	for _, side in { -1, 1 } do
		local x = side * 10.4
		piece(ctx, "WorksLampPlate", V(0.9, 1.5, 0.2), CFrame.new(x, 3.95, -0.9), s.shadow, Enum.Material.Metal)
		piece(ctx, "WorksLampHood", V(0.86, 0.22, 0.52), CFrame.new(x, 4.61, -1.06), s.steel, Enum.Material.Metal)
		piece(ctx, "WorksLampBase", V(0.86, 0.22, 0.52), CFrame.new(x, 3.29, -1.06), s.steel, Enum.Material.Metal)
		ellipsoid(ctx, "WorksLampGlass", V(0.6, 1.02, 0.5), CFrame.new(x, 3.95, -1.08), s.lamp, Enum.Material.Neon)
		ellipsoid(ctx, "WorksLampCore", V(0.3, 0.6, 0.26), CFrame.new(x, 3.95, -1.15), s.lampCore, Enum.Material.Neon)
		for i = -1, 1 do
			piece(ctx, "WorksLampCageBar", V(0.07, 1, 0.1), CFrame.new(x + i * 0.21, 3.95, -1.38), s.bolt, Enum.Material.Metal)
		end
		piece(ctx, "WorksLampCageBand", V(0.62, 0.07, 0.1), CFrame.new(x, 3.95, -1.38), s.bolt, Enum.Material.Metal)
	end

	-- Weathering is read off the loop index, never sampled, so every server
	-- streaks the same steel. The first fourteen run down the exposed outer
	-- face of the posts, outside |x| 9.96; the rest lie along the rails,
	-- outside |y| 5.38. Nothing lands where a row could be reading.
	for i = 1, 26 do
		local side = if i % 2 == 0 then 1 else -1
		local onPost = i <= 14
		local x = if onPost then side * (10.18 + math.cos(i * 1.7) * 0.22) else side * (1.6 + math.abs(math.sin(i * 2.4)) * 7.4)
		local y = if onPost then -7 + ((i * 1.31) % 1) * 12.4 else (if i % 4 < 2 then 5.42 else -5.52)
		local length = 0.5 + math.abs(math.cos(i * 0.9)) * 1.5
		local size = if onPost then V(0.07, length, 0.07) else V(length, 0.07, 0.07)
		local streak = piece(ctx, "WorksRust", size, CFrame.new(x, y, if onPost then -0.86 else -1.07), s.rust, Enum.Material.CorrodedMetal)
		streak.Transparency = 0.42
	end
end

-- ------------------------------------------------------------- orbit
-- Reference: docs/art/region-boards/2026-09-20-mockups/orbit-outpost.png
-- A machined pale-silver plate with all four corners chamfered, laid over a
-- midnight-purple panel: lavender lamp strips sunk into the side members, gold
-- star studs in the panel's cut corners, a ringed-planet medallion cresting the
-- top rail, and stubby graphite posts on bolted octagonal footings.
local ORBIT = {
	silver = rgb(186, 178, 196),
	silverLit = rgb(210, 203, 220),
	silverDark = rgb(146, 139, 158),
	violet = rgb(140, 98, 222),
	violetDeep = rgb(96, 66, 168),
	lamp = rgb(238, 222, 255),
	graphite = rgb(84, 80, 98),
	graphiteDark = rgb(62, 59, 76),
	steel = rgb(140, 136, 152),
	steelLit = rgb(164, 159, 176),
	bolt = rgb(180, 177, 192),
	gold = rgb(238, 218, 158),
	goldDeep = rgb(206, 172, 108),
	cream = rgb(243, 228, 202),
	creamLit = rgb(255, 246, 228),
	ring = rgb(158, 124, 240),
	ringShade = rgb(104, 78, 176),
	crestInk = rgb(62, 52, 86),
	panel = rgb(34, 29, 56),
}

-- The mockup's legs run to nearly half the panel height, the longest in the
-- family, so the footings land at y = -10 rather than Splashwater's -8.6.
local ORBIT_GROUND = -10
local ORBIT_LEG_X = 7.45
-- The legs share the frame's depth centre so post, collar and footing line up.
local ORBIT_LEG_Z = -0.35
local ORBIT_DIAG = math.sqrt(2)

-- One chamfered rectangular ring of the frame: four rails plus a 45-degree bar
-- per corner. Solving the bar from the ring's own inner/outer boxes makes its
-- long outer face and the rails' outer corners land on a single diagonal, so
-- the silhouette closes exactly and no notch is left to patch by eye.
local function orbRing(ctx: Ctx, name: string, ix: number, iy: number, ox: number, oy: number, cut: number, z: number, depth: number, color: Color3, material: Enum.Material?)
	local inner = ix + iy - cut
	local outer = inner + ((ox - ix) + (oy - iy)) / ORBIT_DIAG
	local mid = (inner + outer) / 2
	local bar = (outer - inner) / ORBIT_DIAG
	local length = (ox + oy - mid) * ORBIT_DIAG - bar
	local cx = ox - (length + bar) / (2 * ORBIT_DIAG)
	local cy = mid - cx
	for _, s in { -1, 1 } do
		piece(ctx, name, V((outer - oy) * 2, oy - iy, depth), CFrame.new(0, s * (iy + oy) / 2, z), color, material)
		piece(ctx, name, V(ox - ix, (outer - ox) * 2, depth), CFrame.new(s * (ix + ox) / 2, 0, z), color, material)
		for _, sx in { -1, 1 } do
			piece(ctx, name .. "Corner", V(length, bar, depth),
				CFrame.new(sx * cx, s * cy, z) * CFrame.Angles(0, 0, -sx * s * math.pi / 4), color, material)
		end
	end
end

-- A cylinder stood on end: the primitive's axis is its X, so roll it onto +Y.
local function orbColumn(ctx: Ctx, name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local p = piece(ctx, name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function orbit(ctx: Ctx)
	local s = ORBIT

	-- Four concentric chamfered rings make the frame read as one milled plate:
	-- a dark outer rim, the main face, a raised inner lip, and the violet trim
	-- line lying on the panel. All share the 1.25 corner cut, so the facet runs
	-- unbroken from the panel out to the silhouette. The rails' inner faces are
	-- 4.85 and 8.9, outside the 4.5/8.1 the text rows reach.
	orbRing(ctx, "OrbitFrameRim", 9.05, 5, 10.5, 6.2, 1.25, -0.05, 0.9, s.silverDark, Enum.Material.Metal)
	orbRing(ctx, "OrbitFrame", 8.9, 4.85, 10.35, 6.05, 1.25, -0.4, 1.3, s.silver, Enum.Material.Metal)
	orbRing(ctx, "OrbitFrameLip", 8.9, 4.85, 9.62, 5.55, 1.25, -0.62, 1.34, s.silverLit, Enum.Material.Metal)
	orbRing(ctx, "OrbitTrim", 8.62, 4.58, 8.86, 4.82, 0.95, -0.44, 0.1, s.violet, Enum.Material.SmoothPlastic)

	-- The violet the mockup lays across each cut corner: a broad band pressed
	-- against the lip and a hairline further out, both parallel to the facet.
	for _, band in {
		{ x = 9.04, y = 4.74, size = V(2.55, 0.46, 0.18) },
		{ x = 9.38, y = 5.08, size = V(1.95, 0.16, 0.18) },
	} do
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				piece(ctx, "OrbitCornerBand", band.size,
					CFrame.new(sx * band.x, sy * band.y, -1.11) * CFrame.Angles(0, 0, -sx * sy * math.pi / 4),
					s.violet, Enum.Material.SmoothPlastic)
			end
		end
	end

	-- Indicator strips sunk into the outer half of each side member, the part
	-- the lip leaves exposed. Neon is confined to a 0.42-wide lens so the
	-- lettering stays the brightest thing on the board.
	for _, sx in { -1, 1 } do
		local x = sx * 9.985
		piece(ctx, "OrbitLampBezel", V(0.8, 3.62, 0.34), CFrame.new(x, 0, -0.97), s.violetDeep, Enum.Material.SmoothPlastic)
		piece(ctx, "OrbitLamp", V(0.42, 3.06, 0.3), CFrame.new(x, 0, -1.06), s.lamp, Enum.Material.Neon)
		for _, sy in { -1, 1 } do
			ellipsoid(ctx, "OrbitLampBezelCap", V(0.8, 0.8, 0.34), CFrame.new(x, sy * 1.81, -0.97), s.violetDeep, Enum.Material.SmoothPlastic)
			ellipsoid(ctx, "OrbitLampCap", V(0.42, 0.42, 0.3), CFrame.new(x, sy * 1.53, -1.06), s.lamp, Enum.Material.Neon)
		end
	end

	-- Four-pointed studs in the panel's cut corners. Their tips reach 8.18 and
	-- 4.63, inside the rows' nominal span but in the corners a centred row
	-- always leaves empty, exactly where Gusty parks its daisies.
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local cx, cy = sx * 7.65, sy * 4.1
			for i = 0, 3 do
				local a = i * math.pi / 2
				ellipsoid(ctx, "OrbitStarPoint", V(0.2, 0.54, 0.18),
					CFrame.new(cx + math.sin(a) * 0.26, cy + math.cos(a) * 0.26, -0.44) * CFrame.Angles(0, 0, a),
					s.gold, Enum.Material.Metal)
			end
			ellipsoid(ctx, "OrbitStarBoss", V(0.28, 0.28, 0.22), CFrame.new(cx, cy, -0.47), s.goldDeep, Enum.Material.Metal)
		end
	end

	-- Crest. Raised fins run out from the medallion along the top rail, their
	-- outer ends cut at 45 degrees to echo the frame's corners.
	for _, sx in { -1, 1 } do
		piece(ctx, "OrbitCrestMount", V(0.9, 1.3, 0.55), CFrame.new(sx * 0.95, 5.8, -0.72), s.silverDark, Enum.Material.Metal)
		piece(ctx, "OrbitCrestFin", V(2.6, 0.7, 0.42), CFrame.new(sx * 2.8, 5.62, -1.18), s.silverLit, Enum.Material.Metal)
		piece(ctx, "OrbitCrestFinEnd", V(0.56, 0.56, 0.42), CFrame.new(sx * 4.38, 5.62, -1.18) * CFrame.Angles(0, 0, math.pi / 4), s.silverLit, Enum.Material.Metal)
		piece(ctx, "OrbitCrestFinEdge", V(2.6, 0.1, 0.44), CFrame.new(sx * 2.8, 5.99, -1.19), s.silverDark, Enum.Material.Metal)
	end

	-- The medallion crests the rail and dips onto the panel. Its rim bottoms
	-- out at y 4.50, the Element row's top edge, and no lower.
	disc(ctx, "OrbitCrestRim", 3.56, 0.5, CFrame.new(0, 6.28, -0.95), s.silverDark, Enum.Material.Metal)
	disc(ctx, "OrbitCrestRing", 3.4, 0.62, CFrame.new(0, 6.28, -1.16), s.silver, Enum.Material.Metal)
	-- The groove disc is wider but sits further back, so only a violet annulus
	-- shows between the silver ring and the recessed face.
	disc(ctx, "OrbitCrestGroove", 2.66, 0.46, CFrame.new(0, 6.28, -1.04), s.violet, Enum.Material.SmoothPlastic)
	disc(ctx, "OrbitCrestFace", 2.52, 0.5, CFrame.new(0, 6.28, -1.06), s.crestInk, Enum.Material.Slate)
	ellipsoid(ctx, "OrbitPlanet", V(1.52, 1.52, 0.78), CFrame.new(0, 6.38, -1.38), s.cream, Enum.Material.SmoothPlastic)
	ellipsoid(ctx, "OrbitPlanetLight", V(0.52, 0.44, 0.3), CFrame.new(-0.34, 6.72, -1.72), s.creamLit, Enum.Material.SmoothPlastic)

	-- The orbital ring is a tilted ellipse whose near arc is carried forward of
	-- the planet and whose far arc sinks behind it, so it reads as a ring in
	-- depth instead of a painted oval. Depth follows sin of the parameter.
	local tilt = math.rad(17)
	local function orbitPoint(k: number): (number, number, number)
		local t = k * math.pi / 16
		local ex, ey = math.cos(t) * 1.3, math.sin(t) * 0.37
		return ex * math.cos(tilt) - ey * math.sin(tilt), ex * math.sin(tilt) + ey * math.cos(tilt), -1.4 + math.sin(t) * 0.42
	end
	for i = 0, 31 do
		local ax, ay, az = orbitPoint(i)
		local bx, by, bz = orbitPoint(i + 1)
		local mz = (az + bz) / 2
		local span = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
		-- the half of the ring passing behind the planet takes the shaded tone
		local tone = if mz < -1.4 then s.ring else s.ringShade
		piece(ctx, "OrbitRingArc", V(span * 1.18, 0.17, 0.19),
			CFrame.new((ax + bx) / 2, 6.36 + (ay + by) / 2, mz) * CFrame.Angles(0, 0, math.atan2(by - ay, bx - ax)),
			tone, Enum.Material.SmoothPlastic)
	end

	-- Legs. A 2.3-wide graphite drum only 1.93 tall, a glowing collar ring, a
	-- steel drum and the stepped octagonal footing on the ground at y = -10.
	-- Every load-bearing piece sits below y = -6, so none of them can reach the
	-- 27 approach sightlines, which only sample |y| <= 4.
	for _, sx in { -1, 1 } do
		local x = sx * ORBIT_LEG_X
		orbColumn(ctx, "OrbitPostCap", 2.44, 0.22, CFrame.new(x, -6.04, ORBIT_LEG_Z), s.silverDark, Enum.Material.Metal, true)
		orbColumn(ctx, "OrbitPost", 2.3, 1.93, CFrame.new(x, -7.015, ORBIT_LEG_Z), s.graphite, Enum.Material.Metal, true)
		orbColumn(ctx, "OrbitPostSeam", 2.34, 0.12, CFrame.new(x, -6.3, ORBIT_LEG_Z), s.graphiteDark, Enum.Material.Metal)
		orbColumn(ctx, "OrbitGlowBand", 2.74, 0.24, CFrame.new(x, -8.09, ORBIT_LEG_Z), s.violetDeep, Enum.Material.SmoothPlastic)
		orbColumn(ctx, "OrbitGlowCore", 2.66, 0.15, CFrame.new(x, -8.09, ORBIT_LEG_Z), s.violet, Enum.Material.Neon)
		orbColumn(ctx, "OrbitGlowLip", 2.7, 0.07, CFrame.new(x, -7.99, ORBIT_LEG_Z), s.lamp, Enum.Material.Neon)
		orbColumn(ctx, "OrbitCollar", 2.86, 0.55, CFrame.new(x, -8.475, ORBIT_LEG_Z), s.steel, Enum.Material.Metal, true)
		orbColumn(ctx, "OrbitCollarRim", 3, 0.16, CFrame.new(x, -8.7, ORBIT_LEG_Z), s.steelLit, Enum.Material.Metal)

		-- Each footing tier is a wide slab crossed with a deep one, leaving four
		-- corner notches that a 45-degree bar fills. The bar's outer corners land
		-- on the notch's two tips, so the eight faces close into a true octagon.
		-- The rotation is about Y because this chamfer is in plan, not in the face.
		for _, tier in {
			{ w = 4.4, d = 3, h = 0.8, y = ORBIT_GROUND + 0.4, c = 0.62, tone = s.steel },
			{ w = 4, d = 2.7, h = 0.45, y = -8.975, c = 0.56, tone = s.steelLit },
		} do
			piece(ctx, "OrbitFooting", V(tier.w, tier.h, tier.d - tier.c * 2), CFrame.new(x, tier.y, ORBIT_LEG_Z), tier.tone, Enum.Material.Metal, true)
			piece(ctx, "OrbitFooting", V(tier.w - tier.c * 2, tier.h, tier.d), CFrame.new(x, tier.y, ORBIT_LEG_Z), tier.tone, Enum.Material.Metal, true)
			for _, fx in { -1, 1 } do
				for _, fz in { -1, 1 } do
					piece(ctx, "OrbitFootingFacet", V(tier.c * 1.42, tier.h, tier.c * 0.73),
						CFrame.new(x + fx * (tier.w / 2 - tier.c * 0.758), tier.y, ORBIT_LEG_Z + fz * (tier.d / 2 - tier.c * 0.758))
							* CFrame.Angles(0, fx * fz * math.pi / 4, 0), tier.tone, Enum.Material.Metal, true)
				end
			end
		end

		-- One bolt per octagon face on the upper band. The path is elliptical
		-- because the footing is wider than it is deep: the board's z budget
		-- stops at 1.2, so the plan is squashed front to back, not in x.
		for i = 0, 7 do
			local a = i * math.pi / 4
			ellipsoid(ctx, "OrbitFootingBolt", V(0.38, 0.38, 0.38),
				CFrame.new(x + math.cos(a) * 1.9, -8.94, ORBIT_LEG_Z + math.sin(a) * 1.25), s.bolt, Enum.Material.Metal)
		end
	end
end

-- ------------------------------------------------------------------- api
export type Style = { title: Color3, element: Color3 }

type Design = {
	build: (Ctx) -> (),
	panel: Color3,
	material: Enum.Material,
	title: Color3,
	element: Color3,
	height: number,
}

-- One entry per region whose board was built from concept art. `height` is the
-- board centre above ground: each concept shows its own length of leg between
-- the footings and the frame, and the board is placed to match.
local DESIGNS: { [string]: Design } = {
	Wind = { build = gusty, panel = rgb(43, 72, 51), material = Enum.Material.Wood,
		title = rgb(240, 233, 214), element = rgb(233, 226, 205), height = 7.5 },
	Water = { build = splashwater, panel = BAY.panel, material = Enum.Material.Wood,
		title = rgb(207, 235, 226), element = rgb(161, 207, 225), height = 8.6 },
	Heat = { build = cinder, panel = rgb(34, 32, 34), material = Enum.Material.Slate,
		title = rgb(243, 228, 199), element = rgb(250, 202, 138), height = 10.6 },
	Frost = { build = frostbite, panel = rgb(23, 38, 63), material = Enum.Material.Slate,
		title = rgb(238, 232, 219), element = rgb(163, 209, 238), height = 9.4 },
	Storm = { build = thunderworks, panel = rgb(31, 31, 37), material = Enum.Material.Metal,
		title = rgb(250, 216, 122), element = rgb(198, 192, 192), height = 9.9 },
	Cosmic = { build = orbit, panel = rgb(34, 29, 56), material = Enum.Material.Slate,
		title = rgb(238, 228, 252), element = rgb(197, 168, 244), height = 10 },
}

-- Where MapBuilder puts the board's centre. Read before `dress`, so the two
-- cannot disagree about which ground plane the footings were drawn against.
function RegionSign.height(element: string): number
	local design = DESIGNS[element]
	return if design then design.height else 7.5
end

-- Colours the board and builds its stand. Returns the colours MapBuilder gives
-- the two static text rows; the Cost and Forecast rows are the client's.
function RegionSign.dress(board: BasePart, stand: Model, signCF: CFrame, def: any, makePart: (any) -> Part): Style
	local ctx: Ctx = { stand = stand, cf = signCF, make = makePart }
	local design = DESIGNS[def.element]
	if design then
		board.Color = design.panel
		board.Material = design.material
		design.build(ctx)
		return { title = design.title, element = design.element }
	end
	board.Color = SLATE
	board.Material = Enum.Material.SmoothPlastic
	plain(ctx)
	return { title = def.color, element = rgb(210, 223, 233) }
end

return RegionSign
