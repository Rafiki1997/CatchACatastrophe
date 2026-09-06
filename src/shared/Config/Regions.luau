--!strict
-- The six wild regions. Order is progression order; `element` is the region's
-- single creature element; `baseIncome` is the regional base Coins/second a
-- Common creature from that region produces before multipliers.
-- `unlockCost` is the Coins price shown on the region gate (0 = open).

export type RegionDef = {
	id: string,
	name: string,
	element: string,
	index: number,
	baseIncome: number,
	unlockCost: number,
	color: Color3, -- element colour used by gates, UI badges and hazard telegraphs
	groundColor: Color3,
	desc: string,
	hazard: string, -- Config.Capture.hazards key
}

local Regions = {}

Regions.list = {
	{ id = "gusty_gardens", name = "Gusty Gardens", element = "Wind", index = 1, baseIncome = 4, unlockCost = 0, color = Color3.fromRGB(150, 230, 170), groundColor = Color3.fromRGB(120, 190, 100), desc = "Breezy meadows where little gusts play in the grass.", hazard = "Wind" },
	{ id = "splashwater_bay", name = "Splashwater Bay", element = "Water", index = 2, baseIncome = 8, unlockCost = 2500, color = Color3.fromRGB(90, 180, 255), groundColor = Color3.fromRGB(230, 210, 150), desc = "A sunny bay full of puddles, ducks and rolling waves.", hazard = "Water" },
	{ id = "cinder_canyon", name = "Cinder Canyon", element = "Heat", index = 3, baseIncome = 16, unlockCost = 15000, color = Color3.fromRGB(255, 120, 60), groundColor = Color3.fromRGB(120, 70, 50), desc = "Cracked red rock where the ground itself likes to sizzle.", hazard = "Heat" },
	{ id = "frostbite_peaks", name = "Frostbite Peaks", element = "Frost", index = 4, baseIncome = 32, unlockCost = 75000, color = Color3.fromRGB(170, 230, 255), groundColor = Color3.fromRGB(225, 240, 250), desc = "Snowy slopes and ice arches that never quite stop sliding.", hazard = "Frost" },
	{ id = "thunderworks", name = "Thunderworks", element = "Storm", index = 5, baseIncome = 64, unlockCost = 300000, color = Color3.fromRGB(255, 230, 90), groundColor = Color3.fromRGB(70, 70, 95), desc = "An old power yard where storm critters charge everything they touch.", hazard = "Storm" },
	{ id = "orbit_outpost", name = "Orbit Outpost", element = "Cosmic", index = 6, baseIncome = 128, unlockCost = 1000000, color = Color3.fromRGB(200, 130, 255), groundColor = Color3.fromRGB(45, 40, 70), desc = "A floating space station where gravity is more of a suggestion.", hazard = "Cosmic" },
} :: { RegionDef }

Regions.byId = {} :: { [string]: RegionDef }
Regions.byElement = {} :: { [string]: RegionDef }
for _, r in Regions.list do
	Regions.byId[r.id] = r
	Regions.byElement[r.element] = r
end

Regions.elements = { "Wind", "Water", "Heat", "Frost", "Storm", "Cosmic" }

-- Legendary guarantee + surge forecast (seconds). Every region spawns a
-- Legendary at least this often; the surge window opens when the forecast
-- timer reaches zero and lasts `surgeDuration` seconds.
Regions.legendaryInterval = 480
Regions.surgeDuration = 90

-- Wild population per region and respawn after a capture / expiry.
Regions.populationCap = 6
Regions.respawnDelay = { min = 6, max = 10 }

function Regions.elementColor(element: string): Color3
	local r = Regions.byElement[element]
	return if r then r.color else Color3.new(1, 1, 1)
end

return Regions
