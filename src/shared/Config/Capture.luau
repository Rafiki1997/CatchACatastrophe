--!strict
-- Active capture tuning. One tether system, six hazard flavours.
-- All checks run on the server on a fixed tick; the client only renders
-- telegraphs and applies cosmetic knockback to its own character.

export type HazardDef = {
	element: string,
	name: string,
	warning: string, -- HUD text while telegraphed
	shape: string, -- "line" | "ring" | "circles" | "pull"
	telegraph: number, -- seconds the warning is visible before it can hit
	active: number, -- seconds the hazard can hit after the telegraph
	radius: number, -- circles: patch radius; ring: band half-thickness; pull: zone radius
	count: number, -- circles: patches per attack; line/ring/pull: 1
	spawnRadius: number, -- circles: patches land within this distance of the creature
	length: number, -- line: half-length of the moving wall
	width: number, -- line: half-thickness of the wall
	travel: number, -- line: distance travelled during `active`; ring: final radius
	pullStrength: number, -- pull: client-side pull force toward the zone centre (studs/s)
	color: Color3,
}

local Capture = {}

Capture.tetherRange = 18 -- studs, before upgrades
Capture.tetherRangeCap = 30
Capture.outOfRangeGrace = 1.0 -- seconds outside range before the tether breaks
-- Seconds of progress removed by a break or a hit (clamped at 0). Must stay below
-- every rarity's attack interval (attackInterval / hazardSpeed, Legendary 1.33 s) or
-- a player who is hit every time makes no progress at all; the self-test asserts it.
Capture.hitPenalty = 1
Capture.encounterLifetime = 45 -- seconds a claimed encounter lasts without completion
Capture.wildLifetime = 240 -- seconds an unclaimed wild creature roams before it wanders off (recycled)
Capture.tick = 0.1 -- server capture tick
Capture.captureSecondsCap = 16
-- Client-side impulse on a hit. A shove, not an eject: at 38 it threw the player
-- clean out of the 18-stud tether, so every hit also cost a break a second later;
-- at 16 the playtest said the wall "barely moves me"; 28 was a hop, and the user
-- asked for a little more (not much: Gusty Gardens is the lowest tier). 32.
Capture.knockback = 32
Capture.hitStun = 0.6 -- seconds the tether cannot re-engage after a hit
Capture.ringHeight = 0.8 -- feet above this height clear the low splash band
Capture.wallHeight = 3 -- feet above this clear a sweeping wall (Gust, Ice Wave); the client draws the wall this tall
-- ---------------------------------------------------------------- difficulty
-- Approved 2026-09-07. Nothing scaled with the zone before this, and rarity only
-- shortened the attack interval, so a maxed player found Orbit Outpost as easy
-- as Gusty Gardens. Row = region index (1 Gusty .. 6 Orbit).
--   warning     multiplier on the hazard telegraph time (how long you get to react)
--   extraCount  more patches / bolts for circle hazards (Heat, Storm)
--   penalty     seconds of progress lost per hit (row 1 equals Capture.hitPenalty)
--   knockback   client shove per hit (row 1 equals Capture.knockback)
export type Tuning = { warning: number, size: number, extraCount: number, penalty: number, knockback: number, range: number }

Capture.zoneTuning = {
	{ warning = 1.00, extraCount = 0, penalty = 1.00, knockback = 32 },
	{ warning = 0.92, extraCount = 0, penalty = 1.25, knockback = 34 },
	{ warning = 0.84, extraCount = 1, penalty = 1.50, knockback = 36 },
	{ warning = 0.76, extraCount = 1, penalty = 1.75, knockback = 38 },
	{ warning = 0.68, extraCount = 2, penalty = 2.00, knockback = 40 },
	{ warning = 0.60, extraCount = 2, penalty = 2.25, knockback = 40 },
}
-- On top of the zone, per rarity rank above Common: hazards grow 15% (a Legendary
-- gust wall is 45% longer and wider) and warnings shorten a further 10%.
Capture.raritySizePerRank = 0.15
Capture.rarityWarningPerRank = 0.10
-- Per rarity rank (Common .. Legendary), approved 2026-09-07 for Gusty Gardens and
-- inherited by every zone: the capture circle shrinks and the shove grows, so a hit
-- at the edge of a Legendary circle throws you out and you have the grace second to
-- get back. Common is untouched. Upgraded range scales proportionally.
Capture.rarityRangeMult = { 1.0, 0.9, 0.8, 0.7 }
Capture.rarityKnockbackMult = { 1.0, 1.1, 1.2, 1.35 }

