--!strict
-- Containment Crisis: a 90 second cooperative event in the hub arena, every
-- eight minutes.
--
-- An enlarged roster Legendary shows up clearly labelled as the event boss and
-- throws its element's hazards at everyone in the arena. Players hold three
-- containment pylons to shut it down. The work each pylon needs scales with
-- how many people turned up, so one player alone can still finish it, and a
-- crowd is not eight times faster.
--
-- The reward is once per player per event and requires real participation:
-- standing in the arena earns nothing, holding a pylon does. It is scaled to
-- the player's own production and clamped, so it is a nice bonus and never a
-- reason to skip building a city.
--
-- This event is optional content. Nothing in the main loop depends on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local CrisisService = {}

local E = Config.Events.crisis
local ARENA_RADIUS = 32

local refs: any = nil
local state: {
	phase: string,
	endsAt: number,
	bossSpeciesId: string,
	bossName: string,
	bossModel: Model?,
	pylons: { { progress: number, need: number, done: boolean } },
	participants: number,
	nextAttackAt: number,
	hazards: { { event: Types.HazardEvent, hitAt: { [number]: boolean } } },
}? =
	nil

local function inArena(hrp: BasePart): boolean
	if not refs then
		return false
	end
	local c = refs.arena.centre
	return (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude <= ARENA_RADIUS
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

local function countParticipants(): number
	local n = 0
	for _, player in Players:GetPlayers() do
		local hrp = rootOf(player)
		if hrp and inArena(hrp) then
			n += 1
		end
	end
	return math.max(1, n)
end

-- The boss is a Legendary from the deepest region anyone online has opened, so
-- it grows with the server rather than always being the starter creature.
local function pickBoss(): string
	local best = 0
	for _, profile in Profiles.all() do
		for regionId in profile.data.regions do
			local def = Config.Regions.byId[regionId]
			if def and def.index > best then
				best = def.index
			end
		end
	end
	if best <= 1 then
		return E.fallbackBoss
	end
	local region = Config.Regions.list[best]
	local species = Config.Species.find(region.id, "Legendary")
	return if species then species.id else E.fallbackBoss
end

-- ---------------------------------------------------------------- snapshot

function CrisisService.state(): Types.CrisisState?
	local s = state
	if not s then
		return nil
	end
	local pylons = {}
	for _, p in s.pylons do
		table.insert(pylons, { progress = p.progress, need = p.need, done = p.done })
	end
	return {
		phase = s.phase,
		endsAt = s.endsAt,
		bossSpeciesId = s.bossSpeciesId,
		bossName = s.bossName,
		pylons = pylons,
		participants = s.participants,
		myWork = 0,
		qualified = false,
	}
end

local function pushState()
	local base = CrisisService.state()
	if not base then
		Notify.crisis(nil, nil)
		return
	end
	for _, profile in Profiles.all() do
		local personal: Types.CrisisState = {
			phase = base.phase,
			endsAt = base.endsAt,
			bossSpeciesId = base.bossSpeciesId,
			bossName = base.bossName,
			pylons = base.pylons,
			participants = base.participants,
			myWork = profile.crisisWork,
			qualified = profile.crisisWork >= E.qualifyWork,
		}
		Notify.crisis(profile.player, personal)
	end
end

local function setScreen(text: string)
	if refs and refs.arena and refs.arena.screen then
		refs.arena.screen.Text = text
	end
end

local function setPylonCharge()
	if not refs or not state then
		return
	end
	for i, p in state.pylons do
		local entry = refs.arena.pylons[i]
		if entry and entry.model then
			entry.model:SetAttribute("Charge", if p.need > 0 then math.clamp(p.progress / p.need, 0, 1) else 0)
		end
	end
end

-- ---------------------------------------------------------------- pylons

-- Called by RemoteRouter while a player holds a pylon prompt.
function CrisisService.onPylonHold(profile: Profile, pylonIndex: any, dt: number)
	local s = state
	if not s or s.phase ~= "active" then
		return
	end
	if typeof(pylonIndex) ~= "number" then
		return
	end
	local pylon = s.pylons[math.floor(pylonIndex)]
	if not pylon or pylon.done then
		return
	end
	local hrp = rootOf(profile.player)
	if not hrp or not inArena(hrp) then
		return
	end
	local work = math.clamp(dt, 0, 0.5) * E.holdRate
	pylon.progress = math.min(pylon.progress + work, pylon.need)
	profile.crisisWork += work
	if pylon.progress >= pylon.need and not pylon.done then
		pylon.done = true
		Notify.broadcast("Containment pylon " .. tostring(math.floor(pylonIndex)) .. " is locked in!", Color3.fromRGB(120, 235, 255))
		Notify.effect("pylon", hrp.Position)
	end
	setPylonCharge()
end

-- ---------------------------------------------------------------- lifecycle

local function clearBoss()
	if state and state.bossModel then
		state.bossModel:Destroy()
		state.bossModel = nil
	end
end

local function finish(success: boolean)
	local s = state
	if not s then
		return
	end
	s.phase = if success then "success" else "failed"
	s.endsAt = workspace:GetServerTimeNow() + 6
	clearBoss()

	if success then
		local paid = 0
		for _, profile in Profiles.all() do
			if profile.crisisWork >= E.qualifyWork and not profile.crisisRewarded then
				profile.crisisRewarded = true
				local reward = Stats.scaledReward(profile, E.rewardSeconds, E.rewardMin, E.rewardMax)
				if S.Economy then
					S.Economy.addCoins(profile, reward, "crisis")
				end
				profile.data.stats.crisisWins += 1
				profile.dirty = true
				paid += 1
				Notify.player(profile.player, "success", "Crisis contained! +" .. Format.abbreviate(reward) .. " Coins for your work on the pylons.", 8)
			elseif profile.crisisWork > 0 then
				Notify.player(profile.player, "info", "Crisis contained, but you did not hold a pylon long enough to qualify.", 6)
			end
		end
		Notify.broadcast("Containment Crisis contained! " .. tostring(paid) .. " " .. (if paid == 1 then "responder" else "responders") .. " paid.", Color3.fromRGB(120, 235, 255))
		setScreen("CONTAINED\nGood work.")
	else
		Notify.broadcast("The Containment Crisis broke loose. Better luck in eight minutes.", Color3.fromRGB(255, 140, 120))
		setScreen("BREACH\nIt got away.")
	end
	pushState()
end

local function cleanup()
	clearBoss()
	state = nil
	for _, profile in Profiles.all() do
		profile.crisisWork = 0
		profile.crisisRewarded = false
	end
	if refs then
		for _, entry in refs.arena.pylons do
			if entry.model then
				entry.model:SetAttribute("Charge", 0)
			end
		end
	end
	setScreen("Containment Crisis\nNext one soon.")
	Notify.crisis(nil, nil)
end

local function start()
	local now = workspace:GetServerTimeNow()
	local bossId = pickBoss()
	local def = Config.Species.byId[bossId]
	local participants = countParticipants()
	local need = E.pylonBaseWork + E.pylonWorkPerExtraPlayer * (participants - 1)

	local pylons = {}
	for _ = 1, E.pylons do
		table.insert(pylons, { progress = 0, need = need, done = false })
	end

	state = {
		phase = "warning",
		endsAt = now + E.warning,
		bossSpeciesId = bossId,
		bossName = if def then def.name else "Catastrophe",
		bossModel = nil,
		pylons = pylons,
		participants = participants,
		nextAttackAt = 0,
		hazards = {},
	}
	for _, profile in Profiles.all() do
		profile.crisisWork = 0
		profile.crisisRewarded = false
	end

	Notify.broadcast("Containment Crisis in " .. tostring(E.warning) .. " seconds! Head to the arena.", Color3.fromRGB(255, 200, 80))
	setScreen("CRISIS INCOMING\n" .. (if def then def.name else "?") .. "\nGet to the arena")
	pushState()
end

local function activate()
	local s = state
	if not s or not refs then
		return
	end
	local now = workspace:GetServerTimeNow()
	s.phase = "active"
	s.endsAt = now + E.duration
	s.participants = countParticipants()
	local need = E.pylonBaseWork + E.pylonWorkPerExtraPlayer * (s.participants - 1)
	for _, p in s.pylons do
		p.need = need
	end
	s.nextAttackAt = now + E.bossAttackInterval

	local ok, model = pcall(CreatureModels.build, s.bossSpeciesId, "Normal", false, E.bossScale)
	if ok and typeof(model) == "Instance" then
		local m = model :: Model
		m.Name = "CrisisBoss"
		local cf = CFrame.new(refs.arena.bossSpot.Position)
		m:PivotTo(cf)
		m:SetAttribute("BasePivot", cf)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "BossLabel"
		billboard.Size = UDim2.fromScale(18, 3)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
		billboard.MaxDistance = 400
		billboard.Parent = m
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 120, 100)
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		label.Text = "CRISIS BOSS: " .. s.bossName
		label.Parent = billboard
		game:GetService("CollectionService"):AddTag(m, "Animated")
		m.Parent = refs.arena.model
		s.bossModel = m
	end

	Notify.broadcast("Containment Crisis! Hold the three pylons.", Color3.fromRGB(255, 140, 120))
	setScreen("CRISIS ACTIVE\n" .. s.bossName .. "\nHold the pylons")
	pushState()
