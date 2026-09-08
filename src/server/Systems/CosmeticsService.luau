--!strict
-- Who owns which cosmetic, and which one they are wearing.
--
-- Ownership is stored per item rather than recomputed from the player's current
-- progress, because progress moves backwards: a relaunch closes every region
-- again, and an aura earned by opening Cinder Canyon must not vanish when the
-- city resets. `refresh` therefore only ever adds.
--
-- What is worn is published as a Player attribute rather than sent over a
-- remote: attributes replicate to every client automatically, so one player
-- putting on an aura is drawn for everyone in the server, including anyone who
-- joins afterwards, with no message of our own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DecorModels = require(ReplicatedStorage.Shared.Models.DecorModels)
local DecorSlots = require(ReplicatedStorage.Shared.Models.DecorSlots)

local Notify = require(script.Parent.Notify)
local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)
local Sync = require(script.Parent.Sync)

type Profile = Profiles.Profile

local CosmeticsService = {}

local Cosmetics = Config.Cosmetics
local AURA_ATTRIBUTE = "Aura"
local DECOR_FOLDER = "Decorations"

local function owned(profile: Profile, id: string): boolean
	return profile.data.cosmetics.owned[id] == true
end

-- Has this player met the condition? Ownership is granted from this, never read
-- from it afterwards.
local function earned(profile: Profile, item: Config.Cosmetic): boolean
	local unlock = item.unlock
	local d = profile.data
	if unlock.kind == "region" then
		return d.regions[unlock.regionId] == true
	elseif unlock.kind == "relaunch" then
		return d.relaunch >= unlock.count
	elseif unlock.kind == "crisis" then
		return d.stats.crisisWins >= unlock.wins
	elseif unlock.kind == "coins" then
		return unlock.price <= 0 -- the free default; the rest are bought
	end
	return false -- store items are granted by the purchase, not by playing
end

-- Repaints the ground and puts the bought decorations on their corners. Runs on
-- the plot model itself, so a visitor standing in someone's city sees exactly
-- what the owner sees.
function CosmeticsService.applyCity(profile: Profile)
	local plot = profile.plot
	local model = plot and plot.model
	if not model then
		return
	end
	local equipped = profile.data.cosmetics.equipped

	-- skin: repaint the slabs the city stands on
	local skin = Cosmetics.byId[equipped.skin or ""]
	local palette = if skin then skin.palette else nil
	if palette then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				if part.Name == "Platform" then
					part.Color = palette.platform
				elseif part.Name == "Apron" then
					part.Color = palette.apron
				elseif part.Name == "Kerb" then
					part.Color = palette.kerb
				end
			end
		end
	end

	-- decorations: whatever the player put down, where they put it, facing the
	-- way they turned it. Only what actually changed is rebuilt, so moving one
	-- ornament does not flicker the rest.
	local folder = model:FindFirstChild(DECOR_FOLDER)
	if not folder then
		local made = Instance.new("Model")
		made.Name = DECOR_FOLDER
		made.Parent = model
		folder = made
	end
	local wanted: { [string]: boolean } = {}
	for slotId, entry in profile.data.cosmetics.placed do
		local item = Cosmetics.byId[entry.id]
		if item and item.family == "decor" and owned(profile, entry.id) then
			wanted[slotId] = true
			local existing = folder:FindFirstChild(slotId)
			if existing and (existing:GetAttribute("CosmeticId") ~= entry.id or existing:GetAttribute("Rot") ~= entry.rot) then
				existing:Destroy()
				existing = nil
			end
			if not existing then
				local slot = DecorSlots.find(model, slotId)
				local built = if slot then DecorModels.build(item.preset, item.color, slotId) else nil
				if built and slot then
					built:SetAttribute("CosmeticId", entry.id)
					built:SetAttribute("Rot", entry.rot)
					built:PivotTo(model:GetPivot() * CFrame.new(slot.offset + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(DecorSlots.angleOf(entry.rot)), 0))
					built.Parent = folder
				end
			end
		end
	end
	for _, child in folder:GetChildren() do
		if not wanted[child.Name] then
			child:Destroy()
		end
	end
end