function Capture.tuning(regionIndex: number, rarityRank: number): Tuning
	local zone = Capture.zoneTuning[math.clamp(regionIndex, 1, #Capture.zoneTuning)]
	local above = math.max(0, rarityRank - 1)
	local rank = math.clamp(rarityRank, 1, #Capture.rarityRangeMult)
	return {
		warning = zone.warning * (1 - Capture.rarityWarningPerRank * above),
		size = 1 + Capture.raritySizePerRank * above,
		extraCount = zone.extraCount,
		penalty = zone.penalty,
		knockback = zone.knockback * Capture.rarityKnockbackMult[rank],
		range = Capture.rarityRangeMult[rank],
	}
end

Capture.roamRadius = 22 -- wild creatures wander within this distance of their spawn
Capture.roamSpeed = 4 -- studs/s (client interpolates from path attributes)
Capture.arenaRadius = 20 -- hazards are placed inside this radius around the creature
Capture.claimRange = 22 -- must be this close to claim (slightly above tether range)

-- Perfect capture: no hazard hit and no tether break during the encounter.
-- Overcharged variant: perfect capture while the region's surge is active.

Capture.hazards = {
	Wind = { element = "Wind", name = "Gust", warning = "Gust incoming! Jump it or step aside", shape = "line", telegraph = 1.2, active = 1.5, radius = 0, count = 1, spawnRadius = 0, length = 9, width = 1.6, travel = 30, pullStrength = 0, color = Color3.fromRGB(180, 240, 200) },
	Water = { element = "Water", name = "Splash Ring", warning = "Splash ring! Hop over the band", shape = "ring", telegraph = 1.0, active = 1.4, radius = 1.4, count = 1, spawnRadius = 0, length = 0, width = 0, travel = 16, pullStrength = 0, color = Color3.fromRGB(110, 190, 255) },
	Heat = { element = "Heat", name = "Eruption", warning = "Marked ground erupts! Move off the patches", shape = "circles", telegraph = 1.4, active = 0.5, radius = 4, count = 3, spawnRadius = 12, length = 0, width = 0, travel = 0, pullStrength = 0, color = Color3.fromRGB(255, 120, 60) },
	Frost = { element = "Frost", name = "Ice Wave", warning = "Ice wave sliding in! Jump it or get out of its path", shape = "line", telegraph = 1.2, active = 1.8, radius = 0, count = 1, spawnRadius = 0, length = 11, width = 2.0, travel = 30, pullStrength = 0, color = Color3.fromRGB(170, 230, 255) },
	Storm = { element = "Storm", name = "Lightning", warning = "Lightning! Leave the marked spots", shape = "circles", telegraph = 1.1, active = 0.35, radius = 3.5, count = 2, spawnRadius = 10, length = 0, width = 0, travel = 0, pullStrength = 0, color = Color3.fromRGB(255, 235, 110) },
	Cosmic = { element = "Cosmic", name = "Gravity Pulse", warning = "Gravity zone! Fight the pull, then clear the ring", shape = "pull", telegraph = 1.6, active = 0.4, radius = 7, count = 1, spawnRadius = 8, length = 0, width = 0, travel = 0, pullStrength = 9, color = Color3.fromRGB(210, 150, 255) },
} :: { [string]: HazardDef }

-- Circles hazards place one patch at the catcher's current position so the
-- player always has to move; the rest are random inside `spawnRadius`.
Capture.targetPlayerFirstPatch = true

return Capture
