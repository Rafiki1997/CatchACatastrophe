--!strict
-- Wild creatures: spawning, roaming, claims, the Legendary forecast and the
-- surge window that makes Overcharged variants possible.
--
-- One loop drives every region. Roaming is not simulated on the server: each
-- creature is given a straight leg (PathFrom/PathTo/PathStart/PathDuration)
-- and the client interpolates it, so eight regions of creatures cost the
-- server one table walk every half second.
--
-- Encounter claims are exclusive. A claimed encounter belongs to one player
-- until they finish, cancel, die, leave, walk away or the 45 second timer
-- expires; no one else can start on it and no one else receives that creature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Weighted = require(ReplicatedStorage.Shared.Util.Weighted)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local EncounterService = {}

export type Encounter = {
	uid: string,
	speciesId: string,
	regionId: string,
	rarity: string,
	element: string,
	model: Model,
	root: BasePart,
	claimedBy: number?, -- userId
	expiresAt: number, -- server time the claim lapses (0 = unclaimed)
	spawnedAt: number,
	legendary: boolean,
	home: Vector3,
	legEndsAt: number,
}

local TICK = 0.5
local encounters: { [string]: Encounter } = {}
local regionState: { [string]: { nextLegendaryAt: number, surgeUntil: number, respawnAt: number, count: number } } = {}
local refs: any = nil
local nextUid = 1

local rng = Random.new()

local function newUid(): string
	local uid = "w" .. tostring(nextUid)
	nextUid += 1
	return uid
end

local function forecastTable()
	local out = {}
	for id, state in regionState do
		out[id] = { nextLegendaryAt = state.nextLegendaryAt, surgeUntil = state.surgeUntil }
	end
	return out
end

function EncounterService.forecast()
	return forecastTable()
end

function EncounterService.isSurge(regionId: string): boolean
	local state = regionState[regionId]
	return state ~= nil and workspace:GetServerTimeNow() < state.surgeUntil
end

function EncounterService.get(uid: string): Encounter?
	return encounters[uid]
end

function EncounterService.countIn(regionId: string): number
	local n = 0
	for _, e in encounters do
		if e.regionId == regionId then
			n += 1
		end
	end
	return n
end

-- ---------------------------------------------------------------- roaming

-- Where a new roaming leg starts. The server never moves its own model (the
-- client interpolates the path attributes), so the model's pivot is the SPAWN
-- point forever; a leg started from it snaps the creature back home every few
-- seconds. The previous leg's end is where the creature actually is.
function EncounterService.legStart(previousTo: any, pivot: Vector3): Vector3
	return if typeof(previousTo) == "Vector3" then previousTo else pivot
end

-- Keep roaming paths in the open field, away from boundary scenery. A circle
-- is convex, so clamping both endpoints also keeps the entire leg inside.
function EncounterService.clampToField(position: Vector3, centre: Vector3, radius: number, half: Vector3?): Vector3
	if half then
		-- A remodelled region is a rectangle, and clamping it to a circle kept
		-- creatures off most of its grass.
		return Vector3.new(
			math.clamp(position.X, centre.X - half.X, centre.X + half.X),
			position.Y,
			math.clamp(position.Z, centre.Z - half.Z, centre.Z + half.Z)
		)
	end
	local flat = Vector3.new(position.X - centre.X, 0, position.Z - centre.Z)
	if flat.Magnitude <= radius then
		return position
	end
	local edge = flat.Unit * radius
	return Vector3.new(centre.X + edge.X, position.Y, centre.Z + edge.Z)
end

-- Push a point out of anything the region asked to be kept clear of.
function EncounterService.clearOf(region: any, point: Vector3): Vector3
	for _, zone in region.keepOut or {} do
		local delta = point - region.centre - zone.at
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if zone.lane then
			if math.abs(delta.X) < zone.lane and math.abs(delta.Z) < zone.lane then
				local push = if delta.X >= 0 then zone.lane else -zone.lane
				point = Vector3.new(region.centre.X + zone.at.X + push, point.Y, point.Z)
			end
		elseif zone.radius > 0 and flat.Magnitude < zone.radius then
			local out = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(1, 0, 0)
			local edge = region.centre + zone.at + out * zone.radius
			point = Vector3.new(edge.X, point.Y, edge.Z)
		end
	end
	return point
