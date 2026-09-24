--!strict
-- Gates guide entry; server-side region volumes enforce purchased access from
-- every direction and at every height (jumping over a fence is still entry).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Profiles = require(script.Parent.Profiles)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

local Access = {}
local regions: { [string]: any } = {}
local lastNotice: { [number]: number } = {}
local INTERVAL = 0.2

function Access.findLocked(position: Vector3, unlocked: { [string]: boolean }): (string?, any?)
	for id, region in regions do
		local def = Config.Regions.byId[id]
		if def and def.unlockCost > 0 and unlocked[id] ~= true then
			local delta = position - region.centre
			local half = region.accessHalf
			if half then
				-- The cells tile exactly, so a rectangle per cell covers every
				-- way in without two regions claiming the same ground.
				if math.abs(delta.X) <= half.X and math.abs(delta.Z) <= half.Z then
					return id, region
				end
			else
				local radius = region.accessRadius or 78
				if delta.X * delta.X + delta.Z * delta.Z <= radius * radius then
					return id, region
				end
			end
		end
	end
	return nil, nil
end

function Access.enforce(profile: Profiles.Profile, now: number): string?
	if not profile.loaded or profile.leaving then
		return nil
	end
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local id, region = Access.findLocked(root.Position, profile.data.regions)
	if not id or not region then
		return nil
	end
	if profile.capture and S.Capture then
		S.Capture.cancel(profile, "This region is locked.")
	end
	-- Always land on the existing approach road, outside both the gate and the
	-- protected radius. Clearing velocity prevents repeated jump/knockback entry.
	local gate = region.gate
	local outside = gate.Position + gate.CFrame.LookVector * 12
	local safe = Vector3.new(outside.X, region.centre.Y + 4, outside.Z)
	character:PivotTo(CFrame.lookAt(safe, Vector3.new(region.centre.X, safe.Y, region.centre.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if now - (lastNotice[profile.userId] or -math.huge) >= 5 then
		lastNotice[profile.userId] = now
		local def = Config.Regions.byId[id]
		Notify.player(profile.player, "info", "Unlock " .. def.name .. " at its gate for " .. Format.abbreviate(def.unlockCost) .. " Coins.", 4)
	end
	return id
end

function Access.init(refs: any)
	regions = refs.regions or {}
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < INTERVAL then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, profile in Profiles.all() do
			Access.enforce(profile, now)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastNotice[player.UserId] = nil
	end)
end

S.RegionAccess = Access
return Access
