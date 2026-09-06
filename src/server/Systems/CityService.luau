--!strict
-- Plots, creature inventory, and everything a player's city physically shows:
-- the creature standing on each work pad, its work station, the per-pad label,
-- the collection pad text, the billboard, unlocked pads and decorations.
--
-- Every mutating call validates ownership, the pad range, capacity and the
-- visiting state before it touches data, then marks the profile dirty and asks
-- CircuitService to recalculate (a pad change can make or break a pair).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local CityService = {}

local plots: { [number]: any } = {}
local PlotTemplate: any = nil
local MachineryBuilders: any = nil

local function safeCall(systemName: string, fnName: string, ...)
	local system = (S :: any)[systemName]
	if system and typeof(system[fnName]) == "function" then
		local ok, err = pcall(system[fnName], ...)
		if not ok then
			warn("[City] " .. systemName .. "." .. fnName .. " failed: " .. tostring(err))
		end
	end
end

local function machinery(): any
	if not MachineryBuilders then
		local ok, m = pcall(require, ReplicatedStorage.Shared.Models.MachineryBuilders)
		if ok then
			MachineryBuilders = m
		else
			warn("[City] MachineryBuilders unavailable: " .. tostring(m))
		end
	end
	return MachineryBuilders
end

-- ---------------------------------------------------------------- setup

function CityService.init(refs: any, plotTemplate: any)
	PlotTemplate = plotTemplate
	for index, cframe in refs.plots do
		local ok, plot = pcall(PlotTemplate.build, cframe, index)
		if ok then
			plots[index] = plot
		else
			warn("[City] plot " .. tostring(index) .. " failed: " .. tostring(plot))
		end
	end
end

function CityService.plotOf(index: number): any
	return plots[index]
end

function CityService.allPlots(): { [number]: any }
	return plots
end

function CityService.assign(profile: Profile): any
	for index = 1, Config.MaxPlayers do
		local plot = plots[index]
		if plot and plot.model:GetAttribute("OwnerUserId") == 0 then
			plot.model:SetAttribute("OwnerUserId", profile.userId)
			PlotTemplate.setOwner(plot, profile.userId, profile.player.DisplayName)
			profile.plotIndex = index
			profile.plot = plot
			plot.spawnPoint.Enabled = true
			profile.player.RespawnLocation = plot.spawnPoint
			CityService.applyUpgrades(profile)
			CityService.refreshAll(profile)
			profile.dirty = true
			return plot
		end
	end
	return nil
end

function CityService.release(profile: Profile)
	local plot = profile.plot
	if not plot then
		return
	end
	for _, model in profile.padModels do
		model:Destroy()
	end
	profile.padModels = {}
	for _, model in profile.machineModels do
		model:Destroy()
	end
	profile.machineModels = {}
	PlotTemplate.reset(plot)
	PlotTemplate.setOwner(plot, 0, "")
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.spawnPoint.Enabled = false
	profile.plot = nil
	profile.plotIndex = 0
end

-- ---------------------------------------------------------------- inventory

-- Returns (uid, nil) on success, (nil, message) when storage is full.
function CityService.grantCreature(profile: Profile, speciesId: string, variant: string, perfect: boolean): (string?, string?)
	local def = Config.Species.byId[speciesId]
	if not def then
		return nil, "Unknown creature."
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
	local uid = Profiles.newUid(profile)
	profile.data.creatures[uid] = {
		id = speciesId,
		variant = if Config.Variants.isValid(variant) then variant else "Normal",
		pad = nil,
		favorite = false,
		anchored = false,
		caughtAt = os.time(),
		perfect = perfect,
	}
	profile.dirty = true
	return uid, nil
end

local function ownedCreature(profile: Profile, uid: any): (Profiles.CreatureData?, string?)
	if typeof(uid) ~= "string" then
		return nil, "That creature does not exist."
	end
	local entry = profile.data.creatures[uid]
	if not entry then
		return nil, "You do not own that creature."
	end
	return entry, nil
end

local function checkAtHome(profile: Profile): (boolean, string?)
	if profile.visiting then
		return false, "You are visiting another city. Go home first."
	end
	if not profile.plot then
		return false, "Your city is still loading."
	end
	return true, nil
end

function CityService.deploy(profile: Profile, uid: string, pad: number): (boolean, string?)
	local home, homeMsg = checkAtHome(profile)
	if not home then
		return false, homeMsg
	end
	local entry, msg = ownedCreature(profile, uid)
	if not entry then
		return false, msg
	end
	local computed = Stats.compute(profile)
	if pad < 1 or pad > computed.padsTotal then
		return false, "That work pad is locked. Buy Extra Work Pad in the Workshop."
	end
	if entry.pad == pad then
		return false, nil
	end
	if Stats.padOccupant(profile, pad) then
		return false, "That pad already has a creature. Move it or pick another pad."
	end
	entry.pad = pad
	profile.dirty = true
	CityService.refreshPad(profile, pad)
	safeCall("Circuits", "recalculate", profile)
	safeCall("Quests", "tutorialEvent", profile, "deploy")
	local plot = profile.plot
	if plot then
		Notify.effectFor(profile.player, "deploy", PlotTemplate.padCFrame(plot, pad).Position)
	end
	return true, nil
