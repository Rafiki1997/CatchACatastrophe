--!strict
-- Drives every animated model in the world: wild creatures roaming their
-- region, workers on their pads, work stations, circuit machines and pylons.
--
-- All of it is client-side. The server writes attributes (BasePivot, the Path*
-- fields, Working / Overdrive / Cooling) and this steps them once per frame,
-- culled by distance, so a busy server costs the server nothing per creature.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animate = require(ReplicatedStorage.Shared.Models.Animate)
local State = require(script.Parent.Parent.State)

local WorldAnimator = {}

local TAG = "Animated"
local tracked: { [Model]: boolean } = {}
local pylonTint: { [Model]: BasePart } = {}

-- Animate.track needs the model's root part, and a model replicated from the
-- server arrives BEFORE its parts: at the instant the tag signal fires it has no
-- PrimaryPart and no children. So the first attempt usually cannot register it,
-- and it has to be retried once the parts land, or the model stands frozen for
-- the rest of the session while the server walks it away.
local function attemptTrack(model: Model): boolean
	local ok, result = pcall(Animate.track, model)
	if not ok then
		warn("[WorldAnimator] track failed: " .. tostring(result))
		return true -- a real error; do not keep retrying it
	end
	if result ~= true then
		return false
	end
	tracked[model] = true
	-- pylons show their containment progress in the crystal's colour
	if model:GetAttribute("Kind") == "pylon" then
		local crystal = model:FindFirstChild("Crystal", true)
		if crystal and crystal:IsA("BasePart") then
			pylonTint[model] = crystal
		end
	end
	return true
end

local function track(model: Model)
	if tracked[model] then
		return
	end
	if attemptTrack(model) then
		return
	end
	-- Retry one frame after each new child, so the whole replication batch has
	-- landed before Animate scans the descendants for blades, lights and tints.
	local conns: { RBXScriptConnection } = {}
	local pending = false
	local function stop()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end
	local function retry()
		if pending or tracked[model] then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			if tracked[model] or not model.Parent then
				stop()
				return
			end
			if attemptTrack(model) then
				stop()
			end
		end)
	end
	table.insert(conns, model.ChildAdded:Connect(retry))
	table.insert(conns, model:GetPropertyChangedSignal("PrimaryPart"):Connect(retry))
	table.insert(conns, model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stop()
		end
	end))
end

local function untrack(model: Model)
	if not tracked[model] then
		return
	end
	tracked[model] = nil
	pylonTint[model] = nil
	pcall(Animate.untrack, model)
end

local function updatePylons()
	for model, crystal in pylonTint do
		if not model.Parent then
			pylonTint[model] = nil
			continue
		end
		local charge = model:GetAttribute("Charge")
		local t = if typeof(charge) == "number" then math.clamp(charge, 0, 1) else 0
		crystal.Color = Color3.fromRGB(120, 230, 255):Lerp(Color3.fromRGB(140, 255, 170), t)
		local light = crystal:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.2 + t * 1.6
		end
	end
end

function WorldAnimator.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		if inst:IsA("Model") then
			track(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			track(inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			untrack(inst)
		end
	end)

	local pylonAccumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local snap = State.get()
		-- reduced motion still animates the world, just without the camera-shaking
		-- extras; freezing everything would make the city look broken.
		local now = workspace:GetServerTimeNow()
		local ok, err = pcall(Animate.step, now, if camera then camera.CFrame.Position else nil)
		if not ok then
			warn("[WorldAnimator] step failed: " .. tostring(err))
		end
		local _ = snap

		pylonAccumulator += dt
		if pylonAccumulator >= 0.2 then
			pylonAccumulator = 0
			updatePylons()
		end
	end)
end

function WorldAnimator.count(): number
	local n = 0
	for _ in tracked do
		n += 1
	end
	return n
end

return WorldAnimator
