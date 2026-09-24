--!strict
-- The 24-creature launch roster. Each region has exactly one species per
-- rarity. Income = region base x rarity multiplier (see Stats). `palette`
-- and `anim` feed the procedural model builders (Shared.Models.CreatureBuilders);
-- `job` names the work-pad animation the creature performs when deployed.
--
-- Builders are keyed by `id`. Model conventions: feet at y = 0, face on -Z,
-- total height ~= `height` studs.

local Regions = require(script.Parent.Regions)
local Rarities = require(script.Parent.Rarities)

export type SpeciesDef = {
	id: string,
	name: string,
	region: string, -- Regions id
	element: string,
	rarity: string,
	desc: string, -- Atlas entry
	silhouette: string, -- one-line shape description for undiscovered entries
	palette: { primary: Color3, secondary: Color3, accent: Color3 },
	anim: string, -- ModelKit anim style: bob waddle hop flutter sway spin hover orbit pulse flicker drift shift
	animSpeed: number,
	height: number,
	job: string, -- work animation on a pad: windmill | waterwheel | furnace | freezer | coil | dish
	difficulty: number, -- 1..5 stars shown on the encounter card
	eggOnly: boolean, -- hatches from a Cosmic Egg only: no wild spawn, not in Atlas completion
	builder: string?, -- reuse another species' model builder (ascended recolours)
	scale: number?, -- uniform model scale on top of the builder
}

local Species = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type DefOpts = { eggOnly: boolean?, builder: string?, scale: number? }

local function def(id: string, name: string, region: string, rarity: string, desc: string, silhouette: string, primary: Color3, secondary: Color3, accent: Color3, anim: string, animSpeed: number, height: number, opts: DefOpts?): SpeciesDef
	local r = Regions.byId[region]
	assert(r, "unknown region " .. region)
	local jobs = { Wind = "windmill", Water = "waterwheel", Heat = "furnace", Frost = "freezer", Storm = "coil", Cosmic = "dish" }
	local difficulty = math.clamp(Rarities.rank(rarity) + (if r.index >= 4 then 1 else 0), 1, 5)
	return {
		id = id,
		name = name,
		region = region,
		element = r.element,
		rarity = rarity,
		desc = desc,
		silhouette = silhouette,
		palette = { primary = primary, secondary = secondary, accent = accent },
		anim = anim,
		animSpeed = animSpeed,
		height = height,
		job = jobs[r.element],
		difficulty = difficulty,
		eggOnly = if opts then opts.eggOnly == true else false,
		builder = if opts then opts.builder else nil,
		scale = if opts then opts.scale else nil,
	}
end