end

-- Somewhere on this region's grass: inside the field, off the road and clear of
-- anything standing in it. Falls back to the sampled point rather than looping.
function EncounterService.pickHome(region: any): Vector3
	local half = region.fieldHalf
	for _ = 1, 10 do
		local point
		if half then
			point = region.centre + Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
		else
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(10, region.spawnRadius)
			point = region.centre + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		end
		local ok = true
		for _, zone in region.keepOut or {} do
			local delta = point - region.centre - zone.at
			if zone.lane and math.abs(delta.X) < zone.lane and math.abs(delta.Z) < zone.lane then
				ok = false
			elseif zone.radius > 0 and Vector3.new(delta.X, 0, delta.Z).Magnitude < zone.radius then
				ok = false
			end
		end
		if ok then
			return point
		end
	end
	return region.centre + Vector3.new(region.spawnRadius * 0.6, 0, 0)
end

local function newLeg(encounter: Encounter, now: number)
	local from = EncounterService.legStart(encounter.model:GetAttribute("PathTo"), encounter.model:GetPivot().Position)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(6, Config.Capture.roamRadius)
	local target = encounter.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
	local region = refs.regions[encounter.regionId]
	target = EncounterService.clampToField(target, region.centre, region.spawnRadius, region.fieldHalf)
	target = EncounterService.clearOf(region, target)
	local duration = math.max(1.5, (target - from).Magnitude / Config.Capture.roamSpeed)
	local model = encounter.model
	model:SetAttribute("PathFrom", from)
	model:SetAttribute("PathTo", target)
	model:SetAttribute("PathStart", now)
	model:SetAttribute("PathDuration", duration)
	encounter.legEndsAt = now + duration
end

-- Where the creature is right now, per the leg the client is interpolating.
function EncounterService.positionOf(encounter: Encounter): Vector3
	local model = encounter.model
	local from = model:GetAttribute("PathFrom")
	local to = model:GetAttribute("PathTo")
	local start = model:GetAttribute("PathStart")
	local duration = model:GetAttribute("PathDuration")
	if typeof(from) == "Vector3" and typeof(to) == "Vector3" and typeof(start) == "number" and typeof(duration) == "number" and duration > 0 then
		local t = math.clamp((workspace:GetServerTimeNow() - start) / duration, 0, 1)
		return from:Lerp(to, t)
	end
	return model:GetPivot().Position
end

-- ---------------------------------------------------------------- spawning

local function pickRarity(forceLegendary: boolean): string
	if forceLegendary then
		return "Legendary"
	end
	local weights: { [string]: number } = {}
	for _, r in Config.Rarities.order do
		weights[r] = Config.Rarities.info[r].weight
	end
	return Weighted.pick(weights, rng) or "Common"
end