-- Publishes what the player is wearing. Called after every change and on spawn.
function CosmeticsService.apply(profile: Profile)
	local player = profile.player
	if not player.Parent then
		return
	end
	local auraId = profile.data.cosmetics.equipped.aura
	if auraId and owned(profile, auraId) and Cosmetics.byId[auraId] then
		player:SetAttribute(AURA_ATTRIBUTE, auraId)
	else
		player:SetAttribute(AURA_ATTRIBUTE, nil)
	end
end

function CosmeticsService.grant(profile: Profile, id: string, quiet: boolean?): boolean
	local item = Cosmetics.byId[id]
	if not item or owned(profile, id) then
		return false
	end
	profile.data.cosmetics.owned[id] = true
	profile.dirty = true
	if not quiet and profile.player.Parent then
		Notify.player(profile.player, "success", "New " .. item.family .. ": " .. item.name .. "! Put it on in the Supply Depot.", 7)
	end
	return true
end

-- Grants everything the player has already earned. Safe to call at any time and
-- as often as we like: it only adds, and it says nothing on a first load when
-- the player is being caught up rather than rewarded.
function CosmeticsService.refresh(profile: Profile, quiet: boolean?): number
	local granted = 0
	for _, item in Cosmetics.list do
		if not owned(profile, item.id) and earned(profile, item) then
			if CosmeticsService.grant(profile, item.id, quiet) then
				granted += 1
			end
		end
	end
	if granted > 0 then
		CosmeticsService.apply(profile)
	end
	return granted
end

-- Wearing nothing is a valid choice, so an empty id unequips rather than erroring.
function CosmeticsService.equip(profile: Profile, family: any, id: any): (boolean, string?)
	if typeof(family) ~= "string" or typeof(id) ~= "string" then
		return false, "That is not something you can wear."
	end
	if id == "" then
		-- an empty id clears the family, or one decoration corner by its key
		profile.data.cosmetics.equipped[family] = nil
		profile.dirty = true
		CosmeticsService.apply(profile)
		CosmeticsService.applyCity(profile)
		Sync.push(profile)
		return true, nil
	end
	local item = Cosmetics.byId[id]
	if not item or item.family ~= family then
		return false, "That is not something you can wear."
	end
	if item.family == "decor" then
		return false, "Decorations are placed in your city, not worn."
	end
	if not owned(profile, id) then
		return false, item.name .. " is not yours yet: " .. Cosmetics.requirement(item, function(regionId)
			local region = Config.Regions.byId[regionId]
			return if region then region.name else regionId
		end) .. "."
	end
	profile.data.cosmetics.equipped[family] = id
	profile.dirty = true
	if S.Quests then
		pcall(S.Quests.tutorialEvent, profile, "cosmetic")
	end
	CosmeticsService.apply(profile)
	CosmeticsService.applyCity(profile)
	Sync.push(profile)
	return true, nil
end

-- Decorating is something you do at home: the player has to be standing on
-- their own plot, so nothing can be moved from across the map or while
-- visiting someone else.
local function atHome(profile: Profile): (boolean, string?)
	local plot = profile.plot
	local model = plot and plot.model
	if not model then
		return false, "Your city is still being built. Try again in a moment."
	end
	if profile.visiting then
		return false, "You can only decorate your own city."
	end
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "Go to your city to decorate it."
	end
	local here = model:GetPivot():PointToObjectSpace(root.Position)
	if math.abs(here.X) > 34 or math.abs(here.Z) > 34 then
		return false, "Go to your city to decorate it."
	end
	return true, nil
end

-- Where a decoration currently stands, if anywhere.
function CosmeticsService.slotOf(profile: Profile, id: string): string?
	for slotId, entry in profile.data.cosmetics.placed do
		if entry.id == id then
			return slotId
		end
	end
	return nil
end