Species.list = {
	-- Gusty Gardens / Wind
	def("breeze_bean", "Breeze Bean", "gusty_gardens", "Common", "A floating bean with leaf ears. It hums when the wind changes.", "a small floating bean with two leaf ears", rgb(150, 220, 120), rgb(90, 170, 80), rgb(255, 245, 200), "hover", 1.0, 2.7),
	def("gust_bunny", "Gust Bunny", "gusty_gardens", "Uncommon", "A rabbit whose feet are tiny cyclones. It never quite touches the ground.", "a long-eared bunny standing on two little whirlwinds", rgb(235, 235, 245), rgb(180, 200, 230), rgb(255, 150, 170), "hop", 1.2, 3.6),
	def("twister_terrier", "Twister Terrier", "gusty_gardens", "Rare", "A spiral-bodied dog wearing flight goggles. It spins when excited, which is always.", "a dog with a spiral body and goggles", rgb(200, 170, 120), rgb(140, 110, 80), rgb(120, 200, 230), "spin", 1.0, 3.4),
	def("sir_spins_a_lot", "Sir Spins-a-Lot", "gusty_gardens", "Legendary", "A tornado knight in sneakers, armed with a weather-vane lance. Very polite. Very fast.", "a tall tornado wearing a helmet and holding a lance", rgb(190, 205, 225), rgb(110, 125, 150), rgb(255, 210, 80), "sway", 1.3, 5.2),

	-- Splashwater Bay / Water
	def("drizzle_duck", "Drizzle Duck", "splashwater_bay", "Common", "A duck that wears its own tiny raincloud like a hat.", "a round duck with a small cloud above its head", rgb(255, 225, 90), rgb(255, 160, 60), rgb(200, 215, 235), "waddle", 1.1, 2.6),
	def("puddle_pug", "Puddle Pug", "splashwater_bay", "Uncommon", "A glossy pug made of puddle. Its paws splash with every step.", "a squat wrinkly dog with wide paws", rgb(90, 160, 235), rgb(60, 110, 190), rgb(240, 250, 255), "waddle", 1.0, 2.6),
	def("monsoon_manta", "Monsoon Manta", "splashwater_bay", "Rare", "A hovering manta ray that trails rain wherever it glides.", "a wide flat ray with a long tail", rgb(70, 110, 190), rgb(200, 230, 255), rgb(120, 200, 255), "hover", 0.8, 2.5),
	def("tsunami_toad", "Tsunami Toad", "splashwater_bay", "Legendary", "A crowned toad riding a wave that never breaks. Royalty of the bay.", "a big toad sitting on top of a curling wave", rgb(80, 170, 110), rgb(60, 130, 200), rgb(255, 210, 80), "bob", 0.9, 5.0),

	-- Cinder Canyon / Heat
	def("cinder_chick", "Cinder Chick", "cinder_canyon", "Common", "A charcoal chick with an ember crest that glows when it is happy.", "a tiny round chick with a spiky crest", rgb(60, 55, 60), rgb(255, 120, 40), rgb(255, 220, 90), "hop", 1.4, 2.4),
	def("sizzle_salamander", "Sizzle Salamander", "cinder_canyon", "Uncommon", "A salamander with glowing vents down its back. Do not touch the vents.", "a low lizard with a long tail and back vents", rgb(230, 90, 50), rgb(255, 170, 60), rgb(255, 240, 150), "sway", 1.0, 1.0),
	def("magma_muncher", "Magma Muncher", "cinder_canyon", "Rare", "A squat lava monster with furnace jaws. Eats rocks, burps sparks.", "a wide squat monster with a huge mouth", rgb(120, 40, 40), rgb(255, 100, 30), rgb(255, 230, 120), "pulse", 1.0, 2.6),
	def("mount_chomp", "Mount Chomp", "cinder_canyon", "Legendary", "A giant tortoise whose shell is an active volcano. Slow, smoky, and legendary.", "a giant tortoise with a volcano on its back", rgb(90, 110, 70), rgb(80, 60, 55), rgb(255, 110, 40), "bob", 0.5, 5.6),

	-- Frostbite Peaks / Frost
	def("flurry_ferret", "Flurry Ferret", "frostbite_peaks", "Common", "A snow ferret with a snowflake for a tail. It leaves frost footprints.", "a long slim ferret with a big snowflake tail", rgb(240, 245, 255), rgb(190, 215, 240), rgb(120, 190, 255), "waddle", 1.3, 2.2),
	def("slush_sloth", "Slush Sloth", "frostbite_peaks", "Uncommon", "A sleepy sloth hanging from its own little ice arch. Yawns in slow motion.", "a sloth hanging under an arch", rgb(150, 180, 200), rgb(110, 130, 160), rgb(200, 240, 255), "sway", 0.5, 3.6),
	def("blizzard_bison", "Blizzard Bison", "frostbite_peaks", "Rare", "A shaggy bison with icicle horns. Every snort is a small snowstorm.", "a heavy bison with two long horns", rgb(120, 100, 90), rgb(230, 240, 250), rgb(160, 220, 255), "bob", 0.8, 4.0),
	def("king_coldsnout", "King Coldsnout", "frostbite_peaks", "Legendary", "A royal mammoth wearing a glacier as a crown. The peaks answer to him.", "a huge mammoth with tusks and a tall crown", rgb(110, 130, 170), rgb(220, 235, 250), rgb(255, 215, 90), "bob", 0.5, 6.0),

	-- Thunderworks / Storm
	def("static_sprout", "Static Sprout", "thunderworks", "Common", "A sprout creature with electric hair that stands straight up. Always.", "a small sprout with spiky standing hair", rgb(120, 200, 90), rgb(255, 235, 90), rgb(255, 255, 200), "bob", 1.5, 2.8),
	def("zap_raccoon", "Zap Raccoon", "thunderworks", "Uncommon", "A raccoon with a lightning-striped tail. It steals batteries.", "a raccoon with a big striped tail", rgb(90, 90, 110), rgb(255, 230, 80), rgb(240, 240, 240), "waddle", 1.2, 3.2),
	def("thunder_thumper", "Thunder Thumper", "thunderworks", "Rare", "A gorilla with cloud fists. Every thump is a thunderclap.", "a big gorilla with two puffy fists", rgb(70, 70, 95), rgb(220, 225, 240), rgb(255, 230, 80), "pulse", 0.9, 4.2),
	def("boltjaw_behemoth", "Boltjaw Behemoth", "thunderworks", "Legendary", "A four-legged storm beast with lightning antlers. The sky follows it around.", "a large four-legged beast with jagged antlers", rgb(50, 50, 80), rgb(140, 150, 200), rgb(255, 240, 100), "sway", 0.8, 5.8),

	-- Orbit Outpost / Cosmic
	def("rubble_runt", "Rubble Runt", "orbit_outpost", "Common", "A lopsided asteroid cluster that learned to walk by magnetism. It collects every loose pebble.", "an asymmetrical asteroid cluster with magnetic feet", rgb(112, 96, 84), rgb(170, 150, 125), rgb(100, 220, 255), "bob", 1.1, 2.6),
	def("lagrange_loper", "Lagrange Loper", "orbit_outpost", "Uncommon", "Two celestial lobes share one orbit and never agree which way to turn.", "two unequal celestial lobes joined by a narrow bridge with two moons", rgb(90, 110, 150), rgb(170, 125, 80), rgb(140, 230, 255), "drift", 0.9, 3.5, { scale = 1.35 }),
	def("pulsar_prickle", "Pulsar Prickle", "orbit_outpost", "Rare", "A dense little star that flashes its magnetic poles whenever it gets excited.", "a flattened star with polar caps and four beam fins", rgb(70, 60, 90), rgb(255, 130, 80), rgb(120, 220, 255), "pulse", 1.0, 3.4),
	def("rochebreaker", "Rochebreaker", "orbit_outpost", "Legendary", "A tiny world caught past the Roche limit, proudly turning its own breakup into a parade.", "a stretched core pulling a separate mass through a curved fragment stream", rgb(85, 50, 100), rgb(160, 100, 180), rgb(255, 200, 80), "sway", 0.8, 5.0, { scale = 1.5 }),
} :: { SpeciesDef }