end

local function tickActive(now: number)
	local s = state
	if not s or not refs then
		return
	end

	-- boss hazards against everyone in the arena
	if now >= s.nextAttackAt and S.Capture then
		local def = nil
		local species = Config.Species.byId[s.bossSpeciesId]
		if species then
			def = Config.Capture.hazards[species.element]
		end
		if def then
			local targets = {}
			for _, player in Players:GetPlayers() do
				local hrp = rootOf(player)
				if hrp and inArena(hrp) then
					table.insert(targets, { player = player, pos = hrp.Position })
				end
			end
			local aim = if #targets > 0 then targets[math.random(1, #targets)].pos else refs.arena.centre + Vector3.new(10, 0, 0)
			local ev = S.Capture.buildHazard(def, refs.arena.centre, aim, now, E.bossHazardSpeed, true)
			table.insert(s.hazards, { event = ev, hitAt = {} })
			local list = {}
			for _, t in targets do
				table.insert(list, t.player)
			end
			Notify.hazard(list, ev)
		end
		s.nextAttackAt = now + E.bossAttackInterval
	end

	for i = #s.hazards, 1, -1 do
		local entry = s.hazards[i]
		if now > entry.event.activeEndsAt + 0.5 then
			table.remove(s.hazards, i)
		else
			for _, player in Players:GetPlayers() do
				local hrp = rootOf(player)
				if hrp and inArena(hrp) and not entry.hitAt[player.UserId] and S.Capture.hazardHits(entry.event, hrp.Position, now, S.Capture.feetY(hrp)) then
					entry.hitAt[player.UserId] = true
					local away = Vector3.new(hrp.Position.X - entry.event.origin.X, 0, hrp.Position.Z - entry.event.origin.Z)
					local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
					Notify.knockback(player, dir, Config.Capture.knockback)
					Notify.effectFor(player, "hit", hrp.Position)
				end
			end
		end
	end

	-- win check
	local done = 0
	for _, p in s.pylons do
		if p.done then
			done += 1
		end
	end
	if done >= #s.pylons then
		finish(true)
	elseif now >= s.endsAt then
		finish(false)
	end
end

function CrisisService.init(mapRefs: any)
	refs = mapRefs
	setScreen("Containment Crisis\nEvery " .. tostring(math.floor(E.interval / 60)) .. " minutes in this arena.")

	task.spawn(function()
		-- do not open the server with an immediate crisis
		local nextStart = workspace:GetServerTimeNow() + E.interval
		while true do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			local s = state
			if not s then
				if now >= nextStart then
					nextStart = now + E.interval
					local ok, err = pcall(start)
					if not ok then
						warn("[Crisis] start failed: " .. tostring(err))
						state = nil
					end
				end
			elseif s.phase == "warning" then
				if now >= s.endsAt then
					local ok, err = pcall(activate)
					if not ok then
						warn("[Crisis] activate failed: " .. tostring(err))
						cleanup()
					end
				end
			elseif s.phase == "active" then
				local ok, err = pcall(tickActive, now)
				if not ok then
					warn("[Crisis] tick failed: " .. tostring(err))
					finish(false)
				end
			else
				if now >= s.endsAt then
					cleanup()
				end
			end
		end
	end)

	-- push the live state at a readable rate
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state then
				pcall(pushState)
			end
		end
	end)
end

S.Crisis = CrisisService
return CrisisService
