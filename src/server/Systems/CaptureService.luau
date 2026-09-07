--!strict
-- The containment tether: the only way to get a creature.
--
-- The server owns all of it. The client sends "start" and "cancel" and renders
-- what it is told; it never reports progress, a dodge, or a completed capture.
-- Hazard geometry is chosen here, sent to the client once as a telegraph, and
-- resolved here against the catcher's replicated root position, so what the
-- player sees and what hits them come from the same numbers.
--
-- Progress rules (Config.Capture):
--   * required = rarity capture seconds (cap 16) / tether speed upgrade
--   * leaving range for more than the grace period, or taking a hit, removes
--     `hitPenalty` seconds and clears the perfect flag; progress floors at 0
--   * a claim expires 45 seconds after it starts
--   * death, disconnect, cancel or walking far away all release the claim
--
-- `buildHazard` and `hazardHits` are exported because CrisisService throws the
-- same hazards at everyone in the arena.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile
type HazardEvent = Types.HazardEvent

local CaptureService = {}

local C = Config.Capture
local rng = Random.new()
local hazardSeq = 0

local function horizontal(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			return nil
		end
		return hrp
	end
	return nil
end

-- ---------------------------------------------------------------- hazards

-- Root-to-feet distance differs between R6 and R15 and with avatar scale.
function CaptureService.feetY(hrp: BasePart): number
	local humanoid = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
	local offset = hrp.Size.Y / 2
	if humanoid then
		offset += humanoid.HipHeight
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			local leg = hrp.Parent:FindFirstChild("Left Leg")
			offset += if leg and leg:IsA("BasePart") then leg.Size.Y else 2
		end
	end
	return hrp.Position.Y - offset
end

-- Build one hazard. `origin` is the creature, `targetPos` the catcher.
function CaptureService.buildHazard(def: any, origin: Vector3, targetPos: Vector3, now: number, speed: number, boss: boolean?): HazardEvent
	hazardSeq += 1
	local telegraph = def.telegraph / speed
	local active = def.active / speed
	local telegraphEndsAt = now + telegraph
	local activeEndsAt = telegraphEndsAt + active

	local toTarget = horizontal(targetPos - origin)
	local direction = if toTarget.Magnitude > 0.1 then toTarget.Unit else Vector3.new(0, 0, 1)
	local positions: { Vector3 } = {}
	local start = origin

	if def.shape == "line" then
		-- a wall that sweeps across the arena; it starts behind the creature so
		-- it crosses the whole fight, and is aimed near (not exactly at) the player
		local jitter = math.rad(rng:NextNumber(-20, 20))
		direction = (CFrame.Angles(0, jitter, 0) * direction).Unit
		start = origin - direction * (def.travel * 0.5)
		start = Vector3.new(start.X, origin.Y, start.Z)
	elseif def.shape == "circles" then
		-- the first patch lands where the player is standing, so standing still
		-- is never safe; the rest scatter near the creature
		if C.targetPlayerFirstPatch then
			table.insert(positions, Vector3.new(targetPos.X, origin.Y, targetPos.Z))
		end
		while #positions < def.count do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(2, def.spawnRadius)
			table.insert(positions, origin + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
		end
	elseif def.shape == "pull" then
		-- the gravity well sits between the creature and the player
		local zone = origin + direction * def.spawnRadius
		table.insert(positions, Vector3.new(zone.X, origin.Y, zone.Z))
	end

	local scale = if boss then 1.6 else 1
	return {
		id = "h" .. tostring(hazardSeq),
		element = def.element,
		shape = def.shape,
		origin = start,
		direction = direction,
		positions = positions,
		radius = def.radius * scale,
		length = def.length * scale,
		width = def.width,
		travel = def.travel,
		telegraphEndsAt = telegraphEndsAt,
		activeEndsAt = activeEndsAt,
		pullStrength = def.pullStrength,
		color = def.color,
		boss = boss == true,
	}
end

-- Is `pos` inside the hazard at `now`? Only true during the active window.
function CaptureService.hazardHits(ev: HazardEvent, pos: Vector3, now: number, feetY: number?): boolean
	if now < ev.telegraphEndsAt or now > ev.activeEndsAt then
		return false
	end
	local span = math.max(0.05, ev.activeEndsAt - ev.telegraphEndsAt)
	local u = math.clamp((now - ev.telegraphEndsAt) / span, 0, 1)
	local p = horizontal(pos)

	if ev.shape == "line" then
		local centre = horizontal(ev.origin + ev.direction * (ev.travel * u))
		local rel = p - centre
		local along = rel:Dot(ev.direction)
		local right = Vector3.new(-ev.direction.Z, 0, ev.direction.X)
		local across = rel:Dot(right)
		return math.abs(along) <= ev.width + 1.5 and math.abs(across) <= ev.length
	elseif ev.shape == "ring" then
		if feetY and feetY > ev.origin.Y + C.ringHeight then
			return false
		end
		local r = ev.travel * u
		local d = (p - horizontal(ev.origin)).Magnitude
		return math.abs(d - r) <= ev.radius + 1
	elseif ev.shape == "circles" then
		for _, c in ev.positions do
			if (p - horizontal(c)).Magnitude <= ev.radius + 1 then
				return true
			end
		end
		return false
	elseif ev.shape == "pull" then
		local c = ev.positions[1]
		if not c then
			return false
		end
		return (p - horizontal(c)).Magnitude <= ev.radius
	end
	return false
end

-- ---------------------------------------------------------------- state

local function sendState(profile: Profile, status: string)
	local cap = profile.capture
	if not cap then
		Notify.captureState(profile.player, nil)
		return
	end
	local state: Types.CaptureState = {
		encounterUid = cap.uid,
		speciesId = cap.encounter.speciesId,
		progress = cap.progress,
		required = cap.required,
		inRange = cap.inRange,
		outOfRangeFor = cap.outOfRange,
		status = status,
		perfect = cap.perfect,
		expiresAt = cap.encounter.expiresAt,
		hits = cap.hits,
		surge = cap.surge,
	}
	Notify.captureState(profile.player, state)
end

function CaptureService.isCapturing(profile: Profile): boolean
	return profile.capture ~= nil
end

function CaptureService.start(profile: Profile, encounterUid: any): (boolean, string?)
	if typeof(encounterUid) ~= "string" then
		return false, "Pick a creature first."
	end
	if profile.capture then
		return false, "You are already tethering something."
	end
	if not S.Encounters then
		return false, "The wild is still loading."
	end
	local encounter, msg = S.Encounters.claim(profile, encounterUid)
	if not encounter then
		return false, msg
	end

	local computed = Stats.compute(profile)
	local rarity = Config.Rarities.info[encounter.rarity]
	local required = math.min(rarity.captureSeconds, C.captureSecondsCap) / computed.tetherSpeedMult
	local now = workspace:GetServerTimeNow()

	profile.capture = {
		uid = encounterUid,
		encounter = encounter,
		progress = 0,
		required = required,
		inRange = true,
		outOfRange = 0,
		perfect = true,
		hits = 0,
		startedAt = now,
		nextAttackAt = now + rarity.attackInterval / rarity.hazardSpeed,
		hazards = {} :: { HazardEvent },
		stunUntil = 0,
		surge = S.Encounters.isSurge(encounter.regionId),
	}
	profile.dirty = true
	sendState(profile, "Tethering")
	Notify.effectFor(profile.player, "capture", S.Encounters.positionOf(encounter))
	return true, nil
end

function CaptureService.cancel(profile: Profile, reason: string?)
	local cap = profile.capture
	if not cap then
		return
	end
	profile.capture = nil
	if S.Encounters then
		S.Encounters.release(cap.uid)
	end
	Notify.captureState(profile.player, nil)
	if reason then
		Notify.player(profile.player, "warn", reason, 4)
	end
	profile.dirty = true
end

function CaptureService.onCharacterRemoved(profile: Profile)
	CaptureService.cancel(profile, "Your tether broke when you went down.")
end

-- ---------------------------------------------------------------- completion

local function complete(profile: Profile, cap: any)
	local encounter = cap.encounter
	local speciesId = encounter.speciesId
	local perfect = cap.perfect
	local regionId = encounter.regionId
	local rarity = encounter.rarity

	profile.capture = nil

	local variant = "Normal"
	if S.Variants then
		local ok, result = pcall(S.Variants.rollVariant, profile, regionId, perfect)
		if ok and typeof(result) == "string" then
			variant = result
		end
	end

	local uid, failMsg
	if S.City then
		uid, failMsg = S.City.grantCreature(profile, speciesId, variant, perfect)
	end
	if not uid then
		-- storage filled during the fight; the creature stays wild
		if S.Encounters then
			S.Encounters.release(cap.uid)
		end
		Notify.captureState(profile.player, nil)
		Notify.player(profile.player, "error", failMsg or "Your storage is full.", 7)
		return
	end

	if S.Encounters then
		S.Encounters.consume(cap.uid)
	end

	local d = profile.data
	d.stats.captures += 1
	if perfect then
		d.stats.perfect += 1
	end

	if S.Atlas then
		pcall(S.Atlas.recordCapture, profile, speciesId, variant, perfect)
	end
	if S.Quests then
		pcall(S.Quests.bump, profile, "captures", 1, regionId)
		pcall(S.Quests.bump, profile, "region_captures", 1, regionId)
		if perfect then
			pcall(S.Quests.bump, profile, "perfect", 1, regionId)
		end
		if Config.Rarities.rank(rarity) >= 3 then
			pcall(S.Quests.bump, profile, "rare_captures", 1, regionId)
		end
		pcall(S.Quests.tutorialEvent, profile, "capture")
	end

	Notify.captureState(profile.player, nil)
	Notify.captureResult(profile.player, { speciesId = speciesId, variant = variant, perfect = perfect, uid = uid })
	profile.dirty = true
end

-- ---------------------------------------------------------------- tick

local function tickCapture(profile: Profile, dt: number, now: number)
	local cap = profile.capture
	if not cap then
		return
	end
	local encounter = cap.encounter

	-- the creature vanished (server restart of the region, or someone consumed it)
	if not encounter.model.Parent or (S.Encounters and not S.Encounters.get(cap.uid)) then
		CaptureService.cancel(profile, "The creature got away.")
		return
	end
	-- the claim lapsed
	if encounter.expiresAt > 0 and now >= encounter.expiresAt then
		CaptureService.cancel(profile, "The creature got away.")
		return
	end

	local hrp = rootOf(profile.player)
	if not hrp then
		CaptureService.cancel(profile, "Your tether broke when you went down.")
		return
	end

	local creaturePos = S.Encounters and S.Encounters.positionOf(encounter) or encounter.model:GetPivot().Position
	local distance = (horizontal(hrp.Position) - horizontal(creaturePos)).Magnitude

	-- wandering right out of the area ends it
	if distance > 90 then
		CaptureService.cancel(profile, "You left the creature behind.")
		return
	end

	local computed = Stats.compute(profile)
	local status = "Tethering"
	local wasInRange = cap.inRange
	cap.inRange = distance <= computed.tetherRange

	if cap.inRange then
		cap.outOfRange = 0
		if now >= cap.stunUntil then
			cap.progress = math.min(cap.progress + dt, cap.required)
		else
			status = "Shaken off! Hold on"
		end
		if not wasInRange then
			status = "Back in range"
		end
	else
		cap.outOfRange += dt
		if cap.outOfRange >= C.outOfRangeGrace then
			-- the tether snaps: lose progress, lose the perfect run, keep the claim
			cap.progress = math.max(0, cap.progress - C.hitPenalty)
			cap.perfect = false
			cap.outOfRange = 0
			status = "Tether broke! -" .. tostring(C.hitPenalty) .. "s"
			Notify.effectFor(profile.player, "hit", hrp.Position)
		else
			status = "Out of range! " .. ("%.1f"):format(C.outOfRangeGrace - cap.outOfRange) .. "s"
		end
	end

	-- ------------------------------------------------ hazards
	local rarity = Config.Rarities.info[encounter.rarity]
	if now >= cap.nextAttackAt then
		local def = C.hazards[encounter.element]
		if def then
			local ev = CaptureService.buildHazard(def, creaturePos, hrp.Position, now, rarity.hazardSpeed, false)
			table.insert(cap.hazards, { event = ev, resolved = false })
			Notify.hazard({ profile.player }, ev)
		end
		cap.nextAttackAt = now + rarity.attackInterval / rarity.hazardSpeed
	end

	for i = #cap.hazards, 1, -1 do
		local entry = cap.hazards[i]
		local ev = entry.event
		if now > ev.activeEndsAt + 0.5 then
			table.remove(cap.hazards, i)
		elseif not entry.resolved and CaptureService.hazardHits(ev, hrp.Position, now, CaptureService.feetY(hrp)) then
			entry.resolved = true
			cap.hits += 1
			cap.perfect = false
			cap.progress = math.max(0, cap.progress - C.hitPenalty)
			cap.stunUntil = now + C.hitStun
			status = C.hazards[encounter.element].name .. " hit you! -" .. tostring(C.hitPenalty) .. "s"
			-- knockback is cosmetic and applied by the owning client
			local away = horizontal(hrp.Position - ev.origin)
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
			Notify.knockback(profile.player, dir, C.knockback)
			Notify.effectFor(profile.player, "hit", hrp.Position)
		end
	end

	if cap.progress >= cap.required then
		complete(profile, cap)
		return
	end

	sendState(profile, status)
end

function CaptureService.init()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < C.tick then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = workspace:GetServerTimeNow()
		for _, profile in Profiles.all() do
			if profile.capture then
				local ok, err = pcall(tickCapture, profile, step, now)
				if not ok then
					warn("[Capture] tick failed for " .. profile.player.Name .. ": " .. tostring(err))
					CaptureService.cancel(profile, "Something went wrong with that tether.")
				end
			end
		end
	end)
end

S.Capture = CaptureService
return CaptureService
