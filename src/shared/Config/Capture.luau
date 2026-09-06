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
Capture.hitPenalty = 2 -- seconds of progress removed by a break or hit (clamped at 0)
Capture.encounterLifetime = 45 -- seconds a claimed encounter lasts without completion
Capture.wildLifetime = 240 -- seconds an unclaimed wild creature roams before it wanders off (recycled)
Capture.tick = 0.1 -- server capture tick
Capture.captureSecondsCap = 16
Capture.knockback = 38 -- client-side impulse studs/s applied on a hit
Capture.hitStun = 0.6 -- seconds the tether cannot re-engage after a hit
Capture.roamRadius = 22 -- wild creatures wander within this distance of their spawn
Capture.roamSpeed = 4 -- studs/s (client interpolates from path attributes)
Capture.arenaRadius = 20 -- hazards are placed inside this radius around the creature
Capture.claimRange = 22 -- must be this close to claim (slightly above tether range)

-- Perfect capture: no hazard hit and no tether break during the encounter.
-- Overcharged variant: perfect capture while the region's surge is active.

Capture.hazards = {
	Wind = { element = "Wind", name = "Gust", warning = "Gust incoming! Step aside", shape = "line", telegraph = 1.2, active = 1.5, radius = 0, count = 1, spawnRadius = 0, length = 9, width = 1.6, travel = 30, pullStrength = 0, color = Color3.fromRGB(180, 240, 200) },
	Water = { element = "Water", name = "Splash Ring", warning = "Splash ring! Hop over the band", shape = "ring", telegraph = 1.0, active = 1.4, radius = 1.4, count = 1, spawnRadius = 0, length = 0, width = 0, travel = 16, pullStrength = 0, color = Color3.fromRGB(110, 190, 255) },
	Heat = { element = "Heat", name = "Eruption", warning = "Marked ground erupts! Move off the patches", shape = "circles", telegraph = 1.4, active = 0.5, radius = 4, count = 3, spawnRadius = 12, length = 0, width = 0, travel = 0, pullStrength = 0, color = Color3.fromRGB(255, 120, 60) },
	Frost = { element = "Frost", name = "Ice Wave", warning = "Ice wave sliding in! Get out of its path", shape = "line", telegraph = 1.2, active = 1.8, radius = 0, count = 1, spawnRadius = 0, length = 11, width = 2.0, travel = 30, pullStrength = 0, color = Color3.fromRGB(170, 230, 255) },
	Storm = { element = "Storm", name = "Lightning", warning = "Lightning! Leave the marked spots", shape = "circles", telegraph = 1.1, active = 0.35, radius = 3.5, count = 2, spawnRadius = 10, length = 0, width = 0, travel = 0, pullStrength = 0, color = Color3.fromRGB(255, 235, 110) },
	Cosmic = { element = "Cosmic", name = "Gravity Pulse", warning = "Gravity zone! Fight the pull, then clear the ring", shape = "pull", telegraph = 1.6, active = 0.4, radius = 7, count = 1, spawnRadius = 8, length = 0, width = 0, travel = 0, pullStrength = 9, color = Color3.fromRGB(210, 150, 255) },
} :: { [string]: HazardDef }

-- Circles hazards place one patch at the catcher's current position so the
-- player always has to move; the rest are random inside `spawnRadius`.
Capture.targetPlayerFirstPatch = true

return Capture
