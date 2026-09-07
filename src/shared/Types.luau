--!strict
-- Shared type definitions. The `Snapshot` is exactly what the server sends
-- the owning client on the `State` remote; the client UI renders from it and
-- never derives prices, rates, ownership or capture results on its own.
--
-- All *At / *Until fields are server time from `workspace:GetServerTimeNow()`.

export type CreatureEntry = {
	id: string, -- Config.Species id
	variant: string, -- "Normal" | "Overcharged" | "Prismatic"
	pad: number?, -- work pad index 1..24, nil = in storage
	favorite: boolean,
	anchored: boolean, -- survives relaunch
	cps: number, -- effective Coins/sec INCLUDING variant, relaunch and circuit state (0 when stored / cooling)
	normalCps: number, -- region base x rarity x variant x relaunch (no circuit, no overdrive)
	circuitId: string?, -- recipe id when this creature is in an active pair
	caughtAt: number, -- unix time
	perfect: boolean, -- was caught with a perfect capture
}

export type Overdrive = {
	phase: string, -- "idle" | "active" | "cooldown"
	until_: number, -- server time the current phase ends (0 when idle)
	vented: boolean, -- vent completed during this activation (cooldown skipped)
}

export type CircuitEntry = {
	padA: number,
	padB: number,
	circuitId: string, -- Config.Circuits id
	upgraded: boolean,
	bonus: number, -- fraction each member receives right now (0.25 / 0.40 + efficiency)
	overdrive: Overdrive,
	upgradeCost: number, -- Coins to upgrade this pair (0 when already upgraded)
}

export type AtlasSpecies = {
	firstAt: number, -- unix time of first discovery
	variants: { [string]: boolean }, -- variant ids ever owned
	perfect: number, -- lifetime perfect captures of this species
	caught: number, -- lifetime captures
}

export type Mastery = {
	circuitSeconds: number, -- cumulative online seconds producing inside an active circuit (resets on Prismatic claim)
	perfect: number, -- perfect captures since the last Prismatic claim
	claims: number, -- Prismatic upgrades claimed for this species
}

export type DailyItem = {
	id: string, -- Config.Quests.dailyPool id
	regionId: string?, -- for region-scoped objectives
	desc: string, -- resolved description ("Capture 3 creatures in Cinder Canyon.")
	progress: number,
	target: number,
	claimed: boolean,
	reward: number, -- Coins at claim time (recomputed by the server when claimed)
}

export type RepeatableItem = {
	progress: number,
	target: number, -- resolved (producer is dynamic)
	cycle: number, -- times completed
	reward: number,
}

export type Snapshot = {
	coins: number,
	lifetimeCoins: number,
	bank: number, -- collectible earnings waiting on the collection pad
	bankCap: number,
	bankFull: boolean,
	cps: number, -- city income/sec right now (includes circuits and overdrive)
	normalCps: number, -- production without overdrive (what the bank cap and offline use)
	relaunch: number,
	relaunchMult: number,
	plotIndex: number, -- 1..8, 0 while unassigned
	title: string?, -- highest claimed milestone title

	creatures: { [string]: CreatureEntry }, -- uid -> entry
	storage: { used: number, max: number },
	pads: { total: number, used: number, hardCap: number },
	circuits: { [string]: CircuitEntry }, -- pairKey "3-4" -> entry (active pairs only)
	circuitUpgrades: { [string]: boolean }, -- pairKey -> bought this run
	regions: { [string]: boolean }, -- unlocked region ids
	upgrades: { [string]: number }, -- upgrade id -> level (reset on relaunch)
	derived: {
		tetherRange: number,
		tetherSpeedMult: number,
		walkSpeed: number,
		circuitBonusExtra: number,
		bankCapSeconds: number,
		anchorSlots: number,
	},

	atlas: {
		species: { [string]: AtlasSpecies },
		recipes: { [string]: boolean }, -- circuit ids discovered
		claimed: { [string]: boolean }, -- milestone counts claimed ("4", "8", ...)
		discovered: number,
	},
	mastery: { [string]: Mastery }, -- species id -> progress

	quests: {
		tutorialStep: number, -- 1..7, 8 = finished
		tutorialDone: boolean,
		repeatable: { [string]: RepeatableItem },
		daily: { dayKey: string, resetsAt: number, items: { DailyItem } },
	},

	offline: { amount: number, seconds: number }?, -- pending once-only claim

	settings: {
		music: number, -- 0..1
		sfx: number, -- 0..1
		reducedMotion: boolean,
		reducedFlashing: boolean,
		notifications: boolean,
	},

	build: {
		placeVersion: number,
		environment: string, -- "Studio" | "Live"
		hash: string, -- git short hash from tools/stamp.py, or "unstamped"
		dirty: boolean, -- uncommitted changes were included when stamped
		commitTime: string,
		stampedAt: string,
	},

	stats: {
		captures: number,
		perfect: number,
		relaunches: number,
		connects: number,
		overdrives: number,
		collects: number,
		crisisWins: number,
	},

	capturing: boolean,
	visiting: number?, -- plot index being visited, nil at home
	dataState: string, -- "loading" | "loaded" | "unavailable" | "saving"
	dataSafe: boolean, -- false = load failed, this session never saves
	testAdapter: boolean, -- true when the in-memory Studio adapter is in use
	serverTime: number,
}

export type CaptureState = {
	encounterUid: string,
	speciesId: string,
	progress: number, -- accumulated tether seconds
	required: number, -- seconds needed
	inRange: boolean,
	outOfRangeFor: number, -- seconds outside range (0..grace)
	status: string, -- short HUD text ("Tethering", "Out of range!", "Hit! -2s", "Tether broke")
	perfect: boolean, -- still perfect so far
	expiresAt: number, -- server time
	hits: number,
	surge: boolean, -- region surge active (Overcharged possible)
}

export type HazardEvent = {
	id: string,
	element: string,
	shape: string, -- "line" | "ring" | "circles" | "pull"
	origin: Vector3, -- creature position (ring / pull centre for pull uses `positions[1]`)
	direction: Vector3, -- line: travel direction (unit, horizontal)
	positions: { Vector3 }, -- circles: patch centres; pull: zone centre
	radius: number,
	length: number,
	width: number,
	travel: number,
	telegraphEndsAt: number, -- server time
	activeEndsAt: number, -- server time
	pullStrength: number,
	color: Color3,
	boss: boolean,
}

export type CrisisState = {
	phase: string, -- "warning" | "active" | "success" | "failed"
	endsAt: number,
	bossSpeciesId: string,
	bossName: string,
	pylons: { { progress: number, need: number, done: boolean } },
	participants: number,
	myWork: number,
	qualified: boolean,
}

export type LeaderRow = { name: string, userId: number, value: number }

export type CityInfo = {
	ownerName: string,
	plotIndex: number,
	relaunch: number,
	cps: number,
	creatures: { { id: string, variant: string, pad: number, cps: number } },
	circuits: { { circuitId: string, padA: number, padB: number, upgraded: boolean } },
	recipes: { string },
}

return {}