local function spawnOne(regionId: string, forceSpecies: string?, forceLegendary: boolean?): Encounter?
	local region = refs and refs.regions[regionId]
	local def = Config.Regions.byId[regionId]
	if not region or not def then
		return nil
	end
	local rarity = if forceSpecies then Config.Species.byId[forceSpecies].rarity else pickRarity(forceLegendary == true)
	local species = if forceSpecies then Config.Species.byId[forceSpecies] else Config.Species.find(regionId, rarity)
	if not species then
		return nil
	end

	local home = EncounterService.pickHome(region)

	local ok, model = pcall(CreatureModels.build, species.id, "Normal")
	if not ok or typeof(model) ~= "Instance" then
		warn("[Encounters] model failed for " .. species.id .. ": " .. tostring(model))
		return nil
	end
	local m = model :: Model
	local root = m.PrimaryPart
	if not root then
		m:Destroy()
		return nil
	end

	local now = workspace:GetServerTimeNow()
	local uid = newUid()
	m.Name = species.name
	m:PivotTo(CFrame.new(home))
	m:SetAttribute("EncounterUid", uid)
	m:SetAttribute("SpeciesId", species.id)
	m:SetAttribute("Rarity", species.rarity)
	m:SetAttribute("Element", species.element)
	m:SetAttribute("RegionId", regionId)
	m:SetAttribute("Difficulty", species.difficulty)
	m:SetAttribute("ClaimedBy", 0)
	m:SetAttribute("ExpiresAt", 0)
	m:SetAttribute("Legendary", species.rarity == "Legendary")
	CollectionService:AddTag(m, "Animated")
	CollectionService:AddTag(m, "Wild")
	m.Parent = region.wild

	local encounter: Encounter = {
		uid = uid,
		speciesId = species.id,
		regionId = regionId,
		rarity = species.rarity,
		element = species.element,
		model = m,
		root = root,
		claimedBy = nil,
		expiresAt = 0,
		spawnedAt = now,
		legendary = species.rarity == "Legendary",
		home = home,
		legEndsAt = 0,
	}
	newLeg(encounter, now)
	encounters[uid] = encounter

	if Config.Rarities.info[species.rarity].broadcast then
		Notify.broadcast("A Legendary " .. species.name .. " appeared in " .. def.name .. "!", Config.Rarities.color(species.rarity))
	end
	return encounter
end

local function despawn(uid: string)
	local encounter = encounters[uid]
	if not encounter then
		return
	end
	encounters[uid] = nil
	if encounter.model.Parent then
		encounter.model:Destroy()
	end
end

-- ---------------------------------------------------------------- claims

function EncounterService.claim(profile: Profile, uid: string): (Encounter?, string?)
	local encounter = encounters[uid]
	if not encounter then
		return nil, "That creature is gone."
	end
	if encounter.claimedBy and encounter.claimedBy ~= profile.userId then
		return nil, "Someone is already catching that one."
	end
	if not profile.data.regions[encounter.regionId] then
		local def = Config.Regions.byId[encounter.regionId]
		return nil, "Unlock " .. (if def then def.name else "that region") .. " before you can catch its creatures."
	end
	local character = profile.player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return nil, "Get closer to the creature."
	end
	if (hrp.Position - EncounterService.positionOf(encounter)).Magnitude > Config.Capture.claimRange then
		return nil, "Get closer to the creature."
	end
	local computed = Stats.compute(profile)
	if Stats.storageFull(profile, computed) then
		return nil,
			"Storage full ("
				.. tostring(Stats.storageUsed(profile))
				.. "/"
				.. tostring(computed.storageMax)
				.. "). Sell a creature or buy Creature Storage in the Workshop to make room."
	end

	encounter.claimedBy = profile.userId
	encounter.expiresAt = workspace:GetServerTimeNow() + Config.Capture.encounterLifetime
	encounter.model:SetAttribute("ClaimedBy", profile.userId)
	encounter.model:SetAttribute("ExpiresAt", encounter.expiresAt)
	return encounter, nil
end

function EncounterService.release(uid: string)
	local encounter = encounters[uid]
	if not encounter then
		return
	end
	encounter.claimedBy = nil
	encounter.expiresAt = 0
	if encounter.model.Parent then
		encounter.model:SetAttribute("ClaimedBy", 0)
		encounter.model:SetAttribute("ExpiresAt", 0)
	end
end

-- A successful capture: the creature leaves the world and its region respawns one.
function EncounterService.consume(uid: string)
	local encounter = encounters[uid]
	if not encounter then
		return
	end
	local regionId = encounter.regionId
	Notify.effect("capture", EncounterService.positionOf(encounter))
	despawn(uid)
	local state = regionState[regionId]
	if state then
		state.respawnAt = workspace:GetServerTimeNow() + rng:NextNumber(Config.Regions.respawnDelay.min, Config.Regions.respawnDelay.max)
	end
end