-- Put one down, or move one that is already down. There is one of each, so
-- placing a decoration that is already somewhere moves it rather than cloning it.
function CosmeticsService.place(profile: Profile, id: any, slotId: any, rot: any): (boolean, string?)
	if typeof(id) ~= "string" or typeof(slotId) ~= "string" or typeof(rot) ~= "number" then
		return false, "That is not something you can place."
	end
	local item = Cosmetics.byId[id]
	if not item or item.family ~= "decor" then
		return false, "That is not something you can place."
	end
	if not owned(profile, id) then
		return false, "You do not own " .. item.name .. " yet."
	end
	local ok, why = atHome(profile)
	if not ok then
		return false, why
	end
	local model = profile.plot.model
	if not DecorSlots.find(model, slotId) then
		return false, "That spot will not take a decoration."
	end
	local occupant = profile.data.cosmetics.placed[slotId]
	if occupant and occupant.id ~= id then
		local other = Cosmetics.byId[occupant.id]
		return false, (if other then other.name else "Something") .. " is already there."
	end
	local previous = CosmeticsService.slotOf(profile, id)
	if previous then
		profile.data.cosmetics.placed[previous] = nil
	end
	profile.data.cosmetics.placed[slotId] = { id = id, rot = math.clamp(math.floor(rot), 0, DecorSlots.rotationSteps - 1) }
	profile.dirty = true
	if S.Quests then
		pcall(S.Quests.tutorialEvent, profile, "cosmetic")
	end
	CosmeticsService.applyCity(profile)
	Sync.push(profile)
	return true, nil
end

-- Back into the inventory. Still owned, just not out.
function CosmeticsService.unplace(profile: Profile, slotId: any): (boolean, string?)
	if typeof(slotId) ~= "string" then
		return false, "That is not something you can pick up."
	end
	local entry = profile.data.cosmetics.placed[slotId]
	if not entry then
		return false, "There is nothing there."
	end
	local ok, why = atHome(profile)
	if not ok then
		return false, why
	end
	profile.data.cosmetics.placed[slotId] = nil
	profile.dirty = true
	CosmeticsService.applyCity(profile)
	Sync.push(profile)
	local item = Cosmetics.byId[entry.id]
	Notify.player(profile.player, "info", (if item then item.name else "It") .. " is back in your inventory.", 4)
	return true, nil
end

-- Bought with Coins. Everything here is cosmetic, so the only failure worth a
-- message is not having the money.
function CosmeticsService.buy(profile: Profile, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "That is not something you can buy."
	end
	local item = Cosmetics.byId[id]
	if not item then
		return false, "That is not something you can buy."
	end
	local price = Cosmetics.price(item)
	if not price then
		return false, item.name .. " is not for sale: " .. Cosmetics.requirement(item, function(regionId)
			local region = Config.Regions.byId[regionId]
			return if region then region.name else regionId
		end) .. "."
	end
	if owned(profile, id) then
		return false, "You already own " .. item.name .. "."
	end
	if profile.busy then
		return false, "Finish what you are doing first."
	end
	if price > 0 then
		profile.busy = true
		local paid = S.Economy ~= nil and S.Economy.spend(profile, price)
		profile.busy = false
		if not paid then
			return false, "You need " .. tostring(price) .. " Coins for " .. item.name .. "."
		end
	end
	profile.data.cosmetics.owned[id] = true
	profile.dirty = true
	local message
	if item.family == "decor" then
		-- a decoration is placed by hand, so it waits in the inventory rather
		-- than appearing somewhere the player did not choose
		message = item.name .. " is in your inventory. Stand in your city and press Place to put it down."
		Sync.push(profile)
	else
		CosmeticsService.equip(profile, item.family, id)
		message = if item.family == "aura" then item.name .. " is yours, and you are wearing it."
			else item.name .. " is down. Your whole city is standing on it."
	end
	Notify.player(profile.player, "success", message, 7)
	return true, nil
end

function CosmeticsService.onJoin(profile: Profile)
	-- quiet: a returning player is being caught up, not congratulated
	CosmeticsService.refresh(profile, true)
	CosmeticsService.apply(profile)
	CosmeticsService.applyCity(profile)
end

-- Called wherever progress moves: a region opened, a relaunch, a crisis won.
function CosmeticsService.onProgress(profile: Profile)
	if CosmeticsService.refresh(profile, false) > 0 then
		Sync.push(profile)
	end
end

S.Cosmetics = CosmeticsService

return CosmeticsService