end

function CityService.store(profile: Profile, uid: string): (boolean, string?)
	local home, homeMsg = checkAtHome(profile)
	if not home then
		return false, homeMsg
	end
	local entry, msg = ownedCreature(profile, uid)
	if not entry then
		return false, msg
	end
	if not entry.pad then
		return false, nil
	end
	local pad = entry.pad
	entry.pad = nil
	profile.dirty = true
	CityService.refreshPad(profile, pad)
	safeCall("Circuits", "recalculate", profile)
	return true, nil
end

function CityService.move(profile: Profile, uid: string, pad: number): (boolean, string?)
	local home, homeMsg = checkAtHome(profile)
	if not home then
		return false, homeMsg
	end
	local entry, msg = ownedCreature(profile, uid)
	if not entry then
		return false, msg
	end
	local computed = Stats.compute(profile)
	if pad < 1 or pad > computed.padsTotal then
		return false, "That work pad is locked."
	end
	local from = entry.pad
	if from == pad then
		return false, nil
	end
	local otherUid = Stats.padOccupant(profile, pad)
	if otherUid then
		-- swap: the occupant takes this creature's old pad (or storage)
		profile.data.creatures[otherUid].pad = from
	end
	entry.pad = pad
	profile.dirty = true
	if from then
		CityService.refreshPad(profile, from)
	end
	CityService.refreshPad(profile, pad)
	safeCall("Circuits", "recalculate", profile)
	return true, nil
end

function CityService.setFavorite(profile: Profile, uid: string, favorite: boolean): (boolean, string?)
	local entry, msg = ownedCreature(profile, uid)
	if not entry then
		return false, msg
	end
	entry.favorite = favorite == true
	profile.dirty = true
	if entry.pad then
		CityService.refreshPad(profile, entry.pad)
	end
	return true, nil
end

function CityService.sell(profile: Profile, uid: string): (boolean, string?)
	local entry, msg = ownedCreature(profile, uid)
	if not entry then
		return false, msg
	end
	if entry.favorite then
		return false, "That creature is a favorite. Unfavorite it first if you really want to sell it."
	end
	if entry.anchored then
		return false, "That creature is anchored for your next relaunch and cannot be sold."
	end
	local value = Stats.sellValue(profile, entry)
	local pad = entry.pad
	local def = Config.Species.byId[entry.id]
	profile.data.creatures[uid] = nil
	if S.Economy then
		S.Economy.addCoins(profile, value, "sell")
	end
	profile.dirty = true
	if pad then
		CityService.refreshPad(profile, pad)
		safeCall("Circuits", "recalculate", profile)
	end
	Notify.player(profile.player, "success", "Sold " .. (if def then def.name else "creature") .. " for " .. Format.abbreviate(value) .. " Coins.", 4)
	return true, nil
end

-- ---------------------------------------------------------------- visuals

local function padLabel(model: Model, text: string)
	local billboard = model:FindFirstChild("PadLabel") :: BillboardGui?
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "PadLabel"
		billboard.Size = UDim2.fromScale(10, 2.2)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
		billboard.MaxDistance = 120
		billboard.Parent = model
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 252, 245)
		label.TextStrokeTransparency = 0.25
		label.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		label.Parent = billboard
	end
	local text_ = billboard:FindFirstChild("Text")
	if text_ and text_:IsA("TextLabel") then
		text_.Text = text
	end
end