Species.byId = {} :: { [string]: SpeciesDef }
-- ---------------------------------------------------------------- egg-only roster
-- Showcase creatures, hatched from the Cosmic Egg and nowhere else. They may use
-- their own builders or borrow an existing builder. They are NOT in `Species.list`: that list
-- is the wild roster the Atlas counts, the spawner draws from and Relaunch
-- measures. `Species.byId` and `Species.all` include them.
Species.eggList = {
	def("nebula_noodle", "Nebula Noodle", "orbit_outpost", "Epic", "A living filament of nebula gas curls around an empty core and tickles anyone who gets too close.", "a chunky curled cloud filament wrapped around a dark core", rgb(90, 50, 140), rgb(220, 120, 180), rgb(110, 240, 255), "drift", 0.7, 4.2, { eggOnly = true, scale = 1.45 }),
	def("universe_seed", "Universe Seed", "orbit_outpost", "Mythic", "A seed-shaped pocket universe opens just enough to wave from inside.", "a faceted cosmic seed split by a seam and wrapped in orbital bands", rgb(35, 25, 60), rgb(150, 100, 220), rgb(255, 240, 150), "hover", 0.6, 5.4, { eggOnly = true, scale = 1.25 }),
} :: { SpeciesDef }

-- Wild roster plus egg roster. Use this to build models or look up any creature;
-- use `Species.list` when you mean "the creatures a player can find in the world".
Species.all = {} :: { SpeciesDef }
for _, s in Species.list do
	table.insert(Species.all, s)
end
for _, s in Species.eggList do
	table.insert(Species.all, s)
end

Species.byRegion = {} :: { [string]: { SpeciesDef } }
Species.byElement = {} :: { [string]: { SpeciesDef } }
for _, s in Species.list do
	Species.byId[s.id] = s
	Species.byRegion[s.region] = Species.byRegion[s.region] or {}
	table.insert(Species.byRegion[s.region], s)
	Species.byElement[s.element] = Species.byElement[s.element] or {}
	table.insert(Species.byElement[s.element], s)
end
-- Egg species are addressable by id (models, income, Atlas entries) but stay out
-- of byRegion / byElement so nothing that spawns or searches a region finds them.
Species.byRarity = {} :: { [string]: { SpeciesDef } }
for _, s in Species.eggList do
	Species.byId[s.id] = s
end
for _, s in Species.all do
	Species.byRarity[s.rarity] = Species.byRarity[s.rarity] or {}
	table.insert(Species.byRarity[s.rarity], s)
end

-- The Atlas denominator and the Relaunch requirement: wild species only.
Species.count = #Species.list
Species.eggCount = #Species.eggList
Species.tutorialSpecies = "breeze_bean"

-- Every egg-only species of a rarity, e.g. the two Mythics. Empty for the wild
-- tiers, which the egg draws from the player's unlocked regions instead.
function Species.eggSpecies(rarity: string): { SpeciesDef }
	local out = {}
	for _, s in Species.eggList do
		if s.rarity == rarity then
			table.insert(out, s)
		end
	end
	return out
end

-- The species of a region with the given rarity (exactly one per pair).
function Species.find(regionId: string, rarity: string): SpeciesDef?
	for _, s in Species.byRegion[regionId] or {} do
		if s.rarity == rarity then
			return s
		end
	end
	return nil
end

-- Normal (unmultiplied) income for a species: region base x rarity multiplier.
function Species.baseIncome(id: string): number
	local s = Species.byId[id]
	if not s then
		return 0
	end
	return Regions.byId[s.region].baseIncome * Rarities.info[s.rarity].mult
end

return Species