function EncounterService.releaseAllFor(userId: number)
	for uid, encounter in encounters do
		if encounter.claimedBy == userId then
			EncounterService.release(uid)
		end
	end
end

-- Keeps a guaranteed starter creature available while anyone is on tutorial
-- step 1 or 2, so a fresh player always has something to catch.
function EncounterService.ensureTutorialSpawn(profile: Profile)
	if profile.data.quests.tutorialStep > 2 then
		return
	end
	local species = Config.Species.tutorialSpecies
	for _, e in encounters do
		if e.speciesId == species and not e.claimedBy then
			return
		end
	end
	local def = Config.Species.byId[species]
	if def then
		spawnOne(def.region, species)
	end
end

-- ---------------------------------------------------------------- loop

local function tickRegion(regionId: string, now: number)
	local state = regionState[regionId]
	if not state then
		return
	end

	-- Legendary guarantee: when the forecast hits zero, one spawns and the
	-- region surges for a while (perfect captures then yield Overcharged).
	if now >= state.nextLegendaryAt then
		spawnOne(regionId, nil, true)
		state.surgeUntil = now + Config.Regions.surgeDuration
		state.nextLegendaryAt = now + Config.Regions.legendaryInterval
		local def = Config.Regions.byId[regionId]
		if def then
			Notify.broadcast(def.name .. " is surging! Perfect captures there can turn up Overcharged.", def.color)
		end
		Notify.forecast(nil, forecastTable())
	end

	-- population
	local count = EncounterService.countIn(regionId)
	if count < Config.Regions.populationCap and now >= state.respawnAt then
		spawnOne(regionId)
		state.respawnAt = now + rng:NextNumber(Config.Regions.respawnDelay.min, Config.Regions.respawnDelay.max)
	end
end

local function tickEncounters(now: number)
	for uid, encounter in encounters do
		if not encounter.model.Parent then
			encounters[uid] = nil
			continue
		end
		-- expire a claim nobody finished
		if encounter.claimedBy and encounter.expiresAt > 0 and now >= encounter.expiresAt then
			local profile = Profiles.getByUserId(encounter.claimedBy)
			if profile and S.Capture then
				S.Capture.cancel(profile, "The creature got away.")
			else
				EncounterService.release(uid)
			end
		end
		-- next roaming leg
		if now >= encounter.legEndsAt then
			newLeg(encounter, now)
		end
		-- recycle an old, untouched creature so regions stay fresh
		if not encounter.claimedBy and now - encounter.spawnedAt > Config.Capture.wildLifetime then
			despawn(uid)
		end
	end
end

function EncounterService.init(mapRefs: any)
	refs = mapRefs
	local now = workspace:GetServerTimeNow()
	for i, def in Config.Regions.list do
		regionState[def.id] = {
			-- stagger the six regions so their Legendaries do not all land together
			nextLegendaryAt = now + (Config.Regions.legendaryInterval / #Config.Regions.list) * i,
			surgeUntil = 0,
			respawnAt = now,
			count = 0,
		}
		-- seed the region so it is populated the moment the server opens
		for _ = 1, Config.Regions.populationCap do
			spawnOne(def.id)
		end
	end

	task.spawn(function()
		local lastForecast = 0
		while true do
			task.wait(TICK)
			local serverNow = workspace:GetServerTimeNow()
			for _, def in Config.Regions.list do
				local ok, err = pcall(tickRegion, def.id, serverNow)
				if not ok then
					warn("[Encounters] region tick failed: " .. tostring(err))
				end
			end
			local ok, err = pcall(tickEncounters, serverNow)
			if not ok then
				warn("[Encounters] encounter tick failed: " .. tostring(err))
			end
			for _, profile in Profiles.all() do
				EncounterService.ensureTutorialSpawn(profile)
			end
			if serverNow - lastForecast > 5 then
				lastForecast = serverNow
				Notify.forecast(nil, forecastTable())
			end
		end
	end)
end

S.Encounters = EncounterService
return EncounterService