-- Rebuild one pad: the creature model, its station, and the label.
function CityService.refreshPad(profile: Profile, pad: number)
	local plot = profile.plot
	if not plot then
		return
	end
	local uid = Stats.padOccupant(profile, pad)
	local existing = profile.padModels[tostring(pad)]
	if existing then
		existing:Destroy()
		profile.padModels[tostring(pad)] = nil
	end
	local stationFolder = plot.stations[pad]
	if stationFolder then
		stationFolder:ClearAllChildren()
	end
	if not uid then
		return
	end

	local entry = profile.data.creatures[uid]
	local def = Config.Species.byId[entry.id]
	if not def then
		return
	end

	-- creature
	local ok, model = pcall(CreatureModels.build, entry.id, entry.variant)
	if ok and typeof(model) == "Instance" then
		local m = model :: Model
		m.Name = "Worker_" .. tostring(pad)
		local cf = PlotTemplate.padCFrame(plot, pad)
		m:PivotTo(cf)
		m:SetAttribute("BasePivot", cf)
		m:SetAttribute("Working", true)
		m:SetAttribute("Uid", uid)
		CollectionService:AddTag(m, "Animated")
		m.Parent = stationFolder or plot.model

		local income = Stats.income(profile, workspace:GetServerTimeNow())
		local variantInfo = Config.Variants.info[entry.variant]
		local text = def.name
			.. "  "
			.. Config.Rarities.label(def.rarity)
			.. (if entry.variant ~= "Normal" then "  " .. variantInfo.icon .. " " .. variantInfo.label else "")
			.. (if entry.favorite then "  *" else "")
			.. "\n"
			.. Format.abbreviate(income.perCreature[uid] or 0)
			.. "/s"
		padLabel(m, text)
		profile.padModels[tostring(pad)] = m
	else
		warn("[City] creature model failed: " .. tostring(entry.id) .. " " .. tostring(model))
	end

	-- work station behind the creature
	local mb = machinery()
	if mb and stationFolder then
		local okS, station = pcall(mb.buildWorkStation, def.job, Config.Regions.elementColor(def.element))
		if okS and typeof(station) == "Instance" then
			local sm = station :: Model
			local cf = PlotTemplate.stationCFrame(plot, pad)
			sm:PivotTo(cf)
			sm:SetAttribute("BasePivot", cf)
			sm:SetAttribute("Working", true)
			CollectionService:AddTag(sm, "Animated")
			sm.Parent = stationFolder
		end
	end
end

function CityService.refreshAll(profile: Profile)
	if not profile.plot then
		return
	end
	for pad = 1, Config.Circuits.maxPads do
		CityService.refreshPad(profile, pad)
	end
	safeCall("Circuits", "recalculate", profile)
	CityService.refreshLabels(profile)
end

-- Cheap per-second text updates: bank, earnings, pad income, booth console.
function CityService.refreshLabels(profile: Profile)
	local plot = profile.plot
	if not plot or not profile.loaded then
		return
	end
	local now = workspace:GetServerTimeNow()
	local computed = Stats.compute(profile)
	local income = Stats.income(profile, now, computed)
	local cap = income.totalNormal * computed.bankCapSeconds

	local bank = math.floor(profile.data.bank)
	if cap > 0 and profile.data.bank >= cap - 0.5 then
		plot.collectLabel.Text = "BANK FULL - " .. Format.abbreviate(bank)
		plot.collectLabel.TextColor3 = Color3.fromRGB(255, 140, 120)
	else
		plot.collectLabel.Text = "Bank: " .. Format.abbreviate(bank)
		plot.collectLabel.TextColor3 = Color3.fromRGB(255, 252, 245)
	end
	plot.billboardEarnings.Text = Format.abbreviate(income.total) .. "/s"

	local title = Stats.title(profile)
	plot.billboardTitle.Text = profile.player.DisplayName .. (if title then "\n" .. title else "")

	-- per-pad income lines
	for padKey, model in profile.padModels do
		local pad = tonumber(padKey)
		if pad then
			local uid = Stats.padOccupant(profile, pad)
			if uid then
				local billboard = model:FindFirstChild("PadLabel")
				local label = billboard and billboard:FindFirstChild("Text")
				if label and label:IsA("TextLabel") then
					local head = string.split(label.Text, "\n")[1]
					label.Text = head .. "\n" .. Format.abbreviate(income.perCreature[uid] or 0) .. "/s"
				end
			end
		end
	end

	-- booth console
	local lines = {}
	for key, pair in income.pairs do
		local od = profile.overdrives[key]
		local phase = if od then od.phase else "idle"
		local circuit = Config.Circuits.byId[pair.circuitId]
		local status = if phase == "active"
			then " OVERDRIVE"
			elseif phase == "cooldown" then " cooling"
			else ""
		table.insert(lines, (if circuit then circuit.name else pair.circuitId) .. " +" .. Format.percent(pair.bonus) .. status)
	end
	if #lines == 0 then
		plot.booth.console.Text = "No circuits running.\nPut two matching creatures on side-by-side pads."
	else
		table.sort(lines)
		plot.booth.console.Text = table.concat(lines, "\n")
	end
end

-- Pad unlocks, decoration tier and claimed milestone decorations.
function CityService.applyUpgrades(profile: Profile)
	local plot = profile.plot
	if not plot then
		return
	end
	local computed = Stats.compute(profile)
	for pad = 1, Config.Circuits.maxPads do
		PlotTemplate.setPadUnlocked(plot, pad, pad <= computed.padsTotal)
	end
	PlotTemplate.setDecorationTier(plot, computed.decorationTier)
	for _, milestone in Config.Milestones.list do
		local claimed = profile.data.atlas.claimed[tostring(milestone.count)] == true
		PlotTemplate.setRewardDecoration(plot, milestone.decoration, claimed)
	end
end

S.City = CityService
return CityService
