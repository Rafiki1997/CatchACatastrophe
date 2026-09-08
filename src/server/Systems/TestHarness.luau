--!strict
-- Studio-only self tests. They run three seconds after the server starts and
-- print one [SelfTest] line per check.
--
-- These cover the things that are cheap to get wrong and expensive to notice:
-- the income formula applying each factor exactly once, circuit validation,
-- the overdrive state machine, save round-tripping, and the guards that stop a
-- reward being claimed twice. Live behaviour (hazards actually hitting, two
-- clients, real DataStores) is not covered here and has to be played.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Weighted = require(ReplicatedStorage.Shared.Util.Weighted)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)
local MachineryBuilders = require(ReplicatedStorage.Shared.Models.MachineryBuilders)
local Kit = require(ReplicatedStorage.Shared.Models.ModelKit)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)

local Harness = {}

local passed = 0
local failed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		failed += 1
		local line = name .. (if detail then " (" .. detail .. ")" else "")
		table.insert(failures, line)
		warn("[SelfTest] FAIL " .. line)
	end
end

local function approx(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 0.001)
end

-- A profile with no real Player behind it. Enough for every pure calculation.
local function mockProfile(coins: number): Profiles.Profile
	local fakePlayer = {
		Name = "TestSubject",
		DisplayName = "TestSubject",
		UserId = -1,
		Parent = nil,
		Character = nil,
	}
	local data = Profiles.defaultData()
	data.coins = coins
	local profile: Profiles.Profile = {
		player = fakePlayer :: any,
		userId = -1,
		data = data,
		loaded = true,
		dataSafe = false, -- never let a test profile write anything
		dataState = "loaded",
		testAdapter = true,
		dirty = false,
		plotIndex = 0,
		plot = nil,
		capture = nil,
		visiting = nil,
		overdrives = {},
		padModels = {},
		machineModels = {},
		crisisWork = 0,
		crisisRewarded = false,
		joinedAt = os.time(),
		leaving = false,
		saving = false,
		busy = false,
		passes = {},
		eggAllowed = true,
		lastCollectAt = 0,
	}
	return profile
end

local function give(profile: Profiles.Profile, speciesId: string, variant: string, pad: number?): string
	local uid = Profiles.newUid(profile)
	profile.data.creatures[uid] = {
		id = speciesId,
		variant = variant,
		pad = pad,
		favorite = false,
		anchored = false,
		caughtAt = os.time(),
		perfect = false,
	}
	return uid
end

-- ---------------------------------------------------------------- tests

