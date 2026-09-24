--!strict
-- Decorative motion only: anchored, non-colliding parts; culled and stepped at
-- 30 Hz locally. Reduced motion restores the authored pose, including offscreen.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local State = require(script.Parent.Parent.State)
local Animator = {}
local tracked: { [BasePart]: boolean } = {}
local TAG = "SceneryMotion"

local function add(inst: Instance)
	if inst:IsA("BasePart") then tracked[inst] = true end
end

function Animator.init()
	for _, inst in CollectionService:GetTagged(TAG) do add(inst) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if inst:IsA("BasePart") then tracked[inst] = nil end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then return end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if not camera then return end
		local snap = State.get()
		local reduced = snap and snap.settings.reducedMotion == true
		local now = workspace:GetServerTimeNow()
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for p in tracked do
			if not p:IsDescendantOf(workspace) then continue end
			local pivot = p:GetAttribute("SceneryPivot")
			local offset = p:GetAttribute("SceneryOffset")
			local speed = p:GetAttribute("ScenerySpeed")
			local phase = p:GetAttribute("SceneryPhase")
			-- Attributes may arrive after the tag; retry naturally on the next tick.
			if typeof(pivot) ~= "CFrame" or typeof(offset) ~= "CFrame" or typeof(speed) ~= "number" or typeof(phase) ~= "number" then continue end
			if not reduced and (pivot.Position - camera.CFrame.Position).Magnitude > 260 then continue end
			local angle = 0
			if not reduced then
				if p:GetAttribute("SceneryMode") == "Spin" then
					angle = (now * speed + phase) % (math.pi * 2)
				else
					local amplitude = p:GetAttribute("SceneryAmplitude")
					angle = math.sin(now * speed + phase) * (if typeof(amplitude) == "number" then amplitude else 0.045)
				end
			end
			table.insert(parts, p)
			table.insert(frames, pivot * CFrame.Angles(0, 0, angle) * offset)
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
	end)
end

return Animator
