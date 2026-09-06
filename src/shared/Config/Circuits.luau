--!strict
-- Disaster Circuits: two orthogonally adjacent occupied pads whose creature
-- elements match a recipe. Each creature is in at most one pair.
-- Pair key: the two pad indices sorted ascending, joined with "-" ("3-4").

export type CircuitDef = {
	id: string,
	name: string,
	elements: { string }, -- exactly two
	desc: string, -- visible result
	hint: string, -- Recipe Book hint while undiscovered
	color: Color3,
	machine: string, -- MachineryBuilders key
}

local Circuits = {}

Circuits.list = {
	{ id = "thunder_turbine", name = "Thunder Turbine", elements = { "Wind", "Storm" }, desc = "The turbine spins and lights up nearby buildings.", hint = "Something breezy plus something crackly.", color = Color3.fromRGB(255, 230, 90), machine = "thunder_turbine" },
	{ id = "steamworks", name = "Steamworks", elements = { "Water", "Heat" }, desc = "The boiler puffs steam and drives a big piston.", hint = "Pour something wet onto something hot.", color = Color3.fromRGB(220, 220, 230), machine = "steamworks" },
	{ id = "ice_cream_emergency", name = "Ice Cream Emergency", elements = { "Water", "Frost" }, desc = "The machine fills absurdly oversized ice-cream cones.", hint = "Something wet meets something freezing.", color = Color3.fromRGB(255, 190, 220), machine = "ice_cream_emergency" },
	{ id = "thermal_foundry", name = "Thermal Foundry", elements = { "Heat", "Frost" }, desc = "The forge swings hot and cold to stamp metal blocks.", hint = "Opposites make the best metal.", color = Color3.fromRGB(255, 140, 90), machine = "thermal_foundry" },
	{ id = "orbital_express", name = "Orbital Express", elements = { "Wind", "Cosmic" }, desc = "Tiny delivery pods orbit between the pads.", hint = "A gust strong enough to reach space.", color = Color3.fromRGB(200, 130, 255), machine = "orbital_express" },
	{ id = "neon_grid", name = "Neon Grid", elements = { "Storm", "Cosmic" }, desc = "Floating neon signs and arcade machines switch on.", hint = "Charge up something from beyond the sky.", color = Color3.fromRGB(90, 255, 220), machine = "neon_grid" },
} :: { CircuitDef }

Circuits.byId = {} :: { [string]: CircuitDef }
local byPair: { [string]: CircuitDef } = {}

local function elementKey(a: string, b: string): string
	if a < b then
		return a .. "+" .. b
	end
	return b .. "+" .. a
end

for _, c in Circuits.list do
	Circuits.byId[c.id] = c
	byPair[elementKey(c.elements[1], c.elements[2])] = c
end

-- Recipe lookup by two elements (order-independent). nil = no circuit.
function Circuits.recipe(elementA: string, elementB: string): CircuitDef?
	return byPair[elementKey(elementA, elementB)]
end

-- Income bonus each member receives while the circuit is active.
Circuits.baseBonus = 0.25
Circuits.upgradedBonus = 0.40

-- Upgrade cost: this many seconds of the pair's combined *normal* income
-- (region base x rarity x variant x relaunch, no circuit), never below `upgradeMinCost`.
Circuits.upgradeCostSeconds = 120
Circuits.upgradeMinCost = 500

-- Overdrive: pair output x2 for `activeSeconds`, then 0 for `cooldownSeconds`
-- unless the vent at the control booth was completed during the active phase.
Circuits.overdrive = {
	activeSeconds = 20,
	cooldownSeconds = 15,
	multiplier = 2,
	ventHoldSeconds = 1.5, -- ProximityPrompt hold at the booth
}

-- Pad grid on every city plot: `cols` x `rows` = 24 pads, index 1..24 row-major.
Circuits.grid = { cols = 6, rows = 4 }
Circuits.maxPads = Circuits.grid.cols * Circuits.grid.rows

function Circuits.padCoords(pad: number): (number, number)
	local col = (pad - 1) % Circuits.grid.cols + 1
	local row = (pad - 1) // Circuits.grid.cols + 1
	return col, row
end

function Circuits.areAdjacent(padA: number, padB: number): boolean
	if padA == padB then
		return false
	end
	local ca, ra = Circuits.padCoords(padA)
	local cb, rb = Circuits.padCoords(padB)
	return (ra == rb and math.abs(ca - cb) == 1) or (ca == cb and math.abs(ra - rb) == 1)
end

function Circuits.pairKey(padA: number, padB: number): string
	local lo, hi = math.min(padA, padB), math.max(padA, padB)
	return tostring(lo) .. "-" .. tostring(hi)
end

function Circuits.parsePairKey(key: string): (number?, number?)
	local a, b = string.match(key, "^(%d+)%-(%d+)$")
	if not a or not b then
		return nil, nil
	end
	return tonumber(a), tonumber(b)
end

return Circuits