local function testConfig()
	check("24 species", #Config.Species.list == 24, tostring(#Config.Species.list))
	check("species count constant matches", Config.Species.count == 24)

	local weightSum = 0
	for _, rarity in Config.Rarities.order do
		weightSum += Config.Rarities.info[rarity].weight
	end
	check("rarity weights sum to 100", approx(weightSum, 100), tostring(weightSum))

	-- one species per region per rarity, and nothing left over
	for _, region in Config.Regions.list do
		local list = Config.Species.byRegion[region.id]
		check("region " .. region.id .. " has 4 species", list ~= nil and #list == 4)
		-- wild tiers only: Mythic and above hatch from eggs and have no region
		for _, rarity in Config.Rarities.wildOrder do
			check(region.id .. " has a " .. rarity, Config.Species.find(region.id, rarity) ~= nil)
		end
	end

	-- the regional base rates the spec fixes
	local expected = { 4, 8, 16, 32, 64, 128 }
	for i, region in Config.Regions.list do
		check("region " .. tostring(i) .. " base income", region.baseIncome == expected[i], tostring(region.baseIncome))
	end
	local costs = { 0, 2500, 15000, 75000, 300000, 1000000 }
	for i, region in Config.Regions.list do
		check("region " .. tostring(i) .. " unlock cost", region.unlockCost == costs[i], tostring(region.unlockCost))
	end

	-- six recipes, each pair distinct and order-independent
	check("6 circuits", #Config.Circuits.list == 6)
	for _, circuit in Config.Circuits.list do
		local a, b = circuit.elements[1], circuit.elements[2]
		check("recipe " .. circuit.id .. " is order independent", Config.Circuits.recipe(a, b) == Config.Circuits.recipe(b, a))
	end

	-- relaunch maths
	check("relaunch cost R0", Config.Relaunch.cost(0) == 100000, tostring(Config.Relaunch.cost(0)))
	check("relaunch cost R1", Config.Relaunch.cost(1) == 300000, tostring(Config.Relaunch.cost(1)))
	check("relaunch cost R2", Config.Relaunch.cost(2) == 900000, tostring(Config.Relaunch.cost(2)))
	check("species required R0", Config.Relaunch.speciesRequired(0) == 6)
	check("species required R9", Config.Relaunch.speciesRequired(9) == 24)
	check("species required caps at 24", Config.Relaunch.speciesRequired(10) == 24)
	check("anchor slots 0/3/6", Config.Relaunch.anchorSlots(0) == 1 and Config.Relaunch.anchorSlots(3) == 2 and Config.Relaunch.anchorSlots(6) == 3)
	check("pads grow with relaunch", Config.Relaunch.startingPads(0) == 6 and Config.Relaunch.startingPads(10) == 16)

	-- adjacency
	check("pads 1 and 2 adjacent", Config.Circuits.areAdjacent(1, 2))
	check("pads 1 and 7 adjacent", Config.Circuits.areAdjacent(1, 7))
	check("pads 1 and 8 NOT adjacent (diagonal)", not Config.Circuits.areAdjacent(1, 8))
	check("pads 6 and 7 NOT adjacent (row wrap)", not Config.Circuits.areAdjacent(6, 7))
	check("pair key is order independent", Config.Circuits.pairKey(4, 3) == Config.Circuits.pairKey(3, 4))
end

local function testHazards()
	local Capture = require(script.Parent.CaptureService)
	for _, element in { "Water", "Heat", "Frost", "Storm", "Cosmic" } do
		local def = Config.Capture.hazards[element]
		for _, speed in { 1, 1.5 } do
			local ev = Capture.buildHazard(def, Vector3.zero, Vector3.new(8, 3, 0), 100, speed)
			local mid = (ev.telegraphEndsAt + ev.activeEndsAt) / 2
			local inside = ev.positions[1] or Vector3.zero
			if ev.shape == "ring" then
				inside = Vector3.new(8, 3, 0)
			elseif ev.shape == "line" then
				inside = ev.origin + ev.direction * ev.travel / 2
			end
			local key = element .. " speed " .. tostring(speed)
			check(key .. " warning harmless", not Capture.hazardHits(ev, inside, ev.telegraphEndsAt - 0.001, 0))
			check(key .. " active hits", Capture.hazardHits(ev, inside, mid, 0))
			check(key .. " expired harmless", not Capture.hazardHits(ev, inside, ev.activeEndsAt + 0.001, 0))
			check(key .. " outside safe", not Capture.hazardHits(ev, Vector3.new(100, 3, 100), mid, 0))
			check(key .. " warning scales", approx(ev.telegraphEndsAt - 100, def.telegraph / speed))
			check(key .. " active scales", approx(ev.activeEndsAt - ev.telegraphEndsAt, def.active / speed))
			if ev.shape == "circles" then
				check(key .. " patch count", #ev.positions == def.count)
				check(key .. " targets catcher", ev.positions[1] == Vector3.new(8, 0, 0))
			elseif ev.shape == "ring" then
				check(key .. " jump clears band", not Capture.hazardHits(ev, inside, mid, Config.Capture.ringHeight + 0.1))
				check(key .. " low feet hit", Capture.hazardHits(ev, inside, mid, Config.Capture.ringHeight - 0.1))
				check(key .. " centre safe behind band", not Capture.hazardHits(ev, Vector3.zero, mid, 0))
			elseif ev.shape == "line" then
				local right = Vector3.new(-ev.direction.Z, 0, ev.direction.X)
				check(key .. " sidestep safe", not Capture.hazardHits(ev, inside + right * (ev.length + 1), mid, 0))
				check(key .. " jump clears wall", not Capture.hazardHits(ev, inside, mid, Config.Capture.wallHeight + 0.1))
				check(key .. " low feet hit by wall", Capture.hazardHits(ev, inside, mid, Config.Capture.wallHeight - 0.1))
			end
		end
	end
end

local function testFormat()
	check("abbreviate 999", Format.abbreviate(999) == "999", Format.abbreviate(999))
	check("abbreviate 1500", Format.abbreviate(1500) == "1.5K", Format.abbreviate(1500))
	check("clock 65", Format.clock(65) == "1:05", Format.clock(65))
	check("percent", Format.percent(0.25) == "25%", Format.percent(0.25))
end

local function testModels()
	local built = 0
	for _, def in Config.Species.list do
		local ok, model = pcall(CreatureModels.build, def.id, "Normal")
		if ok and typeof(model) == "Instance" then
			built += 1
			-- `height` means how tall the creature reads standing on the ground,
			-- which is the TOP of its model, not its vertical extent: a hovering
			-- manta is thin but sits high, and comparing extents wrongly failed
			-- it. The client offsets name labels by this, so a wrong number is
			-- visible in game.
			local centre, size = Kit.bounds(model :: Model)
			local top = centre.Y + size.Y / 2
			check(def.id .. " top near " .. tostring(def.height), top > def.height * 0.7 and top < def.height * 1.3, ("%.2f"):format(top))
			check(def.id .. " has a builder", CreatureModels.hasBuilder(def.id))
			;(model :: Model):Destroy()
		else
			check(def.id .. " builds", false, tostring(model))
		end
	end
	check("all 24 creature models build", built == 24, tostring(built) .. "/24")

	-- Effects accumulate across builder, variant, and rarity passes. Check the
	-- finished combinations, including silhouettes used by the collection UI.
	for _, def in Config.Species.list do
		for _, appearance in { "Normal", "Overcharged", "Prismatic", "Silhouette" } do
			local silhouette = appearance == "Silhouette"
			local ok, model = pcall(CreatureModels.build, def.id, if silhouette then "Normal" else appearance, silhouette)
			if ok and typeof(model) == "Instance" then
				local parts, lights, emitters = 0, 0, 0
				local safe = true
				for _, inst in model:GetDescendants() do
					if inst:IsA("BasePart") then
						parts += 1
						safe = safe and inst.Anchored and not inst.CanCollide
					elseif inst:IsA("Light") then
						lights += 1
					elseif inst:IsA("ParticleEmitter") then
						emitters += 1
					end
				end
				check(def.id .. " " .. appearance .. " render budget", parts >= 14 and parts <= 45 and lights <= 2 and emitters <= 3 and safe,
					("%d parts, %d lights, %d emitters"):format(parts, lights, emitters))
				if silhouette then
					check(def.id .. " silhouette has no effects", lights == 0 and emitters == 0)
				end
				model:Destroy()
			else
				check(def.id .. " " .. appearance .. " builds", false, tostring(model))
			end
		end
	end

	for _, job in MachineryBuilders.stationJobs() do
		local ok, model = pcall(MachineryBuilders.buildWorkStation, job, Color3.fromRGB(255, 255, 255))
		check("station " .. job .. " builds", ok and typeof(model) == "Instance", tostring(model))
		if ok and typeof(model) == "Instance" then
			(model :: Model):Destroy()
		end
	end
	for _, circuit in Config.Circuits.list do
		local ok, model = pcall(MachineryBuilders.buildMachine, circuit.id)
		check("machine " .. circuit.id .. " builds", ok and typeof(model) == "Instance", tostring(model))
		if ok and typeof(model) == "Instance" then
			(model :: Model):Destroy()
		end
	end
	for _, milestone in Config.Milestones.list do
		local ok, model = pcall(MachineryBuilders.buildDecoration, milestone.decoration)
		check("decoration " .. milestone.decoration .. " builds", ok and typeof(model) == "Instance", tostring(model))
		if ok and typeof(model) == "Instance" then
			(model :: Model):Destroy()
		end
	end
	local okPylon, pylon = pcall(MachineryBuilders.buildPylon)
	check("pylon builds", okPylon and typeof(pylon) == "Instance", tostring(pylon))
	if okPylon and typeof(pylon) == "Instance" then
		(pylon :: Model):Destroy()
	end
end

-- Capture balance rules that must hold whatever the numbers are tuned to.
local function testCaptureBalance()
	-- zone 1 keeps the new-player guarantee: hit every time, you still progress
	for rarity, info in Config.Rarities.info do
		local interval = info.attackInterval / info.hazardSpeed
		check(rarity .. " zone-1 hit penalty is below its attack interval", Config.Capture.zoneTuning[1].penalty < interval, tostring(Config.Capture.zoneTuning[1].penalty) .. " vs " .. tostring(interval))
	end
	-- the approved difficulty table (2026-09-07)
	local zones = Config.Capture.zoneTuning
	check("one tuning row per region", #zones == #Config.Regions.list, tostring(#zones))
	check("zone 1 tuning matches the base penalty and knockback", zones[1].penalty == Config.Capture.hitPenalty and zones[1].knockback == Config.Capture.knockback)
	local monotonic = true
	for i = 2, #zones do
		if zones[i].warning > zones[i - 1].warning or zones[i].penalty < zones[i - 1].penalty or zones[i].knockback < zones[i - 1].knockback or zones[i].extraCount < zones[i - 1].extraCount then
			monotonic = false
		end
	end
	check("each zone is at least as hard as the one before", monotonic)
	check("hardest zone warning is 60%", approx(zones[#zones].warning, 0.6), tostring(zones[#zones].warning))
	check("hardest zone penalty is 2.25 s", approx(zones[#zones].penalty, 2.25), tostring(zones[#zones].penalty))
	check("knockback never exceeds 40", zones[#zones].knockback <= 40, tostring(zones[#zones].knockback))
	local legendaryOrbit = Config.Capture.tuning(6, Config.Rarities.rank("Legendary"))
	check("Legendary in Orbit warns for 42% of base and hazards are 45% larger", approx(legendaryOrbit.warning, 0.42) and approx(legendaryOrbit.size, 1.45), tostring(legendaryOrbit.warning) .. " / " .. tostring(legendaryOrbit.size))
	local commonGusty = Config.Capture.tuning(1, 1)
	check("Common in Gusty is untouched", approx(commonGusty.warning, 1) and approx(commonGusty.size, 1) and commonGusty.extraCount == 0 and approx(commonGusty.range, 1) and approx(commonGusty.knockback, 32))
	-- rarity: smaller circle, bigger shove (Gusty Gardens numbers approved 2026-09-07)
	check("four rarity range multipliers, shrinking", #Config.Capture.rarityRangeMult == 4 and Config.Capture.rarityRangeMult[1] == 1 and Config.Capture.rarityRangeMult[4] < Config.Capture.rarityRangeMult[3] and Config.Capture.rarityRangeMult[3] < Config.Capture.rarityRangeMult[2])
	check("four rarity knockback multipliers, growing", #Config.Capture.rarityKnockbackMult == 4 and Config.Capture.rarityKnockbackMult[1] == 1 and Config.Capture.rarityKnockbackMult[4] > Config.Capture.rarityKnockbackMult[3])
	local legendaryGusty = Config.Capture.tuning(1, 4)
	check("Legendary in Gusty: 70% circle (12.6 studs at base), knockback 43", approx(legendaryGusty.range, 0.7) and approx(legendaryGusty.knockback, 43.2, 0.01), tostring(legendaryGusty.range) .. " / " .. tostring(legendaryGusty.knockback))
	check("Legendary in Orbit knockback is 54", approx(legendaryOrbit.knockback, 54, 0.01), tostring(legendaryOrbit.knockback))
	check("a Legendary circle at base range still lets the tether start (claim range)", Config.Capture.tetherRange * legendaryGusty.range <= Config.Capture.claimRange)
	-- the tuning reaches the hazard: Cinder eruption gets a fourth patch and a shorter warning
	do
		local Cap = require(script.Parent.CaptureService)
		local heat = Config.Capture.hazards.Heat
		local base = Cap.buildHazard(heat, Vector3.new(0, 0, 0), Vector3.new(6, 0, 0), 1000, 1, false, Config.Capture.tuning(1, 1))
		local cinder = Cap.buildHazard(heat, Vector3.new(0, 0, 0), Vector3.new(6, 0, 0), 1000, 1, false, Config.Capture.tuning(3, 1))
		check("Gusty-tier eruption has 3 patches and the base warning", #base.positions == heat.count and approx(base.telegraph, heat.telegraph), tostring(#base.positions) .. " / " .. tostring(base.telegraph))
		check("Cinder eruption has 4 patches and 84% warning", #cinder.positions == heat.count + 1 and approx(cinder.telegraph, heat.telegraph * 0.84), tostring(#cinder.positions) .. " / " .. tostring(cinder.telegraph))
		local legendaryGust = Cap.buildHazard(Config.Capture.hazards.Wind, Vector3.new(0, 0, 0), Vector3.new(6, 0, 0), 1000, 1.5, false, Config.Capture.tuning(1, 4))
		check("Legendary gust wall is 45% longer and wider", approx(legendaryGust.length, Config.Capture.hazards.Wind.length * 1.45) and approx(legendaryGust.width, Config.Capture.hazards.Wind.width * 1.45), tostring(legendaryGust.length))
	end
	check("a sweeping wall is lower than a jump", Config.Capture.wallHeight < 7, tostring(Config.Capture.wallHeight))
	-- a roaming leg continues from where the previous one ended, never from the spawn pivot
	local Encounters = require(script.Parent.EncounterService)
	local pivot = Vector3.new(0, 0, 0)
	check("first leg starts at the pivot", Encounters.legStart(nil, pivot) == pivot)
	check("later legs start where the last one ended", Encounters.legStart(Vector3.new(5, 0, 7), pivot) == Vector3.new(5, 0, 7))
end

-- A model replicated from the server reaches the client BEFORE its parts do:
-- at the moment the "Animated" tag signal fires it has no PrimaryPart and no
-- children. Animate.track must say so instead of silently doing nothing, or the
-- caller marks the model tracked and every wild creature stands frozen while
-- the server walks it away (the "catching is buggy" report).
local function testAnimateTrack()
	local Animate = require(ReplicatedStorage.Shared.Models.Animate)
	local m = Instance.new("Model")
	local first = Animate.track(m)
	check("Animate.track returns false for a model with no root yet", first == false, tostring(first))
	check("Animate.track does not register a rootless model", Animate.isTracked(m) == false)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Parent = m
	m.PrimaryPart = root
	local second = Animate.track(m)
	check("Animate.track returns true once the root exists", second == true, tostring(second))
	check("Animate.track registers the model once the root exists", Animate.isTracked(m) == true)
	check("Animate.track is idempotent for a tracked model", Animate.track(m) == true)
	Animate.untrack(m)
	check("Animate.untrack forgets the model", Animate.isTracked(m) == false)
	m:Destroy()
end

-- A built plot carries the pad-management prompt on every pad, disabled, and
-- short enough in range that only the pad you stand at can show one.
local function testPlot()
	local PlotTemplate = require(script.Parent.Parent.Map.PlotTemplate)
	local plot = PlotTemplate.build(CFrame.new(0, -1000, 0), 99)
	local prompts, disabled, ranged = 0, 0, 0
	for pad = 1, Config.Circuits.maxPads do
		local p = plot.pads[pad]
		local prompt = p and p:FindFirstChild("ManagePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompts += 1
			if not prompt.Enabled then
				disabled += 1
			end
			if prompt.MaxActivationDistance < 8 then
				ranged += 1
			end
		end
	end
	check("every pad carries a ManagePrompt", prompts == Config.Circuits.maxPads, tostring(prompts) .. "/" .. tostring(Config.Circuits.maxPads))
	check("pad prompts start disabled (the owner's client enables them)", disabled == prompts, tostring(disabled))
	check("pad prompt range is under the 8-stud pad spacing", ranged == prompts, tostring(ranged))
	plot.model:Destroy()
end

-- The heart of it: every income factor applied exactly once.
local function testCollectionPad()
	local CollectionPad = require(script.Parent.CollectionPadService)
	local hold = Config.Economy.collectHoldSeconds
	check("collect hold is not negative", hold >= 0, tostring(hold))
	local since, pay = CollectionPad.advance(nil, 10, true, true)
	check("collection starts without paying", since == 10 and not pay)
	if hold > 0 then
		since, pay = CollectionPad.advance(since, 10 + hold - 0.01, true, true)
		check("collection waits the full hold", since == 10 and not pay)
	end
	since, pay = CollectionPad.advance(since, 10 + hold, true, true)
	check("collection pays once the hold has passed and clears the timer", since == nil and pay)
	since, pay = CollectionPad.advance(since, 10 + hold + 0.1, true, true)
	check("the next cycle starts a new timer rather than paying at once", since == 10 + hold + 0.1 and not pay)
	since, pay = CollectionPad.advance(since, 11.5 + hold, false, true)
	check("stepping off cancels collection", since == nil and not pay)
	since, pay = CollectionPad.advance(since, 12 + hold, true, true)
	check("returning starts a fresh collection", since == 12 + hold and not pay)
	since, pay = CollectionPad.advance(since, 13 + hold, true, false)
	check("empty bank cancels even a completed timer", since == nil and not pay)
	since, pay = CollectionPad.advance(nil, 14, true, false)
	check("empty bank cannot start collection", since == nil and not pay)
	local pad = Instance.new("Part")
	pad.Size = Vector3.new(8, 0.4, 8)
	pad.CFrame = CFrame.new(20, 2, 30) * CFrame.Angles(0, math.rad(45), 0)
	local function point(x: number, y: number, z: number): Vector3
		return pad.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	check("collection accepts feet on rotated pad", CollectionPad.withinPad(pad, point(0, 3.2, 0), 3))
	check("collection rejects outside rotated pad", not CollectionPad.withinPad(pad, point(4.2, 3.2, 0), 3))
	check("collection rejects above pad", not CollectionPad.withinPad(pad, point(0, 6, 0), 3))
	check("collection rejects below pad", not CollectionPad.withinPad(pad, point(0, 0, 0), 3))
	pad:Destroy()
end

local function testIncome()
	local profile = mockProfile(0)
	local now = workspace:GetServerTimeNow()

	-- a Common Wind creature: region base 4, rarity x1, variant x1, relaunch x1
	local uid = give(profile, "breeze_bean", "Normal", 1)
	local income = Stats.income(profile, now)
	check("common wind earns 4/s", approx(income.perCreature[uid], 4), tostring(income.perCreature[uid]))

	-- rarity multiplier
	local rareUid = give(profile, "twister_terrier", "Normal", 3)
	income = Stats.income(profile, now)
	check("rare wind earns 4 x 7", approx(income.perCreature[rareUid], 28), tostring(income.perCreature[rareUid]))

	-- variant multiplier
	profile.data.creatures[rareUid].variant = "Prismatic"
	income = Stats.income(profile, now)
	check("prismatic doubles it", approx(income.perCreature[rareUid], 56), tostring(income.perCreature[rareUid]))
	profile.data.creatures[rareUid].variant = "Normal"

	-- relaunch multiplier, additive 25% a level
	profile.data.relaunch = 2
	income = Stats.income(profile, now)
	check("relaunch 2 gives x1.5", approx(income.perCreature[uid], 6), tostring(income.perCreature[uid]))
	profile.data.relaunch = 0

	-- stored creatures earn nothing
	profile.data.creatures[uid].pad = nil
	income = Stats.income(profile, now)
	check("stored creature earns nothing", approx(income.perCreature[uid] or 0, 0))
	profile.data.creatures[uid].pad = 1

	-- a circuit: Wind + Storm on adjacent pads, +25% to each, once
	local stormUid = give(profile, "static_sprout", "Normal", 2)
	local key = Config.Circuits.pairKey(1, 2)
	local ok, reason = Stats.checkPair(profile, 1, 2)
	check("wind + storm is a valid pair", ok, reason)
	profile.data.circuits[key] = true
	income = Stats.income(profile, now)
	check("circuit member A gets +25%", approx(income.perCreature[uid], 5), tostring(income.perCreature[uid]))
	-- member B is a Storm creature, so its base is Thunderworks' 64, not Wind's 4.
	-- Derive it rather than hard-coding, so retuning a region cannot silently
	-- turn this into a test that checks nothing.
	local stormBase = Config.Species.baseIncome("static_sprout")
	check("circuit member B gets +25%", approx(income.perCreature[stormUid], stormBase * 1.25), tostring(income.perCreature[stormUid]))

	-- upgraded pairs pay 40%
	profile.data.circuitUpgrades[key] = true
	income = Stats.income(profile, now)
	check("upgraded circuit pays +40%", approx(income.perCreature[uid], 4 * 1.4), tostring(income.perCreature[uid]))
	profile.data.circuitUpgrades[key] = nil

	-- overdrive doubles, cooldown zeroes, and neither touches normal production
	profile.overdrives[key] = { phase = "active", until_ = now + 10, vented = false }
	income = Stats.income(profile, now)
	check("overdrive doubles output", approx(income.perCreature[uid], 5 * 2), tostring(income.perCreature[uid]))
	check("overdrive does not change normal", approx(income.perCreatureNormal[uid], 5), tostring(income.perCreatureNormal[uid]))
	profile.overdrives[key] = { phase = "cooldown", until_ = now + 10, vented = false }
	income = Stats.income(profile, now)
	check("cooldown pays nothing", approx(income.perCreature[uid], 0), tostring(income.perCreature[uid]))
	check("cooldown does not change normal", approx(income.perCreatureNormal[uid], 5), tostring(income.perCreatureNormal[uid]))
	profile.overdrives[key] = nil

	-- an invalid pairing is rejected
	local badUid = give(profile, "gust_bunny", "Normal", 7)
	local okBad, reasonBad = Stats.checkPair(profile, 1, 7)
	check("wind + wind is not a recipe", not okBad, reasonBad)
	local okDiagonal = Stats.checkPair(profile, 1, 8)
	check("diagonal pads are rejected", not okDiagonal)
	-- a creature already in a circuit cannot join another
	local okOverlap, reasonOverlap = Stats.checkPair(profile, 2, 8)
	check("a creature in a circuit cannot join another", not okOverlap, reasonOverlap)
	local _ = badUid

	-- bank cap follows normal production, never the overdriven number
	profile.data.circuits = {}
	income = Stats.income(profile, now)
	local cap = Stats.bankCap(profile)
	check("bank cap is an hour of normal production", approx(cap, income.totalNormal * Config.Economy.income.bankCapSeconds, 1), tostring(cap))
end

local function testUpgrades()
	local profile = mockProfile(0)
	local computed = Stats.compute(profile)
	check("starting pads", computed.padsTotal == 6, tostring(computed.padsTotal))
	check("starting storage", computed.storageMax == 60, tostring(computed.storageMax))
	check("starting tether range", computed.tetherRange == 18, tostring(computed.tetherRange))

	-- caps hold
	profile.data.upgrades.tether_range = 99
	computed = Stats.compute(profile)
	check("tether range caps at 30", computed.tetherRange == 30, tostring(computed.tetherRange))
	profile.data.upgrades.move_speed = 99
	computed = Stats.compute(profile)
	check("walk speed caps at 36", computed.walkSpeed == 36, tostring(computed.walkSpeed))
	profile.data.upgrades.storage = 99
	computed = Stats.compute(profile)
	check("storage caps at 120", computed.storageMax == 120, tostring(computed.storageMax))
	profile.data.upgrades.habitat_capacity = 99
	computed = Stats.compute(profile)
	check("pads cap at 24", computed.padsTotal == 24, tostring(computed.padsTotal))

	-- an upgrade that can no longer do anything is not sellable
	profile.data.relaunch = 10
	check("habitat capacity max shrinks as relaunch pads grow", Stats.maxUpgradeLevel(profile, "habitat_capacity") == 8, tostring(Stats.maxUpgradeLevel(profile, "habitat_capacity")))

	-- costs climb
	check("upgrade cost level 0", Config.Economy.upgradeCost("tether_speed", 0) == 120)
	-- Remote Collector: one level, and the gate that guards the CollectBank remote
	local rc = Config.Economy.upgradeById.remote_collector
	check("remote collector upgrade defined (1 level, 20000)", rc ~= nil and rc.maxLevel == 1 and rc.baseCost == 20000, tostring(rc and rc.baseCost))
	do
		local Economy = require(script.Parent.EconomyService)
		local p = mockProfile(0)
		p.data.bank = 500
		p.remoteCollectReadyAt = 0
		local okNo = Economy.remoteCollectGate(p, 1000)
		check("remote collect refused without the upgrade", okNo == false)
		p.data.upgrades.remote_collector = 1
		local okYes = Economy.remoteCollectGate(p, 1000)
		check("remote collect allowed with the upgrade", okYes == true)
		p.remoteCollectReadyAt = 1030
		local okCooling, why = Economy.remoteCollectGate(p, 1000)
		check("remote collect refused during cooldown", okCooling == false and why ~= nil and why:find("recharging") ~= nil, tostring(why))
		local okLater = Economy.remoteCollectGate(p, 1031)
		check("remote collect allowed after cooldown", okLater == true)
		p.data.bank = 0.4
		local okEmpty = Economy.remoteCollectGate(p, 1031)
		check("remote collect refused with an empty bank", okEmpty == false)
	end
	check("upgrade cost rises", Config.Economy.upgradeCost("tether_speed", 1) > Config.Economy.upgradeCost("tether_speed", 0))
end


-- Money code, so the tests are about what must never happen: paying twice,
-- paying and getting nothing, or a forged save granting anything at all.
local function testPurchases()
	local Purchase = require(script.Parent.PurchaseService)
	local Store = Config.Store

	-- catalogue shape
	local ids: { [string]: boolean } = {}
	local liveAssets: { [number]: string } = {}
	for _, entry in Store.passes do
		check("pass id " .. entry.id .. " is unique", not ids[entry.id])
		ids[entry.id] = true
		if entry.assetId > 0 then
			check("pass asset " .. tostring(entry.assetId) .. " is unique", liveAssets[entry.assetId] == nil)
			liveAssets[entry.assetId] = entry.id
		end
	end
	for _, entry in Store.products do
		check("product id " .. entry.id .. " is unique", not ids[entry.id])
		ids[entry.id] = true
		if entry.assetId > 0 then
			check("product asset " .. tostring(entry.assetId) .. " is unique", liveAssets[entry.assetId] == nil)
			liveAssets[entry.assetId] = entry.id
		end
	end
	-- a 0 asset id must be unreachable from a receipt
	check("no product is reachable by asset id 0", Store.productByAssetId[0] == nil)
	check("no pass is reachable by asset id 0", Store.passByAssetId[0] == nil)

	-- coin bundles are priced at the region unlock costs
	local expectedCoins = { coins_s = 2500, coins_m = 15000, coins_l = 75000, coins_xl = 300000 }
	for id, amount in expectedCoins do
		local product = Store.productById[id]
		check(id .. " grants " .. tostring(amount), product ~= nil and product.grant.kind == "coins" and product.grant.amount == amount)
	end

	-- egg odds are percentages, so the panel number is the table number
	for eggId, egg in Store.eggs do
		local sum = 0
		for _, entry in egg.odds do
			sum += entry.weight
			check(eggId .. " odds tier " .. entry.rarity .. " exists", Config.Rarities.info[entry.rarity] ~= nil)
		end
		check(eggId .. " odds sum to 100", approx(sum, 100), tostring(sum))
		local lastRank = math.huge
		for _, row in Store.eggOdds(eggId) do
			local rank = Config.Rarities.rank(row.rarity)
			check(eggId .. " odds are listed best tier first", rank < lastRank, row.rarity)
			lastRank = rank
		end
	end
	-- the three chase tiers exist, never spawn wild, and climb in value
	local previous = Config.Rarities.info.Legendary.mult
	for _, tier in Config.Rarities.eggTiers do
		local info = Config.Rarities.info[tier]
		check(tier .. " exists", info ~= nil)
		check(tier .. " never spawns in the wild", info.weight == 0, tostring(info.weight))
		check(tier .. " is worth more than the tier below", info.mult > previous, tostring(info.mult))
		previous = info.mult
		check(tier .. " has egg species", #Config.Species.eggSpecies(tier) > 0)
	end
	check("wild ladder is unchanged", #Config.Rarities.wildOrder == 4)
	check("egg species stay out of the Atlas count", Config.Species.count == #Config.Species.list)
	for _, def in Config.Species.eggList do
		check(def.id .. " is egg only", def.eggOnly == true)
		check(def.id .. " borrows a real builder", def.builder ~= nil and Config.Species.byId[def.builder] ~= nil, tostring(def.builder))
		check(def.id .. " is not in a region roster", Config.Species.find(def.region, def.rarity) == nil or Config.Species.find(def.region, def.rarity).id ~= def.id)
	end

	-- pity thresholds climb with the tier, or the higher ones can never land
	for eggId, egg in Store.eggs do
		local floor = 0
		for _, tier in Config.Rarities.eggTiers do
			local threshold = egg.pity[tier]
			check(eggId .. " pity for " .. tier .. " is above the tier below", threshold ~= nil and threshold > floor, tostring(threshold))
			floor = threshold or floor
		end
	end
	do
		local p = mockProfile(0)
		local remaining = Store.pityRemaining("cosmic_egg", p.data.eggs.pity.cosmic_egg)
		check("a fresh player sees the full pity distance", #remaining == 3 and remaining[1].remaining == Store.eggs.cosmic_egg.pity.Mythic, tostring(remaining[1] and remaining[1].remaining))
	end

	-- boosts extend, never stack, and never bank more than their cap
	do
		local p = mockProfile(0)
		local now = os.time()
		local product = Store.productById.boost_income_30m
		local ok = Purchase.settle(p, product, { PurchaseId = "b1", ProductId = 0, CurrencySpent = 0 }, function()
			return true
		end)
		check("a boost purchase is granted", ok == Enum.ProductPurchaseDecision.PurchaseGranted)
		local first = Purchase.boostSecondsLeft(p, "income_2x", now)
		check("30 minutes of boost", first >= 1795 and first <= 1801, tostring(first))
		Purchase.settle(p, product, { PurchaseId = "b2", ProductId = 0, CurrencySpent = 0 }, function()
			return true
		end)
		local second = Purchase.boostSecondsLeft(p, "income_2x", now)
		check("buying again adds time", second >= 3595 and second <= 3601, tostring(second))
		check("the multiplier never stacks", Stats.boostMult(p, "income", now) == 2, tostring(Stats.boostMult(p, "income", now)))
		p.data.boosts.income_2x = now + 999999
		local capped = Profiles.sanitize(DataService.roundTrip(p.data))
		check("a far future boost is capped on load", capped.boosts.income_2x ~= nil and capped.boosts.income_2x - os.time() <= Store.boosts.income_2x.maxStackSeconds + 2, tostring(capped.boosts.income_2x))
		p.data.boosts.income_2x = now - 5
		local expired = Profiles.sanitize(DataService.roundTrip(p.data))
		check("an expired boost is dropped on load", expired.boosts.income_2x == nil)
	end

	-- an income boost pays out more without inflating the bank cap or offline
	do
		local p = mockProfile(0)
		give(p, "breeze_bean", "Normal", 1)
		local now = workspace:GetServerTimeNow()
		local plain = Stats.income(p, now)
		p.data.boosts.income_2x = os.time() + 600
		local boosted = Stats.income(p, now)
		check("a boost doubles what the city pays", approx(boosted.total, plain.total * 2, 0.01), tostring(boosted.total))
		check("a boost leaves the bank cap alone", approx(boosted.totalNormal, plain.totalNormal, 0.001), tostring(boosted.totalNormal))
	end

	-- Quick Tether is capped WITH the upgrade, not on top of it
	do
		local p = mockProfile(0)
		p.data.upgrades.tether_speed = Config.Economy.upgradeById.tether_speed.maxLevel
		local maxed = Stats.compute(p).tetherSpeedMult
		p.data.boosts.tether_fast = os.time() + 600
		local boosted = Stats.compute(p).tetherSpeedMult
		check("Quick Tether cannot pass the capture speed cap", boosted <= Store.tetherSpeedCap + 0.001, tostring(boosted))
		check("Quick Tether does something below the cap", boosted >= maxed, tostring(boosted))
	end

	-- receipts: never twice, never on a failed save
	do
		local p = mockProfile(0)
		local product = Store.productById.coins_m
		local receipt = { PurchaseId = "abc123", ProductId = 0, CurrencySpent = 149 }
		local saved = function()
			return true
		end
		local first = Purchase.settle(p, product, receipt, saved)
		check("a coin bundle is granted", first == Enum.ProductPurchaseDecision.PurchaseGranted)
		check("the coins arrived", p.data.coins == 15000, tostring(p.data.coins))
		check("the receipt is in the ledger", #p.data.purchases.ledger == 1)
		local before = p.data.coins
		local again = Purchase.settle(p, product, receipt, saved)
		check("a repeated receipt is not granted twice", p.data.coins == before, tostring(p.data.coins))
		local _ = again
		-- a failed save must roll everything back
		local coinsBefore, ledgerBefore = p.data.coins, #p.data.purchases.ledger
		local failed = Purchase.settle(p, Store.productById.coins_s, { PurchaseId = "def456", ProductId = 0, CurrencySpent = 49 }, function()
			return false
		end)
		check("a failed save is not acknowledged", failed == Enum.ProductPurchaseDecision.NotProcessedYet)
		check("a failed save gives no coins", p.data.coins == coinsBefore, tostring(p.data.coins))
		check("a failed save leaves no ledger row", #p.data.purchases.ledger == ledgerBefore, tostring(#p.data.purchases.ledger))
		check("a failed save leaves the profile free", p.busy == false)
	end

	-- the ledger stays bounded
	do
		local p = mockProfile(0)
		local product = Store.productById.egg_cosmic_1
		for i = 1, Store.ledgerMax + 12 do
			Purchase.settle(p, product, { PurchaseId = "bulk" .. tostring(i), ProductId = 0, CurrencySpent = 0 }, function()
				return true
			end)
		end
		check("the ledger is trimmed to its cap", #p.data.purchases.ledger == Store.ledgerMax, tostring(#p.data.purchases.ledger))
		check("the oldest receipt is the one dropped", p.data.purchases.ledger[1].id ~= "bulk1")
		check("the eggs all arrived", p.data.eggs.counts.cosmic_egg == Store.ledgerMax + 12, tostring(p.data.eggs.counts.cosmic_egg))
	end

	-- a receipt for a product that does not exist yet is never acknowledged
	check("an unknown asset id resolves to nothing", Store.productByAssetId[987654321] == nil)
	check("a receipt with no player is not processed", Purchase.processReceipt({ PurchaseId = "nobody", ProductId = 987654321, PlayerId = -424242, CurrencySpent = 49 }) == Enum.ProductPurchaseDecision.NotProcessedYet)

	-- hatching: storage is checked first, pity forces the tier, counters reset
	do
		local p = mockProfile(0)
		p.data.eggs.counts.cosmic_egg = 3
		local ok, reason = Purchase.hatch(p, "cosmic_egg", 5)
		check("only 1 or " .. tostring(Store.hatchBatch) .. " hatch at a time", ok == false, tostring(reason))
		local okOwned = Purchase.hatch(p, "cosmic_egg", Store.hatchBatch)
		check("you cannot hatch eggs you do not own", okOwned == false)
	end
	do
		local p = mockProfile(0)
		local counters = { Mythic = Store.eggs.cosmic_egg.pity.Mythic - 1, Celestial = 0, Astral = 0 }
		p.data.eggs.pity.cosmic_egg = counters
		local remaining = Store.pityRemaining("cosmic_egg", counters)
		check("pity counts down to the next Mythic", remaining[1].rarity == "Mythic" and remaining[1].remaining == 1, tostring(remaining[1].remaining))
	end

	-- a forged save grants nothing
	do
		local p = mockProfile(0)
		p.data.purchases.passes = { vip = true, not_a_pass = true } :: any
		p.data.eggs.counts = { cosmic_egg = 5, not_an_egg = 99 } :: any
		p.data.boosts = { not_a_boost = os.time() + 600 } :: any
		local clean = Profiles.sanitize(DataService.roundTrip(p.data))
		check("a real pass survives a save", clean.purchases.passes.vip == true)
		check("an invented pass is dropped", clean.purchases.passes.not_a_pass == nil)
		check("real eggs survive a save", clean.eggs.counts.cosmic_egg == 5, tostring(clean.eggs.counts.cosmic_egg))
		check("an invented egg is dropped", clean.eggs.counts.not_an_egg == nil)
		check("an invented boost is dropped", clean.boosts.not_a_boost == nil)
	end
end


-- Cosmetics are free progress made visible, so the tests are about the promise
-- that they are kept: earned once, kept forever, and never worn without owning.
local function testCosmetics()
	local Cosmetics = require(script.Parent.CosmeticsService)
	local DecorModels = require(ReplicatedStorage.Shared.Models.DecorModels)
	local DecorSlots = require(ReplicatedStorage.Shared.Models.DecorSlots)
	local catalogue = Config.Cosmetics

	-- catalogue shape
	local seen: { [string]: boolean } = {}
	for _, item in catalogue.list do
		check("cosmetic " .. item.id .. " is unique", not seen[item.id])
		seen[item.id] = true
		check(item.id .. " belongs to a real family", table.find(catalogue.families, item.family) ~= nil, item.family)
		check(item.id .. " says how to earn it", #catalogue.requirement(item) > 0)
		if item.unlock.kind == "region" then
			check(item.id .. " names a real region", Config.Regions.byId[item.unlock.regionId] ~= nil, item.unlock.regionId)
		end
	end
	-- every region has exactly one aura, so opening the map is always rewarded
	for _, region in Config.Regions.list do
		local found = 0
		for _, item in catalogue.list do
			if item.unlock.kind == "region" and item.unlock.regionId == region.id then
				found += 1
			end
		end
		check(region.id .. " has one aura", found == 1, tostring(found))
	end
	-- prestige is not for sale
	for _, item in catalogue.list do
		if item.source == "relaunch" or item.source == "crisis" then
			check(item.id .. " cannot be bought", Config.Store.productById[item.id] == nil and Config.Store.passById[item.id] == nil)
		end
	end

	-- earning, wearing, and refusing
	do
		local p = mockProfile(0)
		check("a new player owns nothing", next(p.data.cosmetics.owned) == nil)
		local okWear, why = Cosmetics.equip(p, "aura", "aura_frost")
		check("an unowned aura cannot be worn", okWear == false and why ~= nil and why:find("Frostbite") ~= nil, tostring(why))

		-- the starting region is already open, so its aura is earned at once
		Cosmetics.refresh(p, true)
		check("the starting region grants its aura", p.data.cosmetics.owned.aura_wind == true)
		check("a region that is shut grants nothing", p.data.cosmetics.owned.aura_frost == nil)

		p.data.regions.frostbite_peaks = true
		local granted = Cosmetics.refresh(p, true)
		check("opening a region grants its aura", granted == 1 and p.data.cosmetics.owned.aura_frost == true, tostring(granted))
		check("refreshing again grants nothing", Cosmetics.refresh(p, true) == 0)

		local okEquip = Cosmetics.equip(p, "aura", "aura_frost")
		check("an owned aura can be worn", okEquip == true and p.data.cosmetics.equipped.aura == "aura_frost")
		check("wearing nothing is allowed", Cosmetics.equip(p, "aura", "") == true and p.data.cosmetics.equipped.aura == nil)
		check("a made-up id is refused", Cosmetics.equip(p, "aura", "aura_not_real") == false)
		check("the wrong family is refused", Cosmetics.equip(p, "decoration", "aura_frost") == false)

		-- a relaunch shuts every region again; the aura has to stay
		Cosmetics.equip(p, "aura", "aura_frost")
		p.data.regions = { gusty_gardens = true }
		check("a relaunch keeps the aura", p.data.cosmetics.owned.aura_frost == true)
		check("a relaunch keeps it worn", p.data.cosmetics.equipped.aura == "aura_frost")
		check("refresh never takes one away", Cosmetics.refresh(p, true) == 0 and p.data.cosmetics.owned.aura_frost == true)

		-- prestige comes from the counters, not from regions
		p.data.relaunch = 5
		p.data.stats.crisisWins = 10
		Cosmetics.refresh(p, true)
		check("relaunching grants both prestige auras", p.data.cosmetics.owned.aura_relaunch_1 == true and p.data.cosmetics.owned.aura_relaunch_5 == true)
		check("crisis wins grant their aura", p.data.cosmetics.owned.aura_crisis_10 == true)
	end

	-- buying with Coins: the money is taken, the item arrives, and it goes up by
	-- itself so nothing bought is invisible
	do
		local p = mockProfile(50000)
		local before = p.data.coins
		local okBuy, whyBuy = Cosmetics.buy(p, "decor_banner")
		local price = catalogue.price(catalogue.byId.decor_banner)
		check("a decoration can be bought with Coins", okBuy == true, tostring(whyBuy))
		check("the Coins were taken", p.data.coins == before - price, tostring(p.data.coins))
		check("it is owned", p.data.cosmetics.owned.decor_banner == true)
		check("it waits in the inventory to be placed", next(p.data.cosmetics.placed) == nil)
		check("a decoration is never worn", p.data.cosmetics.equipped.decor == nil)
		check("wearing a decoration is refused", Cosmetics.equip(p, "decor", "decor_banner") == false)
		check("buying it twice is refused", Cosmetics.buy(p, "decor_banner") == false)

		local poor = mockProfile(10)
		local okPoor, whyPoor = Cosmetics.buy(poor, "decor_beacon")
		check("no Coins means no purchase", okPoor == false and whyPoor ~= nil and whyPoor:find("Coins") ~= nil, tostring(whyPoor))
		check("nothing was taken", poor.data.coins == 10, tostring(poor.data.coins))
		check("an earned aura cannot be bought", Cosmetics.buy(poor, "aura_relaunch_1") == false)
	end

	-- decorations are placed by hand, so what matters is the model and the grid
	do
		local usedSlot: { [string]: string } = {}
		local _ = usedSlot
		for _, item in catalogue.list do
			if item.family == "decor" then
				check(item.id .. " has a model builder", DecorModels.has(item.preset), item.preset)
			elseif item.family == "skin" then
				check(item.id .. " repaints the ground", item.palette ~= nil)
			end
		end
		-- slot ids are derived from lattice coordinates, so they survive a save
		check("a slot id round-trips", DecorSlots.idFor(-14, -20) == "s-14_-20", DecorSlots.idFor(-14, -20))
		check("rotation is eighths of a turn", DecorSlots.rotationSteps == 8 and DecorSlots.angleOf(2) == 90, tostring(DecorSlots.angleOf(2)))
		check("rotation wraps", DecorSlots.angleOf(8) == 0)
		-- the free ground is free, so a city is never left unpainted
		check("the standard ground costs nothing", catalogue.price(catalogue.byId.skin_default) == 0)
	end

	-- a forged save cannot dress the player in something they do not own
	do
		local p = mockProfile(0)
		p.data.cosmetics.owned = { aura_wind = true, aura_invented = true } :: any
		p.data.cosmetics.equipped = { aura = "aura_cosmic", hat = "aura_wind" } :: any
		p.data.cosmetics.placed = {
			["s-16_-24"] = { id = "decor_banner", rot = 3 },
			["s-12_-24"] = { id = "decor_banner", rot = 0 },
			["s-8_-24"] = { id = "decor_statue", rot = 99 },
			["nonsense"] = { id = "decor_beacon", rot = 0 },
			["s0_0"] = { id = "not_a_decoration", rot = 0 },
		} :: any
		p.data.cosmetics.owned.decor_banner = true
		p.data.cosmetics.owned.decor_statue = true
		local clean = Profiles.sanitize(DataService.roundTrip(p.data))
		check("a real aura survives a save", clean.cosmetics.owned.aura_wind == true)
		-- one of each: a save claiming the same banner in two places keeps one
		local banners = 0
		for _, entry in clean.cosmetics.placed do
			if entry.id == "decor_banner" then
				banners += 1
			end
		end
		check("a decoration cannot be in two places", banners == 1, tostring(banners))
		check("a rotation out of range is clamped", clean.cosmetics.placed["s-8_-24"] == nil or clean.cosmetics.placed["s-8_-24"].rot <= 7, tostring(clean.cosmetics.placed["s-8_-24"] and clean.cosmetics.placed["s-8_-24"].rot))
		check("a slot id that is not a slot id is dropped", clean.cosmetics.placed.nonsense == nil)
		check("an unowned decoration is not placed", clean.cosmetics.placed["s0_0"] == nil)
		check("an invented aura is dropped", clean.cosmetics.owned.aura_invented == nil)
		check("wearing an unowned aura is dropped", clean.cosmetics.equipped.aura == nil)
		check("wearing it in the wrong family is dropped", clean.cosmetics.equipped.hat == nil)
	end
end

local function testData()
	local profile = mockProfile(1234)
	give(profile, "breeze_bean", "Overcharged", 1)
	give(profile, "tsunami_toad", "Prismatic", nil)
	profile.data.atlas.species.breeze_bean = { firstAt = 100, variants = { Normal = true }, perfect = 2, caught = 5 }
	profile.data.regions.splashwater_bay = true
	profile.data.upgrades.tether_speed = 3

	local round = DataService.roundTrip(profile.data)
	check("round trip keeps coins", round.coins == 1234, tostring(round.coins))
	check("round trip keeps creatures", round.creatures ~= nil)
	local count = 0
	for _ in round.creatures do
		count += 1
	end
	check("round trip keeps both creatures", count == 2, tostring(count))
	check("round trip keeps atlas", round.atlas.species.breeze_bean ~= nil and round.atlas.species.breeze_bean.perfect == 2)
	check("round trip keeps region unlock", round.regions.splashwater_bay == true)
	check("round trip keeps upgrade level", round.upgrades.tether_speed == 3)

	-- sanitising junk
	local dirty = Profiles.sanitize({
		coins = 0 / 0, -- NaN
		relaunch = 9999,
		creatures = {
			good = { id = "breeze_bean", variant = "Normal", pad = 1 },
			bogus = { id = "not_a_real_species", variant = "Normal", pad = 2 },
			badVariant = { id = "gust_bunny", variant = "Sparkly", pad = 3 },
			dupePad = { id = "drizzle_duck", variant = "Normal", pad = 1 },
		},
		regions = { gusty_gardens = true, made_up_place = true },
		upgrades = { tether_speed = 500, nonsense = 4 },
		circuits = { ["1-2"] = true, ["1-8"] = true, ["garbage"] = true },
	})
	check("NaN coins fall back to default", dirty.coins == Config.Economy.startingCoins, tostring(dirty.coins))
	check("relaunch clamped to max", dirty.relaunch == Config.Relaunch.maxLevel, tostring(dirty.relaunch))
	check("unknown species dropped", dirty.creatures.bogus == nil)
	check("known species kept", dirty.creatures.good ~= nil)
	check("bad variant reset to Normal", dirty.creatures.badVariant ~= nil and dirty.creatures.badVariant.variant == "Normal")
	check("duplicate pad resolved", dirty.creatures.dupePad == nil or dirty.creatures.dupePad.pad == nil)
	check("unknown region dropped", dirty.regions.made_up_place == nil)
	check("home region always present", dirty.regions.gusty_gardens == true)
	check("upgrade level clamped", dirty.upgrades.tether_speed == Config.Economy.upgradeById.tether_speed.maxLevel, tostring(dirty.upgrades.tether_speed))
	check("unknown upgrade dropped", dirty.upgrades.nonsense == nil)
	check("valid pair key kept", dirty.circuits["1-2"] == true)
	check("diagonal pair key dropped", dirty.circuits["1-8"] == nil)
	check("garbage pair key dropped", dirty.circuits.garbage == nil)

	-- a totally foreign table must still produce a playable profile
	local alien = Profiles.sanitize({ hello = "world" })
	check("alien save yields defaults", alien.coins == Config.Economy.startingCoins and alien.relaunch == 0)
	check("alien save is JSON safe", pcall(function()
		HttpService:JSONEncode(alien)
	end))
end

local function testSellAndStorage()
	local profile = mockProfile(0)
	local uid = give(profile, "tsunami_toad", "Normal", nil)
	local value = Stats.sellValue(profile, profile.data.creatures[uid])
	local expected = math.floor(Config.Species.baseIncome("tsunami_toad") * Config.Rarities.info.Legendary.sellSeconds)
	check("sell value follows rarity seconds", value == expected, tostring(value) .. " vs " .. tostring(expected))
	check("sell value is never below the floor", Stats.sellValue(profile, { id = "breeze_bean", variant = "Normal", pad = nil, favorite = false, anchored = false, caughtAt = 0, perfect = false }) >= Config.Economy.sellMin)

	-- storage fills up
	local computed = Stats.compute(profile)
	for _ = 1, computed.storageMax do
		give(profile, "breeze_bean", "Normal", nil)
	end
	check("storage reports full", Stats.storageFull(profile), tostring(Stats.storageUsed(profile)))
end

local function testQuestsAndRewards()
	local profile = mockProfile(0)
	give(profile, "breeze_bean", "Normal", 1)
	local reward = Stats.scaledReward(profile, 90, 150, 2e9)
	check("reward respects the minimum", reward >= 150, tostring(reward))
	-- a huge city hits the maximum instead
	profile.data.relaunch = 10
	for pad = 2, 20 do
		give(profile, "the_big_whoops", "Prismatic", pad)
	end
	local big = Stats.scaledReward(profile, 90, 150, 5000)
	check("reward respects the maximum", big == 5000, tostring(big))

	-- the day key is a UTC date and rolls at midnight
	local key = Config.Quests.dayKey(1767225600) -- 2026-01-01T00:00:00Z
	check("day key is the UTC date", key == "2026-01-01", key)
	check("seconds until reset is within a day", Config.Quests.secondsUntilReset(1767225600) == 86400)
end

local function testRelaunchRules()
	local profile = mockProfile(0)
	-- discovery is what gates a relaunch, and it survives selling
	for i = 1, 6 do
		local def = Config.Species.list[i]
		profile.data.atlas.species[def.id] = { firstAt = 1, variants = {}, perfect = 0, caught = 1 }
	end
	check("discovered count", Stats.discoveredCount(profile) == 6, tostring(Stats.discoveredCount(profile)))
	check("6 species meets the first requirement", Stats.discoveredCount(profile) >= Config.Relaunch.speciesRequired(0))

	-- what a relaunch keeps is exactly what the config claims
	check("reset list is not empty", #Config.Relaunch.resets > 0)
	check("keep list is not empty", #Config.Relaunch.keeps > 0)
end

local function testRateLimiter()
	local fake = { Name = "RateTest" } :: any
	local allowed = 0
	for _ = 1, 40 do
		if RateLimiter.allow(fake, "DoRelaunch") then
			allowed += 1
		end
	end
	check("relaunch spam is throttled", allowed <= 2, tostring(allowed))
	RateLimiter.clear(fake)

	-- every client remote has a deliberate bucket rather than the default
	local Remotes = require(ReplicatedStorage.Shared.Remotes)
	local limits = RateLimiter.limits()
	local serverToClient = Remotes.serverToClient
	for _, name in Remotes.eventNames do
		if not serverToClient[name] then
			check("remote " .. name .. " has a rate limit", limits[name] ~= nil)
		end
	end
end

local function testWeighted()
	local weights = { a = 1, b = 0 }
	local hitB = false
	for _ = 1, 200 do
		if Weighted.pick(weights) == "b" then
			hitB = true
		end
	end
	check("zero weight never picked", not hitB)
	check("empty table returns nil", Weighted.pick({}) == nil)
end

-- ---------------------------------------------------------------- run

-- ---------------------------------------------------------------- live suite

-- Checks that need a real player standing on a real plot: the ones that build
-- world instances, which the mock-profile tests above cannot reach. Studio
-- only, and it leaves the profile as it found it apart from the creatures it
-- grants, so it is safe to run on a session you are about to play.
function Harness.runLive(profile: any)
	passed = 0
	failed = 0
	table.clear(failures)
	local S = require(script.Parent.Services)
	local plot = profile.plot
	if not plot then
		print("[LiveTest] skipped: no plot assigned yet")
		return 0, 0, {}
	end

	-- Routes and signs: what Controllers.RouteLights / Waypoints read off the map.
	do
		local CollectionService = game:GetService("CollectionService")
		local chevrons = CollectionService:GetTagged("RouteChevron")
		local tagged, neon, ordered = 0, 0, 0
		local routes: { [string]: number } = {}
		for _, p in chevrons do
			if p:IsA("BasePart") then
				tagged += 1
				if p.Material == Enum.Material.Neon then
					neon += 1
				end
				local id, index, count = p:GetAttribute("RouteId"), p:GetAttribute("Index"), p:GetAttribute("Count")
				if typeof(id) == "string" and typeof(index) == "number" and typeof(count) == "number" and index >= 1 and index <= count then
					ordered += 1
					routes[id] = count
				end
			end
		end
		local routeCount = 0
		for _ in routes do
			routeCount += 1
		end
		check("route chevrons are tagged", tagged > 0, tostring(tagged))
		check("route chevrons are Neon", neon == tagged, tostring(neon) .. "/" .. tostring(tagged))
		check("route chevrons carry RouteId / Index <= Count", ordered == tagged, tostring(ordered) .. "/" .. tostring(tagged))
		check("hub, plots, gates and arena all have routes", routeCount >= 20, tostring(routeCount))
		local signs = 0
		for _, p in CollectionService:GetTagged("Waypoint") do
			if p:IsA("BasePart") and typeof(p:GetAttribute("WaypointName")) == "string" then
				signs += 1
			end
		end
		check("hub destinations carry waypoint names", signs >= 4, tostring(signs))
		-- roads stop at what they lead to
		local roads = {}
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Path" then
				table.insert(roads, d)
			end
		end
		local insidePlot = 0
		local plots = workspace:FindFirstChild("Plots")
		for _, plotModel in (if plots then plots:GetChildren() else {}) do
			local platform = plotModel:FindFirstChild("Platform")
			if platform and platform:IsA("BasePart") then
				for _, r in roads do
					local half = r.CFrame.LookVector * (r.Size.Z / 2)
					for _, pt in { r.Position + half, r.Position - half } do
						local l = platform.CFrame:PointToObjectSpace(pt)
						if math.abs(l.X) < platform.Size.X / 2 - 0.5 and math.abs(l.Z) < platform.Size.Z / 2 - 0.5 then
							insidePlot += 1
						end
					end
				end
			end
		end
		check("no road ends inside a plot platform", insidePlot == 0, tostring(insidePlot))
		-- and no road runs across one: sample the centre line every 3 studs
		local crossing = 0
		for _, plotModel in (if plots then plots:GetChildren() else {}) do
			for _, partName in { "Platform", "Apron" } do
				local slab = plotModel:FindFirstChild(partName)
				if slab and slab:IsA("BasePart") then
					for _, r in roads do
						local half = r.CFrame.LookVector * (r.Size.Z / 2)
						local a, b = r.Position - half, r.Position + half
						local steps = math.max(1, math.floor(r.Size.Z / 3))
						local hit = false
						for i = 0, steps do
							local l = slab.CFrame:PointToObjectSpace(a:Lerp(b, i / steps))
							-- a quarter stud in: a driveway ending exactly at the apron edge is a touch, not a crossing
							if math.abs(l.X) < slab.Size.X / 2 - 0.25 and math.abs(l.Z) < slab.Size.Z / 2 - 0.25 then
								hit = true
							end
						end
						if hit then
							crossing += 1
						end
					end
				end
			end
		end
		check("no road crosses a plot platform or apron", crossing == 0, tostring(crossing))
		-- nor the crisis arena floor (a disc: radial test, not its square bounds)
		local arenaModel = workspace:FindFirstChild("Arena")
		local floor = arenaModel and arenaModel:FindFirstChild("Floor")
		local acrossArena = 0
		if floor and floor:IsA("BasePart") then
			local radius = floor.Size.X / 2
			for _, r in roads do
				local half = r.CFrame.LookVector * (r.Size.Z / 2)
				local a, b = r.Position - half, r.Position + half
				local steps = math.max(1, math.floor(r.Size.Z / 3))
				local hit = false
				for i = 0, steps do
					local q = a:Lerp(b, i / steps)
					local dx, dz = q.X - floor.Position.X, q.Z - floor.Position.Z
					if math.sqrt(dx * dx + dz * dz) < radius - 0.5 then
						hit = true
					end
				end
				if hit then
					acrossArena += 1
				end
			end
		end
		check("no road crosses the arena floor disc", acrossArena == 0, tostring(acrossArena) .. " (floor r=" .. tostring(floor and floor.Size.X / 2) .. ")")
		-- the zoom cap is what keeps creatures clickable; PlayerService sets it at join
		check("camera zoom capped (Config.CameraMaxZoomDistance)", profile.player.CameraMaxZoomDistance <= Config.CameraMaxZoomDistance, tostring(profile.player.CameraMaxZoomDistance))
		-- tools/stamp.py must have run (the post-commit hook does it); "unstamped" means nobody knows which code this is
		local build = require(ReplicatedStorage.Shared.Util.BuildInfo).get()
		check("build stamp present (run tools/stamp.py)", build.hash ~= "unstamped" and build.hash:match("^%x%x%x%x%x%x%x+$") ~= nil, build.hash)
		local arena = workspace:FindFirstChild("Arena")
		local arenaRoads = 0
		if arena then
			for _, d in arena:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Path" then
					arenaRoads += 1
				end
			end
		end
		check("no road crosses the arena floor", arenaRoads == 0, tostring(arenaRoads))
	end

	local function income()
		return Stats.income(profile, workspace:GetServerTimeNow())
	end

	-- deploy builds a creature model and its work station
	local windUid = S.City.grantCreature(profile, "breeze_bean", "Normal", true)
	local stormUid = S.City.grantCreature(profile, "static_sprout", "Normal", false)
	check("grantCreature returns uids", windUid ~= nil and stormUid ~= nil)
	local okDeploy = S.City.deploy(profile, windUid, 1)
	check("deploy to pad 1 succeeds", okDeploy == true)
	check("pad 1 has a creature model", profile.padModels["1"] ~= nil)
	check("pad 1 station is populated", #plot.stations[1]:GetChildren() > 0)
	S.City.deploy(profile, stormUid, 2)

	local base = income()
	local windBase = Config.Species.baseIncome("breeze_bean")
	local stormBase = Config.Species.baseIncome("static_sprout")
	check("deployed wind earns its base", approx(base.perCreature[windUid], windBase), tostring(base.perCreature[windUid]))

	-- a circuit builds machinery and pays both members once
	local okConnect = S.Circuits.connect(profile, 1, 2)
	check("wind + storm connects", okConnect == true)
	check("a machine model appeared", #plot.machines:GetChildren() > 0)
	local bonus = Stats.pairBonus(profile, Config.Circuits.pairKey(1, 2))
	local withCircuit = income()
	check("member A paid the bonus once", approx(withCircuit.perCreature[windUid], windBase * (1 + bonus)), tostring(withCircuit.perCreature[windUid]))
	check("member B paid the bonus once", approx(withCircuit.perCreature[stormUid], stormBase * (1 + bonus)), tostring(withCircuit.perCreature[stormUid]))

	local okDiagonal = S.Circuits.connect(profile, 1, 8)
	check("a diagonal connection is refused", okDiagonal == false)

	-- overdrive doubles, refuses to restart, and leaves normal production alone
	local okOver = S.Circuits.startOverdrive(profile, 1, 2)
	check("overdrive starts", okOver == true)
	local during = income()
	check("overdrive doubles the pair", approx(during.total, withCircuit.total * 2, 0.01), tostring(during.total))
	check("overdrive leaves normal production alone", approx(during.totalNormal, withCircuit.total, 0.01), tostring(during.totalNormal))
	local okRestart = S.Circuits.startOverdrive(profile, 1, 2)
	check("overdrive cannot be restarted while running", okRestart == false)

	-- collecting pays the floor of the bank and leaves the remainder
	profile.data.bank = 250.7
	local coinsBefore = profile.data.coins
	local okCollect = S.Economy.collect(profile)
	check("collect succeeds", okCollect == true)
	check("collect paid floor(bank)", profile.data.coins - coinsBefore == 250, tostring(profile.data.coins - coinsBefore))
	check("collect left the fraction", approx(profile.data.bank, 0.7, 0.001), tostring(profile.data.bank))

	-- selling: allowed for a plain creature, refused for a favorite
	S.City.setFavorite(profile, stormUid, true)
	local okSellFav = S.City.sell(profile, stormUid)
	check("selling a favorite is refused", okSellFav == false)
	S.City.setFavorite(profile, stormUid, false)
	local okSell = S.City.sell(profile, windUid)
	check("selling a deployed creature succeeds", okSell == true)
	check("its pad model was removed", profile.padModels["1"] == nil)
	check("the circuit machine went with it", #plot.machines:GetChildren() == 0)

	-- a wild creature in a region the player has not opened cannot be claimed
	local lockedRegion = nil
	for _, def in Config.Regions.list do
		if not profile.data.regions[def.id] then
			lockedRegion = def
			break
		end
	end
	if lockedRegion then
		local blocked = nil
		for _, model in game:GetService("CollectionService"):GetTagged("Wild") do
			if model:GetAttribute("RegionId") == lockedRegion.id then
				blocked = model:GetAttribute("EncounterUid")
				break
			end
		end
		if blocked then
			local encounter, reason = S.Encounters.claim(profile, blocked)
			check("a locked region refuses the claim", encounter == nil, tostring(reason))
		end
	end

	-- The purchase pipeline against the real profile: a probe cannot do this,
	-- because a probe's `require` returns its own copy of every module and so its
	-- own empty profile table. This runs inside the server, on the live profile.
	local hatched: { string } = {}
	do
		local Purchase = S.Purchase
		if Purchase then
			local coinsBefore = profile.data.coins
			local ledgerBefore = #profile.data.purchases.ledger
			local grantedCoins = Purchase.testGrant(profile, "coins_m")
			check("a coin bundle grants through the real pipeline", grantedCoins == true and profile.data.coins == coinsBefore + 15000, tostring(profile.data.coins - coinsBefore))
			check("the receipt reached the ledger", #profile.data.purchases.ledger == ledgerBefore + 1, tostring(#profile.data.purchases.ledger))

			local plain = Stats.income(profile, workspace:GetServerTimeNow())
			Purchase.testGrant(profile, "boost_income_30m")
			local boosted = Stats.income(profile, workspace:GetServerTimeNow())
			check("a live income boost doubles the payout", approx(boosted.total, plain.total * 2, 0.01), tostring(boosted.total))
			check("a live income boost leaves the bank basis alone", approx(boosted.totalNormal, plain.totalNormal, 0.001), tostring(boosted.totalNormal))
			check("the boost has time on it", Purchase.boostSecondsLeft(profile, "income_2x") > 1700, tostring(Purchase.boostSecondsLeft(profile, "income_2x")))

			Purchase.testGrant(profile, "egg_cosmic_10")
			check("eggs land in the inventory", (profile.data.eggs.counts.cosmic_egg or 0) >= 10, tostring(profile.data.eggs.counts.cosmic_egg))
			-- pity is one hatch from a guaranteed Astral, so this proves the whole
			-- chain: forced tier, egg-only species, a real creature in the city
			profile.data.eggs.pity.cosmic_egg = { Mythic = 49, Celestial = 199, Astral = 499 }
			local okHatch, reason, results = Purchase.hatch(profile, "cosmic_egg", 1)
			check("an egg hatches", okHatch == true, tostring(reason))
			if results and results[1] then
				local result = results[1]
				table.insert(hatched, result.uid)
				check("pity forces the top tier", result.rarity == "Astral", result.rarity)
				local def = Config.Species.byId[result.speciesId]
				check("the hatch is an egg-only species", def ~= nil and def.eggOnly == true, result.speciesId)
				check("the creature is really in the city", profile.data.creatures[result.uid] ~= nil)
				local counters = profile.data.eggs.pity.cosmic_egg
				check("an Astral resets every pity counter", counters.Mythic == 0 and counters.Celestial == 0 and counters.Astral == 0, tostring(counters.Mythic) .. "/" .. tostring(counters.Celestial) .. "/" .. tostring(counters.Astral))
				check("its model builds", CreatureModels.build(result.speciesId) ~= nil)
			end
			-- nothing is for sale yet, so a prompt must refuse rather than open a
			-- purchase window with no product behind it
			local promptOk, promptWhy = Purchase.prompt(profile, "product", "coins_m")
			check("a product with no dashboard id says coming soon", promptOk == false and promptWhy ~= nil and promptWhy:find("coming soon") ~= nil, tostring(promptWhy))
		end
	end

	-- the aura is published as a Player attribute, which is what every other
	-- client draws from; a probe cannot see this, the server can
	do
		local Cosmetics = S.Cosmetics
		if Cosmetics then
			Cosmetics.refresh(profile, true)
			check("the starting region's aura is owned live", profile.data.cosmetics.owned.aura_wind == true)
			Cosmetics.equip(profile, "aura", "aura_wind")
			check("wearing an aura publishes it to every client", profile.player:GetAttribute("Aura") == "aura_wind", tostring(profile.player:GetAttribute("Aura")))
			Cosmetics.equip(profile, "aura", "")
			check("taking it off clears the attribute", profile.player:GetAttribute("Aura") == nil)
		end
	end

	-- decorations, against the real plot: the grid comes from the city itself, so
	-- this is the only place the slot ids can be trusted
	do
		local Cosmetics = S.Cosmetics
		local DecorSlots = require(ReplicatedStorage.Shared.Models.DecorSlots)
		if Cosmetics and plot.model then
			local slots = DecorSlots.compute(plot.model)
			check("the city offers somewhere to put things", #slots >= 6, tostring(#slots))
			local ids: { [string]: boolean } = {}
			for _, slot in slots do
				check("slot " .. slot.id .. " is unique", not ids[slot.id])
				ids[slot.id] = true
			end
			if #slots >= 2 then
				profile.data.cosmetics.owned.decor_banner = true
				-- away from home it must refuse, whatever the client sends
				local wasVisiting = profile.visiting
				profile.visiting = { index = 99 } :: any
				local blocked = Cosmetics.place(profile, "decor_banner", slots[1].id, 0)
				profile.visiting = wasVisiting
				check("a decoration cannot be placed while visiting", blocked == false)

				local okPlace, whyPlace = Cosmetics.place(profile, "decor_banner", slots[1].id, 3)
				check("a decoration can be placed at home", okPlace == true, tostring(whyPlace))
				check("it is recorded in the right slot", profile.data.cosmetics.placed[slots[1].id] ~= nil and profile.data.cosmetics.placed[slots[1].id].rot == 3)
				local folder = plot.model:FindFirstChild("Decorations")
				check("it is really in the city", folder ~= nil and folder:FindFirstChild(slots[1].id) ~= nil)

				Cosmetics.place(profile, "decor_banner", slots[2].id, 0)
				local count = 0
				for _, entry in profile.data.cosmetics.placed do
					if entry.id == "decor_banner" then
						count += 1
					end
				end
				check("moving it does not clone it", count == 1, tostring(count))

				check("it can be put away", Cosmetics.unplace(profile, slots[2].id) == true)
				check("and then it is gone from the city", (plot.model:FindFirstChild("Decorations") :: any):FindFirstChild(slots[2].id) == nil)
				profile.data.cosmetics.owned.decor_banner = nil
			end
		end
	end

	-- tidy up: remove what this suite added
	if profile.data.creatures[stormUid] then
		S.City.sell(profile, stormUid)
	end
	for _, uid in hatched do
		if profile.data.creatures[uid] then
			profile.data.creatures[uid] = nil
		end
	end
	profile.data.boosts.income_2x = nil

	print(("[LiveTest] passed %d, failed %d"):format(passed, failed))
	if failed > 0 then
		for _, line in failures do
			print("[LiveTest]   - " .. line)
		end
	end
	return passed, failed, failures
end

function Harness.run()
	passed = 0
	failed = 0
	table.clear(failures)
	local startedAt = os.clock()

	local suites: { { name: string, fn: () -> () } } = {
		{ name = "config", fn = testConfig },
		{ name = "format", fn = testFormat },
		{ name = "hazards", fn = testHazards },
		{ name = "models", fn = testModels },
		{ name = "plot", fn = testPlot },
		{ name = "animate", fn = testAnimateTrack },
		{ name = "capture balance", fn = testCaptureBalance },
		{ name = "collection pad", fn = testCollectionPad },
		{ name = "income", fn = testIncome },
		{ name = "upgrades", fn = testUpgrades },
		{ name = "purchases", fn = testPurchases },
		{ name = "cosmetics", fn = testCosmetics },
		{ name = "data", fn = testData },
		{ name = "sell/storage", fn = testSellAndStorage },
		{ name = "quests", fn = testQuestsAndRewards },
		{ name = "relaunch", fn = testRelaunchRules },
		{ name = "rate limiter", fn = testRateLimiter },
		{ name = "weighted", fn = testWeighted },
	}

	for _, suite in suites do
		local ok, err = pcall(suite.fn)
		if not ok then
			failed += 1
			table.insert(failures, suite.name .. " crashed: " .. tostring(err))
			warn("[SelfTest] CRASH in " .. suite.name .. ": " .. tostring(err))
		end
	end

	local elapsed = math.floor((os.clock() - startedAt) * 1000)
	print(("[SelfTest] passed %d, failed %d, in %d ms"):format(passed, failed, elapsed))
	if failed > 0 then
		for _, line in failures do
			print("[SelfTest]   - " .. line)
		end
	end
	return passed, failed, failures
end

return Harness
