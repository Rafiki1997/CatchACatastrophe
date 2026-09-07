--!strict
-- The server owns both occupancy and payout timing. Client attributes are display only.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)
local Sync = require(script.Parent.Sync)
local Notify = require(script.Parent.Notify)

local CollectionPad = {}
local DURATION = Config.Economy.collectHoldSeconds
local cycles: { [Player]: { since: number, pad: BasePart, character: Model } } = {}
-- One payout per visit. Without this the pad paid every 0.2 s for as long as the
-- player stood on it (a toast and a "+N" flash five times a second); stepping
-- off and back on collects again.
local paidThisVisit: { [Player]: boolean } = {}

-- Pure timer rule, also exercised by the self-test suite.
function CollectionPad.advance(since: number?, now: number, eligible: boolean, hasCoins: boolean): (number?, boolean)
	if not eligible or not hasCoins then
		return nil, false
	end
	if not since then
		return now, false
	end
	if now - since >= DURATION then
		return nil, true
	end
	return since, false
end

function CollectionPad.withinPad(pad: BasePart, rootPosition: Vector3, footOffset: number): boolean
	local p = pad.CFrame:PointToObjectSpace(rootPosition)
	local feet = p.Y - footOffset
	return math.abs(p.X) <= pad.Size.X / 2 and math.abs(p.Z) <= pad.Size.Z / 2
		and feet >= -1.5 and feet <= pad.Size.Y / 2 + 1
end

function CollectionPad.update(profile: Profiles.Profile, now: number)
	local player = profile.player
	local plot = profile.plot
	local pad = plot and plot.collectPad
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local eligible = profile.loaded and not profile.leaving and not profile.busy and not profile.visiting
		and plot and profile.plotIndex == plot.index and plot.model:GetAttribute("OwnerUserId") == player.UserId
		and pad and pad.Parent and character and root and root:IsA("BasePart")
		and humanoid and humanoid.Health > 0 and humanoid.FloorMaterial ~= Enum.Material.Air
	if eligible then
		local leg = character:FindFirstChild("Left Leg")
		local extra = if humanoid.RigType == Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") then leg.Size.Y else 0
		eligible = CollectionPad.withinPad(pad, root.Position, humanoid.HipHeight + root.Size.Y / 2 + extra)
	end
	local cycle = cycles[player]
	if cycle and (cycle.pad ~= pad or cycle.character ~= character) then
		cycle = nil
	end
	-- Leaving the pad footprint re-arms the payout. Anything less (a jump, a
	-- brief moment in the air, a menu opening) must not: that would pay again.
	local onPad = pad and pad.Parent and root and root:IsA("BasePart") and character
	if onPad then
		local l = pad.CFrame:PointToObjectSpace(root.Position)
		onPad = math.abs(l.X) <= pad.Size.X / 2 + 1 and math.abs(l.Z) <= pad.Size.Z / 2 + 1 and math.abs(l.Y) < 8
	end
	if not onPad then
		paidThisVisit[player] = nil
	end
	local since, pay = CollectionPad.advance(cycle and cycle.since, now, eligible == true, profile.data.bank >= 1 and not paidThisVisit[player])
	cycles[player] = if since and pad and character then { since = since, pad = pad, character = character } else nil
	player:SetAttribute("CollectionStartedAt", since)
	local status: string? = nil
	if eligible then
		if paidThisVisit[player] then
			status = "Done"
		elseif since then
			status = "Collecting"
		else
			status = "Waiting"
		end
	end
	player:SetAttribute("CollectionStatus", status)
	if pay and S.Economy then
		local before = profile.data.coins
		local ok = S.Economy.collect(profile, true)
		paidThisVisit[player] = true
		if ok then
			local amount = profile.data.coins - before
			player:SetAttribute("CollectionLastAmount", amount)
			player:SetAttribute("CollectionLastAt", now)
			Notify.player(player, "success", Format.abbreviate(amount) .. " Coins collected!", 3)
			Sync.push(profile)
		end
	end
end

function CollectionPad.init()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		cycles[player] = nil
		paidThisVisit[player] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then return end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, profile in Profiles.all() do
			local ok, err = pcall(CollectionPad.update, profile, now)
			if not ok then warn("[CollectionPad] " .. tostring(err)) end
		end
	end)
end

return CollectionPad
